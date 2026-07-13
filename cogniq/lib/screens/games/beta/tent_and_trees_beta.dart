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
  final List<List<int>> _solutions = [
    [0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0],
    [0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0],
    [0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0],
    [0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0],
    [0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0]
  ];

  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _grid = List.filled(16, 0);
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

  void _showHint() {
    final sol = _solutions[_currentLevel];
    int hintCell = -1;
    for (int i = 0; i < _grid.length; i++) {
      if (sol[i] == 2 && _grid[i] != 2) {
        hintCell = i;
        break;
      }
      if (_grid[i] == 2 && sol[i] != 2) {
        hintCell = i;
        break;
      }
    }
    if (hintCell != -1) {
      setState(() {
        _grid[hintCell] = sol[hintCell];
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
          '1. Place tents next to trees orthogonally.\n\n2. Tents cannot touch each other, even diagonally.\n\n3. Row and column counts must match clue totals.',
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
                        Text('Place tents next to trees orthogonally to match row/col counts.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary)),
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
                              int cellType = _grid[gridIdx];
                              return GestureDetector(
                                onTap: () => setState(() {
                                  if (cellType == 0) _grid[gridIdx] = 2; // Empty to Tent
                                  else if (cellType == 2) _grid[gridIdx] = 0; // Tent to Empty
                                }),
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: context.bgSurface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade800),
                                  ),
                                  child: Center(
                                    child: cellType == 1
                                        ? const Icon(Icons.park, color: Colors.green, size: 24)
                                        : cellType == 2
                                            ? const Icon(Icons.campaign, color: Colors.orange, size: 24)
                                            : null,
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
