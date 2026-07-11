import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../widgets/game_tutorial_dialog.dart';
import '../../../utils/audio_manager.dart';
import '../../../utils/hint_manager.dart';
import '../../../widgets/interactive_tutorial_overlay.dart';
import '../../../widgets/swipe_trail_overlay.dart';
import '../../../widgets/buy_hints_dialog.dart';
import '../../../utils/shuffle_manager.dart';
import '../../../utils/achievement_manager.dart';
import '../../../widgets/achievement_toast.dart';

class NumberlinkBetaScreen extends StatefulWidget {
  const NumberlinkBetaScreen({super.key});
  @override
  State<NumberlinkBetaScreen> createState() => _NumberlinkBetaScreenState();
}

class _NumberlinkBetaScreenState extends State<NumberlinkBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  bool _playDailyMode = false;

  int _gridSize = 4;
  int _numColors = 2;
  List<int> _grid = []; // 0 = empty, 1..C = endpoints
  List<List<int>> _paths = []; // User paths for each color 1..C
  List<List<int>> _solutionPaths = [];
  int _hintCount = 0;
  int _dragColor = 0; // 0 = none, 1..C = active dragging color
  bool _shuffleActive = false;

  final List<Color> _colors = [
    Colors.red.shade500,       // Red
    Colors.blue.shade500,      // Blue
    Colors.green.shade500,     // Green
    Colors.orange.shade500,    // Orange
    Colors.purple.shade500,    // Purple
    Colors.pink.shade400,      // Pink
    Colors.teal.shade400,      // Teal
    Colors.amber.shade700,     // Amber/Yellow
  ];

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
    final savedLvl = prefs.getInt('level_colour_link') ?? 0;
    final hCount = await HintManager.getHints('colour_link');
    
    final tutorialKey = 'has_seen_tutorial_colour_link';
    final hasSeen = prefs.getBool(tutorialKey) ?? false;
    
    if (mounted) {
      setState(() {
        _hintCount = hCount;
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
    final tutorialKey = 'has_seen_tutorial_colour_link';
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
      _dragColor = 0;
      
      if (_isTutorialMode) {
        _gridSize = 3;
        _numColors = 1;
        _grid = List.filled(9, 0);
        _grid[0] = 1;
        _grid[8] = 1;
        _paths = [[]];
        _solutionPaths = [[0, 1, 2, 5, 8]];
        return;
      }
      
      // Determine difficulty parameters based on level
      if (_currentLevel < 5) {
        _gridSize = 4;
        _numColors = 2;
      } else if (_currentLevel < 10) {
        _gridSize = 5;
        _numColors = 3;
      } else if (_currentLevel < 20) {
        _gridSize = 6;
        _numColors = 4;
      } else if (_currentLevel < 35) {
        _gridSize = 7;
        _numColors = 5;
      } else {
        _gridSize = 8;
        _numColors = 6;
      }

      _grid = List.filled(_gridSize * _gridSize, 0);
      _paths = List.generate(_numColors, (_) => []);

      // Procedural level generation using seeded random path growth
      bool generated = false;
      final rng = Random(_currentLevel + 2026); // Seeded random for consistent levels
      
      int attempts = 0;
      while (attempts < 2000) {
        attempts++;
        List<List<int>> testPaths = List.generate(_numColors, (_) => []);
        List<int> board = List.filled(_gridSize * _gridSize, 0);
        bool success = true;

        for (int c = 1; c <= _numColors; c++) {
          List<int> empties = [];
          for (int i = 0; i < board.length; i++) {
            if (board[i] == 0) empties.add(i);
          }
          if (empties.isEmpty) {
            success = false;
            break;
          }
          int start = empties[rng.nextInt(empties.length)];
          board[start] = c;
          testPaths[c - 1].add(start);

          int curr = start;
          while (true) {
            int r = curr ~/ _gridSize;
            int col = curr % _gridSize;
            List<int> neighbors = [];
            if (r > 0 && board[(r - 1) * _gridSize + col] == 0) neighbors.add((r - 1) * _gridSize + col);
            if (r < _gridSize - 1 && board[(r + 1) * _gridSize + col] == 0) neighbors.add((r + 1) * _gridSize + col);
            if (col > 0 && board[r * _gridSize + col - 1] == 0) neighbors.add(r * _gridSize + col - 1);
            if (col < _gridSize - 1 && board[r * _gridSize + col + 1] == 0) neighbors.add(r * _gridSize + col + 1);

            if (neighbors.isEmpty) break;

            int next = neighbors[rng.nextInt(neighbors.length)];
            board[next] = c;
            testPaths[c - 1].add(next);
            curr = next;
          }

          if (testPaths[c - 1].length < 2) {
            success = false;
            break;
          }
        }

        if (success && board.every((cell) => cell != 0)) {
          // Found a full grid partition!
          for (int c = 1; c <= _numColors; c++) {
            int ep1 = testPaths[c - 1].first;
            int ep2 = testPaths[c - 1].last;
            _grid[ep1] = c;
            _grid[ep2] = c;
          }
          _solutionPaths = testPaths;
          generated = true;
          break;
        }
      }

      if (!generated) {
        // Fallback static level if generation fails
        _gridSize = 4;
        _numColors = 2;
        _grid = List.filled(16, 0);
        _paths = List.generate(2, (_) => []);
        _grid[0] = 1; _grid[15] = 1; // Red
        _grid[3] = 2; _grid[12] = 2; // Blue
        _solutionPaths = [
          [0, 1, 5, 9, 13, 14, 15],
          [3, 2, 6, 10, 11, 7, 8, 12]
        ];
      }
    });
  }

  int _cellAtLocal(Offset localPos, double cs) {
    int col = (localPos.dx / cs).floor();
    int row = (localPos.dy / cs).floor();
    if (col >= 0 && col < _gridSize && row >= 0 && row < _gridSize) {
      return row * _gridSize + col;
    }
    return -1;
  }

  List<int> _interpolateCells(int start, int end) {
    List<int> cells = [];
    int r = start ~/ _gridSize;
    int c = start % _gridSize;
    int tr = end ~/ _gridSize;
    int tc = end % _gridSize;
    int limit = 30;
    while ((r != tr || c != tc) && limit > 0) {
      limit--;
      int dr = (tr - r).sign;
      int dc = (tc - c).sign;
      if (dr.abs() >= dc.abs()) {
        r += dr;
      } else {
        c += dc;
      }
      cells.add(r * _gridSize + c);
    }
    return cells;
  }

  bool _isCellOccupiedByOther(int cell, int activeColor) {
    for (int c = 1; c <= _numColors; c++) {
      if (c == activeColor) continue;
      if (_paths[c - 1].contains(cell)) return true;
    }
    return false;
  }

  void _onPanStart(DragStartDetails details, double cs) {
    if (_isSuccess) return;
    int idx = _cellAtLocal(details.localPosition, cs);
    if (idx == -1) return;

    // Check if user tapped an endpoint or an existing path cell
    int cellVal = _grid[idx];
    if (cellVal > 0) {
      settingsNotifier.hapticTap();
      setState(() {
        _dragColor = cellVal;
        _paths[cellVal - 1] = [idx];
      });
    } else {
      for (int c = 1; c <= _numColors; c++) {
        if (_paths[c - 1].contains(idx)) {
          settingsNotifier.hapticTap();
          setState(() {
            _dragColor = c;
            int cutIdx = _paths[c - 1].indexOf(idx);
            _paths[c - 1] = _paths[c - 1].sublist(0, cutIdx + 1);
          });
          break;
        }
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails details, double cs) {
    if (_isSuccess || _dragColor == 0) return;
    int idx = _cellAtLocal(details.localPosition, cs);
    if (idx == -1) return;

    List<int> activePath = _paths[_dragColor - 1];
    if (activePath.isEmpty) return;

    int lastIdx = activePath.last;
    if (lastIdx == idx) return;

    // Undo by dragging backwards
    if (activePath.length >= 2 && activePath[activePath.length - 2] == idx) {
      settingsNotifier.hapticTap();
      setState(() {
        activePath.removeLast();
      });
      return;
    }

    // Connect with interpolation
    final listCells = _interpolateCells(lastIdx, idx);
    for (int cell in listCells) {
      if (_isCellOccupiedByOther(cell, _dragColor)) break;
      if (activePath.contains(cell)) continue;

      int cellVal = _grid[cell];
      if (cellVal == 0 || (cellVal == _dragColor && cell != activePath.first)) {
        settingsNotifier.hapticTap();
        setState(() {
          activePath.add(cell);
        });

        // Hit endpoint -> stop drag
        if (cellVal == _dragColor) {
          _dragColor = 0;
          _checkSilentWin();
          break;
        }
      } else {
        break;
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _dragColor = 0;
    });
    _checkSilentWin();
  }

  void _checkSilentWin() {
    int totalPathCells = 0;
    bool allConnected = true;

    for (int c = 1; c <= _numColors; c++) {
      final path = _paths[c - 1];
      totalPathCells += path.length;

      List<int> eps = [];
      for (int i = 0; i < _grid.length; i++) {
        if (_grid[i] == c) eps.add(i);
      }

      if (path.length < 2 || 
          !((path.first == eps[0] && path.last == eps[1]) || (path.first == eps[1] && path.last == eps[0]))) {
        allConnected = false;
      }
    }

    if (allConnected) {
      if (totalPathCells == _gridSize * _gridSize) {
        if (_isTutorialMode) {
          if (!_tutorialCompleted) {
            AudioManager.playSuccess();
            settingsNotifier.hapticSuccess();
            setState(() {
              _tutorialCompleted = true;
            });
          }
        } else {
          _onLevelCleared();
        }
      } else {
        AudioManager.playFail();
        settingsNotifier.hapticError();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Fill all cells!',
            style: GoogleFonts.outfit(color: context.textPrimary, fontWeight: FontWeight.bold),
          ),
          backgroundColor: context.bgCard,
          duration: const Duration(seconds: 2),
        ));
      }
    }
  }

  Future<void> _onLevelCleared() async {
    AudioManager.playSuccess();
    settingsNotifier.hapticSuccess();

    final prefs = await SharedPreferences.getInstance();
    final key = 'level_colour_link';
    int highest = prefs.getInt(key) ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt(key, _currentLevel + 1);
    }

    final earned = await HintManager.onLevelCleared('colour_link');
    final hCount = await HintManager.getHints('colour_link');

    setState(() {
      _hintCount = hCount;
      _isSuccess = true;
    });

    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hint earned! (Total: $hCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.accentFor('colour_link'),
        ),
      );
    }

    final newUnlocks = await AchievementManager.checkAndUnlock('colour_link');
    for (final a in newUnlocks) {
      if (mounted) {
        AchievementToast.show(context, a);
      }
    }
  }

  void _nextLevel() async {
    if (await ShuffleManager.isActive()) {
      final next = await ShuffleManager.pickNextGame('colour_link');
      if (mounted) ShuffleManager.navigateToGame(context, next);
      return;
    }
    setState(() {
      _currentLevel++;
      _loadLevel();
    });
  }

  Future<void> _useHint() async {
    if (_hintCount <= 0 || _isSuccess) return;

    settingsNotifier.hapticTap();

    int targetColor = -1;
    for (int c = 1; c <= _numColors; c++) {
      final userPath = _paths[c - 1];
      final solPath = _solutionPaths[c - 1];
      
      bool isMatch = userPath.length == solPath.length;
      if (isMatch) {
        for (int i = 0; i < userPath.length; i++) {
          if (userPath[i] != solPath[i]) {
            isMatch = false;
            break;
          }
        }
      }
      if (!isMatch) {
        targetColor = c;
        break;
      }
    }

    if (targetColor == -1) return;

    final userPath = _paths[targetColor - 1];
    final solPath = _solutionPaths[targetColor - 1];

    bool isPrefix = true;
    if (userPath.length > solPath.length) {
      isPrefix = false;
    } else {
      for (int i = 0; i < userPath.length; i++) {
        if (userPath[i] != solPath[i]) {
          isPrefix = false;
          break;
        }
      }
    }

    setState(() {
      if (!isPrefix) {
        userPath.clear();
      }
      if (userPath.isEmpty) {
        userPath.addAll(solPath.take(2));
        for (int c = 1; c <= _numColors; c++) {
          if (c == targetColor) continue;
          _paths[c - 1].remove(solPath[0]);
          _paths[c - 1].remove(solPath[1]);
        }
      } else {
        int nextCell = solPath[userPath.length];
        userPath.add(nextCell);
        for (int c = 1; c <= _numColors; c++) {
          if (c == targetColor) continue;
          _paths[c - 1].remove(nextCell);
        }
      }
    });

    await HintManager.useHint('colour_link');
    final hCount = await HintManager.getHints('colour_link');
    setState(() {
      _hintCount = hCount;
    });

    _checkSilentWin();
  }

  void _showRules() {
    settingsNotifier.hapticTap();
    GameTutorialDialog.show(context, 'colour_link', 'Colour Link');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Colour Link', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_shuffleActive)
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              tooltip: 'Skip Game',
              onPressed: () => ShuffleManager.tryShuffleNavigate(context, 'colour_link'),
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
            onPressed: !_isSuccess
                ? () async {
                    if (_hintCount > 0) {
                      _useHint();
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'colour_link',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('colour_link');
                          if (mounted) setState(() => _hintCount = newCount);
                        },
                      );
                    }
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppTheme.dustyMauve),
            tooltip: 'Rules',
            onPressed: _showRules,
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
      body: SwipeTrailOverlay(
        accentColor: AppTheme.dustyMauve,
        child: Stack(
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
                          'Connect all matching colors & fill every cell on the board.',
                          style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        RepaintBoundary(
                          child: Container(
                            width: 280, height: 280,
                            decoration: BoxDecoration(
                              color: context.bgCard,
                              border: Border.all(color: context.textMuted, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  double cs = constraints.maxWidth / _gridSize;
                                  return GestureDetector(
                                    onPanStart: (d) => _onPanStart(d, cs),
                                    onPanUpdate: (d) => _onPanUpdate(d, cs),
                                    onPanEnd: _onPanEnd,
                                    child: CustomPaint(
                                      size: Size(constraints.maxWidth, constraints.maxHeight),
                                      painter: NumberlinkPainter(
                                        grid: _grid,
                                        paths: _paths,
                                        gridSize: _gridSize,
                                        cellSize: cs,
                                        colors: _colors,
                                      ),
                                    ),
                                  );
                                }
                              ),
                            ),
                          ),
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
                  ? "Nice! You successfully connected the endpoints and filled the grid."
                  : "Drag to connect the matching colored dots. Paths cannot cross, and every empty tile must be filled!",
              isCompleted: _tutorialCompleted,
              onSkip: _finishTutorial,
              onStartGame: _finishTutorial,
            ),
        ],
      ),
    ),
  );
}
}

class NumberlinkPainter extends CustomPainter {
  final List<int> grid;
  final List<List<int>> paths;
  final int gridSize;
  final double cellSize;
  final List<Color> colors;

  NumberlinkPainter({
    required this.grid,
    required this.paths,
    required this.gridSize,
    required this.cellSize,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Grid Lines
    final linePaint = Paint()
      ..color = Colors.grey.shade800
      ..strokeWidth = 1;
    for (int i = 1; i < gridSize; i++) {
      canvas.drawLine(Offset(i * cellSize, 0), Offset(i * cellSize, size.height), linePaint);
      canvas.drawLine(Offset(0, i * cellSize), Offset(size.width, i * cellSize), linePaint);
    }

    // 2. Draw Paths
    for (int c = 1; c <= paths.length; c++) {
      final path = paths[c - 1];
      final pathPaint = Paint()
        ..color = colors[c - 1].withOpacity(0.55)
        ..strokeWidth = cellSize * 0.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      _drawPath(canvas, path, pathPaint);
    }

    // 3. Draw Endpoints
    for (int idx = 0; idx < grid.length; idx++) {
      int endpoint = grid[idx];
      if (endpoint > 0) {
        final dotPaint = Paint()
          ..color = colors[endpoint - 1]
          ..style = PaintingStyle.fill;
        double cx = (idx % gridSize) * cellSize + cellSize / 2;
        double cy = (idx ~/ gridSize) * cellSize + cellSize / 2;
        canvas.drawCircle(Offset(cx, cy), cellSize * 0.3, dotPaint);
      }
    }
  }

  void _drawPath(Canvas canvas, List<int> path, Paint paint) {
    if (path.length < 2) return;
    final p = Path();
    double startX = (path[0] % gridSize) * cellSize + cellSize / 2;
    double startY = (path[0] ~/ gridSize) * cellSize + cellSize / 2;
    p.moveTo(startX, startY);
    for (int i = 1; i < path.length; i++) {
      double cx = (path[i] % gridSize) * cellSize + cellSize / 2;
      double cy = (path[i] ~/ gridSize) * cellSize + cellSize / 2;
      p.lineTo(cx, cy);
    }
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant NumberlinkPainter oldDelegate) {
    return oldDelegate.cellSize != cellSize ||
        oldDelegate.gridSize != gridSize ||
        !listEquals(oldDelegate.grid, grid) ||
        _anyPathChanged(oldDelegate.paths, paths);
  }

  bool _anyPathChanged(List<List<int>> p1, List<List<int>> p2) {
    if (p1.length != p2.length) return true;
    for (int i = 0; i < p1.length; i++) {
      if (!listEquals(p1[i], p2[i])) return true;
    }
    return false;
  }
}
