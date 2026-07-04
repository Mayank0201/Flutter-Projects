import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/auto_next_countdown.dart';

class SlitherlinkBetaScreen extends StatefulWidget {
  const SlitherlinkBetaScreen({super.key});
  @override
  State<SlitherlinkBetaScreen> createState() => _SlitherlinkBetaScreenState();
}
class _SlitherlinkBetaScreenState extends State<SlitherlinkBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _clues = List.filled(9, -1);
  List<bool> _edges = List.filled(24, false); // 12 horizontal, 12 vertical edges

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      _edges = List.filled(24, false);
      if (_currentLevel == 0) {
        _clues = [3, -1, 2, -1, 2, -1, -1, 1, -1];
      } else if (_currentLevel == 1) {
        _clues = [3, -1, 1, -1, 2, 1, 3, 3, 1];
      } else if (_currentLevel == 2) {
        _clues = [-1, -1, 2, 1, -1, -1, 2, 2, 2];
      } else if (_currentLevel == 3) {
        _clues = [2, 2, -1, 1, 2, -1, 3, -1, 1];
      } else if (_currentLevel == 4) {
        _clues = [3, 3, 3, 1, -1, 2, 3, 4, 3];
      } else if (_currentLevel == 5) {
        _clues = [3, -1, 2, -1, 2, -1, -1, 1, -1];
      } else if (_currentLevel == 6) {
        _clues = [3, -1, 1, -1, 2, 1, 3, 3, 1];
      } else if (_currentLevel == 7) {
        _clues = [-1, -1, 2, 1, -1, -1, 2, 2, 2];
      } else if (_currentLevel == 8) {
        _clues = [2, 2, -1, 1, 2, -1, 3, -1, 1];
      } else {
        _clues = [3, 3, 3, 1, -1, 2, 3, 4, 3];
      }
    });
  }

  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_slitherlink') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_slitherlink', _currentLevel + 1);
    }
    setState(() => _isSuccess = true);
  }

  bool _validateLoop() {
    // 1. Build adjacency list of vertices
    Map<int, List<int>> adj = {};
    for (int i = 0; i < 16; i++) adj[i] = [];

    // Horizontal edges
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 3; c++) {
        int idx = r * 4 + c;
        if (_edges[idx]) {
          int u = r * 4 + c;
          int v = r * 4 + c + 1;
          adj[u]!.add(v);
          adj[v]!.add(u);
        }
      }
    }

    // Vertical edges
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 4; c++) {
        int idx = 12 + r * 3 + c;
        if (_edges[idx]) {
          int u = r * 4 + c;
          int v = (r + 1) * 4 + c;
          adj[u]!.add(v);
          adj[v]!.add(u);
        }
      }
    }

    // Check degrees
    int activeCount = 0;
    int startVertex = -1;
    for (int i = 0; i < 16; i++) {
      int deg = adj[i]!.length;
      if (deg != 0 && deg != 2) return false; // degrees must be 0 or 2
      if (deg == 2) {
        activeCount++;
        if (startVertex == -1) startVertex = i;
      }
    }

    if (activeCount == 0) return false; // empty loop is not valid

    // Trace single component
    List<bool> visited = List.filled(16, false);
    int curr = startVertex;
    int prev = -1;
    int visitedCount = 0;

    while (curr != -1 && !visited[curr]) {
      visited[curr] = true;
      visitedCount++;
      int next = -1;
      for (int neighbor in adj[curr]!) {
        if (neighbor != prev) {
          next = neighbor;
          break;
        }
      }
      prev = curr;
      curr = next;
    }

    return visitedCount == activeCount && curr == startVertex;
  }

  void _checkSolution() {
    // Check if edge counts match clue requirements
    bool isValid = true;
    for (int i = 0; i < 9; i++) {
      int clue = _clues[i];
      if (clue >= 0) {
        int r = i ~/ 3; int c = i % 3;
        int topEdge = r * 4 + c;
        int bottomEdge = (r + 1) * 4 + c;
        int leftEdge = 12 + r * 3 + c;
        int rightEdge = 12 + r * 3 + c + 1;
        int count = 0;
        if (_edges[topEdge]) count++;
        if (_edges[bottomEdge]) count++;
        if (_edges[leftEdge]) count++;
        if (_edges[rightEdge]) count++;
        if (count != clue) isValid = false;
      }
    }
    
    // Check loop validity
    if (isValid && _validateLoop()) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Edges must match clue counts AND form a single continuous closed loop!'),
      ));
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

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text('How to Play Slitherlink', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
        content: Text(
          '1. Draw a single, continuous, closed loop by connecting adjacent dots with lines.\n\n'
          '2. The loop must NOT cross itself, branch off, or form multiple separate loops.\n\n'
          '3. The numbers inside the cells indicate exactly how many of its 4 boundary edges are part of the loop.\n\n'
          '4. Empty cells (without numbers) can have any number of active boundary edges.',
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

  void _showHint() {
    final solutions = [
      [true, false, false, false, false, true, false, false, false, false, true, false, true, true, true, true, false, true, true, false, false, true, false, false],
      [true, false, false, false, false, true, false, false, true, false, false, false, true, true, false, true, false, true, false, true, true, false, false, false],
      [true, true, false, false, false, false, false, false, false, false, false, false, true, true, true, true, false, true, true, false, true, false, false, false],
      [true, true, false, false, false, false, false, false, false, true, false, false, true, false, true, true, false, true, true, true, false, false, false, false],
      [true, false, false, false, false, true, true, false, false, true, false, false, true, true, true, true, false, false, true, true, true, true, false, false],
      [true, false, false, false, false, true, false, false, false, false, true, false, true, true, true, true, false, true, true, false, false, true, false, false],
      [true, false, false, false, false, true, false, false, true, false, false, false, true, true, false, true, false, true, false, true, true, false, false, false],
      [true, true, false, false, false, false, false, false, false, false, false, false, true, true, true, true, false, true, true, false, true, false, false, false],
      [true, true, false, false, false, false, false, false, false, true, false, false, true, false, true, true, false, true, true, true, false, false, false, false],
      [true, false, false, false, false, true, true, false, false, true, false, false, true, true, true, true, false, false, true, true, true, true, false, false],
    ];
    final sol = solutions[_currentLevel];
    int hintCell = -1;
    for (int i = 0; i < 24; i++) {
      if (_edges[i] != sol[i]) {
        hintCell = i;
        break;
      }
    }
    
    if (hintCell != -1) {
      setState(() {
        _edges[hintCell] = sol[hintCell];
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The board is already correctly solved!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Slitherlink', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Tap edges to draw a single continuous loop. Numbers indicate exactly how many of its 4 edges must be part of the loop.',
                            style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        RepaintBoundary(
                          child: Container(
                            width: 240, height: 240,
                            decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.textMuted.withAlpha(40))),
                            child: LayoutBuilder(builder: (context, constraints) {
                              double cs = constraints.maxWidth / 3;
                              return Stack(
                              children: [
                                for (int i = 0; i < 9; i++) ...[
                                  if (_clues[i] >= 0)
                                    Positioned(
                                      left: (i % 3) * cs, top: (i ~/ 3) * cs, width: cs, height: cs,
                                      child: Center(child: Text('${_clues[i]}', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.dustyMauve))),
                                    ),
                                ],
                                // Horizontal lines
                                for (int r = 0; r < 4; r++)
                                  for (int c = 0; c < 3; c++)
                                    Positioned(
                                      left: c * cs + 4, top: r * cs - 12, width: cs - 8, height: 24,
                                      child: GestureDetector(
                                        onTap: () => setState(() {
                                          int edgeIdx = r * 4 + c;
                                          _edges[edgeIdx] = !_edges[edgeIdx];
                                        }),
                                        child: Container(
                                          color: Colors.transparent,
                                          child: Center(
                                            child: Container(
                                              height: 4,
                                              color: _edges[r * 4 + c] ? Colors.amber : Colors.grey.shade800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                // Vertical lines
                                for (int r = 0; r < 3; r++)
                                  for (int c = 0; c < 4; c++)
                                    Positioned(
                                      left: c * cs - 12, top: r * cs + 4, width: 24, height: cs - 8,
                                      child: GestureDetector(
                                        onTap: () => setState(() {
                                          int edgeIdx = 12 + r * 3 + c;
                                          _edges[edgeIdx] = !_edges[edgeIdx];
                                        }),
                                        child: Container(
                                          color: Colors.transparent,
                                          child: Center(
                                            child: Container(
                                              width: 4,
                                              color: _edges[12 + r * 3 + c] ? Colors.amber : Colors.grey.shade800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                              ],
                            );
                          }),
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
