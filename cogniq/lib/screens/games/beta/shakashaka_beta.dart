import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';

class ShakashakaLevel {
  final List<int> initialGrid; // 0: empty/playable, -1: black wall, -2: black wall with clue 0, -3: clue 1, -4: clue 2, -5: clue 3, -6: clue 4
  final List<int> solution;    // 0: empty, 1: triangle top-left, 2: triangle bottom-right
  const ShakashakaLevel({required this.initialGrid, required this.solution});
}

class ShakashakaBetaScreen extends StatefulWidget {
  const ShakashakaBetaScreen({super.key});
  @override
  State<ShakashakaBetaScreen> createState() => _ShakashakaBetaScreenState();
}

class _ShakashakaBetaScreenState extends State<ShakashakaBetaScreen> {
  final List<ShakashakaLevel> _levels = const [
    ShakashakaLevel(
      initialGrid: [0, 0, 0, 0, -3, 0, 0, 0, 0],
      solution: [0, 2, 0, 0, -3, 0, 0, 1, 0],
    ),
    ShakashakaLevel(
      initialGrid: [-1, 0, -1, 0, 0, 0, -1, 0, -1],
      solution: [-1, 1, -1, 2, 0, 1, -1, 2, -1],
    ),
    ShakashakaLevel(
      initialGrid: [0, -4, 0, 0, 0, 0, 0, -4, 0],
      solution: [1, -4, 2, 0, 0, 0, 2, -4, 1],
    ),
    ShakashakaLevel(
      initialGrid: [0, 0, 0, -5, 0, -5, 0, 0, 0],
      solution: [2, 0, 1, -5, 0, -5, 2, 0, 1],
    ),
    ShakashakaLevel(
      initialGrid: [-2, 0, -2, 0, -6, 0, -2, 0, -2],
      solution: [-2, 1, -2, 2, -6, 1, -2, 2, -2],
    ),
  ];

  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _grid = List.filled(9, 0);

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      // Copy initialGrid to grid
      final lvl = _levels[_currentLevel];
      _grid = List<int>.from(lvl.initialGrid);
    });
  }

  void _showHint() {
    final lvl = _levels[_currentLevel];
    int hintCell = -1;
    for (int i = 0; i < 9; i++) {
      if (lvl.initialGrid[i] >= 0 && _grid[i] != lvl.solution[i]) {
        hintCell = i;
        break;
      }
    }
    if (hintCell != -1) {
      setState(() {
        _grid[hintCell] = lvl.solution[hintCell];
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
          '1. Tap cells to place half-block triangles (cycle through orientations).\n\n'
          '2. Black cells are walls. Clue numbers on walls specify exactly how many triangles must touch their edges.\n\n'
          '3. Arrange triangles to outline rectangular white corridors.',
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
    int highest = prefs.getInt('beta_level_shakashaka') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_shakashaka', _currentLevel + 1);
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
    final lvl = _levels[_currentLevel];
    bool correct = true;
    for (int i = 0; i < 9; i++) {
      if (lvl.initialGrid[i] >= 0) {
        if (_grid[i] != lvl.solution[i]) {
          correct = false;
          break;
        }
      }
    }
    if (correct) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect solution! Make sure white areas form rectangles.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lvl = _levels[_currentLevel];
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Shakashaka', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        Text('Fill white cells with half-block triangles to form rectangles.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary)),
                        const SizedBox(height: 24),
                        Container(
                          width: 240, height: 240,
                          decoration: BoxDecoration(border: Border.all(color: context.textMuted, width: 2)),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
                            itemCount: 9,
                            itemBuilder: (context, idx) {
                              int cellType = lvl.initialGrid[idx];
                              bool isWall = cellType < 0;
                              
                              if (isWall) {
                                int clueVal = cellType == -1 ? -1 : (cellType + 2).abs();
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    border: Border.all(color: Colors.grey.shade900),
                                  ),
                                  child: clueVal >= 0
                                      ? Center(
                                          child: Text(
                                            '$clueVal',
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        )
                                      : null,
                                );
                              }

                              int shape = _grid[idx];
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _grid[idx] = (_grid[idx] + 1) % 3;
                                }),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: context.bgCard,
                                    border: Border.all(color: Colors.grey.shade800),
                                  ),
                                  child: CustomPaint(
                                    painter: _ShakashakaPainter(shape),
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

class _ShakashakaPainter extends CustomPainter {
  final int shape;
  _ShakashakaPainter(this.shape);
  @override
  void paint(Canvas canvas, Size size) {
    if (shape == 0) return;
    Paint paint = Paint()..color = Colors.black..style = PaintingStyle.fill;
    Path path = Path();
    if (shape == 1) {
      path.moveTo(0, 0); path.lineTo(size.width, 0); path.lineTo(0, size.height);
    } else if (shape == 2) {
      path.moveTo(size.width, 0); path.lineTo(size.width, size.height); path.lineTo(0, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
