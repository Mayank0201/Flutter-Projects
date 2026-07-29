import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../utils/rotation_engine.dart';
import '../../../utils/point_manager.dart';
import '../../../utils/prefs_keys.dart';
import '../../../utils/hint_manager.dart';
import '../../../widgets/buy_hints_dialog.dart';
import '../../../widgets/challenge_cleared_overlay.dart';

class KillerSudokuBetaScreen extends StatefulWidget {
  const KillerSudokuBetaScreen({super.key});
  @override
  State<KillerSudokuBetaScreen> createState() => _KillerSudokuBetaScreenState();
}
class _KillerSudokuBetaScreenState extends State<KillerSudokuBetaScreen> {
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
  int _spyCageId = -1;
  bool get _isEndgame => !_playDailyMode && _currentLevel >= 10;
  Set<String> _activeModifiers = {};
  Timer? _gameTimer;
  int _timeLeft = -1;
  bool _timeBonusEarned = false;

  @override
  void initState() {
    super.initState();
    _initLevelState();
  }

  Future<void> _initLevelState() async {
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool('play_daily_mode') ?? false;
    _dailyModifierType = _playDailyMode ? (prefs.getString(PrefsKeys.dailyModifierType) ?? '') : '';
    final savedLvl = prefs.getInt('level_killersudoku') ?? 0;
    
    if (mounted) {
      setState(() {
        _currentLevel = _playDailyMode ? (savedLvl % 10) : savedLvl;
        _loadLevel();
      });
    }
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  void _generateProceduralLevel() {
    final rng = _playDailyMode
        ? Random(_currentLevel * 777)
        : RotationEngine.getDeterminism('killersudoku', _currentLevel);

    int maxCageSize = 3;
    int numGivens = 0;

    if (!_playDailyMode && _currentLevel >= 30) {
      if (_currentLevel >= 30 && _currentLevel < 50) {
        _gridSize = 6;
      } else {
        _gridSize = 9;
      }
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'killersudoku',
        levelIndex: _currentLevel,
        pool: ['cageSize', 'clueThinning', 'timer'],
        minActive: 1,
        maxActive: 2,
        smallGrid: _gridSize == 6,
      );
      maxCageSize = _activeModifiers.contains('cageSize') ? (_gridSize == 9 ? 5 : 4) : 3;
      numGivens = _activeModifiers.contains('clueThinning') ? 0 : 3;
    } else if (!_playDailyMode && _currentLevel >= 10) {
      _activeModifiers = {};
      if (_currentLevel >= 10 && _currentLevel < 25) {
        _gridSize = 4;
        maxCageSize = 3;
        numGivens = 0;
      } else if (_currentLevel >= 25 && _currentLevel < 40) {
        _gridSize = 6;
        maxCageSize = 3;
        numGivens = 0;
      } else if (_currentLevel >= 40 && _currentLevel < 55) {
        _gridSize = 6;
        maxCageSize = 4;
        numGivens = 0;
      } else if (_currentLevel >= 55 && _currentLevel < 70) {
        _gridSize = 6;
        maxCageSize = 4;
        numGivens = max(0, 4 - ((_currentLevel - 55) ~/ 5)); // 4, 3, 2, 1 givens
      } else if (_currentLevel >= 70 && _currentLevel < 90) {
        _gridSize = 9;
        maxCageSize = 4;
        numGivens = 0;
      } else {
        // Rotation (L90+)
        int combo = (_currentLevel - 90) % 3;
        if (combo == 0) {
          _gridSize = 4;
          maxCageSize = 3;
        } else if (combo == 1) {
          _gridSize = 6;
          maxCageSize = 4;
        } else {
          _gridSize = 9;
          maxCageSize = 4;
        }
        numGivens = 0;
      }
    } else {
      _activeModifiers = {};
      _gridSize = (_currentLevel % 2 == 0) ? 4 : 6;
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
    List<int> testBoard = List.filled(_gridSize * _gridSize, 0);
    for (int cell in _givenCells) {
      testBoard[cell] = _grid[cell];
    }
    
    int statesChecked = 0;
    const int maxStates = 4000;
    
    void solve(int idx) {
      if (solutions > 1 || statesChecked > maxStates) return;
      statesChecked++;
      if (idx == _gridSize * _gridSize) {
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
          
          int cageId = cages[idx];
          bool cageOk = true;
          int currentSum = 0;
          int filledCount = 0;
          int totalCageCells = 0;
          
          for (int j = 0; j < cages.length; j++) {
            if (cages[j] == cageId) {
              totalCageCells++;
              if (testBoard[j] != 0) {
                currentSum += testBoard[j];
                filledCount++;
              }
            }
          }
          
          int targetSum = cageSums[cageId];
          if (currentSum > targetSum) {
            cageOk = false;
          } else if (filledCount == totalCageCells && currentSum != targetSum) {
            cageOk = false;
          }
          
          if (cageOk) {
            solve(idx + 1);
          }
          testBoard[idx] = 0;
        }
      }
    }
    
    solve(0);
    if (statesChecked > maxStates) return false;
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
    HintManager.getHints('killersudoku').then((v) {
      if (mounted) setState(() => _hintCount = v);
    });

    setState(() {
      _isSuccess = false;
      _selectedIdx = -1;
      _gameTimer?.cancel();
      _timeLeft = -1;
      _timeBonusEarned = false;

      _activeModifiers.clear();
      _spyCageId = -1;
      if (_playDailyMode && _dailyModifierType.isNotEmpty) {
        _activeModifiers.add(_dailyModifierType);
      }

      if (_isEndgame) {
        _generateProceduralLevel();
        if ((_playDailyMode || _currentLevel >= 30) && _activeModifiers.contains('timer')) {
          _timeLeft = _gridSize == 4 ? 90 : (_gridSize == 6 ? 180 : 300);
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
          _cages = [0, 1, 1, 2, 0, 3, 1, 2, 0, 3, 4, 2, 5, 3, 4, 6];
          _cageSums = [7, 7, 9, 7, 6, 3, 1];
        } else if (_currentLevel == 3) {
          _cages = [0, 1, 1, 2, 0, 0, 1, 2, 3, 4, 5, 2, 3, 4, 5, 6];
          _cageSums = [8, 8, 6, 5, 5, 4, 4];
        } else if (_currentLevel == 4) {
          _cages = [0, 0, 1, 1, 2, 0, 3, 3, 2, 4, 4, 3, 2, 5, 4, 6];
          _cageSums = [7, 5, 9, 6, 10, 1, 2];
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

      if (_activeModifiers.contains('spy') && _cageSums.isNotEmpty) {
        final rng = Random(_currentLevel * 71 + 9);
        _spyCageId = rng.nextInt(_cageSums.length);
        _cageSums[_spyCageId] = _cageSums[_spyCageId] + 3;
      }
    });
  }

  Future<void> _onLevelCleared() async {
    _gameTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_killersudoku') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_killersudoku', _currentLevel + 1);
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
        bool ignoreSumCheck = _activeModifiers.contains('spy') && cageId == _spyCageId;
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
    final controller = TextEditingController(text: '${_currentLevel + 1}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text('Jump to Level', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter level number (1 - 150):', style: GoogleFonts.outfit(color: context.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: GoogleFonts.outfit(color: context.textPrimary),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'e.g. 111',
                hintStyle: GoogleFonts.outfit(color: context.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: context.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dustyMauve),
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val >= 1) {
                Navigator.pop(context);
                setState(() {
                  _currentLevel = val - 1;
                  _loadLevel();
                });
              }
            },
            child: Text('Go', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
      setState(() {
        _hintCount = newCount;
        _grid[hintCell] = _solution[hintCell];
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The board is already correctly solved!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Killer Sudoku', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
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
          GestureDetector(
            onTap: _showJumpToLevelDialog,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Level ${_currentLevel + 1}', style: AppTheme.numberStyle(color: AppTheme.dustyMauve, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit, size: 12, color: AppTheme.dustyMauve),
                  ],
                ),
              ),
            ),
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

                            RepaintBoundary(
                              child: Container(
                                width: _gridSize == 4 ? 280 : 320, height: _gridSize == 4 ? 280 : 320,
                                decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.textMuted.withAlpha(40))),
                                child: GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _gridSize),
                                  itemCount: _gridSize * _gridSize,
                                  itemBuilder: (context, idx) {
                                    int cageId = (idx < _cages.length) ? _cages[idx] : 0;
                                    Color cageColor = Colors.primaries[cageId % Colors.primaries.length].withOpacity(0.12);
                                    bool isCageStart = _cages.indexOf(cageId) == idx;
                                    return GestureDetector(
                                      onTap: () {
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
                                              Positioned(top: 2, left: 2, child: Text('${_cageSums[cageId]}', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold))),
                                            Center(
                                              child: Text(
                                                _grid[idx] == 0 ? "" : "${_grid[idx]}",
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
                            ),
                            const SizedBox(height: 16),
                            Row(
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
