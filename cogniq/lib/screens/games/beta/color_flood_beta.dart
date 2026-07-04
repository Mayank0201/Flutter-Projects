import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';

class ColorFloodBetaScreen extends StatefulWidget {
  const ColorFloodBetaScreen({super.key});
  @override
  State<ColorFloodBetaScreen> createState() => _ColorFloodBetaScreenState();
}
class _ColorFloodBetaScreenState extends State<ColorFloodBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _grid = List.filled(25, 0); // 5x5 grid of colors (0 to 3)
  int _movesLeft = 10;
  final List<Color> _colors = [Colors.red, Colors.green, Colors.blue, Colors.orange];

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }
  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      _movesLeft = 12 - _currentLevel;
      if (_currentLevel == 0) {
        _grid = [0, 1, 2, 0, 1, 3, 0, 1, 2, 0, 2, 3, 0, 1, 2, 1, 3, 0, 2, 1, 0, 1, 3, 2, 0];
      } else if (_currentLevel == 1) {
        _grid = [1, 2, 0, 3, 1, 0, 1, 2, 0, 3, 2, 3, 1, 0, 2, 1, 0, 3, 2, 1, 0, 3, 2, 1, 0];
      } else if (_currentLevel == 2) {
        _grid = [2, 0, 1, 3, 2, 1, 3, 0, 2, 1, 0, 2, 3, 1, 0, 3, 1, 0, 2, 3, 2, 0, 1, 3, 2];
      } else if (_currentLevel == 3) {
        _grid = [3, 1, 0, 2, 3, 2, 0, 3, 1, 2, 1, 2, 0, 3, 1, 0, 3, 2, 1, 0, 3, 1, 0, 2, 3];
      } else if (_currentLevel == 4) {
        _grid = [0, 2, 3, 1, 0, 1, 3, 0, 2, 1, 2, 0, 1, 3, 2, 3, 1, 2, 0, 3, 0, 2, 3, 1, 0];
      } else if (_currentLevel == 5) {
        _grid = [1, 2, 0, 3, 1, 0, 1, 2, 0, 3, 2, 3, 1, 0, 2, 1, 0, 3, 2, 1, 0, 3, 2, 1, 0].map((e) => (e + 1) % 4).toList();
      } else if (_currentLevel == 6) {
        _grid = [2, 0, 1, 3, 2, 1, 3, 0, 2, 1, 0, 2, 3, 1, 0, 3, 1, 0, 2, 3, 2, 0, 1, 3, 2].map((e) => (e + 2) % 4).toList();
      } else if (_currentLevel == 7) {
        _grid = [3, 1, 0, 2, 3, 2, 0, 3, 1, 2, 1, 2, 0, 3, 1, 0, 3, 2, 1, 0, 3, 1, 0, 2, 3].map((e) => (e + 3) % 4).toList();
      } else if (_currentLevel == 8) {
        _grid = [0, 2, 3, 1, 0, 1, 3, 0, 2, 1, 2, 0, 1, 3, 2, 3, 1, 2, 0, 3, 0, 2, 3, 1, 0].map((e) => (e + 1) % 4).toList();
      } else {
        _grid = [0, 1, 2, 0, 1, 3, 0, 1, 2, 0, 2, 3, 0, 1, 2, 1, 3, 0, 2, 1, 0, 1, 3, 2, 0].map((e) => (e + 2) % 4).toList();
      }
    });
  }
  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_colorflood') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_colorflood', _currentLevel + 1);
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
  void _flood(int targetColor) {
    if (_movesLeft <= 0 || _isSuccess) return;
    int original = _grid[0];
    if (original == targetColor) return;
    List<bool> visited = List.filled(25, false);
    List<int> queue = [0];
    visited[0] = true;
    while (queue.isNotEmpty) {
      int curr = queue.removeAt(0);
      _grid[curr] = targetColor;
      int r = curr ~/ 5; int c = curr % 5;
      var neighbors = [
        if (r > 0) (r - 1) * 5 + c,
        if (r < 4) (r + 1) * 5 + c,
        if (c > 0) r * 5 + c - 1,
        if (c < 4) r * 5 + c + 1,
      ];
      for (int n in neighbors) {
        if (_grid[n] == original && !visited[n]) {
          visited[n] = true;
          queue.add(n);
        }
      }
    }
    setState(() {
      _movesLeft--;
      if (_grid.every((e) => e == targetColor)) {
        _onLevelCleared();
      } else if (_movesLeft == 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No moves left! Reset to try again.')));
      }
    });
  }

  void _showHint() {
    int currentColor = _grid[0];
    List<bool> flooded = List.filled(25, false);
    List<int> queue = [0];
    flooded[0] = true;
    while (queue.isNotEmpty) {
      int curr = queue.removeAt(0);
      int r = curr ~/ 5; int c = curr % 5;
      var neighbors = [
        if (r > 0) (r - 1) * 5 + c,
        if (r < 4) (r + 1) * 5 + c,
        if (c > 0) r * 5 + c - 1,
        if (c < 4) r * 5 + c + 1,
      ];
      for (int nbr in neighbors) {
        if (!flooded[nbr] && _grid[nbr] == currentColor) {
          flooded[nbr] = true;
          queue.add(nbr);
        }
      }
    }
    int bestColor = -1;
    int maxGain = -1;
    for (int col = 0; col < 4; col++) {
      if (col == currentColor) continue;
      int gain = 0;
      for (int i = 0; i < 25; i++) {
        if (flooded[i]) {
          int r = i ~/ 5; int c = i % 5;
          var neighbors = [
            if (r > 0) (r - 1) * 5 + c,
            if (r < 4) (r + 1) * 5 + c,
            if (c > 0) r * 5 + c - 1,
            if (c < 4) r * 5 + c + 1,
          ];
          for (int nbr in neighbors) {
            if (!flooded[nbr] && _grid[nbr] == col) {
              gain++;
            }
          }
        }
      }
      if (gain > maxGain) {
        maxGain = gain;
        bestColor = col;
      }
    }
    String colorName = "Unknown";
    if (bestColor == 0) colorName = "Red";
    if (bestColor == 1) colorName = "Green";
    if (bestColor == 2) colorName = "Blue";
    if (bestColor == 3) colorName = "Orange";
    
    settingsNotifier.hapticTap();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Hint: Try picking $colorName next to flood more cells!'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Color Flood', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Flood the entire board with a single color. Start from the top-left cell (marked with 🏠). Pick a color below to fill all connected cells of the same color. Moves left: $_movesLeft',
                            style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        RepaintBoundary(
                          child: Container(
                            width: 250, height: 250,
                            decoration: BoxDecoration(border: Border.all(color: context.textMuted, width: 2), borderRadius: BorderRadius.circular(12)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
                                itemCount: 25,
                                itemBuilder: (context, idx) {
                                  return Container(
                                    color: _colors[_grid[idx]],
                                    child: idx == 0
                                        ? const Center(
                                            child: Icon(Icons.home, color: Colors.white, size: 24),
                                          )
                                        : null,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(4, (i) {
                            return GestureDetector(
                              onTap: () => _flood(i),
                              child: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: _colors[i],
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            );
                          }),
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
