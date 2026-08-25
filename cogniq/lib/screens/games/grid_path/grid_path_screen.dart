import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../widgets/game_level_chip.dart';
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
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../utils/rotation_engine.dart';
import '../../../utils/point_manager.dart';
import '../../../utils/shuffle_manager.dart';
import '../../../widgets/loss_overlay.dart';

class ZipLevel {
  final int rows, cols;
  final List<List<int>> waypoints;
  const ZipLevel({required this.rows, required this.cols, required this.waypoints});
  int get maxWaypoint { int m = 0; for (var r in waypoints) { for (var v in r) { if (v > m) { m = v; } } } return m; }
  int get wallCount { int count = 0; for (var r in waypoints) { for (var v in r) { if (v == -1) { count++; } } } return count; }
  int get totalCells => rows * cols;
  int get totalCellsToVisit => rows * cols - wallCount;
}
/// The free-play modifier pool. Mirrored by `pools['zip']` in
/// test/difficulty_curve_test.dart — keep the two in step.
///
/// `silence` must never be added here: it defers judgement to a Submit, while
/// `ratchet` punishes an out-of-order number the instant it is touched.
const List<String> kGridPathModifierPool = [
  'waypointSparsity',
  'nonRectShape',
  'timer',
  'retro',
  'minimal',
  'ratchet',
];

class GridPathScreen extends StatefulWidget {
  const GridPathScreen({super.key});
  @override
  State<GridPathScreen> createState() => _GridPathScreenState();
}

class _GridPathScreenState extends State<GridPathScreen> with SingleTickerProviderStateMixin {
  String? _forcedModifier;
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
  String _dailyModifierName = '';
  String _dailyModifierDesc = '';
  List<(int, int)>? _solution;
  bool _shuffleActive = false;
  Set<String> _activeModifiers = {};
  bool get _isReversePath => _isDailyMode && _dailyModifierType == 'mirror';
  bool _hideGridPathElements = false;
  Timer? _blindStepsTimer;
  Timer? _gameTimer;
  int _timeLeft = -1;
  // Timer value at the moment the hard timer started; 0 when no timer ran.
  // Only used for the Speed Demon achievement check on clear.
  int _initialTime = 0;
  bool _timeBonusEarned = false;
  bool _gameOver = false;
  bool _isMemorizingPhase = false;
  int _memorizeTimeLeft = 10;
  Timer? _memorizeTimer;

  @override
  void dispose() {
    _blindStepsTimer?.cancel();
    _gameTimer?.cancel();
    _memorizeTimer?.cancel();
    super.dispose();
  }

  /// Modifiers now begin at a per-game level chosen in RotationEngine
  /// rather than a flat level 30 for every game.
  bool get _modsOn => !_isDailyMode && RotationEngine.hasModifiers('zip', _levelIndex);

  // COGNIQ-FIX:mod-active-helper
  bool _isModActive(String name) {
    if (_forcedModifier == name) return true;
    if (_isDailyMode) return _dailyModifierType == name;
    return _levelIndex >= RotationEngine.modifierStartLevel('zip') &&
        _activeModifiers.contains(name);
  }

  /// `ratchet` — the path cannot be retraced. Backing a step out is this
  /// game's undo, so locking it is what "No Way Back" means here; Restart
  /// stays available, because a player who paints themselves into a corner
  /// needs a way out that is not a softlock.
  bool get _ratchet => _isModActive('ratchet');
  int _strikes = 0;

  /// `r * cols + c` for each waypoint reached out of order. Deduplicated by
  /// cell so brushing the same number twice during one drag cannot spend both
  /// mistakes at once.
  final Set<int> _crackedCells = {};
  String _lossReason = 'You ran out of time!';

  void _registerRatchetMistake(int r, int c) {
    final key = r * _level.cols + c;
    if (_crackedCells.contains(key)) return;
    setState(() {
      _crackedCells.add(key);
      _strikes++;
      if (_strikes >= 2) {
        _gameTimer?.cancel();
        _lossReason = 'Two numbers taken out of order — no way back.';
        _gameOver = true;
      } else {
        _msg = 'Out of order. One mistake left.';
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _level = _getDynamicLevel(0);
    _initLevel();
  }

  Future<void> _initLevel() async {
    await HintManager.startLevel('zip');
    _hintCount = await HintManager.getHints('zip');
    final prefs = await SharedPreferences.getInstance();
    _isDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    if (_isDailyMode) {
      _dailyModifierType = prefs.getString(PrefsKeys.dailyModifierType) ?? '';
      _dailyModifierName = prefs.getString(PrefsKeys.dailyModifierName) ?? '';
      _dailyModifierDesc = prefs.getString(PrefsKeys.dailyModifierDesc) ?? '';
    } else {
      _dailyModifierType = '';
      _dailyModifierName = '';
      _dailyModifierDesc = '';
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
    final earned = await HintManager.onLevelCleared(
      'zip',
      // Speed Demon: cleared a hard-timer level with more than half the
      // clock still left. _initialTime is 0 unless the timer modifier ran.
      isSpeedDemon: _initialTime > 0 && _timeLeft * 2 > _initialTime,
    );
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
          _gameTimer?.cancel();
          _won = true;
          _msg = 'Path complete!';
          AudioManager.playSuccess();
          settingsNotifier.hapticError(); // equivalent to heavyImpact
          _savePersistedLevel(_levelIndex + 1);
          _clearState();

          if (_timeLeft > 0 && _timeBonusEarned) {
            PointManager.addPoints(5);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Speed Bonus! Earned +5 Points!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
                backgroundColor: Colors.amber,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        _msg = 'Hint added to path!';
        AudioManager.playClick();
        settingsNotifier.hapticTap(); // equivalent to lightImpact
        _saveState();
      }
    });
  }

  void _reverseRange(List<(int, int)> a, int i, int j) {
    while (i < j) {
      final t = a[i];
      a[i] = a[j];
      a[j] = t;
      i++;
      j--;
    }
  }

  List<(int, int)> _randomHamiltonian(int rows, int cols, Random rand, {int? moves}) {
    final path = <(int, int)>[];
    for (int r = 0; r < rows; r++) {
      if (r.isEven) {
        for (int c = 0; c < cols; c++) {
          path.add((r, c));
        }
      } else {
        for (int c = cols - 1; c >= 0; c--) {
          path.add((r, c));
        }
      }
    }
    int key(int r, int c) => r * cols + c;
    final pos = <int, int>{
      for (int i = 0; i < path.length; i++) key(path[i].$1, path[i].$2): i
    };

    final n = path.length;
    final total = moves ?? (8 * n);
    for (int m = 0; m < total; m++) {
      final atHead = rand.nextBool();
      final end = atHead ? path.first : path.last;
      final nbrs = <(int, int)>[];
      for (final d in [const (-1, 0), const (1, 0), const (0, -1), const (0, 1)]) {
        final nr = end.$1 + d.$1, nc = end.$2 + d.$2;
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
          nbrs.add((nr, nc));
        }
      }
      final nb = nbrs[rand.nextInt(nbrs.length)];
      final k = pos[key(nb.$1, nb.$2)]!;
      if (atHead) {
        if (k > 0) _reverseRange(path, 0, k - 1);
      } else {
        if (k < n - 1) _reverseRange(path, k + 1, n - 1);
      }
      for (int i = 0; i < n; i++) {
        pos[key(path[i].$1, path[i].$2)] = i;
      }
    }
    return path;
  }

  double _turnRatio(List<(int, int)> path) {
    if (path.length < 3) return 0.0;
    int turns = 0;
    for (int i = 1; i < path.length - 1; i++) {
      final dr1 = path[i].$1 - path[i - 1].$1;
      final dc1 = path[i].$2 - path[i - 1].$2;
      final dr2 = path[i + 1].$1 - path[i].$1;
      final dc2 = path[i + 1].$2 - path[i].$2;
      if (dr1 != dr2 || dc1 != dc2) turns++;
    }
    return turns / (path.length - 2);
  }

  ZipLevel _getDynamicLevel(int levelIndex) {
    int gridSize;
    Set<String> activeMods = {};
    bool isSmallGrid = false;

    // Board size only. These thresholds are difficulty tuning, NOT a modifier
    // gate -- the modifier gate lives in its own block below.
    if (!_isDailyMode && levelIndex >= 30) { // not-a-modifier-gate
      if (levelIndex >= 75) {
        gridSize = 8 + ((levelIndex - 75) % 2);
      } else if (levelIndex >= 50) {
        gridSize = 7;
      } else {
        gridSize = 6;
      }
    } else if (levelIndex < 5) {
      gridSize = 3;
    } else if (levelIndex < 15) {
      gridSize = 4;
    } else if (levelIndex < 30) { // not-a-modifier-gate
      gridSize = 5;
    } else {
      gridSize = 6;
    }

    isSmallGrid = (gridSize <= 5);

    // COGNIQ-FIX:mod-start-early
    // Modifier selection is gated on the per-game start level in RotationEngine,
    // never on a literal 30. Hardcoding 30 here made the map value unreachable.
    if (!_isDailyMode && RotationEngine.hasModifiers('zip', levelIndex)) {
      activeMods = RotationEngine.getActiveModifiers(
        gameId: 'zip',
        levelIndex: levelIndex,
        pool: kGridPathModifierPool,
        minActive: 2,
        maxActive: 3,
        smallGrid: isSmallGrid,
      );
    }

    if (_forcedModifier != null) {
      activeMods = {_forcedModifier!};
    }

    if (activeMods.contains('nonRectShape') && !activeMods.contains('timer')) {
      activeMods = Set.from(activeMods)..add('timer');
    }
    _activeModifiers = activeMods;

    final int rows = gridSize;
    final int cols = gridSize;
    final rand = RotationEngine.getDeterminism('zip', levelIndex);

    int waypointCount;
    int minWaypoints = gridSize + 2;

    // COGNIQ-FIX:gridpath-floor
    if (!_isDailyMode && levelIndex >= 30) { // not-a-modifier-gate
      // Start above minWaypoints (8) and climb, so these values actually survive the
      // floor below. The old 4/5/6-based branches were silently discarded: every
      // level from 30 to 74 resolved to a flat 8. // not-a-modifier-gate
      final int band = levelIndex >= 75 ? 2 : (levelIndex >= 50 ? 1 : 0);
      waypointCount = minWaypoints + band + (levelIndex % 2); // 8-9, 9-10, 10-11
    } else if (levelIndex < 5) {
      waypointCount = 2 + (levelIndex ~/ 2);
    } else if (levelIndex < 15) {
      // COGNIQ-FIX:curve-plateau
      // Was `3 + ((levelIndex - 5) ~/ 3)` -> 3..6, every value at or under the
      // floor of 6, so levels 5-14 were TEN identical 6-waypoint boards.
      // Expressed relative to minWaypoints it now climbs 6,6,6,7,7,7,8,8,8,9.
      waypointCount = minWaypoints + ((levelIndex - 5) ~/ 3);
    } else if (levelIndex < 30) {
      // COGNIQ-FIX:curve-plateau
      // Was `5 + ((levelIndex - 15) ~/ 4)` -> 5..7 against a floor of 7, so
      // levels 15-26 were TWELVE identical boards. Now climbs 7 -> 11.
      waypointCount = minWaypoints + ((levelIndex - 15) ~/ 3);
    } else {
      // Daily-mode path for level >= 30 (gridSize 6, floor 8). Was
      // `6 + ((levelIndex - 30) ~/ 5)`, which stayed under the floor until
      // level 40 and flattened daily levels 30-39.
      // COGNIQ-FIX:curve-plateau
      waypointCount = minWaypoints + ((levelIndex - 30) ~/ 5);
    }

    if (levelIndex >= 5) {
      if (waypointCount < minWaypoints) {
        waypointCount = minWaypoints;
      }
    }
    waypointCount = waypointCount.clamp(2, (gridSize * gridSize) - 2);

    // COGNIQ-FIX:mod-deadeffect
    // waypointSparsity used to sit inside the `levelIndex >= 30` branch AND
    // clamp its floor to minWaypoints, so on every level whose baseline already
    // equalled minWaypoints it removed nothing at all. It now lives outside the
    // level-30 branch (so it works from the map's start level onwards) and is
    // applied after the floor, with its own lower bound one below minWaypoints
    // but never under 4 -- guaranteeing it always removes at least one waypoint.
    if (activeMods.contains('waypointSparsity') && waypointCount > 4) {
      final int sparseFloor = (minWaypoints - 1) < 4 ? 4 : (minWaypoints - 1);
      int sparse = waypointCount - 2;
      if (sparse < sparseFloor) sparse = sparseFloor;
      if (sparse >= waypointCount) sparse = waypointCount - 1;
      if (sparse < 4) sparse = 4;
      waypointCount = sparse;
    }

    List<(int, int)> path = [];
    final successfulWalls = <String>{};

    final bool isNonRect = (_isDailyMode && _dailyModifierType == 'nonRectShape') ||
        (!_isDailyMode && activeMods.contains('nonRectShape'));

    if (!isNonRect) {
      // Rectangular grid: generate twisty Hamiltonian path via backbite scramble
      path = _randomHamiltonian(rows, cols, rand);
      int guard = 0;
      while (_turnRatio(path) < 0.35 && guard < 50) {
        path = _randomHamiltonian(rows, cols, rand);
        guard++;
      }
    } else {
      // nonRectShape: try DFS with a higher budget (500 attempts)
      for (int attempt = 0; attempt < 500; attempt++) {
        final localVisited = <String>{};
        localVisited.add('0,0');
        localVisited.add('0,${cols - 1}');
        localVisited.add('${rows - 1},0');
        localVisited.add('${rows - 1},${cols - 1}');

        int startR = rand.nextInt(rows);
        int startC = rand.nextInt(cols);
        while (localVisited.contains('$startR,$startC')) {
          startR = rand.nextInt(rows);
          startC = rand.nextInt(cols);
        }

        final currentPath = <(int, int)>[(startR, startC)];
        localVisited.add('$startR,$startC');

        while (true) {
          final cur = currentPath.last;
          final neighbors = <(int, int)>[];
          for (final d in [const (-1, 0), const (1, 0), const (0, -1), const (0, 1)]) {
            final nr = cur.$1 + d.$1;
            final nc = cur.$2 + d.$2;
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && !localVisited.contains('$nr,$nc')) {
              neighbors.add((nr, nc));
            }
          }
          if (neighbors.isEmpty) break;

          neighbors.shuffle(rand);
          neighbors.sort((a, b) {
            int countA = 0, countB = 0;
            for (final d in [const (-1, 0), const (1, 0), const (0, -1), const (0, 1)]) {
              final ar = a.$1 + d.$1, ac = a.$2 + d.$2;
              if (ar >= 0 && ar < rows && ac >= 0 && ac < cols && !localVisited.contains('$ar,$ac')) countA++;
              final br = b.$1 + d.$1, bc = b.$2 + d.$2;
              if (br >= 0 && br < rows && bc >= 0 && bc < cols && !localVisited.contains('$br,$bc')) countB++;
            }
            return countA.compareTo(countB);
          });

          final next = neighbors.first;
          currentPath.add(next);
          localVisited.add('${next.$1},${next.$2}');
        }

        final targetCoverage = rows * cols - 4;
        if (currentPath.length >= targetCoverage) {
          path = currentPath;
          for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
              final key = '$r,$c';
              if (!localVisited.contains(key)) {
                successfulWalls.add(key);
              }
            }
          }
          successfulWalls.add('0,0');
          successfulWalls.add('0,${cols - 1}');
          successfulWalls.add('${rows - 1},0');
          successfulWalls.add('${rows - 1},${cols - 1}');
          break;
        }
      }

      // Gracious fallback if DFS fails to find nonRect path: use full rectangular path
      if (path.isEmpty) {
        path = _randomHamiltonian(rows, cols, rand);
        int guard = 0;
        while (_turnRatio(path) < 0.35 && guard < 50) {
          path = _randomHamiltonian(rows, cols, rand);
          guard++;
        }
      }
    }

    final waypoints = List.generate(rows, (_) => List.filled(cols, 0));
    for (final wallStr in successfulWalls) {
      final parts = wallStr.split(',');
      final r = int.parse(parts[0]);
      final c = int.parse(parts[1]);
      waypoints[r][c] = -1;
    }

    final int pathLen = path.length;
    for (int i = 0; i < waypointCount; i++) {
      final int pathIndex = (i * (pathLen - 1) / (waypointCount - 1)).round();
      final cell = path[pathIndex];
      waypoints[cell.$1][cell.$2] = i + 1;
    }

    return ZipLevel(rows: rows, cols: cols, waypoints: waypoints);
  }

  // COGNIQ-FIX:mod-desc-copy
  String _getModifierDescription(String mod) {
    switch (mod) {
      case 'waypointSparsity':
        return 'Fewer waypoints are numbered. Deduce the path between them.';
      case 'nonRectShape':
        return 'The grid has irregular borders and obstacles.';
      case 'timer':
        return 'Complete the entire path before the timer runs out.';
      case 'retro':
        return 'Classic retro styling active for the grid path.';
      case 'minimal':
        return 'Numbered waypoints fade away after 10 seconds.';
      case 'ratchet':
        return 'The path cannot be retraced once drawn.';
      default:
        return '';
    }
  }

  String get _modifierBannerText {
    if (_isTutorialMode) return '';
    if (_isDailyMode) {
      if (_dailyModifierDesc.isNotEmpty) return _dailyModifierDesc;
      if (_dailyModifierName.isNotEmpty) return _dailyModifierName;
      return '';
    }
    return _activeModifiers
        .map(_getModifierDescription)
        .where((d) => d.isNotEmpty)
        .join(' · ');
  }

  void _loadLevel([SharedPreferences? prefs]) {
    _gameTimer?.cancel();
    _timeLeft = -1;
    _timeBonusEarned = false;
    _gameOver = false;

    _level = _getDynamicLevel(_levelIndex);
    _solution = _solveZip(_level);
    _path.clear();
    _strikes = 0;
    _crackedCells.clear();
    _lossReason = 'You ran out of time!';
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
    _memorizeTimer?.cancel();
    _isMemorizingPhase = false;

    final bool isMinimal = _forcedModifier == 'minimal' ||
        (_isDailyMode && _dailyModifierType == 'minimal') ||
        (!_isDailyMode && _modsOn && _activeModifiers.contains('minimal'));
    if (isMinimal) {
      _isMemorizingPhase = true;
      _memorizeTimeLeft = 10;
      _memorizeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            if (_memorizeTimeLeft > 1) {
              _memorizeTimeLeft--;
            } else {
              _memorizeTimer?.cancel();
              _isMemorizingPhase = false;
              _hideGridPathElements = true;
            }
          });
        }
      });
    }

    final bool startTimer = (_isDailyMode && _dailyModifierType == 'timer') ||
        (!_isDailyMode && _activeModifiers.contains('timer'));
    if (startTimer) {
      _timeLeft = 20 + (_level.rows * 12);
      _initialTime = _timeLeft;
      _timeBonusEarned = true;
      _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            if (_timeLeft > 0) {
              _timeLeft--;
            } else {
              _timeLeft = 0;
              _timeBonusEarned = false;
              _gameTimer?.cancel();
              AudioManager.playFail();
              _gameOver = true;
            }
          });
        }
      });
    }
  }

  void _showJumpToLevelDialog() {
    showDialog(
      context: context,
      builder: (context) {
        int target = _levelIndex + 1;
        String? selectedMod = _forcedModifier;
        const pool = kGridPathModifierPool;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: context.bgCard,
              title: Text('Jump to Level', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(color: context.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Level Number (1+)',
                        labelStyle: GoogleFonts.outfit(color: context.textSecondary),
                      ),
                      onChanged: (val) {
                        target = int.tryParse(val) ?? target;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedMod,
                      dropdownColor: context.bgCard,
                      style: GoogleFonts.outfit(color: context.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Force Modifier',
                        labelStyle: GoogleFonts.outfit(color: context.textSecondary),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None (Default)')),
                        ...pool.map((m) => DropdownMenuItem(value: m, child: Text(m))),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          selectedMod = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.outfit(color: context.textSecondary)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (target > 0) {
                      setState(() {
                        _levelIndex = target - 1;
                        _forcedModifier = selectedMod;
                        _loadLevel();
                      });
                    }
                  },
                  child: Text('Jump', style: GoogleFonts.outfit(color: AppTheme.zipPink)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _reset() {
    _clearState();
    setState(() => _loadLevel());
  }

  bool _inPath(int r, int c) => _path.any((p) => p.$1 == r && p.$2 == c);
  bool _isAdjacent((int,int) a, (int,int) b) => (a.$1-b.$1).abs() + (a.$2-b.$2).abs() == 1;

  void _truncatePathTo((int, int) cell) {
    // Retracing is this game's undo, so `ratchet` locks it. The chip above the
    // board says so, and Restart is still there.
    if (_ratchet) return;
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
    if (_won || _gameOver) return;
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
      if (_ratchet) {
        _registerRatchetMistake(r, c);
        return;
      }
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
        // Flexible with ellipsis so a three-digit level never pushes the app
        // bar past the screen edge.
        title: const GameTitle('Grid Path'),
        centerTitle: true,
        actions: [
          if (_shuffleActive && !_isTutorialMode)
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              tooltip: 'Skip Game',
              onPressed: () => ShuffleManager.tryShuffleNavigate(context, 'zip'),
            ),
          IconButton(
            tooltip: 'Hint',
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
          if (_timeLeft >= 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Row(
                  children: [
                    Icon(
                      Icons.timer,
                      color: _timeLeft <= 10 ? Colors.red : Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_timeLeft s',
                      style: GoogleFonts.spaceGrotesk(
                        color: _timeLeft <= 10 ? Colors.red : Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            tooltip: 'Rules',
            icon: const Icon(Icons.help_outline, size: 20),
            color: context.textMuted,
            onPressed: () => RulesHelper.showRulesBottomSheet(context, 'zip', 'Grid Path'),
          ),
          IconButton(tooltip: 'Restart', icon: const Icon(Icons.refresh, size: 20), onPressed: _reset, color: context.textMuted),
          GameLevelChip(
            level: _levelIndex + 1,
            modeLabel: _isTutorialMode ? 'Tutorial' : (_isDailyMode ? 'Daily' : null),
            accent: AppTheme.accentFor('zip'),
            onTap: kDebugMode ? _showJumpToLevelDialog : null,
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
                   if (_isMemorizingPhase) ...[
                     Container(
                       width: double.infinity,
                       margin: const EdgeInsets.only(bottom: 12),
                       padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                       decoration: BoxDecoration(
                         color: Colors.redAccent.withOpacity(0.12),
                         borderRadius: BorderRadius.circular(8),
                       ),
                       child: Text(
                         '📝 MEMORIZE THE PATH: $_memorizeTimeLeft s',
                         style: GoogleFonts.spaceGrotesk(
                           color: Colors.redAccent,
                           fontWeight: FontWeight.bold,
                           fontSize: 14,
                           letterSpacing: 1.2,
                         ),
                         textAlign: TextAlign.center,
                       ),
                     ),
                   ],
                   if (_msg.isNotEmpty) Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(_msg, style: GoogleFonts.outfit(color: _won ? AppTheme.zipPink : context.textSecondary, fontSize: context.scale(13)), textAlign: TextAlign.center),
                  ),
                   const SizedBox(height: 12),
                   if (_ratchet) ...[
                     Container(
                       margin: const EdgeInsets.only(bottom: 10),
                       padding: const EdgeInsets.symmetric(
                           horizontal: 14, vertical: 7),
                       decoration: BoxDecoration(
                         color: AppTheme.warmAmber.withValues(alpha: 0.18),
                         borderRadius: BorderRadius.circular(10),
                         border: Border.all(
                             color: AppTheme.warmAmber.withValues(alpha: 0.55)),
                       ),
                       // The label is long enough to out-measure a phone
                       // width on its own, so the Text must be Flexible and
                       // allowed to wrap. It must never be clipped or
                       // dropped: a modifier that runs has to stay readable,
                       // strike count included.
                       child: Row(
                         mainAxisSize: MainAxisSize.min,
                         crossAxisAlignment: CrossAxisAlignment.center,
                         children: [
                           const Icon(Icons.lock_outline,
                               size: 16, color: AppTheme.warmAmber),
                           const SizedBox(width: 6),
                           Flexible(
                             child: Text(
                               'No Way Back  ·  retrace locked  ·  mistakes $_strikes/2',
                               textAlign: TextAlign.center,
                               softWrap: true,
                               style: GoogleFonts.spaceGrotesk(
                                 color: AppTheme.warmAmber,
                                 fontWeight: FontWeight.bold,
                                 fontSize: context.scale(11),
                                 height: 1.3,
                               ),
                             ),
                           ),
                         ],
                       ),
                     ),
                   ],
                   if (_modifierBannerText.isNotEmpty) ...[
                     Padding(
                       padding: const EdgeInsets.only(bottom: 8.0),
                       child: Text(
                         _modifierBannerText,
                         textAlign: TextAlign.center,
                         style: GoogleFonts.outfit(
                           fontSize: 13,
                           fontWeight: FontWeight.w600,
                           color: AppTheme.zipPink.withOpacity(0.9),
                         ),
                       ),
                     ),
                   ],
                   Builder(
                    builder: (context) {
                      Widget gridWidget = RepaintBoundary(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) {
                            if (_won || _isMemorizingPhase) return;
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
                            if (_won || _isMemorizingPhase) return;
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
                            if (_won || !_dragActive || _isMemorizingPhase) return;
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
                             child: Stack(
                               children: [
                                 Positioned.fill(
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
                                         modifierType: _forcedModifier ?? (_isDailyMode ? _dailyModifierType : (_activeModifiers.contains('retro') ? 'retro' : '')),
                                         hideWaypoints: _hideGridPathElements,
                                         isDarkMode: Theme.of(context).brightness == Brightness.dark,
                                         crackedCells: _crackedCells,
                                         crackColor: AppTheme.warmAmber.withValues(alpha: 0.45),
                                       ),
                                   ),
                                 ),
                                 if (_isMemorizingPhase)
                                   Positioned.fill(
                                     child: Container(
                                       color: Colors.black.withOpacity(0.5),
                                       child: Center(
                                         child: Column(
                                           mainAxisAlignment: MainAxisAlignment.center,
                                           children: [
                                             Text(
                                               'Memorize the path!',
                                               style: GoogleFonts.outfit(
                                                 fontSize: 22,
                                                 fontWeight: FontWeight.bold,
                                                 color: Colors.white,
                                               ),
                                             ),
                                             const SizedBox(height: 8),
                                             Text(
                                               'Starting in $_memorizeTimeLeft s...',
                                               style: GoogleFonts.outfit(
                                                 fontSize: 16,
                                                 color: Colors.white70,
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
      if (_gameOver)
        Positioned.fill(
          child: LossOverlay(
            onTryAgain: () {
              setState(() {
                _gameOver = false;
                _loadLevel();
              });
            },
            subtitle: _lossReason,
            accentColor: AppTheme.zipPink,
          ),
        ),
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

  /// `ratchet` scars, keyed `r * cols + c`. At most one exists before the
  /// level ends, and the set is empty on every other level, so drawing them is
  /// a loop over an empty collection rather than a per-cell test.
  final Set<int> crackedCells;
  final Color crackColor;

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
    required this.crackedCells,
    required this.crackColor,
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
    for (final key in crackedCells) {
      final r = key ~/ level.cols;
      final c = key % level.cols;
      if (r < 0 || r >= level.rows || c < 0 || c >= level.cols) continue;
      final rect = Rect.fromLTWH(c * cellW + 3, r * cellH + 3, cellW - 6, cellH - 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()
          ..color = crackColor
          ..style = PaintingStyle.fill,
      );
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
      old.level != level ||
      old.path.length != path.length ||
      old.won != won ||
      old.gridColor != gridColor ||
      old.fillColor != fillColor ||
      old.cellBgColor != cellBgColor ||
      old.pathColor != pathColor ||
      old.visitedWpColor != visitedWpColor ||
      old.modifierType != modifierType ||
      old.hideWaypoints != hideWaypoints ||
      old.crackedCells.length != crackedCells.length;
}
