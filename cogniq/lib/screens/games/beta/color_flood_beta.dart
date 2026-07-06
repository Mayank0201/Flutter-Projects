import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../utils/ad_manager.dart';
import '../../../utils/audio_manager.dart';

import '../../../utils/hint_manager.dart';

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

  final List<Color> _colors = [
    Colors.red.shade400,
    Colors.green.shade400,
    Colors.blue.shade400,
    Colors.orange.shade400,
    Colors.purple.shade400,
    Colors.teal.shade400,
  ];

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
        _currentLevel = _playDailyMode ? (savedLvl % 10) : savedLvl;
        _loadLevel();
      });
    }
  }

  void _loadLevel() {
    setState(() {
      _isSuccess = false;

      int minOptimal = 0;
      int maxOptimal = 0;
      int buffer = 0;

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
        buffer = 0;
      }

      final rng = Random(_currentLevel * 73 + 2026);

      bool found = false;
      int attempts = 0;
      List<int> bestGrid = [];
      int bestMoves = 999;
      int bestOpt = -1;

      while (attempts < 20) {
        attempts++;
        List<int> testGrid = List.generate(_gridSize * _gridSize, (_) => rng.nextInt(_numColors));
        if (testGrid.every((c) => c == testGrid[0])) continue;

        int opt = _solveColorFlood(testGrid, _gridSize, _numColors);
        if (opt < 99) {
          if (opt >= minOptimal && opt <= maxOptimal) {
            _grid = testGrid;
            _movesLeft = opt + buffer;
            found = true;
            break;
          }
          if ((opt - (minOptimal + maxOptimal) ~/ 2).abs() < (bestMoves - (minOptimal + maxOptimal) ~/ 2).abs()) {
            bestGrid = testGrid;
            bestMoves = opt;
            bestOpt = opt;
          }
        }
      }

      if (!found) {
        if (bestGrid.isNotEmpty) {
          _grid = bestGrid;
          _movesLeft = bestOpt + buffer;
        } else {
          _grid = List.generate(_gridSize * _gridSize, (_) => rng.nextInt(_numColors));
          if (_gridSize == 5) {
            _movesLeft = 11;
          } else if (_gridSize == 6) {
            _movesLeft = 13;
          } else if (_gridSize == 7) {
            _movesLeft = 14;
          } else if (_gridSize == 8) {
            _movesLeft = 16;
          } else {
            _movesLeft = 18;
          }
        }
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
      
      int firstColor = currentGrid[0];
      if (currentGrid.every((c) => c == firstColor)) {
        return moves;
      }
      
      for (int col = 0; col < numColors; col++) {
        if (col == firstColor) continue;
        
        List<int> nextGrid = List<int>.from(currentGrid);
        
        List<int> component = [0];
        List<bool> compVisited = List.filled(size * size, false);
        compVisited[0] = true;
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
    AudioManager.playSuccess();
    settingsNotifier.hapticSuccess();

    final prefs = await SharedPreferences.getInstance();
    final key = 'level_color_flood';
    int highest = prefs.getInt(key) ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt(key, _currentLevel + 1);
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
  }

  void _nextLevel() {
    setState(() {
      _currentLevel++;
      _loadLevel();
    });
  }

  void _flood(int targetColor) {
    if (_movesLeft <= 0 || _isSuccess) return;
    int original = _grid[0];
    if (original == targetColor) return;

    AudioManager.playClick();
    settingsNotifier.hapticTap();

    List<bool> visited = List.filled(_gridSize * _gridSize, false);
    List<int> queue = [0];
    visited[0] = true;

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
      if (_grid.every((e) => e == targetColor)) {
        _onLevelCleared();
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

  Future<void> _useHint() async {
    if (_hintCount <= 0 || _isSuccess || _movesLeft <= 0) return;

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
    _flood(bestColor);

    await HintManager.useHint('color_flood');
    final hCount = await HintManager.getHints('color_flood');
    setState(() {
      _hintCount = hCount;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Hint: Flooded board with $colorName!'),
      backgroundColor: AppTheme.accentFor('color_flood'),
    ));
  }

  void _showRules() {
    settingsNotifier.hapticTap();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: context.textMuted.withAlpha(40)),
        ),
        title: Text(
          'How to Play',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        content: Text(
          '• Start from the top-left cell.\n• Tap a color circle to flood connected cells of the same color.\n• Make the entire board a single color within the move limit.',
          style: GoogleFonts.outfit(color: context.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Got it',
              style: GoogleFonts.outfit(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Color Flood', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
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
                      '$_hintCount',
                      style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            onPressed: _hintCount > 0 && !_isSuccess && _movesLeft > 0 ? _useHint : null,
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
                'Level ${_currentLevel + 1}', 
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
                            final double boardSize = MediaQuery.of(context).size.width - 32;
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
                                      return Container(
                                        color: _colors[_grid[idx]],
                                        child: idx == 0
                                            ? const Center(
                                                child: Icon(Icons.home, color: Colors.white, size: 20),
                                              )
                                            : null,
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
                if (_isSuccess && !_playDailyMode)
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
        ],
      ),
    );
  }
}
