import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cogniq/widgets/buy_hints_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/rules_helper.dart';
import '../../../utils/prefs_keys.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/audio_manager.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/animated_level_indicator.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../utils/shuffle_manager.dart';

class ZipLevel {
  final int rows, cols;
  final List<List<int>> waypoints;
  const ZipLevel({required this.rows, required this.cols, required this.waypoints});
  int get maxWaypoint { int m = 0; for (var r in waypoints) { for (var v in r) { if (v > m) { m = v; } } } return m; }
  int get wallCount { int count = 0; for (var r in waypoints) { for (var v in r) { if (v == -1) { count++; } } } return count; }
  int get totalCells => rows * cols;
  int get totalCellsToVisit => rows * cols - wallCount;
}
class GridPathScreen extends StatefulWidget {
  const GridPathScreen({super.key});
  @override
  State<GridPathScreen> createState() => _GridPathScreenState();
}

class _GridPathScreenState extends State<GridPathScreen> with SingleTickerProviderStateMixin {
  int _levelIndex = 0;
  late ZipLevel _level;
  bool _isTutorialMode = false;
  bool _tutorialCompleted = false;
  int _actualGameLevel = 0;
  final List<(int, int)> _path = [];
  int _nextWaypoint = 1;
  bool _won = false;
  String _msg = 'Drag through every cell — hit numbers in order';
  final GlobalKey _gridKey = GlobalKey();

  int _hintCount = 0;
  bool _dragActive = false;
  bool _isDailyMode = false;
  String _dailyModifierType = '';
  List<(int, int)>? _solution;
  bool _shuffleActive = false;
  bool get _isReversePath => _isDailyMode && _dailyModifierType == 'mirror';
  bool _hideGridPathElements = false;
  Timer? _blindStepsTimer;

  @override
  void dispose() {
    _blindStepsTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _level = _getDynamicLevel(0);
    _initLevel();
  }

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('zip');
    final prefs = await SharedPreferences.getInstance();
    _isDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    if (_isDailyMode) {
      _dailyModifierType = prefs.getString(PrefsKeys.dailyModifierType) ?? '';
    }
    int savedLevel = prefs.getInt(PrefsKeys.gameLevel('zip')) ?? 0;
    final active = await ShuffleManager.isActive();

    _isTutorialMode = false;
    _levelIndex = savedLevel;

    if (mounted) {
      setState(() {
        _shuffleActive = active;
        _loadLevel(prefs);
      });
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    final pathStrings = _path.map((p) => '${p.$1},${p.$2}').toList();
    await prefs.setStringList(PrefsKeys.zipPath(_levelIndex), pathStrings);
  }

  Future<void> _clearState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PrefsKeys.zipPath(_levelIndex));
  }

  Future<void> _savePersistedLevel(int lvl) async {
    if (_isDailyMode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PrefsKeys.gameLevel('zip'), lvl);
    final earned = await HintManager.onLevelCleared('zip');
    final newCount = await HintManager.getHints('zip');
    if (!mounted) return;
    setState(() {
      _hintCount = newCount;
    });
    
  }

  List<(int, int)>? _solveZip(ZipLevel level) {
    int startR = -1, startC = -1;
    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        if (level.waypoints[r][c] == 1) {
          startR = r; startC = c;
        }
      }
    }
    if (startR == -1) return null;

    List<(int, int)> path = [(startR, startC)];
    Set<String> visited = {'$startR,$startC'};
    int steps = 0;

    bool dfs(int r, int c, int nextWp) {
      steps++;
      if (steps > 10000) return false; // Prevent infinite loops or massive searches
      
      if (path.length == level.totalCellsToVisit) {
        final lastWp = level.waypoints[path.last.$1][path.last.$2];
        return lastWp == level.maxWaypoint;
      }

      final dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];
      for (final dir in dirs) {
        final nr = r + dir.$1;
        final nc = c + dir.$2;
        if (nr >= 0 && nr < level.rows && nc >= 0 && nc < level.cols) {
          final key = '$nr,$nc';
          if (!visited.contains(key)) {
            final wp = level.waypoints[nr][nc];
            if (wp == -1) continue;
            if (wp > 0 && wp != nextWp) continue;
            
            visited.add(key);
            path.add((nr, nc));
            
            if (dfs(nr, nc, wp > 0 ? nextWp + 1 : nextWp)) {
              return true;
            }
            
            path.removeLast();
            visited.remove(key);
            if (steps > 10000) return false;
          }
        }
      }
      return false;
    }

    if (dfs(startR, startC, 2)) {
      return path;
    }
    return null;
  }

  Future<void> _useHint() async {
    if (_won || _hintCount <= 0) return;
    final rawSolution = _solveZip(_level);
    if (rawSolution == null || rawSolution.isEmpty) return;
    final List<(int, int)> solution = _isReversePath ? rawSolution.reversed.toList() : rawSolution;

    bool matches = true;
    if (_path.length > solution.length) {
      matches = false;
    } else {
      for (int i = 0; i < _path.length; i++) {
        if (_path[i].$1 != solution[i].$1 || _path[i].$2 != solution[i].$2) {
          matches = false;
          break;
        }
      }
    }

    await HintManager.useHint('zip');
    final newCount = await HintManager.getHints('zip');

    if (!mounted) return;
    setState(() {
      _hintCount = newCount;
      if (!matches || _path.isEmpty) {
        _path.clear();
        _path.add(solution[0]);
        if (solution.length > 1) {
          _path.add(solution[1]);
        }
      } else {
        _path.add(solution[_path.length]);
      }

      _nextWaypoint = _isReversePath ? _level.maxWaypoint : 1;
      for (var p in _path) {
        final wp = _level.waypoints[p.$1][p.$2];
        if (wp == _nextWaypoint) {
          if (_isReversePath) {
            _nextWaypoint--;
          } else {
            _nextWaypoint++;
          }
        }
      }

      final lastCellWp = _level.waypoints[_path.last.$1][_path.last.$2];
      final targetLastWp = _isReversePath ? 1 : _level.maxWaypoint;
      if (lastCellWp == targetLastWp && _path.length == _level.totalCellsToVisit) {
        if (_isTutorialMode) {
          if (!_tutorialCompleted) {
            AudioManager.playSuccess();
            settingsNotifier.hapticError();
            setState(() {
              _tutorialCompleted = true;
            });
          }
        } else {
          _won = true;
          _msg = 'Path complete!';
          AudioManager.playSuccess();
          settingsNotifier.hapticError(); // equivalent to heavyImpact
          _savePersistedLevel(_levelIndex + 1);
          _clearState();
        }
      } else {
        _msg = 'Hint added to path!';
        AudioManager.playClick();
        settingsNotifier.hapticTap(); // equivalent to lightImpact
        _saveState();
      }
    });
  }

  ZipLevel _getDynamicLevel(int levelIndex) {
    int gridSize;
    int waypointCount;

    if (levelIndex < 5) {
      gridSize = 3;
      waypointCount = 2 + ((levelIndex + 1) ~/ 2); // 2, 3, 3, 4, 4 waypoints
    } else if (levelIndex < 15) {
      gridSize = 4;
      waypointCount = 3 + ((levelIndex - 5 + 1) ~/ 3);
    } else if (levelIndex < 30) {
      gridSize = 5;
      waypointCount = 5 + ((levelIndex - 15 + 1) ~/ 4);
    } else if (levelIndex < 50) {
      gridSize = 6;
      waypointCount = 8 + ((levelIndex - 30 + 1) ~/ 5);
    } else {
      gridSize = 6;
      waypointCount = 12 + ((levelIndex - 50) ~/ 6);
    }
    waypointCount = waypointCount.clamp(2, (gridSize * gridSize) - 2);
    final int rows = gridSize;
    final int cols = gridSize;
    final rand = Random(levelIndex);

    List<(int, int)> path = [];
    final successfulWalls = <String>{};

    // Check that all non-wall cells are still connected via BFS
    bool isConnected(Set<String> walls, int rows, int cols) {
      // Find the first non-wall cell
      (int, int)? start;
      for (int r = 0; r < rows && start == null; r++) {
        for (int c = 0; c < cols && start == null; c++) {
          if (!walls.contains('$r,$c')) start = (r, c);
        }
      }
      if (start == null) return false;
      final visited = <String>{};
      final queue = <(int, int)>[start];
      visited.add('${start.$1},${start.$2}');
      while (queue.isNotEmpty) {
        final cell = queue.removeAt(0);
        for (final d in [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
          final nr = cell.$1 + d.$1;
          final nc = cell.$2 + d.$2;
          final key = '$nr,$nc';
          if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && !walls.contains(key) && !visited.contains(key)) {
            visited.add(key);
            queue.add((nr, nc));
          }
        }
      }
      return visited.length == rows * cols - walls.length;
    }

    int countUnvisitedNeighbors(int r, int c, Set<String> visited) {
      int count = 0;
      for (final d in [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        final nr = r + d.$1;
        final nc = c + d.$2;
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && !visited.contains('$nr,$nc')) {
          count++;
        }
      }
      return count;
    }

    // Try up to 20 attempts with higher step budget to find a Hamiltonian path
    for (int attempt = 0; attempt < 20; attempt++) {
      final startR = rand.nextInt(rows);
      final startC = rand.nextInt(cols);

      // Generate walls for levels 30+, validating connectivity
      final walls = <String>{};
      if (levelIndex >= 30) {
        final numWalls = 2 + (levelIndex % 4); // 2 to 5 walls
        final candidates = <(int, int)>[];
        for (int r = 0; r < rows; r++) {
          for (int c = 0; c < cols; c++) {
            if (r != startR || c != startC) candidates.add((r, c));
          }
        }
        candidates.shuffle(rand);
        for (final cell in candidates) {
          if (walls.length >= numWalls) break;
          final key = '${cell.$1},${cell.$2}';
          walls.add(key);
          // Check connectivity — if adding this wall breaks it, remove it
          if (!isConnected(walls, rows, cols)) {
            walls.remove(key);
          }
        }
      }

      final int targetPathLength = rows * cols - walls.length;
      final currentPath = <(int, int)>[(startR, startC)];
      final visited = <String>{'$startR,$startC', ...walls};
      int totalSteps = 0;

      bool dfs(int r, int c) {
        totalSteps++;
        if (totalSteps > 5000) return false;
        if (currentPath.length == targetPathLength) return true;

        final dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)]..shuffle(rand);
        // Warnsdorff heuristic: prefer neighbors with fewer exits
        dirs.sort((a, b) {
          final nra = r + a.$1, nca = c + a.$2;
          final nrb = r + b.$1, ncb = c + b.$2;
          final countA = (nra >= 0 && nra < rows && nca >= 0 && nca < cols && !visited.contains('$nra,$nca'))
              ? countUnvisitedNeighbors(nra, nca, visited) : 999;
          final countB = (nrb >= 0 && nrb < rows && ncb >= 0 && ncb < cols && !visited.contains('$nrb,$ncb'))
              ? countUnvisitedNeighbors(nrb, ncb, visited) : 999;
          return countA.compareTo(countB);
        });

        for (final dir in dirs) {
          final nr = r + dir.$1;
          final nc = c + dir.$2;
          if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
            final key = '$nr,$nc';
            if (!visited.contains(key)) {
              visited.add(key);
              currentPath.add((nr, nc));
              if (dfs(nr, nc)) return true;
              currentPath.removeLast();
              visited.remove(key);
              if (totalSteps > 5000) return false;
            }
          }
        }
        return false;
      }

      if (dfs(startR, startC)) {
        path = currentPath;
        successfulWalls.addAll(walls);
        break;
      }
    }

    // Randomized fallback — shuffle a zigzag to avoid boring straight lines
    if (path.isEmpty) {
      // Use a simple randomized walk: start from a random corner, 
      // greedily visit unvisited neighbors in random order
      final fallbackRand = Random(levelIndex * 7 + 13);
      final visited = <String>{};
      final fallbackPath = <(int, int)>[];
      final startR = fallbackRand.nextInt(rows);
      final startC = fallbackRand.nextInt(cols);
      fallbackPath.add((startR, startC));
      visited.add('$startR,$startC');

      while (fallbackPath.length < rows * cols) {
        final cur = fallbackPath.last;
        final neighbors = <(int, int)>[];
        for (final d in [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
          final nr = cur.$1 + d.$1;
          final nc = cur.$2 + d.$2;
          if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && !visited.contains('$nr,$nc')) {
            neighbors.add((nr, nc));
          }
        }
        if (neighbors.isEmpty) {
          // Dead end — restart with basic zigzag
          fallbackPath.clear();
          visited.clear();
          for (int r = 0; r < rows; r++) {
            if (r % 2 == 0) {
              for (int c = 0; c < cols; c++) fallbackPath.add((r, c));
            } else {
              for (int c = cols - 1; c >= 0; c--) fallbackPath.add((r, c));
            }
          }
          break;
        }
        neighbors.shuffle(fallbackRand);
        // Pick neighbor with fewest unvisited neighbors (greedy Warnsdorff)
        neighbors.sort((a, b) {
          int countA = 0, countB = 0;
          for (final d in [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
            final ar = a.$1 + d.$1, ac = a.$2 + d.$2;
            if (ar >= 0 && ar < rows && ac >= 0 && ac < cols && !visited.contains('$ar,$ac')) countA++;
            final br = b.$1 + d.$1, bc = b.$2 + d.$2;
            if (br >= 0 && br < rows && bc >= 0 && bc < cols && !visited.contains('$br,$bc')) countB++;
          }
          return countA.compareTo(countB);
        });
        final next = neighbors.first;
        fallbackPath.add(next);
        visited.add('${next.$1},${next.$2}');
      }
      path = fallbackPath;
      successfulWalls.clear(); // No walls on fallback
    }

    // Set all cells initially to 0 (free tile)
    final waypoints = List.generate(rows, (_) => List.filled(cols, 0));

    // Fill walls
    for (final wallStr in successfulWalls) {
      final parts = wallStr.split(',');
      final r = int.parse(parts[0]);
      final c = int.parse(parts[1]);
      waypoints[r][c] = -1;
    }

    // Fill waypoints evenly along the path
    final int pathLen = path.length;
    for (int i = 0; i < waypointCount; i++) {
      final int pathIndex = (i * (pathLen - 1) / (waypointCount - 1)).round();
      final cell = path[pathIndex];
      waypoints[cell.$1][cell.$2] = i + 1;
    }

    return ZipLevel(rows: rows, cols: cols, waypoints: waypoints);
  }

  void _loadLevel([SharedPreferences? prefs]) {
    _level = _getDynamicLevel(_levelIndex);
    _solution = _solveZip(_level);
    _path.clear();
    _nextWaypoint = _isReversePath ? _level.maxWaypoint : 1;
    _won = false;
    _msg = _isReversePath
        ? 'Reverse Path! Drag through every cell — hit numbers from max down to 1'
        : 'Drag through every cell — hit numbers in order';
    
    if (prefs != null) {
      final pathStrings = prefs.getStringList(PrefsKeys.zipPath(_levelIndex));
      if (pathStrings != null && pathStrings.isNotEmpty) {
        for (final s in pathStrings) {
          final parts = s.split(',');
          if (parts.length == 2) {
            final r = int.tryParse(parts[0]);
            final c = int.tryParse(parts[1]);
            if (r != null && c != null) {
              _path.add((r, c));
              final wp = _level.waypoints[r][c];
              if (wp == _nextWaypoint) {
                if (_isReversePath) {
                  _nextWaypoint--;
                } else {
                  _nextWaypoint++;
                }
              }
            }
          }
        }
        if (_path.isNotEmpty) {
          final lastCellWp = _level.waypoints[_path.last.$1][_path.last.$2];
          final targetLastWp = _isReversePath ? 1 : _level.maxWaypoint;
          if (lastCellWp == targetLastWp && _path.length == _level.totalCellsToVisit) {
            _won = true;
            _msg = 'Path complete!';
          }
        }
      }
    }

    _blindStepsTimer?.cancel();
    _hideGridPathElements = false;
    if (_isDailyMode && _dailyModifierType == 'minimal') {
      _blindStepsTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _hideGridPathElements = true;
          });
        }
      });
    }
  }

  void _reset() {
    _clearState();
    setState(() => _loadLevel());
  }

  bool _inPath(int r, int c) => _path.any((p) => p.$1 == r && p.$2 == c);
  bool _isAdjacent((int,int) a, (int,int) b) => (a.$1-b.$1).abs() + (a.$2-b.$2).abs() == 1;

  void _truncatePathTo((int, int) cell) {
    final idx = _path.indexOf(cell);
    if (idx == -1 || idx == _path.length - 1) return;
    setState(() {
      _path.removeRange(idx + 1, _path.length);
      _nextWaypoint = _isReversePath ? _level.maxWaypoint : 1;
      for (var p in _path) {
        final wp = _level.waypoints[p.$1][p.$2];
        if (wp == _nextWaypoint) {
          if (_isReversePath) {
            _nextWaypoint--;
          } else {
            _nextWaypoint++;
          }
        }
      }
      _msg = 'Dragging...';
    });
  }

  void _addCell(int r, int c) {
    if (_won) return;
    if (r < 0 || r >= _level.rows || c < 0 || c >= _level.cols) return;

    final wp = _level.waypoints[r][c];
    if (wp == -1) return; // Ignore wall cells

    if (_path.isEmpty) {
      final targetStartWp = _isReversePath ? _level.maxWaypoint : 1;
      if (wp != targetStartWp) return;
    }

    if (_inPath(r, c)) return;
    if (_path.isNotEmpty && !_isAdjacent(_path.last, (r, c))) return;

    if (_path.isNotEmpty) {
      final lastCellWp = _level.waypoints[_path.last.$1][_path.last.$2];
      final targetLastWp = _isReversePath ? 1 : _level.maxWaypoint;
      if (lastCellWp == targetLastWp) return;
    }

    final bool isCorrectWaypoint = wp <= 0 || wp == _nextWaypoint;
    if (!isCorrectWaypoint) {
      AudioManager.playFail();
      settingsNotifier.hapticSuccess(); // mediumImpact feedback
      setState(() {
        _msg = 'Go in number order';
      });
      return;
    }

    if (_path.isEmpty) {
      AudioManager.playClick();
    }
    settingsNotifier.hapticTap(); // equivalent to lightImpact
    setState(() {
      if (wp > 0 && wp == _nextWaypoint) {
        if (_isReversePath) {
          _nextWaypoint--;
        } else {
          _nextWaypoint++;
        }
      }
      _path.add((r, c));
      _msg = 'Dragging...';
    });
    _checkWin();
  }

  void _checkWin() {
    if (_won || _tutorialCompleted) return;
    if (_path.isNotEmpty) {
      final lastCellWp = _level.waypoints[_path.last.$1][_path.last.$2];
      final targetLastWp = _isReversePath ? 1 : _level.maxWaypoint;
      if (lastCellWp == targetLastWp) {
        if (_path.length == _level.totalCellsToVisit) {
          if (_isTutorialMode) {
            if (!_tutorialCompleted) {
              AudioManager.playSuccess();
              settingsNotifier.hapticError(); // heavyImpact
              setState(() {
                _tutorialCompleted = true;
              });
            }
          } else {
            setState(() {
              _won = true;
              _msg = 'Path complete!';
              AudioManager.playSuccess();
              settingsNotifier.hapticError(); // heavyImpact
              _savePersistedLevel(_levelIndex + 1);
              _clearState();
            });
          }
        } else {
          setState(() {
            _msg = 'Not all cells filled!';
          });
        }
      }
    }
  }

  (int,int)? _cellAtLocal(Offset local) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final cw = box.size.width / _level.cols;
    final ch = box.size.height / _level.rows;
    final dx = local.dx.clamp(-cw / 2, box.size.width + cw / 2);
    final dy = local.dy.clamp(-ch / 2, box.size.height + ch / 2);
    final col = (dx / cw).floor().clamp(0, _level.cols - 1);
    final row = (dy / ch).floor().clamp(0, _level.rows - 1);
    return (row, col);
  }

  List<(int, int)> _interpolatePath((int, int) start, (int, int) end) {
    List<(int, int)> path = [];
    int r = start.$1;
    int c = start.$2;
    int tr = end.$1;
    int tc = end.$2;
    int limit = 30; // Safety limit to avoid infinite loop
    while ((r != tr || c != tc) && limit > 0) {
      limit--;
      int dr = (tr - r).sign;
      int dc = (tc - c).sign;
      if (dr.abs() >= dc.abs()) {
        r += dr;
      } else {
        c += dc;
      }
      path.add((r, c));
    }
    return path;
  }

  void _nextLevel() async {
    if (!_won) return;
    if (_isDailyMode) {
      Navigator.pop(context, true);
      return;
    }
    if (await ShuffleManager.tryShuffleNavigate(context, 'zip')) return;

    _clearState();
    setState(() {
      _levelIndex = _levelIndex + 1;
      _loadLevel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sw = context.screenWidth - 40;
    final cellW = sw / _level.cols;
    final cellH = cellW;

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark, foregroundColor: context.textPrimary,
        title: Text(_isTutorialMode ? 'Tutorial' : 'Grid Path', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
        centerTitle: true,
        actions: [
          if (_shuffleActive && !_isTutorialMode)
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              tooltip: 'Skip Game',
              onPressed: () => ShuffleManager.tryShuffleNavigate(context, 'zip'),
            ),
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
            onPressed: !_won && !_isTutorialMode
                ? () async {
                    if (_hintCount > 0) {
                      _useHint();
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'zip',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('zip');
                          if (mounted) setState(() => _hintCount = newCount);
                        },
                      );
                    }
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            color: context.textMuted,
            onPressed: () => RulesHelper.showRulesBottomSheet(context, 'zip', 'Grid Path'),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _reset, color: context.textMuted),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isTutorialMode
                ? Text(
                    'Tutorial',
                    style: GoogleFonts.outfit(
                      color: AppTheme.zipPink,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : _isDailyMode
                    ? Text(
                        'Daily Challenge',
                        style: GoogleFonts.outfit(
                          color: AppTheme.zipPink,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : AnimatedLevelIndicator(
                        level: _levelIndex + 1,
                        accentColor: AppTheme.zipPink,
                      ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  if (_isDailyMode)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      color: Colors.amber.withOpacity(0.15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _isReversePath ? 'DAILY CHALLENGE: REVERSE PATH MODE' : 'DAILY CHALLENGE',
                              style: GoogleFonts.outfit(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text('${_path.length} / ${_level.totalCellsToVisit} cells',
                    style: GoogleFonts.outfit(color: context.textMuted, fontSize: context.scale(12))),
                  const SizedBox(height: 4),
                  if (_msg.isNotEmpty) Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(_msg, style: GoogleFonts.outfit(color: _won ? AppTheme.zipPink : context.textSecondary, fontSize: context.scale(13)), textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      Widget gridWidget = RepaintBoundary(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) {
                            if (_won) return;
                            final c = _cellAtLocal(d.localPosition);
                            if (c != null) {
                              final r = c.$1;
                              final col = c.$2;
                              if (_path.isEmpty) {
                                final wp = _level.waypoints[r][col];
                                final targetStartWp = _isReversePath ? _level.maxWaypoint : 1;
                                if (wp == targetStartWp) {
                                  _addCell(r, col);
                                } else {
                                  AudioManager.playFail();
                                  settingsNotifier.hapticSuccess(); // mediumImpact
                                  setState(() => _msg = _isReversePath ? 'Start at number $targetStartWp!' : 'Start at number 1!');
                                }
                              } else {
                                if (_path.contains(c)) {
                                  _truncatePathTo(c);
                                } else {
                                  final last = _path.last;
                                  final int stepR = (r - last.$1).sign;
                                  final int stepC = (col - last.$2).sign;

                                  if ((stepR == 0 && stepC != 0) || (stepR != 0 && stepC == 0)) {
                                    int currR = last.$1;
                                    int currC = last.$2;
                                    while (currR != r || currC != col) {
                                      currR += stepR;
                                      currC += stepC;
                                      _addCell(currR, currC);
                                    }
                                  }
                                }
                              }
                              _saveState();
                            }
                          },
                          onPanStart: (d) {
                            if (_won) return;
                            final c = _cellAtLocal(d.localPosition);
                            if (c != null) {
                              if (_path.isEmpty) {
                                final wp = _level.waypoints[c.$1][c.$2];
                                final targetStartWp = _isReversePath ? _level.maxWaypoint : 1;
                                if (wp == targetStartWp) {
                                  _dragActive = true;
                                  _addCell(c.$1, c.$2);
                                } else {
                                  _dragActive = false;
                                  AudioManager.playFail();
                                  settingsNotifier.hapticSuccess(); // mediumImpact
                                  setState(() => _msg = _isReversePath ? 'Start at number $targetStartWp!' : 'Start at number 1!');
                                }
                              } else {
                                if (_path.contains(c)) {
                                  if (c == _path.last) {
                                    _dragActive = true;
                                  } else if (_path.length >= 2 && c == _path[_path.length - 2]) {
                                    _dragActive = true;
                                    _truncatePathTo(c);
                                  } else {
                                    _dragActive = false;
                                  }
                                } else if (_isAdjacent(_path.last, c) && !_path.contains(c)) {
                                  _dragActive = true;
                                  _addCell(c.$1, c.$2);
                                } else {
                                  _dragActive = false;
                                }
                              }
                            } else {
                              _dragActive = false;
                            }
                          },
                          onPanUpdate: (d) {
                            if (_won || !_dragActive) return;
                            final c = _cellAtLocal(d.localPosition);
                            if (c != null) {
                              if (_path.isNotEmpty && c == _path.last) return; // Ignore duplicate cell updates to prevent lag
                              if (_path.contains(c)) {
                                if (_path.length >= 2 && c == _path[_path.length - 2]) {
                                  _truncatePathTo(c);
                                }
                              } else if (_path.isNotEmpty) {
                                final last = _path.last;
                                final lineCells = _interpolatePath(last, c);
                                for (final cell in lineCells) {
                                  if (!_path.contains(cell)) {
                                    _addCell(cell.$1, cell.$2);
                                  }
                                }
                              } else {
                                _addCell(c.$1, c.$2);
                              }
                            }
                          },
                          onPanEnd: (_) {
                            setState(() {
                              _dragActive = false;
                            });
                            _saveState();
                            _checkWin();
                          },
                          onPanCancel: () {
                            setState(() {
                              _dragActive = false;
                            });
                            _saveState();
                          },
                          child: SizedBox(
                            key: _gridKey, width: sw, height: cellH * _level.rows,
                            child: CustomPaint(
                              painter: _ZipPainter(
                                  level: _level,
                                  path: List.from(_path),
                                  solution: _solution,
                                  cellW: cellW,
                                  cellH: cellH,
                                  won: _won,
                                  cellBgColor: context.bgCard,
                                  gridColor: context.textMuted.withAlpha(70),
                                  pathColor: AppTheme.zipPink,
                                  fillColor: AppTheme.zipPink.withAlpha(35),
                                  visitedWpColor: AppTheme.softSage,
                                  modifierType: _dailyModifierType,
                                  hideWaypoints: _hideGridPathElements,
                                  isDarkMode: Theme.of(context).brightness == Brightness.dark,
                                ),
                            ),
                          ),
                        ),
                      );

                      if (_isDailyMode && _dailyModifierType == 'mirror') {
                        gridWidget = Transform(
                          transform: Matrix4.identity()..scale(-1.0, 1.0),
                          alignment: Alignment.center,
                          child: gridWidget,
                        );
                      }
                      return gridWidget;
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_won && !_isDailyMode)
                    AutoNextCountdown(
                      onNext: _nextLevel,
                      accentColor: AppTheme.zipPink,
                    ),
                  if (_path.isNotEmpty && !_won) TextButton(onPressed: _reset,
                    child: Text('Reset', style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(15)))),
                ],
              ),
            ),
          ),
        ),
      ),
      if (_won && _isDailyMode)
        Positioned.fill(
          child: ChallengeClearedOverlay(
            accentColor: AppTheme.zipPink,
            onComplete: () {
              Navigator.pop(context, true);
            },
          ),
        ),
      // if (_isTutorialMode)
      //   InteractiveTutorialOverlay(
      //     instruction: _tutorialCompleted
      //         ? "Nice! You successfully traced the path and filled the grid."
      //         : "Touch the starting tile and drag your finger to trace a continuous path. Visit the waypoints in order!",
      //     isCompleted: _tutorialCompleted,
      //     onSkip: _finishTutorial,
      //     onStartGame: _finishTutorial,
      //   ),
    ],
  ),
);
  }
}

class _ZipPainter extends CustomPainter {
  final ZipLevel level;
  final List<(int, int)> path;
  final List<(int, int)>? solution;
  final double cellW, cellH;
  final bool won;
  final Color cellBgColor;
  final Color gridColor;
  final Color pathColor;
  final Color fillColor;
  final Color visitedWpColor;
  final String modifierType;
  final bool hideWaypoints;
  final bool isDarkMode;

  _ZipPainter({
    required this.level,
    required this.path,
    this.solution,
    required this.cellW,
    required this.cellH,
    required this.won,
    required this.cellBgColor,
    required this.gridColor,
    required this.pathColor,
    required this.fillColor,
    required this.visitedWpColor,
    required this.modifierType,
    required this.hideWaypoints,
    required this.isDarkMode,
  }) : super();

  Offset _ctr(int r, int c) => Offset(c * cellW + cellW / 2, r * cellH + cellH / 2);

  @override
  void paint(Canvas canvas, Size size) {
    final isRetro = modifierType == 'retro';
    final bgPaint = Paint()..color = cellBgColor..style = PaintingStyle.fill;
    final border = Paint()
      ..color = isRetro ? gridColor.withAlpha(15) : gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isRetro ? 0.8 : 1.2;
    final filled = Paint()..color = fillColor..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellW * 0.26
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        final wp = level.waypoints[r][c];
        final rect = Rect.fromLTWH(c * cellW + 3, r * cellH + 3, cellW - 6, cellH - 6);
        final rr = RRect.fromRectAndRadius(rect, Radius.circular(isRetro ? 2 : 8));
        
        if (wp == -1) {
          final wallBgPaint = Paint()..color = gridColor.withAlpha(25)..style = PaintingStyle.fill;
          canvas.drawRRect(rr, wallBgPaint);
          
          final wallBorder = Paint()..color = gridColor.withAlpha(isRetro ? 10 : 45)..style = PaintingStyle.stroke..strokeWidth = 1.0;
          canvas.drawRRect(rr, wallBorder);
          
          final Color xColor = isDarkMode ? Colors.white : Colors.black;
          final crossPaint = Paint()
            ..color = xColor.withAlpha(isRetro ? 120 : 200)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;
          final cx = rect.center.dx;
          final cy = rect.center.dy;
          final size = cellW * 0.15;
          canvas.drawLine(Offset(cx - size, cy - size), Offset(cx + size, cy + size), crossPaint);
          canvas.drawLine(Offset(cx + size, cy - size), Offset(cx - size, cy + size), crossPaint);
        } else {
          if (isRetro) {
            Color baseColor = cellBgColor;
            final isSolutionCell = solution != null && solution!.contains((r, c));
            if (isSolutionCell) {
              baseColor = Color.lerp(cellBgColor, Colors.black, 0.08) ?? cellBgColor;
            }
            (int, int)? targetCell;
            if (solution != null && solution!.isNotEmpty) {
              final idx = path.length;
              if (idx < solution!.length) {
                targetCell = solution![idx];
              } else {
                targetCell = solution!.last;
              }
            }
            int dist = 999;
            if (targetCell != null) {
              dist = (r - targetCell.$1).abs() + (c - targetCell.$2).abs();
            }
            final factor = (1.0 - dist * 0.25).clamp(0.0, 1.0);
            final retroColor = Color.lerp(baseColor, pathColor.withAlpha(150), factor) ?? baseColor;
            canvas.drawRRect(rr, Paint()..color = retroColor..style = PaintingStyle.fill);
          } else {
            canvas.drawRRect(rr, bgPaint);
          }

          if (path.any((p) => p.$1 == r && p.$2 == c)) {
            canvas.drawRRect(rr, filled);
          }
          canvas.drawRRect(rr, border);
        }
      }
    }
    if (path.length > 1) {
      final lp = Path()..moveTo(_ctr(path[0].$1, path[0].$2).dx, _ctr(path[0].$1, path[0].$2).dy);
      for (int i = 1; i < path.length; i++) {
        lp.lineTo(_ctr(path[i].$1, path[i].$2).dx, _ctr(path[i].$1, path[i].$2).dy);
      }
      canvas.drawPath(lp, linePaint);
    }

    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        final wp = level.waypoints[r][c];
        if (wp > 0) {
          if (isRetro && wp > 1) continue;
          final visited = path.any((p) => p.$1 == r && p.$2 == c);
          if (hideWaypoints && !visited) continue;
          final center = _ctr(r, c);
          if (visited) {
            canvas.drawCircle(center, cellW * 0.28, Paint()..color = pathColor..style = PaintingStyle.fill);
            final tp = TextPainter(
              text: TextSpan(
                text: '$wp',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: cellW * 0.26,
                  fontWeight: FontWeight.w900,
                  fontFamily: isRetro ? 'Courier' : null,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
          } else {
            canvas.drawCircle(center, cellW * 0.28, Paint()..color = pathColor..style = PaintingStyle.stroke..strokeWidth = 2.5);
            final tp = TextPainter(
              text: TextSpan(
                text: '$wp',
                style: TextStyle(
                  color: pathColor,
                  fontSize: cellW * 0.26,
                  fontWeight: FontWeight.w900,
                  fontFamily: isRetro ? 'Courier' : null,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
          }
        }
      }
    }

  }

  @override
  bool shouldRepaint(_ZipPainter old) =>
      old.path.length != path.length ||
      old.won != won ||
      old.gridColor != gridColor ||
      old.fillColor != fillColor ||
      old.cellBgColor != cellBgColor ||
      old.pathColor != pathColor ||
      old.visitedWpColor != visitedWpColor ||
      old.modifierType != modifierType;
}
