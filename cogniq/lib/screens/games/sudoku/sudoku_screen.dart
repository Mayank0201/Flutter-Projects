import 'dart:math';
import 'dart:async';
import 'dart:convert';
import '../../../utils/rotation_engine.dart';
import '../../../utils/point_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../widgets/game_level_chip.dart';
import 'sudoku_levels.dart';
import 'package:cogniq/widgets/buy_hints_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/prefs_keys.dart';
import '../../../utils/audio_manager.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/rules_helper.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/fog_overlay.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../widgets/loss_overlay.dart';
import '../../../utils/shuffle_manager.dart';



/// The free-play modifier pool. Mirrored by `pools['sudoku']` in
/// test/difficulty_curve_test.dart — keep the two in step.
///
/// `ratchet` must never be added here: it punishes the first wrong digit
/// instantly, which is the exact opposite of `silence`.
const List<String> kSudokuModifierPool = [
  'clueThinning',
  'eclipse',
  'timer',
  'zoom',
  'glitch',
  'time_warp',
  'silence',
];

class SudokuScreen extends StatefulWidget {
  final int? dailyLevelIndex;
  const SudokuScreen({super.key, this.dailyLevelIndex});
  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  String? _forcedModifier;
  int _levelIndex = 0;
  late SudokuLevel _level;
  late List<List<int>> _board;
  int _selectedRow = -1;
  int _selectedCol = -1;
  String _message = '';
  bool _won = false;
  bool _isTutorialMode = false;
  bool _tutorialCompleted = false;
  int _actualGameLevel = 0;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  String _dailyModifierName = '';
  String _dailyModifierDesc = '';
  int _dailyGridSize = 9;
  double _dailyRadius = 1.5;
  Timer? _blackoutTimer;
  bool _isBlackout = false;
  int _blackoutCountdown = 30;
  int _correctPlacementsCount = 0;
  bool _gameOver = false;
  int _warpTimeLeft = 90;
  Timer? _warpTimer;
  bool _isPanMode = false;

  bool _inRecallTest = false;
  bool _shuffleActive = false;
  bool _isScanPhase = true;
  int _recallTargetCount = 2;
  int _recallPlacedCount = 0;
  final Set<(int, int)> _recallCorrectSelections = {};
  final Set<(int, int)> _lockedRecallCells = {};

  Set<String> _activeModifiers = {};

  // COGNIQ-FIX:mod-active-helper
  bool _isModActive(String name) {
    if (_forcedModifier == name) return true;
    if (_playDailyMode) return _dailyModifierType == name;
    return _levelIndex >= RotationEngine.modifierStartLevel('sudoku') &&
        _activeModifiers.contains(name);
  }

  // COGNIQ-FIX:mod-getters
  bool get _isEclipseActive => _isModActive('eclipse');
  bool get _isEndgame => _isModActive('timer');
  bool get _silent => _isModActive('silence');
  bool get _isGlitchActive => _isModActive('glitch');
  bool get _isZoomActive => _isModActive('zoom');
  bool get _isTimeWarpActive => _isModActive('time_warp');
  bool get _isClueThinningActive => _isModActive('clueThinning');
  int _submitAttempts = 3;
  Timer? _gameTimer;
  int _timeLeft = -1;
  // Timer value at the moment the hard timer started; 0 when no timer ran.
  // Only used for the Speed Demon achievement check on clear.
  int _initialTime = 0;
  bool _timeBonusEarned = false;

  /// Modifiers now begin at a per-game level chosen in RotationEngine
  /// rather than a flat level 30 for every game.
  bool get _modsOn => !_playDailyMode && RotationEngine.hasModifiers('sudoku', _levelIndex);

  @override
  void initState() {
    super.initState();
    // Default synchronous initialization to avoid LateInitializationError
    _level = _getSudokuLevel(0);
    _board = List.generate(_level.size, (r) => List.from(_level.startBoard[r]));
    _initLevel();
  }

  /// Held in state rather than rebuilt inside build(): a fresh controller
  /// on every frame leaked one per rebuild and snapped the player's pan
  /// position back to the start each time the board changed.
  final TransformationController _zoomController =
      TransformationController(Matrix4.identity()..scale(1.4));

  @override
  void dispose() {
    _zoomController.dispose();
    _blackoutTimer?.cancel();
    _warpTimer?.cancel();
    _gameTimer?.cancel();
    super.dispose();
  }

  void _endScanPhase() {
    _blackoutTimer?.cancel();
    setState(() {
      _isScanPhase = false;
      _inRecallTest = true;
      _recallPlacedCount = 0;
      _recallCorrectSelections.clear();
      _selectedRow = -1;
      _selectedCol = -1;
      _message = 'Recall Phase! Place $_recallTargetCount numbers correctly.';
      
      // Hide all user-placed numbers that are not locked
      for (int r = 0; r < _level.size; r++) {
        for (int c = 0; c < _level.size; c++) {
          if (_level.startBoard[r][c] == 0 && !_lockedRecallCells.contains((r, c))) {
            _board[r][c] = 0;
          }
        }
      }
      AudioManager.playClick();
    });
  }

  void _startBlackoutTimer() {
    _blackoutTimer?.cancel();
    if (_isEclipseActive) {
      _isScanPhase = true;
      _inRecallTest = false;
      _blackoutCountdown = 30;
      
      _blackoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_gameOver || _won) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_isScanPhase) {
            if (_blackoutCountdown > 1) {
              _blackoutCountdown--;
            } else {
              _endScanPhase();
            }
          }
        });
      });
    }
  }

  int _hintCount = 0;

  Future<void> _initLevel() async {
    await HintManager.startLevel('sudoku');
    _hintCount = await HintManager.getHints('sudoku');
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString(PrefsKeys.dailyModifierType) ?? '';
      _dailyModifierName = prefs.getString(PrefsKeys.dailyModifierName) ?? '';
      _dailyModifierDesc = prefs.getString(PrefsKeys.dailyModifierDesc) ?? '';
      final difficulty = prefs.getString(PrefsKeys.dailyModifierDifficulty) ?? 'Medium';
      if (difficulty.toLowerCase() == 'hard') {
        _dailyGridSize = 9;
      } else {
        _dailyGridSize = 6;
      }
      final extraParamsStr = prefs.getString(PrefsKeys.dailyModifierExtraParams) ?? '';
      if (extraParamsStr.isNotEmpty) {
        try {
          final extraParams = jsonDecode(extraParamsStr) as Map<String, dynamic>;
          if (extraParams.containsKey('radius')) {
            _dailyRadius = (extraParams['radius'] as num).toDouble();
          } else {
            _dailyRadius = 1.5;
          }
        } catch (_) {
          _dailyRadius = 1.5;
        }
      } else {
        _dailyRadius = 1.5;
      }
    } else {
      _dailyModifierType = '';
      _dailyModifierName = '';
      _dailyModifierDesc = '';
      _dailyGridSize = 9;
      _dailyRadius = 1.5;
    }

    if (!_playDailyMode && !_isTutorialMode) {
      Future.delayed(Duration.zero, () async {
        if (!mounted) return;
        final savedStateStr = prefs.getString(PrefsKeys.normalGameState('sudoku'));
        if (savedStateStr != null) {
          try {
            final data = jsonDecode(savedStateStr);
            if (data['levelIndex'] == _levelIndex) {
              final continueGame = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  backgroundColor: context.bgCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: context.textMuted.withAlpha(40)),
                  ),
                  title: Text(
                    'Continue Game?',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
                  ),
                  content: Text(
                    'We found a saved state for this level. Would you like to continue playing or start a new game?',
                    style: GoogleFonts.outfit(color: context.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx, false); // New Game
                      },
                      child: Text(
                        'New Game',
                        style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx, true); // Continue
                      },
                      child: Text(
                        'Continue',
                        style: GoogleFonts.outfit(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ) ?? false;

              if (continueGame) {
                final List<dynamic> boardData = data['board'];
                final List<List<int>> loadedBoard = boardData.map((row) => List<int>.from(row)).toList();
                final List<dynamic>? startBoardData = data['startBoard'];
                final List<dynamic>? solutionData = data['solution'];
                setState(() {
                  _board = loadedBoard;
                  if (startBoardData != null && solutionData != null) {
                    final loadedStartBoard = startBoardData.map((row) => List<int>.from(row)).toList();
                    final loadedSolution = solutionData.map((row) => List<int>.from(row)).toList();
                    _level = SudokuLevel(
                      size: _level.size,
                      startBoard: loadedStartBoard,
                      solution: loadedSolution,
                    );
                  }
                  _correctPlacementsCount = data['correctPlacementsCount'] ?? 0;
                });
              } else {
                await _clearNormalState();
              }
            } else {
              await _clearNormalState();
            }
          } catch (_) {
            await _clearNormalState();
          }
        }
      });
    }

    if (widget.dailyLevelIndex != null) {
      if (mounted) {
        setState(() {
          _levelIndex = widget.dailyLevelIndex!;
          _loadLevel();
        });
      }
      return;
    }
    final savedLevel = prefs.getInt(PrefsKeys.gameLevel('sudoku')) ?? 0;
    final active = await ShuffleManager.isActive();

    _isTutorialMode = false;
    _levelIndex = savedLevel;
 
    if (mounted) {
      setState(() {
        _shuffleActive = active;
        _loadLevel();
      });
    }
  }



  Future<void> _saveNormalState() async {
    if (_playDailyMode || _won) return;
    final prefs = await SharedPreferences.getInstance();
    final state = {
      'board': _board,
      'levelIndex': _levelIndex,
      'startBoard': _level.startBoard,
      'solution': _level.solution,
      'correctPlacementsCount': _correctPlacementsCount,
    };
    await prefs.setString(PrefsKeys.normalGameState('sudoku'), jsonEncode(state));
  }

  Future<void> _clearNormalState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PrefsKeys.normalGameState('sudoku'));
  }

  Future<void> _savePersistedLevel(int lvl) async {
    _gameTimer?.cancel();
    if (_timeLeft > 0 && _timeBonusEarned) {
      await PointManager.addPoints(5);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Speed Bonus! Earned +5 Points!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
            backgroundColor: Colors.amber,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    // A daily challenge borrows the game's level slot, so saving here would leak
    // the challenge's level into real progress. Registering the clear would also
    // double-pay: the daily grants its own reward, and HintManager.onLevelCleared
    // adds points, the global clear count, achievements and trail milestones on
    // top. Same guard as star_battle_screen.dart.
    // `widget.dailyLevelIndex` alone never fired — nothing in lib/ ever passes it,
    // so a daily run (which is flagged by the play_daily_mode pref) got through.
    if (_playDailyMode || widget.dailyLevelIndex != null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PrefsKeys.gameLevel('sudoku'), lvl);
    final earned = await HintManager.onLevelCleared(
      'sudoku',
      // Speed Demon: cleared a hard-timer level with more than half the
      // clock still left. _initialTime is 0 unless the timer modifier ran.
      isSpeedDemon: _initialTime > 0 && _timeLeft * 2 > _initialTime,
    );
    if (earned) {
      final newCount = await HintManager.getHints('sudoku');
      if (mounted) {
        setState(() {
          _hintCount = newCount;
        });
      }
    }
  }

  bool _isValidSudokuPlace(List<List<int>> board, int size, int r, int c, int val) {
    for (int col = 0; col < size; col++) {
      if (board[r][col] == val) return false;
    }
    for (int row = 0; row < size; row++) {
      if (board[row][c] == val) return false;
    }
    int boxRows, boxCols;
    if (size == 4) {
      boxRows = 2; boxCols = 2;
    } else if (size == 6) {
      boxRows = 2; boxCols = 3;
    } else {
      boxRows = 3; boxCols = 3;
    }
    int boxStartRow = (r ~/ boxRows) * boxRows;
    int boxStartCol = (c ~/ boxCols) * boxCols;
    for (int i = 0; i < boxRows; i++) {
      for (int j = 0; j < boxCols; j++) {
        if (board[boxStartRow + i][boxStartCol + j] == val) return false;
      }
    }
    return true;
  }

  bool _hasUniqueSolution(List<List<int>> board, int size) {
    int solutionCount = 0;
    bool solve(int row, int col) {
      if (row == size) {
        solutionCount++;
        return solutionCount > 1;
      }
      int nextRow = col == size - 1 ? row + 1 : row;
      int nextCol = col == size - 1 ? 0 : col + 1;
      if (board[row][col] != 0) {
        return solve(nextRow, nextCol);
      }
      for (int val = 1; val <= size; val++) {
        if (_isValidSudokuPlace(board, size, row, col, val)) {
          board[row][col] = val;
          if (solve(nextRow, nextCol)) {
            board[row][col] = 0;
            return true;
          }
          board[row][col] = 0;
        }
      }
      return false;
    }
    solve(0, 0);
    return solutionCount == 1;
  }

  SudokuLevel _getSudokuLevel(int index) {
    final List<SudokuLevel> levels4 = kSudokuLevels.where((l) => l.size == 4).toList();
    final List<SudokuLevel> levels6 = kSudokuLevels.where((l) => l.size == 6).toList();
    final List<SudokuLevel> levels9 = kSudokuLevels.where((l) => l.size == 9).toList();

    SudokuLevel baseLevel;
    if (_playDailyMode) {
      if (_dailyGridSize == 6) {
        baseLevel = levels6[index % levels6.length];
      } else if (_dailyGridSize == 4) {
        baseLevel = levels4[index % levels4.length];
      } else {
        baseLevel = levels9[index % levels9.length];
      }
    } else {
      if (index < 10) {
        baseLevel = levels4[index % levels4.length];
      } else if (index < 25) {
        baseLevel = levels6[(index - 10) % levels6.length];
      } else {
        baseLevel = levels9[(index - 25) % levels9.length];
      }
    }

    final size = baseLevel.size;
    final rng = _playDailyMode
        ? Random(index * 997)
        : RotationEngine.getDeterminism('sudoku', index);
    final digits = List.generate(size, (i) => i + 1)..shuffle(rng);
    final mapping = <int, int>{};
    for (int i = 0; i < size; i++) {
      mapping[i + 1] = digits[i];
    }
    mapping[0] = 0;
    // Transposing is only safe when the box shape is square. A 6x6 uses 2x3
    // boxes, so a transposed grid is valid for 3x2 boxes while the validator,
    // hint solver and win check all still use 2x3 -- which made the stored
    // solution unreachable and the level unwinnable.
    final transpose = size == 6 ? false : rng.nextBool();
    final startBoard = List.generate(size, (r) => List.filled(size, 0));
    final solutionList = List.generate(size, (r) => List.filled(size, 0));
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final baseStart = baseLevel.startBoard[r][c];
        final baseSol = baseLevel.solution[r][c];
        final mappedStart = mapping[baseStart]!;
        final mappedSol = mapping[baseSol]!;
        if (transpose) {
          startBoard[c][r] = mappedStart;
          solutionList[c][r] = mappedSol;
        } else {
          startBoard[r][c] = mappedStart;
          solutionList[r][c] = mappedSol;
        }
      }
    }

    // Now dynamically reduce pre-filled cells based on the level index to increase difficulty
    final List<int> filledCells = [];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (startBoard[r][c] != 0) {
          filledCells.add(r * size + c);
        }
      }
    }

    int targetFilled;
    if (_playDailyMode && _dailyModifierType == 'minimal') {
      if (size == 4) {
        targetFilled = 4;
      } else if (size == 6) {
        targetFilled = 10;
      } else {
        targetFilled = 17;
      }
    } else if (!_playDailyMode && index >= 30) { // not-a-modifier-gate
      if (size == 4) {
        targetFilled = 5;
      } else if (size == 6) {
        targetFilled = max(11, 14 - ((index - 30) ~/ 4));
      } else {
        // COGNIQ-FIX:curve-regression
        // Was `max(17, 25 - ((index - 45) ~/ 3))`. For levels 30-44 the dividend
        // is negative and Dart's `~/` truncates toward zero, so `(30-45) ~/ 3`
        // is -5 and level 30 handed out THIRTY clues -- five MORE than level 29
        // -- not recovering to 25 until level 43. Anchoring the ramp at 30
        // instead of 45 keeps the dividend non-negative, so the count can only
        // fall. 25 at level 30 matches what level 29 gives (see the `index < 40`
        // arm below), one clue is removed every 5 levels, and the floor of 17 --
        // the minimum a 9x9 needs for a unique solution -- is reached at level
        // 70. The old `index >= 90 -> 17` special case is folded in: from level
        // 70 the raw value is already at or below the floor, so `max` pins it
        // there for every level above, which is exactly what that branch did.
        targetFilled = max(17, 25 - ((index - 30) ~/ 5));
      }
      // COGNIQ-FIX:mod-getters
      if (_isClueThinningActive) {
        targetFilled = max(4, targetFilled - (size == 4 ? 1 : size == 6 ? 2 : 3));
      }
    } else if (size == 9) {
      if (index < 40) {
        targetFilled = 25; // levels 26-40
      } else if (index < 60) {
        targetFilled = 21; // levels 41-60
      } else {
        targetFilled = 17; // levels 61+
      }
    } else if (size == 6) {
      // levels 11-25, scale from 18 down to 14
      targetFilled = 18 - ((index - 10) * 4 ~/ 15);
    } else {
      // levels 1-10, scale from 8 down to 5
      targetFilled = 8 - (index * 3 ~/ 10);
    }

    if (filledCells.length > targetFilled) {
      filledCells.shuffle(rng);
      int removedCount = 0;
      final int targetToRemove = filledCells.length - targetFilled;
      for (int i = 0; i < filledCells.length; i++) {
        if (removedCount >= targetToRemove) break;
        final idxVal = filledCells[i];
        final r = idxVal ~/ size;
        final c = idxVal % size;
        final temp = startBoard[r][c];
        startBoard[r][c] = 0;
        final copy = List.generate(size, (row) => List<int>.from(startBoard[row]));
        if (_hasUniqueSolution(copy, size)) {
          removedCount++;
        } else {
          startBoard[r][c] = temp;
        }
      }
    }

    return SudokuLevel(
      size: size,
      startBoard: startBoard,
      solution: solutionList,
    );
  }

  // COGNIQ-FIX:mod-desc-copy
  String _getModifierDescription(String mod) {
    switch (mod) {
      case 'clueThinning':
        return 'Fewer starting numbers provided across the grid.';
      case 'eclipse':
        return 'Periodic eclipse tests your recall of placed numbers.';
      case 'timer':
        return 'Solve the entire puzzle before time runs out.';
      case 'zoom':
        return 'The grid is magnified with pan-and-scan enabled.';
      case 'glitch':
        return 'Rows subtly shift positions periodically.';
      case 'time_warp':
        return '+5s gained for correct placements, -10s lost on mistakes.';
      case 'silence':
        return 'No error feedback until you submit the completed board (3 tries).';
      default:
        return '';
    }
  }

  String get _modifierBannerText {
    if (_isTutorialMode) return '';
    if (_playDailyMode) {
      if (_dailyModifierDesc.isNotEmpty) return _dailyModifierDesc;
      if (_dailyModifierName.isNotEmpty) return _dailyModifierName;
      return '';
    }
    return _activeModifiers
        .map(_getModifierDescription)
        .where((d) => d.isNotEmpty)
        .join(' · ');
  }

  void _loadLevel() {
    if (_modsOn) {
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'sudoku',
        levelIndex: _levelIndex,
        pool: kSudokuModifierPool,
        minActive: 2,
        maxActive: 4,
      );
    } else {
      _activeModifiers = {};
    }
    if (_forcedModifier != null) {
      _activeModifiers = {_forcedModifier!};
    }
    // `silence` defers every judgement to Submit, so it cannot share a level
    // with a modifier that reports correctness on each placement -- `eclipse`
    // fails the level the instant a recalled cell is wrong, and `time_warp`
    // announces "+5s"/"-10s" per digit. RotationEngine enumerates every pair,
    // so keeping them out of the pool cannot keep them apart; drop the partner
    // here instead, and let the caption show only what actually ran.
    // COGNIQ-FIX:mod-getters
    if (_silent) {
      _activeModifiers.remove('eclipse');
      _activeModifiers.remove('time_warp');
    }
    _submitAttempts = 3;
    _level = _getSudokuLevel(_levelIndex);
    _board = List.generate(_level.size, (r) => List.from(_level.startBoard[r]));
    _selectedRow = -1;
    _selectedCol = -1;
    _message = '';
    _won = false;
    _correctPlacementsCount = 0;

    _warpTimer?.cancel();
    _blackoutTimer?.cancel();
    _gameOver = false;
    _isBlackout = false;
    _inRecallTest = false;
    _isScanPhase = true;
    _recallTargetCount = 2;
    _recallPlacedCount = 0;
    _recallCorrectSelections.clear();
    _lockedRecallCells.clear();
    
    // COGNIQ-FIX:mod-getters
    // Hand-rolled copy of the getter, which is exactly what the getter exists to
    // stop: `_activeModifiers` is only ever populated when `_modsOn`, so the two
    // read identically.
    if (_isTimeWarpActive) {
      _warpTimeLeft = 90;
      _warpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _won || _gameOver) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_warpTimeLeft > 0) {
            _warpTimeLeft--;
          } else {
            _gameOver = true;
            _message = 'Time is up!';
            AudioManager.playFail();
          }
        });
      });
    }
    if (_isEclipseActive) {
      _startBlackoutTimer();
    }
    if (!_playDailyMode) {
      _gameTimer?.cancel();
      _timeLeft = -1;
      _timeBonusEarned = false;
      // COGNIQ-FIX:mod-getters
      // `_isEndgame` IS `_isModActive('timer')`; the extra `contains` was a
      // second, weaker copy of the same test.
      if (_isEndgame) {
        _timeLeft = _level.size == 4 ? 60 : (_level.size == 6 ? 120 : 240);
        _initialTime = _timeLeft;
        _timeBonusEarned = true;
        _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted || _won || _gameOver) {
            timer.cancel();
            return;
          }
          if (_isEclipseActive && _isScanPhase) {
            return;
          }
          setState(() {
            if (_timeLeft > 0) {
              _timeLeft--;
            } else {
              _timeLeft = 0;
              _timeBonusEarned = false;
              _gameTimer?.cancel();
              AudioManager.playFail();
              setState(() {
                _gameOver = true;
              });
            }
          });
        });
      }
    }
  }

  void _showJumpToLevelDialog() {
    showDialog(
      context: context,
      builder: (context) {
        int target = _levelIndex + 1;
        String? selectedMod = _forcedModifier;
        const pool = kSudokuModifierPool;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.bgCard,
              title: Text('Jump to Level', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(color: context.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Level Number (1+)',
                        labelStyle: GoogleFonts.outfit(color: context.textSecondary),
                      ),
                      onChanged: (val) {
                        target = int.tryParse(val) ?? target;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedMod,
                      dropdownColor: context.bgCard,
                      style: GoogleFonts.outfit(color: context.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Force Modifier',
                        labelStyle: GoogleFonts.outfit(color: context.textSecondary),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None (Default)')),
                        ...pool.map((m) => DropdownMenuItem(value: m, child: Text(m))),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          selectedMod = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.outfit(color: context.textSecondary)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (target > 0) {
                      setState(() {
                        _levelIndex = target - 1;
                        _forcedModifier = selectedMod;
                        _loadLevel();
                      });
                    }
                  },
                  child: Text('Jump', style: GoogleFonts.outfit(color: AppTheme.accentFor('sudoku'))),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _reset() => setState(() => _loadLevel());

  bool _isOriginal(int r, int c) {
    return _level.startBoard[r][c] != 0 || _lockedRecallCells.contains((r, c));
  }

  void _selectCell(int r, int c) {
    if (_won || _gameOver) return;
    if (_isEclipseActive && _isScanPhase) return;
    if (_isOriginal(r, c)) return;
    if (_inRecallTest && _recallCorrectSelections.contains((r, c))) return;
    setState(() {
      _selectedRow = r;
      _selectedCol = c;
      _message = '';
      AudioManager.playClick();
    });
  }

  void _inputNumber(int num) {
    if (_won || _gameOver || _selectedRow == -1 || _selectedCol == -1) return;
    if (_isEclipseActive && _isScanPhase) return;
    final prevVal = _board[_selectedRow][_selectedCol];
    final targetVal = _level.solution[_selectedRow][_selectedCol];

    if (_isEclipseActive && _inRecallTest) {
      if (num == targetVal) {
        setState(() {
          _board[_selectedRow][_selectedCol] = num;
          _recallCorrectSelections.add((_selectedRow, _selectedCol));
          _recallPlacedCount++;
          _selectedRow = -1;
          _selectedCol = -1;
          _message = 'Correct placement! ($_recallPlacedCount/$_recallTargetCount)';
          AudioManager.playClick();

          if (_recallPlacedCount >= _recallTargetCount) {
            for (final cell in _recallCorrectSelections) {
              _lockedRecallCells.add(cell);
            }
            
            bool fullySolved = true;
            for (int r = 0; r < _level.size; r++) {
              for (int c = 0; c < _level.size; c++) {
                if (_board[r][c] != _level.solution[r][c]) {
                  fullySolved = false;
                  break;
                }
              }
            }

            if (fullySolved) {
              _won = true;
              _selectedRow = -1;
              _selectedCol = -1;
              _message = 'Correct! Sudoku Solved!';
              AudioManager.playSuccess();
              _savePersistedLevel(_levelIndex + 1);
              _clearNormalState();
            } else {
              _isScanPhase = true;
              _inRecallTest = false;
              _recallTargetCount++;
              _blackoutCountdown = 30;
              _message = 'Recall success! Placed cells locked. Scan again!';
              AudioManager.playSuccess();
            }
          }
        });
      } else {
        setState(() {
          _board[_selectedRow][_selectedCol] = num;
          _gameOver = true;
          _message = 'Incorrect placement! Recall failed.';
          AudioManager.playFail();
        });
      }
      return;
    }

    setState(() {
      _board[_selectedRow][_selectedCol] = num;
      _message = '';
      AudioManager.playClick();
    });
    
    // COGNIQ-FIX:mod-getters
    if (_isTimeWarpActive) {
      if (num == targetVal) {
        _warpTimeLeft = (_warpTimeLeft + 5).clamp(0, 300);
        _message = '+5 Seconds!';
      } else {
        _warpTimeLeft = (_warpTimeLeft - 10).clamp(0, 300);
        _message = '-10 Seconds!';
        if (_warpTimeLeft <= 0) {
          _gameOver = true;
          _message = 'Time is up!';
          AudioManager.playFail();
        }
      }
    }
    
    // COGNIQ-FIX:mod-getters
    if (_isGlitchActive) {
      // Under `silence` the swap must not double as a correctness tell, so it
      // counts placements rather than correct placements. The board still
      // shuffles just as often.
      final bool countsTowardsSwap =
          prevVal != num && (_silent || num == targetVal);
      if (countsTowardsSwap) {
        _correctPlacementsCount++;
        if (_correctPlacementsCount >= 3) {
          _correctPlacementsCount = 0;
          _glitchRowSwap();
        }
      }
    }
    _saveNormalState();
    _tryAutoCheck();
  }

  void _tryAutoCheck() {
    if (_won || _gameOver) return;
    // `silence`: filling the last cell must not reveal anything. The board is
    // only judged when the player presses Submit.
    if (_silent) return;
    final size = _level.size;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (_board[r][c] == 0) return;
      }
    }
    _checkBoard();
  }

  void _clearCell() {
    if (_won || _gameOver || _selectedRow == -1 || _selectedCol == -1) return;
    if (_inRecallTest) return;
    setState(() {
      _board[_selectedRow][_selectedCol] = 0;
      _message = '';
      AudioManager.playClick();
    });
    _saveNormalState();
  }

  /// `silence`'s only judgement. Reports how many cells are wrong and never
  /// which, spends one of three attempts, and loses the level when they run
  /// out.
  void _onSubmitSilent() {
    if (_won || _gameOver || _submitAttempts <= 0) return;
    final size = _level.size;
    int wrong = 0;
    int blank = 0;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final v = _board[r][c];
        if (v == 0) {
          blank++;
        } else if (v != _level.solution[r][c]) {
          wrong++;
        }
      }
    }

    if (wrong == 0 && blank == 0) {
      _checkBoard();
      return;
    }

    setState(() {
      _submitAttempts--;
      _message = wrong == 0
          ? 'No errors — but the board is not complete'
          : '$wrong cell${wrong == 1 ? '' : 's'} wrong';
      AudioManager.playFail();
    });

    if (_submitAttempts <= 0) {
      setState(() {
        _gameOver = true;
        _message = 'Out of submissions.';
      });
    }
  }

  void _checkBoard() {
    if (_won || _gameOver) return;
    bool correct = true;
    final size = _level.size;
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        if (_board[r][c] != _level.solution[r][c]) {
          correct = false;
          break;
        }
      }
    }
    if (correct) {
      if (_isTutorialMode) {
        setState(() {
          _tutorialCompleted = true;
          _selectedRow = -1;
          _selectedCol = -1;
          _message = 'Correct! Tutorial complete.';
          AudioManager.playSuccess();
        });
      } else {
        setState(() {
          _won = true;
          _selectedRow = -1;
          _selectedCol = -1;
          _message = 'Correct! Sudoku Solved!';
          AudioManager.playSuccess();
          _savePersistedLevel(_levelIndex + 1);
        });
        _clearNormalState();
      }
    } else {
      setState(() {
        _message = 'Some numbers are incorrect or missing!';
        AudioManager.playFail();
      });
    }
  }

  void _nextLevel() async {
    if (!_won) return;
    if (widget.dailyLevelIndex != null) {
      Navigator.pop(context, true);
      return;
    }
    if (await ShuffleManager.tryShuffleNavigate(context, 'sudoku')) return;
 
    setState(() {
      _levelIndex = _levelIndex + 1;
      _loadLevel();
    });
  }

  Future<void> _useSudokuHint() async {
    if (_hintCount <= 0 || _won) return;
    if (_selectedRow == -1 || _selectedCol == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Select an empty cell first to get a hint!',
            style: GoogleFonts.outfit(),
          ),
        ),
      );
      return;
    }
    if (_isOriginal(_selectedRow, _selectedCol)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This cell is already part of the original board!',
            style: GoogleFonts.outfit(),
          ),
        ),
      );
      return;
    }
    if (_board[_selectedRow][_selectedCol] ==
        _level.solution[_selectedRow][_selectedCol]) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This cell is already correct!',
            style: GoogleFonts.outfit(),
          ),
        ),
      );
      return;
    }

    await HintManager.useHint('sudoku');
    final newCount = await HintManager.getHints('sudoku');
    if (mounted) {
      setState(() {
        _hintCount = newCount;
        _board[_selectedRow][_selectedCol] =
            _level.solution[_selectedRow][_selectedCol];
        _message = 'Revealed correct number!';
      });
    }
    _checkBoard();
    if (!_won) {
      _saveNormalState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AppTheme.accentFor('sudoku');
    final size = _level.size;
    final boardScale = size == 9
        ? 300.0
        : size == 6
        ? 280.0
        : 260.0;

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: const GameTitle('Sudoku'),
        centerTitle: true,
        actions: [
          if (_shuffleActive && !_isTutorialMode)
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              tooltip: 'Skip Game',
              onPressed: () => ShuffleManager.tryShuffleNavigate(context, 'sudoku'),
            ),
          IconButton(
            tooltip: 'Hint',
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  size: 20,
                  color: Colors.amber,
                ),
                Text(
                  _hintCount == 0 ? '+' : '$_hintCount',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            onPressed: !_won && !_isTutorialMode
                ? () async {
                    if (_hintCount > 0) {
                      _useSudokuHint();
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'sudoku',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('sudoku');
                          if (mounted) setState(() => _hintCount = newCount);
                        },
                      );
                    }
                  }
                : null,
          ),
          if (MediaQuery.of(context).size.width < 360)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: context.textMuted),
              onSelected: (val) {
                if (val == 'help') {
                  RulesHelper.showRulesBottomSheet(context, 'sudoku', 'Sudoku');
                } else if (val == 'reset') {
                  _reset();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'help',
                  child: Row(
                    children: [
                      Icon(Icons.help_outline, size: 20),
                      SizedBox(width: 8),
                      Text('Rules'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 20),
                      SizedBox(width: 8),
                      Text('Reset'),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            IconButton(
              tooltip: 'Rules',
              icon: const Icon(Icons.help_outline, size: 20),
              color: context.textMuted,
              onPressed: () => RulesHelper.showRulesBottomSheet(context, 'sudoku', 'Sudoku'),
            ),
            IconButton(
              tooltip: 'Restart',
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _reset,
              color: context.textMuted,
            ),
          ],
          if (_timeLeft >= 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Row(
                  children: [
                    Icon(
                      Icons.timer,
                      color: _timeLeft <= 15 ? Colors.red : Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_timeLeft s',
                      style: GoogleFonts.spaceGrotesk(
                        color: _timeLeft <= 15 ? Colors.red : Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          GameLevelChip(
            level: _levelIndex + 1,
            modeLabel: _isTutorialMode ? 'Tutorial' : (_playDailyMode ? 'Daily' : null),
            accent: AppTheme.accentFor('sudoku'),
            onTap: kDebugMode ? _showJumpToLevelDialog : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 10,
              ),
              child: Column(
                children: [
                  Text(
                    'Fill the ${size}x${size} grid so every row, column and subgrid contains unique numbers from 1 to $size',
                    style: GoogleFonts.outfit(
                      color: context.textSecondary,
                      fontSize: context.scale(13),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_playDailyMode && _dailyModifierType == 'time_warp') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.hourglass_bottom, color: Colors.orange, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Time Left: $_warpTimeLeft s',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: context.scale(18),
                            fontWeight: FontWeight.bold,
                            color: _warpTimeLeft <= 15 ? Colors.redAccent : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_isEclipseActive) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isScanPhase ? Icons.timer : Icons.memory,
                          color: _isScanPhase ? Colors.amber : Colors.redAccent,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        // COGNIQ-FIX:curve-regression
                        // Unflexed, this Row overflowed by 264px the moment the
                        // rotation put `eclipse` on a level without `silence` to
                        // strip it -- the caption is a full sentence with two
                        // interpolated counts in it and nothing was allowed to
                        // wrap. Flexible lets it take a second line instead.
                        Flexible(
                          child: Text(
                            _isScanPhase
                                ? 'SCAN PHASE: Memorize $_recallTargetCount cells! $_blackoutCountdown s'
                                : 'RECALL PHASE: Place $_recallTargetCount numbers! ($_recallPlacedCount/$_recallTargetCount)',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: context.scale(16),
                              fontWeight: FontWeight.bold,
                              color: _isScanPhase ? Colors.amber : Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isScanPhase) ...[
                      const SizedBox(height: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: _endScanPhase,
                        child: Text(
                          'I\'m Ready',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                  if (_modifierBannerText.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        _modifierBannerText,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: accentColor.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                  // Sudoku Board Display
                  if (_isZoomActive) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: Text('Input Mode', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                          selected: !_isPanMode,
                          onSelected: (val) => setState(() => _isPanMode = !val),
                          selectedColor: accentColor.withAlpha(40),
                          checkmarkColor: accentColor,
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: Text('Pan Mode', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                          selected: _isPanMode,
                          onSelected: (val) => setState(() => _isPanMode = val),
                          selectedColor: accentColor.withAlpha(40),
                          checkmarkColor: accentColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  Center(
                    child: Builder(
                      builder: (context) {
                        Widget boardWidget = Container(
                          width: context.scale(boardScale),
                          height: context.scale(boardScale),
                          decoration: BoxDecoration(
                            color: context.bgCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: context.textMuted, width: 2),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: FogOverlay(
                                  enabled: _playDailyMode && _dailyModifierType == 'fog',
                                  radius: (context.scale(boardScale) / size) * _dailyRadius,
                                  focalPoint: (_selectedRow != -1 && _selectedCol != -1)
                                      ? Offset(
                                          (_selectedCol + 0.5) * (context.scale(boardScale) / size),
                                          (_selectedRow + 0.5) * (context.scale(boardScale) / size),
                                        )
                                      : null,
                                  child: GridView.builder(
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: size * size,
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: size,
                                    ),
                                    itemBuilder: (ctx, idx) {
                                      final r = idx ~/ size;
                                      final c = idx % size;
                                      final value = _board[r][c];
                                      final isOrig = _isOriginal(r, c);
                                      final isSel = r == _selectedRow && c == _selectedCol;

                                      BorderSide borderRight;
                                      BorderSide borderBottom;

                                      if (size == 4) {
                                        borderRight = (c == 1)
                                            ? BorderSide(color: context.textMuted, width: 2)
                                            : BorderSide(
                                                color: context.textMuted.withAlpha(40),
                                                width: 0.5,
                                              );
                                        borderBottom = (r == 1)
                                            ? BorderSide(color: context.textMuted, width: 2)
                                            : BorderSide(
                                                color: context.textMuted.withAlpha(40),
                                                width: 0.5,
                                              );
                                      } else if (size == 6) {
                                        borderRight = (c == 2)
                                            ? BorderSide(color: context.textMuted, width: 2)
                                            : BorderSide(
                                                color: context.textMuted.withAlpha(40),
                                                width: 0.5,
                                              );
                                        borderBottom = (r == 1 || r == 3)
                                            ? BorderSide(color: context.textMuted, width: 2)
                                            : BorderSide(
                                                color: context.textMuted.withAlpha(40),
                                                width: 0.5,
                                              );
                                      } else {
                                        borderRight = (c == 2 || c == 5)
                                            ? BorderSide(color: context.textMuted, width: 2)
                                            : BorderSide(
                                                color: context.textMuted.withAlpha(40),
                                                width: 0.5,
                                              );
                                        borderBottom = (r == 2 || r == 5)
                                            ? BorderSide(color: context.textMuted, width: 2)
                                            : BorderSide(
                                                color: context.textMuted.withAlpha(40),
                                                width: 0.5,
                                              );
                                      }

                                      final cellLabel =
                                          'Cell Row ${r + 1}, Column ${c + 1}, value ${value == 0 ? 'empty' : value}';

                                      return Semantics(
                                        label: cellLabel,
                                        selected: isSel,
                                        button: true,
                                        child: GestureDetector(
                                          onTap: _isPanMode ? null : () => _selectCell(r, c),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isSel
                                                  ? accentColor.withAlpha(45)
                                                  : (_inRecallTest
                                                      ? context.bgCard
                                                      : (isOrig
                                                          ? context.bgSurface
                                                          : context.bgCard)),
                                              border: Border(
                                                right: borderRight,
                                                bottom: borderBottom,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                _inRecallTest
                                                    ? (_recallCorrectSelections.contains((r, c)) ? '$value' : '')
                                                    : (value != 0 ? '$value' : ''),
                                                style: AppTheme.numberStyle(
                                                  fontSize: context.scale(
                                                    size == 9 ? 15 : 18,
                                                  ),
                                                  fontWeight: isOrig
                                                      ? FontWeight.w900
                                                      : FontWeight.w600,
                                                  color: isOrig
                                                      ? context.textPrimary
                                                      : accentColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );

                        // COGNIQ-FIX:mod-getters
                        if (_isZoomActive) {
                          boardWidget = SizedBox(
                            width: context.scale(boardScale),
                            height: context.scale(boardScale),
                            child: InteractiveViewer(
                              panEnabled: _isPanMode,
                              scaleEnabled: false,
                              minScale: 1.4,
                              maxScale: 1.4,
                              transformationController: _zoomController,
                              child: boardWidget,
                            ),
                          );
                        }
                        return boardWidget;
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_message.isNotEmpty)
                    Text(
                      _message,
                      style: GoogleFonts.outfit(
                        color: _won ? accentColor : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: context.scale(14),
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Number Pad (1 to size)
                  if (!_won && !_tutorialCompleted) ...[
                    if (!(_isEclipseActive && _isScanPhase)) ...[
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: List.generate(size, (i) => i + 1).map((n) {
                          return SizedBox(
                            width: context.scale(size == 9 ? 42 : 50),
                            height: context.scale(size == 9 ? 42 : 50),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.bgSurface,
                                foregroundColor: context.textPrimary,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: (_selectedRow != -1)
                                        ? accentColor
                                        : context.textMuted.withAlpha(50),
                                    width: 1.5,
                                  ),
                                ),
                                elevation: 0,
                              ),
                              onPressed: (_selectedRow != -1)
                                  ? () => _inputNumber(n)
                                  : null,
                              child: Text(
                                '$n',
                                style: AppTheme.numberStyle(
                                  fontSize: context.scale(16),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (_silent) ...[
                      Center(
                        child: FilledButton.tonal(
                          onPressed: _onSubmitSilent,
                          style: FilledButton.styleFrom(
                            backgroundColor: accentColor.withValues(alpha: 0.18),
                            foregroundColor: accentColor,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: Text(
                            'Submit  ·  $_submitAttempts left',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: context.scale(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (!_isEclipseActive)
                      Center(
                        child: TextButton(
                          onPressed: (_selectedRow != -1) ? _clearCell : null,
                          child: Text(
                            'CLEAR',
                            style: GoogleFonts.outfit(
                              color: context.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: context.scale(14),
                            ),
                          ),
                        ),
                      ),
                  ] else ...[
                    const SizedBox(height: 16),
                    if (!_playDailyMode && !_isTutorialMode)
                      AutoNextCountdown(
                        onNext: _nextLevel,
                        accentColor: accentColor,
                      ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
      if (_gameOver && !_won)
        LossOverlay(
          onTryAgain: _reset,
          subtitle: _silent && _submitAttempts <= 0
              ? 'Three submissions, still wrong.'
              : (_playDailyMode
                  ? 'Daily Challenge failed.'
                  : 'Failed on level ${_levelIndex + 1}.'),
          accentColor: accentColor,
        ),
      if (_won && _playDailyMode)
        ChallengeClearedOverlay(
          accentColor: accentColor,
          onComplete: () {
            Navigator.pop(context, true);
          },
        ),
      // if (_isTutorialMode)
      //   InteractiveTutorialOverlay(
      //     instruction: _tutorialCompleted
      //       ? "Nice! You successfully completed the Sudoku puzzle."
      //       : "Fill the grid so that every row, column, and subgrid contains the numbers 1 to 4/6/9 without repetition!",
      //     isCompleted: _tutorialCompleted,
      //     onSkip: _finishTutorial,
      //     onStartGame: _finishTutorial,
      //   ),
    ],
  ),
);
  }

  void _glitchRowSwap() {
    final size = _level.size;
    final rng = Random();
    
    int bandSize = 3; 
    if (size == 4) bandSize = 2;
    if (size == 6) bandSize = 2; 
    
    final numBands = size ~/ bandSize;
    final bandIdx = rng.nextInt(numBands);
    
    final startRow = bandIdx * bandSize;
    final r1 = startRow + rng.nextInt(bandSize);
    int r2 = startRow + rng.nextInt(bandSize);
    while (r2 == r1) {
      r2 = startRow + rng.nextInt(bandSize);
    }
    
    final tempBoardRow = List<int>.from(_board[r1]);
    _board[r1] = List<int>.from(_board[r2]);
    _board[r2] = tempBoardRow;

    final tempStartRow = List<int>.from(_level.startBoard[r1]);
    _level.startBoard[r1] = List<int>.from(_level.startBoard[r2]);
    _level.startBoard[r2] = tempStartRow;

    final tempSolRow = List<int>.from(_level.solution[r1]);
    _level.solution[r1] = List<int>.from(_level.solution[r2]);
    _level.solution[r2] = tempSolRow;
    
    setState(() {
      _message = 'Glitch! Rows $r1 and $r2 swapped!';
    });
    
    AudioManager.playFail(); 
  }
}
