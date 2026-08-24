import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../widgets/game_level_chip.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../utils/rotation_engine.dart';
import '../../../utils/point_manager.dart';
import '../../../utils/prefs_keys.dart';
import '../../../utils/progress_guard.dart';
import '../../../utils/hint_manager.dart';
import '../../../widgets/buy_hints_dialog.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../widgets/fog_overlay.dart';

/// The free-play modifier pool. Mirrored by `pools['killersudoku']` in
/// test/difficulty_curve_test.dart — keep the two in step.
const List<String> kKillerSudokuModifierPool = [
  'cageSize',
  'clueThinning',
  'timer',
  'spy',
  'eclipse',
  'zoom',
  'fog',
  'wildcard',
];

/// Which cage sums `wildcard` draws as "?" on [level].
///
/// The salt on the game id matters: `'killersudoku'` already seeds the board
/// itself, so reusing it would tie the hidden clues to the generator's own
/// choices instead of varying independently. Nothing here touches the sums —
/// this is a set of ids the renderer consults, and the win check keeps using
/// the real numbers.
Set<int> killerSudokuHiddenCages({
  required int cageCount,
  required int level,
  int spyCageId = -1,
}) {
  final rng = RotationEngine.getDeterminism('killersudoku_wild', level);
  final hidden = <int>{};
  for (int i = 0; i < cageCount; i++) {
    // `spy` doctors one cage's sum and dares the player to spot it. Hiding
    // that cage would quietly cancel the other modifier out.
    if (i == spyCageId) continue;
    if (rng.nextDouble() < 0.3) hidden.add(i);
  }
  return hidden;
}

class KillerSudokuScreen extends StatefulWidget {
  const KillerSudokuScreen({super.key});
  @override
  State<KillerSudokuScreen> createState() => _KillerSudokuScreenState();
}
class _KillerSudokuScreenState extends State<KillerSudokuScreen> {
  String? _forcedModifier;
  int _currentLevel = 0;
  bool _isSuccess = false;
  int _gridSize = 4;
  List<int> _grid = List.filled(16, 0);
  List<int> _cages = [0, 0, 1, 1, 0, 2, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4];
  List<int> _cageSums = [9, 4, 7, 3, 9, 4, 4];
  int _selectedIdx = -1;
  final Set<int> _givenCells = {};
  List<int> _solution = [];
  int _hintCount = 0;

  bool _playDailyMode = false;
  String _dailyModifierType = '';
  String _dailyModifierName = '';
  String _dailyModifierDesc = '';
  int _spyCageId = -1;
  Set<String> _activeModifiers = {};
  Timer? _gameTimer;
  int _timeLeft = -1;
  // Timer value at the moment the hard timer started; 0 when no timer ran.
  // Only used for the Speed Demon achievement check on clear.
  int _initialTime = 0;
  bool _timeBonusEarned = false;
  bool _isPanMode = false;

  // COGNIQ-FIX:mod-active-helper
  bool _isModActive(String name) {
    if (_forcedModifier == name) return true;
    if (_playDailyMode) return _dailyModifierType == name;
    return _currentLevel >= RotationEngine.modifierStartLevel('killersudoku') &&
        _activeModifiers.contains(name);
  }

  // COGNIQ-FIX:mod-getters
  bool get _isZoomActive => _isModActive('zoom');
  bool get _isEclipseActive => _isModActive('eclipse');
  bool get _isFogActive => _isModActive('fog');
  bool get _isSpyActive => _isModActive('spy');
  bool get _isEndgame => _isModActive('timer');
  bool get _wildcard => _isModActive('wildcard');

  Timer? _blackoutTimer;
  bool _isBlackout = false;
  bool _inRecallTest = false;
  bool _isScanPhase = true;
  int _recallTargetCount = 2;
  int _recallPlacedCount = 0;
  final Set<int> _recallCorrectSelections = {};
  final Set<int> _lockedRecallCells = {};
  int _blackoutCountdown = 0;

  /// Modifiers now begin at a per-game level chosen in RotationEngine
  /// rather than a flat level 30 for every game.
  bool get _modsOn => !_playDailyMode && RotationEngine.hasModifiers('killersudoku', _currentLevel);

  /// Cage ids whose sum is drawn as "?". Chosen from a salted seed so the
  /// hidden set is stable for a level yet differs from every other seeded
  /// choice made at that same level.
  final Set<int> _hiddenCageSums = {};

  void _pickHiddenCageSums() {
    _hiddenCageSums.clear();
    if (!_wildcard || _cageSums.isEmpty) return;
    _hiddenCageSums.addAll(killerSudokuHiddenCages(
      cageCount: _cageSums.length,
      level: _currentLevel,
      spyCageId: _spyCageId,
    ));
  }

  @override
  void initState() {
    super.initState();
    _initLevelState();
  }

  Future<void> _initLevelState() async {
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool('play_daily_mode') ?? false;
    _dailyModifierType = _playDailyMode ? (prefs.getString(PrefsKeys.dailyModifierType) ?? '') : '';
    _dailyModifierName = _playDailyMode ? (prefs.getString(PrefsKeys.dailyModifierName) ?? '') : '';
    _dailyModifierDesc = _playDailyMode ? (prefs.getString(PrefsKeys.dailyModifierDesc) ?? '') : '';
    final savedLvl = prefs.getInt(PrefsKeys.gameLevel('killersudoku')) ?? 0;
    
    if (mounted) {
      setState(() {
        _currentLevel = _playDailyMode ? (savedLvl % 10) : savedLvl;
        _loadLevel();
      });
    }
  }

  // COGNIQ-FIX:mod-desc-copy
  String _getModifierDescription(String mod) {
    switch (mod) {
      case 'cageSize':
        return 'Cages are larger and combine more cells.';
      case 'clueThinning':
        return 'Fewer cage sums are provided upfront.';
      case 'timer':
        return 'Solve the puzzle before the timer runs out.';
      case 'spy':
        return 'One cage total is encrypted as an anagram.';
      case 'zoom':
        return 'Grid is magnified with pan-and-scan navigation.';
      case 'eclipse':
        return 'Periodic eclipse tests your recall of placed numbers.';
      case 'fog':
        return 'A dense fog obscures portions of the grid.';
      case 'wildcard':
        return 'Several cage totals are masked as question marks.';
      default:
        return '';
    }
  }

  String get _modifierBannerText {
    if (_isSuccess) return '';
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

  /// Held in state rather than rebuilt inside build(): a fresh controller
  /// on every frame leaked one per rebuild and snapped the player's pan
  /// position back to the start each time the board changed.
  final TransformationController _zoomController =
      TransformationController(Matrix4.identity()..scale(1.4));

  @override
  void dispose() {
    _zoomController.dispose();
    _gameTimer?.cancel();
    _blackoutTimer?.cancel();
    super.dispose();
  }

  void _generateProceduralLevel() {
    final rng = _playDailyMode
        ? Random(_currentLevel * 777)
        : RotationEngine.getDeterminism('killersudoku', _currentLevel);

    int maxCageSize = 3;
    int numGivens = 0;

    if (!_playDailyMode) {
      // One climbing ramp for the whole campaign. This used to be two branches
      // whose tiers for level 40, 55, 70 and 90 sat inside the half that only
      // ran below level 30, so none of them could ever be reached -- and the
      // first ten levels alternated between a 4x4 and a 6x6, bouncing the
      // difficulty up and down before the player had learned the rules.
      _activeModifiers = {};
      if (_currentLevel < 6) {
        _gridSize = 4;
        maxCageSize = 3;
        numGivens = 2;
      } else if (_currentLevel < 16) {
        _gridSize = 6;
        maxCageSize = 3;
        numGivens = 2;
      } else if (_currentLevel < 30) { // not-a-modifier-gate
        _gridSize = 6;
        maxCageSize = 4;
        // Givens thin out across the tier: 2, 1, then none.
        numGivens = max(0, 2 - ((_currentLevel - 16) ~/ 5));
      } else if (_currentLevel < 50) {
        _gridSize = 6;
        maxCageSize = 5;
        numGivens = 0;
      } else {
        _gridSize = 9;
        maxCageSize = 4;
        numGivens = 3;
      }
    } else {
      _activeModifiers = {};
      if (_dailyModifierType.isNotEmpty) {
        _activeModifiers.add(_dailyModifierType);
      }
      _gridSize = (_currentLevel % 2 == 0) ? 4 : 6;
    }

    // Modifiers now start before the level-30 endgame. The chain above still
    // decides the board itself at its own thresholds; this only fills in the
    // modifiers for the earlier levels it does not cover.
    if (_modsOn && _activeModifiers.isEmpty) {
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'killersudoku',
        levelIndex: _currentLevel,
        pool: kKillerSudokuModifierPool,
        minActive: 1,
        maxActive: 2,
        smallGrid: _gridSize == 6,
      );
      if (_forcedModifier != null) {
        _activeModifiers = {_forcedModifier!};
      }
      if (_isModActive('cageSize')) {
        maxCageSize = _gridSize == 9 ? 5 : 4;
      }
      if (_isModActive('clueThinning')) {
        numGivens = 0;
      }
    }

    int totalCells = _gridSize * _gridSize;
    _grid = List.filled(totalCells, 0);
    _givenCells.clear();

    List<int> solved = List.filled(totalCells, 0);
    _solveSudokuBoard(solved, 0, _gridSize, rng);
    _solution = List.from(solved);

    _cages = List.filled(totalCells, -1);
    _cageSums = [];
    int cageId = 0;

    for (int i = 0; i < totalCells; i++) {
      if (_cages[i] != -1) continue;

      List<int> cageCells = [i];
      _cages[i] = cageId;

      int targetSize = 2 + rng.nextInt(maxCageSize - 1);
      List<int> queue = [i];

      while (queue.isNotEmpty && cageCells.length < targetSize) {
        int curr = queue.removeAt(0);
        int r = curr ~/ _gridSize;
        int c = curr % _gridSize;

        List<int> neighbors = [];
        if (r > 0 && _cages[(r - 1) * _gridSize + c] == -1) neighbors.add((r - 1) * _gridSize + c);
        if (r < _gridSize - 1 && _cages[(r + 1) * _gridSize + c] == -1) neighbors.add((r + 1) * _gridSize + c);
        if (c > 0 && _cages[r * _gridSize + c - 1] == -1) neighbors.add(r * _gridSize + c - 1);
        if (c < _gridSize - 1 && _cages[r * _gridSize + c + 1] == -1) neighbors.add(r * _gridSize + c + 1);

        neighbors.shuffle(rng);
        for (int nextCell in neighbors) {
          if (cageCells.length < targetSize && !cageCells.contains(nextCell)) {
            cageCells.add(nextCell);
            _cages[nextCell] = cageId;
            queue.add(nextCell);
          }
        }
      }

      int sum = cageCells.fold(0, (acc, idx) => acc + solved[idx]);
      _cageSums.add(sum);
      cageId++;
    }

    // Apply initial givens from setup config
    if (numGivens > 0) {
      final List<int> indices = List.generate(totalCells, (index) => index)..shuffle(rng);
      for (int i = 0; i < min(numGivens, totalCells); i++) {
        final idx = indices[i];
        _grid[idx] = solved[idx];
        _givenCells.add(idx);
      }
    }

    // Progressively add more givens if the board does not have a unique solution
    if (!_hasUniqueKillerSolution(solved, _cages, _cageSums)) {
      final List<int> indices = List.generate(totalCells, (index) => index)..shuffle(rng);
      for (int idx in indices) {
        if (!_givenCells.contains(idx)) {
          _grid[idx] = solved[idx];
          _givenCells.add(idx);
          if (_hasUniqueKillerSolution(solved, _cages, _cageSums)) {
            break;
          }
        }
      }
    }
  }

  bool _hasUniqueKillerSolution(List<int> solved, List<int> cages, List<int> cageSums) {
    int solutions = 0;
    final int total = _gridSize * _gridSize;
    List<int> testBoard = List.filled(total, 0);
    for (int cell in _givenCells) {
      testBoard[cell] = _grid[cell];
    }

    // Group the cells of each cage up front. This used to be rescanned for
    // every candidate digit at every cell, which made each search step cost a
    // full pass over the board.
    final int cageCount =
        cages.isEmpty ? 0 : (cages.reduce((a, b) => a > b ? a : b) + 1);
    final cageCells = List.generate(cageCount, (_) => <int>[]);
    for (int j = 0; j < cages.length; j++) {
      cageCells[cages[j]].add(j);
    }

    int statesChecked = 0;
    // The old cap of 4000 was exhausted immediately on a 9x9, so the search
    // always reported "not unique" and the caller kept piling on givens --
    // burning CPU and over-revealing the board without ever verifying
    // anything. With the cage lookup above each step is far cheaper, so a
    // realistic budget can actually finish.
    const int maxStates = 300000;
    bool exhausted = false;

    void solve(int idx) {
      if (solutions > 1 || exhausted) return;
      if (++statesChecked > maxStates) {
        exhausted = true;
        return;
      }
      if (idx == total) {
        solutions++;
        return;
      }
      if (testBoard[idx] != 0) {
        solve(idx + 1);
        return;
      }

      int r = idx ~/ _gridSize;
      int c = idx % _gridSize;

      for (int d = 1; d <= _gridSize; d++) {
        if (_isValidSudokuPlace(testBoard, _gridSize, r, c, d)) {
          testBoard[idx] = d;

          final int cageId = cages[idx];
          final cells = cageCells[cageId];
          int currentSum = 0;
          int filledCount = 0;
          for (final j in cells) {
            final v = testBoard[j];
            if (v != 0) {
              currentSum += v;
              filledCount++;
            }
          }

          final int targetSum = cageSums[cageId];
          bool cageOk = true;
          if (currentSum > targetSum) {
            cageOk = false;
          } else if (filledCount == cells.length && currentSum != targetSum) {
            cageOk = false;
          }

          if (cageOk) {
            solve(idx + 1);
          }
          testBoard[idx] = 0;
          if (exhausted) return;
        }
      }
    }

    solve(0);
    // Ran out of budget: report "not unique" so the caller adds another given
    // rather than shipping a board that might have several answers.
    if (exhausted) return false;
    return solutions == 1;
  }

  bool _solveSudokuBoard(List<int> board, int idx, int size, Random rng) {
    if (idx == size * size) return true;
    int r = idx ~/ size;
    int c = idx % size;

    List<int> digits = List.generate(size, (i) => i + 1)..shuffle(rng);
    for (int d in digits) {
      if (_isValidSudokuPlace(board, size, r, c, d)) {
        board[idx] = d;
        if (_solveSudokuBoard(board, idx + 1, size, rng)) return true;
        board[idx] = 0;
      }
    }
    return false;
  }

  bool _isValidSudokuPlace(List<int> board, int size, int r, int c, int val) {
    for (int col = 0; col < size; col++) {
      if (board[r * size + col] == val) return false;
    }
    for (int row = 0; row < size; row++) {
      if (board[row * size + c] == val) return false;
    }
    int boxRows = size == 9 ? 3 : 2;
    int boxCols = size == 4 ? 2 : 3;
    int startR = (r ~/ boxRows) * boxRows;
    int startC = (c ~/ boxCols) * boxCols;
    for (int dr = 0; dr < boxRows; dr++) {
      for (int dc = 0; dc < boxCols; dc++) {
        if (board[(startR + dr) * size + (startC + dc)] == val) return false;
      }
    }
    return true;
  }

  void _loadLevel() {
    HintManager.startLevel('killersudoku');
    HintManager.getHints('killersudoku').then((v) {
      if (mounted) setState(() => _hintCount = v);
    });

    setState(() {
      _isSuccess = false;
      _selectedIdx = -1;
      _gameTimer?.cancel();
      _timeLeft = -1;
      _timeBonusEarned = false;
      _blackoutTimer?.cancel();
      _isScanPhase = true;
      _blackoutCountdown = 10;

      _activeModifiers.clear();
      _spyCageId = -1;
      if (_playDailyMode && _dailyModifierType.isNotEmpty) {
        _activeModifiers.add(_dailyModifierType);
      }

      if (_isEndgame) {
        _generateProceduralLevel();
        if (_isEndgame) {
          _timeLeft = _gridSize == 4 ? 90 : (_gridSize == 6 ? 180 : 300);
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
                }
              });
            }
          });
        }
      } else {
        final solutions = [
          [2, 4, 3, 1, 1, 3, 2, 4, 4, 2, 1, 3, 3, 1, 4, 2],
          [1, 3, 4, 2, 2, 4, 3, 1, 3, 2, 1, 4, 4, 1, 2, 3],
          [2, 3, 1, 4, 1, 4, 3, 2, 4, 1, 2, 3, 3, 2, 4, 1],
          [1, 2, 4, 3, 4, 3, 2, 1, 3, 4, 1, 2, 2, 1, 3, 4],
          [1, 4, 2, 3, 3, 2, 1, 4, 2, 3, 4, 1, 4, 1, 3, 2],
          [2, 4, 3, 1, 1, 3, 2, 4, 4, 2, 1, 3, 3, 1, 4, 2],
          [1, 3, 4, 2, 2, 4, 3, 1, 3, 2, 1, 4, 4, 1, 2, 3],
          [2, 3, 1, 4, 1, 4, 3, 2, 4, 1, 2, 3, 3, 2, 4, 1],
          [1, 2, 4, 3, 4, 3, 2, 1, 3, 4, 1, 2, 2, 1, 3, 4],
          [1, 4, 2, 3, 3, 2, 1, 4, 2, 3, 4, 1, 4, 1, 3, 2],
        ];
        _solution = solutions[_currentLevel % solutions.length];

        _gridSize = 4;
        _grid = List.filled(16, 0);
        _givenCells.clear();
        if (_currentLevel == 0) {
          _cages = [0, 0, 1, 1, 2, 0, 3, 4, 2, 2, 3, 4, 5, 5, 6, 4];
          _cageSums = [9, 4, 7, 3, 9, 4, 4];
        } else if (_currentLevel == 1) {
          _cages = [0, 1, 1, 1, 0, 0, 2, 2, 3, 4, 4, 2, 3, 5, 5, 5];
          _cageSums = [7, 9, 8, 7, 3, 6];
        } else if (_currentLevel == 2) {
          _cages = [0, 1, 1, 2, 0, 3, 3, 2, 0, 3, 4, 2, 5, 3, 4, 6];
          _cageSums = [7, 4, 9, 10, 6, 3, 1];
        } else if (_currentLevel == 3) {
          _cages = [0, 1, 1, 2, 0, 0, 0, 2, 3, 4, 5, 2, 3, 4, 5, 6];
          _cageSums = [10, 6, 6, 5, 5, 4, 4];
        } else if (_currentLevel == 4) {
          _cages = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7];
          _cageSums = [5, 5, 5, 5, 5, 5, 5, 5];
        } else if (_currentLevel == 5) {
          _cages = [0, 0, 1, 2, 3, 0, 1, 2, 3, 4, 4, 2, 5, 5, 6, 6];
          _cageSums = [9, 5, 8, 5, 3, 4, 6];
        } else if (_currentLevel == 6) {
          _cages = [0, 0, 0, 1, 2, 3, 3, 1, 2, 4, 4, 5, 2, 6, 6, 5];
          _cageSums = [8, 3, 9, 7, 3, 7, 3];
        } else if (_currentLevel == 7) {
          _cages = [0, 1, 1, 1, 0, 2, 3, 4, 0, 2, 3, 4, 5, 5, 6, 6];
          _cageSums = [7, 8, 5, 5, 5, 5, 5];
        } else if (_currentLevel == 8) {
          _cages = [0, 0, 1, 1, 2, 3, 3, 4, 2, 5, 5, 4, 2, 6, 6, 6];
          _cageSums = [3, 7, 9, 5, 3, 5, 8];
        } else {
          _cages = [0, 1, 2, 2, 0, 1, 3, 4, 5, 5, 3, 4, 6, 6, 6, 4];
          _cageSums = [4, 6, 5, 5, 7, 5, 8];
        }
      }

      if (_isSpyActive && _cageSums.isNotEmpty) {
        final rng = Random(_currentLevel * 71 + 9);
        _spyCageId = rng.nextInt(_cageSums.length);
        _cageSums[_spyCageId] = _cageSums[_spyCageId] + 3;
      }

      // Render-time only, and last, so it sees the final cage list.
      _pickHiddenCageSums();
    });

    if (_isEclipseActive) {
      _blackoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_isSuccess) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_blackoutCountdown > 1) {
            _blackoutCountdown--;
          } else {
            _isScanPhase = false;
            _blackoutTimer?.cancel();
          }
        });
      });
    }
  }

  Future<void> _onLevelCleared() async {
    _gameTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    if (!_playDailyMode) {
      int highest = prefs.getInt(PrefsKeys.gameLevel('killersudoku')) ?? 0;
      if (_currentLevel + 1 > highest) {
        await prefs.setInt(PrefsKeys.gameLevel('killersudoku'), _currentLevel + 1);
      }
      await prefs.setInt('beta_level_killersudoku', _currentLevel + 1);
    }
    // Register the clear. Without this the game awards no points, increments no
    // clear count, unlocks no achievement and ticks no trail milestone — a win
    // here was worth literally nothing. It also drives the Zen-vs-Challenge
    // split, so hand-rolled bookkeeping cannot substitute for it.
    if (!_playDailyMode) {
      await HintManager.onLevelCleared(
        'killersudoku',
        // Speed Demon: cleared a hard-timer level with more than half the
        // clock still left. _initialTime is 0 unless the timer modifier ran.
        isSpeedDemon: _initialTime > 0 && _timeLeft * 2 > _initialTime,
      );
    }

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
    setState(() => _isSuccess = true);
  }

  void _nextLevel() {
    if (_playDailyMode) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _currentLevel++;
      _loadLevel();
    });
    // Forward-only: replaying an earlier level used to write that lower number
    // straight over the player's real progress.
    ProgressGuard.saveLevel('killersudoku', _currentLevel, isDaily: false);
  }

  void _checkSolution() {
    bool isValid = true;
    int totalCells = _gridSize * _gridSize;
    for (int i = 0; i < totalCells; i++) {
      if (_grid[i] == 0) isValid = false;
    }
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill all cells!')));
      return;
    }
    for (int i = 0; i < _gridSize; i++) {
      var row = List.generate(_gridSize, (c) => _grid[i * _gridSize + c]);
      var col = List.generate(_gridSize, (r) => _grid[r * _gridSize + i]);
      if (row.toSet().length != _gridSize || col.toSet().length != _gridSize) isValid = false;
    }
    int boxRows = _gridSize == 9 ? 3 : 2;
    int boxCols = _gridSize == 4 ? 2 : 3;
    for (int r = 0; r < _gridSize; r += boxRows) {
      for (int c = 0; c < _gridSize; c += boxCols) {
        var box = <int>[];
        for (int dr = 0; dr < boxRows; dr++) {
          for (int dc = 0; dc < boxCols; dc++) {
            box.add(_grid[(r + dr) * _gridSize + (c + dc)]);
          }
        }
        if (box.toSet().length != _gridSize) isValid = false;
      }
    }
    Map<int, List<int>> cageVals = {};
    for (int i = 0; i < totalCells; i++) {
      if (_cages[i] >= 0) {
        cageVals.putIfAbsent(_cages[i], () => []).add(_grid[i]);
      }
    }
    cageVals.forEach((cageId, vals) {
      if (cageId < _cageSums.length) {
        int sum = vals.reduce((a, b) => a + b);
        bool ignoreSumCheck = _isSpyActive && cageId == _spyCageId;
        if (ignoreSumCheck) {
          if (vals.toSet().length != vals.length) {
            isValid = false;
          }
        } else {
          if (sum != _cageSums[cageId] || vals.toSet().length != vals.length) {
            isValid = false;
          }
        }
      }
    });
    if (isValid) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect solution. Check rows, columns, subgrids, and cage rules.')));
    }
  }

  void _showJumpToLevelDialog() {
    showDialog(
      context: context,
      builder: (context) {
        int target = _currentLevel + 1;
        String? selectedMod = _forcedModifier;
        const pool = kKillerSudokuModifierPool;
        
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
                        _currentLevel = target - 1;
                        _forcedModifier = selectedMod;
                        _loadLevel();
                      });
                    }
                  },
                  child: Text('Jump', style: GoogleFonts.outfit(color: AppTheme.dustyMauve)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text('How to Play Killer Sudoku', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
        content: Text(
          '1. Fill the 4x4 grid with digits 1-4. Each row, column, and 2x2 subgrid must contain each digit exactly once.\n\n'
          '2. The grid is divided into outlined cages.\n\n'
          '3. The numbers in each cage must sum to the target value in the corner.\n\n'
          '4. No digit can be repeated within a cage.',
          style: GoogleFonts.outfit(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it', style: GoogleFonts.outfit(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showHint() async {
    if (_isSuccess) return;

    if (_hintCount <= 0) {
      BuyHintsDialog.show(
        context,
        initialGameId: 'killersudoku',
        isFromGameScreen: true,
        onPurchaseComplete: () {
          HintManager.getHints('killersudoku').then((val) {
            if (mounted) setState(() => _hintCount = val);
          });
        },
      );
      return;
    }

    if (_solution.isEmpty) return;
    int hintCell = -1;
    final totalCells = _gridSize * _gridSize;
    for (int i = 0; i < totalCells; i++) {
      if (_grid[i] != _solution[i]) {
        hintCell = i;
        break;
      }
    }
    
    if (hintCell != -1) {
      await HintManager.useHint('killersudoku');
      final newCount = await HintManager.getHints('killersudoku');
      if (mounted) {
        setState(() {
          _hintCount = newCount;
          _grid[hintCell] = _solution[hintCell];
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The board is already correctly solved!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: const GameTitle('Killer Sudoku'),
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
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
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppTheme.dustyMauve),
            tooltip: 'Instructions',
            onPressed: _showInstructions,
          ),
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.lightbulb_outline, color: AppTheme.dustyMauve),
                Positioned(
                  right: -4,
                  top: -4,
                  child: CircleAvatar(
                    radius: 6,
                    backgroundColor: Colors.amber,
                    child: Text(
                      _hintCount == 0 ? '+' : '$_hintCount',
                      style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            tooltip: 'Hint',
            onPressed: _showHint,
          ),
          GameLevelChip(
            level: _currentLevel + 1,
            modeLabel: _playDailyMode ? 'Daily' : null,
            accent: AppTheme.accentFor('killersudoku'),
            onTap: kDebugMode ? _showJumpToLevelDialog : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isEclipseActive && _isScanPhase) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                'MEMORIZE CELLS & CAGES: $_blackoutCountdown s',
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
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
                                  color: AppTheme.dustyMauve.withOpacity(0.9),
                                ),
                              ),
                            ),
                          ],
                          if (_isZoomActive) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ChoiceChip(
                                  label: Text('Input Mode', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                                  selected: !_isPanMode,
                                  onSelected: (val) => setState(() => _isPanMode = !val),
                                  selectedColor: AppTheme.dustyMauve.withAlpha(40),
                                  checkmarkColor: AppTheme.dustyMauve,
                                ),
                                const SizedBox(width: 12),
                                ChoiceChip(
                                  label: Text('Pan Mode', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                                  selected: _isPanMode,
                                  onSelected: (val) => setState(() => _isPanMode = val),
                                  selectedColor: AppTheme.dustyMauve.withAlpha(40),
                                  checkmarkColor: AppTheme.dustyMauve,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          RepaintBoundary(
                            child: Builder(
                              builder: (context) {
                                final double sizeDim = _gridSize == 4 ? 280 : 320;
                                
                                Widget board = Container(
                                  width: sizeDim,
                                  height: sizeDim,
                                  decoration: BoxDecoration(
                                    color: context.bgCard,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: context.textMuted.withAlpha(40)),
                                  ),
                                  child: FogOverlay(
                                    enabled: _isFogActive,
                                    radius: (sizeDim / _gridSize) * 1.5,
                                    focalPoint: (_selectedIdx != -1)
                                        ? Offset(
                                            ((_selectedIdx % _gridSize) + 0.5) * (sizeDim / _gridSize),
                                            ((_selectedIdx ~/ _gridSize) + 0.5) * (sizeDim / _gridSize),
                                          )
                                        : null,
                                    child: GridView.builder(
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _gridSize),
                                      itemCount: _gridSize * _gridSize,
                                      itemBuilder: (context, idx) {
                                        int cageId = (idx < _cages.length) ? _cages[idx] : 0;
                                        Color cageColor = Colors.primaries[cageId % Colors.primaries.length].withOpacity(0.12);
                                        bool isCageStart = _cages.indexOf(cageId) == idx;
                                        return GestureDetector(
                                          onTap: (_isPanMode || (_isEclipseActive && _isScanPhase))
                                              ? null
                                              : () {
                                                  settingsNotifier.hapticTap();
                                                  setState(() => _selectedIdx = idx);
                                                },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: cageColor,
                                              border: Border(
                                                top: BorderSide(color: idx >= _gridSize && _cages[idx - _gridSize] == cageId ? Colors.transparent : Colors.black, width: 1.5),
                                                bottom: BorderSide(color: idx < _gridSize * (_gridSize - 1) && _cages[idx + _gridSize] == cageId ? Colors.transparent : Colors.black, width: 1.5),
                                                left: BorderSide(color: idx % _gridSize > 0 && _cages[idx - 1] == cageId ? Colors.transparent : Colors.black, width: 1.5),
                                                right: BorderSide(color: idx % _gridSize < _gridSize - 1 && _cages[idx + 1] == cageId ? Colors.transparent : Colors.black, width: 1.5),
                                              ),
                                            ),
                                            child: Stack(
                                              children: [
                                                if (isCageStart && cageId < _cageSums.length)
                                                  Positioned(
                                                    top: 2,
                                                    left: 2,
                                                    child: Text(
                                                      ((_isEclipseActive && !_isScanPhase) ||
                                                              _hiddenCageSums.contains(cageId))
                                                          ? '?'
                                                          : '${_cageSums[cageId]}',
                                                      style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                Center(
                                                  child: Text(
                                                    (_isEclipseActive && _isScanPhase)
                                                        ? (_solution.length > idx ? "${_solution[idx]}" : "")
                                                        : (_grid[idx] == 0 ? "" : "${_grid[idx]}"),
                                                    style: GoogleFonts.spaceGrotesk(
                                                      fontSize: _gridSize == 4 ? 18 : 15,
                                                      fontWeight: FontWeight.bold,
                                                      color: _givenCells.contains(idx) ? Colors.blue.shade700 : context.textPrimary,
                                                    ),
                                                  ),
                                                ),
                                                if (_selectedIdx == idx)
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      border: Border.all(color: AppTheme.dustyMauve, width: 2),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );

                                if (_isZoomActive) {
                                  board = SizedBox(
                                    width: sizeDim,
                                    height: sizeDim,
                                    child: InteractiveViewer(
                                      panEnabled: _isPanMode,
                                      scaleEnabled: false,
                                      minScale: 1.4,
                                      maxScale: 1.4,
                                      transformationController: _zoomController,
                                      child: board,
                                    ),
                                  );
                                }

                                return board;
                              }
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (!(_isEclipseActive && _isScanPhase))
                            // Nine number buttons plus clear do not fit across
                            // a narrow phone at their natural size, so the row
                            // scales down instead of running off the edge.
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (int i = 1; i <= _gridSize; i++) ...[
                                  GestureDetector(
                                    onTap: () {
                                      if (_selectedIdx != -1 && !_givenCells.contains(_selectedIdx)) {
                                        settingsNotifier.hapticTap();
                                        setState(() {
                                          _grid[_selectedIdx] = i;
                                        });
                                        if (_grid.every((val) => val != 0)) {
                                          _checkSolution();
                                        }
                                      }
                                    },
                                    child: Container(
                                      width: _gridSize == 4 ? 44 : (_gridSize == 6 ? 38 : 30), height: _gridSize == 4 ? 44 : (_gridSize == 6 ? 38 : 30),
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.dustyMauve,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text('$i', style: GoogleFonts.spaceGrotesk(fontSize: _gridSize == 9 ? 15 : 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                    ),
                                  ),
                                ],
                                GestureDetector(
                                  onTap: () {
                                    if (_selectedIdx != -1 && !_givenCells.contains(_selectedIdx)) {
                                      settingsNotifier.hapticTap();
                                      setState(() {
                                        _grid[_selectedIdx] = 0;
                                      });
                                    }
                                  },
                                  child: Container(
                                    width: _gridSize == 9 ? 32 : 44, height: _gridSize == 9 ? 32 : 44,
                                    margin: const EdgeInsets.symmetric(horizontal: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade800,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.clear, color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                              ],
                          ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: context.bgCard, foregroundColor: context.textPrimary),
                      onPressed: _loadLevel, icon: const Icon(Icons.refresh), label: const Text('Reset'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isSuccess)
            if (_playDailyMode)
              Positioned.fill(
                child: ChallengeClearedOverlay(
                  accentColor: AppTheme.dustyMauve,
                  onComplete: () {
                    Navigator.pop(context, true);
                  },
                ),
              )
            else
              Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
                        const SizedBox(height: 16),
                        Text('Level ${_currentLevel + 1} Cleared!', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        AutoNextCountdown(
                          onNext: _nextLevel,
                          accentColor: AppTheme.dustyMauve,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
      ),
    );
  }
}
