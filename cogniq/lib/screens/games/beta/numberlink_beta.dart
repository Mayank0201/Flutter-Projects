import 'dart:math';
import 'dart:async';
import '../../../utils/rotation_engine.dart';
import '../../../utils/point_manager.dart';
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
  bool get _isEndgame => !_playDailyMode && _currentLevel >= 30;
  Timer? _gameTimer;
  int _timeLeft = -1;
  bool _timeBonusEarned = false;
  final Set<int> _wallCells = {};

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

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
    
    if (mounted) {
      setState(() {
        _hintCount = hCount;
        _actualGameLevel = savedLvl;
        _isTutorialMode = false;
        _currentLevel = _playDailyMode ? (savedLvl % 10) : savedLvl;
        _loadLevel();
      });
    }
  }

  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      _dragColor = 0;
      _gameTimer?.cancel();
      _timeLeft = -1;
      _timeBonusEarned = false;
      
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
      
      if (!_playDailyMode && _currentLevel >= 30) {
        if (_currentLevel >= 30 && _currentLevel < 45) {
          _gridSize = 8;
          _numColors = 6 + min(2, (_currentLevel - 30) ~/ 7); // 7-8 colors
        } else if (_currentLevel >= 45 && _currentLevel < 60) {
          _gridSize = 8;
          _numColors = 8;
        } else if (_currentLevel >= 60 && _currentLevel < 80) {
          _gridSize = 8;
          _numColors = 6;
        } else {
          // Rotation (L80+)
          _gridSize = 4 + ((_currentLevel - 80) % 5); // Rotates 4x4 to 8x8
          _numColors = 3 + ((_currentLevel - 80) % 4); // Rotates 3-6 color pairs
        }
      } else if (_currentLevel < 5) {
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
      _wallCells.clear();

      final rng = _playDailyMode
          ? Random(_currentLevel + 2026)
          : RotationEngine.getDeterminism('colourlink', _currentLevel);

      int wallCount = 0;
      if (!_playDailyMode && _currentLevel >= 60) {
        if (_currentLevel < 80) {
          wallCount = 1 + (_currentLevel - 60) ~/ 5;
        } else {
          int combo = (_currentLevel - 80) % 3;
          if (combo == 1 || combo == 2) {
            wallCount = 1 + _gridSize ~/ 2;
          }
        }
      }
      
      bool generated = false;
      int attempts = 0;
      while (attempts < 2000) {
        attempts++;
        List<List<int>> testPaths = List.generate(_numColors, (_) => []);
        List<int> board = List.filled(_gridSize * _gridSize, 0);
        _wallCells.clear();

        if (wallCount > 0) {
          final List<int> indices = List.generate(_gridSize * _gridSize, (idx) => idx)..shuffle(rng);
          int placed = 0;
          for (int idx in indices) {
            if (placed >= wallCount) break;
            board[idx] = -1;
            _wallCells.add(idx);
            placed++;
          }
        }

        bool success = true;

        for (int c = 1; c <= _numColors; c++) {
          List<int> empties = [];
          for (int i = 0; i < board.length; i++) {
            if (board[i] == 0) empties.add(i);
          }
          if (empties.isEmpty) { success = false; break; }
          int current = empties[rng.nextInt(empties.length)];
          testPaths[c - 1].add(current);
          board[current] = c;

          int len = 3 + rng.nextInt(max(3, _gridSize));
          if (!_playDailyMode && _currentLevel >= 45) {
            int extra = ((_currentLevel - 45) ~/ 4);
            if (_currentLevel >= 80) {
              int combo = (_currentLevel - 80) % 3;
              if (combo == 0 || combo == 2) {
                extra = _gridSize;
              }
            }
            len = 3 + _gridSize + extra;
          }

          for (int step = 0; step < len; step++) {
            int r = current ~/ _gridSize;
            int cCell = current % _gridSize;
            List<int> neighbors = [];
            if (r > 0 && board[current - _gridSize] == 0) neighbors.add(current - _gridSize);
            if (r < _gridSize - 1 && board[current + _gridSize] == 0) neighbors.add(current + _gridSize);
            if (cCell > 0 && board[current - 1] == 0) neighbors.add(current - 1);
            if (cCell < _gridSize - 1 && board[current + 1] == 0) neighbors.add(current + 1);

            if (neighbors.isEmpty) break;
            int nextNode = neighbors[rng.nextInt(neighbors.length)];
            testPaths[c - 1].add(nextNode);
            board[nextNode] = c;
            current = nextNode;
          }
          if (testPaths[c - 1].length < 2) { success = false; break; }
        }

        if (success) {
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
        _gridSize = 4;
        _numColors = 2;
        _grid = List.filled(16, 0);
        _paths = List.generate(2, (_) => []);
        _wallCells.clear();
        _grid[0] = 1; _grid[15] = 1;
        _grid[3] = 2; _grid[12] = 2;
        _solutionPaths = [
          [0, 1, 5, 9, 13, 14, 15],
          [3, 2, 6, 10, 11, 7, 8, 12]
        ];
      }

      if (_isEndgame) {
        _timeLeft = 30 + (_gridSize * 12);
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
              }
            });
          }
        });
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
    if (idx == -1 || _wallCells.contains(idx)) return;

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
    if (idx == -1 || _wallCells.contains(idx)) return;

    List<int> activePath = _paths[_dragColor - 1];
    if (activePath.isEmpty) return;

    int lastIdx = activePath.last;
    if (lastIdx == idx) return;

    // Undo by dragging backwards (only to the immediate previous cell)
    if (activePath.contains(idx)) {
      if (activePath.length >= 2 && activePath[activePath.length - 2] == idx) {
        settingsNotifier.hapticTap();
        setState(() {
          activePath.removeLast();
        });
      }
      return;
    }

    // Connect with interpolation
    final listCells = _interpolateCells(lastIdx, idx);
    for (int cell in listCells) {
      if (_wallCells.contains(cell)) break;
      if (_isCellOccupiedByOther(cell, _dragColor)) break;
      if (activePath.contains(cell)) continue;

      // Adjacency check to block diagonal paths
      int last = activePath.last;
      int r1 = last ~/ _gridSize, c1 = last % _gridSize;
      int r2 = cell ~/ _gridSize, c2 = cell % _gridSize;
      if ((r1 - r2).abs() + (c1 - c2).abs() != 1) {
        break; // Stop extending path if a diagonal jump occurs
      }

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
      if (totalPathCells == _gridSize * _gridSize - _wallCells.length) {
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
    _gameTimer?.cancel();
    AudioManager.playSuccess();
    settingsNotifier.hapticSuccess();

    final prefs = await SharedPreferences.getInstance();
    final key = 'level_colour_link';
    int highest = prefs.getInt(key) ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt(key, _currentLevel + 1);
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
            Text('Enter level number (1 - 150):', style: GoogleFonts.outfit(color: context.textSecondary)),
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
            icon: const Icon(Icons.help_outline, color: AppTheme.dustyMauve),
            tooltip: 'Rules',
            onPressed: _showRules,
          ),
          GestureDetector(
            onTap: _isTutorialMode ? null : _showJumpToLevelDialog,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isTutorialMode ? 'Tutorial' : 'Level ${_currentLevel + 1}', 
                      style: AppTheme.numberStyle(
                        color: AppTheme.dustyMauve, 
                        fontSize: 14, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!_isTutorialMode) ...[
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
                          child: Builder(
                            builder: (context) {
                              final double boardSize = min(MediaQuery.of(context).size.width - 32, 400.0);
                              return Container(
                                width: boardSize, height: boardSize,
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
                                        wallCells: _wallCells,
                                      ),
                                    ),
                                  );
                                }
                              ),
                            ),
                          );
                        },
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
          // if (_isTutorialMode)
          //   InteractiveTutorialOverlay(
          //     instruction: _tutorialCompleted
          //         ? "Nice! You successfully connected the endpoints and filled the grid."
          //         : "Drag to connect the matching colored dots. Paths cannot cross, and every empty tile must be filled!",
          //     isCompleted: _tutorialCompleted,
          //     onSkip: _finishTutorial,
          //     onStartGame: _finishTutorial,
          //   ),
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
  final Set<int> wallCells;

  NumberlinkPainter({
    required this.grid,
    required this.paths,
    required this.gridSize,
    required this.cellSize,
    required this.colors,
    required this.wallCells,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 0. Draw Wall Cells
    final wallPaint = Paint()
      ..color = Colors.grey.shade900
      ..style = PaintingStyle.fill;
    for (int idx in wallCells) {
      double left = (idx % gridSize) * cellSize;
      double top = (idx ~/ gridSize) * cellSize;
      canvas.drawRect(Rect.fromLTWH(left, top, cellSize, cellSize), wallPaint);
    }

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
        !setEquals(oldDelegate.wallCells, wallCells) ||
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
