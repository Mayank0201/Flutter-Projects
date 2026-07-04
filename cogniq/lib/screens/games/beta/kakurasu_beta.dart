import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';

class KakurasuBetaScreen extends StatefulWidget {
  const KakurasuBetaScreen({super.key});
  @override
  State<KakurasuBetaScreen> createState() => _KakurasuBetaScreenState();
}
class _KakurasuBetaScreenState extends State<KakurasuBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<bool> _shaded = List.filled(9, false);
  List<int> _rowTargets = [3, 2, 4];
  List<int> _colTargets = [2, 3, 4];

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
        _rowTargets = [3, 2, 4]; _colTargets = [2, 3, 4];
      } else if (_currentLevel == 1) {
        _rowTargets = [1, 5, 2]; _colTargets = [4, 1, 3];
      } else if (_currentLevel == 2) {
        _rowTargets = [4, 2, 5]; _colTargets = [3, 5, 3];
      } else if (_currentLevel == 3) {
        _rowTargets = [2, 4, 3]; _colTargets = [5, 2, 2];
      } else {
        _rowTargets = [3, 3, 3]; _colTargets = [3, 3, 3];
      }
    });
  }
  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_kakurasu') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_kakurasu', _currentLevel + 1);
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
      int sum = 0;
      for (int c = 0; c < 3; c++) {
        if (_shaded[r * 3 + c]) sum += (c + 1);
      }
      if (sum != _rowTargets[r]) isValid = false;
    }
    for (int c = 0; c < 3; c++) {
      int sum = 0;
      for (int r = 0; r < 3; r++) {
        if (_shaded[r * 3 + c]) sum += (r + 1);
      }
      if (sum != _colTargets[c]) isValid = false;
    }
    if (isValid) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Target sums not matched!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Kakurasu', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        Text('Shade squares to make row and column sums match targets. Values: Col 1=1, Col 2=2, Col 3=3.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary)),
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
                              // Row indices: Col 1-3 has values 1-3. Col 4 is target, Col 0 is indicator.
                              if (r == 0 || r == 4 || c == 0 || c == 4) {
                                if (r == 0 && c > 0 && c < 4) return Center(child: Text('$c', style: GoogleFonts.spaceGrotesk(color: Colors.grey)));
                                if (c == 0 && r > 0 && r < 4) return Center(child: Text('$r', style: GoogleFonts.spaceGrotesk(color: Colors.grey)));
                                if (r > 0 && r < 4 && c == 4) return Center(child: Text('${_rowTargets[r - 1]}', style: GoogleFonts.spaceGrotesk(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold)));
                                if (c > 0 && c < 4 && r == 4) return Center(child: Text('${_colTargets[c - 1]}', style: GoogleFonts.spaceGrotesk(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold)));
                                return const SizedBox.shrink();
                              }
                              int gridIdx = (r - 1) * 3 + (c - 1);
                              bool shade = _shaded[gridIdx];
                              return GestureDetector(
                                onTap: () => setState(() => _shaded[gridIdx] = !_shaded[gridIdx]),
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: shade ? AppTheme.dustyMauve : context.bgSurface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade800),
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
