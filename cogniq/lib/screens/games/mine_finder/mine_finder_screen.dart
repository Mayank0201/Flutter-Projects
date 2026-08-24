import 'dart:math';
import 'dart:async';
import 'dart:convert';
import '../../../utils/rotation_engine.dart';
import '../../../utils/point_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../widgets/game_level_chip.dart';
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
import '../../../utils/shuffle_manager.dart';

/// The free-play modifier pool. Mirrored by `pools['mines']` in
/// test/difficulty_curve_test.dart — keep the two in step.
///
/// `ratchet` must never be added here: it punishes a mistake the instant it is
/// made, which is the exact opposite of `silence`.
const List<String> kMineFinderModifierPool = [
  'limitedFlags',
  'hiddenCount',
  'timer',
  'fog',
  'silence',
];

class MineFinderScreen extends StatefulWidget {
  final int? dailyLevelIndex;
  const MineFinderScreen({super.key, this.dailyLevelIndex});

  @override
  State<MineFinderScreen> createState() => _MineFinderScreenState();
}

class _MineFinderScreenState extends State<MineFinderScreen> {
  String? _forcedModifier;
  int _levelIndex = 0;
  int _gridSize = 9;
  int _mineCount = 10;
  List<List<bool>> _mines = List.generate(9, (_) => List.filled(9, false));
  List<List<bool>> _revealed = List.generate(9, (_) => List.filled(9, false));
  List<List<bool>> _flagged = List.generate(9, (_) => List.filled(9, false));

  bool _isFirstTap = true;
  bool _won = false;
  bool _lost = false;
  bool _flagMode = false; // Toggle: false = Dig, true = Flag
  bool _isTutorialMode = false;
  bool _tutorialCompleted = false;

  int _hintCount = 0;
  String _message = '';
  bool _shuffleActive = false;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  double _dailyModifierRadius = 2.0;
  String _dailyModifierName = '';
  String _dailyModifierDesc = '';

  Set<String> _activeModifiers = {};

  // COGNIQ-FIX:mod-active-helper
  bool _isModActive(String name) {
    if (_forcedModifier == name) return true;
    if (_playDailyMode) {
      if (name == 'fog') {
        return _dailyModifierType == 'fog' ||
            _dailyModifierType == 'spotlight' ||
            _dailyModifierType == 'spotlight2';
      }
      return _dailyModifierType == name;
    }
    return _levelIndex >= RotationEngine.modifierStartLevel('minesweeper') &&
        _activeModifiers.contains(name);
  }

  // COGNIQ-FIX:mod-getters
  bool get _isLimitedFlagsActive => _isModActive('limitedFlags');
  bool get _isHiddenMinesActive => _isModActive('hiddenCount');
  bool get _isFogActive => _isModActive('fog');
  bool get _isEndgame => _isModActive('timer');

  /// `silence` — digging a mine no longer detonates. The cell simply opens and
  /// shows its adjacent count like any other, the board is never judged as you
  /// play, and the only verdict comes from Submit: how many cells are wrong,
  /// never which. Three attempts, then the level is lost.
  bool get _silent => _isModActive('silence');
  int _submitAttempts = 3;

  /// Set once the level ends, so the board may finally show where the mines
  /// were. While `silence` is live this stays false and a dug mine renders as
  /// an ordinary opened cell.
  bool get _revealTruth => _won || _lost;

  /// How many of the player's committed decisions contradict the board: a mine
  /// that has been dug, or a flag on safe ground.
  int _countSilentErrors() {
    int wrong = 0;
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        if (_mines[r][c] && _revealed[r][c]) wrong++;
        if (!_mines[r][c] && _flagged[r][c]) wrong++;
      }
    }
    return wrong;
  }

  /// True when every safe cell has been opened — the game's normal win shape.
  bool _allSafeRevealed() {
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        if (!_mines[r][c] && !_revealed[r][c]) return false;
      }
    }
    return true;
  }

  void _onSubmitSilent() {
    if (_won || _lost || _submitAttempts <= 0) return;
    final wrong = _countSilentErrors();
    if (wrong == 0 && _allSafeRevealed()) {
      _finishSilentWin();
      return;
    }

    setState(() {
      _submitAttempts--;
      _message = wrong == 0
          ? 'No errors — but the field is not cleared'
          : '$wrong cell${wrong == 1 ? '' : 's'} wrong';
      AudioManager.playFail();
    });

    if (_submitAttempts <= 0) {
      setState(() {
        _lost = true;
        _message = 'Out of submissions.';
        for (int i = 0; i < _gridSize; i++) {
          for (int j = 0; j < _gridSize; j++) {
            if (_mines[i][j]) _revealed[i][j] = true;
          }
        }
      });
      _clearNormalState();
    }
  }

  // COGNIQ-FIX:mod-desc-copy
  String _getModifierDescription(String mod) {
    switch (mod) {
      case 'limitedFlags':
        return 'Flag count is strictly limited to total mines.';
      case 'hiddenCount':
        return 'Mine counts and remaining flags are hidden.';
      case 'timer':
        return 'Clear all safe cells before the timer runs out.';
      case 'blind':
        return 'Flagging a safe cell triggers an instant loss.';
      case 'fog':
        return 'A dense fog obscures unrevealed regions of the board.';
      case 'silence':
        return 'Mines do not detonate immediately — submit when finished (3 tries).';
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

  int _countFlags() {
    int count = 0;
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        if (_flagged[r][c]) count++;
      }
    }
    return count;
  }

  Timer? _gameTimer;
  int _timeLeft = -1;
  // Timer value at the moment the hard timer started; 0 when no timer ran.
  // Only used for the Speed Demon achievement check on clear.
  int _initialTime = 0;
  bool _timeBonusEarned = false;

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  /// Modifiers now begin at a per-game level chosen in RotationEngine
  /// rather than a flat level 30 for every game.
  bool get _modsOn => !_playDailyMode && RotationEngine.hasModifiers('mines', _levelIndex);

  @override
  void initState() {
    super.initState();
    _initLevel();
  }

  Future<void> _initLevel() async {
    await HintManager.startLevel('minesweeper');
    _hintCount = await HintManager.getHints('minesweeper');
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString(PrefsKeys.dailyModifierType) ?? '';
      _dailyModifierName = prefs.getString(PrefsKeys.dailyModifierName) ?? '';
      _dailyModifierDesc = prefs.getString(PrefsKeys.dailyModifierDesc) ?? '';
      try {
        final extraParamsStr = prefs.getString(PrefsKeys.dailyModifierExtraParams);
        if (extraParamsStr != null) {
          final params = jsonDecode(extraParamsStr);
          if (params['radius'] != null) {
            _dailyModifierRadius = (params['radius'] as num).toDouble();
          }
        }
      } catch (_) {}
    } else {
      _dailyModifierType = '';
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
    final savedLevel = prefs.getInt(PrefsKeys.gameLevel('minesweeper')) ?? 0;
    final active = await ShuffleManager.isActive();

    _isTutorialMode = false;
    _levelIndex = savedLevel;
 
    if (mounted) {
      setState(() {
        _shuffleActive = active;
        _loadLevel();
      });
    }

    if (!_playDailyMode && !_isTutorialMode) {
      Future.delayed(Duration.zero, () async {
        if (!mounted) return;
        final savedStateStr = prefs.getString(PrefsKeys.normalGameState('minesweeper'));
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
                final List<dynamic> minesData = data['mines'];
                final List<dynamic> revealedData = data['revealed'];
                final List<dynamic> flaggedData = data['flagged'];
                final bool isFirstTap = data['isFirstTap'] ?? true;

                setState(() {
                  _mines = minesData.map((row) => List<bool>.from(row)).toList();
                  _revealed = revealedData.map((row) => List<bool>.from(row)).toList();
                  _flagged = flaggedData.map((row) => List<bool>.from(row)).toList();
                  _isFirstTap = isFirstTap;
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
  }



  Future<void> _saveNormalState() async {
    if (_playDailyMode || _won || _lost) return;
    final prefs = await SharedPreferences.getInstance();
    final state = {
      'mines': _mines,
      'revealed': _revealed,
      'flagged': _flagged,
      'isFirstTap': _isFirstTap,
      'levelIndex': _levelIndex,
    };
    await prefs.setString(PrefsKeys.normalGameState('minesweeper'), jsonEncode(state));
  }

  Future<void> _clearNormalState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PrefsKeys.normalGameState('minesweeper'));
  }

  void _loadLevel() {
    _gameTimer?.cancel();
    _timeLeft = -1;
    _timeBonusEarned = false;

    bool isHighLevel = !_playDailyMode && _levelIndex >= 30; // not-a-modifier-gate
    if (isHighLevel) {
      _gridSize = (10 + ((_levelIndex - 30) ~/ 4)).clamp(10, 16);
      final double maxMines = ((_gridSize * _gridSize) - 9) * 0.28;
      _mineCount = (_gridSize * _gridSize * 0.22).floor().clamp(12, maxMines.floor());
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'mines',
        levelIndex: _levelIndex,
        pool: kMineFinderModifierPool,
        minActive: 2,
        maxActive: 3,
        smallGrid: _gridSize <= 10,
      );
      if (_forcedModifier != null) {
        _activeModifiers = {_forcedModifier!};
      }
    } else {
      _gridSize = (5 + (_levelIndex ~/ 3)).clamp(5, 16);
      final double maxMines = ((_gridSize * _gridSize) - 9) * 0.25;
      _mineCount = (3 + (_levelIndex * 1.2).floor()).clamp(3, maxMines.floor());
      _activeModifiers = {};
    }

    _mines = List.generate(_gridSize, (_) => List.filled(_gridSize, false));
    _revealed = List.generate(_gridSize, (_) => List.filled(_gridSize, false));
    _flagged = List.generate(_gridSize, (_) => List.filled(_gridSize, false));

    _isFirstTap = true;
    _won = false;
    _lost = false;
    _message = '';
    _submitAttempts = 3;

    if (isHighLevel && _activeModifiers.contains('timer')) {
      _timeLeft = 35 + (_gridSize * 9);
      _initialTime = _timeLeft;
      _timeBonusEarned = true;
      _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            if (_timeLeft > 0) {
              _timeLeft--;
            } else {
              _timeLeft = 0;
              _timeBonusEarned = false;
              _gameTimer?.cancel();
              AudioManager.playFail();
              _lost = true;
              _message = 'Time is up!';
            }
          });
        }
      });
    }
  }

  void _showJumpToLevelDialog() {
    showDialog(
      context: context,
      builder: (context) {
        int target = _levelIndex + 1;
        String? selectedMod = _forcedModifier;
        final pool = ['limitedFlags', 'hiddenCount', 'timer', 'blind', 'fog'];
        
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
                  child: Text('Jump', style: GoogleFonts.outfit(color: AppTheme.accentFor('minesweeper'))),
                ),
              ],
            );
          }
        );
      },
    );
  }

  bool _isCorner(int r, int c) => (r == 0 || r == _gridSize - 1) && (c == 0 || c == _gridSize - 1);

  void _generateMines(int firstRow, int firstCol) {
    final rand = _playDailyMode
        ? Random()
        : RotationEngine.getDeterminism('minesweeper', _levelIndex);
    int currentMineCount = _mineCount;
    final isHiddenRule = _playDailyMode && _dailyModifierType == 'hidden_rule';
    if (isHiddenRule) {
      currentMineCount = max(4, _mineCount);
    }
    bool foundSolvable = false;

    // Try up to 200 times to find a mine layout with the exact mine count that is solvable
    for (int attempt = 0; attempt < 200; attempt++) {
      // Clear mines
      for (int i = 0; i < _gridSize; i++) {
        _mines[i].fillRange(0, _gridSize, false);
      }

      int placedMines = 0;
      if (isHiddenRule) {
        _mines[0][0] = true;
        _mines[0][_gridSize - 1] = true;
        _mines[_gridSize - 1][0] = true;
        _mines[_gridSize - 1][_gridSize - 1] = true;
        placedMines = 4;
      }

      while (placedMines < currentMineCount) {
        int r = rand.nextInt(_gridSize);
        int c = rand.nextInt(_gridSize);

        if (isHiddenRule && _isCorner(r, c)) {
          continue;
        }

        // Avoid placing a mine in the 3x3 area around first tap to guarantee starting space
        bool tooClose = false;
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            if (firstRow + dr == r && firstCol + dc == c) {
              tooClose = true;
            }
          }
        }

        // If the grid size is small and we can't fit mines comfortably, fallback to checking just the clicked cell
        if (_gridSize * _gridSize - 9 < currentMineCount) {
          tooClose = (r == firstRow && c == firstCol);
        }

        if (!_mines[r][c] && !tooClose) {
          _mines[r][c] = true;
          placedMines++;
        }
      }

      // Check if this candidate is solvable without guessing starting from the first clicked cell
      if (_isBoardSolvable(firstRow, firstCol)) {
        foundSolvable = true;
        break; // Found one!
      }
    }

    // If we couldn't find a 100% solvable board with the exact mine count,
    // generate a layout with the exact mine count where the first tap area is safe.
    if (!foundSolvable) {
      for (int i = 0; i < _gridSize; i++) {
        _mines[i].fillRange(0, _gridSize, false);
      }
      int placedMines = 0;
      if (isHiddenRule) {
        _mines[0][0] = true;
        _mines[0][_gridSize - 1] = true;
        _mines[_gridSize - 1][0] = true;
        _mines[_gridSize - 1][_gridSize - 1] = true;
        placedMines = 4;
      }
      while (placedMines < currentMineCount) {
        int r = rand.nextInt(_gridSize);
        int c = rand.nextInt(_gridSize);

        if (isHiddenRule && _isCorner(r, c)) {
          continue;
        }

        bool tooClose = false;
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            if (firstRow + dr == r && firstCol + dc == c) {
              tooClose = true;
            }
          }
        }

        if (_gridSize * _gridSize - 9 < currentMineCount) {
          tooClose = (r == firstRow && c == firstCol);
        }

        if (!_mines[r][c] && !tooClose) {
          _mines[r][c] = true;
          placedMines++;
        }
      }
    }
  }

  bool _isBoardSolvable(int startRow, int startCol) {
    // 1. Initialize simulation structures
    final simRevealed = List.generate(_gridSize, (_) => List.filled(_gridSize, false));
    final simFlagged = List.generate(_gridSize, (_) => List.filled(_gridSize, false));

    // 2. Perform the initial reveal
    _simReveal(startRow, startCol, simRevealed, simFlagged);

    // Helper to calculate target mine count at (r, c)
    int getMineCount(int r, int c) {
      int count = 0;
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          int nr = r + dr;
          int nc = c + dc;
          if (nr >= 0 && nr < _gridSize && nc >= 0 && nc < _gridSize) {
            if (_mines[nr][nc]) count++;
          }
        }
      }
      return count;
    }

    // 3. Iteratively solve using single-cell logic
    while (true) {
      // Check if all non-mine cells are revealed
      bool allSafeRevealed = true;
      for (int r = 0; r < _gridSize; r++) {
        for (int c = 0; c < _gridSize; c++) {
          if (!_mines[r][c] && !simRevealed[r][c]) {
            allSafeRevealed = false;
            break;
          }
        }
        if (!allSafeRevealed) break;
      }

      if (allSafeRevealed) return true;

      bool madeProgress = false;

      for (int r = 0; r < _gridSize; r++) {
        for (int c = 0; c < _gridSize; c++) {
          if (simRevealed[r][c]) {
            final targetCount = getMineCount(r, c);
            if (targetCount == 0) continue;

            // Gather adjacent cells info
            int flagCount = 0;
            final List<(int, int)> unrevealedAdj = [];

            for (int dr = -1; dr <= 1; dr++) {
              for (int dc = -1; dc <= 1; dc++) {
                if (dr == 0 && dc == 0) continue;
                int nr = r + dr;
                int nc = c + dc;
                if (nr >= 0 && nr < _gridSize && nc >= 0 && nc < _gridSize) {
                  if (simFlagged[nr][nc]) {
                    flagCount++;
                  } else if (!simRevealed[nr][nc]) {
                    unrevealedAdj.add((nr, nc));
                  }
                }
              }
            }

            if (unrevealedAdj.isNotEmpty) {
              // Rule 1: F + U == M -> all U are mines
              if (flagCount + unrevealedAdj.length == targetCount) {
                for (final cell in unrevealedAdj) {
                  simFlagged[cell.$1][cell.$2] = true;
                }
                madeProgress = true;
              }
              // Rule 2: F == M -> all U are safe
              else if (flagCount == targetCount) {
                for (final cell in unrevealedAdj) {
                  _simReveal(cell.$1, cell.$2, simRevealed, simFlagged);
                }
                madeProgress = true;
              }
            }
          }
        }
      }

      if (!madeProgress) {
        break; // Stuck (guess required)
      }
    }

    // Check if we solved it
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        if (!_mines[r][c] && !simRevealed[r][c]) {
          return false;
        }
      }
    }
    return true;
  }

  void _simReveal(int r, int c, List<List<bool>> simRevealed, List<List<bool>> simFlagged) {
    if (r < 0 || r >= _gridSize || c < 0 || c >= _gridSize) return;
    if (simRevealed[r][c] || simFlagged[r][c]) return;

    simRevealed[r][c] = true;

    // Count adjacent mines
    int count = 0;
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        int nr = r + dr;
        int nc = c + dc;
        if (nr >= 0 && nr < _gridSize && nc >= 0 && nc < _gridSize) {
          if (_mines[nr][nc]) count++;
        }
      }
    }

    if (count == 0) {
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          _simReveal(r + dr, c + dc, simRevealed, simFlagged);
        }
      }
    }
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
    await prefs.setInt(PrefsKeys.gameLevel('minesweeper'), lvl + 1);
    final earned = await HintManager.onLevelCleared(
      'minesweeper',
      // Speed Demon: cleared a hard-timer level with more than half the
      // clock still left. _initialTime is 0 unless the timer modifier ran.
      isSpeedDemon: _initialTime > 0 && _timeLeft * 2 > _initialTime,
    );
    if (earned) {
      final newCount = await HintManager.getHints('minesweeper');
      setState(() {
        _hintCount = newCount;
      });
    }
    await _clearNormalState();
  }

  int _countAdjacentMines(int r, int c) {
    int count = 0;
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        int nr = r + dr;
        int nc = c + dc;
        if (nr >= 0 && nr < _gridSize && nc >= 0 && nc < _gridSize) {
          if (_mines[nr][nc]) count++;
        }
      }
    }
    return count;
  }

  void _revealCell(int r, int c) {
    if (r < 0 || r >= _gridSize || c < 0 || c >= _gridSize) return;
    if (_revealed[r][c] || _flagged[r][c]) return;

    _revealed[r][c] = true;

    if (_countAdjacentMines(r, c) == 0 && !_mines[r][c]) {
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          _revealCell(r + dr, c + dc);
        }
      }
    }
  }

  void _handleCellTap(int r, int c) {
    if (_won || _lost) return;

    setState(() {
      AudioManager.playClick();
      if (_flagMode) {
        _toggleFlag(r, c);
        return;
      }

      if (_isFirstTap) {
        _isFirstTap = false;
        _generateMines(r, c);
      }

      if (_flagged[r][c]) return;

      if (_mines[r][c]) {
        if (_silent) {
          // No boom, no red, no message. The cell opens like any other and
          // shows its adjacent count; the mistake is only counted at Submit.
          _revealed[r][c] = true;
        } else if (_playDailyMode && _dailyModifierType == 'hidden_rule' && _isCorner(r, c)) {
          _revealCell(r, c);
          _checkWin();
        } else {
          // Exploded!
          _lost = true;
          _message = 'Boom! Detonated a mine.';
          AudioManager.playFail();
          // Reveal all mines
          for (int i = 0; i < _gridSize; i++) {
            for (int j = 0; j < _gridSize; j++) {
              if (_mines[i][j]) {
                _revealed[i][j] = true;
              }
            }
          }
        }
      } else {
        _revealCell(r, c);
        _checkWin();
      }
    });
    if (_won || _lost) {
      _clearNormalState();
    } else {
      _saveNormalState();
    }
  }

  void _toggleFlag(int r, int c) {
    if (_revealed[r][c]) return;
    final currentlyFlagged = _countFlags();
    if (!_flagged[r][c] && _isLimitedFlagsActive && currentlyFlagged >= _mineCount) {
      setState(() {
        _message = "No more flags left! Unflag a cell first.";
      });
      return;
    }
    setState(() {
      _flagged[r][c] = !_flagged[r][c];
      _message = '';
      AudioManager.playClick();
    });

    _checkWin();

    if (_won || _lost) {
      _clearNormalState();
    } else {
      _saveNormalState();
    }
  }

  void _finishSilentWin() {
    _checkWin(fromSubmit: true);
    if (_won) _clearNormalState();
  }

  void _checkWin({bool fromSubmit = false}) {
    // `silence`: opening the last safe cell must not announce anything. Only
    // Submit can end the level.
    if (_silent && !fromSubmit) return;
    bool allSafeRevealed = true;
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        if (!_mines[r][c] && !_revealed[r][c]) {
          allSafeRevealed = false;
          break;
        }
      }
    }

    bool allMinesFlagged = true;
    if (_isHiddenMinesActive) {
      for (int r = 0; r < _gridSize; r++) {
        for (int c = 0; c < _gridSize; c++) {
          if (_mines[r][c] != _flagged[r][c]) {
            allMinesFlagged = false;
            break;
          }
        }
      }
    } else {
      allMinesFlagged = false;
    }

    bool hasWon = allSafeRevealed || allMinesFlagged;

    if (hasWon && !_won && !_lost) {
      if (_isTutorialMode) {
        setState(() {
          _tutorialCompleted = true;
          _message = 'Safe path cleared! Tutorial complete.';
        });
        AudioManager.playSuccess();
      } else {
        setState(() {
          _won = true;
          _message = _isHiddenMinesActive && allMinesFlagged
              ? 'All mines successfully flagged!'
              : 'Safe path cleared! Level complete.';
        });
        AudioManager.playSuccess();
        _savePersistedLevel(_levelIndex);
      }
      // Auto-flag all mines
      for (int r = 0; r < _gridSize; r++) {
        for (int c = 0; c < _gridSize; c++) {
          if (_mines[r][c]) {
            _flagged[r][c] = true;
          }
        }
      }
    }
  }

  Future<void> _useHint() async {
    if (_hintCount <= 0 || _won || _lost) return;

    if (_isFirstTap) {
      _isFirstTap = false;
      _generateMines(_gridSize ~/ 2, _gridSize ~/ 2);
    }

    // Find a safe unrevealed cell
    List<Point<int>> safeUnrevealed = [];
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        if (!_mines[r][c] && !_revealed[r][c]) {
          safeUnrevealed.add(Point(r, c));
        }
      }
    }

    if (safeUnrevealed.isEmpty) return;

    await HintManager.useHint('minesweeper');
    final newCount = await HintManager.getHints('minesweeper');

    final rand = Random();
    final chosen = safeUnrevealed[rand.nextInt(safeUnrevealed.length)];

    setState(() {
      _hintCount = newCount;
      _flagged[chosen.x][chosen.y] = false;
      _revealCell(chosen.x, chosen.y);
      _message = 'Hint revealed a safe cell!';
      _checkWin();
    });
    if (_won || _lost) {
      _clearNormalState();
    } else {
      _saveNormalState();
    }
  }

  void _nextLevel() async {
    if (!_won) return;
    if (widget.dailyLevelIndex != null) {
      Navigator.pop(context, true);
      return;
    }
    if (await ShuffleManager.tryShuffleNavigate(context, 'minesweeper')) return;
 
    setState(() {
      _levelIndex++;
      _loadLevel();
    });
  }

  void _reset() {
    setState(() {
      _loadLevel();
    });
    _saveNormalState();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AppTheme.accentFor('minesweeper');

    // Choose grid cell size depending on screen space and grid dimensions
    // We increase the minimum cell size to 34.0 to make it easier to tap without errors
    final maxGridWidth = context.screenWidth - 56;
    final maxGridHeight = (context.screenHeight - 380).clamp(150.0, double.infinity);
    final cellSizeWidth = maxGridWidth / _gridSize - 4;
    final cellSizeHeight = maxGridHeight / _gridSize - 4;
    final cellSize = min(cellSizeWidth, cellSizeHeight).clamp(24.0, 48.0);

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: const GameTitle('Mine Finder'),
        centerTitle: true,
        actions: [
          if (_shuffleActive && !_isTutorialMode)
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              tooltip: 'Skip Game',
              onPressed: () => ShuffleManager.tryShuffleNavigate(context, 'minesweeper'),
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
            onPressed: !_won && !_lost && !_isTutorialMode
                ? () async {
                    if (_hintCount > 0) {
                      _useHint();
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'minesweeper',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('minesweeper');
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
                  RulesHelper.showRulesBottomSheet(context, 'minesweeper', 'Mine Finder');
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
              onPressed: () => RulesHelper.showRulesBottomSheet(
                context,
                'minesweeper',
                'Mine Finder',
              ),
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
            modeLabel: _isTutorialMode
                ? 'Tutorial'
                : (_playDailyMode ? 'Daily' : null),
            accent: AppTheme.accentFor('minesweeper'),
            onTap: kDebugMode ? _showJumpToLevelDialog : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_playDailyMode && _dailyModifierName.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: Colors.amber.withOpacity(0.12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'DAILY CHALLENGE: ${_dailyModifierName.toUpperCase()}',
                              style: GoogleFonts.outfit(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: context.scale(12),
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dailyModifierDesc,
                          style: GoogleFonts.outfit(
                            color: context.textSecondary,
                            fontSize: context.scale(11),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
              // Instruction text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Uncover all safe spaces without hitting a mine! Flag spaces you suspect are trapped.',
                  style: GoogleFonts.outfit(
                    color: context.textSecondary,
                    fontSize: context.scale(13),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),

              // Game Info Row (Mines Count & Flag Count)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                // Each badge takes half the row and shrinks with the screen.
                // At their natural width the pair ran past the edge of a narrow
                // phone.
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Flexible(
                      child: _buildStatsBadge(
                        icon: Icons.dangerous_outlined,
                        label: 'Mines',
                        value: _isHiddenMinesActive ? '?' : '$_mineCount',
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: _buildStatsBadge(
                        icon: Icons.flag_rounded,
                        label: 'Flags',
                        value: _isHiddenMinesActive
                            ? '?'
                            : '${_flagged.expand((f) => f).where((f) => f).length}',
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (!_playDailyMode && _activeModifiers.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    _activeModifiers.map((m) => _getModifierDescription(m)).where((desc) => desc.isNotEmpty).join(' · '),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accentColor.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
              // Interactive Minesweeper Grid
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Center(
                    child: GestureDetector(
                      onPanStart: _isFogActive
                          ? (_) {}
                          : null,
                      onPanUpdate: _isFogActive
                          ? (_) {}
                          : null,
                      child: FogOverlay(
                        enabled: _isFogActive,
                        radius: (cellSize + 4) * _dailyModifierRadius * 1.35,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(_gridSize, (r) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(_gridSize, (c) {
                              final isRev = _revealed[r][c];
                              // Under `silence` a dug mine must look exactly
                              // like any other opened cell until the level
                              // ends, or the board would leak the verdict the
                              // modifier exists to withhold.
                              final isMine =
                                  _mines[r][c] && (!_silent || _revealTruth);
                              final isFlag = _flagged[r][c];
                              final adjCount = _countAdjacentMines(r, c);
                              final revealedSafeColor = context.isDarkMode
                                  ? const Color(0xFF332F2A)
                                  : context.bgSurface;

                               String cellLabel = 'Cell Row ${r + 1}, Column ${c + 1}';
                               if (isRev) {
                                 if (isMine) {
                                   cellLabel += ', mine';
                                 } else {
                                   cellLabel += ', revealed: $adjCount adjacent mines';
                                 }
                               } else {
                                 if (isFlag) {
                                   cellLabel += ', flagged';
                                 } else {
                                   cellLabel += ', unrevealed';
                                 }
                               }

                               return Semantics(
                                 label: cellLabel,
                                 button: true,
                                 child: GestureDetector(
                                   onTap: () => _handleCellTap(r, c),
                                   onLongPress: () => _toggleFlag(r, c),
                                   child: AnimatedContainer(
                                     duration: const Duration(milliseconds: 150),
                                     width: cellSize,
                                     height: cellSize,
                                     margin: const EdgeInsets.all(2),
                                     decoration: BoxDecoration(
                                       color: isRev
                                           ? (isMine
                                                 ? ((_playDailyMode && _dailyModifierType == 'hidden_rule' && _isCorner(r, c))
                                                     ? revealedSafeColor
                                                     : Colors.redAccent.withAlpha(80))
                                                 : revealedSafeColor)
                                           : context.bgCard,
                                       borderRadius: BorderRadius.circular(6),
                                       border: Border.all(
                                         color: isRev
                                             ? context.textMuted.withAlpha(
                                                 context.isDarkMode ? 80 : 30,
                                               )
                                             : context.textMuted.withAlpha(80),
                                         width: 1,
                                       ),
                                       boxShadow: isRev
                                           ? []
                                           : [
                                               BoxShadow(
                                                 color: Colors.black.withAlpha(15),
                                                 blurRadius: 1,
                                                 offset: const Offset(0, 1),
                                               ),
                                             ],
                                     ),
                                     child: Center(
                                       child: _buildCellContent(
                                         r,
                                         c,
                                         isRev,
                                         isMine,
                                         isFlag,
                                         adjCount,
                                         accentColor,
                                         cellSize,
                                       ),
                                     ),
                                   ),
                                 ),
                               );
                            }),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
              ),
              const SizedBox(height: 24),

              // Display status/victory message
              if (_message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _message,
                        style: GoogleFonts.outfit(
                          color: _won ? accentColor : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: context.scale(15),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_won && !_isTutorialMode) ...[
                        const SizedBox(height: 16),
                        if (!_playDailyMode)
                          AutoNextCountdown(
                            onNext: _nextLevel,
                            accentColor: accentColor,
                          ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // Controls row
              if (!_won && !_lost)
                // A Wrap, not a Row: `silence` adds a Submit button next to
                // the mode toggle and the pair is wider than a phone. Both
                // have to stay on screen and tappable, so the second one drops
                // to its own line rather than being clipped.
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (_silent) ...[
                      FilledButton.tonal(
                        onPressed: _onSubmitSilent,
                        style: FilledButton.styleFrom(
                          backgroundColor: accentColor.withValues(alpha: 0.18),
                          foregroundColor: accentColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        child: Text(
                          'Submit  ·  $_submitAttempts left',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: context.scale(12),
                          ),
                        ),
                      ),
                    ],
                    // Mode Toggle Action Button
                    InkWell(
                      onTap: () => setState(() => _flagMode = !_flagMode),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _flagMode
                              ? Colors.redAccent.withAlpha(40)
                              : accentColor.withAlpha(40),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: _flagMode ? Colors.redAccent : accentColor,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          // A Wrap hands its children a bounded width, so the
                          // pill would stretch edge to edge without this.
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _flagMode
                                  ? Icons.flag_rounded
                                  : Icons.gavel_rounded,
                              color: _flagMode ? Colors.redAccent : accentColor,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _flagMode ? 'FLAG MODE' : 'DIG MODE',
                              style: GoogleFonts.outfit(
                                color: _flagMode
                                    ? Colors.redAccent
                                    : accentColor,
                                fontWeight: FontWeight.w800,
                                fontSize: context.scale(12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_lost)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.bgSurface,
                          foregroundColor: context.textPrimary,
                          side: BorderSide(
                            color: context.textMuted.withAlpha(100),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _reset,
                        child: Text(
                          'Retry',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: context.scale(13),
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
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
      //         ? "Nice! You successfully cleared all safe cells."
      //         : "Tap safe cells to reveal adjacent mine counts. Use Flag mode to mark suspected mines, and Dig mode to clear safe spaces!",
      //     isCompleted: _tutorialCompleted,
      //     onSkip: _finishTutorial,
      //     onStartGame: _finishTutorial,
      //   ),
    ],
  ),
);
  }

  Widget _buildStatsBadge({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.textMuted.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          // The label gives way before the value does, so a narrow screen
          // shortens "Mines" rather than pushing the count out of view.
          Flexible(
            child: Text(
              '$label: ',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: context.textSecondary,
                fontSize: context.scale(12),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: context.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: context.scale(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCellContent(
    int r,
    int c,
    bool isRev,
    bool isMine,
    bool isFlag,
    int adjCount,
    Color accentColor,
    double cellSize,
  ) {
    final double itemSize = (cellSize * 0.6).clamp(10.0, 28.0);
    if (isFlag) {
      return Icon(Icons.flag_rounded, color: Colors.redAccent, size: itemSize);
    }

    if (!isRev) return const SizedBox.shrink();

    if (isMine) {
      if (_playDailyMode && _dailyModifierType == 'hidden_rule' && _isCorner(r, c)) {
        // Fall through to show the adjacent mine count!
      } else {
        return Icon(
          Icons.dangerous_outlined,
          color: Colors.redAccent,
          size: itemSize,
        );
      }
    }

    if (adjCount == 0) {
      return Icon(
        Icons.fiber_manual_record,
        color: context.textMuted.withAlpha(context.isDarkMode ? 140 : 90),
        size: (cellSize * 0.25).clamp(3.0, 12.0),
      );
    }

    // Map number of neighbors to different Zen friendly colors
    Color numColor;
    switch (adjCount) {
      case 1:
        numColor = Colors.blueAccent;
        break;
      case 2:
        numColor = Colors.green;
        break;
      case 3:
        numColor = Colors.orange;
        break;
      case 4:
        numColor = Colors.deepPurpleAccent;
        break;
      default:
        numColor = Colors.red;
    }

    return Text(
      '$adjCount',
      style: GoogleFonts.outfit(
        fontWeight: FontWeight.w900,
        fontSize: (cellSize * 0.55).clamp(10.0, 24.0),
        color: numColor,
      ),
    );
  }
}
