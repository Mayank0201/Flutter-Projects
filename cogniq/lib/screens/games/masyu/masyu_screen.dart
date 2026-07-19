import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
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
import '../../../widgets/game_tutorial_dialog.dart';

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
  int _hintCount = 1;
  bool _isHintShowing = false;
  int _hintIdx = -1;

  // Drag loop variables
  int _dragStartCell = -1;
  List<int> _dragPath = [];
  final ValueNotifier<Offset?> _dragPositionNotifier = ValueNotifier<Offset?>(null);

  static const List<MasyuLevel> _kLevels = [
    // Easy (4x4)
    MasyuLevel(
      gridSize: 4,
      pearls: [
        0, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 2, 0,
        0, 0, 0, 0,
      ],
    ),
    MasyuLevel(
      gridSize: 4,
      pearls: [
        0, 0, 0, 0,
        0, 0, 1, 0,
        0, 2, 0, 0,
        0, 0, 0, 0,
      ],
    ),
    MasyuLevel(
      gridSize: 4,
      pearls: [
        0, 2, 0, 0,
        0, 0, 0, 1,
        0, 0, 0, 0,
        0, 0, 0, 0,
      ],
    ),
    MasyuLevel(
      gridSize: 4,
      pearls: [
        0, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 0, 2,
        0, 0, 0, 0,
      ],
    ),
    MasyuLevel(
      gridSize: 4,
      pearls: [
        0, 1, 0, 0,
        0, 0, 0, 0,
        0, 0, 2, 0,
        0, 0, 0, 0,
      ],
    ),
    // Medium (5x5)
    MasyuLevel(
      gridSize: 5,
      pearls: [
        0, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 2, 0, 2,
        0, 0, 0, 1, 0,
        0, 0, 0, 0, 0,
      ],
    ),
    MasyuLevel(
      gridSize: 5,
      pearls: [
        0, 0, 1, 0, 0,
        0, 0, 0, 0, 0,
        0, 2, 0, 2, 0,
        0, 0, 0, 0, 0,
        0, 0, 1, 0, 0,
      ],
    ),
    MasyuLevel(
      gridSize: 5,
      pearls: [
        0, 0, 0, 0, 2,
        0, 0, 0, 0, 0,
        0, 1, 0, 1, 0,
        0, 0, 0, 0, 0,
        2, 0, 0, 0, 0,
      ],
    ),
    MasyuLevel(
      gridSize: 5,
      pearls: [
        1, 0, 0, 0, 1,
        0, 0, 0, 0, 0,
        0, 2, 0, 2, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
      ],
    ),
    MasyuLevel(
      gridSize: 5,
      pearls: [
        0, 0, 0, 0, 0,
        0, 1, 0, 1, 0,
        0, 0, 2, 0, 0,
        0, 1, 0, 1, 0,
        0, 0, 0, 0, 0,
      ],
    ),
    // Hard (6x6)
    MasyuLevel(
      gridSize: 6,
      pearls: [
        0, 0, 0, 0, 0, 0,
        0, 1, 0, 0, 0, 0,
        0, 0, 2, 0, 2, 0,
        0, 0, 0, 1, 0, 0,
        0, 2, 0, 0, 1, 0,
        0, 0, 0, 0, 0, 0,
      ],
    ),
    MasyuLevel(
      gridSize: 6,
      pearls: [
        0, 1, 0, 0, 1, 0,
        0, 0, 0, 0, 0, 0,
        0, 0, 2, 2, 0, 0,
        0, 0, 0, 0, 0, 0,
        0, 1, 0, 0, 2, 0,
        0, 0, 0, 0, 0, 0,
      ],
    ),
    MasyuLevel(
      gridSize: 6,
      pearls: [
        0, 2, 0, 0, 2, 0,
        0, 0, 1, 1, 0, 0,
        0, 0, 0, 0, 0, 0,
        0, 0, 2, 2, 0, 0,
        0, 1, 0, 0, 1, 0,
        0, 0, 0, 0, 0, 0,
      ],
    ),
    MasyuLevel(
      gridSize: 6,
      pearls: [
        1, 0, 0, 0, 0, 1,
        0, 0, 2, 2, 0, 0,
        0, 1, 0, 0, 1, 0,
        0, 0, 2, 2, 0, 0,
        1, 0, 0, 0, 0, 1,
        0, 0, 0, 0, 0, 0,
      ],
    ),
    MasyuLevel(
      gridSize: 6,
      pearls: [
        0, 0, 1, 1, 0, 0,
        0, 2, 0, 0, 2, 0,
        1, 0, 0, 0, 0, 1,
        1, 0, 0, 0, 0, 1,
        0, 2, 0, 0, 2, 0,
        0, 0, 1, 1, 0, 0,
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadProgressAndLevel();
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

  void _setupLevel() {
    final level = _kLevels[_currentLevel % _kLevels.length];
    _gridSize = level.gridSize;
    _grid = List.from(level.pearls);
    _activeEdges.clear();
    _isSuccess = false;
    _dragStartCell = -1;
    _dragPath.clear();
    _dragPositionNotifier.value = null;
    _isHintShowing = false;
    _hintIdx = -1;
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
  }

  void _checkSolution() {
    bool isValid = true;
    final totalCells = _gridSize * _gridSize;
    List<int> degree = List.filled(totalCells, 0);
    final edges = _getEdges();

    for (int i = 0; i < edges.length; i++) {
      int u = edges[i][0];
      int v = edges[i][1];
      if (_hasEdge(u, v)) {
        degree[u]++;
        degree[v]++;
      }
    }

    int loopCellsCount = 0;
    int startCell = -1;
    for (int i = 0; i < totalCells; i++) {
      if (degree[i] == 2) {
        loopCellsCount++;
        if (startCell == -1) startCell = i;
      } else if (degree[i] != 0) {
        isValid = false;
      }
    }

    if (loopCellsCount < 4) isValid = false;

    // Single loop check (BFS/DFS connectivity)
    if (isValid && startCell != -1) {
      List<bool> visited = List.filled(totalCells, false);
      List<int> queue = [startCell];
      visited[startCell] = true;
      int visitedCount = 1;
      while (queue.isNotEmpty) {
        int curr = queue.removeAt(0);
        for (int i = 0; i < edges.length; i++) {
          int u = edges[i][0];
          int v = edges[i][1];
          if (_hasEdge(u, v)) {
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
      }
      if (visitedCount != loopCellsCount) isValid = false;
    }

    // Pearls verification
    if (isValid) {
      for (int i = 0; i < totalCells; i++) {
        int pearl = _grid[i];
        if (pearl > 0) {
          if (degree[i] != 2) {
            isValid = false;
            break;
          }

          List<int> neighbors = [];
          int ri = i ~/ _gridSize; int ci = i % _gridSize;
          if (ri > 0 && _hasEdge(i, (ri - 1) * _gridSize + ci)) neighbors.add((ri - 1) * _gridSize + ci);
          if (ri < _gridSize - 1 && _hasEdge(i, (ri + 1) * _gridSize + ci)) neighbors.add((ri + 1) * _gridSize + ci);
          if (ci > 0 && _hasEdge(i, i - 1)) neighbors.add(i - 1);
          if (ci < _gridSize - 1 && _hasEdge(i, i + 1)) neighbors.add(i + 1);

          if (neighbors.length != 2) {
            isValid = false;
            break;
          }

          int n1 = neighbors[0];
          int n2 = neighbors[1];
          int r1 = n1 ~/ _gridSize, c1 = n1 % _gridSize;
          int r2 = n2 ~/ _gridSize, c2 = n2 % _gridSize;
          bool isStraight = (r1 == r2) || (c1 == c2);

          if (pearl == 1) {
            // White pearl: must go straight
            if (!isStraight) {
              isValid = false;
              break;
            }
            
            // At least one neighbor must make a 90-degree turn
            bool n1Turns = false;
            int rn1 = n1 ~/ _gridSize, cn1 = n1 % _gridSize;
            List<int> n1Neighbors = [];
            if (rn1 > 0 && _hasEdge(n1, (rn1 - 1) * _gridSize + cn1)) n1Neighbors.add((rn1 - 1) * _gridSize + cn1);
            if (rn1 < _gridSize - 1 && _hasEdge(n1, (rn1 + 1) * _gridSize + cn1)) n1Neighbors.add((rn1 + 1) * _gridSize + cn1);
            if (cn1 > 0 && _hasEdge(n1, n1 - 1)) n1Neighbors.add(n1 - 1);
            if (cn1 < _gridSize - 1 && _hasEdge(n1, n1 + 1)) n1Neighbors.add(n1 + 1);
            if (n1Neighbors.length == 2) {
              int rn1_1 = n1Neighbors[0] ~/ _gridSize, cn1_1 = n1Neighbors[0] % _gridSize;
              int rn1_2 = n1Neighbors[1] ~/ _gridSize, cn1_2 = n1Neighbors[1] % _gridSize;
              n1Turns = (rn1_1 != rn1_2) && (cn1_1 != cn1_2);
            }

            bool n2Turns = false;
            int rn2 = n2 ~/ _gridSize, cn2 = n2 % _gridSize;
            List<int> n2Neighbors = [];
            if (rn2 > 0 && _hasEdge(rn2 * _gridSize + cn2, (rn2 - 1) * _gridSize + cn2)) n2Neighbors.add((rn2 - 1) * _gridSize + cn2);
            if (rn2 < _gridSize - 1 && _hasEdge(rn2 * _gridSize + cn2, (rn2 + 1) * _gridSize + cn2)) n2Neighbors.add((rn2 + 1) * _gridSize + cn2);
            if (cn2 > 0 && _hasEdge(rn2 * _gridSize + cn2, rn2 * _gridSize + cn2 - 1)) n2Neighbors.add(rn2 * _gridSize + cn2 - 1);
            if (cn2 < _gridSize - 1 && _hasEdge(rn2 * _gridSize + cn2, rn2 * _gridSize + cn2 + 1)) n2Neighbors.add(rn2 * _gridSize + cn2 + 1);
            if (n2Neighbors.length == 2) {
              int rn2_1 = n2Neighbors[0] ~/ _gridSize, cn2_1 = n2Neighbors[0] % _gridSize;
              int rn2_2 = n2Neighbors[1] ~/ _gridSize, cn2_2 = n2Neighbors[1] % _gridSize;
              n2Turns = (rn2_1 != rn2_2) && (cn2_1 != cn2_2);
            }

            if (!n1Turns && !n2Turns) {
              isValid = false;
              break;
            }
          } else if (pearl == 2) {
            // Black pearl: must make 90-degree turn
            if (isStraight) {
              isValid = false;
              break;
            }

            // Both outgoing paths must continue straight for at least 1 cell
            bool n1Straight = false;
            int rn1 = n1 ~/ _gridSize, cn1 = n1 % _gridSize;
            List<int> n1Neighbors = [];
            if (rn1 > 0 && _hasEdge(n1, (rn1 - 1) * _gridSize + cn1)) n1Neighbors.add((rn1 - 1) * _gridSize + cn1);
            if (rn1 < _gridSize - 1 && _hasEdge(n1, (rn1 + 1) * _gridSize + cn1)) n1Neighbors.add((rn1 + 1) * _gridSize + cn1);
            if (cn1 > 0 && _hasEdge(n1, n1 - 1)) n1Neighbors.add(n1 - 1);
            if (cn1 < _gridSize - 1 && _hasEdge(n1, n1 + 1)) n1Neighbors.add(n1 + 1);
            if (n1Neighbors.length == 2) {
              int rn1_1 = n1Neighbors[0] ~/ _gridSize, cn1_1 = n1Neighbors[0] % _gridSize;
              int rn1_2 = n1Neighbors[1] ~/ _gridSize, cn1_2 = n1Neighbors[1] % _gridSize;
              n1Straight = (rn1_1 == rn1_2) || (cn1_1 == cn1_2);
            }

            bool n2Straight = false;
            int rn2 = n2 ~/ _gridSize, cn2 = n2 % _gridSize;
            List<int> n2Neighbors = [];
            if (rn2 > 0 && _hasEdge(rn2 * _gridSize + cn2, (rn2 - 1) * _gridSize + cn2)) n2Neighbors.add((rn2 - 1) * _gridSize + cn2);
            if (rn2 < _gridSize - 1 && _hasEdge(rn2 * _gridSize + cn2, (rn2 + 1) * _gridSize + cn2)) n2Neighbors.add((rn2 + 1) * _gridSize + cn2);
            if (cn2 > 0 && _hasEdge(rn2 * _gridSize + cn2, rn2 * _gridSize + cn2 - 1)) n2Neighbors.add(rn2 * _gridSize + cn2 - 1);
            if (cn2 < _gridSize - 1 && _hasEdge(rn2 * _gridSize + cn2, rn2 * _gridSize + cn2 + 1)) n2Neighbors.add(rn2 * _gridSize + cn2 + 1);
            if (n2Neighbors.length == 2) {
              int rn2_1 = n2Neighbors[0] ~/ _gridSize, cn2_1 = n2Neighbors[0] % _gridSize;
              int rn2_2 = n2Neighbors[1] ~/ _gridSize, cn2_2 = n2Neighbors[1] % _gridSize;
              n2Straight = (rn2_1 == rn2_2) || (cn2_1 == cn2_2);
            }

            if (!n1Straight || !n2Straight) {
              isValid = false;
              break;
            }
          }
        }
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
            'Invalid loop. Check all pearl rules!',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    if (!_playDailyMode) {
      int highest = prefs.getInt('beta_level_masyu') ?? 0;
      if (_currentLevel + 1 > highest) {
        await prefs.setInt('beta_level_masyu', _currentLevel + 1);
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
    for (int i = 0; i < _grid.length; i++) {
      if (_grid[i] > 0 && _hintIdx == -1) {
        setState(() {
          _hintIdx = i;
          _isHintShowing = true;
        });
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _isHintShowing = false;
              _hintIdx = -1;
            });
          }
        });
        break;
      }
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

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Masyu', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => GameTutorialDialog.show(context, 'masyu', 'Masyu'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: Center(
              child: Text(
                _playDailyMode ? 'Challenge' : 'Level ${_currentLevel + 1}',
                style: GoogleFonts.outfit(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold, fontSize: 14),
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
                          _activeEdges.clear();
                          _dragPath.clear();
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

  _MasyuPainter({
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
      ..color = Colors.grey.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        canvas.drawCircle(Offset(origin + c * cellSpacing, origin + r * cellSpacing), 3, dotPaint);
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
  bool shouldRepaint(covariant _MasyuPainter old) =>
      old.gridSize != gridSize ||
      old.grid != grid ||
      old.activeEdges != activeEdges ||
      old.cellSpacing != cellSpacing ||
      old.origin != origin ||
      old.dragPath != dragPath ||
      old.hintIdx != hintIdx;
}
