import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:collection';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';

class SlidingTileBetaScreen extends StatefulWidget {
  const SlidingTileBetaScreen({super.key});
  @override
  State<SlidingTileBetaScreen> createState() => _SlidingTileBetaScreenState();
}
class _SlidingTileBetaScreenState extends State<SlidingTileBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _board = [1, 2, 3, 4, 5, 6, 8, 7, 0]; // 0 is empty slot

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      if (_currentLevel == 0) {
        _board = [1, 0, 2, 4, 5, 3, 7, 8, 6];
      } else if (_currentLevel == 1) {
        _board = [1, 5, 2, 4, 8, 3, 7, 0, 6];
      } else if (_currentLevel == 2) {
        _board = [1, 5, 2, 0, 8, 3, 4, 7, 6];
      } else if (_currentLevel == 3) {
        _board = [5, 0, 2, 1, 8, 3, 4, 7, 6];
      } else if (_currentLevel == 4) {
        _board = [5, 8, 2, 1, 7, 3, 0, 4, 6];
      } else if (_currentLevel == 5) {
        _board = [1, 0, 2, 4, 5, 3, 7, 8, 6];
      } else if (_currentLevel == 6) {
        _board = [1, 5, 2, 4, 8, 3, 7, 0, 6];
      } else if (_currentLevel == 7) {
        _board = [1, 5, 2, 0, 8, 3, 4, 7, 6];
      } else if (_currentLevel == 8) {
        _board = [5, 0, 2, 1, 8, 3, 4, 7, 6];
      } else {
        _board = [5, 8, 2, 1, 7, 3, 0, 4, 6];
      }
    });
  }

  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_slidingtile') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_slidingtile', _currentLevel + 1);
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

  void _moveTile(int idx) {
    if (_isSuccess) return;
    int emptyIdx = _board.indexOf(0);
    int emptyRow = emptyIdx ~/ 3;
    int emptyCol = emptyIdx % 3;
    int tappedRow = idx ~/ 3;
    int tappedCol = idx % 3;
    bool isAdjacent = (emptyRow == tappedRow && (emptyCol - tappedCol).abs() == 1) ||
                      (emptyCol == tappedCol && (emptyRow - tappedRow).abs() == 1);
    if (isAdjacent) {
      settingsNotifier.hapticTap();
      setState(() {
        _board[emptyIdx] = _board[idx];
        _board[idx] = 0;
        if (_board.toString() == [1, 2, 3, 4, 5, 6, 7, 8, 0].toString()) {
          _onLevelCleared();
        }
      });
    }
  }

  // Slide via swipe/drag. The swipe direction must point toward the empty gap,
  // i.e. the neighbouring cell in that direction is the empty slot. Reuses the
  // same move logic as tapping. An illegal swipe does nothing.
  void _swipeTile(int idx, {required bool horizontal, required double primaryVelocity}) {
    if (_isSuccess) return;
    if (primaryVelocity == 0) return;
    int emptyIdx = _board.indexOf(0);
    int row = idx ~/ 3;
    int col = idx % 3;
    int? targetIdx;
    if (horizontal) {
      if (primaryVelocity > 0 && col < 2) {
        targetIdx = idx + 1; // swipe right
      } else if (primaryVelocity < 0 && col > 0) {
        targetIdx = idx - 1; // swipe left
      }
    } else {
      if (primaryVelocity > 0 && row < 2) {
        targetIdx = idx + 3; // swipe down
      } else if (primaryVelocity < 0 && row > 0) {
        targetIdx = idx - 3; // swipe up
      }
    }
    // Only slide if the swipe points at the empty gap.
    if (targetIdx == emptyIdx) {
      _moveTile(idx);
    }
  }

  List<int>? _solveState(List<int> currentBoard) {
    List<int> target = [1, 2, 3, 4, 5, 6, 7, 8, 0];
    if (currentBoard.toString() == target.toString()) return null;

    Map<String, String> parent = {};
    Queue<List<int>> queue = Queue();
    queue.add(currentBoard);
    parent[currentBoard.toString()] = "";

    while (queue.isNotEmpty) {
      var curr = queue.removeFirst();
      if (curr.toString() == target.toString()) {
        var path = <List<int>>[];
        var temp = curr;
        while (temp.toString() != currentBoard.toString()) {
          path.add(temp);
          var pStr = parent[temp.toString()]!;
          temp = pStr.substring(1, pStr.length - 1).split(', ').map(int.parse).toList();
        }
        return path.last;
      }

      int emptyIdx = curr.indexOf(0);
      int r = emptyIdx ~/ 3;
      int c = emptyIdx % 3;

      var moves = <int>[];
      if (r > 0) moves.add(emptyIdx - 3);
      if (r < 2) moves.add(emptyIdx + 3);
      if (c > 0) moves.add(emptyIdx - 1);
      if (c < 2) moves.add(emptyIdx + 1);

      for (int nextIdx in moves) {
        var nextBoard = List<int>.from(curr);
        nextBoard[emptyIdx] = nextBoard[nextIdx];
        nextBoard[nextIdx] = 0;

        String key = nextBoard.toString();
        if (!parent.containsKey(key)) {
          parent[key] = curr.toString();
          queue.add(nextBoard);
        }
      }
    }
    return null;
  }

  void _showHint() {
    var nextBoard = _solveState(_board);
    if (nextBoard != null) {
      setState(() {
        _board = nextBoard;
        if (_board.toString() == [1, 2, 3, 4, 5, 6, 7, 8, 0].toString()) {
          _onLevelCleared();
        }
      });
    }
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text('How to Play Sliding Tile', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
        content: Text(
          '1. Tap a tile adjacent to the empty slot to slide it into the empty slot.\n\n'
          '2. Arrange the tiles in numerical order from 1 to 8, with the empty slot at the bottom-right.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Sliding Tile', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        Text('Tap or swipe tiles to arrange them in order 1 to 8.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        Container(
                          width: 240, height: 240,
                          decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.textMuted.withAlpha(40))),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
                            itemCount: 9,
                            itemBuilder: (context, idx) {
                              int val = _board[idx];
                              return GestureDetector(
                                onTap: () => _moveTile(idx),
                                onHorizontalDragEnd: (details) => _swipeTile(idx, horizontal: true, primaryVelocity: details.primaryVelocity ?? 0),
                                onVerticalDragEnd: (details) => _swipeTile(idx, horizontal: false, primaryVelocity: details.primaryVelocity ?? 0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: val == 0 ? Colors.transparent : context.bgSurface,
                                    border: Border.all(color: Colors.grey.shade900),
                                  ),
                                  child: Center(
                                    child: val == 0
                                        ? null
                                        : Text('$val', style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.bold, color: context.textPrimary)),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(top: 16),
                          decoration: BoxDecoration(
                            color: context.bgCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.textMuted.withAlpha(20)),
                          ),
                          child: Text(
                            '💡 Rule Details:\n'
                            '• Slide tiles into the empty space by tapping or swiping.\n'
                            '• Arrange the numbers in order to solve the puzzle.',
                            style: GoogleFonts.outfit(fontSize: 12, color: context.textSecondary),
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
