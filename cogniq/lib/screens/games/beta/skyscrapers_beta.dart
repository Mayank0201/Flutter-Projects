import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';

class SkyscrapersBetaScreen extends StatefulWidget {
  const SkyscrapersBetaScreen({super.key});
  @override
  State<SkyscrapersBetaScreen> createState() => _SkyscrapersBetaScreenState();
}

class _SkyscrapersBetaScreenState extends State<SkyscrapersBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _grid = List.filled(9, 0);
  List<int> _topClues = [2, 1, 3];
  List<int> _bottomClues = [2, 0, 1];
  List<int> _leftClues = [0, 1, 3];
  List<int> _rightClues = [2, 2, 0];
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
      _grid = List.filled(9, 0);
      if (_currentLevel == 0) {
        _topClues = [2, 1, 3]; _bottomClues = [2, 0, 1]; _leftClues = [0, 1, 3]; _rightClues = [2, 2, 0];
      } else if (_currentLevel == 1) {
        _topClues = [0, 0, 2]; _bottomClues = [2, 0, 2]; _leftClues = [1, 3, 2]; _rightClues = [2, 1, 0];
      } else if (_currentLevel == 2) {
        _topClues = [2, 2, 1]; _bottomClues = [1, 2, 3]; _leftClues = [2, 2, 0]; _rightClues = [1, 2, 3];
      } else if (_currentLevel == 3) {
        _topClues = [1, 3, 0]; _bottomClues = [2, 1, 2]; _leftClues = [1, 3, 2]; _rightClues = [2, 1, 2];
      } else if (_currentLevel == 4) {
        _topClues = [0, 2, 1]; _bottomClues = [1, 0, 2]; _leftClues = [3, 2, 0]; _rightClues = [0, 2, 0];
      } else if (_currentLevel == 5) {
        _topClues = [2, 1, 3]; _bottomClues = [2, 2, 1]; _leftClues = [2, 1, 3]; _rightClues = [2, 2, 1];
      } else if (_currentLevel == 6) {
        _topClues = [1, 3, 2]; _bottomClues = [2, 1, 2]; _leftClues = [1, 3, 2]; _rightClues = [2, 1, 2];
      } else if (_currentLevel == 7) {
        _topClues = [2, 2, 1]; _bottomClues = [1, 2, 3]; _leftClues = [2, 2, 1]; _rightClues = [1, 2, 3];
      } else if (_currentLevel == 8) {
        _topClues = [1, 3, 2]; _bottomClues = [2, 1, 2]; _leftClues = [1, 3, 2]; _rightClues = [2, 1, 2];
      } else {
        _topClues = [3, 2, 1]; _bottomClues = [1, 2, 2]; _leftClues = [3, 2, 1]; _rightClues = [1, 2, 2];
      }
    });
  }

  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_skyscrapers') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_skyscrapers', _currentLevel + 1);
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
    for (int i = 0; i < 3; i++) {
      var row = [_grid[i*3], _grid[i*3+1], _grid[i*3+2]];
      var col = [_grid[i], _grid[i+3], _grid[i+6]];
      if (row.toSet().length != 3 || col.toSet().length != 3) isValid = false;
    }
    int countVisible(List<int> line) {
      int visible = 0; int maxVal = 0;
      for (int h in line) { if (h > maxVal) { visible++; maxVal = h; } }
      return visible;
    }
    for (int i = 0; i < 3; i++) {
      var row = [_grid[i*3], _grid[i*3+1], _grid[i*3+2]];
      var col = [_grid[i], _grid[i+3], _grid[i+6]];
      if (_leftClues[i] > 0 && countVisible(row) != _leftClues[i]) isValid = false;
      if (_rightClues[i] > 0 && countVisible(row.reversed.toList()) != _rightClues[i]) isValid = false;
      if (_topClues[i] > 0 && countVisible(col) != _topClues[i]) isValid = false;
      if (_bottomClues[i] > 0 && countVisible(col.reversed.toList()) != _bottomClues[i]) isValid = false;
    }
    if (isValid) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect solution! Check block heights and clue visibility.')));
    }
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text('How to Play Skyscrapers', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
        content: Text(
          '1. Fill the 3x3 grid with heights 1 to 3 without repeating in any row or column.\n\n'
          '2. The numbers outside the grid represent clues.\n\n'
          '3. Each clue shows the number of buildings (skyscrapers) visible from that perspective.\n\n'
          '4. Taller buildings block the view of shorter buildings behind them.',
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
      [2, 3, 1, 3, 1, 2, 1, 2, 3],
      [3, 1, 2, 1, 2, 3, 2, 3, 1],
      [2, 1, 3, 1, 3, 2, 3, 2, 1],
      [3, 1, 2, 1, 2, 3, 2, 3, 1],
      [1, 2, 3, 2, 3, 1, 3, 1, 2],
      [2, 3, 1, 3, 1, 2, 1, 2, 3],
      [3, 1, 2, 1, 2, 3, 2, 3, 1],
      [2, 1, 3, 1, 3, 2, 3, 2, 1],
      [3, 1, 2, 1, 2, 3, 2, 3, 1],
      [1, 2, 3, 2, 3, 1, 3, 1, 2],
    ];
    final sol = solutions[_currentLevel];
    int hintCell = -1;
    for (int i = 0; i < 9; i++) {
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
        title: Text('Skyscrapers', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
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
                        Text('Heights 1-3. Border clues show visible skyscrapers.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        Container(
                          width: 300, height: 300,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.textMuted.withAlpha(40))),
                          child: LayoutBuilder(builder: (context, constraints) {
                            double cs = constraints.maxWidth / 5;
                            return Stack(
                              children: [
                                for (int i = 0; i < 3; i++) ...[
                                  if (_topClues[i] > 0) Positioned(left: (i+1)*cs, top: 0, width: cs, height: cs, child: Center(child: Text('${_topClues[i]}', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.dustyMauve)))),
                                  if (_bottomClues[i] > 0) Positioned(left: (i+1)*cs, bottom: 0, width: cs, height: cs, child: Center(child: Text('${_bottomClues[i]}', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.dustyMauve)))),
                                  if (_leftClues[i] > 0) Positioned(left: 0, top: (i+1)*cs, width: cs, height: cs, child: Center(child: Text('${_leftClues[i]}', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.dustyMauve)))),
                                  if (_rightClues[i] > 0) Positioned(right: 0, top: (i+1)*cs, width: cs, height: cs, child: Center(child: Text('${_rightClues[i]}', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.dustyMauve)))),
                                ],
                                  for (int r = 0; r < 3; r++)
                                    for (int c = 0; c < 3; c++)
                                      Builder(
                                        builder: (context) {
                                          int cellIdx = r * 3 + c;
                                          return Positioned(
                                            left: (c + 1) * cs + 4, top: (r + 1) * cs + 4, width: cs - 8, height: cs - 8,
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
                                                    color: _selectedIdx == cellIdx ? AppTheme.dustyMauve : context.textMuted.withAlpha(30),
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
                                ],
                              );
                            }),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (int i = 1; i <= 3; i++) ...[
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
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: context.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.textMuted.withAlpha(20)),
                  ),
                  child: Text(
                    '💡 Rule Details:\n• Each row and column contains each height exactly once.\n• A number outside the grid = how many buildings are visible from that side.\n• Taller buildings hide shorter ones behind them.',
                    style: GoogleFonts.outfit(fontSize: 12, color: context.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),
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
