import 'dart:convert';
import 'dart:math';
import 'dart:async';
import '../../../utils/point_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../widgets/game_level_chip.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../utils/prefs_keys.dart';
import '../../../utils/shuffle_manager.dart';
import '../../../widgets/loss_overlay.dart';
import '../../../utils/audio_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../utils/rotation_engine.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../widgets/fog_overlay.dart';
import '../../../widgets/buy_hints_dialog.dart';
import '../../../utils/hint_manager.dart';
import '../../../widgets/game_tutorial_dialog.dart';
import 'bridges_levels.dart';

class BridgesLevel {
  final int gridSize;
  final List<int> islands;
  const BridgesLevel({required this.gridSize, required this.islands});
}

class BridgesScreen extends StatefulWidget {
  const BridgesScreen({super.key});

  @override
  State<BridgesScreen> createState() => _BridgesScreenState();
}

class _BridgesScreenState extends State<BridgesScreen> {
  String? _forcedModifier;

  int _currentLevel = 0;
  bool _isLoading = true;
  bool _isSuccess = false;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  double _dailyRadius = 1.5;

  String _dailyModifierName = '';
  String _dailyModifierDesc = '';

  late int _gridSize;
  late List<int> _islands;
  Map<String, int> _bridgeCounts = {}; // Key: "min-max" (endpoint indices), Value: 0, 1, 2
  int _hintCount = 1;
  bool _isHintShowing = false;
  int _hintIdx = -1;

  // Selected island for two-tap connection
  int _selectedIsland = -1;

  // Drag variables
  int _dragStartIsland = -1;
  final ValueNotifier<Offset?> _dragPositionNotifier = ValueNotifier<Offset?>(null);

  bool _gameOver = false;
  Set<String> _activeModifiers = {};
  bool _isPanMode = false;

  // COGNIQ-FIX:mod-active-helper
  bool _isModActive(String name) {
    if (_forcedModifier == name) return true;
    if (_playDailyMode) return _dailyModifierType == name;
    return _currentLevel >= RotationEngine.modifierStartLevel('bridges') &&
        _activeModifiers.contains(name);
  }

  // COGNIQ-FIX:mod-getters
  bool get _isEndgame => _isModActive('timer');
  bool get _isHiddenIslandsActive => _isModActive('hiddenIslands');
  bool get _isFogActive => _isModActive('fog');
  bool get _isZoomActive => _isModActive('zoom');

  // COGNIQ-FIX:mod-desc-copy
  String _getModifierDescription(String mod) {
    switch (mod) {
      case 'hiddenIslands':
        return 'Some island requirements are hidden until connected.';
      case 'timer':
        return 'A countdown timer is active for this board.';
      case 'zoom':
        return 'The grid is magnified. Pan to explore the full board.';
      case 'fog':
        return 'Fog obscures distant islands until connected.';
      default:
        return '';
    }
  }

  String get _modifierBannerText {
    if (_playDailyMode) {
      if (_dailyModifierDesc.isNotEmpty) return _dailyModifierDesc;
      if (_dailyModifierName.isNotEmpty) return _dailyModifierName;
      return '';
    }
    return _activeModifiers
        .map(_getModifierDescription)
        .where((d) => d.isNotEmpty)
        .join(' · ');
  }

  final Set<int> _hiddenIslands = {};
  Timer? _gameTimer;
  int _timeLeft = -1;
  // Timer value at the moment the hard timer started; 0 when no timer ran.
  // Only used for the Speed Demon achievement check on clear.
  int _initialTime = 0;
  bool _timeBonusEarned = false;

  /// Held in state rather than rebuilt inside build(): a fresh controller
  /// on every frame leaked one per rebuild and snapped the player's pan
  /// position back to the start each time the board changed.
  final TransformationController _zoomController =
      TransformationController(Matrix4.identity()..scale(1.4));

  @override
  void dispose() {
    _zoomController.dispose();
    _gameTimer?.cancel();
    super.dispose();
  }

  /// Modifiers now begin at a per-game level chosen in RotationEngine
  /// rather than a flat level 30 for every game.
  bool get _modsOn => !_playDailyMode && RotationEngine.hasModifiers('bridges', _currentLevel);

  @override
  void initState() {
    super.initState();
    _loadProgressAndLevel();
  }

  Future<void> _loadProgressAndLevel() async {
    final prefs = await SharedPreferences.getInstance();
    _hintCount = await HintManager.getHints('bridges');
    _playDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString(PrefsKeys.dailyModifierType) ?? '';
      _dailyModifierName = prefs.getString(PrefsKeys.dailyModifierName) ?? '';
      _dailyModifierDesc = prefs.getString(PrefsKeys.dailyModifierDesc) ?? '';
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
      _dailyModifierName = '';
      _dailyModifierDesc = '';
    }

    int level = prefs.getInt(PrefsKeys.gameLevel('bridges')) ?? 0;
    if (mounted) {
      setState(() {
        _currentLevel = level;
        _isLoading = false;
        _setupLevel();
      });
    }
  }

  void _showJumpToLevelDialog() {
    showDialog(
      context: context,
      builder: (context) {
        int target = _currentLevel + 1;
        String? selectedMod = _forcedModifier;
        final pool = ['hiddenIslands', 'timer', 'zoom', 'fog'];
        
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
                        _currentLevel = target - 1;
                        _forcedModifier = selectedMod;
                        _setupLevel();
                      });
                    }
                  },
                  child: Text('Jump', style: GoogleFonts.outfit(color: AppTheme.accentFor('bridges'))),
                ),
              ],
            );
          }
        );
      },
    );
  }



  void _setupLevel() {
    HintManager.startLevel('bridges');
    final level = kBridgesLevels[_currentLevel % kBridgesLevels.length];
    _gridSize = level.gridSize;

    if (_modsOn) {
      // Zoom fixes the board at 1.4x and lets the player scroll, which is a
      // fair challenge on a big grid but simply hides half a small one -- on a
      // 4x4 only about two islands stay on screen. Offer it once the board is
      // large enough to be worth scrolling.
      final pool = <String>[
        'hiddenIslands',
        'timer',
        'fog',
        if (_gridSize >= 7) 'zoom',
      ];
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'bridges',
        levelIndex: _currentLevel,
        pool: pool,
        minActive: 1,
        maxActive: 2,
      );
      if (_forcedModifier != null) {
        _activeModifiers = {_forcedModifier!};
      }

    } else {
      _activeModifiers = {};
      if (_playDailyMode && _dailyModifierType.isNotEmpty) {
        _activeModifiers.add(_dailyModifierType);
      }
    }

    _islands = List.from(level.islands);
    _bridgeCounts.clear();
    _isSuccess = false;
    _gameOver = false;
    _dragStartIsland = -1;
    _selectedIsland = -1;
    _dragPositionNotifier.value = null;
    _isHintShowing = false;
    _hintIdx = -1;

    _hiddenIslands.clear();
    if (_isHiddenIslandsActive) {
      final rng = RotationEngine.getDeterminism('bridges', _currentLevel);
      final List<int> islandIndices = [];
      for (int i = 0; i < _gridSize * _gridSize; i++) {
        if (_islands[i] > 0) {
          islandIndices.add(i);
        }
      }
      double hideRatio = (0.35 + max(0, _currentLevel - 30) * 0.005).clamp(0.35, 0.8);

      final int countToHide = (islandIndices.length * hideRatio).round();
      if (countToHide > 0) {
        islandIndices.shuffle(rng);
        for (int i = 0; i < countToHide; i++) {
          _hiddenIslands.add(islandIndices[i]);
        }
      }
    }

    _gameTimer?.cancel();
    _timeLeft = -1;
    _timeBonusEarned = false;
    if (_isEndgame) {
      _timeLeft = 45 + (_gridSize * 10);
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

  List<List<int>> _getConnections() {
    List<List<int>> conns = [];
    for (int idx = 0; idx < _gridSize * _gridSize; idx++) {
      if (_islands[idx] == 0) continue;
      int r = idx ~/ _gridSize;
      int c = idx % _gridSize;

      // Check Right
      for (int c2 = c + 1; c2 < _gridSize; c2++) {
        int target = r * _gridSize + c2;
        if (_islands[target] > 0) {
          conns.add([idx, target]);
          break;
        }
      }

      // Check Down
      for (int r2 = r + 1; r2 < _gridSize; r2++) {
        int target = r2 * _gridSize + c;
        if (_islands[target] > 0) {
          conns.add([idx, target]);
          break;
        }
      }
    }
    return conns;
  }

  int _getCurrentBridges(int idx) {
    int sum = 0;
    _bridgeCounts.forEach((key, val) {
      final parts = key.split('-');
      int a = int.parse(parts[0]);
      int b = int.parse(parts[1]);
      if (a == idx || b == idx) sum += val;
    });
    return sum;
  }

  bool _toggleBridge(int a, int b) {
    if (!_isAdjacent(a, b)) return false;
    final key = a < b ? '$a-$b' : '$b-$a';
    int current = _bridgeCounts[key] ?? 0;

    if (current == 0 && _wouldCross(a, b)) {
      settingsNotifier.hapticError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bridges cannot cross each other!',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    settingsNotifier.hapticTap();
    setState(() {
      _bridgeCounts[key] = (current + 1) % 3;
    });
    _tryAutoCheck();
    return true;
  }

  void _tryAutoCheck() {
    final totalCells = _gridSize * _gridSize;
    bool allMatched = true;
    for (int i = 0; i < totalCells; i++) {
      if (_islands[i] > 0) {
        if (_getCurrentBridges(i) != _islands[i]) {
          allMatched = false;
          break;
        }
      }
    }
    if (allMatched) {
      _checkSolution();
    }
  }

  bool _isAdjacent(int a, int b) {
    int r1 = a ~/ _gridSize, c1 = a % _gridSize;
    int r2 = b ~/ _gridSize, c2 = b % _gridSize;
    if (r1 != r2 && c1 != c2) return false;

    // Check that there are no intermediate islands
    if (r1 == r2) {
      int minC = min(c1, c2);
      int maxC = max(c1, c2);
      for (int c = minC + 1; c < maxC; c++) {
        if (_islands[r1 * _gridSize + c] > 0) return false;
      }
    } else {
      int minR = min(r1, r2);
      int maxR = max(r1, r2);
      for (int r = minR + 1; r < maxR; r++) {
        if (_islands[r * _gridSize + c1] > 0) return false;
      }
    }
    return true;
  }

  bool _wouldCross(int a, int b) {
    final double screenW = MediaQuery.of(context).size.width;
    final double boardSize = min(screenW - 32, 400.0);
    final double cellSpacing = boardSize / _gridSize;
    final double origin = cellSpacing / 2;

    final p1 = _islandCenter(a, cellSpacing, origin);
    final p2 = _islandCenter(b, cellSpacing, origin);

    for (final entry in _bridgeCounts.entries) {
      if (entry.value <= 0) continue;
      final parts = entry.key.split('-');
      int c = int.parse(parts[0]);
      int d = int.parse(parts[1]);
      if (c == a || c == b || d == a || d == b) continue;

      final p3 = _islandCenter(c, cellSpacing, origin);
      final p4 = _islandCenter(d, cellSpacing, origin);

      if (_segmentsIntersect(p1, p2, p3, p4)) {
        return true;
      }
    }
    return false;
  }

  bool _segmentsIntersect(Offset p1, Offset p2, Offset p3, Offset p4) {
    double d1 = _cross(p3, p4, p1);
    double d2 = _cross(p3, p4, p2);
    double d3 = _cross(p1, p2, p3);
    double d4 = _cross(p1, p2, p4);
    return (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0)));
  }

  double _cross(Offset a, Offset b, Offset c) =>
      (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);

  int _getIslandAt(Offset localPos, double cellSpacing, double origin) {
    return _getIslandAtWithTolerance(localPos, cellSpacing, origin, cellSpacing * 0.45);
  }

  int _getIslandAtWithTolerance(Offset localPos, double cellSpacing, double origin, double tolerance) {
    int best = -1;
    double bestDist = tolerance;
    for (int idx = 0; idx < _gridSize * _gridSize; idx++) {
      if (_islands[idx] == 0) continue;
      double dist = (localPos - _islandCenter(idx, cellSpacing, origin)).distance;
      if (dist < bestDist) {
        bestDist = dist;
        best = idx;
      }
    }
    return best;
  }

  Offset _islandCenter(int idx, double cellSpacing, double origin) {
    final r = idx ~/ _gridSize;
    final c = idx % _gridSize;
    return Offset(origin + c * cellSpacing, origin + r * cellSpacing);
  }

  void _onPanStart(DragStartDetails d, double cellSpacing, double origin) {
    if (_isSuccess) return;
    int idx = _getIslandAt(d.localPosition, cellSpacing, origin);
    if (idx != -1) {
      settingsNotifier.hapticTap();
      setState(() {
        _dragStartIsland = idx;
        _selectedIsland = idx;
        _dragPositionNotifier.value = _islandCenter(idx, cellSpacing, origin);
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails d, double cellSpacing, double origin) {
    if (_isSuccess || _dragStartIsland == -1) return;
    _dragPositionNotifier.value = d.localPosition;
  }

  void _onPanEnd(DragEndDetails d, double cellSpacing, double origin) {
    if (!_isSuccess && _dragStartIsland != -1 && _dragPositionNotifier.value != null) {
      int targetIdx = _getIslandAtWithTolerance(_dragPositionNotifier.value!, cellSpacing, origin, cellSpacing * 0.8);
      if (targetIdx != -1 && targetIdx != _dragStartIsland && _islands[targetIdx] > 0) {
        if (_isAdjacent(_dragStartIsland, targetIdx)) {
          _toggleBridge(_dragStartIsland, targetIdx);
        }
      }
    }
    _dragStartIsland = -1;
    _dragPositionNotifier.value = null;
  }

  void _onTapUp(TapUpDetails d, double cellSpacing, double origin) {
    if (_isSuccess) return;
    int idx = _getIslandAt(d.localPosition, cellSpacing, origin);

    if (_dragStartIsland != -1 && idx != -1 && idx != _dragStartIsland && _islands[idx] > 0) {
      if (_isAdjacent(_dragStartIsland, idx)) {
        _toggleBridge(_dragStartIsland, idx);
      }
      _dragStartIsland = -1;
      _dragPositionNotifier.value = null;
      return;
    }

    if (idx != -1 && _islands[idx] > 0) {
      if (_selectedIsland == -1) {
        setState(() {
          _selectedIsland = idx;
        });
      } else if (_selectedIsland == idx) {
        setState(() {
          _selectedIsland = -1;
        });
      } else {
        if (_isAdjacent(_selectedIsland, idx)) {
          _toggleBridge(_selectedIsland, idx);
        }
        setState(() {
          _selectedIsland = -1;
        });
      }
    } else {
      setState(() {
        _selectedIsland = -1;
      });
    }
  }

  void _checkSolution() {
    bool isValid = true;
    final totalCells = _gridSize * _gridSize;

    // 1. Check bridge sums match clues
    for (int i = 0; i < totalCells; i++) {
      if (_islands[i] > 0) {
        if (_getCurrentBridges(i) != _islands[i]) {
          isValid = false;
          break;
        }
      }
    }

    // 2. Check full connectivity of all islands
    if (isValid) {
      int islandCount = 0;
      int startIsland = -1;
      for (int i = 0; i < totalCells; i++) {
        if (_islands[i] > 0) {
          islandCount++;
          if (startIsland == -1) startIsland = i;
        }
      }

      if (startIsland != -1) {
        List<bool> visited = List.filled(totalCells, false);
        List<int> queue = [startIsland];
        visited[startIsland] = true;
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
        if (visitedCount != islandCount) isValid = false;
      }
    }

    if (isValid) {
      AudioManager.playSuccess();
      settingsNotifier.hapticSuccess();
      _onLevelCleared();
    } else {
      AudioManager.playFail();
      settingsNotifier.hapticError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Keep building! All bridge counts must match exactly and be connected.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onLevelCleared() async {
    _gameTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    if (!_playDailyMode) {
      int highest = prefs.getInt('beta_level_bridges') ?? 0;
      if (_currentLevel + 1 > highest) {
        await prefs.setInt('beta_level_bridges', _currentLevel + 1);
      }
      await HintManager.onLevelCleared(
        'bridges',
        // Speed Demon: cleared a hard-timer level with more than half the
        // clock still left. _initialTime is 0 unless the timer modifier ran.
        isSpeedDemon: _initialTime > 0 && _timeLeft * 2 > _initialTime,
      );
    }
    if (_timeLeft > 0 && _timeBonusEarned) {
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
    if (_playDailyMode) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _currentLevel++;
      _setupLevel();
    });
    final prefs = SharedPreferences.getInstance().then((p) {
      p.setInt(PrefsKeys.gameLevel('bridges'), _currentLevel);
    });
  }



  /// Solves the board.
  ///
  /// When [respectPlayer] is true the bridges already on the board are locked
  /// in and the solver looks for a solution that contains them. That is what
  /// makes a hint safe: if such a solution exists the player is on a valid
  /// line -- possibly a different one from the puzzle's canonical answer -- and
  /// the hint should only add. If none exists, their board genuinely cannot be
  /// completed, and removing an offending bridge is the helpful thing to do.
  Map<String, int>? _solveBridges({bool respectPlayer = false}) {
    final solverIslands = <_SolverIsland>[];
    final islandIdxMap = <int, int>{};
    for (int i = 0; i < _islands.length; i++) {
      if (_islands[i] > 0) {
        islandIdxMap[i] = solverIslands.length;
        solverIslands.add(_SolverIsland(i % _gridSize, i ~/ _gridSize, _islands[i], i));
      }
    }

    final adjList = <List<int>>[];
    final connKeys = <String>[];

    bool canConnect(int i, int j) {
      final a = solverIslands[i];
      final b = solverIslands[j];
      if (a.x != b.x && a.y != b.y) return false;
      if (a.y == b.y) {
        int minX = min(a.x, b.x);
        int maxX = max(a.x, b.x);
        for (int k = 0; k < solverIslands.length; k++) {
          if (k == i || k == j) continue;
          if (solverIslands[k].y == a.y && solverIslands[k].x > minX && solverIslands[k].x < maxX) {
            return false;
          }
        }
      } else {
        int minY = min(a.y, b.y);
        int maxY = max(a.y, b.y);
        for (int k = 0; k < solverIslands.length; k++) {
          if (k == i || k == j) continue;
          if (solverIslands[k].x == a.x && solverIslands[k].y > minY && solverIslands[k].y < maxY) {
            return false;
          }
        }
      }
      return true;
    }

    for (int i = 0; i < solverIslands.length; i++) {
      for (int j = i + 1; j < solverIslands.length; j++) {
        if (canConnect(i, j)) {
          adjList.add([i, j]);
          int u = solverIslands[i].gridIdx;
          int v = solverIslands[j].gridIdx;
          connKeys.add(u < v ? '$u-$v' : '$v-$u');
        }
      }
    }

    bool segmentsIntersect(int x1, int y1, int x2, int y2, int x3, int y3, int x4, int y4) {
      bool isH1 = y1 == y2;
      bool isV1 = x1 == x2;
      bool isH2 = y3 == y4;
      bool isV2 = x3 == x4;
      if (isH1 && isV2) {
        return (min(x1, x2) < x3 && x3 < max(x1, x2)) && (min(y3, y4) < y1 && y1 < max(y3, y4));
      }
      if (isV1 && isH2) {
        return (min(x3, x4) < x1 && x1 < max(x3, x4)) && (min(y1, y2) < y3 && y3 < max(y1, y2));
      }
      return false;
    }

    bool crossesAny(int connIdx, List<int> currentBridges) {
      final a = solverIslands[adjList[connIdx][0]];
      final b = solverIslands[adjList[connIdx][1]];
      for (int i = 0; i < connIdx; i++) {
        if (currentBridges[i] == 0) continue;
        final c = solverIslands[adjList[i][0]];
        final d = solverIslands[adjList[i][1]];
        if (segmentsIntersect(a.x, a.y, b.x, b.y, c.x, c.y, d.x, d.y)) return true;
      }
      return false;
    }

    bool validate(List<int> currentBridges) {
      final degrees = List.filled(solverIslands.length, 0);
      for (int i = 0; i < adjList.length; i++) {
        degrees[adjList[i][0]] += currentBridges[i];
        degrees[adjList[i][1]] += currentBridges[i];
      }
      for (int i = 0; i < solverIslands.length; i++) {
        if (degrees[i] != solverIslands[i].val) return false;
      }
      final visited = List.filled(solverIslands.length, false);
      final queue = [0];
      visited[0] = true;
      int visitedCount = 1;
      while (queue.isNotEmpty) {
        final curr = queue.removeAt(0);
        for (int i = 0; i < adjList.length; i++) {
          if (currentBridges[i] == 0) continue;
          final u = adjList[i][0];
          final v = adjList[i][1];
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
      return visitedCount == solverIslands.length;
    }

    Map<String, int>? solution;
    final currentBridges = List.filled(adjList.length, 0);

    // This search runs synchronously on the UI thread. Without a budget a
    // large board can explore an enormous tree and freeze the app outright,
    // so give up rather than hang -- the caller already handles a null result
    // by telling the player it could not find a hint.
    const int maxSteps = 200000;
    int steps = 0;

    bool solve(int connIdx) {
      if (++steps > maxSteps) return false;
      // Honour what the player has already built: that connection is fixed, so
      // move straight past it instead of exploring other counts for it.
      if (respectPlayer && connIdx < adjList.length) {
        final placed = _bridgeCounts[connKeys[connIdx]] ?? 0;
        if (placed > 0) {
          if (crossesAny(connIdx, currentBridges)) return false;
          currentBridges[connIdx] = placed;
          final ok = solve(connIdx + 1);
          if (ok) return true;
          currentBridges[connIdx] = 0;
          return false;
        }
      }
      if (connIdx == adjList.length) {
        if (validate(currentBridges)) {
          solution = {};
          for (int i = 0; i < adjList.length; i++) {
            if (currentBridges[i] > 0) {
              solution![connKeys[i]] = currentBridges[i];
            }
          }
          return true;
        }
        return false;
      }

      final degrees = List.filled(solverIslands.length, 0);
      final maxRemaining = List.filled(solverIslands.length, 0);
      for (int i = 0; i < adjList.length; i++) {
        final u = adjList[i][0];
        final v = adjList[i][1];
        degrees[u] += currentBridges[i];
        degrees[v] += currentBridges[i];
        if (i >= connIdx) {
          maxRemaining[u] += 2;
          maxRemaining[v] += 2;
        }
      }
      for (int i = 0; i < solverIslands.length; i++) {
        if (degrees[i] > solverIslands[i].val) return false;
        if (degrees[i] + maxRemaining[i] < solverIslands[i].val) return false;
      }

      for (int bridges = 0; bridges <= 2; bridges++) {
        if (bridges > 0 && crossesAny(connIdx, currentBridges)) continue;
        currentBridges[connIdx] = bridges;
        if (solve(connIdx + 1)) return true;
        currentBridges[connIdx] = 0;
      }
      return false;
    }

    solve(0);
    return solution;
  }

  /// Returns true only when the hint actually helped, so the caller knows
  /// whether to spend one.
  bool _showHint() {
    // First ask whether the player's own bridges can still lead somewhere. If
    // they can, extend that line rather than the puzzle's canonical answer --
    // otherwise a player who found a different valid arrangement would have
    // their work torn down.
    var solution = _solveBridges(respectPlayer: true);

    if (solution == null) {
      // No solution contains what they have built, so something on the board is
      // genuinely wrong. Now removing a bridge is the helpful move, and this is
      // the only case where a hint takes something away.
      final canonical = _solveBridges();
      if (canonical == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot find a solution for this board.', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 3),
          ),
        );
        return false;
      }

      String? offending;
      _bridgeCounts.forEach((key, count) {
        if (count > 0 && count > (canonical[key] ?? 0)) offending = key;
      });

      if (offending != null) {
        final u = int.parse(offending!.split('-')[0]);
        setState(() {
          final left = _bridgeCounts[offending!]! - 1;
          if (left == 0) {
            _bridgeCounts.remove(offending);
          } else {
            _bridgeCounts[offending!] = left;
          }
          _hintIdx = u;
          _isHintShowing = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('That bridge cannot be part of any solution - removed it.', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.amber.shade800,
            duration: const Duration(seconds: 2),
          ),
        );
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _isHintShowing = false);
        });
        return true;
      }

      solution = canonical;
    }

    // Find a missing bridge and add it
    String? missingKey;
    solution.forEach((key, solCount) {
      int userCount = _bridgeCounts[key] ?? 0;
      if (userCount < solCount) {
        missingKey = key;
      }
    });

    if (missingKey != null) {
      final parts = missingKey!.split('-');
      int u = int.parse(parts[0]);
      setState(() {
        _bridgeCounts[missingKey!] = (_bridgeCounts[missingKey!] ?? 0) + 1;
        _hintIdx = u;
        _isHintShowing = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Placed a correct bridge!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.dustyMauve,
          duration: const Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isHintShowing = false);
      });
      _tryAutoCheck();
      return true;
    }

    // Every bridge the known solution needs is already there, so the board
    // must also carry extras. Say so rather than doing nothing silently, and
    // do not spend the hint.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Every bridge the solution needs is already placed, but some extras are in the way. Try removing one.',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.amber.shade800,
        duration: const Duration(seconds: 3),
      ),
    );
    return false;
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

    final bool allLevelsCompleted = !_playDailyMode && _currentLevel >= kBridgesLevels.length;

    if (allLevelsCompleted) {
      return Scaffold(
        backgroundColor: context.bgDark,
        appBar: AppBar(
          title: const GameTitle('Bridges'),
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
                  'Congratulations! You have solved all ${kBridgesLevels.length} levels of Bridges. More levels will be added in future updates!',
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
                    await prefs.setInt(PrefsKeys.gameLevel('bridges'), 0);
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
        title: Text('Bridges', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
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
            onPressed: !_isSuccess && !_isHintShowing
                ? () async {
                    if (_hintCount > 0) {
                      // Only spend a hint when it actually placed a bridge.
                      // It used to be charged even when the solver gave up or
                      // there was nothing left to add.
                      if (_showHint()) {
                        setState(() => _hintCount--);
                        await HintManager.useHint('bridges');
                      }
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'bridges',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('bridges');
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
            tooltip: 'Rules',
            icon: const Icon(Icons.help_outline),
            onPressed: () => GameTutorialDialog.show(context, 'bridges', 'Bridges'),
          ),
          GameLevelChip(
            level: _currentLevel + 1,
            modeLabel: _playDailyMode ? 'Daily' : null,
            accent: AppTheme.accentFor('bridges'),
            onTap: kDebugMode ? _showJumpToLevelDialog : null,
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
                            'Connect islands. Drag or tap A then B. Bridges cannot cross.',
                            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.dustyMauve, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        // Bridges announced no modifiers at all, so a board
                        // could arrive fogged, zoomed or with hidden island
                        // numbers and the player had no idea why.
                        if (_modifierBannerText.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            _modifierBannerText,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentFor('bridges').withOpacity(0.9),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (_activeModifiers.contains('zoom')) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ChoiceChip(
                                label: Text('Draw Bridges', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                selected: !_isPanMode,
                                onSelected: (val) => setState(() => _isPanMode = !val),
                                selectedColor: AppTheme.dustyMauve.withOpacity(0.2),
                              ),
                              const SizedBox(width: 12),
                              ChoiceChip(
                                label: Text('Scroll Grid', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                selected: _isPanMode,
                                onSelected: (val) => setState(() => _isPanMode = val),
                                selectedColor: AppTheme.dustyMauve.withOpacity(0.2),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        Builder(
                          builder: (context) {
                            Widget boardWidget = RepaintBoundary(
                              child: Container(
                                width: boardSize,
                                height: boardSize,
                                decoration: BoxDecoration(
                                  color: context.bgCard,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: context.textMuted.withAlpha(30)),
                                ),
                                child: FogOverlay(
                                  enabled: _isFogActive,
                                  radius: cellSpacing * _dailyRadius,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: GestureDetector(
                                      onPanStart: _isPanMode ? null : (d) => _onPanStart(d, cellSpacing, origin),
                                      onPanUpdate: _isPanMode ? null : (d) => _onPanUpdate(d, cellSpacing, origin),
                                      onPanEnd: _isPanMode ? null : (d) => _onPanEnd(d, cellSpacing, origin),
                                      onTapUp: _isPanMode ? null : (d) => _onTapUp(d, cellSpacing, origin),
                                      child: CustomPaint(
                                        size: Size(boardSize, boardSize),
                                        painter: _BridgesPainter(
                                          gridSize: _gridSize,
                                          islands: _islands,
                                          bridgeCounts: _bridgeCounts,
                                          cellSpacing: cellSpacing,
                                          origin: origin,
                                          selectedIsland: _selectedIsland,
                                          dragPosition: _dragPositionNotifier,
                                          dragStartIsland: _dragStartIsland,
                                          hintIdx: _hintIdx,
                                          onGetBridges: _getCurrentBridges,
                                          hiddenIslands: _hiddenIslands,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );

                            if (_activeModifiers.contains('zoom')) {
                              boardWidget = SizedBox(
                                width: boardSize,
                                height: boardSize,
                                child: InteractiveViewer(
                                  panEnabled: _isPanMode,
                                  scaleEnabled: false,
                                  minScale: 1.4,
                                  maxScale: 1.4,
                                  transformationController: _zoomController,
                                  child: boardWidget,
                                ),
                              );
                            }
                            return boardWidget;
                          }
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
                              _bridgeCounts.clear();
                              _selectedIsland = -1;
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
          if (_gameOver)
            Positioned.fill(
              child: LossOverlay(
                onTryAgain: () {
                  setState(() {
                    _gameOver = false;
                    _setupLevel();
                  });
                },
                subtitle: 'You ran out of time!',
                accentColor: AppTheme.dustyMauve,
              ),
            ),
        ],
      ),
    );
  }
}

class _BridgesPainter extends CustomPainter {
  final int gridSize;
  final List<int> islands;
  final Map<String, int> bridgeCounts;
  final double cellSpacing;
  final double origin;
  final int selectedIsland;
  final ValueNotifier<Offset?> dragPosition;
  final int dragStartIsland;
  final int hintIdx;
  final int Function(int) onGetBridges;
  final Set<int> hiddenIslands;

  _BridgesPainter({
    required this.gridSize,
    required this.islands,
    required this.bridgeCounts,
    required this.cellSpacing,
    required this.origin,
    required this.selectedIsland,
    required this.dragPosition,
    required this.dragStartIsland,
    required this.hintIdx,
    required this.onGetBridges,
    required this.hiddenIslands,
  }) : super(repaint: dragPosition);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Bridges (Active connections)
    final Paint bridgePaint = Paint()
      ..color = AppTheme.dustyMauve
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    bridgeCounts.forEach((key, val) {
      if (val > 0) {
        final parts = key.split('-');
        int a = int.parse(parts[0]);
        int b = int.parse(parts[1]);
        Offset p1 = _islandCenter(a);
        Offset p2 = _islandCenter(b);

        double dx = p2.dx - p1.dx;
        double dy = p2.dy - p1.dy;
        double len = sqrt(dx * dx + dy * dy);
        if (len == 0) return;
        
        // Offset normal vector for double bridges
        double nx = -dy / len;
        double ny = dx / len;
        double offsetDist = 4.0;

        if (val == 1) {
          bridgePaint.strokeWidth = 4.0;
          canvas.drawLine(p1, p2, bridgePaint);
        } else if (val == 2) {
          bridgePaint.strokeWidth = 2.5;
          // Draw two parallel bridges
          canvas.drawLine(
            Offset(p1.dx + nx * offsetDist, p1.dy + ny * offsetDist),
            Offset(p2.dx + nx * offsetDist, p2.dy + ny * offsetDist),
            bridgePaint,
          );
          canvas.drawLine(
            Offset(p1.dx - nx * offsetDist, p1.dy - ny * offsetDist),
            Offset(p2.dx - nx * offsetDist, p2.dy - ny * offsetDist),
            bridgePaint,
          );
        }
      }
    });

    // 2. Draw Active Drag Line
    if (dragStartIsland != -1) {
      final curPos = dragPosition.value;
      if (curPos != null) {
        final Paint dragPaint = Paint()
          ..color = AppTheme.dustyMauve.withOpacity(0.5)
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke;
        canvas.drawLine(_islandCenter(dragStartIsland), curPos, dragPaint);
      }
    }

    // 3. Draw Islands
    final Paint islandFillPaint = Paint()
      ..style = PaintingStyle.fill;
    final Paint islandBorderPaint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < gridSize * gridSize; i++) {
      int clue = islands[i];
      if (clue > 0) {
        Offset center = _islandCenter(i);
        double radius = cellSpacing * 0.22;

        // Glowing hint aura
        if (hintIdx == i) {
          final Paint glowPaint = Paint()
            ..color = Colors.amber.withOpacity(0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
          canvas.drawCircle(center, radius * 1.6, glowPaint);
        }

        // Color based on completion state
        int currentBridges = onGetBridges(i);
        bool isFull = currentBridges == clue;
        bool isOver = currentBridges > clue;

        Color bgColor;
        Color borderColor;
        Color textColor;

        if (isOver) {
          bgColor = Colors.red.shade900;
          borderColor = Colors.red.shade300;
          textColor = Colors.white;
        } else if (isFull) {
          bgColor = const Color(0xFF2E7D32); // Deep Green
          borderColor = const Color(0xFF81C784);
          textColor = Colors.white;
        } else {
          bgColor = (selectedIsland == i) ? AppTheme.dustyMauve.withAlpha(200) : const Color(0xFF1E2126);
          borderColor = (selectedIsland == i) ? Colors.white : AppTheme.dustyMauve.withAlpha(120);
          textColor = Colors.white;
        }

        islandFillPaint.color = bgColor;
        islandBorderPaint.color = borderColor;

        canvas.drawCircle(center, radius, islandFillPaint);
        canvas.drawCircle(center, radius, islandBorderPaint);

        // Draw island target number
        final displayClue = hiddenIslands.contains(i) ? '?' : '$clue';
        final tp = TextPainter(
          text: TextSpan(
            text: displayClue,
            style: GoogleFonts.spaceGrotesk(
              fontSize: radius * 1.1,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
      }
    }
  }

  Offset _islandCenter(int idx) {
    final r = idx ~/ gridSize;
    final c = idx % gridSize;
    return Offset(origin + c * cellSpacing, origin + r * cellSpacing);
  }

  @override
  bool shouldRepaint(covariant _BridgesPainter old) =>
      old.gridSize != gridSize ||
      old.islands != islands ||
      old.bridgeCounts != bridgeCounts ||
      old.cellSpacing != cellSpacing ||
      old.origin != origin ||
      old.selectedIsland != selectedIsland ||
      old.dragStartIsland != dragStartIsland ||
      old.hintIdx != hintIdx ||
      old.hiddenIslands != hiddenIslands;
}

class _SolverIsland {
  final int x, y, val, gridIdx;
  _SolverIsland(this.x, this.y, this.val, this.gridIdx);
}
