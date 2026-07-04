import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';

class TentAndTreesBetaScreen extends StatefulWidget {
  const TentAndTreesBetaScreen({super.key});
  @override
  State<TentAndTreesBetaScreen> createState() => _TentAndTreesBetaScreenState();
}
class _TentAndTreesBetaScreenState extends State<TentAndTreesBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _grid = List.filled(16, 0); // 0: empty, 1: tree, 2: tent
  List<int> _rowCounts = [0, 0, 0, 0];
  List<int> _colCounts = [0, 0, 0, 0];

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }
  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      _grid = List.filled(16, 0);
      if (_currentLevel == 0) {
        _grid[2] = 1; _grid[9] = 1;
        _rowCounts = [1, 0, 1, 0];
        _colCounts = [0, 1, 0, 1];
      } else if (_currentLevel == 1) {
        _grid[0] = 1; _grid[11] = 1;
        _rowCounts = [0, 1, 0, 1];
        _colCounts = [1, 0, 1, 0];
      } else if (_currentLevel == 2) {
        _grid[5] = 1; _grid[10] = 1;
        _rowCounts = [1, 0, 0, 1];
        _colCounts = [0, 1, 1, 0];
      } else if (_currentLevel == 3) {
        _grid[1] = 1; _grid[14] = 1;
        _rowCounts = [0, 1, 1, 0];
        _colCounts = [1, 0, 0, 1];
      } else {
        _grid[2] = 1; _grid[8] = 1;
        _rowCounts = [0, 1, 1, 0];
        _colCounts = [1, 0, 1, 0];
      }
    });
  }
  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_tentandtrees') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_tentandtrees', _currentLevel + 1);
    }
    setState(() => _isSuccess = true);
  }
  void _checkSolution() {
    bool isValid = true;
    for (int r = 0; r < 4; r++) {
      int count = 0;
      for (int c = 0; c < 4; c++) {
        if (_grid[r * 4 + c] == 2) count++;
      }
      if (count != _rowCounts[r]) isValid = false;
    }
    for (int c = 0; c < 4; c++) {
      int count = 0;
      for (int r = 0; r < 4; r++) {
        if (_grid[r * 4 + c] == 2) count++;
      }
      if (count != _colCounts[c]) isValid = false;
    }
    if (isValid) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tent counts do not match row/col clues!')));
    }
  }

    void _nextLevel() {
    if (_currentLevel < 4) {
      setState(() {
        _currentLevel++;
        _loadLevel();
      });
    } else {
      Navigator.pop(context);
    }
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Tent & Trees', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('Level ${_currentLevel + 1}/5', style: AppTheme.numberStyle(color: AppTheme.dustyMauve, fontSize: 14, fontWeight: FontWeight.bold))),
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
                        Text('Place tents adjacent to trees. Tents cannot touch each other.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary)),
                        const SizedBox(height: 24),
                        Container(
                          width: 320, height: 320,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(12)),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
                            itemCount: 25,
                            itemBuilder: (context, idx) {
                              int r = idx ~/ 5; int c = idx % 5;
                              if (r == 4 && c == 4) return const SizedBox.shrink();
                              if (r == 4) {
                                return Center(child: Text('${_colCounts[c]}', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.dustyMauve)));
                              }
                              if (c == 4) {
                                return Center(child: Text('${_rowCounts[r]}', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.dustyMauve)));
                              }
                              int gridIdx = r * 4 + c;
                              int cell = _grid[gridIdx];
                              return GestureDetector(
                                onTap: cell == 1 ? null : () => setState(() {
                                  _grid[gridIdx] = _grid[gridIdx] == 0 ? 2 : 0;
                                }),
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: context.bgSurface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade800),
                                  ),
                                  child: Center(
                                    child: cell == 1
                                        ? const Icon(Icons.park, color: Colors.green)
                                        : (cell == 2 ? const Icon(Icons.home, color: Colors.amber) : null),
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
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dustyMauve, foregroundColor: Colors.white),
                        onPressed: _nextLevel,
                        child: Text(_currentLevel < 4 ? 'Next Level' : 'Finish'),
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
