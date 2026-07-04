import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';

class FutoshikiBetaScreen extends StatefulWidget {
  const FutoshikiBetaScreen({super.key});
  @override
  State<FutoshikiBetaScreen> createState() => _FutoshikiBetaScreenState();
}
class _FutoshikiBetaScreenState extends State<FutoshikiBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _grid = List.filled(16, 0);
  Map<String, String> _ineq = {};
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
        _ineq = {"14-15": "<", "13-14": ">", "8-9": ">"};
      } else if (_currentLevel == 1) {
        _ineq = {"0-4": "<", "4-5": ">", "3-7": ">"};
      } else if (_currentLevel == 2) {
        _ineq = {"7-11": ">", "4-8": "<", "0-4": "<"};
      } else if (_currentLevel == 3) {
        _ineq = {"14-15": "<", "0-1": ">", "8-12": ">"};
      } else if (_currentLevel == 4) {
        _ineq = {"11-15": ">", "0-1": ">", "7-11": "<"};
      } else if (_currentLevel == 5) {
        _ineq = {"0-1": "<", "5-6": "<", "9-13": "<"};
      } else if (_currentLevel == 6) {
        _ineq = {"1-2": "<", "4-8": ">", "14-15": "<"};
      } else if (_currentLevel == 7) {
        _ineq = {"2-3": "<", "5-9": ">", "12-13": ">"};
      } else if (_currentLevel == 8) {
        _ineq = {"0-4": "<", "6-7": "<", "10-14": ">"};
      } else {
        _ineq = {"4-5": "<", "10-11": "<", "12-13": "<"};
      }
    });
  }

  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_futoshiki') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_futoshiki', _currentLevel + 1);
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
    if (_grid.any((e) => e == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill all cells!')));
      return;
    }
    bool isValid = true;
    for (int i = 0; i < 4; i++) {
      var row = [_grid[i*4], _grid[i*4+1], _grid[i*4+2], _grid[i*4+3]];
      var col = [_grid[i], _grid[i+4], _grid[i+8], _grid[i+12]];
      if (row.toSet().length != 4 || col.toSet().length != 4) isValid = false;
    }
    _ineq.forEach((key, sign) {
      var parts = key.split("-");
      int v1 = _grid[int.parse(parts[0])];
      int v2 = _grid[int.parse(parts[1])];
      if (sign == "<" && v1 >= v2) isValid = false;
      if (sign == ">" && v1 <= v2) isValid = false;
    });
    if (isValid) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect solution! Check rows, columns, and inequalities.')));
    }
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text('How to Play Futoshiki', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
        content: Text(
          '1. Fill the 4x4 grid with digits 1 to 4 without repeating in any row or column.\n\n'
          '2. The inequality signs (< or >) between cells must be satisfied by the adjacent numbers.',
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
      [1, 4, 2, 3, 4, 1, 3, 2, 3, 2, 4, 1, 2, 3, 1, 4],
      [2, 4, 1, 3, 3, 1, 4, 2, 4, 3, 2, 1, 1, 2, 3, 4],
      [1, 2, 4, 3, 2, 1, 3, 4, 4, 3, 1, 2, 3, 4, 2, 1],
      [2, 1, 3, 4, 4, 3, 1, 2, 3, 2, 4, 1, 1, 4, 2, 3],
      [3, 2, 1, 4, 2, 4, 3, 1, 4, 1, 2, 3, 1, 3, 4, 2],
      [1, 4, 2, 3, 4, 1, 3, 2, 3, 2, 4, 1, 2, 3, 1, 4],
      [2, 4, 1, 3, 3, 1, 4, 2, 4, 3, 2, 1, 1, 2, 3, 4],
      [1, 2, 4, 3, 2, 1, 3, 4, 4, 3, 1, 2, 3, 4, 2, 1],
      [2, 1, 3, 4, 4, 3, 1, 2, 3, 2, 4, 1, 1, 4, 2, 3],
      [3, 2, 1, 4, 2, 4, 3, 1, 4, 1, 2, 3, 1, 3, 4, 2],
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
        title: Text('Futoshiki', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Fill the grid with 1-4. Satisfy inequalities.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        Container(
                          width: 300, height: 300,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.textMuted.withAlpha(40))),
                          child: LayoutBuilder(builder: (context, constraints) {
                            double cs = constraints.maxWidth / 4;
                            return RepaintBoundary(
                              child: Stack(
                                children: [
                                  for (int r = 0; r < 4; r++)
                                    for (int c = 0; c < 4; c++)
                                      Builder(
                                        builder: (context) {
                                          int cellIdx = r * 4 + c;
                                          return Positioned(
                                            left: c * cs + 4, top: r * cs + 4, width: cs - 8, height: cs - 8,
                                            child: GestureDetector(
                                              onTap: () {
                                                settingsNotifier.hapticTap();
                                                setState(() => _selectedIdx = cellIdx);
                                              },
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: context.bgSurface,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: _selectedIdx == cellIdx ? AppTheme.dustyMauve : Colors.transparent,
                                                    width: _selectedIdx == cellIdx ? 2 : 1,
                                                  ),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    _grid[cellIdx] == 0 ? "" : "${_grid[cellIdx]}",
                                                    style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      ),
                                  ..._ineq.entries.map((entry) {
                                    var parts = entry.key.split("-");
                                    int idx1 = int.parse(parts[0]); int idx2 = int.parse(parts[1]);
                                    int r1 = idx1 ~/ 4; int c1 = idx1 % 4;
                                    int r2 = idx2 ~/ 4; int c2 = idx2 % 4;
                                    double cx = (c1 + c2) / 2 * cs + cs / 2;
                                    double cy = (r1 + r2) / 2 * cs + cs / 2;
                                    return Positioned(
                                      left: cx - 12, top: cy - 12, width: 24, height: 24,
                                      child: Center(child: Text(entry.value, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.dustyMauve))),
                                    );
                                  }).toList(),
                                ],
                              ),
                            );
                          }),
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
                      ],
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
