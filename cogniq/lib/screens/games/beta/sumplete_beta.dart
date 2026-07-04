import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';

class SumpleteBetaScreen extends StatefulWidget {
  const SumpleteBetaScreen({super.key});
  @override
  State<SumpleteBetaScreen> createState() => _SumpleteBetaScreenState();
}
class _SumpleteBetaScreenState extends State<SumpleteBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _grid = [];
  List<bool> _keep = [];
  List<int> _rowTargets = [];
  List<int> _colTargets = [];

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      if (_currentLevel == 0) {
        _grid = [3, 4, 5, 1, 3, 5, 1, 1, 1];
        _rowTargets = [12, 3, 2];
        _colTargets = [4, 7, 6];
      } else if (_currentLevel == 1) {
        _grid = [4, 4, 2, 2, 3, 3, 3, 5, 4];
        _rowTargets = [2, 5, 5];
        _colTargets = [2, 5, 5];
      } else if (_currentLevel == 2) {
        _grid = [5, 5, 4, 1, 1, 1, 1, 4, 5];
        _rowTargets = [5, 2, 5];
        _colTargets = [2, 9, 1];
      } else if (_currentLevel == 3) {
        _grid = [2, 3, 5, 4, 4, 3, 2, 3, 3];
        _rowTargets = [8, 8, 2];
        _colTargets = [6, 7, 5];
      } else if (_currentLevel == 4) {
        _grid = [4, 5, 3, 1, 2, 1, 2, 4, 4];
        _rowTargets = [12, 2, 4];
        _colTargets = [4, 7, 7];
      } else if (_currentLevel == 5) {
        _grid = [2, 3, 4, 5, 1, 2, 3, 4, 1];
        _rowTargets = [7, 7, 7];
        _colTargets = [8, 7, 6];
      } else if (_currentLevel == 6) {
        _grid = [4, 2, 3, 1, 5, 2, 1, 3, 4];
        _rowTargets = [7, 5, 5];
        _colTargets = [5, 5, 7];
      } else if (_currentLevel == 7) {
        _grid = [3, 2, 4, 5, 1, 3, 2, 4, 5];
        _rowTargets = [5, 4, 7];
        _colTargets = [5, 3, 8];
      } else if (_currentLevel == 8) {
        _grid = [1, 5, 4, 3, 2, 5, 1, 3, 4];
        _rowTargets = [9, 5, 7];
        _colTargets = [3, 10, 8];
      } else {
        _grid = [5, 4, 3, 2, 1, 5, 2, 4, 3];
        _rowTargets = [8, 8, 4];
        _colTargets = [7, 5, 8];
      }
      _keep = List.filled(9, true);
    });
  }

  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_sumplete') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_sumplete', _currentLevel + 1);
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
    for (int i = 0; i < 3; i++) {
      int rSum = 0;
      for (int j = 0; j < 3; j++) {
        if (_keep[i * 3 + j]) rSum += _grid[i * 3 + j];
      }
      if (rSum != _rowTargets[i]) isValid = false;

      int cSum = 0;
      for (int j = 0; j < 3; j++) {
        if (_keep[j * 3 + i]) cSum += _grid[j * 3 + i];
      }
      if (cSum != _colTargets[i]) isValid = false;
    }
    if (isValid) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sums do not match targets! Check rows and columns.')));
    }
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text('How to Play Sum Strike', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
        content: Text(
          '1. Delete (cross out) numbers in the grid so that the sum of the remaining numbers in each row and column matches the target numbers at the borders.\n\n'
          '2. Tap a cell to toggle it between kept (highlighted) and deleted (crossed out).',
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
      [true, true, true, false, true, false, true, false, true],
      [false, false, true, true, false, true, false, true, false],
      [false, true, false, true, false, true, true, true, false],
      [false, true, true, true, true, false, true, false, false],
      [true, true, true, false, true, false, false, false, true],
      [false, true, true, true, false, true, true, true, false],
      [true, false, true, false, true, false, true, false, true],
      [true, true, false, false, true, true, true, false, true],
      [false, true, true, true, true, false, false, true, true],
      [true, false, true, true, true, true, false, true, false],
    ];
    final sol = solutions[_currentLevel];
    int hintCell = -1;
    for (int i = 0; i < 9; i++) {
      if (_keep[i] != sol[i]) {
        hintCell = i;
        break;
      }
    }
    
    if (hintCell != -1) {
      setState(() {
        _keep[hintCell] = sol[hintCell];
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
        title: Text('Sum Strike', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        Text('Tap numbers to delete them so the remaining numbers in each row and col sum to the target.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        Container(
                          width: 320, height: 320,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.textMuted.withAlpha(40))),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
                            itemCount: 16,
                            itemBuilder: (context, idx) {
                              int r = idx ~/ 4;
                              int c = idx % 4;
                              if (r == 3 && c == 3) return const SizedBox.shrink();
                              if (r == 3) {
                                return Center(child: Text('${_colTargets[c]}', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.dustyMauve)));
                              }
                              if (c == 3) {
                                return Center(child: Text('${_rowTargets[r]}', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.dustyMauve)));
                              }
                              int gridIdx = r * 3 + c;
                              bool isKept = _keep[gridIdx];
                              return GestureDetector(
                                onTap: () => setState(() => _keep[gridIdx] = !_keep[gridIdx]),
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isKept ? context.bgSurface : context.bgDark,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isKept ? AppTheme.dustyMauve : Colors.grey.shade900),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${_grid[gridIdx]}',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: isKept ? context.textPrimary : context.textMuted.withOpacity(0.3),
                                        decoration: isKept ? null : TextDecoration.lineThrough,
                                      ),
                                    ),
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
