import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import 'package:flutter/foundation.dart';

class NumberlinkBetaScreen extends StatefulWidget {
  const NumberlinkBetaScreen({super.key});
  @override
  State<NumberlinkBetaScreen> createState() => _NumberlinkBetaScreenState();
}

class _NumberlinkBetaScreenState extends State<NumberlinkBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _grid = List.filled(16, 0); // 1, 2 for endpoints
  List<int> _connections = List.filled(16, 0); // User colored paths

  // Paths
  List<int> _redPath = [];
  List<int> _bluePath = [];
  int _dragColor = 0; // 0: none, 1: red, 2: blue

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      _dragColor = 0;
      _redPath = [];
      _bluePath = [];
      _grid = List.filled(16, 0);
      _connections = List.filled(16, 0);

      if (_currentLevel == 0) {
        _grid[9] = 1; _grid[15] = 1;
        _grid[5] = 2; _grid[12] = 2;
      } else if (_currentLevel == 1) {
        _grid[10] = 1; _grid[12] = 1;
        _grid[6] = 2; _grid[15] = 2;
      } else if (_currentLevel == 2) {
        _grid[3] = 1; _grid[10] = 1;
        _grid[5] = 2; _grid[12] = 2;
      } else if (_currentLevel == 3) {
        _grid[3] = 1; _grid[10] = 1;
        _grid[9] = 2; _grid[15] = 2;
      } else if (_currentLevel == 4) {
        _grid[0] = 1; _grid[9] = 1;
        _grid[6] = 2; _grid[15] = 2;
      } else if (_currentLevel == 5) {
        _grid[9] = 1; _grid[15] = 1;
        _grid[5] = 2; _grid[12] = 2;
      } else if (_currentLevel == 6) {
        _grid[10] = 1; _grid[12] = 1;
        _grid[6] = 2; _grid[15] = 2;
      } else if (_currentLevel == 7) {
        _grid[3] = 1; _grid[10] = 1;
        _grid[5] = 2; _grid[12] = 2;
      } else if (_currentLevel == 8) {
        _grid[3] = 1; _grid[10] = 1;
        _grid[9] = 2; _grid[15] = 2;
      } else {
        _grid[0] = 1; _grid[9] = 1;
        _grid[6] = 2; _grid[15] = 2;
      }

      _syncConnections();
    });
  }

  void _syncConnections() {
    _connections = List.filled(16, 0);
    // Put endpoints in connections
    for (int i = 0; i < 16; i++) {
      if (_grid[i] > 0) {
        _connections[i] = _grid[i];
      }
    }
    // Put paths in connections
    for (int idx in _redPath) {
      _connections[idx] = 1;
    }
    for (int idx in _bluePath) {
      _connections[idx] = 2;
    }
  }

  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_numberlink') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_numberlink', _currentLevel + 1);
    }
    setState(() => _isSuccess = true);
  }

  void _checkSolution() {
    _syncConnections();
    bool isValid = true;
    for (int i = 0; i < 16; i++) {
      if (_connections[i] == 0) {
        isValid = false;
        break;
      }
    }
    if (isValid) {
      for (int color = 1; color <= 2; color++) {
        List<int> endpoints = [];
        List<int> pathCells = [];
        for (int i = 0; i < 16; i++) {
          if (_grid[i] == color) endpoints.add(i);
          if (_connections[i] == color) pathCells.add(i);
        }
        if (endpoints.length != 2) {
          isValid = false;
          break;
        }
        for (int cell in pathCells) {
          int r = cell ~/ 4; int c = cell % 4;
          int sameColorNeighbors = 0;
          var neighbors = [
            if (r > 0) (r - 1) * 4 + c,
            if (r < 3) (r + 1) * 4 + c,
            if (c > 0) r * 4 + c - 1,
            if (c < 3) r * 4 + c + 1,
          ];
          for (int n in neighbors) {
            if (_connections[n] == color) sameColorNeighbors++;
          }
          bool isEp = endpoints.contains(cell);
          if (isEp) {
            if (sameColorNeighbors != 1) {
              isValid = false;
              break;
            }
          } else {
            if (sameColorNeighbors != 2) {
              isValid = false;
              break;
            }
          }
        }
        if (!isValid) break;

        List<bool> visited = List.filled(16, false);
        int startEp = endpoints[0];
        List<int> queue = [startEp];
        visited[startEp] = true;
        int visitedCount = 1;
        while (queue.isNotEmpty) {
          int curr = queue.removeAt(0);
          int r = curr ~/ 4; int c = curr % 4;
          var neighbors = [
            if (r > 0) (r - 1) * 4 + c,
            if (r < 3) (r + 1) * 4 + c,
            if (c > 0) r * 4 + c - 1,
            if (c < 3) r * 4 + c + 1,
          ];
          for (int n in neighbors) {
            if (_connections[n] == color && !visited[n]) {
              visited[n] = true;
              queue.add(n);
              visitedCount++;
            }
          }
        }
        if (visitedCount != pathCells.length) {
          isValid = false;
          break;
        }
      }
    }

    if (isValid) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paths are incorrect, branched, or do not cover the whole grid!')));
    }
  }

  void _showHint() {
    final solutions = [
      [1, 1, 1, 1, 1, 2, 2, 1, 1, 1, 2, 1, 2, 2, 2, 1],
      [1, 1, 1, 1, 1, 2, 2, 1, 1, 2, 1, 1, 1, 2, 2, 2],
      [1, 1, 1, 1, 1, 2, 2, 2, 1, 1, 1, 2, 2, 2, 2, 2],
      [1, 1, 1, 1, 1, 2, 2, 2, 1, 2, 1, 2, 1, 1, 1, 2],
      [1, 1, 1, 1, 2, 2, 2, 1, 2, 1, 1, 1, 2, 2, 2, 2],
      [1, 1, 1, 1, 1, 2, 2, 1, 1, 1, 2, 1, 2, 2, 2, 1],
      [1, 1, 1, 1, 1, 2, 2, 1, 1, 2, 1, 1, 1, 2, 2, 2],
      [1, 1, 1, 1, 1, 2, 2, 2, 1, 1, 1, 2, 2, 2, 2, 2],
      [1, 1, 1, 1, 1, 2, 2, 2, 1, 2, 1, 2, 1, 1, 1, 2],
      [1, 1, 1, 1, 2, 2, 2, 1, 2, 1, 1, 1, 2, 2, 2, 2],
    ];
    final sol = solutions[_currentLevel];

    // Reconstruct paths from solution
    setState(() {
      _redPath = [];
      _bluePath = [];
      for (int i = 0; i < 16; i++) {
        if (sol[i] == 1) _redPath.add(i);
        if (sol[i] == 2) _bluePath.add(i);
      }
      _syncConnections();
      _checkSolution();
    });
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text('How to Play Numberlink', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
        content: Text(
          '1. Drag from a colored dot to draw a path.\n\n'
          '2. Connect matching colored dots.\n\n'
          '3. Paths cannot cross each other.\n\n'
          '4. Fill every single cell on the board to complete the level.',
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

  int _cellAtLocal(Offset localPos, double cs) {
    int col = localPos.dx ~/ cs;
    int row = localPos.dy ~/ cs;
    if (col >= 0 && col < 4 && row >= 0 && row < 4) {
      return row * 4 + col;
    }
    return -1;
  }

  void _onPanStart(DragStartDetails details, double cs) {
    if (_isSuccess) return;
    int idx = _cellAtLocal(details.localPosition, cs);
    if (idx == -1) return;

    if (_grid[idx] == 1 || _redPath.contains(idx)) {
      settingsNotifier.hapticTap();
      setState(() {
        _dragColor = 1;
        if (_grid[idx] == 1) {
          _redPath = [idx];
        } else {
          int cutIdx = _redPath.indexOf(idx);
          _redPath = _redPath.sublist(0, cutIdx + 1);
        }
        _syncConnections();
      });
    } else if (_grid[idx] == 2 || _bluePath.contains(idx)) {
      settingsNotifier.hapticTap();
      setState(() {
        _dragColor = 2;
        if (_grid[idx] == 2) {
          _bluePath = [idx];
        } else {
          int cutIdx = _bluePath.indexOf(idx);
          _bluePath = _bluePath.sublist(0, cutIdx + 1);
        }
        _syncConnections();
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details, double cs) {
    if (_isSuccess || _dragColor == 0) return;
    int idx = _cellAtLocal(details.localPosition, cs);
    if (idx == -1) return;

    List<int> activePath = _dragColor == 1 ? _redPath : _bluePath;
    List<int> otherPath = _dragColor == 1 ? _bluePath : _redPath;

    if (activePath.isEmpty) return;

    int lastIdx = activePath.last;
    if (lastIdx == idx) return;

    // Undo by moving back
    if (activePath.length >= 2 && activePath[activePath.length - 2] == idx) {
      settingsNotifier.hapticTap();
      setState(() {
        activePath.removeLast();
        _syncConnections();
      });
      return;
    }

    // Check adjacency
    int r1 = lastIdx ~/ 4; int c1 = lastIdx % 4;
    int r2 = idx ~/ 4; int c2 = idx % 4;
    bool isAdjacent = (r1 - r2).abs() + (c1 - c2).abs() == 1;

    if (isAdjacent) {
      // Don't cross other path, but let them cross empty spaces
      if (!otherPath.contains(idx) && !activePath.contains(idx)) {
        // Can't pass through a different endpoint
        if (_grid[idx] == 0 || _grid[idx] == _dragColor) {
          settingsNotifier.hapticTap();
          setState(() {
            activePath.add(idx);
            _syncConnections();
          });
          // If we reached target endpoint, stop drag
          if (_grid[idx] == _dragColor && idx != activePath.first) {
            _dragColor = 0;
            _checkSolution();
          }
        }
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _dragColor = 0;
    });
    _checkSolution();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Numberlink', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        Text('Drag to draw paths connecting matching colors.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary)),
                        const SizedBox(height: 24),
                        RepaintBoundary(
                          child: Container(
                            width: 280, height: 280,
                            decoration: BoxDecoration(color: context.bgCard, border: Border.all(color: context.textMuted, width: 2), borderRadius: BorderRadius.circular(12)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  double cs = constraints.maxWidth / 4;
                                  return GestureDetector(
                                    onPanStart: (d) => _onPanStart(d, cs),
                                    onPanUpdate: (d) => _onPanUpdate(d, cs),
                                    onPanEnd: _onPanEnd,
                                    child: CustomPaint(
                                      size: Size(constraints.maxWidth, constraints.maxHeight),
                                      painter: NumberlinkPainter(
                                        grid: _grid,
                                        redPath: _redPath,
                                        bluePath: _bluePath,
                                        cellSize: cs,
                                      ),
                                    ),
                                  );
                                }
                              ),
                            ),
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

class NumberlinkPainter extends CustomPainter {
  final List<int> grid;
  final List<int> redPath;
  final List<int> bluePath;
  final double cellSize;

  NumberlinkPainter({
    required this.grid,
    required this.redPath,
    required this.bluePath,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Grid Lines
    final linePaint = Paint()
      ..color = Colors.grey.shade800
      ..strokeWidth = 1;
    for (int i = 1; i < 4; i++) {
      canvas.drawLine(Offset(i * cellSize, 0), Offset(i * cellSize, size.height), linePaint);
      canvas.drawLine(Offset(0, i * cellSize), Offset(size.width, i * cellSize), linePaint);
    }

    // 2. Draw Paths
    final redPaint = Paint()
      ..color = Colors.red.withOpacity(0.55)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final bluePaint = Paint()
      ..color = Colors.blue.withOpacity(0.55)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    _drawPath(canvas, redPath, redPaint);
    _drawPath(canvas, bluePath, bluePaint);

    // 3. Draw Endpoints (Dots)
    for (int idx = 0; idx < 16; idx++) {
      int endpoint = grid[idx];
      if (endpoint > 0) {
        final dotPaint = Paint()
          ..color = endpoint == 1 ? Colors.red : Colors.blue
          ..style = PaintingStyle.fill;
        double cx = (idx % 4) * cellSize + cellSize / 2;
        double cy = (idx ~/ 4) * cellSize + cellSize / 2;
        canvas.drawCircle(Offset(cx, cy), 12, dotPaint);
      }
    }
  }

  void _drawPath(Canvas canvas, List<int> path, Paint paint) {
    if (path.length < 2) return;
    final p = Path();
    double startX = (path[0] % 4) * cellSize + cellSize / 2;
    double startY = (path[0] ~/ 4) * cellSize + cellSize / 2;
    p.moveTo(startX, startY);
    for (int i = 1; i < path.length; i++) {
      double cx = (path[i] % 4) * cellSize + cellSize / 2;
      double cy = (path[i] ~/ 4) * cellSize + cellSize / 2;
      p.lineTo(cx, cy);
    }
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant NumberlinkPainter oldDelegate) {
    return !listEquals(oldDelegate.redPath, redPath) ||
        !listEquals(oldDelegate.bluePath, bluePath) ||
        oldDelegate.cellSize != cellSize ||
        !listEquals(oldDelegate.grid, grid);
  }
}
