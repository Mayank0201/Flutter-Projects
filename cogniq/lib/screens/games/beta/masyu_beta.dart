import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import 'package:flutter/foundation.dart';

class MasyuBetaScreen extends StatefulWidget {
  const MasyuBetaScreen({super.key});
  @override
  State<MasyuBetaScreen> createState() => _MasyuBetaScreenState();
}

class _MasyuBetaScreenState extends State<MasyuBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _grid = List.filled(16, 0); // 0: empty, 1: white, 2: black
  Map<String, bool> _activeEdges = {}; // Key: "u-v", Value: active loop status

  // Drag states
  int _dragStartCell = -1;
  List<int> _dragPath = [];
  final ValueNotifier<Offset?> _dragPositionNotifier = ValueNotifier<Offset?>(null);

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      _grid = List.filled(16, 0);
      _activeEdges = {};
      _dragStartCell = -1;
      _dragPath = [];
      _dragPositionNotifier.value = null;

      if (_currentLevel == 0) {
        _grid[11] = 1; _grid[15] = 2;
      } else if (_currentLevel == 1) {
        _grid[9] = 1; _grid[15] = 2;
      } else if (_currentLevel == 2) {
        _grid[9] = 1; _grid[13] = 2;
      } else if (_currentLevel == 3) {
        _grid[10] = 1; _grid[14] = 2;
      } else if (_currentLevel == 4) {
        _grid[6] = 1; _grid[5] = 2;
      } else if (_currentLevel == 5) {
        _grid[11] = 1; _grid[15] = 2;
      } else if (_currentLevel == 6) {
        _grid[9] = 1; _grid[15] = 2;
      } else if (_currentLevel == 7) {
        _grid[9] = 1; _grid[13] = 2;
      } else if (_currentLevel == 8) {
        _grid[10] = 1; _grid[14] = 2;
      } else {
        _grid[6] = 1; _grid[5] = 2;
      }
    });
  }

  List<List<int>> _getEdges() {
    List<List<int>> list = [];
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 3; c++) {
        list.add([r * 4 + c, r * 4 + c + 1]);
      }
    }
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 4; c++) {
        list.add([r * 4 + c, (r + 1) * 4 + c]);
      }
    }
    return list;
  }

  bool _hasEdge(int a, int b) {
    String key = a < b ? '$a-$b' : '$b-$a';
    return _activeEdges[key] ?? false;
  }

  int _getClosestCell(Offset localPos) {
    for (int idx = 0; idx < 16; idx++) {
      double cx = 35.0 + (idx % 4) * 70.0;
      double cy = 35.0 + (idx ~/ 4) * 70.0;
      double dist = (localPos - Offset(cx, cy)).distance;
      if (dist < 24.0) {
        return idx;
      }
    }
    return -1;
  }

  void _onPanStart(DragStartDetails d) {
    if (_isSuccess) return;
    int idx = _getClosestCell(d.localPosition);
    if (idx != -1) {
      settingsNotifier.hapticTap();
      _dragStartCell = idx;
      _dragPath = [idx];
      double cx = 35.0 + (idx % 4) * 70.0;
      double cy = 35.0 + (idx ~/ 4) * 70.0;
      _dragPositionNotifier.value = Offset(cx, cy);
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_isSuccess || _dragStartCell == -1) return;
    _dragPositionNotifier.value = d.localPosition;

    int idx = _getClosestCell(d.localPosition);
    if (idx != -1 && _dragPath.isNotEmpty) {
      int last = _dragPath.last;
      if (last == idx) return;

      // Undo by dragging back
      if (_dragPath.length >= 2 && _dragPath[_dragPath.length - 2] == idx) {
        settingsNotifier.hapticTap();
        setState(() {
          String key = last < idx ? '$last-$idx' : '$idx-$last';
          _activeEdges.remove(key);
          _dragPath.removeLast();
        });
        return;
      }

      // Check adjacency
      int r1 = last ~/ 4; int c1 = last % 4;
      int r2 = idx ~/ 4; int c2 = idx % 4;
      bool isAdjacent = (r1 - r2).abs() + (c1 - c2).abs() == 1;

      if (isAdjacent && !_dragPath.contains(idx)) {
        settingsNotifier.hapticTap();
        setState(() {
          String key = last < idx ? '$last-$idx' : '$idx-$last';
          _activeEdges[key] = !(_activeEdges[key] ?? false);
          _dragPath.add(idx);
        });
      }
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (_isSuccess || _dragStartCell == -1) return;
    _dragPositionNotifier.value = null;
    _dragStartCell = -1;
    _dragPath = [];
    _checkSolution();
  }

  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_masyu') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_masyu', _currentLevel + 1);
    }
    setState(() => _isSuccess = true);
  }

  void _checkSolution() {
    bool isValid = true;
    List<int> degree = List.filled(16, 0);
    final edges = _getEdges();

    for (int i = 0; i < edges.length; i++) {
      int u = edges[i][0];
      int v = edges[i][1];
      if (_hasEdge(u, v)) {
        degree[u]++;
        degree[v]++;
      }
    }

    int loopCellsCount = 0;
    int startCell = -1;
    for (int i = 0; i < 16; i++) {
      if (degree[i] == 2) {
        loopCellsCount++;
        if (startCell == -1) startCell = i;
      } else if (degree[i] != 0) {
        isValid = false;
      }
    }

    if (loopCellsCount < 4) isValid = false;

    if (isValid && startCell != -1) {
      List<bool> visited = List.filled(16, false);
      List<int> queue = [startCell];
      visited[startCell] = true;
      int visitedCount = 1;
      while (queue.isNotEmpty) {
        int curr = queue.removeAt(0);
        for (int i = 0; i < edges.length; i++) {
          int u = edges[i][0];
          int v = edges[i][1];
          if (_hasEdge(u, v)) {
            if (u == curr && !visited[v]) {
              visited[v] = true;
              queue.add(v);
              visitedCount++;
            } else if (v == curr && !visited[u]) {
              visited[u] = true;
              queue.add(u);
              visitedCount++;
            }
          }
        }
      }
      if (visitedCount != loopCellsCount) isValid = false;
    }

    if (isValid) {
      for (int i = 0; i < 16; i++) {
        int pearl = _grid[i];
        if (pearl > 0) {
          if (degree[i] != 2) {
            isValid = false;
            break;
          }

          List<int> neighbors = [];
          int ri = i ~/ 4; int ci = i % 4;
          if (ri > 0 && _hasEdge(i, (ri - 1) * 4 + ci)) neighbors.add((ri - 1) * 4 + ci);
          if (ri < 3 && _hasEdge(i, (ri + 1) * 4 + ci)) neighbors.add((ri + 1) * 4 + ci);
          if (ci > 0 && _hasEdge(i, i - 1)) neighbors.add(i - 1);
          if (ci < 3 && _hasEdge(i, i + 1)) neighbors.add(i + 1);

          if (neighbors.length != 2) {
            isValid = false;
            break;
          }

          int n1 = neighbors[0];
          int n2 = neighbors[1];
          int r1 = n1 ~/ 4, c1 = n1 % 4;
          int r2 = n2 ~/ 4, c2 = n2 % 4;
          bool isStraight = (r1 == r2) || (c1 == c2);

          if (pearl == 1) {
            if (!isStraight) {
              isValid = false;
              break;
            }
            
            bool n1Turns = false;
            int rn1 = n1 ~/ 4, cn1 = n1 % 4;
            List<int> n1Neighbors = [];
            if (rn1 > 0 && _hasEdge(n1, (rn1 - 1) * 4 + cn1)) n1Neighbors.add((rn1 - 1) * 4 + cn1);
            if (rn1 < 3 && _hasEdge(n1, (rn1 + 1) * 4 + cn1)) n1Neighbors.add((rn1 + 1) * 4 + cn1);
            if (cn1 > 0 && _hasEdge(n1, n1 - 1)) n1Neighbors.add(n1 - 1);
            if (cn1 < 3 && _hasEdge(n1, n1 + 1)) n1Neighbors.add(n1 + 1);
            if (n1Neighbors.length == 2) {
              int rn1_1 = n1Neighbors[0] ~/ 4, cn1_1 = n1Neighbors[0] % 4;
              int rn1_2 = n1Neighbors[1] ~/ 4, cn1_2 = n1Neighbors[1] % 4;
              n1Turns = (rn1_1 != rn1_2) && (cn1_1 != cn1_2);
            }

            bool n2Turns = false;
            int rn2 = n2 ~/ 4, cn2 = n2 % 4;
            List<int> n2Neighbors = [];
            if (rn2 > 0 && _hasEdge(n2, (rn2 - 1) * 4 + cn2)) n2Neighbors.add((rn2 - 1) * 4 + cn2);
            if (rn2 < 3 && _hasEdge(n2, (rn2 + 1) * 4 + cn2)) n2Neighbors.add((rn2 + 1) * 4 + cn2);
            if (cn2 > 0 && _hasEdge(n2, n2 - 1)) n2Neighbors.add(n2 - 1);
            if (cn2 < 3 && _hasEdge(n2, n2 + 1)) n2Neighbors.add(n2 + 1);
            if (n2Neighbors.length == 2) {
              int rn2_1 = n2Neighbors[0] ~/ 4, cn2_1 = n2Neighbors[0] % 4;
              int rn2_2 = n2Neighbors[1] ~/ 4, cn2_2 = n2Neighbors[1] % 4;
              n2Turns = (rn2_1 != rn2_2) && (cn2_1 != cn2_2);
            }

            if (!n1Turns && !n2Turns) {
              isValid = false;
              break;
            }
          } else if (pearl == 2) {
            if (isStraight) {
              isValid = false;
              break;
            }

            bool n1Straight = false;
            int rn1 = n1 ~/ 4, cn1 = n1 % 4;
            List<int> n1Neighbors = [];
            if (rn1 > 0 && _hasEdge(n1, (rn1 - 1) * 4 + cn1)) n1Neighbors.add((rn1 - 1) * 4 + cn1);
            if (rn1 < 3 && _hasEdge(n1, (rn1 + 1) * 4 + cn1)) n1Neighbors.add((rn1 + 1) * 4 + cn1);
            if (cn1 > 0 && _hasEdge(n1, n1 - 1)) n1Neighbors.add(n1 - 1);
            if (cn1 < 3 && _hasEdge(n1, n1 + 1)) n1Neighbors.add(n1 + 1);
            if (n1Neighbors.length == 2) {
              int rn1_1 = n1Neighbors[0] ~/ 4, cn1_1 = n1Neighbors[0] % 4;
              int rn1_2 = n1Neighbors[1] ~/ 4, cn1_2 = n1Neighbors[1] % 4;
              n1Straight = (rn1_1 == rn1_2) || (cn1_1 == cn1_2);
            }
            if (!n1Straight) {
              isValid = false;
              break;
            }

            bool n2Straight = false;
            int rn2 = n2 ~/ 4, cn2 = n2 % 4;
            List<int> n2Neighbors = [];
            if (rn2 > 0 && _hasEdge(n2, (rn2 - 1) * 4 + cn2)) n2Neighbors.add((rn2 - 1) * 4 + cn2);
            if (rn2 < 3 && _hasEdge(n2, (rn2 + 1) * 4 + cn2)) n2Neighbors.add((rn2 + 1) * 4 + cn2);
            if (cn2 > 0 && _hasEdge(n2, n2 - 1)) n2Neighbors.add(n2 - 1);
            if (cn2 < 3 && _hasEdge(n2, n2 + 1)) n2Neighbors.add(n2 + 1);
            if (n2Neighbors.length == 2) {
              int rn2_1 = n2Neighbors[0] ~/ 4, cn2_1 = n2Neighbors[0] % 4;
              int rn2_2 = n2Neighbors[1] ~/ 4, cn2_2 = n2Neighbors[1] % 4;
              n2Straight = (rn2_1 == rn2_2) || (cn2_1 == cn2_2);
            }
            if (!n2Straight) {
              isValid = false;
              break;
            }
          }
        }
      }
    }

    if (isValid) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masyu rules violated! Check closed loop shape and pearl constraints.')));
    }
  }

  void _showHint() {
    final solutions = [
      {"6-7": 1, "9-10": 1, "13-14": 1, "14-15": 1, "6-10": 1, "7-11": 1, "9-13": 1, "11-15": 1},
      {"6-7": 1, "8-9": 1, "9-10": 1, "12-13": 1, "13-14": 1, "14-15": 1, "6-10": 1, "7-11": 1, "8-12": 1, "11-15": 1},
      {"5-6": 1, "10-11": 1, "13-14": 1, "14-15": 1, "5-9": 1, "6-10": 1, "9-13": 1, "11-15": 1},
      {"5-6": 1, "8-9": 1, "12-13": 1, "13-14": 1, "5-9": 1, "6-10": 1, "8-12": 1, "10-14": 1},
      {"5-6": 1, "6-7": 1, "13-14": 1, "14-15": 1, "5-9": 1, "7-11": 1, "9-13": 1, "11-15": 1},
      {"6-7": 1, "9-10": 1, "13-14": 1, "14-15": 1, "6-10": 1, "7-11": 1, "9-13": 1, "11-15": 1},
      {"6-7": 1, "8-9": 1, "9-10": 1, "12-13": 1, "13-14": 1, "14-15": 1, "6-10": 1, "7-11": 1, "8-12": 1, "11-15": 1},
      {"5-6": 1, "10-11": 1, "13-14": 1, "14-15": 1, "5-9": 1, "6-10": 1, "9-13": 1, "11-15": 1},
      {"5-6": 1, "8-9": 1, "12-13": 1, "13-14": 1, "5-9": 1, "6-10": 1, "8-12": 1, "10-14": 1},
      {"5-6": 1, "6-7": 1, "13-14": 1, "14-15": 1, "5-9": 1, "7-11": 1, "9-13": 1, "11-15": 1},
    ];
    final sol = solutions[_currentLevel];
    String? hintKey;
    bool hintVal = false;
    
    final edges = _getEdges();
    for (var edge in edges) {
      final key = '${edge[0]}-${edge[1]}';
      bool current = _activeEdges[key] ?? false;
      bool target = sol.containsKey(key);
      if (current != target) {
        hintKey = key;
        hintVal = target;
        break;
      }
    }
    
    if (hintKey != null) {
      setState(() {
        if (hintVal) {
          _activeEdges[hintKey!] = true;
        } else {
          _activeEdges.remove(hintKey!);
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The board is already correctly solved!')));
    }
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

  @override
  Widget build(BuildContext context) {
    final edges = _getEdges();
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Masyu', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        Text('Drag through grid centers to draw a loop connecting pearls.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        RepaintBoundary(
                          child: GestureDetector(
                            onPanStart: _onPanStart,
                            onPanUpdate: _onPanUpdate,
                            onPanEnd: _onPanEnd,
                            child: Container(
                              width: 280, height: 280,
                              decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.textMuted.withAlpha(40))),
                              child: Stack(
                                children: [
                                  CustomPaint(
                                    size: const Size(280, 280),
                                    painter: MasyuPainter(
                                      edges: edges,
                                      activeEdges: _activeEdges,
                                      grid: _grid,
                                      lineColor: Colors.amber.shade600,
                                      dragPath: _dragPath,
                                      dragPositionNotifier: _dragPositionNotifier,
                                    ),
                                  ),
                                  for (int i = 0; i < 16; i++)
                                    Positioned(
                                      left: 35.0 + (i % 4) * 70.0 - 15.0,
                                      top: 35.0 + (i ~/ 4) * 70.0 - 15.0,
                                      child: IgnorePointer(
                                        child: Center(
                                          child: _grid[i] > 0
                                              ? Container(
                                                  width: 24, height: 24,
                                                  decoration: BoxDecoration(
                                                    color: _grid[i] == 1 ? Colors.white : Colors.black,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: Colors.grey.shade400, width: 2),
                                                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
                                                  ),
                                                )
                                              : Container(
                                                  width: 6, height: 6,
                                                  decoration: BoxDecoration(
                                                    color: context.textMuted.withOpacity(0.3),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                ],
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

class MasyuPainter extends CustomPainter {
  final List<List<int>> edges;
  final Map<String, bool> activeEdges;
  final List<int> grid;
  final Color lineColor;
  final List<int> dragPath;
  final ValueNotifier<Offset?> dragPositionNotifier;

  MasyuPainter({
    required this.edges,
    required this.activeEdges,
    required this.grid,
    required this.lineColor,
    required this.dragPath,
    required this.dragPositionNotifier,
  }) : super(repaint: dragPositionNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Grid Lines Helper dots
    final dotPaint = Paint()
      ..color = Colors.grey.shade900
      ..strokeWidth = 1;
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        canvas.drawCircle(Offset(35.0 + j * 70.0, 35.0 + i * 70.0), 1.5, dotPaint);
      }
    }

    // 2. Draw active loop edges
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var edge in edges) {
      int u = edge[0];
      int v = edge[1];
      String key = u < v ? '$u-$v' : '$v-$u';
      bool isActive = activeEdges[key] ?? false;
      if (isActive) {
        double x1 = 35.0 + (u % 4) * 70.0;
        double y1 = 35.0 + (u ~/ 4) * 70.0;
        double x2 = 35.0 + (v % 4) * 70.0;
        double y2 = 35.0 + (v ~/ 4) * 70.0;
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      }
    }

    // 3. Draw live line from last drag cell center to pointer
    final dragOffset = dragPositionNotifier.value;
    if (dragOffset != null && dragPath.isNotEmpty) {
      int last = dragPath.last;
      double x1 = 35.0 + (last % 4) * 70.0;
      double y1 = 35.0 + (last ~/ 4) * 70.0;
      final livePaint = Paint()
        ..color = lineColor.withOpacity(0.5)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(x1, y1), dragOffset, livePaint);
    }
  }

  @override
  bool shouldRepaint(covariant MasyuPainter oldDelegate) {
    return oldDelegate.activeEdges != activeEdges ||
        !listEquals(oldDelegate.grid, grid) ||
        oldDelegate.lineColor != lineColor ||
        !listEquals(oldDelegate.dragPath, dragPath) ||
        oldDelegate.dragPositionNotifier != dragPositionNotifier;
  }
}
