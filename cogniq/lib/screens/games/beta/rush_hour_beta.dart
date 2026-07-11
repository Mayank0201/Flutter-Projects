import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../widgets/game_tutorial_dialog.dart';
import '../../../utils/ad_manager.dart';
import '../../../utils/audio_manager.dart';
import '../../../widgets/interactive_tutorial_overlay.dart';

class RushHourBetaScreen extends StatefulWidget {
  const RushHourBetaScreen({super.key});
  @override
  State<RushHourBetaScreen> createState() => _RushHourBetaScreenState();
}

class Vehicle {
  final String id;
  int row;
  int col;
  final int len;
  final bool isVertical;
  final Color color;

  Vehicle({
    required this.id,
    required this.row,
    required this.col,
    required this.len,
    required this.isVertical,
    required this.color,
  });

  List<int> getOccupiedCells(int gridSize) {
    List<int> cells = [];
    for (int i = 0; i < len; i++) {
      if (isVertical) {
        cells.add((row + i) * gridSize + col);
      } else {
        cells.add(row * gridSize + (col + i));
      }
    }
    return cells;
  }

  Color getDisplayColor() {
    if (id == 'red') return Colors.redAccent;
    return len == 2 ? Colors.green.shade400 : Colors.blue.shade400;
  }
}

class _RushHourBetaScreenState extends State<RushHourBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  bool _playDailyMode = false;
  List<Vehicle> _vehicles = [];

  // Drag states
  double _dragStartX = 0.0;
  double _dragStartY = 0.0;
  int _vehicleStartRow = 0;
  int _vehicleStartCol = 0;

  int get _gridSize {
    if (_currentLevel < 5) return 4;
    if (_currentLevel < 10) return 5;
    return 6;
  }

  int get _exitRow {
    final size = _gridSize;
    return size ~/ 2 - (size % 2 == 0 ? 1 : 0);
  }

  bool _isTutorialMode = false;
  bool _tutorialCompleted = false;
  int _actualGameLevel = 0;

  @override
  void initState() {
    super.initState();
    _initLevelState();
  }

  Future<void> _initLevelState() async {
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool('play_daily_mode') ?? false;
    final savedLvl = prefs.getInt('level_block_escape') ?? 0;
    
    final tutorialKey = 'has_seen_tutorial_block_escape';
    final hasSeen = prefs.getBool(tutorialKey) ?? false;
    
    if (mounted) {
      setState(() {
        _actualGameLevel = savedLvl;
        if (!hasSeen) {
          _isTutorialMode = true;
          _currentLevel = 0;
        } else {
          _isTutorialMode = false;
          _currentLevel = _playDailyMode ? (savedLvl % 10) : savedLvl;
        }
        _loadLevel();
      });
    }
  }

  Future<void> _finishTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final tutorialKey = 'has_seen_tutorial_block_escape';
    await prefs.setBool(tutorialKey, true);
    setState(() {
      _isTutorialMode = false;
      _currentLevel = _playDailyMode ? (_actualGameLevel % 10) : _actualGameLevel;
      _loadLevel();
    });
  }

  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      
      if (_isTutorialMode) {
        final er = _exitRow;
        _vehicles = [
          Vehicle(id: 'red', row: er, col: 0, len: 2, isVertical: false, color: Colors.redAccent),
          Vehicle(id: 'v1', row: 0, col: 2, len: 2, isVertical: true, color: Colors.green.shade400),
        ];
        return;
      }
      
      _generateProceduralLevel();
    });
  }

  void _generateProceduralLevel() {
    final size = _gridSize;
    final er = _exitRow;
    
    // Seeded Random for consistent levels
    final rng = Random(_currentLevel * 37 + 101);
    
    int minMoves = 2 + (_currentLevel ~/ 2);
    minMoves = minMoves.clamp(2, 12);
    
    List<Vehicle>? bestVehicles;
    int bestMoves = -1;

    int attempts = 0;
    final maxAttempts = _currentLevel < 15 ? 150 : 40;

    while (attempts < maxAttempts) {
      attempts++;
      final List<Vehicle> testVehicles = [
        Vehicle(id: 'red', row: er, col: 0, len: 2, isVertical: false, color: Colors.redAccent),
      ];
      
      int vehicleCount = 2 + (size == 4 ? 2 : (size == 5 ? 4 : 6));
      vehicleCount += rng.nextInt(2);

      for (int i = 0; i < vehicleCount; i++) {
        bool isVert = rng.nextBool();
        int len = rng.nextDouble() > 0.8 ? 3 : 2;
        
        for (int tries = 0; tries < 30; tries++) {
          int r = rng.nextInt(size);
          int c = rng.nextInt(size);
          
          if (isVert) {
            if (r + len > size) continue;
          } else {
            if (c + len > size) continue;
            if (r == er) continue; // Don't block exit row
          }
          
          final temp = Vehicle(id: 'v$i', row: r, col: c, len: len, isVertical: isVert, color: Colors.blue);
          bool overlaps = false;
          
          for (var existing in testVehicles) {
            final occupied1 = existing.getOccupiedCells(size);
            final occupied2 = temp.getOccupiedCells(size);
            if (occupied1.any((cell) => occupied2.contains(cell))) {
              overlaps = true;
              break;
            }
          }
          
          if (!overlaps) {
            testVehicles.add(temp);
            break;
          }
        }
      }
      
      // Solve
      int solutionMoves = _solve(testVehicles, size, er);
      if (solutionMoves >= minMoves) {
        _vehicles = testVehicles;
        return;
      }

      if (solutionMoves > bestMoves) {
        bestMoves = solutionMoves;
        bestVehicles = testVehicles;
      }
    }
    
    // Fallback to the best solvable board generated during attempts
    if (bestVehicles != null && bestMoves > 0) {
      _vehicles = bestVehicles;
      return;
    }

    // Hard fallback static level if no solvable layouts were generated
    _vehicles = [
      Vehicle(id: 'red', row: er, col: 0, len: 2, isVertical: false, color: Colors.redAccent),
      Vehicle(id: 'v0', row: 0, col: 2, len: 2, isVertical: true, color: Colors.green),
      if (size > 4) Vehicle(id: 'v1', row: er + 1, col: 1, len: 2, isVertical: false, color: Colors.blue),
    ];
  }

  int _solve(List<Vehicle> initialVehicles, int size, int exitRow) {
    String stateKey(List<Vehicle> list) {
      return list.map((v) => "${v.row},${v.col}").join(";");
    }

    bool isSolvedState(List<Vehicle> list) {
      final red = list[0]; // Red is always at index 0
      return red.col == size - red.len;
    }

    bool vehiclesOverlap(Vehicle a, Vehicle b) {
      if (a.isVertical && b.isVertical) {
        if (a.col != b.col) return false;
        return a.row < b.row + b.len && b.row < a.row + a.len;
      } else if (!a.isVertical && !b.isVertical) {
        if (a.row != b.row) return false;
        return a.col < b.col + b.len && b.col < a.col + a.len;
      } else {
        final vert = a.isVertical ? a : b;
        final horiz = a.isVertical ? b : a;
        return (vert.col >= horiz.col && vert.col < horiz.col + horiz.len) &&
               (horiz.row >= vert.row && horiz.row < vert.row + vert.len);
      }
    }

    final startKey = stateKey(initialVehicles);
    final Set<String> visited = {startKey};
    final List<(List<Vehicle>, int)> queue = [(initialVehicles, 0)];

    int maxBfsAttempts = 3000; 
    int bfsTries = 0;
    int head = 0;

    while (head < queue.length && bfsTries < maxBfsAttempts) {
      bfsTries++;
      final (current, moves) = queue[head++];

      if (isSolvedState(current)) {
        return moves;
      }

      for (int i = 0; i < current.length; i++) {
        final v = current[i];
        
        final directions = [-1, 1];
        for (int step in directions) {
          int k = 1;
          while (true) {
            int newRow = v.isVertical ? v.row + step * k : v.row;
            int newCol = v.isVertical ? v.col : v.col + step * k;

            if (newRow < 0 || newRow + (v.isVertical ? v.len : 1) > size ||
                newCol < 0 || newCol + (v.isVertical ? 1 : v.len) > size) {
              break;
            }

            final nextVehicles = List<Vehicle>.generate(current.length, (idx) {
              final x = current[idx];
              if (idx == i) {
                return Vehicle(id: x.id, row: newRow, col: newCol, len: x.len, isVertical: x.isVertical, color: x.color);
              }
              return x; // Reuse existing reference
            });

            bool overlaps = false;
            final activeVehicle = nextVehicles[i];

            for (int j = 0; j < nextVehicles.length; j++) {
              if (i == j) continue;
              if (vehiclesOverlap(activeVehicle, nextVehicles[j])) {
                overlaps = true;
                break;
              }
            }

            if (overlaps) {
              break; 
            }

            final nKey = stateKey(nextVehicles);
            if (!visited.contains(nKey)) {
              visited.add(nKey);
              queue.add((nextVehicles, moves + 1));
            }
            k++;
          }
        }
      }
    }
    return -1; // Unsolvable in BFS limits
  }

  void _onDragStart(DragStartDetails details, Vehicle v) {
    if (_isSuccess) return;
    _dragStartX = details.globalPosition.dx;
    _dragStartY = details.globalPosition.dy;
    _vehicleStartRow = v.row;
    _vehicleStartCol = v.col;
  }

  void _onDragUpdate(DragUpdateDetails details, Vehicle v, double cs) {
    if (_isSuccess) return;
    final size = _gridSize;

    double dx = details.globalPosition.dx - _dragStartX;
    double dy = details.globalPosition.dy - _dragStartY;

    if (v.isVertical) {
      int cellDiff = (dy / cs).round();
      int targetRow = (_vehicleStartRow + cellDiff).clamp(0, size - v.len);
      if (targetRow != v.row && _isMoveValid(v, targetRow, v.col)) {
        settingsNotifier.hapticTap();
        setState(() {
          v.row = targetRow;
        });
      }
    } else {
      int cellDiff = (dx / cs).round();
      int maxCol = (v.id == 'red') ? size - v.len : size - v.len;
      int targetCol = (_vehicleStartCol + cellDiff).clamp(0, maxCol);
      if (targetCol != v.col && _isMoveValid(v, v.row, targetCol)) {
        settingsNotifier.hapticTap();
        setState(() {
          v.col = targetCol;
        });
      }
    }
  }

  bool _isMoveValid(Vehicle v, int tr, int tc) {
    final size = _gridSize;
    final temp = Vehicle(id: v.id, row: tr, col: tc, len: v.len, isVertical: v.isVertical, color: v.color);
    final occupied = temp.getOccupiedCells(size);

    for (var other in _vehicles) {
      if (other.id == v.id) continue;
      final otherOccupied = other.getOccupiedCells(size);
      if (occupied.any((cell) => otherOccupied.contains(cell))) {
        return false;
      }
    }
    return true;
  }

  void _onDragEnd(Vehicle v) {
    final size = _gridSize;

    setState(() {
      if (v.id == 'red' && v.col == size - v.len) {
        // Red block reached exit! Slide completely out of board
        AudioManager.playClick();
        if (_isTutorialMode) {
          if (!_tutorialCompleted) {
            AudioManager.playSuccess();
            settingsNotifier.hapticSuccess();
            setState(() {
              _tutorialCompleted = true;
            });
          }
        } else {
          _isSuccess = true;
          _onLevelCleared();
        }
      }
    });
  }

  Future<void> _onLevelCleared() async {
    AudioManager.playSuccess();
    settingsNotifier.hapticSuccess();

    final prefs = await SharedPreferences.getInstance();
    final key = 'level_block_escape';
    int highest = prefs.getInt(key) ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt(key, _currentLevel + 1);
    }

    int newLevel = _currentLevel + 1;
    if (newLevel == 15 || newLevel == 30 || newLevel == 40 || newLevel == 50) {
      AdManager.showInterstitialAd();
    }

    setState(() => _isSuccess = true);
  }

  void _nextLevel() {
    setState(() {
      _currentLevel++;
      _loadLevel();
    });
  }

  void _showHint() {
    settingsNotifier.hapticTap();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Hint: Move the long vertical blocks first to unlock the horizontal ones!'),
    ));
  }

  void _showRules() {
    settingsNotifier.hapticTap();
    GameTutorialDialog.show(context, 'block_escape', 'Block Escape');
  }

  @override
  Widget build(BuildContext context) {
    final size = _gridSize;
    final er = _exitRow;
    
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Block Escape', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppTheme.dustyMauve),
            tooltip: 'Rules',
            onPressed: _showRules,
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
                _isTutorialMode ? 'Tutorial' : 'Level ${_currentLevel + 1}', 
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
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 36),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Slide blocks out of the way. Slide the RED block to the right exit.', 
                          style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary), 
                          textAlign: TextAlign.center
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RepaintBoundary(
                              child: Container(
                                width: 240, height: 240,
                                decoration: BoxDecoration(
                                  color: context.bgCard, 
                                  borderRadius: BorderRadius.circular(16), 
                                  border: Border.all(color: context.textMuted.withAlpha(40)),
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    double cs = constraints.maxWidth / size;
                                    return Stack(
                                      children: [
                                        for (int i = 1; i < size; i++) ...[
                                          Positioned(left: i * cs, top: 0, bottom: 0, child: Container(width: 1, color: Colors.grey.shade900.withOpacity(0.3))),
                                          Positioned(top: i * cs, left: 0, right: 0, child: Container(height: 1, color: Colors.grey.shade900.withOpacity(0.3))),
                                        ],
                                        for (var v in _vehicles)
                                          Positioned(
                                            left: v.col * cs,
                                            top: v.row * cs,
                                            width: v.isVertical ? cs : cs * v.len,
                                            height: v.isVertical ? cs * v.len : cs,
                                            child: GestureDetector(
                                              onPanStart: (d) => _onDragStart(d, v),
                                              onPanUpdate: (d) => _onDragUpdate(d, v, cs),
                                              onPanEnd: (_) => _onDragEnd(v),
                                              child: Container(
                                                margin: const EdgeInsets.all(3),
                                                decoration: BoxDecoration(
                                                  color: v.getDisplayColor(),
                                                  borderRadius: BorderRadius.circular(12),
                                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  }
                                ),
                              ),
                            ),
                            Container(
                              width: 30, height: 240,
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  SizedBox(height: er * (240 / size) + (240 / size - 24) / 2),
                                  const Icon(Icons.arrow_forward, color: Colors.green, size: 24),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
                if (!_isSuccess)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.bgCard,
                          foregroundColor: context.textPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: context.textMuted.withAlpha(40)),
                          ),
                        ),
                        onPressed: _loadLevel,
                        icon: const Icon(Icons.refresh),
                        label: Text('Reset Board', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                if (_isSuccess && !_playDailyMode && !_isTutorialMode)
                  AutoNextCountdown(
                    onNext: _nextLevel,
                    accentColor: AppTheme.dustyMauve,
                  ),
              ],
            ),
          ),
          if (_isSuccess && _playDailyMode)
            Positioned.fill(
              child: ChallengeClearedOverlay(
                accentColor: AppTheme.dustyMauve,
                onComplete: () {
                  Navigator.pop(context, true);
                },
              ),
            ),
          if (_isTutorialMode)
            InteractiveTutorialOverlay(
              instruction: _tutorialCompleted
                  ? "Nice! You successfully escaped the red block from the grid."
                  : "Slide the green blocking obstacle down, then slide the RED block to the right exit slot!",
              isCompleted: _tutorialCompleted,
              onSkip: _finishTutorial,
              onStartGame: _finishTutorial,
            ),
        ],
      ),
    );
  }
}
