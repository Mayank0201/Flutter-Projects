import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../utils/rotation_engine.dart';
import '../../../utils/point_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../widgets/game_tutorial_dialog.dart';
import '../../../utils/audio_manager.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/shuffle_manager.dart';
import '../../../widgets/swipe_trail_overlay.dart';
import '../../../widgets/buy_hints_dialog.dart';
import '../../../utils/achievement_manager.dart';
import '../../../widgets/achievement_toast.dart';

class ColorFloodBetaScreen extends StatefulWidget {
  const ColorFloodBetaScreen({super.key});
  @override
  State<ColorFloodBetaScreen> createState() => _ColorFloodBetaScreenState();
}

class _ColorFloodBetaScreenState extends State<ColorFloodBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  bool _playDailyMode = false;

  int _gridSize = 5;
  int _numColors = 4;
  List<int> _grid = [];
  int _movesLeft = 12;
  int _hintCount = 0;
  bool _shuffleActive = false;
  Timer? _gameTimer;
  int _timeLeft = -1;
  bool _timeBonusEarned = false;

  final List<Color> _colors = [
    Colors.red.shade400,
    Colors.green.shade400,
    Colors.blue.shade400,
    Colors.orange.shade400,
    Colors.purple.shade400,
    Colors.teal.shade400,
    Colors.pink.shade400,
    Colors.amber.shade400,
    Colors.indigo.shade400,
  ];

  bool _isTutorialMode = false;
  bool _tutorialCompleted = false;
  int _actualGameLevel = 0;
  bool _seedFromCenter = false;
  Set<String> _activeModifiers = {};
  int get _seedCell => _seedFromCenter ? (_gridSize ~/ 2) * _gridSize + (_gridSize ~/ 2) : 0;

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
    final savedLvl = prefs.getInt('level_color_flood') ?? 0;
    final hCount = await HintManager.getHints('color_flood');
    
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

  bool _isFloodConnected(List<int> grid, int size, int obstacleVal) {
    int startIdx = _seedFromCenter ? (size ~/ 2) * size + (size ~/ 2) : 0;
    final visited = List.filled(size * size, false);
    final queue = <int>[startIdx];
    visited[startIdx] = true;
    int visitedCount = 1;
    int nonObstacles = grid.where((c) => c != obstacleVal).length;

    int head = 0;
    while (head < queue.length) {
      int curr = queue[head++];
      int r = curr ~/ size;
      int c = curr % size;
      final neighbors = [
        if (r > 0) (r - 1) * size + c,
        if (r < size - 1) (r + 1) * size + c,
        if (c > 0) r * size + c - 1,
        if (c < size - 1) r * size + c + 1,
      ];
      for (int n in neighbors) {
        if (grid[n] != obstacleVal && !visited[n]) {
          visited[n] = true;
          queue.add(n);
          visitedCount++;
        }
      }
    }
    return visitedCount == nonObstacles;
  }

  void _loadLevel() {
    setState(() {
      _isSuccess = false;

      if (_isTutorialMode) {
        _gridSize = 3;
        _numColors = 3;
        final rng = Random(2026);
        _grid = List.generate(9, (_) => rng.nextInt(3));
        _movesLeft = 6;
        return;
      }

      _gameTimer?.cancel();
      _timeLeft = -1;
      _timeBonusEarned = false;

      int minOptimal = 0;
      int maxOptimal = 0;
      int buffer = 0;
      _seedFromCenter = false;
      bool hasObstacles = false;

      if (!_playDailyMode && _currentLevel >= 30) {
        // First determine grid size and colour count
        if (_currentLevel >= 30 && _currentLevel < 45) {
          _gridSize = 9;
          _numColors = 6;
        } else if (_currentLevel >= 45 && _currentLevel < 60) {
          _gridSize = 9;
          _numColors = 6 + min(2, (_currentLevel - 45) ~/ 7); // 7-8 colors
        } else if (_currentLevel >= 60 && _currentLevel < 75) {
          _gridSize = 9;
          _numColors = 7;
        } else if (_currentLevel >= 75 && _currentLevel < 90) {
          _gridSize = 9;
          _numColors = 7;
        } else {
          // Rotation (L90+)
          _gridSize = 9;
          _numColors = 8;
        }

        _activeModifiers = RotationEngine.getActiveModifiers(
          gameId: 'colorflood',
          levelIndex: _currentLevel,
          pool: ['centerSeed', 'timer'],
          minActive: 2,
          maxActive: 3,
          smallGrid: (_gridSize <= 6),
        );

        minOptimal = 6 + ((_gridSize + _numColors) * 1.5).round();
        maxOptimal = minOptimal + 2;

        buffer = 0;
        _seedFromCenter = _activeModifiers.contains('centerSeed');
        hasObstacles = false;
      } else {
        _activeModifiers = {};
        if (_currentLevel < 5) {
          _gridSize = 5;
          _numColors = 4;
          minOptimal = 6;
          maxOptimal = 9;
          buffer = 2;
        } else if (_currentLevel < 10) {
          _gridSize = 6;
          _numColors = 4;
          minOptimal = 9;
          maxOptimal = 12;
          buffer = 1;
        } else if (_currentLevel < 20) {
          _gridSize = 7;
          _numColors = 5;
          minOptimal = 12;
          maxOptimal = 15;
          buffer = 0;
        } else if (_currentLevel < 35) {
          _gridSize = 8;
          _numColors = 5;
          minOptimal = 15;
          maxOptimal = 18;
          buffer = 0;
        } else {
          _gridSize = 9;
          _numColors = 6;
          minOptimal = 18;
          maxOptimal = 21;
          buffer = (_currentLevel < 45) ? 3 : ((_currentLevel < 60) ? 1 : 0);
        }
      }

      final rng = _playDailyMode
          ? Random()
          : RotationEngine.getDeterminism('colorflood', _currentLevel);

      bool found = false;
      int attempts = 0;
      List<int> bestGrid = [];
      int targetOptimal = (minOptimal + maxOptimal) ~/ 2;
      int bestDiff = 999;
      int bestOpt = -1;

      while (attempts < 50) {
        attempts++;
        List<int> testGrid;
        
        if (hasObstacles) {
          do {
            testGrid = List.generate(_gridSize * _gridSize, (_) => rng.nextInt(_numColors));
            double obstacleChance = 0.08 + rng.nextDouble() * 0.08;
            if (_currentLevel >= 75 && _currentLevel < 90) {
              obstacleChance = 0.08 + 0.08 * ((_currentLevel - 75) / 14.0);
            }
            for (int i = 0; i < testGrid.length; i++) {
              if (i == _seedCell) continue;
              if (rng.nextDouble() < obstacleChance) {
                testGrid[i] = _numColors;
              }
            }
          } while (!_isFloodConnected(testGrid, _gridSize, _numColors));
        } else {
          testGrid = List.generate(_gridSize * _gridSize, (_) => rng.nextInt(_numColors));
        }
        
        if (testGrid.every((c) => c == testGrid[0])) continue;

        int opt = _solveColorFlood(testGrid, _gridSize, _numColors);
        if (opt < 99) {
          if (opt >= minOptimal && opt <= maxOptimal) {
            _grid = testGrid;
            _movesLeft = opt + buffer;
            found = true;
            break;
          }
          int diff = (opt - targetOptimal).abs();
          if (diff < bestDiff) {
            bestDiff = diff;
            bestGrid = testGrid;
            bestOpt = opt;
          }
        }
      }

      if (!found && bestGrid.isNotEmpty) {
        _grid = bestGrid;
        _movesLeft = bestOpt + buffer;
      } else if (!found) {
        RotationEngine.logFallback('colorflood', _currentLevel);
        _grid = List.generate(_gridSize * _gridSize, (_) => rng.nextInt(_numColors));
        int fallbackOpt = _solveColorFlood(_grid, _gridSize, _numColors);
        _movesLeft = (fallbackOpt < 99 ? fallbackOpt : 15) + buffer;
      }

      if (!_playDailyMode && _currentLevel >= 30 && _activeModifiers.contains('timer')) {
        _timeLeft = 20 + (_gridSize * 8);
        _timeBonusEarned = true;
        _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            if (_timeLeft > 0) {
              setState(() {
                _timeLeft--;
              });
            } else {
              _gameTimer?.cancel();
              AudioManager.playFail();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Time is up! Restarting level...'), duration: Duration(seconds: 1)),
              );
              _loadLevel();
            }
          }
        });
      }
    });
  }

  int _solveColorFlood(List<int> initialGrid, int size, int numColors) {
    String serialize(List<int> g) => String.fromCharCodes(g);
    
    final startKey = serialize(initialGrid);
    final Set<String> visited = {startKey};
    final List<(List<int>, int)> queue = [(List<int>.from(initialGrid), 0)];
    
    int limit = 800; // Fast cap
    int head = 0;
    
    while (head < queue.length && head < limit) {
      final (currentGrid, moves) = queue[head++];
      int seedIdx = _seedFromCenter ? (size ~/ 2) * size + (size ~/ 2) : 0;
      int firstColor = currentGrid[seedIdx];
      bool allMatched = true;
      for (int i = 0; i < currentGrid.length; i++) {
        if (currentGrid[i] != numColors && currentGrid[i] != firstColor) {
          allMatched = false;
          break;
        }
      }
      if (allMatched) {
        return moves;
      }
      
      for (int col = 0; col < numColors; col++) {
        if (col == firstColor) continue;
        
        List<int> nextGrid = List<int>.from(currentGrid);
        
        List<int> component = [seedIdx];
        List<bool> compVisited = List.filled(size * size, false);
        compVisited[seedIdx] = true;
        int compHead = 0;
        while (compHead < component.length) {
          int curr = component[compHead++];
          int r = curr ~/ size;
          int c = curr % size;
          
          if (r > 0) {
            int n = (r - 1) * size + c;
            if (nextGrid[n] == firstColor && !compVisited[n]) {
              compVisited[n] = true;
              component.add(n);
            }
          }
          if (r < size - 1) {
            int n = (r + 1) * size + c;
            if (nextGrid[n] == firstColor && !compVisited[n]) {
              compVisited[n] = true;
              component.add(n);
            }
          }
          if (c > 0) {
            int n = r * size + c - 1;
            if (nextGrid[n] == firstColor && !compVisited[n]) {
              compVisited[n] = true;
              component.add(n);
            }
          }
          if (c < size - 1) {
            int n = r * size + c + 1;
            if (nextGrid[n] == firstColor && !compVisited[n]) {
              compVisited[n] = true;
              component.add(n);
            }
          }
        }
        
        for (int idx in component) {
          nextGrid[idx] = col;
        }
        
        final nKey = serialize(nextGrid);
        if (!visited.contains(nKey)) {
          visited.add(nKey);
          queue.add((nextGrid, moves + 1));
        }
      }
    }
    return 99; // Solver limit hit
  }

  Future<void> _onLevelCleared() async {
    _gameTimer?.cancel();
    AudioManager.playSuccess();
    settingsNotifier.hapticSuccess();

    final prefs = await SharedPreferences.getInstance();
    final key = 'level_color_flood';
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

    final earned = await HintManager.onLevelCleared('color_flood');
    final hCount = await HintManager.getHints('color_flood');

    setState(() {
      _hintCount = hCount;
      _isSuccess = true;
    });

    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hint earned! (Total: $hCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.accentFor('color_flood'),
        ),
      );
    }

    final newUnlocks = await AchievementManager.checkAndUnlock('color_flood');
    for (final a in newUnlocks) {
      if (mounted) {
        AchievementToast.show(context, a);
      }
    }
  }

  void _nextLevel() async {
    if (await ShuffleManager.isActive()) {
      final next = await ShuffleManager.pickNextGame('color_flood');
      if (mounted) ShuffleManager.navigateToGame(context, next);
      return;
    }
    setState(() {
      _currentLevel++;
      _loadLevel();
    });
  }

  void _flood(int targetColor) {
    if (_movesLeft <= 0 || _isSuccess) return;
    int original = _grid[_seedCell];
    if (original == targetColor) return;

    AudioManager.playClick();
    settingsNotifier.hapticTap();

    List<bool> visited = List.filled(_gridSize * _gridSize, false);
    List<int> queue = [_seedCell];
    visited[_seedCell] = true;

    while (queue.isNotEmpty) {
      int curr = queue.removeAt(0);
      _grid[curr] = targetColor;
      int r = curr ~/ _gridSize;
      int c = curr % _gridSize;
      var neighbors = [
        if (r > 0) (r - 1) * _gridSize + c,
        if (r < _gridSize - 1) (r + 1) * _gridSize + c,
        if (c > 0) r * _gridSize + c - 1,
        if (c < _gridSize - 1) r * _gridSize + c + 1,
      ];
      for (int n in neighbors) {
        if (_grid[n] == original && !visited[n]) {
          visited[n] = true;
          queue.add(n);
        }
      }
    }

    setState(() {
      _movesLeft--;
      bool isWin = true;
      for (int i = 0; i < _grid.length; i++) {
        if (_grid[i] != _numColors && _grid[i] != targetColor) {
          isWin = false;
          break;
        }
      }
      if (isWin) {
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
      } else if (_movesLeft == 0) {
        AudioManager.playFail();
        settingsNotifier.hapticError();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No moves left! Reset to try again.'),
          backgroundColor: Colors.redAccent,
        ));
      }
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
    if (_isSuccess || _movesLeft <= 0) return;

    if (_hintCount <= 0) {
      BuyHintsDialog.show(
        context,
        initialGameId: 'color_flood',
        isFromGameScreen: true,
        onPurchaseComplete: () {
          HintManager.getHints('color_flood').then((val) {
            if (mounted) setState(() => _hintCount = val);
          });
        },
      );
      return;
    }

    int currentColor = _grid[0];
    List<bool> flooded = List.filled(_gridSize * _gridSize, false);
    List<int> queue = [0];
    flooded[0] = true;

    while (queue.isNotEmpty) {
      int curr = queue.removeAt(0);
      int r = curr ~/ _gridSize;
      int c = curr % _gridSize;
      var neighbors = [
        if (r > 0) (r - 1) * _gridSize + c,
        if (r < _gridSize - 1) (r + 1) * _gridSize + c,
        if (c > 0) r * _gridSize + c - 1,
        if (c < _gridSize - 1) r * _gridSize + c + 1,
      ];
      for (int nbr in neighbors) {
        if (!flooded[nbr] && _grid[nbr] == currentColor) {
          flooded[nbr] = true;
          queue.add(nbr);
        }
      }
    }

    int bestColor = -1;
    int maxGain = -1;
    for (int col = 0; col < _numColors; col++) {
      if (col == currentColor) continue;
      int gain = 0;
      for (int i = 0; i < _grid.length; i++) {
        if (flooded[i]) {
          int r = i ~/ _gridSize;
          int c = i % _gridSize;
          var neighbors = [
            if (r > 0) (r - 1) * _gridSize + c,
            if (r < _gridSize - 1) (r + 1) * _gridSize + c,
            if (c > 0) r * _gridSize + c - 1,
            if (c < _gridSize - 1) r * _gridSize + c + 1,
          ];
          for (int nbr in neighbors) {
            if (!flooded[nbr] && _grid[nbr] == col) {
              gain++;
            }
          }
        }
      }
      if (gain > maxGain) {
        maxGain = gain;
        bestColor = col;
      }
    }

    if (bestColor == -1) return;

    final colorNames = ["Red", "Green", "Blue", "Orange", "Purple", "Teal"];
    String colorName = (bestColor >= 0 && bestColor < colorNames.length) ? colorNames[bestColor] : "Unknown";

    settingsNotifier.hapticTap();

    await HintManager.useHint('color_flood');
    final hCount = await HintManager.getHints('color_flood');
    setState(() {
      _hintCount = hCount;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Hint: Try flooding with $colorName next!'),
      backgroundColor: AppTheme.accentFor('color_flood'),
      duration: const Duration(seconds: 3),
    ));
  }

  void _showRules() {
    settingsNotifier.hapticTap();
    GameTutorialDialog.show(context, 'color_flood', 'Color Flood');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Color Flood', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_shuffleActive)
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              tooltip: 'Skip Game',
              onPressed: () => ShuffleManager.tryShuffleNavigate(context, 'color_flood'),
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
            onPressed: !_isSuccess && _movesLeft > 0
                ? () async {
                    if (_hintCount > 0) {
                      _useHint();
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'color_flood',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('color_flood');
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
            onTap: null,
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
                      const Icon(null, size: 12, color: AppTheme.dustyMauve),
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
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Flood the entire board with a single color. Start at the top-left cell. Moves left: $_movesLeft',
                            style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Builder(
                          builder: (context) {
                            final double screenW = MediaQuery.of(context).size.width;
                            final double screenH = MediaQuery.of(context).size.height;
                            final double maxBoardH = screenH - 320;
                            final double boardSize = min(screenW - 32, maxBoardH).clamp(180.0, 400.0);
                            return RepaintBoundary(
                              child: Container(
                                width: boardSize, height: boardSize,
                                decoration: BoxDecoration(
                                  border: Border.all(color: context.textMuted, width: 2), 
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: GridView.builder(
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _gridSize),
                                    itemCount: _grid.length,
                                    itemBuilder: (context, idx) {
                                      final val = _grid[idx];
                                      final isObstacle = val == _numColors;
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: isObstacle
                                              ? Colors.grey.shade900
                                              : _colors[val],
                                          border: Border.all(
                                            color: context.bgDark.withOpacity(0.12),
                                            width: 1.0,
                                          ),
                                        ),
                                        child: isObstacle
                                            ? const Center(
                                                child: Icon(Icons.close_rounded, color: Colors.white24, size: 14),
                                              )
                                            : (idx == _seedCell
                                                ? const Center(
                                                    child: Icon(Icons.home, color: Colors.white, size: 20),
                                                  )
                                                : null),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(_numColors, (i) {
                            return GestureDetector(
                              onTap: () => _flood(i),
                              child: Container(
                                width: 42, height: 42,
                                decoration: BoxDecoration(
                                  color: _colors[i],
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 36),
                      ],
                    ),
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
          //         ? "Nice! You successfully flooded the entire board with a single color."
          //         : "Tap the color buttons below. Start at the top-left home tile and flood adjacent cells until everything is one color!",
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
