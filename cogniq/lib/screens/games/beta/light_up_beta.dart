import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';

class LightUpBetaScreen extends StatefulWidget {
  const LightUpBetaScreen({super.key});
  @override
  State<LightUpBetaScreen> createState() => _LightUpBetaScreenState();
}
class _LightUpBetaScreenState extends State<LightUpBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _grid = List.filled(16, 0); // 0: empty, 1: bulb, -1: wall, -2: wall(0), -3: wall(1), -4: wall(2)

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }
  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      if (_currentLevel == 0) {
        _grid = [0, 0, -3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -2, 0, 0];
      } else if (_currentLevel == 1) {
        _grid = [0, -2, 0, 0, 0, 0, 0, -3, 0, 0, 0, 0, 0, 0, -3, 0];
      } else if (_currentLevel == 2) {
        _grid = [-2, 0, 0, 0, 0, 0, -4, 0, 0, -3, 0, 0, 0, 0, 0, -1];
      } else if (_currentLevel == 3) {
        _grid = [0, 0, 0, -3, 0, -1, 0, 0, 0, 0, -2, 0, -3, 0, 0, 0];
      } else if (_currentLevel == 4) {
        _grid = [0, 0, -4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -3, 0, 0];
      } else if (_currentLevel == 5) {
        _grid = [0, 0, -3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -2, 0, 0];
      } else if (_currentLevel == 6) {
        _grid = [0, -2, 0, 0, 0, 0, 0, -3, 0, 0, 0, 0, 0, 0, -3, 0];
      } else if (_currentLevel == 7) {
        _grid = [-2, 0, 0, 0, 0, 0, -4, 0, 0, -3, 0, 0, 0, 0, 0, -1];
      } else if (_currentLevel == 8) {
        _grid = [0, 0, 0, -3, 0, -1, 0, 0, 0, 0, -2, 0, -3, 0, 0, 0];
      } else {
        _grid = [0, 0, -4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -3, 0, 0];
      }
    });
  }
  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_lightup') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_lightup', _currentLevel + 1);
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
  List<bool> _calculateLitCells() {
    List<bool> lit = List.filled(16, false);
    for (int idx = 0; idx < 16; idx++) {
      if (_grid[idx] == 1) {
        lit[idx] = true;
        int r = idx ~/ 4; int c = idx % 4;
        for (int y = r - 1; y >= 0; y--) {
          if (_grid[y * 4 + c] < 0) break;
          lit[y * 4 + c] = true;
        }
        for (int y = r + 1; y < 4; y++) {
          if (_grid[y * 4 + c] < 0) break;
          lit[y * 4 + c] = true;
        }
        for (int x = c - 1; x >= 0; x--) {
          if (_grid[r * 4 + x] < 0) break;
          lit[r * 4 + x] = true;
        }
        for (int x = c + 1; x < 4; x++) {
          if (_grid[r * 4 + x] < 0) break;
          lit[r * 4 + x] = true;
        }
      }
    }
    return lit;
  }

  void _checkSolution() {
    bool isValid = true;
    for (int idx = 0; idx < 16; idx++) {
      int cell = _grid[idx];
      if (cell == -1 || cell == -2 || cell == -3 || cell == -4) {
        int req = cell == -2 ? 0 : (cell == -3 ? 1 : (cell == -4 ? 2 : -1));
        if (req >= 0) {
          int count = 0;
          int r = idx ~/ 4; int c = idx % 4;
          if (r > 0 && _grid[(r - 1) * 4 + c] == 1) count++;
          if (r < 3 && _grid[(r + 1) * 4 + c] == 1) count++;
          if (c > 0 && _grid[r * 4 + c - 1] == 1) count++;
          if (c < 3 && _grid[r * 4 + c + 1] == 1) count++;
          if (count != req) isValid = false;
        }
      }
    }
    List<bool> lit = List.filled(16, false);
    bool bulbShinesOnAnother = false;
    for (int idx = 0; idx < 16; idx++) {
      if (_grid[idx] == 1) {
        lit[idx] = true;
        int r = idx ~/ 4; int c = idx % 4;
        for (int y = r - 1; y >= 0; y--) {
          if (_grid[y * 4 + c] < 0) break;
          if (_grid[y * 4 + c] == 1) bulbShinesOnAnother = true;
          lit[y * 4 + c] = true;
        }
        for (int y = r + 1; y < 4; y++) {
          if (_grid[y * 4 + c] < 0) break;
          if (_grid[y * 4 + c] == 1) bulbShinesOnAnother = true;
          lit[y * 4 + c] = true;
        }
        for (int x = c - 1; x >= 0; x--) {
          if (_grid[r * 4 + x] < 0) break;
          if (_grid[r * 4 + x] == 1) bulbShinesOnAnother = true;
          lit[r * 4 + x] = true;
        }
        for (int x = c + 1; x < 4; x++) {
          if (_grid[r * 4 + x] < 0) break;
          if (_grid[r * 4 + x] == 1) bulbShinesOnAnother = true;
          lit[r * 4 + x] = true;
        }
      }
    }
    if (bulbShinesOnAnother) isValid = false;
    for (int idx = 0; idx < 16; idx++) {
      if (_grid[idx] >= 0 && !lit[idx]) isValid = false;
    }
    if (isValid) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect bulb positions or unlit cells!')));
    }
  }

  void _showHint() {
    final solutions = [
      [0, 3, 5, 10],
      [3, 4, 9, 15],
      [2, 5, 11, 12],
      [0, 7, 13],
      [0, 3, 6, 9],
      [0, 3, 5, 10],
      [3, 4, 9, 15],
      [2, 5, 11, 12],
      [0, 7, 13],
      [0, 3, 6, 9],
    ];
    final sol = solutions[_currentLevel];
    int hintCell = -1;
    for (int cellIdx in sol) {
      if (_grid[cellIdx] != 1) {
        hintCell = cellIdx;
        break;
      }
    }
    if (hintCell != -1) {
      setState(() {
        _grid[hintCell] = 1;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All bulbs are already placed!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final litCells = _calculateLitCells();
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Light Up', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
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
                        Text('Place bulbs to illuminate all empty squares. Bulbs cannot shine on each other.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary)),
                        const SizedBox(height: 24),
                        Container(
                          width: 280, height: 280,
                          decoration: BoxDecoration(border: Border.all(color: context.textMuted, width: 2)),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
                            itemCount: 16,
                            itemBuilder: (context, idx) {
                              int cell = _grid[idx];
                              bool isWall = cell < 0;
                              String wallText = cell == -2 ? '0' : (cell == -3 ? '1' : (cell == -4 ? '2' : ''));
                              return GestureDetector(
                                onTap: isWall ? null : () => setState(() {
                                  _grid[idx] = _grid[idx] == 0 ? 1 : 0;
                                }),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isWall
                                        ? Colors.black
                                        : context.bgCard,
                                    border: Border.all(color: Colors.grey.shade900),
                                  ),
                                  child: Stack(
                                    children: [
                                      if (!isWall && litCells[idx])
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: RadialGradient(
                                                colors: [
                                                  Colors.amber.withOpacity(_grid[idx] == 1 ? 0.45 : 0.22),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      Center(
                                        child: isWall
                                            ? Text(wallText, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))
                                            : (_grid[idx] == 1 ? Icon(Icons.lightbulb, color: Colors.amber.shade400, size: 24) : null),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
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
