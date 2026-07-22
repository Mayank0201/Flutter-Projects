import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/buy_hints_dialog.dart';
import '../../../widgets/fog_overlay.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../utils/prefs_keys.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/audio_manager.dart';
import '../../../utils/rotation_engine.dart';

class KakuroScreen extends StatefulWidget {
  const KakuroScreen({super.key});

  @override
  State<KakuroScreen> createState() => _KakuroScreenState();
}

class _KakuroScreenState extends State<KakuroScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  double _dailyRadius = 1.5;
  int _gridSize = 4; // 4, 6, or 8 based on difficulty/level

  // Grid state
  List<int> _grid = []; // player entries (0 for empty)
  List<int> _solution = []; // full solution digits
  List<int> _types = []; // 0: wall, 1: white, 2: clue
  List<int> _hClues = []; // horizontal clues
  List<int> _vClues = []; // vertical clues

  int _selectedIdx = -1;
  int _hintIdx = -1;
  bool _isLoading = true;

  Set<String> _activeModifiers = {};
  Timer? _gameTimer;
  int _timeLeft = -1;
  bool _timeBonusEarned = false;

  @override
  void initState() {
    super.initState();
    _loadProgressAndGenerate();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProgressAndGenerate() async {
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString(PrefsKeys.dailyModifierType) ?? '';
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
      _dailyRadius = 1.5;
    }

    int level = prefs.getInt(PrefsKeys.gameLevel('kakuro')) ?? 0;
    if (mounted) {
      setState(() {
        _currentLevel = level;
        _isLoading = true;
      });
      _generatePuzzle();
    }
  }

  // Predefined layouts for grid sizes
  static const List<int> _kLayout4x4 = [
    0, 2, 2, 0,
    2, 1, 1, 0,
    2, 1, 1, 2,
    0, 0, 2, 0
  ];

  static const List<int> _kLayout6x6 = [
    0, 2, 2, 2, 2, 0,
    2, 1, 1, 1, 1, 2,
    2, 1, 1, 0, 1, 1,
    2, 1, 0, 2, 1, 1,
    2, 1, 1, 1, 1, 0,
    0, 0, 2, 2, 0, 0
  ];

  static const List<int> _kLayout8x8 = [
    0, 2, 2, 2, 0, 2, 2, 2,
    2, 1, 1, 1, 2, 1, 1, 1,
    2, 1, 1, 1, 2, 1, 1, 1,
    0, 2, 1, 1, 1, 1, 0, 0,
    0, 0, 1, 1, 1, 1, 2, 0,
    2, 1, 1, 1, 2, 1, 1, 1,
    2, 1, 1, 1, 2, 1, 1, 1,
    0, 0, 0, 0, 0, 0, 0, 0
  ];

  void _generatePuzzle() {
    _gameTimer?.cancel();
    _timeLeft = -1;
    _timeBonusEarned = false;

    if (!_playDailyMode && _currentLevel >= 30) {
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'kakuro',
        levelIndex: _currentLevel,
        pool: ['timer'],
        minActive: 1,
        maxActive: 1,
        smallGrid: false,
      );
    } else {
      _activeModifiers = {};
    }

    // Determine size based on level
    if (_currentLevel < 5) {
      _gridSize = 4;
      _types = List.from(_kLayout4x4);
    } else if (_currentLevel < 12) {
      _gridSize = 6;
      _types = List.from(_kLayout6x6);
    } else {
      _gridSize = 8;
      _types = List.from(_kLayout8x8);
    }

    final totalCells = _gridSize * _gridSize;
    _grid = List.filled(totalCells, 0);
    _solution = List.filled(totalCells, 0);
    _hClues = List.filled(totalCells, 0);
    _vClues = List.filled(totalCells, 0);

    final rand = Random();
    bool generated = false;

    // Retry loop to build a valid grid and ensure uniqueness
    for (int retry = 0; retry < 50; retry++) {
      _solution = List.filled(totalCells, 0);
      _hClues = List.filled(totalCells, 0);
      _vClues = List.filled(totalCells, 0);
      if (_fillGridWithUniqueDigits(0, rand)) {
        _computeClues();
        final tempBoard = List.filled(totalCells, 0);
        final numSolutions = _countSolutions(0, tempBoard, 2);
        if (numSolutions == 1) {
          _grid = List.filled(totalCells, 0);
          generated = true;
          break;
        }
      }
    }

    if (!generated) {
      // Fallback fallback if generation is stuck
      _currentLevel = 0; // reset scale
      _gridSize = 4;
      _types = List.from(_kLayout4x4);
      _grid = List.filled(16, 0);
      _solution = [0, 0, 0, 0, 0, 8, 7, 0, 0, 1, 5, 0, 0, 0, 0, 0];
      _types = [0, 2, 2, 0, 2, 1, 1, 0, 2, 1, 1, 2, 0, 0, 2, 0];
      _hClues = [0, 0, 0, 0, 15, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0];
      _vClues = [0, 9, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    }

    setState(() {
      _isSuccess = false;
      _selectedIdx = -1;
      _hintIdx = -1;
      _isLoading = false;
    });

    if (!_playDailyMode && _currentLevel >= 30 && _activeModifiers.contains('timer')) {
      _timeLeft = 60 + (_gridSize * 15);
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Time is up! Restarting level...'), duration: Duration(seconds: 1)),
              );
              _generatePuzzle();
            }
          });
        }
      });
    }
  }

  // Returns horizontal segment starting at or before index
  List<int> _getRowSegmentIndices(int idx) {
    List<int> indices = [];
    int r = idx ~/ _gridSize;
    int c = idx % _gridSize;

    // Go left to find start of segment
    int startCol = c;
    while (startCol >= 0 && _types[r * _gridSize + startCol] == 1) {
      startCol--;
    }
    // Now startCol points to the clue cell or wall
    // Go right and collect indices
    int x = startCol + 1;
    while (x < _gridSize && _types[r * _gridSize + x] == 1) {
      indices.add(r * _gridSize + x);
      x++;
    }
    return indices;
  }

  // Returns vertical segment starting at or before index
  List<int> _getColSegmentIndices(int idx) {
    List<int> indices = [];
    int r = idx ~/ _gridSize;
    int c = idx % _gridSize;

    // Go up to find start of segment
    int startRow = r;
    while (startRow >= 0 && _types[startRow * _gridSize + c] == 1) {
      startRow--;
    }
    // Now startRow points to the clue cell or wall
    // Go down and collect indices
    int y = startRow + 1;
    while (y < _gridSize && _types[y * _gridSize + c] == 1) {
      indices.add(y * _gridSize + c);
      y++;
    }
    return indices;
  }

  bool _fillGridWithUniqueDigits(int cellIdx, Random rand) {
    if (cellIdx >= _types.length) return true;

    if (_types[cellIdx] != 1) {
      return _fillGridWithUniqueDigits(cellIdx + 1, rand);
    }

    // Shuffled digits for variety
    final digits = [1, 2, 3, 4, 5, 6, 7, 8, 9]..shuffle(rand);

    for (final d in digits) {
      if (_isValidDigitPlacement(cellIdx, d)) {
        _solution[cellIdx] = d;
        if (_fillGridWithUniqueDigits(cellIdx + 1, rand)) {
          return true;
        }
        _solution[cellIdx] = 0;
      }
    }
    return false;
  }

  bool _isValidDigitPlacement(int idx, int d) {
    // Check horizontal run uniqueness
    final rowIndices = _getRowSegmentIndices(idx);
    for (final ri in rowIndices) {
      if (ri != idx && _solution[ri] == d) return false;
    }

    // Check vertical run uniqueness
    final colIndices = _getColSegmentIndices(idx);
    for (final ci in colIndices) {
      if (ci != idx && _solution[ci] == d) return false;
    }

    return true;
  }

  bool _isValidSolverPlacement(int idx, int d, List<int> tempBoard) {
    final rowIndices = _getRowSegmentIndices(idx);
    for (final ri in rowIndices) {
      if (ri != idx && tempBoard[ri] == d) return false;
    }
    final colIndices = _getColSegmentIndices(idx);
    for (final ci in colIndices) {
      if (ci != idx && tempBoard[ci] == d) return false;
    }
    return true;
  }

  bool _isSegmentSumsValid(int idx, List<int> tempBoard) {
    final rowIndices = _getRowSegmentIndices(idx);
    int rowSum = 0;
    bool rowComplete = true;
    for (final ri in rowIndices) {
      if (tempBoard[ri] == 0) {
        rowComplete = false;
      } else {
        rowSum += tempBoard[ri];
      }
    }
    int r = idx ~/ _gridSize;
    int c = idx % _gridSize;
    int startCol = c;
    while (startCol >= 0 && _types[r * _gridSize + startCol] == 1) {
      startCol--;
    }
    int hClueCell = r * _gridSize + startCol;
    int hClue = _hClues[hClueCell];
    if (rowComplete) {
      if (rowSum != hClue) return false;
    } else {
      if (rowSum >= hClue) return false;
    }

    final colIndices = _getColSegmentIndices(idx);
    int colSum = 0;
    bool colComplete = true;
    for (final ci in colIndices) {
      if (tempBoard[ci] == 0) {
        colComplete = false;
      } else {
        colSum += tempBoard[ci];
      }
    }
    int startRow = r;
    while (startRow >= 0 && _types[startRow * _gridSize + c] == 1) {
      startRow--;
    }
    int vClueCell = startRow * _gridSize + c;
    int vClue = _vClues[vClueCell];
    if (colComplete) {
      if (colSum != vClue) return false;
    } else {
      if (colSum >= vClue) return false;
    }

    return true;
  }

  int _countSolutions(int cellIdx, List<int> tempBoard, int maxSolutions) {
    if (cellIdx >= _types.length) return 1;

    if (_types[cellIdx] != 1) {
      return _countSolutions(cellIdx + 1, tempBoard, maxSolutions);
    }

    int solutionsCount = 0;
    for (int d = 1; d <= 9; d++) {
      if (_isValidSolverPlacement(cellIdx, d, tempBoard)) {
        tempBoard[cellIdx] = d;
        if (_isSegmentSumsValid(cellIdx, tempBoard)) {
          solutionsCount += _countSolutions(cellIdx + 1, tempBoard, maxSolutions);
          if (solutionsCount >= maxSolutions) {
            tempBoard[cellIdx] = 0;
            return solutionsCount;
          }
        }
        tempBoard[cellIdx] = 0;
      }
    }
    return solutionsCount;
  }

  void _computeClues() {
    for (int i = 0; i < _types.length; i++) {
      if (_types[i] == 2) {
        // Horizontal clue (sum of white run directly to the right)
        int nextRight = i + 1;
        if (nextRight < _types.length && (nextRight % _gridSize != 0) && _types[nextRight] == 1) {
          final run = _getRowSegmentIndices(nextRight);
          _hClues[i] = run.map((idx) => _solution[idx]).reduce((a, b) => a + b);
        }

        // Vertical clue (sum of white run directly below)
        int nextDown = i + _gridSize;
        if (nextDown < _types.length && _types[nextDown] == 1) {
          final run = _getColSegmentIndices(nextDown);
          _vClues[i] = run.map((idx) => _solution[idx]).reduce((a, b) => a + b);
        }
      }
    }
  }

  void _checkSolution() {
    bool isValid = true;
    for (int i = 0; i < _types.length; i++) {
      if (_types[i] == 1 && _grid[i] == 0) {
        isValid = false;
      }
    }

    if (!isValid) {
      settingsNotifier.hapticError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill all entry cells!')),
      );
      return;
    }

    // Verify all clues
    for (int idx = 0; idx < _types.length; idx++) {
      if (_types[idx] == 2) {
        int hc = _hClues[idx];
        int vc = _vClues[idx];

        if (hc > 0) {
          final run = _getRowSegmentIndices(idx + 1);
          final vals = run.map((i) => _grid[i]).toList();
          if (vals.reduce((a, b) => a + b) != hc || vals.toSet().length != vals.length) {
            isValid = false;
          }
        }

        if (vc > 0) {
          final run = _getColSegmentIndices(idx + _gridSize);
          final vals = run.map((i) => _grid[i]).toList();
          if (vals.reduce((a, b) => a + b) != vc || vals.toSet().length != vals.length) {
            isValid = false;
          }
        }
      }
    }

    if (isValid) {
      settingsNotifier.hapticSuccess();
      _onLevelCleared();
    } else {
      settingsNotifier.hapticError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect solution! Check clues and make sure digits in a run are unique.'),
        ),
      );
    }
  }

  Future<void> _onLevelCleared() async {
    if (!_playDailyMode) {
      final prefs = await SharedPreferences.getInstance();
      int highest = prefs.getInt('beta_level_kakuro') ?? 0;
      if (_currentLevel + 1 > highest) {
        await prefs.setInt('beta_level_kakuro', _currentLevel + 1);
      }
      await prefs.setInt(PrefsKeys.gameLevel('kakuro'), _currentLevel + 1);
      
      // Track stats
      int currentClears = prefs.getInt(PrefsKeys.globalLevelClearedCount) ?? 0;
      await prefs.setInt(PrefsKeys.globalLevelClearedCount, currentClears + 1);
    }

    setState(() => _isSuccess = true);
  }

  void _nextLevel() {
    setState(() {
      _currentLevel++;
      _isLoading = true;
    });
    _generatePuzzle();
  }

  void _showHint() async {
    if (_selectedIdx == -1 || _types[_selectedIdx] != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an empty cell first!')),
      );
      return;
    }

    final hints = await HintManager.getHints('kakuro');
    if (hints > 0) {
      await HintManager.useHint('kakuro');
      setState(() {
        _grid[_selectedIdx] = _solution[_selectedIdx];
      });
    } else {
      BuyHintsDialog.show(context, initialGameId: 'kakuro', onPurchaseComplete: () {
        setState(() {});
      });
    }
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text(
          'How to Play Kakuro',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        content: Text(
          '1. Fill the empty white cells with digits 1-9.\n\n'
          '2. The sum of each horizontal block must equal the clue number to its left.\n\n'
          '3. The sum of each vertical block must equal the clue number above it.\n\n'
          '4. No digit can be repeated within a single run (row or column block).',
          style: GoogleFonts.outfit(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style: GoogleFonts.outfit(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.bgDark,
        body: const Center(child: CircularProgressIndicator(color: AppTheme.dustyMauve)),
      );
    }

    final double boardSize = MediaQuery.of(context).size.width * 0.85;

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Kakuro', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppTheme.dustyMauve),
            tooltip: 'Instructions',
            onPressed: _showInstructions,
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline, color: AppTheme.dustyMauve),
            tooltip: 'Hint',
            onPressed: _showHint,
          ),
          if (_timeLeft >= 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Row(
                  children: [
                    Icon(
                      Icons.timer,
                      color: _timeLeft <= 10 ? Colors.red : Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_timeLeft s',
                      style: GoogleFonts.spaceGrotesk(
                        color: _timeLeft <= 10 ? Colors.red : Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                _playDailyMode ? 'Challenge' : 'Level ${_currentLevel + 1}',
                style: AppTheme.numberStyle(
                  color: AppTheme.dustyMauve,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double maxBoardSide = min(
                  constraints.maxWidth * 0.88,
                  max(200.0, constraints.maxHeight - 200.0),
                );

                return Column(
                  children: [
                    Text(
                      'Fill entry cells with digits 1-9 to match clues.',
                      style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Center(
                        child: RepaintBoundary(
                          child: Container(
                            width: maxBoardSide,
                            height: maxBoardSide,
                            decoration: BoxDecoration(
                              color: context.bgCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.textMuted.withAlpha(40)),
                            ),
                            child: FogOverlay(
                              enabled: _playDailyMode && _dailyModifierType == 'fog',
                              radius: (maxBoardSide / _gridSize) * _dailyRadius,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: _gridSize,
                                    crossAxisSpacing: 2,
                                    mainAxisSpacing: 2,
                                  ),
                                  itemCount: _gridSize * _gridSize,
                                  itemBuilder: (context, idx) {
                                    int type = _types[idx];
                                    if (type == 0) {
                                      // Solid slate wall
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF181A1F),
                                          border: Border.all(color: Colors.black26, width: 0.5),
                                        ),
                                      );
                                    }

                                    if (type == 2) {
                                      // Clue cell
                                      return CustomPaint(
                                        painter: _KakuroCluePainter(
                                          rightSum: _hClues[idx],
                                          downSum: _vClues[idx],
                                          lineColor: AppTheme.dustyMauve,
                                          textColor: Colors.white,
                                        ),
                                      );
                                    }

                                    // Entry cell (type == 1)
                                    bool isSelected = idx == _selectedIdx;
                                    bool isHinted = idx == _hintIdx;
                                    int val = _grid[idx];

                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedIdx = idx;
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppTheme.dustyMauve.withAlpha(40)
                                              : (isHinted ? Colors.amber.withAlpha(40) : context.bgCard),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppTheme.dustyMauve
                                                : (isHinted
                                                    ? Colors.amber
                                                    : context.textMuted.withAlpha(40)),
                                            width: isSelected || isHinted ? 2 : 0.5,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: AppTheme.dustyMauve.withAlpha(60),
                                                    blurRadius: 6,
                                                  )
                                                ]
                                              : null,
                                        ),
                                        child: Center(
                                          child: Text(
                                            val == 0 ? '' : '$val',
                                            style: GoogleFonts.spaceGrotesk(
                                              fontSize: _gridSize == 4 ? 22 : 18,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? AppTheme.dustyMauve : context.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Number keypad
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.textMuted.withAlpha(30)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (int i = 1; i <= 5; i++) _buildKeypadButton(i),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (int i = 6; i <= 9; i++) _buildKeypadButton(i),
                              _buildEraseButton(),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.bgCard,
                          foregroundColor: context.textPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          setState(() {
                            _grid = List.filled(_gridSize * _gridSize, 0);
                            _selectedIdx = -1;
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_isSuccess)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: _playDailyMode
                      ? ChallengeClearedOverlay(
                          accentColor: AppTheme.dustyMauve,
                          onComplete: () {
                            Navigator.pop(context, true);
                          },
                        )
                      : Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: context.bgCard,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
                              const SizedBox(height: 16),
                              Text(
                                'Level ${_currentLevel + 1} Cleared!',
                                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
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
            ),
        ],
      ),
    );
  }

  void _tryAutoCheck() {
    bool allFilled = true;
    for (int i = 0; i < _types.length; i++) {
      if (_types[i] == 1 && _grid[i] == 0) {
        allFilled = false;
        break;
      }
    }
    if (allFilled) {
      _checkSolution();
    }
  }

  Widget _buildKeypadButton(int val) {
    return GestureDetector(
      onTap: () {
        if (_selectedIdx != -1 && _types[_selectedIdx] == 1) {
          settingsNotifier.hapticTap();
          setState(() {
            _grid[_selectedIdx] = val;
          });
          _tryAutoCheck();
        }
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppTheme.dustyMauve,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '$val',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEraseButton() {
    return GestureDetector(
      onTap: () {
        if (_selectedIdx != -1 && _types[_selectedIdx] == 1) {
          settingsNotifier.hapticTap();
          setState(() {
            _grid[_selectedIdx] = 0;
          });
        }
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.red.shade800,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.backspace_outlined, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _KakuroCluePainter extends CustomPainter {
  final int rightSum; // horizontal run clue (bottom-left triangle)
  final int downSum;  // vertical run clue (top-right triangle)
  final Color lineColor;
  final Color textColor;
  const _KakuroCluePainter({
    required this.rightSum,
    required this.downSum,
    required this.lineColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fill the entire cell with a solid dark grey/slate wall color
    final Paint bgPaint = Paint()
      ..color = const Color(0xFF181A1F)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final bool hasClues = rightSum > 0 || downSum > 0;

    if (hasClues) {
      // Draw slightly darker shading for the bottom-left triangle to give depth split
      final Path path = Path()
        ..moveTo(0, 0)
        ..lineTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..close();
      final Paint fillPaint = Paint()
        ..color = const Color(0xFF111317)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      // Draw the diagonal divider line
      final Paint lp = Paint()
        ..color = lineColor.withOpacity(0.6)
        ..strokeWidth = 1.5
        ..isAntiAlias = true;
      canvas.drawLine(Offset.zero, Offset(size.width, size.height), lp);

      final double fontSize = size.shortestSide * 0.22;

      // rightSum: horizontal clue (top-right triangle in Kakuro)
      if (rightSum > 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$rightSum',
            style: GoogleFonts.spaceGrotesk(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final double cx = size.width * 0.75 - tp.width / 2;
        final double cy = size.height * 0.25 - tp.height / 2;
        tp.paint(canvas, Offset(cx, cy));
      }

      // downSum: vertical clue (bottom-left triangle in Kakuro)
      if (downSum > 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$downSum',
            style: GoogleFonts.spaceGrotesk(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final double cx = size.width * 0.25 - tp.width / 2;
        final double cy = size.height * 0.75 - tp.height / 2;
        tp.paint(canvas, Offset(cx, cy));
      }
    }

    // Draw a subtle border around the clue cell for neat grid alignment
    final Paint borderPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _KakuroCluePainter old) =>
      old.rightSum != rightSum ||
      old.downSum != downSum ||
      old.lineColor != lineColor ||
      old.textColor != textColor;
}
