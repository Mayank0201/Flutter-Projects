import 'dart:math';
import 'dart:convert';
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

class HitoriScreen extends StatefulWidget {
  const HitoriScreen({super.key});

  @override
  State<HitoriScreen> createState() => _HitoriScreenState();
}

class _HitoriScreenState extends State<HitoriScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  double _dailyRadius = 1.5;
  int _gridSize = 4; // 4, 6, or 8 based on level

  List<int> _grid = []; // Cell values
  List<bool> _shaded = []; // Player's shaded cells
  List<bool> _markedWhite = []; // Player's marked-to-keep-white cells (circle helper)
  List<bool> _solution = []; // Correct solution shaded mask

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgressAndGenerate();
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

    int level = prefs.getInt(PrefsKeys.gameLevel('hitori')) ?? 0;
    if (mounted) {
      setState(() {
        _currentLevel = level;
        _isLoading = true;
      });
      _generatePuzzle();
    }
  }

  void _generatePuzzle() {
    if (_currentLevel < 5) {
      _gridSize = 4;
    } else if (_currentLevel < 12) {
      _gridSize = 6;
    } else {
      _gridSize = 8;
    }

    final totalCells = _gridSize * _gridSize;
    final rand = Random();
    bool generated = false;

    for (int attempt = 0; attempt < 100; attempt++) {
      // 1. Generate a valid solution mask (shaded positions)
      List<bool> solMask = _generateValidSolutionMask(rand);

      // 2. Populate cell values based on the mask
      List<int> board = _populateBoardValues(solMask, rand);

      // 3. Verify that Hitori rules yield a unique solution
      if (_hasUniqueSolution(board, solMask)) {
        _grid = board;
        _solution = solMask;
        _shaded = List.filled(totalCells, false);
        _markedWhite = List.filled(totalCells, false);
        generated = true;
        break;
      }
    }

    if (!generated) {
      // Fallback puzzle if generator timed out
      _gridSize = 4;
      _grid = [1, 3, 2, 2, 3, 2, 1, 2, 1, 3, 2, 4, 4, 2, 1, 3];
      _solution = [
        false, true, false, false,
        true, false, false, true,
        false, false, true, false,
        false, true, false, false
      ];
      _shaded = List.filled(16, false);
      _markedWhite = List.filled(16, false);
    }

    setState(() {
      _isSuccess = false;
      _isLoading = false;
    });
  }

  List<bool> _generateValidSolutionMask(Random rand) {
    final totalCells = _gridSize * _gridSize;
    List<bool> mask = List.filled(totalCells, false);

    // Randomly select some cells to shade, keeping adjacency and connectivity intact
    for (int i = 0; i < totalCells; i++) {
      if (rand.nextDouble() < 0.25) {
        // Check if shading violates adjacency rule
        if (_hasAdjacentShaded(mask, i)) continue;

        mask[i] = true;
        // Check if connectivity is broken
        if (!_isFullyConnected(mask)) {
          mask[i] = false; // rollback
        }
      }
    }
    return mask;
  }

  bool _hasAdjacentShaded(List<bool> mask, int idx) {
    int r = idx ~/ _gridSize;
    int c = idx % _gridSize;
    // Check Left
    if (c > 0 && mask[idx - 1]) return true;
    // Check Right
    if (c < _gridSize - 1 && mask[idx + 1]) return true;
    // Check Up
    if (r > 0 && mask[idx - _gridSize]) return true;
    // Check Down
    if (r < _gridSize - 1 && mask[idx + _gridSize]) return true;
    return false;
  }

  bool _isFullyConnected(List<bool> mask) {
    final totalCells = mask.length;
    int start = -1;
    for (int i = 0; i < totalCells; i++) {
      if (!mask[i]) {
        start = i;
        break;
      }
    }
    if (start == -1) return false;

    List<bool> visited = List.filled(totalCells, false);
    List<int> queue = [start];
    visited[start] = true;
    int count = 1;

    int qHead = 0;
    while (qHead < queue.length) {
      int idx = queue[qHead++];
      int r = idx ~/ _gridSize;
      int c = idx % _gridSize;

      // Neighbors
      final neighbors = <int>[];
      if (c > 0) neighbors.add(idx - 1);
      if (c < _gridSize - 1) neighbors.add(idx + 1);
      if (r > 0) neighbors.add(idx - _gridSize);
      if (r < _gridSize - 1) neighbors.add(idx + _gridSize);

      for (final n in neighbors) {
        if (!mask[n] && !visited[n]) {
          visited[n] = true;
          queue.add(n);
          count++;
        }
      }
    }

    int totalUnshaded = mask.where((shaded) => !shaded).length;
    return count == totalUnshaded;
  }

  List<int> _populateBoardValues(List<bool> mask, Random rand) {
    final totalCells = mask.length;
    List<int> board = List.filled(totalCells, 0);

    // Fill row-by-row
    for (int r = 0; r < _gridSize; r++) {
      List<int> available = List.generate(_gridSize, (i) => i + 1)..shuffle(rand);
      for (int c = 0; c < _gridSize; c++) {
        int idx = r * _gridSize + c;
        if (!mask[idx]) {
          board[idx] = available.removeLast();
        }
      }
    }

    // For shaded cells, place duplicate values in row or col
    for (int idx = 0; idx < totalCells; idx++) {
      if (mask[idx]) {
        int r = idx ~/ _gridSize;
        int c = idx % _gridSize;

        // Choose to duplicate row or column value
        bool duplicateRow = rand.nextBool();
        List<int> candidates = [];

        if (duplicateRow) {
          // Find unshaded values in row
          for (int x = 0; x < _gridSize; x++) {
            int targetIdx = r * _gridSize + x;
            if (!mask[targetIdx] && board[targetIdx] > 0) {
              candidates.add(board[targetIdx]);
            }
          }
        } else {
          // Find unshaded values in col
          for (int y = 0; y < _gridSize; y++) {
            int targetIdx = y * _gridSize + c;
            if (!mask[targetIdx] && board[targetIdx] > 0) {
              candidates.add(board[targetIdx]);
            }
          }
        }

        if (candidates.isEmpty) {
          board[idx] = rand.nextInt(_gridSize) + 1;
        } else {
          board[idx] = candidates[rand.nextInt(candidates.length)];
        }
      }
    }
    return board;
  }

  bool _hasUniqueSolution(List<int> board, List<bool> solMask) {
    // A simplified unique-checker: backtracks to find all solutions.
    int solutionsCount = 0;

    void solve(List<bool> mask, int idx) {
      if (solutionsCount > 1) return;
      if (idx >= mask.length) {
        if (_checkHitoriRules(board, mask)) {
          solutionsCount++;
        }
        return;
      }

      // Option A: Keep cell unshaded
      mask[idx] = false;
      solve(mask, idx + 1);

      // Option B: Shade cell (if valid)
      if (!_hasAdjacentShaded(mask, idx)) {
        mask[idx] = true;
        // incremental check
        if (_isFullyConnected(mask)) {
          solve(mask, idx + 1);
        }
        mask[idx] = false;
      }
    }

    solve(List.filled(board.length, false), 0);
    return solutionsCount == 1;
  }

  bool _checkHitoriRules(List<int> board, List<bool> mask) {
    // 1. Shaded adjacency check
    for (int i = 0; i < mask.length; i++) {
      if (mask[i]) {
        if (_hasAdjacentShaded(mask, i)) return false;
      }
    }

    // 2. Connectivity check
    if (!_isFullyConnected(mask)) return false;

    // 3. Row/Col duplicates check (no duplicates in unshaded cells)
    for (int r = 0; r < _gridSize; r++) {
      final seen = <int>{};
      for (int c = 0; c < _gridSize; c++) {
        int idx = r * _gridSize + c;
        if (!mask[idx]) {
          if (seen.contains(board[idx])) return false;
          seen.add(board[idx]);
        }
      }
    }

    for (int c = 0; c < _gridSize; c++) {
      final seen = <int>{};
      for (int r = 0; r < _gridSize; r++) {
        int idx = r * _gridSize + c;
        if (!mask[idx]) {
          if (seen.contains(board[idx])) return false;
          seen.add(board[idx]);
        }
      }
    }

    return true;
  }

  void _checkSolution() {
    if (_checkHitoriRules(_grid, _shaded)) {
      settingsNotifier.hapticSuccess();
      _onLevelCleared();
    } else {
      settingsNotifier.hapticError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect solution! Ensure shaded cells do not touch orthogonally, all unshaded cells are connected, and no duplicates exist.'),
        ),
      );
    }
  }

  Future<void> _onLevelCleared() async {
    if (!_playDailyMode) {
      final prefs = await SharedPreferences.getInstance();
      int highest = prefs.getInt('beta_level_hitori') ?? 0;
      if (_currentLevel + 1 > highest) {
        await prefs.setInt('beta_level_hitori', _currentLevel + 1);
      }
      await prefs.setInt(PrefsKeys.gameLevel('hitori'), _currentLevel + 1);
      
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
    int hintCell = -1;
    for (int i = 0; i < _shaded.length; i++) {
      if (_shaded[i] != _solution[i]) {
        hintCell = i;
        break;
      }
    }

    if (hintCell != -1) {
      final hints = await HintManager.getHints('hitori');
      if (hints > 0) {
        await HintManager.useHint('hitori');
        setState(() {
          _shaded[hintCell] = _solution[hintCell];
          _markedWhite[hintCell] = !_solution[hintCell];
        });
      } else {
        BuyHintsDialog.show(context, initialGameId: 'hitori', onPurchaseComplete: () {
          setState(() {});
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The board matches correct solution!')),
      );
    }
  }

  void _toggleCellState(int idx) {
    settingsNotifier.hapticTap();
    setState(() {
      if (!_shaded[idx] && !_markedWhite[idx]) {
        // Normal -> Shaded
        _shaded[idx] = true;
      } else if (_shaded[idx]) {
        // Shaded -> Marked White
        _shaded[idx] = false;
        _markedWhite[idx] = true;
      } else {
        // Marked White -> Normal
        _markedWhite[idx] = false;
      }
    });
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text(
          'How to Play Hitori',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        content: Text(
          '1. Shade duplicate numbers in rows and columns so each remains unique.\n\n'
          '2. Shaded (black) cells cannot touch horizontally or vertically.\n\n'
          '3. All unshaded (white) cells must connect in a single continuous group.\n\n'
          '💡 Tap cells to toggle states: White ➔ Shaded ➔ Keep Circle.',
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
        title: Text('Hitori', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Eliminate duplicates. Tap to cycle: Normal ➔ Shaded ➔ Circle.',
                          style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        RepaintBoundary(
                          child: Container(
                            width: boardSize,
                            height: boardSize,
                            decoration: BoxDecoration(
                              color: context.bgCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.textMuted.withAlpha(40)),
                            ),
                            child: FogOverlay(
                              enabled: _playDailyMode && _dailyModifierType == 'fog',
                              radius: (boardSize / _gridSize) * _dailyRadius,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _gridSize,
                                ),
                                itemCount: _gridSize * _gridSize,
                                itemBuilder: (context, idx) {
                                  final cellVal = _grid[idx];
                                  final isShaded = _shaded[idx];
                                  final isMarked = _markedWhite[idx];

                                  return Semantics(
                                    label: 'Cell row ${idx ~/ _gridSize + 1}, column ${idx % _gridSize + 1}. '
                                        'Value $cellVal. '
                                        '${isShaded ? "Shaded/Black" : isMarked ? "Marked to keep white" : "Unshaded"}.',
                                    child: GestureDetector(
                                      onTap: () => _toggleCellState(idx),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        decoration: BoxDecoration(
                                          color: isShaded ? Colors.grey[900] : context.bgCard,
                                          border: Border.all(
                                            color: context.textMuted.withAlpha(40),
                                            width: 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              if (isMarked)
                                                Container(
                                                  width: boardSize / (_gridSize * 1.5),
                                                  height: boardSize / (_gridSize * 1.5),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: AppTheme.dustyMauve.withAlpha(160),
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),
                                              Text(
                                                "$cellVal",
                                                style: GoogleFonts.spaceGrotesk(
                                                  fontSize: _gridSize == 4 ? 24 : 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: isShaded
                                                      ? Colors.white30
                                                      : context.textPrimary,
                                                ),
                                              ),
                                            ],
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
                      const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.textMuted.withAlpha(20)),
                          ),
                          child: Text(
                            '💡 Tap cycle guide:\n'
                            '• First Tap: Shades the cell black.\n'
                            '• Second Tap: Draws a circle helper (locks cell white).\n'
                            '• Third Tap: Returns to default.',
                            style: GoogleFonts.outfit(fontSize: 12, color: context.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.bgCard,
                        foregroundColor: context.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          _shaded = List.filled(_gridSize * _gridSize, false);
                          _markedWhite = List.filled(_gridSize * _gridSize, false);
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.dustyMauve,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _checkSolution,
                      icon: const Icon(Icons.check),
                      label: const Text('Check'),
                    ),
                  ],
                ),
              ],
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
}
