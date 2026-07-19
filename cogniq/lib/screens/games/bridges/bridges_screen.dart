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
  int _currentLevel = 0;
  bool _isLoading = true;
  bool _isSuccess = false;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  double _dailyRadius = 1.5;

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

  static const List<BridgesLevel> _kLevels = [
    // Easy (3x3)
    BridgesLevel(
      gridSize: 3,
      islands: [
        0, 0, 0,
        0, 2, 1,
        1, 2, 0,
      ],
    ),
    BridgesLevel(
      gridSize: 3,
      islands: [
        0, 0, 0,
        0, 1, 0,
        1, 3, 1,
      ],
    ),
    BridgesLevel(
      gridSize: 3,
      islands: [
        2, 2, 0,
        2, 4, 2,
        0, 2, 2,
      ],
    ),
    BridgesLevel(
      gridSize: 3,
      islands: [
        0, 0, 0,
        0, 1, 2,
        1, 0, 2,
      ],
    ),
    BridgesLevel(
      gridSize: 3,
      islands: [
        0, 0, 0,
        0, 1, 1,
        0, 2, 2,
      ],
    ),
    // Medium (4x4)
    BridgesLevel(
      gridSize: 4,
      islands: [
        2, 0, 3, 2,
        0, 0, 0, 0,
        2, 0, 4, 2,
        2, 0, 3, 2,
      ],
    ),
    BridgesLevel(
      gridSize: 4,
      islands: [
        1, 2, 0, 2,
        0, 2, 0, 0,
        2, 0, 3, 1,
        1, 2, 0, 2,
      ],
    ),
    BridgesLevel(
      gridSize: 4,
      islands: [
        2, 2, 2, 2,
        2, 0, 0, 2,
        0, 0, 0, 0,
        2, 2, 2, 2,
      ],
    ),
    BridgesLevel(
      gridSize: 4,
      islands: [
        3, 3, 0, 2,
        0, 0, 0, 0,
        0, 0, 0, 0,
        3, 3, 0, 2,
      ],
    ),
    BridgesLevel(
      gridSize: 4,
      islands: [
        2, 0, 2, 2,
        0, 0, 0, 0,
        2, 0, 2, 2,
        2, 0, 2, 2,
      ],
    ),
    // Hard (5x5)
    BridgesLevel(
      gridSize: 5,
      islands: [
        2, 3, 0, 3, 2,
        0, 0, 0, 0, 0,
        3, 0, 4, 0, 3,
        0, 0, 0, 0, 0,
        2, 3, 0, 3, 2,
      ],
    ),
    BridgesLevel(
      gridSize: 5,
      islands: [
        3, 0, 4, 0, 3,
        0, 0, 0, 0, 0,
        4, 0, 6, 0, 4,
        0, 0, 0, 0, 0,
        3, 0, 4, 0, 3,
      ],
    ),
    BridgesLevel(
      gridSize: 5,
      islands: [
        2, 0, 2, 0, 2,
        0, 0, 0, 0, 0,
        2, 0, 4, 0, 2,
        0, 0, 0, 0, 0,
        2, 0, 2, 0, 2,
      ],
    ),
    BridgesLevel(
      gridSize: 5,
      islands: [
        1, 2, 0, 2, 1,
        2, 0, 0, 0, 2,
        0, 0, 4, 0, 0,
        2, 0, 0, 0, 2,
        1, 2, 0, 2, 1,
      ],
    ),
    BridgesLevel(
      gridSize: 5,
      islands: [
        2, 2, 2, 2, 2,
        2, 0, 0, 0, 2,
        2, 0, 4, 0, 2,
        2, 0, 0, 0, 2,
        2, 2, 2, 2, 2,
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
    _hintCount = await HintManager.getHints('bridges');
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

    int level = prefs.getInt(PrefsKeys.gameLevel('bridges')) ?? 0;
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
    _islands = List.from(level.islands);
    _bridgeCounts.clear();
    _isSuccess = false;
    _dragStartIsland = -1;
    _selectedIsland = -1;
    _dragPositionNotifier.value = null;
    _isHintShowing = false;
    _hintIdx = -1;
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
    return true;
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
    int best = -1;
    double bestDist = cellSpacing * 0.45;
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

    int idx = _getIslandAt(d.localPosition, cellSpacing, origin);
    if (idx != -1 && idx != _dragStartIsland) {
      if (_toggleBridge(_dragStartIsland, idx)) {
        setState(() {
          _dragStartIsland = -1;
          _selectedIsland = -1;
          _dragPositionNotifier.value = null;
        });
      }
    }
  }

  void _onPanEnd(DragEndDetails d) {
    _dragStartIsland = -1;
    _dragPositionNotifier.value = null;
  }

  void _onTapUp(TapUpDetails d, double cellSpacing, double origin) {
    if (_isSuccess) return;
    int idx = _getIslandAt(d.localPosition, cellSpacing, origin);
    if (idx != -1) {
      if (_selectedIsland == -1) {
        settingsNotifier.hapticTap();
        setState(() {
          _selectedIsland = idx;
        });
      } else if (_selectedIsland == idx) {
        setState(() {
          _selectedIsland = -1;
        });
      } else {
        if (_toggleBridge(_selectedIsland, idx)) {
          setState(() {
            _selectedIsland = -1;
          });
        } else {
          setState(() {
            _selectedIsland = idx;
          });
        }
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
    final prefs = await SharedPreferences.getInstance();
    if (!_playDailyMode) {
      int highest = prefs.getInt('beta_level_bridges') ?? 0;
      if (_currentLevel + 1 > highest) {
        await prefs.setInt('beta_level_bridges', _currentLevel + 1);
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
      p.setInt(PrefsKeys.gameLevel('bridges'), _currentLevel);
    });
  }

  void _showHint() {
    for (int i = 0; i < _islands.length; i++) {
      if (_islands[i] > 0 && _getCurrentBridges(i) != _islands[i]) {
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
        title: Text('Bridges', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                      HintManager.useHint('bridges');
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
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => GameTutorialDialog.show(context, 'bridges', 'Bridges'),
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
                            'Connect islands. Drag or tap A then B. Bridges cannot cross.',
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
                                  onPanStart: (d) => _onPanStart(d, cellSpacing, origin),
                                  onPanUpdate: (d) => _onPanUpdate(d, cellSpacing, origin),
                                  onPanEnd: _onPanEnd,
                                  onTapUp: (d) => _onTapUp(d, cellSpacing, origin),
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
                          _bridgeCounts.clear();
                          _selectedIsland = -1;
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
        final tp = TextPainter(
          text: TextSpan(
            text: '$clue',
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
      old.hintIdx != hintIdx;
}
