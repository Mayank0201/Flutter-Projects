import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';

class KakuroBetaScreen extends StatefulWidget {
  const KakuroBetaScreen({super.key});
  @override
  State<KakuroBetaScreen> createState() => _KakuroBetaScreenState();
}
class _KakuroBetaScreenState extends State<KakuroBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _grid = List.filled(16, 0);
  List<int> _types = [0, 2, 2, 0, 2, 1, 1, 0, 2, 1, 1, 2, 0, 0, 2, 0];
  List<int> _hClues = [0, 0, 0, 0, 15, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0];
  List<int> _vClues = [0, 9, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
  int _selectedIdx = -1;

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      _selectedIdx = -1;
      _grid = List.filled(16, 0);
      _types = [0, 2, 2, 0, 2, 1, 1, 0, 2, 1, 1, 2, 0, 0, 2, 0];
      if (_currentLevel == 0) {
        _hClues = [0, 0, 0, 0, 15, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0];
        _vClues = [0, 9, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
      } else if (_currentLevel == 1) {
        _hClues = [0, 0, 0, 0, 10, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0];
        _vClues = [0, 15, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
      } else if (_currentLevel == 2) {
        _hClues = [0, 0, 0, 0, 13, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0];
        _vClues = [0, 15, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
      } else if (_currentLevel == 3) {
        _hClues = [0, 0, 0, 0, 10, 0, 0, 0, 13, 0, 0, 0, 0, 0, 0, 0];
        _vClues = [0, 16, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
      } else if (_currentLevel == 4) {
        _hClues = [0, 0, 0, 0, 11, 0, 0, 0, 13, 0, 0, 0, 0, 0, 0, 0];
        _vClues = [0, 15, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
      } else if (_currentLevel == 5) {
        _hClues = [0, 0, 0, 0, 15, 0, 0, 0, 11, 0, 0, 0, 0, 0, 0, 0];
        _vClues = [0, 9, 17, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
      } else if (_currentLevel == 6) {
        _hClues = [0, 0, 0, 0, 9, 0, 0, 0, 14, 0, 0, 0, 0, 0, 0, 0];
        _vClues = [0, 8, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
      } else if (_currentLevel == 7) {
        _hClues = [0, 0, 0, 0, 12, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0];
        _vClues = [0, 11, 17, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
      } else if (_currentLevel == 8) {
        _hClues = [0, 0, 0, 0, 6, 0, 0, 0, 13, 0, 0, 0, 0, 0, 0, 0];
        _vClues = [0, 7, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
      } else {
        _hClues = [0, 0, 0, 0, 12, 0, 0, 0, 13, 0, 0, 0, 0, 0, 0, 0];
        _vClues = [0, 8, 17, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
      }
    });
  }

  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_kakuro') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_kakuro', _currentLevel + 1);
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
    for (int i = 0; i < 16; i++) {
      if (_types[i] == 1 && _grid[i] == 0) isValid = false;
    }
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill all entry cells!')));
      return;
    }
    
    for (int idx = 0; idx < 16; idx++) {
      if (_types[idx] == 2) {
        int hc = _hClues[idx];
        int vc = _vClues[idx];
        if (hc > 0) {
          List<int> run = [];
          int x = idx + 1;
          while (x % 4 != 0 && _types[x] == 1) {
            run.add(_grid[x]);
            x++;
          }
          if (run.isNotEmpty) {
            if (run.reduce((a, b) => a + b) != hc || run.toSet().length != run.length) {
              isValid = false;
            }
          }
        }
        if (vc > 0) {
          List<int> run = [];
          int y = idx + 4;
          while (y < 16 && _types[y] == 1) {
            run.add(_grid[y]);
            y += 4;
          }
          if (run.isNotEmpty) {
            if (run.reduce((a, b) => a + b) != vc || run.toSet().length != run.length) {
              isValid = false;
            }
          }
        }
      }
    }
    if (isValid) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect solution! Check clues and make sure digits in a run are unique.')));
    }
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text('How to Play Kakuro', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
        content: Text(
          '1. Fill the empty white cells with digits 1-9.\n\n'
          '2. The sum of each horizontal block must equal the clue number to its left.\n\n'
          '3. The sum of each vertical block must equal the clue number above it.\n\n'
          '4. No digit can be repeated within a single run (row or column block).',
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
      [0, 0, 0, 0, 0, 8, 7, 0, 0, 1, 5, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 7, 3, 0, 0, 8, 2, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 8, 5, 0, 0, 7, 1, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 7, 3, 0, 0, 9, 4, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 9, 2, 0, 0, 6, 7, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 6, 9, 0, 0, 3, 8, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 2, 7, 0, 0, 6, 8, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 4, 8, 0, 0, 7, 9, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 1, 5, 0, 0, 6, 7, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 3, 9, 0, 0, 5, 8, 0, 0, 0, 0, 0],
    ];
    final sol = solutions[_currentLevel];
    int hintCell = -1;
    for (int i = 0; i < 16; i++) {
      if (_types[i] == 1 && _grid[i] != sol[i]) {
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
        title: Text('Kakuro', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        Text('Fill entry cells with digits 1-9 to match clues.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                            RepaintBoundary(
                              child: Container(
                                width: 280, height: 280,
                                decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.textMuted.withAlpha(40))),
                                child: GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
                                  itemCount: 16,
                                  itemBuilder: (context, idx) {
                                    int type = _types[idx];
                                    if (type == 0) return Container(color: Colors.grey[900]);
                                    if (type == 2) {
                                      return Container(
                                        color: Colors.grey[950],
                                        child: CustomPaint(painter: _KakuroCluePainter(_hClues[idx], _vClues[idx])),
                                      );
                                    }
                                    return GestureDetector(
                                      onTap: () {
                                        settingsNotifier.hapticTap();
                                        setState(() => _selectedIdx = idx);
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: context.bgCard,
                                          border: Border.all(
                                            color: _selectedIdx == idx ? AppTheme.dustyMauve : context.textMuted.withAlpha(50),
                                            width: _selectedIdx == idx ? 2 : 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            _grid[idx] == 0 ? "" : "${_grid[idx]}",
                                            style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (int i = 1; i <= 9; i++) ...[
                                    GestureDetector(
                                      onTap: () {
                                        if (_selectedIdx != -1 && _types[_selectedIdx] == 1) {
                                          settingsNotifier.hapticTap();
                                          setState(() {
                                            _grid[_selectedIdx] = i;
                                          });
                                        }
                                      },
                                      child: Container(
                                        width: 38, height: 38,
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.dustyMauve,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text('$i', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                        ),
                                      ),
                                    ),
                                  ],
                                  GestureDetector(
                                    onTap: () {
                                      if (_selectedIdx != -1 && _types[_selectedIdx] == 1) {
                                        settingsNotifier.hapticTap();
                                        setState(() {
                                          _grid[_selectedIdx] = 0;
                                        });
                                      }
                                    },
                                    child: Container(
                                      width: 38, height: 38,
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade800,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.clear, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ),
                                ],
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
class _KakuroCluePainter extends CustomPainter {
  final int hSum; final int vSum;
  _KakuroCluePainter(this.hSum, this.vSum);
  @override
  void paint(Canvas canvas, Size size) {
    Paint lp = Paint()..color = Colors.grey..strokeWidth = 1.0;
    canvas.drawLine(const Offset(0, 0), Offset(size.width, size.height), lp);
    TextPainter tp;
    if (hSum > 0) {
      tp = TextPainter(text: TextSpan(text: '$hSum', style: GoogleFonts.spaceGrotesk(fontSize: 10, color: Colors.white)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(size.width * 0.55, size.height * 0.15));
    }
    if (vSum > 0) {
      tp = TextPainter(text: TextSpan(text: '$vSum', style: GoogleFonts.spaceGrotesk(fontSize: 10, color: Colors.white)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(size.width * 0.15, size.height * 0.55));
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
