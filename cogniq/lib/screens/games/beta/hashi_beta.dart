import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import 'package:flutter/foundation.dart';

class HashiBetaScreen extends StatefulWidget {
  const HashiBetaScreen({super.key});
  @override
  State<HashiBetaScreen> createState() => _HashiBetaScreenState();
}

class _HashiBetaScreenState extends State<HashiBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _islands = List.filled(9, 0); // 3x3 grid
  Map<String, int> _bridgeCounts = {}; // Key: "min-max", Value: bridge count (0, 1, 2)

  // Drag variables
  int _dragStartIsland = -1;
  final ValueNotifier<Offset?> _dragPositionNotifier = ValueNotifier<Offset?>(null);

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      _bridgeCounts = {};
      _dragStartIsland = -1;
      _dragPositionNotifier.value = null;
      if (_currentLevel == 0) {
        _islands = [0, 0, 0, 0, 2, 1, 1, 2, 0];
      } else if (_currentLevel == 1) {
        _islands = [0, 0, 0, 0, 1, 0, 1, 3, 1];
      } else if (_currentLevel == 2) {
        _islands = [2, 2, 0, 2, 4, 2, 0, 2, 2];
      } else if (_currentLevel == 3) {
        _islands = [0, 0, 0, 0, 1, 2, 1, 0, 2];
      } else if (_currentLevel == 4) {
        _islands = [0, 0, 0, 0, 1, 1, 0, 2, 2];
      } else if (_currentLevel == 5) {
        _islands = [0, 0, 0, 0, 2, 1, 1, 2, 0];
      } else if (_currentLevel == 6) {
        _islands = [0, 0, 0, 0, 1, 0, 1, 3, 1];
      } else if (_currentLevel == 7) {
        _islands = [2, 2, 0, 2, 4, 2, 0, 2, 2];
      } else if (_currentLevel == 8) {
        _islands = [0, 0, 0, 0, 1, 2, 1, 0, 2];
      } else {
        _islands = [0, 0, 0, 0, 1, 1, 0, 2, 2];
      }
    });
  }

  List<List<int>> _getConnections() {
    List<List<int>> conns = [];
    for (int idx = 0; idx < 9; idx++) {
      if (_islands[idx] == 0) continue;
      int r = idx ~/ 3;
      int c = idx % 3;
      
      // Right
      for (int c2 = c + 1; c2 < 3; c2++) {
        int target = r * 3 + c2;
        if (_islands[target] > 0) {
          conns.add([idx, target]);
          break;
        }
      }
      
      // Down
      for (int r2 = r + 1; r2 < 3; r2++) {
        int target = r2 * 3 + c;
        if (_islands[target] > 0) {
          conns.add([idx, target]);
          break;
        }
      }
    }
    return conns;
  }

  int _getCurrentBridges(int i) {
    int sum = 0;
    _bridgeCounts.forEach((key, val) {
      final parts = key.split('-');
      int a = int.parse(parts[0]);
      int b = int.parse(parts[1]);
      if (a == i || b == i) sum += val;
    });
    return sum;
  }

  void _toggleBridge(int a, int b) {
    final key = a < b ? '$a-$b' : '$b-$a';
    setState(() {
      int current = _bridgeCounts[key] ?? 0;
      _bridgeCounts[key] = (current + 1) % 3;
    });
  }

  int _getIslandAt(Offset localPos) {
    for (int idx = 0; idx < 9; idx++) {
      if (_islands[idx] == 0) continue;
      double cx = 40.0 + (idx % 3) * 80.0;
      double cy = 40.0 + (idx ~/ 3) * 80.0;
      double dist = (localPos - Offset(cx, cy)).distance;
      if (dist < 24.0) {
        return idx;
      }
    }
    return -1;
  }

  bool _isAdjacent(int a, int b) {
    int r1 = a ~/ 3; int c1 = a % 3;
    int r2 = b ~/ 3; int c2 = b % 3;

    if (r1 == r2) {
      int minC = r1 * 3 + (c1 < c2 ? c1 : c2);
      int maxC = r1 * 3 + (c1 < c2 ? c2 : c1);
      // Check no islands in between
      for (int i = minC + 1; i < maxC; i++) {
        if (_islands[i] > 0) return false;
      }
      return true;
    } else if (c1 == c2) {
      int minR = (r1 < r2 ? r1 : r2);
      int maxR = (r1 < r2 ? r2 : r1);
      for (int r = minR + 1; r < maxR; r++) {
        int i = r * 3 + c1;
        if (_islands[i] > 0) return false;
      }
      return true;
    }
    return false;
  }

  void _onPanStart(DragStartDetails d) {
    if (_isSuccess) return;
    int idx = _getIslandAt(d.localPosition);
    if (idx != -1) {
      settingsNotifier.hapticTap();
      _dragStartIsland = idx;
      double cx = 40.0 + (idx % 3) * 80.0;
      double cy = 40.0 + (idx ~/ 3) * 80.0;
      _dragPositionNotifier.value = Offset(cx, cy);
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_isSuccess || _dragStartIsland == -1) return;
    _dragPositionNotifier.value = d.localPosition;
  }

  void _onPanEnd(DragEndDetails d) {
    if (_isSuccess || _dragStartIsland == -1) return;
    final releasePos = _dragPositionNotifier.value;
    _dragPositionNotifier.value = null;

    if (releasePos != null) {
      int targetIdx = _getIslandAt(releasePos);
      if (targetIdx != -1 && targetIdx != _dragStartIsland) {
        if (_isAdjacent(_dragStartIsland, targetIdx)) {
          settingsNotifier.hapticTap();
          _toggleBridge(_dragStartIsland, targetIdx);
        }
      }
    }
    _dragStartIsland = -1;
  }

  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_hashi') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_hashi', _currentLevel + 1);
    }
    setState(() => _isSuccess = true);
  }

  void _checkSolution() {
    bool isValid = true;
    for (int i = 0; i < 9; i++) {
      int clue = _islands[i];
      if (clue > 0) {
        if (_getCurrentBridges(i) != clue) {
          isValid = false;
        }
      }
    }
    
    if (isValid) {
      List<int> activeIslands = [];
      for (int i = 0; i < 9; i++) {
        if (_islands[i] > 0) activeIslands.add(i);
      }
      
      if (activeIslands.isNotEmpty) {
        List<bool> visited = List.filled(9, false);
        List<int> queue = [activeIslands[0]];
        visited[activeIslands[0]] = true;
        int visitedCount = 1;
        
        while (queue.isNotEmpty) {
          int curr = queue.removeAt(0);
          _bridgeCounts.forEach((key, val) {
            if (val > 0) {
              final parts = key.split('-');
              int a = int.parse(parts[0]);
              int b = int.parse(parts[1]);
              if (a == curr && !visited[b]) {
                visited[b] = true;
                queue.add(b);
                visitedCount++;
              } else if (b == curr && !visited[a]) {
                visited[a] = true;
                queue.add(a);
                visitedCount++;
              }
            }
          });
        }
        
        if (visitedCount != activeIslands.length) {
          isValid = false;
        }
      }
    }

    if (isValid) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bridge rules violated! Check connection counts and connectivity.')));
    }
  }

  void _showHint() {
    final solutions = [
      {"4-5": 1, "4-7": 1, "6-7": 1},
      {"4-7": 1, "6-7": 1, "7-8": 1},
      {"0-1": 1, "0-3": 1, "1-4": 1, "3-4": 1, "4-5": 1, "4-7": 1, "5-8": 1, "7-8": 1},
      {"4-5": 1, "5-8": 1, "6-8": 1},
      {"4-7": 1, "5-8": 1, "7-8": 1},
      {"4-5": 1, "4-7": 1, "6-7": 1},
      {"4-7": 1, "6-7": 1, "7-8": 1},
      {"0-1": 1, "0-3": 1, "1-4": 1, "3-4": 1, "4-5": 1, "4-7": 1, "5-8": 1, "7-8": 1},
      {"4-5": 1, "5-8": 1, "6-8": 1},
      {"4-7": 1, "5-8": 1, "7-8": 1},
    ];
    final sol = solutions[_currentLevel];
    String? hintKey;
    int hintVal = 0;
    
    final conns = _getConnections();
    for (var conn in conns) {
      int a = conn[0]; int b = conn[1];
      final key = a < b ? '$a-$b' : '$b-$a';
      int current = _bridgeCounts[key] ?? 0;
      int target = sol[key] ?? 0;
      if (current != target) {
        hintKey = key;
        hintVal = target;
        break;
      }
    }
    
    if (hintKey != null) {
      setState(() {
        _bridgeCounts[hintKey!] = hintVal;
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
    final conns = _getConnections();
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Hashi', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        Text('Drag from one island to another to draw bridges. Connect all islands into a single network.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        RepaintBoundary(
                          child: GestureDetector(
                            onPanStart: _onPanStart,
                            onPanUpdate: _onPanUpdate,
                            onPanEnd: _onPanEnd,
                            child: Container(
                              width: 240, height: 240,
                              decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.textMuted.withAlpha(40))),
                              child: Stack(
                                children: [
                                  CustomPaint(
                                    size: const Size(240, 240),
                                    painter: HashiPainter(
                                      conns: conns,
                                      bridgeCounts: _bridgeCounts,
                                      islands: _islands,
                                      lineColor: AppTheme.dustyMauve,
                                      dragStartIsland: _dragStartIsland,
                                      dragPositionNotifier: _dragPositionNotifier,
                                    ),
                                  ),
                                  for (int i = 0; i < 9; i++)
                                    if (_islands[i] > 0)
                                      Positioned(
                                        left: 40.0 + (i % 3) * 80.0 - 20.0,
                                        top: 40.0 + (i ~/ 3) * 80.0 - 20.0,
                                        child: Builder(
                                          builder: (context) {
                                            int sum = _getCurrentBridges(i);
                                            Color nodeColor = sum == _islands[i]
                                                ? Colors.green.shade700
                                                : (sum > _islands[i] ? Colors.red.shade700 : AppTheme.dustyMauve);
                                            return Container(
                                              width: 40, height: 40,
                                              decoration: BoxDecoration(
                                                color: nodeColor,
                                                shape: BoxShape.circle,
                                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                                              ),
                                              child: Center(
                                                child: Text('${_islands[i]}', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                              ),
                                            );
                                          }
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

class HashiPainter extends CustomPainter {
  final List<List<int>> conns;
  final Map<String, int> bridgeCounts;
  final List<int> islands;
  final Color lineColor;
  final int dragStartIsland;
  final ValueNotifier<Offset?> dragPositionNotifier;

  HashiPainter({
    required this.conns,
    required this.bridgeCounts,
    required this.islands,
    required this.lineColor,
    required this.dragStartIsland,
    required this.dragPositionNotifier,
  }) : super(repaint: dragPositionNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // 1. Draw existing bridges
    for (var conn in conns) {
      int a = conn[0];
      int b = conn[1];
      final key = a < b ? '$a-$b' : '$b-$a';
      int val = bridgeCounts[key] ?? 0;

      double x1 = 40.0 + (a % 3) * 80.0;
      double y1 = 40.0 + (a ~/ 3) * 80.0;
      double x2 = 40.0 + (b % 3) * 80.0;
      double y2 = 40.0 + (b ~/ 3) * 80.0;

      if (val == 0) {
        paint.color = lineColor.withOpacity(0.15);
        paint.strokeWidth = 1.5;
        double dx = x2 - x1;
        double dy = y2 - y1;
        double len = Offset(dx, dy).distance;
        int dashes = (len / 6).floor();
        for (int i = 0; i < dashes; i++) {
          if (i % 2 == 0) {
            canvas.drawLine(
              Offset(x1 + dx * (i / dashes), y1 + dy * (i / dashes)),
              Offset(x1 + dx * ((i + 1) / dashes), y1 + dy * ((i + 1) / dashes)),
              paint,
            );
          }
        }
      } else if (val == 1) {
        paint.color = lineColor;
        paint.strokeWidth = 3;
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      } else if (val == 2) {
        paint.color = lineColor;
        paint.strokeWidth = 2;
        double dx = x2 - x1;
        double dy = y2 - y1;
        double len = Offset(dx, dy).distance;
        double px = -dy / len;
        double py = dx / len;
        
        canvas.drawLine(
          Offset(x1 + px * 4, y1 + py * 4),
          Offset(x2 + px * 4, y2 + py * 4),
          paint,
        );
        canvas.drawLine(
          Offset(x1 - px * 4, y1 - py * 4),
          Offset(x2 - px * 4, y2 - py * 4),
          paint,
        );
      }
    }

    // 2. Draw live rubber-band drag line
    final dragOffset = dragPositionNotifier.value;
    if (dragOffset != null && dragStartIsland != -1) {
      paint.color = lineColor.withOpacity(0.5);
      paint.strokeWidth = 3.0;
      double x1 = 40.0 + (dragStartIsland % 3) * 80.0;
      double y1 = 40.0 + (dragStartIsland ~/ 3) * 80.0;
      canvas.drawLine(Offset(x1, y1), dragOffset, paint);
    }
  }

  @override
  bool shouldRepaint(covariant HashiPainter oldDelegate) {
    return !listEquals(oldDelegate.conns, conns) ||
        oldDelegate.bridgeCounts != bridgeCounts ||
        !listEquals(oldDelegate.islands, islands) ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.dragStartIsland != dragStartIsland ||
        oldDelegate.dragPositionNotifier != dragPositionNotifier;
  }
}
