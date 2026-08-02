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
  Set<String> _activeModifiers = {};
  bool get _isReversePath => _isDailyMode && _dailyModifierType == 'mirror';
  bool _hideGridPathElements = false;
  Timer? _blindStepsTimer;
  Timer? _gameTimer;
  int _timeLeft = -1;
  bool _timeBonusEarned = false;
  bool _gameOver = false;

  @override
  void dispose() {
    _blindStepsTimer?.cancel();
    _gameTimer?.cancel();
    super.dispose();
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

    if (!_isDailyMode && levelIndex >= 30) {
      if (levelIndex >= 75) {
        gridSize = 8 + ((levelIndex - 75) % 2);
      } else if (levelIndex >= 50) {
        gridSize = 7;
      } else {
        gridSize = 6;
      }
      isSmallGrid = (gridSize <= 5);
      activeMods = RotationEngine.getActiveModifiers(
        gameId: 'zip',
        levelIndex: levelIndex,
        pool: ['waypointSparsity', 'nonRectShape', 'timer'],
        minActive: 2,
        maxActive: 3,
        smallGrid: isSmallGrid,
      );
      _activeModifiers = activeMods;
    } else if (levelIndex < 5) {
      gridSize = 3;
      _activeModifiers = {};
    } else if (levelIndex < 15) {
      gridSize = 4;
      _activeModifiers = {};
    } else if (levelIndex < 30) {
      gridSize = 5;
      _activeModifiers = {};
    } else {
      gridSize = 6;
      _activeModifiers = {};
    }

    final int rows = gridSize;
    final int cols = gridSize;
    final rand = RotationEngine.getDeterminism('zip', levelIndex);

    int waypointCount;
    int minWaypoints = gridSize + 2;

    if (!_isDailyMode && levelIndex >= 30) {
      if (levelIndex >= 75) {
        waypointCount = 6 + (levelIndex % 4);
      } else if (levelIndex >= 50) {
        waypointCount = 5 + (levelIndex % 3);
      } else {
        waypointCount = 4 + (levelIndex % 2);
      }
      if (activeMods.contains('waypointSparsity')) {
        waypointCount = minWaypoints;
      }
    } else if (levelIndex < 5) {
      waypointCount = 2 + (levelIndex ~/ 2);
    } else if (levelIndex < 15) {
      waypointCount = 3 + ((levelIndex - 5) ~/ 3);
    } else if (levelIndex < 30) {
      waypointCount = 5 + ((levelIndex - 15) ~/ 4);
    } else {
      waypointCount = 6 + ((levelIndex - 30) ~/ 5);
    }

    if (levelIndex >= 5) {
      if (waypointCount < minWaypoints) {
        waypointCount = minWaypoints;
      }
    }
    waypointCount = waypointCount.clamp(2, (gridSize * gridSize) - 2);

    List<(int, int)> path = [];
    final successfulWalls = <String>{};

    final bool isNonRect = !_isDailyMode && levelIndex >= 30 && activeMods.contains('nonRectShape');

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

  void _loadLevel([SharedPreferences? prefs]) {
    _gameTimer?.cancel();
    _timeLeft = -1;
    _timeBonusEarned = false;
    _gameOver = false;

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

    if (!_isDailyMode && _levelIndex >= 30 && _activeModifiers.contains('timer')) {
      _timeLeft = 20 + (_level.rows * 12);
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
    final controller = TextEditingController(text: '${_levelIndex + 1}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text('Jump to Level', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter level number (1 - 150):', style: GoogleFonts.outfit(color: context.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: GoogleFonts.outfit(color: context.textPrimary),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'e.g. 100',
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
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.zipPink),
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val >= 1) {
                Navigator.pop(context);
                setState(() {
                  _levelIndex = val - 1;
                  _loadLevel();
                });
              }
            },
            child: Text('Go', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
            icon: const Icon(Icons.help_outline, size: 20),
            color: context.textMuted,
            onPressed: () => RulesHelper.showRulesBottomSheet(context, 'zip', 'Grid Path'),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _reset, color: context.textMuted),
          InkWell(
            onTap: null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _isTutorialMode
                      ? Text('Tutorial', style: GoogleFonts.outfit(color: AppTheme.zipPink, fontSize: 14, fontWeight: FontWeight.bold))
                      : _isDailyMode
                          ? Text('Daily Challenge', style: GoogleFonts.outfit(color: AppTheme.zipPink, fontSize: 14, fontWeight: FontWeight.bold))
                          : AnimatedLevelIndicator(
                              level: _levelIndex + 1,
                              accentColor: AppTheme.zipPink,
                            ),
                  if (!_isTutorialMode && !_isDailyMode) ...[
                    const SizedBox(width: 4),
                    const Icon(null, size: 14, color: AppTheme.zipPink),
                  ],
                ],
              ),
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
      if (_gameOver)
        Positioned.fill(
          child: LossOverlay(
            onTryAgain: () {
              setState(() {
                _gameOver = false;
                _loadLevel();
              });
            },
            subtitle: 'You ran out of time!',
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
      old.level != level ||
      old.path.length != path.length ||
      old.won != won ||
      old.gridColor != gridColor ||
      old.fillColor != fillColor ||
      old.cellBgColor != cellBgColor ||
      old.pathColor != pathColor ||
      old.visitedWpColor != visitedWpColor ||
      old.modifierType != modifierType ||
      old.hideWaypoints != hideWaypoints;
}
