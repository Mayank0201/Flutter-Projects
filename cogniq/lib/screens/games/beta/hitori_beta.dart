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
  final List<List<bool>> _solutions = [
    [false, true, false, false, false, true, true, false, false],
    [true, false, false, false, false, true, false, true, false],
    [false, true, false, true, false, true, false, true, false],
    [false, true, false, false, false, true, true, false, false],
    [false, true, false, true, false, true, false, true, false]
  ];

  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _grid = List.filled(9, 1);
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
        _grid = [1, 3, 2, 2, 3, 2, 1, 2, 1];
      } else if (_currentLevel == 1) {
        _grid = [1, 3, 1, 3, 2, 3, 1, 2, 2];
      } else if (_currentLevel == 2) {
        _grid = [2, 2, 3, 3, 2, 2, 3, 2, 1];
      } else if (_currentLevel == 3) {
        _grid = [1, 3, 3, 3, 1, 1, 2, 3, 2];
      } else {
        _grid = [2, 1, 1, 3, 3, 3, 1, 3, 2];
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
          '1. Shade duplicate numbers in rows and columns.\n\n2. Shaded cells cannot touch orthogonally.\n\n3. Unshaded cells must remain connected.',
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
    int highest = prefs.getInt('beta_level_hitori') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_hitori', _currentLevel + 1);
    }
    setState(() => _isSuccess = true);
  }

  void _checkSolution() {
    bool isValid = true;
    for (int i = 0; i < 9; i++) {
      if (_shaded[i]) {
        int r = i ~/ 3; int c = i % 3;
        if (r < 2 && _shaded[(r + 1) * 3 + c]) isValid = false;
        if (c < 2 && _shaded[r * 3 + c + 1]) isValid = false;
      }
    }
    for (int r = 0; r < 3; r++) {
      List<int> rowVals = [];
      for (int c = 0; c < 3; c++) {
        if (!_shaded[r * 3 + c]) rowVals.add(_grid[r * 3 + c]);
      }
      if (rowVals.length != rowVals.toSet().length) isValid = false;
    }
    for (int c = 0; c < 3; c++) {
      List<int> colVals = [];
      for (int r = 0; r < 3; r++) {
        if (!_shaded[r * 3 + c]) colVals.add(_grid[r * 3 + c]);
      }
      if (colVals.length != colVals.toSet().length) isValid = false;
    }
    if (isValid) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uniqueness or adjacency rules violated!')));
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
                        Text('Shade cells so no duplicates remain in rows and columns.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary)),
                        const SizedBox(height: 24),
                        Container(
                          width: 240, height: 240,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(12)),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
                            itemCount: 9,
                            itemBuilder: (context, idx) {
                              final isShaded = _shaded[idx];
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _shaded[idx] = !isShaded;
                                }),
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isShaded ? AppTheme.dustyMauve : context.bgSurface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade800),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${_grid[idx]}',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: isShaded ? Colors.white : context.textPrimary,
                                      ),
                                    ),
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
