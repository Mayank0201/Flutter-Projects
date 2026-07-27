import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../utils/point_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../utils/prefs_keys.dart';
import '../../../utils/audio_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../widgets/fog_overlay.dart';
import '../../../widgets/buy_hints_dialog.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/rotation_engine.dart';
import '../../../widgets/game_tutorial_dialog.dart';
import 'masyu_levels.dart';

class MasyuLevel {
  final int gridSize;
  final List<int> pearls; // 0: empty, 1: white, 2: black
  const MasyuLevel({required this.gridSize, required this.pearls});
}

class MasyuScreen extends StatefulWidget {
  const MasyuScreen({super.key});

  @override
  State<MasyuScreen> createState() => _MasyuScreenState();
}

class _MasyuScreenState extends State<MasyuScreen> {
  int _currentLevel = 0;
  bool _isLoading = true;
  bool _isSuccess = false;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  double _dailyRadius = 1.5;

  late int _gridSize;
  late List<int> _grid; // 0: empty, 1: white, 2: black
  Map<String, bool> _activeEdges = {}; // Key: "u-v" (u < v), Value: true/false
  Map<String, bool> _solutionEdges = {}; // Cached correct solution edges for hints
  bool _solveAttempted = false;
  int _hintCount = 1;
  bool _isHintShowing = false;
  int _hintIdx = -1;
  Timer? _gameTimer;
  int _timeLeft = -1;
  bool _timeBonusEarned = false;

  // Drag loop variables
  int _dragStartCell = -1;
  List<int> _dragPath = [];
  final ValueNotifier<Offset?> _dragPositionNotifier = ValueNotifier<Offset?>(null);

  static const List<MasyuLevel> _kLevels = kMasyuLevels;

  @override
  void initState() {
    super.initState();
    _loadProgressAndLevel();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _dragPositionNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadProgressAndLevel() async {
    final prefs = await SharedPreferences.getInstance();
    _hintCount = await HintManager.getHints('masyu');
    _playDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString(PrefsKeys.dailyModifierType) ?? '';
      final extraParamsStr = prefs.getString(PrefsKeys.dailyModifierExtraParams) ?? '';
      if (extraParamsStr.isNotEmpty) {
        try {
          final extraParams = jsonDecode(extraParamsStr) as Map<String, dynamic>;
          if (extraParams.containsKey('radius')) {
            _dailyRadius = (extraParams['radius'] as num).toDouble();
          }
        } catch (_) {}
      }
    } else {
      _dailyModifierType = '';
    }

    int level = prefs.getInt(PrefsKeys.gameLevel('masyu')) ?? 0;
    if (mounted) {
      setState(() {
        _currentLevel = level;
        _isLoading = false;
        _setupLevel();
      });
    }
  }

  void _showJumpToLevelDialog() {
    final controller = TextEditingController(text: '${_currentLevel + 1}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text('Jump to Level', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter level number (1 - 205):', style: GoogleFonts.outfit(color: context.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: GoogleFonts.outfit(color: context.textPrimary),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'e.g. 50',
                hintStyle: GoogleFonts.outfit(color: context.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: context.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dustyMauve),
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val >= 1) {
                Navigator.pop(context);
                setState(() {
                  _currentLevel = val - 1;
                  _setupLevel();
                });
              }
            },
            child: Text('Go', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _setupLevel() {
    if (!_playDailyMode && _currentLevel >= 500) {
      return;
    }
    _gameTimer?.cancel();
    _timeLeft = -1;
    _timeBonusEarned = false;

    _activeEdges.clear();
    _isSuccess = false;
    _dragStartCell = -1;
    _dragPath.clear();
    _dragPositionNotifier.value = null;
    _isHintShowing = false;
    _hintIdx = -1;
    _solutionEdges = {};
    _solveAttempted = false;

    final level = _kLevels[_currentLevel % _kLevels.length];
    _gridSize = level.gridSize;
    _grid = List.from(level.pearls);
  }

  void _generateEndgameLevel(int levelIndex) {
    final rand = RotationEngine.getDeterminism('masyu', levelIndex);
    if (levelIndex >= 90) {
      _gridSize = 5 + ((levelIndex - 90) % 5);
    } else if (levelIndex >= 75) {
      _gridSize = 8;
    } else if (levelIndex >= 60) {
      _gridSize = 7;
    } else if (levelIndex >= 45) {
      _gridSize = 6;
    } else {
      _gridSize = 5;
    }
    final total = _gridSize * _gridSize;
    _grid = List.filled(total, 0);

    bool isStraight(int a, int b, int c) {
      int rA = a ~/ _gridSize, cA = a % _gridSize;
      int rB = b ~/ _gridSize, cB = b % _gridSize;
      int rC = c ~/ _gridSize, cC = c % _gridSize;
      return (rA == rB && rB == rC) || (cA == cB && cB == cC);
    }

    for (int attempt = 0; attempt < 500; attempt++) {
      final loop = _generateRandomLoop(_gridSize, rand);
      if (loop == null) continue;

      final candidates = <int>[];
      final pearlTypes = <int, int>{};
      final K = loop.length;

      for (int i = 0; i < K; i++) {
        int prev = loop[(i - 1 + K) % K];
        int curr = loop[i];
        int next = loop[(i + 1) % K];
        if (isStraight(prev, curr, next)) {
          pearlTypes[curr] = 1;
        } else {
          pearlTypes[curr] = 2;
        }
        candidates.add(curr);
      }

      candidates.shuffle(rand);

      double decayVal = RotationEngine.getDecayValue(
        level: levelIndex - 30,
        start: 0.45,
        floor: 0.22,
        rate: 60.0,
      );
      int targetCount = (total * decayVal).round();
      if (targetCount < _gridSize + 1) targetCount = _gridSize + 1;
      if (targetCount > candidates.length) targetCount = candidates.length;

      double blackRatio = 0.35 + (0.25 * ((levelIndex - 30) / (levelIndex - 30 + 100)));
      if (blackRatio > 0.65) blackRatio = 0.65;

      final selectedGrid = List.filled(total, 0);
      int placed = 0;
      int maxBlacks = (targetCount * blackRatio).round();
      int placedBlacks = 0;

      for (final cell in candidates) {
        if (placed >= targetCount) break;
        int type = pearlTypes[cell]!;
        if (type == 2 && placedBlacks >= maxBlacks) continue;
        selectedGrid[cell] = type;
        if (type == 2) placedBlacks++;
        placed++;
      }

      for (final cell in candidates) {
        if (placed >= targetCount) break;
        if (selectedGrid[cell] == 0) {
          int type = pearlTypes[cell]!;
          selectedGrid[cell] = type;
          placed++;
        }
      }

      if (_countMasyuSolutions(selectedGrid, _gridSize, 2) == 1) {
        _grid = selectedGrid;
        return;
      }
    }

    _gridSize = 5;
    _grid = [0, 1, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 2, 0, 0, 0, 0, 0, 0];
  }

  List<int>? _generateRandomLoop(int gridSize, Random rand) {
    final totalCells = gridSize * gridSize;
    final visited = List.filled(totalCells, false);
    final startCell = rand.nextInt(totalCells);
    visited[startCell] = true;

    List<int> getNeighbors(int idx) {
      final r = idx ~/ gridSize;
      final c = idx % gridSize;
      final res = <int>[];
      if (r > 0) res.add(idx - gridSize);
      if (r < gridSize - 1) res.add(idx + gridSize);
      if (c > 0) res.add(idx - 1);
      if (c < gridSize - 1) res.add(idx + 1);
      return res;
    }

    List<int>? cycle;

    bool dfs(int curr, List<int> path) {
      if (path.length >= 6) {
        final startNeighbors = getNeighbors(startCell);
        if (startNeighbors.contains(curr)) {
          if (rand.nextDouble() < 0.15) {
            cycle = List.from(path);
            return true;
          }
        }
      }

      final neighbors = getNeighbors(curr)..shuffle(rand);
      for (final next in neighbors) {
        if (next == startCell) continue;
        if (!visited[next]) {
          visited[next] = true;
          path.add(next);
          if (dfs(next, path)) return true;
          path.removeLast();
          visited[next] = false;
        }
      }
      return false;
    }

    for (int attempt = 0; attempt < 200; attempt++) {
      visited.fillRange(0, totalCells, false);
      visited[startCell] = true;
      cycle = null;
      if (dfs(startCell, [startCell])) {
        return cycle;
      }
    }
    return null;
  }

  int _countMasyuSolutions(List<int> grid, int gridSize, int maxSolutions) {
    int startCell = -1;
    for (int i = 0; i < grid.length; i++) {
      if (grid[i] > 0) {
        startCell = i;
        break;
      }
    }
    if (startCell == -1) return 0;

    final totalCells = gridSize * gridSize;

    List<int> getNeighbors(int idx) {
      final r = idx ~/ gridSize;
      final c = idx % gridSize;
      final res = <int>[];
      if (r > 0) res.add(idx - gridSize);
      if (r < gridSize - 1) res.add(idx + gridSize);
      if (c > 0) res.add(idx - 1);
      if (c < gridSize - 1) res.add(idx + 1);
      return res;
    }

    bool isStraight(int a, int b, int c) {
      int rA = a ~/ gridSize, cA = a % gridSize;
      int rB = b ~/ gridSize, cB = b % gridSize;
      int rC = c ~/ gridSize, cC = c % gridSize;
      return (rA == rB && rB == rC) || (cA == cB && cB == cC);
    }

    bool isTurn(int a, int b, int c) {
      return !isStraight(a, b, c);
    }

    bool validateLoop(List<int> loop) {
      final K = loop.length;
      final loopSet = Set<int>.from(loop);
      for (int i = 0; i < grid.length; i++) {
        if (grid[i] > 0 && !loopSet.contains(i)) return false;
      }

      for (int j = 0; j < K; j++) {
        int idx = loop[j];
        int pearl = grid[idx];
        if (pearl == 0) continue;

        int prev = loop[(j - 1 + K) % K];
        int next = loop[(j + 1) % K];
        int prevPrev = loop[(j - 2 + K) % K];
        int nextNext = loop[(j + 2) % K];

        if (pearl == 1) {
          if (!isStraight(prev, idx, next)) return false;
          bool prevTurns = isTurn(prevPrev, prev, idx);
          bool nextTurns = isTurn(idx, next, nextNext);
          if (!prevTurns && !nextTurns) return false;
        } else if (pearl == 2) {
          if (!isTurn(prev, idx, next)) return false;
          bool prevStraight = isStraight(prevPrev, prev, idx);
          bool nextStraight = isStraight(idx, next, nextNext);
          if (!prevStraight || !nextStraight) return false;
        }
      }
      return true;
    }

    int solutionsCount = 0;
    final visited = List.filled(totalCells, false);
    int steps = 0;

    bool dfs(int curr, List<int> path) {
      steps++;
      if (steps > 10000) return false;
      if (path.length >= 4) {
        final startNeighbors = getNeighbors(startCell);
        if (startNeighbors.contains(curr)) {
          if (validateLoop(path)) {
            solutionsCount++;
            if (solutionsCount >= maxSolutions) return true;
          }
        }
      }

      final neighbors = getNeighbors(curr);
      for (final next in neighbors) {
        if (next == startCell) continue;
        if (!visited[next]) {
          if (path.length >= 2) {
            int prevIdx = path[path.length - 2];
            int pearlIdx = path[path.length - 1];
            int pearlType = grid[pearlIdx];
            if (pearlType == 1) {
              if (!isStraight(prevIdx, pearlIdx, next)) continue;
            } else if (pearlType == 2) {
              if (!isTurn(prevIdx, pearlIdx, next)) continue;
            }
          }

          if (path.length >= 3) {
            int prevIdx = path[path.length - 2];
            int pearlIdx = path[path.length - 1];
            if (grid[prevIdx] == 2) {
              if (!isStraight(prevIdx, pearlIdx, next)) continue;
            }
          }

          visited[next] = true;
          path.add(next);
          if (dfs(next, path)) return true;
          path.removeLast();
          visited[next] = false;
        }
      }
      return false;
    }

    visited[startCell] = true;
    dfs(startCell, [startCell]);

    return solutionsCount;
  }

  void _ensureSolution() {
    if (_solveAttempted) return;
    _solveAttempted = true;
    _solutionEdges = _solveMasyu() ?? {};
  }

  Map<String, bool>? _solveMasyu() {
    int startCell = -1;
    for (int i = 0; i < _grid.length; i++) {
      if (_grid[i] > 0) {
        startCell = i;
        break;
      }
    }
    if (startCell == -1) return null;

    final totalCells = _gridSize * _gridSize;

    List<int> getNeighbors(int idx) {
      final r = idx ~/ _gridSize;
      final c = idx % _gridSize;
      final res = <int>[];
      if (r > 0) res.add(idx - _gridSize);
      if (r < _gridSize - 1) res.add(idx + _gridSize);
      if (c > 0) res.add(idx - 1);
      if (c < _gridSize - 1) res.add(idx + 1);
      return res;
    }

    bool isStraight(int a, int b, int c) {
      int rA = a ~/ _gridSize, cA = a % _gridSize;
      int rB = b ~/ _gridSize, cB = b % _gridSize;
      int rC = c ~/ _gridSize, cC = c % _gridSize;
      return (rA == rB && rB == rC) || (cA == cB && cB == cC);
    }

    bool isTurn(int a, int b, int c) {
      return !isStraight(a, b, c);
    }

    bool validateLoop(List<int> loop) {
      final K = loop.length;
      final loopSet = Set<int>.from(loop);
      for (int i = 0; i < _grid.length; i++) {
        if (_grid[i] > 0 && !loopSet.contains(i)) return false;
      }

      final cellToIdx = {for (int j = 0; j < K; j++) loop[j]: j};

      for (int j = 0; j < K; j++) {
        int idx = loop[j];
        int pearl = _grid[idx];
        if (pearl == 0) continue;

        int prev = loop[(j - 1 + K) % K];
        int next = loop[(j + 1) % K];
        int prevPrev = loop[(j - 2 + K) % K];
        int nextNext = loop[(j + 2) % K];

        if (pearl == 1) {
          if (!isStraight(prev, idx, next)) return false;
          bool prevTurns = isTurn(prevPrev, prev, idx);
          bool nextTurns = isTurn(idx, next, nextNext);
          if (!prevTurns && !nextTurns) return false;
        } else if (pearl == 2) {
          if (!isTurn(prev, idx, next)) return false;
          bool prevStraight = isStraight(prevPrev, prev, idx);
          bool nextStraight = isStraight(idx, next, nextNext);
          if (!prevStraight || !nextStraight) return false;
        }
      }
      return true;
    }

    List<int>? solutionLoop;
    final visited = List.filled(totalCells, false);
    int steps = 0;

    bool dfs(int curr, List<int> path) {
      steps++;
      if (steps > 10000) return false;
      if (path.length >= 4) {
        final startNeighbors = getNeighbors(startCell);
        if (startNeighbors.contains(curr)) {
          if (validateLoop(path)) {
            solutionLoop = List.from(path);
            return true;
          }
        }
      }

      final neighbors = getNeighbors(curr);
      for (final next in neighbors) {
        if (next == startCell) continue;
        if (!visited[next]) {
          if (path.length >= 2) {
            int prevIdx = path[path.length - 2];
            int pearlIdx = path[path.length - 1];
            int pearlType = _grid[pearlIdx];
            if (pearlType == 1) {
              if (!isStraight(prevIdx, pearlIdx, next)) continue;
            } else if (pearlType == 2) {
              if (!isTurn(prevIdx, pearlIdx, next)) continue;
            }
          }

          if (path.length >= 3) {
            int prevIdx = path[path.length - 2];
            int pearlIdx = path[path.length - 1];
            if (_grid[prevIdx] == 2) {
              if (!isStraight(prevIdx, pearlIdx, next)) continue;
            }
          }

          visited[next] = true;
          path.add(next);
          if (dfs(next, path)) return true;
          path.removeLast();
          visited[next] = false;
        }
      }
      return false;
    }

    visited[startCell] = true;
    dfs(startCell, [startCell]);

    if (solutionLoop == null) return null;

    final Map<String, bool> solEdges = {};
    final K = solutionLoop!.length;
    for (int i = 0; i < K; i++) {
      int u = solutionLoop![i];
      int v = solutionLoop![(i + 1) % K];
      String key = u < v ? '$u-$v' : '$v-$u';
      solEdges[key] = true;
    }
    return solEdges;
  }

  List<List<int>> _getEdges() {
    List<List<int>> list = [];
    // Horizontal edges
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize - 1; c++) {
        list.add([r * _gridSize + c, r * _gridSize + c + 1]);
      }
    }
    // Vertical edges
    for (int r = 0; r < _gridSize - 1; r++) {
      for (int c = 0; c < _gridSize; c++) {
        list.add([r * _gridSize + c, (r + 1) * _gridSize + c]);
      }
    }
    return list;
  }

  bool _hasEdge(int a, int b) {
    String key = a < b ? '$a-$b' : '$b-$a';
    return _activeEdges[key] ?? false;
  }

  int _getClosestCell(Offset localPos, double cellSpacing, double origin, double boardSize) {
    for (int idx = 0; idx < _gridSize * _gridSize; idx++) {
      final center = _nodeCenter(idx, cellSpacing, origin);
      double dist = (localPos - center).distance;
      if (dist < cellSpacing * 0.4) {
        return idx;
      }
    }
    return -1;
  }

  Offset _nodeCenter(int idx, double cellSpacing, double origin) {
    final r = idx ~/ _gridSize;
    final c = idx % _gridSize;
    return Offset(origin + c * cellSpacing, origin + r * cellSpacing);
  }

  void _onPanStart(DragStartDetails d, double cellSpacing, double origin, double boardSize) {
    if (_isSuccess) return;
    int idx = _getClosestCell(d.localPosition, cellSpacing, origin, boardSize);
    if (idx != -1) {
      settingsNotifier.hapticTap();
      _dragStartCell = idx;
      _dragPath = [idx];
      _dragPositionNotifier.value = _nodeCenter(idx, cellSpacing, origin);
    }
  }

  void _onPanUpdate(DragUpdateDetails d, double cellSpacing, double origin, double boardSize) {
    if (_isSuccess || _dragStartCell == -1) return;
    _dragPositionNotifier.value = d.localPosition;

    int idx = _getClosestCell(d.localPosition, cellSpacing, origin, boardSize);
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
      int r1 = last ~/ _gridSize; int c1 = last % _gridSize;
      int r2 = idx ~/ _gridSize; int c2 = idx % _gridSize;
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
    setState(() {
      _dragPath.clear();
    });
    _tryAutoCheck();
  }

  Map<int, List<int>> _buildAdjacency() {
    final adj = <int, List<int>>{};
    _activeEdges.forEach((key, active) {
      if (active) {
        final parts = key.split('-');
        int u = int.parse(parts[0]);
        int v = int.parse(parts[1]);
        adj.putIfAbsent(u, () => []).add(v);
        adj.putIfAbsent(v, () => []).add(u);
      }
    });
    return adj;
  }

  bool _isStraight(int a, int b, int c) {
    int rA = a ~/ _gridSize, cA = a % _gridSize;
    int rB = b ~/ _gridSize, cB = b % _gridSize;
    int rC = c ~/ _gridSize, cC = c % _gridSize;
    return (rA == rB && rB == rC) || (cA == cB && cB == cC);
  }

  bool _isTurn(int a, int b, int c) {
    return !_isStraight(a, b, c);
  }

  (bool isValid, String? errorMsg, int? errIdx) _validateMasyuGraph() {
    final adj = _buildAdjacency();
    final totalCells = _gridSize * _gridSize;

    if (adj.isEmpty) {
      return (false, 'Draw a loop connecting the pearls!', null);
    }

    // 1. Degree check: Every cell in loop graph must have degree 2
    int loopCellsCount = 0;
    int startCell = -1;
    for (final entry in adj.entries) {
      int u = entry.key;
      int deg = entry.value.length;
      if (deg == 2) {
        loopCellsCount++;
        if (startCell == -1) startCell = u;
      } else if (deg != 0) {
        int r = u ~/ _gridSize + 1, c = u % _gridSize + 1;
        return (false, 'Cell ($r,$c) has $deg connections — must have 0 or 2', u);
      }
    }

    if (loopCellsCount < 4 || startCell == -1) {
      return (false, 'Loop must connect at least 4 cells', null);
    }

    // 2. Single-loop connectivity check via BFS
    List<bool> visited = List.filled(totalCells, false);
    List<int> queue = [startCell];
    visited[startCell] = true;
    int visitedCount = 1;

    while (queue.isNotEmpty) {
      int curr = queue.removeAt(0);
      for (int neighbor in adj[curr] ?? []) {
        if (!visited[neighbor]) {
          visited[neighbor] = true;
          queue.add(neighbor);
          visitedCount++;
        }
      }
    }

    if (visitedCount != loopCellsCount) {
      return (false, 'Multiple loops found — only a single loop is allowed', null);
    }

    // Reconstruct the ordered loop sequence
    final List<int> loop = [startCell];
    int prevNode = -1;
    int currNode = startCell;
    while (true) {
      final neighbors = adj[currNode]!;
      int nextNode = (prevNode == -1)
          ? neighbors[0]
          : ((neighbors[0] == prevNode) ? neighbors[1] : neighbors[0]);
      if (nextNode == startCell) {
        break;
      }
      loop.add(nextNode);
      prevNode = currNode;
      currNode = nextNode;
    }

    final int K = loop.length;
    final Map<int, int> cellToLoopIndex = {};
    for (int j = 0; j < K; j++) {
      cellToLoopIndex[loop[j]] = j;
    }

    // 3. Pearl rule validation along the reconstructed loop
    final bool isPrism = _playDailyMode && _dailyModifierType == 'prism';
    for (int i = 0; i < totalCells; i++) {
      int pearl = _grid[i];
      if (pearl == 0) continue;
      if (isPrism) {
        pearl = (pearl == 1) ? 2 : 1;
      }

      int r = i ~/ _gridSize + 1, c = i % _gridSize + 1;
      if (!cellToLoopIndex.containsKey(i)) {
        return (false, 'Pearl at ($r,$c) must be part of the loop', i);
      }

      int j = cellToLoopIndex[i]!;
      int prev = loop[(j - 1 + K) % K];
      int next = loop[(j + 1) % K];
      int prevPrev = loop[(j - 2 + K) % K];
      int nextNext = loop[(j + 2) % K];

      if (pearl == 1) {
        // White Pearl: Must go STRAIGHT through it
        if (!_isStraight(prev, i, next)) {
          return (false, 'White pearl at ($r,$c) must go straight through', i);
        }

        // At least one adjacent cell must make a 90-degree turn
        bool prevTurns = _isTurn(prevPrev, prev, i);
        bool nextTurns = _isTurn(i, next, nextNext);

        if (!prevTurns && !nextTurns) {
          return (false, 'White pearl at ($r,$c): at least 1 neighbor must turn', i);
        }
      } else if (pearl == 2) {
        // Black Pearl: Must TURN 90 degrees at the pearl
        if (!_isTurn(prev, i, next)) {
          return (false, 'Black pearl at ($r,$c) must turn 90°', i);
        }

        // Both outgoing paths must continue straight for 1 unit
        bool prevStraight = _isStraight(prevPrev, prev, i);
        bool nextStraight = _isStraight(i, next, nextNext);

        if (!prevStraight || !nextStraight) {
          return (false, 'Black pearl at ($r,$c): path must continue straight after turn', i);
        }
      }
    }

    return (true, null, null);
  }

  void _checkSolution() {
    final (isValid, errorMsg, errIdx) = _validateMasyuGraph();
    if (isValid) {
      AudioManager.playSuccess();
      settingsNotifier.hapticSuccess();
      _onLevelCleared();
    } else {
      AudioManager.playFail();
      settingsNotifier.hapticError();
      if (errIdx != null) {
        setState(() => _hintIdx = errIdx);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMsg ?? 'Invalid loop. Check pearl rules!',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _tryAutoCheck() {
    if (_isSuccess) return;
    int activeEdgeCount = _activeEdges.values.where((v) => v).length;
    int pearlCount = _grid.where((p) => p > 0).length;
    if (activeEdgeCount >= max(4, pearlCount)) {
      final (isValid, _, _) = _validateMasyuGraph();
      if (isValid) {
        _checkSolution();
      }
    }
  }

  Future<void> _onLevelCleared() async {
    _gameTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    if (!_playDailyMode) {
      int highest = prefs.getInt('beta_level_masyu') ?? 0;
      if (_currentLevel + 1 > highest) {
        await prefs.setInt('beta_level_masyu', _currentLevel + 1);
      }
    }
    
    if (_timeBonusEarned && _timeLeft > 0) {
      await PointManager.addPoints(5);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Speed Bonus! Earned +5 Points!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
            backgroundColor: Colors.amber,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    setState(() => _isSuccess = true);
  }

  void _nextLevel() {
    setState(() {
      _currentLevel++;
      _setupLevel();
    });
    final prefs = SharedPreferences.getInstance().then((p) {
      p.setInt(PrefsKeys.gameLevel('masyu'), _currentLevel);
    });
  }

  void _showHint() {
    _ensureSolution();
    if (_solutionEdges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot find solution. Try clearing some lines!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // 1. Spot incorrect edges and erase them
    String? incorrectKey;
    _activeEdges.forEach((key, isActive) {
      if (isActive) {
        if (!_solutionEdges.containsKey(key) || !_solutionEdges[key]!) {
          incorrectKey = key;
        }
      }
    });

    if (incorrectKey != null) {
      final parts = incorrectKey!.split('-');
      int u = int.parse(parts[0]);
      setState(() {
        _activeEdges[incorrectKey!] = false;
        _hintIdx = u;
        _isHintShowing = true;
      });
      settingsNotifier.hapticTap();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erased an incorrect line!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.amber.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isHintShowing = false);
      });
      return;
    }

    // 2. Give the next step by placing a correct edge
    String? missingKey;
    _solutionEdges.forEach((key, isSolActive) {
      if (isSolActive) {
        if (!_activeEdges.containsKey(key) || !_activeEdges[key]!) {
          missingKey = key;
        }
      }
    });

    if (missingKey != null) {
      final parts = missingKey!.split('-');
      int u = int.parse(parts[0]);
      setState(() {
        _activeEdges[missingKey!] = true;
        _hintIdx = u;
        _isHintShowing = true;
      });
      settingsNotifier.hapticTap();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Revealed the next step!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.dustyMauve,
          duration: const Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isHintShowing = false);
      });
      _tryAutoCheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.bgDark,
        body: const Center(child: CircularProgressIndicator(color: AppTheme.dustyMauve)),
      );
    }

    final double screenW = MediaQuery.of(context).size.width;
    final double boardSize = min(screenW - 32, 400.0);
    final double cellSpacing = boardSize / _gridSize;
    final double origin = cellSpacing / 2;

    final bool allLevelsCompleted = !_playDailyMode && _currentLevel >= _kLevels.length;

    if (allLevelsCompleted) {
      return Scaffold(
        backgroundColor: context.bgDark,
        appBar: AppBar(
          title: Text('Pearl Loop', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        body: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: context.bgCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.textMuted.withAlpha(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events,
                  color: Colors.amber,
                  size: 80,
                ),
                const SizedBox(height: 24),
                Text(
                  'All Levels Completed!',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Congratulations! You have solved all ${_kLevels.length} levels of Pearl Loop. More levels will be added in future updates!',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: context.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.dustyMauve,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.home),
                  label: const Text('Back to Home'),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: context.textMuted,
                  ),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt(PrefsKeys.gameLevel('masyu'), 0);
                    setState(() {
                      _currentLevel = 0;
                      _setupLevel();
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reset Progress & Replay'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Pearl Loop', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.lightbulb_outline, size: 20, color: context.textMuted),
                Positioned(
                  right: -4,
                  top: -4,
                  child: CircleAvatar(
                    radius: 6,
                    backgroundColor: Colors.amber,
                    child: Text(
                      _hintCount == 0 ? '+' : '$_hintCount',
                      style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            onPressed: !_isSuccess && !_isHintShowing
                ? () async {
                    if (_hintCount > 0) {
                      _showHint();
                      setState(() => _hintCount--);
                      HintManager.useHint('masyu');
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'masyu',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('masyu');
                          if (mounted) setState(() => _hintCount = newCount);
                        },
                      );
                    }
                  }
                : null,
          ),
          if (_timeLeft >= 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Row(
                  children: [
                    Icon(
                      Icons.timer,
                      color: _timeLeft <= 15 ? Colors.red : Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_timeLeft s',
                      style: GoogleFonts.spaceGrotesk(
                        color: _timeLeft <= 15 ? Colors.red : Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => GameTutorialDialog.show(context, 'masyu', 'Pearl Loop'),
          ),
          GestureDetector(
            onTap: _showJumpToLevelDialog,
            child: Padding(
              padding: const EdgeInsets.only(right: 16, left: 8),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _playDailyMode ? 'Challenge' : 'Level ${_currentLevel + 1}',
                      style: GoogleFonts.outfit(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (!_playDailyMode) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, size: 12, color: AppTheme.dustyMauve),
                    ],
                  ],
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.dustyMauve.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Connect dots. Straight through White. Turn inside Black.',
                            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.dustyMauve, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        RepaintBoundary(
                          child: Container(
                            width: boardSize,
                            height: boardSize,
                            decoration: BoxDecoration(
                              color: context.bgCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.textMuted.withAlpha(30)),
                            ),
                            child: FogOverlay(
                              enabled: _playDailyMode && _dailyModifierType == 'fog',
                              radius: cellSpacing * _dailyRadius,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: GestureDetector(
                                  onPanStart: (d) => _onPanStart(d, cellSpacing, origin, boardSize),
                                  onPanUpdate: (d) => _onPanUpdate(d, cellSpacing, origin, boardSize),
                                  onPanEnd: _onPanEnd,
                                  child: CustomPaint(
                                    size: Size(boardSize, boardSize),
                                    painter: _MasyuPainter(
                                      gridSize: _gridSize,
                                      grid: _grid,
                                      activeEdges: _activeEdges,
                                      cellSpacing: cellSpacing,
                                      origin: origin,
                                      dragPath: _dragPath,
                                      dragPosition: _dragPositionNotifier,
                                      hintIdx: _hintIdx,
                                      isPrism: _playDailyMode && _dailyModifierType == 'prism',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: _isSuccess
                      ? AutoNextCountdown(
                          onNext: _nextLevel,
                          accentColor: AppTheme.dustyMauve,
                        )
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.bgCard,
                            foregroundColor: context.textPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            setState(() {
                              _activeEdges.clear();
                              _dragPath.clear();
                              _isSuccess = false;
                              _hintIdx = -1;
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset'),
                        ),
                ),
              ],
            ),
          ),
          if (_isSuccess && _playDailyMode)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: ChallengeClearedOverlay(
                    accentColor: AppTheme.dustyMauve,
                    onComplete: () {
                      Navigator.pop(context, true);
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MasyuPainter extends CustomPainter {
  final int gridSize;
  final List<int> grid;
  final Map<String, bool> activeEdges;
  final double cellSpacing;
  final double origin;
  final List<int> dragPath;
  final ValueNotifier<Offset?> dragPosition;
  final int hintIdx;
  final bool isPrism;

  _MasyuPainter({
    required this.gridSize,
    required this.grid,
    required this.activeEdges,
    required this.cellSpacing,
    required this.origin,
    required this.dragPath,
    required this.dragPosition,
    required this.hintIdx,
    required this.isPrism,
  }) : super(repaint: dragPosition);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 1.0;
    
    for (int i = 0; i < gridSize; i++) {
      double pos = origin + i * cellSpacing;
      canvas.drawLine(Offset(origin, pos), Offset(size.width - origin, pos), linePaint);
      canvas.drawLine(Offset(pos, origin), Offset(pos, size.height - origin), linePaint);
    }

    final Paint dotPaint = Paint()
      ..color = AppTheme.dustyMauve.withAlpha(200)
      ..style = PaintingStyle.fill;
    
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        canvas.drawCircle(Offset(origin + c * cellSpacing, origin + r * cellSpacing), 4.5, dotPaint);
      }
    }

    final Paint edgePaint = Paint()
      ..color = AppTheme.dustyMauve
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        int u = r * gridSize + c;
        Offset centerU = _nodeCenter(u);
        if (c < gridSize - 1) {
          int v = u + 1;
          if (activeEdges['$u-$v'] ?? false) {
            canvas.drawLine(centerU, _nodeCenter(v), edgePaint);
          }
        }
        if (r < gridSize - 1) {
          int v = u + gridSize;
          if (activeEdges['$u-$v'] ?? false) {
            canvas.drawLine(centerU, _nodeCenter(v), edgePaint);
          }
        }
      }
    }

    if (dragPath.isNotEmpty) {
      final Paint dragPaint = Paint()
        ..color = AppTheme.dustyMauve.withOpacity(0.4)
        ..strokeWidth = 8.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final Path p = Path();
      p.moveTo(_nodeCenter(dragPath.first).dx, _nodeCenter(dragPath.first).dy);
      for (int i = 1; i < dragPath.length; i++) {
        final center = _nodeCenter(dragPath[i]);
        p.lineTo(center.dx, center.dy);
      }
      final curPos = dragPosition.value;
      if (curPos != null) {
        p.lineTo(curPos.dx, curPos.dy);
      }
      canvas.drawPath(p, dragPaint);
    }

    final Paint whitePearlPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final Paint whiteBorderPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    final Paint blackPearlPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    final Paint blackBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < gridSize * gridSize; i++) {
      int pearl = grid[i];
      if (pearl > 0) {
        Offset center = _nodeCenter(i);
        double rad = cellSpacing * 0.22;
        
        if (hintIdx == i) {
          final Paint glowPaint = Paint()
            ..color = Colors.amber.withOpacity(0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
          canvas.drawCircle(center, rad * 1.8, glowPaint);
        }

        int drawPearl = pearl;
        if (isPrism) {
          drawPearl = (pearl == 1) ? 2 : 1;
        }

        if (drawPearl == 1) {
          canvas.drawCircle(center, rad, whitePearlPaint);
          canvas.drawCircle(center, rad, whiteBorderPaint);
        } else if (drawPearl == 2) {
          canvas.drawCircle(center, rad, blackPearlPaint);
          canvas.drawCircle(center, rad, blackBorderPaint);
        }
      }
    }
  }

  Offset _nodeCenter(int idx) {
    final r = idx ~/ gridSize;
    final c = idx % gridSize;
    return Offset(origin + c * cellSpacing, origin + r * cellSpacing);
  }

  @override
  bool shouldRepaint(covariant _MasyuPainter old) => true;
}
