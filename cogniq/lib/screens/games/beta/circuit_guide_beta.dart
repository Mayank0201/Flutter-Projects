import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';

class CircuitGuideBetaScreen extends StatefulWidget {
  const CircuitGuideBetaScreen({super.key});
  @override
  State<CircuitGuideBetaScreen> createState() => _CircuitGuideBetaScreenState();
}

class _CircuitGuideBetaScreenState extends State<CircuitGuideBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _rotations = List.filled(9, 0); // 0 to 3
  List<String> _wireTypes = List.filled(9, "S"); // "SRC", "TGT", "S", "E"

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      if (_currentLevel == 0) {
        // Path: 0 -> 1 -> 4 -> 7 -> 8
        _wireTypes = ["SRC", "E", "S", "S", "S", "E", "S", "E", "TGT"];
        _rotations = [0, 1, 0, 0, 0, 1, 1, 3, 0]; // Scrambled
      } else if (_currentLevel == 1) {
        // Path: 0 -> 3 -> 6 -> 7 -> 8
        _wireTypes = ["SRC", "S", "S", "E", "S", "S", "E", "S", "TGT"];
        _rotations = [0, 0, 1, 2, 0, 0, 0, 0, 0];
      } else if (_currentLevel == 2) {
        // Path: 0 -> 1 -> 2 -> 5 -> 8
        _wireTypes = ["SRC", "S", "E", "S", "E", "S", "S", "S", "TGT"];
        _rotations = [0, 1, 2, 0, 3, 1, 0, 0, 0];
      } else if (_currentLevel == 3) {
        // Path: 0 -> 1 -> 4 -> 5 -> 8
        _wireTypes = ["SRC", "E", "S", "S", "E", "E", "S", "S", "TGT"];
        _rotations = [0, 3, 0, 1, 2, 0, 1, 0, 0];
      } else if (_currentLevel == 4) {
        // Path: 0 -> 3 -> 4 -> 5 -> 8
        _wireTypes = ["SRC", "S", "S", "S", "S", "E", "S", "S", "TGT"];
        _rotations = [0, 1, 0, 1, 0, 2, 1, 0, 0];
      } else if (_currentLevel == 5) {
        // Path: 0 -> 1 -> 4 -> 7 -> 8
        _wireTypes = ["SRC", "E", "S", "S", "S", "E", "S", "E", "TGT"];
        _rotations = [0, 1, 0, 0, 0, 1, 1, 3, 0]; // Scrambled
      } else if (_currentLevel == 6) {
        // Path: 0 -> 3 -> 6 -> 7 -> 8
        _wireTypes = ["SRC", "S", "S", "E", "S", "S", "E", "S", "TGT"];
        _rotations = [0, 0, 1, 2, 0, 0, 0, 0, 0];
      } else if (_currentLevel == 7) {
        // Path: 0 -> 1 -> 2 -> 5 -> 8
        _wireTypes = ["SRC", "S", "E", "S", "E", "S", "S", "S", "TGT"];
        _rotations = [0, 1, 2, 0, 3, 1, 0, 0, 0];
      } else if (_currentLevel == 8) {
        // Path: 0 -> 1 -> 4 -> 5 -> 8
        _wireTypes = ["SRC", "E", "S", "S", "E", "E", "S", "S", "TGT"];
        _rotations = [0, 3, 0, 1, 2, 0, 1, 0, 0];
      } else {
        // Path: 0 -> 3 -> 4 -> 5 -> 8
        _wireTypes = ["SRC", "S", "S", "S", "S", "E", "S", "S", "TGT"];
        _rotations = [0, 1, 0, 1, 0, 2, 1, 0, 0];
      }
      
      // Source & Target always rotation 0
      _rotations[0] = 0;
      _rotations[8] = 0;
    });
  }

  // Get active connections for a node: 0=North, 1=East, 2=South, 3=West
  List<int> _getConnections(int idx) {
    final type = _wireTypes[idx];
    final rot = _rotations[idx];

    if (type == "SRC") {
      return [1]; // Source only connects East
    }
    if (type == "TGT") {
      return [3]; // Target only connects West
    }
    if (type == "S") {
      // Straight wire
      if (rot == 0 || rot == 2) {
        return [1, 3]; // East, West
      } else {
        return [0, 2]; // North, South
      }
    }
    if (type == "E") {
      // Elbow wire
      // rot 0: North & East, rot 1: East & South, rot 2: South & West, rot 3: West & North
      return [rot, (rot + 1) % 4];
    }
    return [];
  }

  // Check connectivity starting from Source (0)
  List<bool> _getConnectedStatus() {
    List<bool> connected = List.filled(9, false);
    connected[0] = true;

    List<int> queue = [0];
    List<bool> visited = List.filled(9, false);
    visited[0] = true;

    while (queue.isNotEmpty) {
      int curr = queue.removeAt(0);
      int r = curr ~/ 3;
      int c = curr % 3;

      List<int> currConn = _getConnections(curr);

      for (int dir in currConn) {
        int nr = r;
        int nc = c;
        int oppDir = -1;

        if (dir == 0) { nr--; oppDir = 2; } // North -> look South
        if (dir == 1) { nc++; oppDir = 3; } // East -> look West
        if (dir == 2) { nr++; oppDir = 0; } // South -> look North
        if (dir == 3) { nc--; oppDir = 1; } // West -> look East

        if (nr >= 0 && nr < 3 && nc >= 0 && nc < 3) {
          int nextIdx = nr * 3 + nc;
          if (!visited[nextIdx]) {
            List<int> nextConn = _getConnections(nextIdx);
            if (nextConn.contains(oppDir)) {
              connected[nextIdx] = true;
              visited[nextIdx] = true;
              queue.add(nextIdx);
            }
          }
        }
      }
    }
    return connected;
  }

  void _onRotate(int idx) {
    if (_isSuccess) return;
    if (_wireTypes[idx] == "SRC" || _wireTypes[idx] == "TGT") return;

    settingsNotifier.hapticTap();

    setState(() {
      _rotations[idx] = (_rotations[idx] + 1) % 4;
      
      // Auto check solution
      final connected = _getConnectedStatus();
      if (connected[8]) {
        _onLevelCleared();
      }
    });
  }

  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_circuit') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_circuit', _currentLevel + 1);
    }
    setState(() => _isSuccess = true);
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

  void _showHint() {
    setState(() {
      // Set correct rotations for levels
      if (_currentLevel == 0) {
        _rotations = [0, 2, 0, 0, 1, 1, 0, 0, 0];
      } else if (_currentLevel == 1) {
        _rotations = [0, 0, 0, 1, 0, 0, 0, 0, 0];
      } else if (_currentLevel == 2) {
        _rotations = [0, 0, 2, 0, 2, 1, 0, 0, 0];
      } else if (_currentLevel == 3) {
        _rotations = [0, 2, 0, 0, 1, 3, 0, 0, 0];
      } else if (_currentLevel == 4) {
        _rotations = [0, 0, 0, 1, 0, 2, 0, 0, 0];
      } else if (_currentLevel == 5) {
        _rotations = [0, 2, 0, 0, 1, 1, 0, 0, 0];
      } else if (_currentLevel == 6) {
        _rotations = [0, 0, 0, 1, 0, 0, 0, 0, 0];
      } else if (_currentLevel == 7) {
        _rotations = [0, 0, 2, 0, 2, 1, 0, 0, 0];
      } else if (_currentLevel == 8) {
        _rotations = [0, 2, 0, 0, 1, 3, 0, 0, 0];
      } else {
        _rotations = [0, 0, 0, 1, 0, 2, 0, 0, 0];
      }
      if (_getConnectedStatus()[8]) {
        _onLevelCleared();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final connected = _getConnectedStatus();

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Circuit Guide', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        Text('Rotate nodes to connect the Power Source (⚡) to the Bulb (💡).', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        RepaintBoundary(
                          child: Container(
                            width: 240, height: 240,
                            decoration: BoxDecoration(
                              color: context.bgCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.textMuted.withAlpha(40)),
                            ),
                            child: GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
                              itemCount: 9,
                              itemBuilder: (context, idx) {
                                final isNodeConnected = connected[idx];
                                return GestureDetector(
                                  onTap: () => _onRotate(idx),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: context.bgCard,
                                      border: Border.all(color: Colors.grey.shade900),
                                    ),
                                    child: CustomPaint(
                                      painter: WirePainter(
                                        type: _wireTypes[idx],
                                        rotation: _rotations[idx],
                                        isConnected: isNodeConnected,
                                        activeColor: Colors.amber,
                                      ),
                                    ),
                                  ),
                                );
                              },
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

class WirePainter extends CustomPainter {
  final String type;
  final int rotation;
  final bool isConnected;
  final Color activeColor;

  WirePainter({
    required this.type,
    required this.rotation,
    required this.isConnected,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isConnected ? activeColor : Colors.grey.shade700
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double cy = h / 2;

    if (type == "SRC") {
      final fillPaint = Paint()
        ..color = isConnected ? activeColor.withOpacity(0.2) : Colors.transparent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), cx * 0.5, fillPaint);
      
      final borderPaint = Paint()
        ..color = isConnected ? activeColor : Colors.grey.shade600
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(cx, cy), cx * 0.5, borderPaint);

      // Draw standard electric bolt representation inside source
      final textPainter = TextPainter(
        text: TextSpan(
          text: "⚡",
          style: TextStyle(fontSize: 20, color: isConnected ? Colors.amber : Colors.grey),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(cx - textPainter.width / 2, cy - textPainter.height / 2));

      // Draw wire pointing East
      canvas.drawLine(Offset(cx + cx * 0.5, cy), Offset(w, cy), paint);
    } else if (type == "TGT") {
      final fillPaint = Paint()
        ..color = isConnected ? activeColor.withOpacity(0.2) : Colors.transparent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), cx * 0.5, fillPaint);
      
      final borderPaint = Paint()
        ..color = isConnected ? activeColor : Colors.grey.shade600
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(cx, cy), cx * 0.5, borderPaint);

      // Draw bulb representation inside target
      final textPainter = TextPainter(
        text: TextSpan(
          text: "💡",
          style: TextStyle(fontSize: 20, color: isConnected ? Colors.amber : Colors.grey),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(cx - textPainter.width / 2, cy - textPainter.height / 2));

      // Draw wire pointing West
      canvas.drawLine(Offset(0, cy), Offset(cx - cx * 0.5, cy), paint);
    } else {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rotation * 3.14159265 / 2);
      canvas.translate(-cx, -cy);

      if (type == "S") {
        canvas.drawLine(Offset(0, cy), Offset(w, cy), paint);
      } else if (type == "E") {
        canvas.drawArc(
          Rect.fromCircle(center: Offset(w, 0), radius: cx),
          3.14159265 * 0.5,
          3.14159265 * 0.5,
          false,
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant WirePainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.rotation != rotation ||
        oldDelegate.isConnected != isConnected ||
        oldDelegate.activeColor != activeColor;
  }
}
