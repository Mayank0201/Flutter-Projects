import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';

class KillerSudokuBetaScreen extends StatefulWidget {
  const KillerSudokuBetaScreen({super.key});
  @override
  State<KillerSudokuBetaScreen> createState() => _KillerSudokuBetaScreenState();
}
class _KillerSudokuBetaScreenState extends State<KillerSudokuBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _grid = List.filled(16, 0);
  List<int> _cages = [0, 0, 1, 1, 0, 2, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4];
  List<int> _cageSums = [9, 4, 7, 3, 9, 4, 4];
  int _selectedIdx = -1;

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      _selectedIdx = -1;
      _grid = List.filled(16, 0);
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
    });
  }

  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_killersudoku') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_killersudoku', _currentLevel + 1);
    }
    setState(() => _isSuccess = true);
  }

  void _nextLevel() {
    if (_currentLevel < 9) {
      setState(() {
        _currentLevel++;
        _loadLevel();
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _checkSolution() {
    bool isValid = true;
    for (int i = 0; i < 16; i++) {
      if (_grid[i] == 0) isValid = false;
    }
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill all cells!')));
      return;
    }
    for (int i = 0; i < 4; i++) {
      var row = [_grid[i*4], _grid[i*4+1], _grid[i*4+2], _grid[i*4+3]];
      var col = [_grid[i], _grid[i+4], _grid[i+8], _grid[i+12]];
      if (row.toSet().length != 4 || col.toSet().length != 4) isValid = false;
    }
    // Check 2x2 boxes
    for (int r = 0; r < 4; r += 2) {
      for (int c = 0; c < 4; c += 2) {
        var box = [
          _grid[r * 4 + c],
          _grid[r * 4 + c + 1],
          _grid[(r + 1) * 4 + c],
          _grid[(r + 1) * 4 + c + 1]
        ];
        if (box.toSet().length != 4) isValid = false;
      }
    }
    Map<int, List<int>> cageVals = {};
    for (int i = 0; i < 16; i++) {
      cageVals.putIfAbsent(_cages[i], () => []).add(_grid[i]);
    }
    cageVals.forEach((cageId, vals) {
      int sum = vals.reduce((a, b) => a + b);
      if (sum != _cageSums[cageId] || vals.toSet().length != vals.length) {
        isValid = false;
      }
    });
    if (isValid) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect solution. Check rows, columns, 2x2 boxes, and cage rules.')));
    }
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

  void _showHint() {
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
    final sol = solutions[_currentLevel];
    int hintCell = -1;
    for (int i = 0; i < 16; i++) {
      if (_grid[i] != sol[i]) {
        hintCell = i;
        break;
      }
    }
    
    if (hintCell != -1) {
      setState(() {
        _grid[hintCell] = sol[hintCell];
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
            child: Center(child: Text('Level ${_currentLevel + 1}/10', style: AppTheme.numberStyle(color: AppTheme.dustyMauve, fontSize: 14, fontWeight: FontWeight.bold))),
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
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Fill the 4x4 grid with digits 1-4. Cages must sum to the target value without repeating digits.',
                            style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                            RepaintBoundary(
                              child: Container(
                                width: 280, height: 280,
                                decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.textMuted.withAlpha(40))),
                                child: GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
                                  itemCount: 16,
                                  itemBuilder: (context, idx) {
                                    int cageId = _cages[idx];
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
                                            top: BorderSide(color: idx >= 4 && _cages[idx - 4] == cageId ? Colors.transparent : Colors.black, width: 1.5),
                                            bottom: BorderSide(color: idx < 12 && _cages[idx + 4] == cageId ? Colors.transparent : Colors.black, width: 1.5),
                                            left: BorderSide(color: idx % 4 > 0 && _cages[idx - 1] == cageId ? Colors.transparent : Colors.black, width: 1.5),
                                            right: BorderSide(color: idx % 4 < 3 && _cages[idx + 1] == cageId ? Colors.transparent : Colors.black, width: 1.5),
                                          ),
                                        ),
                                        child: Stack(
                                          children: [
                                            if (isCageStart)
                                              Positioned(top: 2, left: 2, child: Text('${_cageSums[cageId]}', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold))),
                                            Center(
                                              child: Text(
                                                _grid[idx] == 0 ? "" : "${_grid[idx]}",
                                                style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
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
                                for (int i = 1; i <= 4; i++) ...[
                                  GestureDetector(
                                    onTap: () {
                                      if (_selectedIdx != -1) {
                                        settingsNotifier.hapticTap();
                                        setState(() {
                                          _grid[_selectedIdx] = i;
                                        });
                                      }
                                    },
                                    child: Container(
                                      width: 44, height: 44,
                                      margin: const EdgeInsets.symmetric(horizontal: 6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.dustyMauve,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text('$i', style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                    ),
                                  ),
                                ],
                                GestureDetector(
                                  onTap: () {
                                    if (_selectedIdx != -1) {
                                      settingsNotifier.hapticTap();
                                      setState(() {
                                        _grid[_selectedIdx] = 0;
                                      });
                                    }
                                  },
                                  child: Container(
                                    width: 44, height: 44,
                                    margin: const EdgeInsets.symmetric(horizontal: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade800,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.clear, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.bgCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.textMuted.withAlpha(20)),
                              ),
                              child: Text(
                                '💡 Rule Details:\n• Sudoku rules: Row, column, and 2x2 boxes must contain 1, 2, 3, 4 without duplicates.\n• Cage sums: Dotted cage values must add up to the corner target number.\n• Cage duplicates: No number can repeat within a single cage.',
                                style: GoogleFonts.outfit(fontSize: 12, color: context.textSecondary),
                              ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: context.bgCard, foregroundColor: context.textPrimary),
                      onPressed: _loadLevel, icon: const Icon(Icons.refresh), label: const Text('Reset'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dustyMauve, foregroundColor: Colors.white),
                      onPressed: _checkSolution, icon: const Icon(Icons.check), label: const Text('Check'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isSuccess)
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
    );
  }
}
