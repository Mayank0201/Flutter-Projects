import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';

class MinesweeperBetaScreen extends StatefulWidget {
  const MinesweeperBetaScreen({super.key});
  @override
  State<MinesweeperBetaScreen> createState() => _MinesweeperBetaScreenState();
}
class _MinesweeperBetaScreenState extends State<MinesweeperBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<bool> _mines = List.filled(16, false);
  List<bool> _revealed = List.filled(16, false);
  List<bool> _flagged = List.filled(16, false);

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }
  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      _mines = List.filled(16, false);
      _revealed = List.filled(16, false);
      _flagged = List.filled(16, false);
      if (_currentLevel == 0) {
        _mines[2] = true; _mines[5] = true;
      } else if (_currentLevel == 1) {
        _mines[0] = true; _mines[15] = true;
      } else if (_currentLevel == 2) {
        _mines[3] = true; _mines[12] = true;
      } else if (_currentLevel == 3) {
        _mines[1] = true; _mines[6] = true; _mines[11] = true;
      } else {
        _mines[4] = true; _mines[9] = true; _mines[14] = true;
      }
    });
  }
  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_minesweeper') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_minesweeper', _currentLevel + 1);
    }
    setState(() => _isSuccess = true);
  }
  void _nextLevel() {
    if (_currentLevel < 4) {
      setState(() {
        _currentLevel++;
        _loadLevel();
      });
    } else {
      Navigator.pop(context);
    }
  }
  int _countMines(int idx) {
    int r = idx ~/ 4; int c = idx % 4;
    int count = 0;
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        int nr = r + dr; int nc = c + dc;
        if (nr >= 0 && nr < 4 && nc >= 0 && nc < 4) {
          if (_mines[nr * 4 + nc]) count++;
        }
      }
    }
    return count;
  }
  void _revealCell(int idx) {
    if (_mines[idx]) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Boom! Hit a mine.')));
      _loadLevel();
      return;
    }
    setState(() {
      _revealed[idx] = true;
      _checkWin();
    });
  }
  void _checkWin() {
    bool win = true;
    for (int i = 0; i < 16; i++) {
      if (!_mines[i] && !_revealed[i]) win = false;
    }
    if (win) {
      _onLevelCleared();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Minesweeper', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('Level ${_currentLevel + 1}/5', style: AppTheme.numberStyle(color: AppTheme.dustyMauve, fontSize: 14, fontWeight: FontWeight.bold))),
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
                        Text('Reveal all safe cells. Tap to reveal, long press to flag a mine.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary)),
                        const SizedBox(height: 24),
                        Container(
                          width: 280, height: 280,
                          decoration: BoxDecoration(border: Border.all(color: context.textMuted, width: 2)),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
                            itemCount: 16,
                            itemBuilder: (context, idx) {
                              bool rev = _revealed[idx];
                              bool flag = _flagged[idx];
                              return GestureDetector(
                                onTap: () => _revealCell(idx),
                                onLongPress: () => setState(() => _flagged[idx] = !_flagged[idx]),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: rev ? Colors.grey.shade800 : context.bgCard,
                                    border: Border.all(color: Colors.grey.shade900),
                                  ),
                                  child: Center(
                                    child: flag
                                        ? const Icon(Icons.flag, color: Colors.red)
                                        : (rev ? Text('${_countMines(idx)}', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold)) : null),
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
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dustyMauve, foregroundColor: Colors.white),
                        onPressed: _nextLevel,
                        child: Text(_currentLevel < 4 ? 'Next Level' : 'Finish'),
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
