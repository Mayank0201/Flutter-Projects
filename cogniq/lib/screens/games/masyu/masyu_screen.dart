import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../widgets/game_level_chip.dart';
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
  String? _forcedModifier;

  int _currentLevel = 0;
  bool _isLoading = true;
  bool _isSuccess = false;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  String _dailyModifierName = '';
  String _dailyModifierDesc = '';
  double _dailyRadius = 1.5;
  bool _solveAttempted = false;
  int _hintCount = 1;
  bool _isHintShowing = false;
  int _hintIdx = -1;
  Timer? _gameTimer;

  late int _gridSize;
  late List<int> _grid; // 0: empty, 1: white, 2: black
  Map<String, bool> _activeEdges = {}; // Key: "u-v" (u < v), Value: true/false
  Map<String, bool> _solutionEdges = {}; // Cached correct solution edges for hints
  int _timeLeft = -1;
  // Timer value at the moment the hard timer started; 0 when no timer ran.
  // Only used for the Speed Demon achievement check on clear.
  int _initialTime = 0;

  Set<String> _activeModifiers = {};

  /// Pearls concealed by the 'hiddenPearls' modifier. They still constrain the
  /// loop; they are simply not drawn.
  final Set<int> _hiddenPearls = {};

  // COGNIQ-FIX:mod-active-helper
  bool _isModActive(String name) {
    if (_forcedModifier == name) return true;
    if (_playDailyMode) return _dailyModifierType == name;
    return _currentLevel >= RotationEngine.modifierStartLevel('masyu') &&
        _activeModifiers.contains(name);
  }

  // COGNIQ-FIX:mod-getters
  bool get _isFogActive => _isModActive('fog');
  bool get _isHiddenPearlsActive => _isModActive('hiddenPearls');
  bool get _isZoomActive => _isModActive('zoom');
  bool get _isEndgame => _isModActive('timer');
  bool get _modsOn =>
      !_playDailyMode && RotationEngine.hasModifiers('masyu', _currentLevel);

  // COGNIQ-FIX:mod-deadeffect
  // `zoom` had no implementation at all: `_isZoomActive` was declared and read
  // nowhere, and there was no InteractiveViewer in the file, so the banner
  // promised "Grid is magnified with pan-and-scan navigation" and nothing
  // happened. Implemented here the way Star Battle does it -- a fixed 1.4x
  // InteractiveViewer plus a Draw/Scroll toggle, because the board is drawn
  // with pan gestures and panning cannot share them with drawing.
  bool _isPanMode = false;

  /// Held in state rather than rebuilt inside build(): a fresh controller on
  /// every frame would leak one per rebuild and snap the player's pan position
  /// back to the start whenever the board changed.
  final TransformationController _zoomController =
      TransformationController(Matrix4.identity()..scale(1.4));

  bool _timeBonusEarned = false;

  // Drag loop variables
  int _dragStartCell = -1;
  List<int> _dragPath = [];
  final ValueNotifier<Offset?> _dragPositionNotifier = ValueNotifier<Offset?>(null);

  static const List<MasyuLevel> _kLevels = kMasyuLevels;

  // COGNIQ-FIX:mod-desc-copy
  String _getModifierDescription(String mod) {
    switch (mod) {
      case 'timer':
        return 'Close the loop before time runs out.';
      case 'fog':
        return 'A dense fog obscures portions of the grid.';
      case 'zoom':
        return 'Grid is magnified with pan-and-scan navigation.';
      case 'hiddenPearls':
        return 'Some pearls are concealed on the board.';
      default:
        return '';
    }
  }

  String get _modifierBannerText {
    if (_isSuccess) return '';
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

  @override
  void initState() {
    super.initState();
    _loadProgressAndLevel();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _dragPositionNotifier.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  Future<void> _loadProgressAndLevel() async {
    final prefs = await SharedPreferences.getInstance();
    _hintCount = await HintManager.getHints('masyu');
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
    showDialog(
      context: context,
      builder: (context) {
        int target = _currentLevel + 1;
        String? selectedMod = _forcedModifier;
        final pool = ['timer', 'fog', 'zoom', 'hiddenPearls'];
        
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
                  child: Text('Jump', style: GoogleFonts.outfit(color: AppTheme.dustyMauve)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _setupLevel() {
    HintManager.startLevel('masyu');
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

    // Masyu was the one game with no modifier rotation at all: the board is
    // the same size for fifty levels in a row and nothing else ever changed.
    // It now draws from a pool like every other game.
    if (_modsOn) {
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'masyu',
        levelIndex: _currentLevel,
        pool: ['timer', 'fog', 'zoom', 'hiddenPearls'],
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

    // COGNIQ-FIX:mod-deadeffect
    // A fresh board starts in Draw mode and centred, so a pan left over from
    // the previous level cannot swallow the first stroke on this one.
    _isPanMode = false;
    _zoomController.value = Matrix4.identity()..scale(1.4);

    _hiddenPearls.clear();
    if (_isHiddenPearlsActive) {
      // Conceal a couple of pearls: they still have to be satisfied, the
      // player just has to work out where they are from the loop.
      final pearlCells = <int>[
        for (int i = 0; i < _grid.length; i++)
          if (_grid[i] > 0) i
      ];
      final rng = RotationEngine.getDeterminism('masyu_hidden', _currentLevel);
      pearlCells.shuffle(rng);
      final hideCount = (pearlCells.length * 0.25).round().clamp(1, 3);
      _hiddenPearls.addAll(pearlCells.take(hideCount));
    }

    if (_isEndgame) {
      _timeLeft = 25 + (_gridSize * 8);
      _initialTime = _timeLeft;
      _timeBonusEarned = true;
      _startTimer();
    }
  }

  void _startTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_isSuccess) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _timeLeft = 0;
          _timeBonusEarned = false;
          _gameTimer?.cancel();
        }
      });
    });
  }

  void _ensureSolution() {
    if (_solveAttempted) return;
    _solveAttempted = true;
    _solutionEdges = _solveMasyu() ?? {};
  }

  /// Finds a valid loop.
  ///
  /// When [requiredEdges] is given, only a loop that contains every one of
  /// those edges counts. That is how a hint tells "the player drew a line that
  /// belongs to a different valid loop" apart from "the player drew a line no
  /// loop can use" -- the first deserves to be extended, the second is the only
  /// case where a hint should rub something out.
  Map<String, bool>? _solveMasyu({Set<String>? requiredEdges}) {
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

      if (requiredEdges != null && requiredEdges.isNotEmpty) {
        final loopEdges = <String>{};
        for (int j = 0; j < K; j++) {
          final u = loop[j];
          final v = loop[(j + 1) % K];
          loopEdges.add(u < v ? '$u-$v' : '$v-$u');
        }
        if (!requiredEdges.every(loopEdges.contains)) return false;
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
      if (steps > 50000) return false;
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
    for (int i = 0; i < totalCells; i++) {
      int pearl = _grid[i];
      if (pearl == 0) continue;

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
    
    // Register the clear. Without this the game awards no points, increments no
    // clear count, unlocks no achievement and ticks no trail milestone — a win
    // here was worth literally nothing. It also drives the Zen-vs-Challenge
    // split, so hand-rolled bookkeeping cannot substitute for it.
    if (!_playDailyMode) {
      await HintManager.onLevelCleared(
        'masyu',
        // Speed Demon: cleared a hard-timer level with more than half the
        // clock still left. _initialTime is 0 unless the timer modifier ran.
        isSpeedDemon: _initialTime > 0 && _timeLeft * 2 > _initialTime,
      );
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
    if (_playDailyMode) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _currentLevel++;
      _setupLevel();
    });
    final prefs = SharedPreferences.getInstance().then((p) {
      p.setInt(PrefsKeys.gameLevel('masyu'), _currentLevel);
    });
  }

  bool _showHint() {
    // Prefer a loop that keeps what the player has already drawn. If one
    // exists they are on a valid line -- perhaps not the puzzle's canonical
    // one -- and the hint should build on it rather than tear it down.
    final drawn = <String>{
      for (final e in _activeEdges.entries)
        if (e.value) e.key
    };
    if (drawn.isNotEmpty) {
      final consistent = _solveMasyu(requiredEdges: drawn);
      if (consistent != null && consistent.isNotEmpty) {
        _solutionEdges = consistent;
        _solveAttempted = true;
      }
    }

    _ensureSolution();
    if (_solutionEdges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot find solution. Try clearing some lines!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }

    // A hint never removes the player's own lines. Masyu boards can have more
    // than one valid loop, and this only knows a single stored solution, so
    // erasing "incorrect" lines used to wipe out work that was actually right
    // -- and charged a hint for the privilege. It now only ever adds.

    // Give the next step by placing a correct edge
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
      return true;
    }

    // Nothing left to add, so the board carries lines the solution does not
    // use -- and the search above already showed no valid loop keeps them.
    // Removing one is now the genuinely helpful move.
    String? offending;
    _activeEdges.forEach((key, isActive) {
      if (isActive && !(_solutionEdges[key] ?? false)) offending = key;
    });

    if (offending != null) {
      final u = int.parse(offending!.split('-')[0]);
      setState(() {
        _activeEdges[offending!] = false;
        _hintIdx = u;
        _isHintShowing = true;
      });
      settingsNotifier.hapticTap();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'That line cannot be part of any loop - removed it.',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.amber.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isHintShowing = false);
      });
      return true;
    }

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

    final bool allLevelsCompleted = !_playDailyMode && _currentLevel >= _kLevels.length;

    if (allLevelsCompleted) {
      return Scaffold(
        backgroundColor: context.bgDark,
        appBar: AppBar(
          title: const GameTitle('Pearl Loop'),
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
                      final success = _showHint();
                      if (success) {
                        setState(() => _hintCount--);
                        await HintManager.useHint('masyu');
                      }
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
            tooltip: 'Rules',
            icon: const Icon(Icons.help_outline),
            onPressed: () => GameTutorialDialog.show(context, 'masyu', 'Pearl Loop'),
          ),
          GameLevelChip(
            level: _currentLevel + 1,
            modeLabel: _playDailyMode ? 'Daily' : null,
            accent: AppTheme.accentFor('masyu'),
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
                            'Connect dots. Straight through White. Turn inside Black.',
                            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.dustyMauve, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_modifierBannerText.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Text(
                              _modifierBannerText,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.dustyMauve.withOpacity(0.9),
                              ),
                            ),
                          ),
                        ],
                        // COGNIQ-FIX:mod-deadeffect
                        // Wrap, not Row: the pair is wider than a small phone,
                        // and both chips have to stay tappable for `zoom` to
                        // be playable at all.
                        if (_isZoomActive) ...[
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: Text('Draw Loop', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                selected: !_isPanMode,
                                onSelected: (val) => setState(() => _isPanMode = !val),
                                selectedColor: AppTheme.dustyMauve.withOpacity(0.2),
                              ),
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
                                  // Also honours the campaign 'fog' modifier, not
                                  // just the daily one.
                                  enabled: _isFogActive,
                                  radius: cellSpacing * _dailyRadius,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: GestureDetector(
                                      // COGNIQ-FIX:mod-deadeffect
                                      // In Scroll mode the drag belongs to the
                                      // InteractiveViewer below, so the loop
                                      // handlers step aside.
                                      onPanStart: _isPanMode
                                          ? null
                                          : (d) => _onPanStart(d, cellSpacing, origin, boardSize),
                                      onPanUpdate: _isPanMode
                                          ? null
                                          : (d) => _onPanUpdate(d, cellSpacing, origin, boardSize),
                                      onPanEnd: _isPanMode ? null : _onPanEnd,
                                      child: CustomPaint(
                                        size: Size(boardSize, boardSize),
                                        painter: _MasyuPainter(
                                          hiddenPearls: _hiddenPearls,
                                          gridSize: _gridSize,
                                          grid: _grid,
                                          activeEdges: _activeEdges,
                                          cellSpacing: cellSpacing,
                                          origin: origin,
                                          dragPath: _dragPath,
                                          dragPosition: _dragPositionNotifier,
                                          hintIdx: _hintIdx,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );

                            // COGNIQ-FIX:mod-deadeffect
                            // The magnification `zoom` advertises. Scale is
                            // pinned so the board cannot be zoomed back out to
                            // a size the modifier was meant to deny.
                            if (_isZoomActive) {
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
                          },
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
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.bgCard,
                                foregroundColor: context.textPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                          ],
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

  /// Pearls the 'hiddenPearls' modifier conceals. They still bind the loop;
  /// they are simply not drawn.
  final Set<int> hiddenPearls;

  _MasyuPainter({
    this.hiddenPearls = const {},
    required this.gridSize,
    required this.grid,
    required this.activeEdges,
    required this.cellSpacing,
    required this.origin,
    required this.dragPath,
    required this.dragPosition,
    required this.hintIdx,
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
      if (pearl > 0 && !hiddenPearls.contains(i)) {
        Offset center = _nodeCenter(i);
        double rad = cellSpacing * 0.22;
        
        if (hintIdx == i) {
          final Paint glowPaint = Paint()
            ..color = Colors.amber.withOpacity(0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
          canvas.drawCircle(center, rad * 1.8, glowPaint);
        }

        if (pearl == 1) {
          canvas.drawCircle(center, rad, whitePearlPaint);
          canvas.drawCircle(center, rad, whiteBorderPaint);
        } else if (pearl == 2) {
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
