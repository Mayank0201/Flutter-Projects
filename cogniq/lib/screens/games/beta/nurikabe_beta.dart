import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';

class NurikabeBetaScreen extends StatefulWidget {
  const NurikabeBetaScreen({super.key});
  @override
  State<NurikabeBetaScreen> createState() => _NurikabeBetaScreenState();
}
class _NurikabeBetaScreenState extends State<NurikabeBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _grid = List.filled(16, 0); // 0: white, 1: black (stream), 2: clue
  List<int> _clues = List.filled(16, 0);

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }
  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      _grid = List.filled(16, 0);
      _clues = List.filled(16, 0);
      if (_currentLevel == 0) {
        _clues[0] = 9; _clues[14] = 2;
        _grid[0] = 2; _grid[14] = 2;
      } else if (_currentLevel == 1) {
        _clues[0] = 8; _clues[12] = 3;
        _grid[0] = 2; _grid[12] = 2;
      } else if (_currentLevel == 2) {
        _clues[1] = 2; _clues[14] = 3;
        _grid[1] = 2; _grid[14] = 2;
      } else if (_currentLevel == 3) {
        _clues[0] = 8; _clues[13] = 3;
        _grid[0] = 2; _grid[13] = 2;
      } else if (_currentLevel == 4) {
        _clues[0] = 8; _clues[13] = 2;
        _grid[0] = 2; _grid[13] = 2;
      } else if (_currentLevel == 5) {
        _clues[0] = 9; _clues[14] = 2;
        _grid[0] = 2; _grid[14] = 2;
      } else if (_currentLevel == 6) {
        _clues[0] = 8; _clues[12] = 3;
        _grid[0] = 2; _grid[12] = 2;
      } else if (_currentLevel == 7) {
        _clues[1] = 2; _clues[14] = 3;
        _grid[1] = 2; _grid[14] = 2;
      } else if (_currentLevel == 8) {
        _clues[0] = 8; _clues[13] = 3;
        _grid[0] = 2; _grid[13] = 2;
      } else {
        _clues[0] = 8; _clues[13] = 2;
        _grid[0] = 2; _grid[13] = 2;
      }
    });
  }
  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_nurikabe') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_nurikabe', _currentLevel + 1);
    }
    setState(() => _isSuccess = true);
  }
  void _nextLevel() {
    if (_currentLevel < 9) {
      setState(() {
        _currentLevel++;
        _loadLevel();
      });
    } else {
      Navigator.pop(context);
    }
  }
  void _checkSolution() {
    bool isValid = true;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        if (_grid[r*4+c] == 1 && _grid[r*4+c+1] == 1 && _grid[(r+1)*4+c] == 1 && _grid[(r+1)*4+c+1] == 1) {
          isValid = false;
        }
      }
    }
    int blackCount = 0;
    int startIdx = -1;
    for (int i = 0; i < 16; i++) {
      if (_grid[i] == 1) {
        blackCount++;
        if (startIdx == -1) startIdx = i;
      }
    }
    if (blackCount == 0) isValid = false;
    if (isValid && startIdx != -1) {
      List<bool> visited = List.filled(16, false);
      List<int> queue = [startIdx];
      visited[startIdx] = true;
      int visitedCount = 1;
      while (queue.isNotEmpty) {
        int curr = queue.removeAt(0);
        int r = curr ~/ 4; int c = curr % 4;
        var neighbors = [
          if (r > 0) (r - 1) * 4 + c,
          if (r < 3) (r + 1) * 4 + c,
          if (c > 0) r * 4 + c - 1,
          if (c < 3) r * 4 + c + 1,
        ];
        for (int n in neighbors) {
          if (_grid[n] == 1 && !visited[n]) {
            visited[n] = true;
            queue.add(n);
            visitedCount++;
          }
        }
      }
      if (visitedCount != blackCount) isValid = false;
    }

    if (isValid) {
      List<bool> whiteVisited = List.filled(16, false);
      for (int i = 0; i < 16; i++) {
        if (_grid[i] != 1 && !whiteVisited[i]) {
          List<int> region = [];
          List<int> wQueue = [i];
          whiteVisited[i] = true;
          while (wQueue.isNotEmpty) {
            int curr = wQueue.removeAt(0);
            region.add(curr);
            int r = curr ~/ 4; int c = curr % 4;
            var neighbors = [
              if (r > 0) (r - 1) * 4 + c,
              if (r < 3) (r + 1) * 4 + c,
              if (c > 0) r * 4 + c - 1,
              if (c < 3) r * 4 + c + 1,
            ];
            for (int n in neighbors) {
              if (_grid[n] != 1 && !whiteVisited[n]) {
                whiteVisited[n] = true;
                wQueue.add(n);
              }
            }
          }

          List<int> regionClues = [];
          for (int cell in region) {
            if (_clues[cell] > 0) {
              regionClues.add(cell);
            }
          }
          if (regionClues.length != 1) {
            isValid = false;
            break;
          }
          int clueVal = _clues[regionClues[0]];
          if (region.length != clueVal) {
            isValid = false;
            break;
          }
        }
      }
    }

    if (isValid) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nurikabe rules violated! Check island sizes, clue counts, or stream connectivity.')));
    }
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text('How to Play Nurikabe', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
        content: Text(
          '1. Connect all black cells into a single continuous stream.\n\n'
          '2. The stream of black cells cannot contain any 2x2 blocks.\n\n'
          '3. The remaining white cells form islands. Each island must contain exactly one numbered clue, and the number of cells in that island must equal the clue value.',
          style: GoogleFonts.outfit(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it', style: GoogleFonts.outfit(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showHint() {
    final solutions = [
      [2, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 2, 0],
      [2, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 0, 0, 1],
      [1, 2, 0, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 2, 1],
      [2, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 2, 0, 0],
      [2, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 2, 0, 1],
      [2, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 2, 0],
      [2, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 0, 0, 1],
      [1, 2, 0, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 2, 1],
      [2, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 2, 0, 0],
      [2, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 2, 0, 1],
    ];
    final sol = solutions[_currentLevel];
    int hintCell = -1;
    for (int i = 0; i < 16; i++) {
      if (_grid[i] != sol[i]) {
        hintCell = i;
        break;
      }
    }
    if (hintCell != -1) {
      setState(() {
        _grid[hintCell] = sol[hintCell];
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The board is already correctly solved!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Nurikabe', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppTheme.dustyMauve),
            tooltip: 'Instructions',
            onPressed: _showInstructions,
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline, color: AppTheme.dustyMauve),
            tooltip: 'Hint',
            onPressed: _showHint,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('Level ${_currentLevel + 1}/10', style: AppTheme.numberStyle(color: AppTheme.dustyMauve, fontSize: 14, fontWeight: FontWeight.bold))),
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
                        Text('Connect all black cells to form a continuous stream. Islands are white areas containing exactly one number clue equal to its size.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary)),
                        const SizedBox(height: 24),
                        Container(
                          width: 280, height: 280,
                          decoration: BoxDecoration(border: Border.all(color: context.textMuted, width: 2)),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
                            itemCount: 16,
                            itemBuilder: (context, idx) {
                              bool isClue = _grid[idx] == 2;
                              bool isBlack = _grid[idx] == 1;
                              return GestureDetector(
                                onTap: isClue ? null : () => setState(() {
                                  _grid[idx] = _grid[idx] == 0 ? 1 : 0;
                                }),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isBlack ? Colors.black : context.bgCard,
                                    border: Border.all(color: Colors.grey.shade800),
                                  ),
                                  child: Center(
                                    child: isClue
                                        ? Text('${_clues[idx]}', style: GoogleFonts.spaceGrotesk(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold, fontSize: 20))
                                        : null,
                                  ),
                                ),
                              );
                            },
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
                      style: ElevatedButton.styleFrom(backgroundColor: context.bgCard, foregroundColor: context.textPrimary),
                      onPressed: _loadLevel, icon: const Icon(Icons.refresh), label: const Text('Reset'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dustyMauve, foregroundColor: Colors.white),
                      onPressed: _checkSolution, icon: const Icon(Icons.check), label: const Text('Check'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isSuccess)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
                      const SizedBox(height: 16),
                      Text('Level ${_currentLevel + 1} Cleared!', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
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
        ],
      ),
    );
  }
}
