import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/buy_hints_dialog.dart';
import '../../../widgets/fog_overlay.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../utils/prefs_keys.dart';
import '../../../utils/hint_manager.dart';

class SlitherlinkScreen extends StatefulWidget {
  const SlitherlinkScreen({super.key});

  @override
  State<SlitherlinkScreen> createState() => _SlitherlinkScreenState();
}

class _SlitherlinkScreenState extends State<SlitherlinkScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  double _dailyRadius = 1.5;
  int _gridSize = 3; // 3, 4, or 5 cells

  List<int> _clues = []; // -1 for empty/hidden clue
  List<int> _edges = []; // 0: none, 1: line, 2: X
  List<bool> _solution = []; // Correct solution edge mask (true = line)

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgressAndGenerate();
  }

  Future<void> _loadProgressAndGenerate() async {
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString(PrefsKeys.dailyModifierType) ?? '';
      final extraParamsStr = prefs.getString(PrefsKeys.dailyModifierExtraParams) ?? '';
      if (extraParamsStr.isNotEmpty) {
        try {
          final extraParams = jsonDecode(extraParamsStr) as Map<String, dynamic>;
          if (extraParams.containsKey('radius')) {
            _dailyRadius = (extraParams['radius'] as num).toDouble();
          } else {
            _dailyRadius = 1.5;
          }
        } catch (_) {
          _dailyRadius = 1.5;
        }
      } else {
        _dailyRadius = 1.5;
      }
    } else {
      _dailyModifierType = '';
      _dailyRadius = 1.5;
    }

    int level = prefs.getInt(PrefsKeys.gameLevel('slitherlink')) ?? 0;
    if (mounted) {
      setState(() {
        _currentLevel = level;
        _isLoading = true;
      });
      _generatePuzzle();
    }
  }

  void _generatePuzzle() {
    if (_currentLevel < 5) {
      _gridSize = 3;
    } else if (_currentLevel < 12) {
      _gridSize = 4;
    } else {
      _gridSize = 5;
    }

    final numH = (_gridSize + 1) * _gridSize;
    final numV = _gridSize * (_gridSize + 1);
    final totalEdges = numH + numV;

    _edges = List.filled(totalEdges, 0);
    _solution = List.filled(totalEdges, false);

    final rand = Random();
    // 1. Generate a valid Jordan Curve loop by growing cells
    Set<int> loopCells = _generateSimplyConnectedCells(rand);

    // 2. Derive the correct edge solution from the loop cells
    _deriveSolutionEdges(loopCells);

    // 3. Compute clues for each cell based on the solution loop
    _clues = List.filled(_gridSize * _gridSize, -1);
    for (int i = 0; i < _gridSize * _gridSize; i++) {
      _clues[i] = _countCellEdgesInSolution(i);
    }

    // 4. Hide random clues (approx 40-50% clues hidden)
    int hideCount = (_gridSize * _gridSize) ~/ 2;
    List<int> indices = List.generate(_gridSize * _gridSize, (i) => i)..shuffle(rand);
    for (int i = 0; i < hideCount; i++) {
      _clues[indices[i]] = -1;
    }

    setState(() {
      _isSuccess = false;
      _isLoading = false;
    });
  }

  Set<int> _generateSimplyConnectedCells(Random rand) {
    Set<int> cells = {};
    int targetSize = 2; // Default size
    if (_gridSize == 3) {
      targetSize = rand.nextInt(3) + 3; // 3 to 5 cells
    } else if (_gridSize == 4) {
      targetSize = rand.nextInt(4) + 6; // 6 to 9 cells
    } else {
      targetSize = rand.nextInt(5) + 10; // 10 to 14 cells
    }

    // Start with a random cell
    int startCell = rand.nextInt(_gridSize * _gridSize);
    cells.add(startCell);

    while (cells.length < targetSize) {
      // Collect candidate neighbors adjacent to the current set
      List<int> candidates = [];
      for (final cell in cells) {
        int r = cell ~/ _gridSize;
        int c = cell % _gridSize;

        final adj = <int>[];
        if (r > 0) adj.add(cell - _gridSize);
        if (r < _gridSize - 1) adj.add(cell + _gridSize);
        if (c > 0) adj.add(cell - 1);
        if (c < _gridSize - 1) adj.add(cell + 1);

        for (final a in adj) {
          if (!cells.contains(a)) {
            candidates.add(a);
          }
        }
      }

      if (candidates.isEmpty) break;

      // Shuffle and pick one candidate that preserves simple connectivity (no holes)
      candidates.shuffle(rand);
      bool added = false;
      for (final cand in candidates) {
        // Temporarily add and verify no holes are created
        cells.add(cand);
        if (_isSimplyConnected(cells)) {
          added = true;
          break;
        } else {
          cells.remove(cand);
        }
      }

      if (!added) {
        // Fallback: forcefully add one if stuck
        cells.add(candidates.first);
      }
    }

    return cells;
  }

  bool _isSimplyConnected(Set<int> cells) {
    // A grid is simply connected if the cells form exactly one connected component,
    // and the complement (outside cells + boundaries) also forms exactly one connected component.
    
    // 1. Check path connectivity of the cells
    if (cells.isEmpty) return false;
    final cellList = cells.toList();
    List<bool> visited = List.filled(_gridSize * _gridSize, false);
    List<int> queue = [cellList.first];
    visited[cellList.first] = true;
    int visitedCount = 1;

    int qHead = 0;
    while (qHead < queue.length) {
      int idx = queue[qHead++];
      int r = idx ~/ _gridSize;
      int c = idx % _gridSize;

      final neighbors = <int>[];
      if (r > 0) neighbors.add(idx - _gridSize);
      if (r < _gridSize - 1) neighbors.add(idx + _gridSize);
      if (c > 0) neighbors.add(idx - 1);
      if (c < _gridSize - 1) neighbors.add(idx + 1);

      for (final n in neighbors) {
        if (cells.contains(n) && !visited[n]) {
          visited[n] = true;
          queue.add(n);
          visitedCount++;
        }
      }
    }

    if (visitedCount != cells.length) return false;

    // 2. Check path connectivity of the complement cells (including outer boundary)
    // We can run BFS on all non-selected cells. To handle borders correctly,
    // we can imagine an extra border of padding around the grid.
    final paddedSize = _gridSize + 2;
    final totalPadded = paddedSize * paddedSize;
    List<bool> compVisited = List.filled(totalPadded, false);

    // Any cell in padded grid is 'complement' if it doesn't map to a selected cell
    bool isComplement(int idx) {
      int r = idx ~/ paddedSize;
      int c = idx % paddedSize;
      if (r == 0 || r == paddedSize - 1 || c == 0 || c == paddedSize - 1) {
        return true;
      }
      int origCell = (r - 1) * _gridSize + (c - 1);
      return !cells.contains(origCell);
    }

    int startComp = 0; // Top-left cell of padding is always complement
    List<int> compQueue = [startComp];
    compVisited[startComp] = true;
    int compVisitedCount = 1;

    int cqHead = 0;
    while (cqHead < compQueue.length) {
      int idx = compQueue[cqHead++];
      int r = idx ~/ paddedSize;
      int c = idx % paddedSize;

      final neighbors = <int>[];
      if (r > 0) neighbors.add(idx - paddedSize);
      if (r < paddedSize - 1) neighbors.add(idx + paddedSize);
      if (c > 0) neighbors.add(idx - 1);
      if (c < paddedSize - 1) neighbors.add(idx + 1);

      for (final n in neighbors) {
        if (!compVisited[n] && isComplement(n)) {
          compVisited[n] = true;
          compQueue.add(n);
          compVisitedCount++;
        }
      }
    }

    int expectedComplement = totalPadded - cells.length;
    return compVisitedCount == expectedComplement;
  }

  void _deriveSolutionEdges(Set<int> loopCells) {
    // An edge is in the loop if it separates a cell in loopCells from one not in loopCells.
    final numH = (_gridSize + 1) * _gridSize;

    // Horizontal edges
    for (int r = 0; r <= _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        int idx = r * _gridSize + c;
        int upperCell = (r - 1) * _gridSize + c;
        int lowerCell = r * _gridSize + c;

        bool hasUpper = r > 0 && loopCells.contains(upperCell);
        bool hasLower = r < _gridSize && loopCells.contains(lowerCell);

        _solution[idx] = hasUpper != hasLower;
      }
    }

    // Vertical edges
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c <= _gridSize; c++) {
        int idx = numH + r * (_gridSize + 1) + c;
        int leftCell = r * _gridSize + (c - 1);
        int rightCell = r * _gridSize + c;

        bool hasLeft = c > 0 && loopCells.contains(leftCell);
        bool hasRight = c < _gridSize && loopCells.contains(rightCell);

        _solution[idx] = hasLeft != hasRight;
      }
    }
  }

  int _countCellEdgesInSolution(int cellIdx) {
    int r = cellIdx ~/ _gridSize;
    int c = cellIdx % _gridSize;
    final numH = (_gridSize + 1) * _gridSize;

    int topEdge = r * _gridSize + c;
    int bottomEdge = (r + 1) * _gridSize + c;
    int leftEdge = numH + r * (_gridSize + 1) + c;
    int rightEdge = numH + r * (_gridSize + 1) + c + 1;

    int count = 0;
    if (_solution[topEdge]) count++;
    if (_solution[bottomEdge]) count++;
    if (_solution[leftEdge]) count++;
    if (_solution[rightEdge]) count++;
    return count;
  }

  int _countCellEdgesInPlayerGrid(int cellIdx) {
    int r = cellIdx ~/ _gridSize;
    int c = cellIdx % _gridSize;
    final numH = (_gridSize + 1) * _gridSize;

    int topEdge = r * _gridSize + c;
    int bottomEdge = (r + 1) * _gridSize + c;
    int leftEdge = numH + r * (_gridSize + 1) + c;
    int rightEdge = numH + r * (_gridSize + 1) + c + 1;

    int count = 0;
    if (_edges[topEdge] == 1) count++;
    if (_edges[bottomEdge] == 1) count++;
    if (_edges[leftEdge] == 1) count++;
    if (_edges[rightEdge] == 1) count++;
    return count;
  }

  bool _validateLoop() {
    final numVertices = (_gridSize + 1) * (_gridSize + 1);
    final numH = (_gridSize + 1) * _gridSize;

    // 1. Build adjacency list of vertices
    Map<int, List<int>> adj = {};
    for (int i = 0; i < numVertices; i++) adj[i] = [];

    // Horizontal edges
    for (int r = 0; r <= _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        int idx = r * _gridSize + c;
        if (_edges[idx] == 1) {
          int u = r * (_gridSize + 1) + c;
          int v = r * (_gridSize + 1) + c + 1;
          adj[u]!.add(v);
          adj[v]!.add(u);
        }
      }
    }

    // Vertical edges
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c <= _gridSize; c++) {
        int idx = numH + r * (_gridSize + 1) + c;
        if (_edges[idx] == 1) {
          int u = r * (_gridSize + 1) + c;
          int v = (r + 1) * (_gridSize + 1) + c;
          adj[u]!.add(v);
          adj[v]!.add(u);
        }
      }
    }

    int activeCount = 0;
    int startVertex = -1;
    for (int i = 0; i < numVertices; i++) {
      int deg = adj[i]!.length;
      if (deg != 0 && deg != 2) return false;
      if (deg == 2) {
        activeCount++;
        if (startVertex == -1) startVertex = i;
      }
    }

    if (activeCount == 0) return false;

    // Trace components to ensure it's a single closed loop
    List<bool> visited = List.filled(numVertices, false);
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
    bool isValid = true;

    // Check cell clue counts
    for (int i = 0; i < _gridSize * _gridSize; i++) {
      int clue = _clues[i];
      if (clue >= 0) {
        if (_countCellEdgesInPlayerGrid(i) != clue) {
          isValid = false;
          break;
        }
      }
    }

    if (isValid && _validateLoop()) {
      settingsNotifier.hapticSuccess();
      _onLevelCleared();
    } else {
      settingsNotifier.hapticError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Edges must match clue counts AND form a single continuous closed loop!'),
        ),
      );
    }
  }

  Future<void> _onLevelCleared() async {
    if (!_playDailyMode) {
      final prefs = await SharedPreferences.getInstance();
      int highest = prefs.getInt('beta_level_slitherlink') ?? 0;
      if (_currentLevel + 1 > highest) {
        await prefs.setInt('beta_level_slitherlink', _currentLevel + 1);
      }
      await prefs.setInt(PrefsKeys.gameLevel('slitherlink'), _currentLevel + 1);

      int currentClears = prefs.getInt(PrefsKeys.globalLevelClearedCount) ?? 0;
      await prefs.setInt(PrefsKeys.globalLevelClearedCount, currentClears + 1);
    }

    setState(() => _isSuccess = true);
  }

  void _nextLevel() {
    setState(() {
      _currentLevel++;
      _isLoading = true;
    });
    _generatePuzzle();
  }

  void _showHint() async {
    int hintCell = -1;
    for (int i = 0; i < _edges.length; i++) {
      int solVal = _solution[i] ? 1 : 0;
      if (_edges[i] != solVal) {
        hintCell = i;
        break;
      }
    }

    if (hintCell != -1) {
      final hints = await HintManager.getHints('slitherlink');
      if (hints > 0) {
        await HintManager.useHint('slitherlink');
        setState(() {
          _edges[hintCell] = _solution[hintCell] ? 1 : 0;
        });
      } else {
        BuyHintsDialog.show(context, initialGameId: 'slitherlink', onPurchaseComplete: () {
          setState(() {});
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The board is already correctly solved!')),
      );
    }
  }

  void _toggleEdge(int idx) {
    settingsNotifier.hapticTap();
    setState(() {
      // Cycle: none (0) -> line (1) -> cross (2) -> none (0)
      _edges[idx] = (_edges[idx] + 1) % 3;
    });
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text(
          'How to Play Slitherlink',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        content: Text(
          '1. Draw a single, continuous, closed loop by connecting adjacent dots with lines.\n\n'
          '2. The loop must NOT cross itself, branch off, or form separate loops.\n\n'
          '3. The numbers inside cells indicate exactly how many of its 4 boundary edges are part of the loop.\n\n'
          '4. Empty cells (without numbers) can have any number of active boundary edges.',
          style: GoogleFonts.outfit(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style: GoogleFonts.outfit(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.bgDark,
        body: const Center(child: CircularProgressIndicator(color: AppTheme.dustyMauve)),
      );
    }

    final double boardSize = MediaQuery.of(context).size.width * 0.85;

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
            child: Center(
              child: Text(
                _playDailyMode ? 'Challenge' : 'Level ${_currentLevel + 1}',
                style: AppTheme.numberStyle(
                  color: AppTheme.dustyMauve,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
                        Text(
                          'Tap between dots to toggle: Line ➔ Cross (X) ➔ Empty.',
                          style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        RepaintBoundary(
                          child: Container(
                            width: boardSize,
                            height: boardSize,
                            decoration: BoxDecoration(
                              color: context.bgCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.textMuted.withAlpha(40)),
                            ),
                            child: FogOverlay(
                              enabled: _playDailyMode && _dailyModifierType == 'fog',
                              radius: (boardSize / _gridSize) * _dailyRadius,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                final double cellSpacing = constraints.maxWidth / _gridSize;
                                final numH = (_gridSize + 1) * _gridSize;

                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // 1. Clue Numbers Inside Cells
                                    for (int i = 0; i < _gridSize * _gridSize; i++) ...[
                                      if (_clues[i] >= 0)
                                        Positioned(
                                          left: (i % _gridSize) * cellSpacing,
                                          top: (i ~/ _gridSize) * cellSpacing,
                                          width: cellSpacing,
                                          height: cellSpacing,
                                          child: Center(
                                            child: Text(
                                              '${_clues[i]}',
                                              style: GoogleFonts.spaceGrotesk(
                                                fontSize: _gridSize == 3 ? 20 : 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.dustyMauve,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],

                                    // 2. Horizontal Interactive Edges
                                    for (int r = 0; r <= _gridSize; r++)
                                      for (int c = 0; c < _gridSize; c++)
                                        Positioned(
                                          left: c * cellSpacing + 6,
                                          top: r * cellSpacing - 12,
                                          width: cellSpacing - 12,
                                          height: 24,
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => _toggleEdge(r * _gridSize + c),
                                            child: _buildEdgeVisual(r * _gridSize + c, isHorizontal: true),
                                          ),
                                        ),

                                    // 3. Vertical Interactive Edges
                                    for (int r = 0; r < _gridSize; r++)
                                      for (int c = 0; c <= _gridSize; c++)
                                        Positioned(
                                          left: c * cellSpacing - 12,
                                          top: r * cellSpacing + 6,
                                          width: 24,
                                          height: cellSpacing - 12,
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => _toggleEdge(numH + r * (_gridSize + 1) + c),
                                            child: _buildEdgeVisual(numH + r * (_gridSize + 1) + c, isHorizontal: false),
                                          ),
                                        ),

                                    // 4. Dot Grid Vertices
                                    for (int r = 0; r <= _gridSize; r++)
                                      for (int c = 0; c <= _gridSize; c++)
                                        Positioned(
                                          left: c * cellSpacing - 4,
                                          top: r * cellSpacing - 4,
                                          width: 8,
                                          height: 8,
                                          child: Container(
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.textMuted.withAlpha(20)),
                          ),
                          child: Text(
                            '💡 Click cycle:\n'
                            '• One Tap: Places a line boundary.\n'
                            '• Two Taps: Places an X (indicating no loop line here).\n'
                            '• Three Taps: Resets back to empty.',
                            style: GoogleFonts.outfit(fontSize: 12, color: context.textSecondary),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.bgCard,
                        foregroundColor: context.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          _edges = List.filled(_edges.length, 0);
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.dustyMauve,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _checkSolution,
                      icon: const Icon(Icons.check),
                      label: const Text('Check'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isSuccess)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: _playDailyMode
                      ? ChallengeClearedOverlay(
                          accentColor: AppTheme.dustyMauve,
                          onComplete: () {
                            Navigator.pop(context, true);
                          },
                        )
                      : Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: context.bgCard,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
                              const SizedBox(height: 16),
                              Text(
                                'Level ${_currentLevel + 1} Cleared!',
                                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
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
            ),
        ],
      ),
    );
  }

  Widget _buildEdgeVisual(int idx, {required bool isHorizontal}) {
    final edgeState = _edges[idx];
    Color lineColor = Colors.transparent;
    if (edgeState == 1) {
      lineColor = Colors.amber;
    } else if (edgeState == 0) {
      lineColor = Colors.grey.shade800.withAlpha(80);
    }

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: isHorizontal ? double.infinity : 4,
            height: isHorizontal ? 4 : double.infinity,
            color: lineColor,
          ),
          if (edgeState == 2)
            Text(
              '✕',
              style: TextStyle(
                color: Colors.red.shade400,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}
