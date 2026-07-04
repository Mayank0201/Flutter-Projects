import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';

class ThermometersBetaScreen extends StatefulWidget {
  const ThermometersBetaScreen({super.key});
  @override
  State<ThermometersBetaScreen> createState() => _ThermometersBetaScreenState();
}
class _ThermometersBetaScreenState extends State<ThermometersBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _grid = List.filled(9, 0); // 0: empty, 1: mercury
  List<int> _rowTargets = [1, 2, 2];
  List<int> _colTargets = [2, 1, 2];

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }
  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      _grid = List.filled(9, 0);
      if (_currentLevel == 0) {
        _rowTargets = [1, 2, 2]; _colTargets = [2, 1, 2];
      } else if (_currentLevel == 1) {
        _rowTargets = [2, 1, 1]; _colTargets = [1, 2, 1];
      } else if (_currentLevel == 2) {
        _rowTargets = [3, 1, 2]; _colTargets = [2, 2, 2];
      } else if (_currentLevel == 3) {
        _rowTargets = [2, 2, 2]; _colTargets = [2, 2, 2];
      } else {
        _rowTargets = [1, 1, 1]; _colTargets = [1, 1, 1];
      }
    });
  }
  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_thermometers') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_thermometers', _currentLevel + 1);
    }
    setState(() => _isSuccess = true);
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
  void _checkSolution() {
    bool isValid = true;
    for (int r = 0; r < 3; r++) {
      int count = 0;
      for (int c = 0; c < 3; c++) {
        if (_grid[r * 3 + c] == 1) count++;
      }
      if (count != _rowTargets[r]) isValid = false;
    }
    for (int c = 0; c < 3; c++) {
      int count = 0;
      for (int r = 0; r < 3; r++) {
        if (_grid[r * 3 + c] == 1) count++;
      }
      if (count != _colTargets[c]) isValid = false;
    }
    if (isValid) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mercury levels do not match row/col clues!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Thermometers', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        Text('Fill thermometers from bulb up to match row and col counts.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary)),
                        const SizedBox(height: 24),
                        Container(
                          width: 320, height: 320,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(12)),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
                            itemCount: 16,
                            itemBuilder: (context, idx) {
                              int r = idx ~/ 4; int c = idx % 4;
                              if (r == 3 && c == 3) return const SizedBox.shrink();
                              if (r == 3) {
                                return Center(child: Text('${_colTargets[c]}', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.dustyMauve)));
                              }
                              if (c == 3) {
                                return Center(child: Text('${_rowTargets[r]}', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.dustyMauve)));
                              }
                              int gridIdx = r * 3 + c;
                              bool isMercury = _grid[gridIdx] == 1;
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _grid[gridIdx] = _grid[gridIdx] == 0 ? 1 : 0;
                                }),
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isMercury ? Colors.red : context.bgSurface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade800),
                                  ),
                                  child: Center(
                                    child: r == 2
                                        ? const Icon(Icons.circle, size: 12, color: Colors.white)
                                        : null,
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
