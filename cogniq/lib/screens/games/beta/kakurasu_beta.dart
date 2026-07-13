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
  final List<List<bool>> _solutions = [
    [false, false, true, false, false, true, true, true, true],
    [false, false, true, false, true, false, true, false, false],
    [false, false, true, false, true, false, true, false, true],
    [false, false, true, false, true, false, true, true, false],
    [false, false, true, false, true, false, true, true, true]
  ];

  int _currentLevel = 0;
  bool _isSuccess = false;
  List<bool> _shaded = List.filled(9, false);
  List<int> _rowTargets = [3, 3, 6];
  List<int> _colTargets = [3, 3, 6];

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
        _rowTargets = [3, 3, 6]; _colTargets = [3, 3, 6];
      } else if (_currentLevel == 1) {
        _rowTargets = [3, 2, 1]; _colTargets = [3, 2, 1];
      } else if (_currentLevel == 2) {
        _rowTargets = [3, 2, 4]; _colTargets = [3, 2, 4];
      } else if (_currentLevel == 3) {
        _rowTargets = [3, 2, 3]; _colTargets = [3, 5, 1];
      } else {
        _rowTargets = [3, 2, 6]; _colTargets = [3, 5, 4];
      }
    });
  }

  void _showHint() {
    final sol = _solutions[_currentLevel];
    int hintCell = -1;
    for (int i = 0; i < _shaded.length; i++) {
      if (_shaded[i] != sol[i]) {
        hintCell = i;
        break;
      }
    }
    if (hintCell != -1) {
      setState(() {
        _shaded[hintCell] = sol[hintCell];
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hint placed!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Board matches correct solution!')));
    }
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text('Instructions', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
        content: Text(
          '1. Shade cells so that weighted row and column targets match.\n\n2. Column weights are 1, 2, 3 (from left to right).\n\n3. Row weights are 1, 2, 3 (from top to bottom).',
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

  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_kakurasu') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_kakurasu', _currentLevel + 1);
    }
    setState(() => _isSuccess = true);
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sums do not match targets!')));
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
        title: Text('Kakurasu', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                              if (r == 0 || r == 4 || c == 0 || c == 4) {
                                if (r == 0 && c > 0 && c < 4) return Center(child: Text('$c', style: GoogleFonts.spaceGrotesk(color: Colors.grey)));
                                if (r == 4 && c > 0 && c < 4) return Center(child: Text('${_colTargets[c - 1]}', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.dustyMauve)));
                                if (c == 0 && r > 0 && r < 4) return Center(child: Text('$r', style: GoogleFonts.spaceGrotesk(color: Colors.grey)));
                                if (c == 4 && r > 0 && r < 4) return Center(child: Text('${_rowTargets[r - 1]}', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.dustyMauve)));
                                return const SizedBox.shrink();
                              }
                              int gridIdx = (r - 1) * 3 + (c - 1);
                              final isShaded = _shaded[gridIdx];
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _shaded[gridIdx] = !isShaded;
                                }),
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isShaded ? AppTheme.dustyMauve : context.bgSurface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade800),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _checkSolution,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.dustyMauve,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          ),
                          child: Text('Check Grid', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isSuccess)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.8),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Correct!', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.softSage)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _nextLevel,
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dustyMauve),
                        child: Text('Next Level', style: GoogleFonts.outfit(color: Colors.white)),
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
