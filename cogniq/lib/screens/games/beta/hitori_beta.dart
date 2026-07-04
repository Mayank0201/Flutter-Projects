import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';

class HitoriBetaScreen extends StatefulWidget {
  const HitoriBetaScreen({super.key});
  @override
  State<HitoriBetaScreen> createState() => _HitoriBetaScreenState();
}
class _HitoriBetaScreenState extends State<HitoriBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _grid = List.filled(9, 0);
  List<bool> _shaded = List.filled(9, false);

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }
  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      _shaded = List.filled(9, false);
      if (_currentLevel == 0) {
        _grid = [1, 2, 1, 2, 3, 2, 3, 1, 2];
      } else if (_currentLevel == 1) {
        _grid = [2, 2, 1, 1, 3, 2, 3, 1, 3];
      } else if (_currentLevel == 2) {
        _grid = [1, 1, 2, 3, 2, 1, 2, 3, 3];
      } else if (_currentLevel == 3) {
        _grid = [3, 2, 1, 2, 2, 3, 1, 3, 2];
      } else {
        _grid = [1, 3, 2, 3, 2, 1, 2, 1, 3];
      }
    });
  }
  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_hitori') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_hitori', _currentLevel + 1);
    }
    setState(() => _isSuccess = true);
  }
  void _checkSolution() {
    bool isValid = true;
    for (int i = 0; i < 3; i++) {
      List<int> row = []; List<int> col = [];
      for (int j = 0; j < 3; j++) {
        if (!_shaded[i * 3 + j]) row.add(_grid[i * 3 + j]);
        if (!_shaded[j * 3 + i]) col.add(_grid[j * 3 + i]);
      }
      if (row.toSet().length != row.length || col.toSet().length != col.length) {
        isValid = false;
      }
    }
    // Shaded cells cannot be adjacent
    for (int i = 0; i < 9; i++) {
      if (_shaded[i]) {
        int r = i ~/ 3; int c = i % 3;
        if (r < 2 && _shaded[(r + 1) * 3 + c]) isValid = false;
        if (c < 2 && _shaded[r * 3 + c + 1]) isValid = false;
      }
    }
    if (isValid) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No duplicate numbers in rows/cols allowed, and shaded cells cannot touch!')));
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
        title: Text('Hitori', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        Text('Shade cells containing duplicate values so each row and col has no repeats.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary)),
                        const SizedBox(height: 24),
                        Container(
                          width: 240, height: 240,
                          decoration: BoxDecoration(border: Border.all(color: context.textMuted, width: 2)),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
                            itemCount: 9,
                            itemBuilder: (context, idx) {
                              bool shade = _shaded[idx];
                              return GestureDetector(
                                onTap: () => setState(() => _shaded[idx] = !_shaded[idx]),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: shade ? Colors.black : context.bgCard,
                                    border: Border.all(color: Colors.grey.shade800),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${_grid[idx]}',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: shade ? Colors.grey.shade800 : context.textPrimary,
                                      ),
                                    ),
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
