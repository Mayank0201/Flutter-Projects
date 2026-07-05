import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';

class BinairoBetaScreen extends StatefulWidget {
  const BinairoBetaScreen({super.key});
  @override
  State<BinairoBetaScreen> createState() => _BinairoBetaScreenState();
}

class _BinairoBetaScreenState extends State<BinairoBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  int _size = 4;
  List<int> _grid = List.filled(16, -1);
  List<bool> _locked = List.filled(16, false);

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      if (_currentLevel == 0) {
        _size = 4;
        _grid = [1, -1, -1, 1, -1, 1, -1, -1, -1, -1, -1, 0, 0, -1, 0, -1];
      } else if (_currentLevel == 1) {
        _size = 4;
        _grid = [-1, 1, -1, -1, 1, -1, -1, -1, -1, 0, 0, -1, -1, -1, -1, 1];
      } else if (_currentLevel == 2) {
        _size = 4;
        _grid = [1, -1, 1, -1, -1, -1, -1, 1, 1, -1, -1, 1, -1, 1, -1, -1];
      } else if (_currentLevel == 3) {
        _size = 4;
        _grid = [0, -1, -1, 1, -1, 0, 1, -1, -1, -1, 0, -1, 1, -1, 1, -1];
      } else if (_currentLevel == 4) {
        _size = 4;
        _grid = [-1, 0, -1, -1, -1, -1, 1, -1, 0, -1, -1, 1, 1, -1, -1, -1];
      } else if (_currentLevel == 5) {
        _size = 6;
        _grid = [-1, 0, 1, 1, 0, -1, -1, 0, -1, -1, -1, -1, -1, 1, 0, 0, -1, 1, 1, -1, -1, 1, -1, 0, -1, -1, -1, -1, -1, 1, -1, -1, -1, 0, -1, -1];
      } else if (_currentLevel == 6) {
        _size = 6;
        _grid = [1, -1, 1, 1, -1, -1, -1, -1, -1, 0, -1, -1, -1, -1, 0, 0, -1, -1, 1, 1, -1, 1, 0, 0, -1, 0, -1, -1, 0, 1, -1, -1, -1, -1, -1, -1];
      } else if (_currentLevel == 7) {
        _size = 6;
        _grid = [1, -1, -1, 1, -1, 0, -1, 0, -1, 0, -1, 1, -1, -1, -1, -1, -1, -1, 1, -1, -1, -1, -1, -1, 0, -1, 1, -1, 0, -1, 1, -1, -1, 0, 1, 0];
      } else if (_currentLevel == 8) {
        _size = 6;
        _grid = [1, -1, 1, 1, -1, 0, -1, -1, -1, 0, 1, -1, -1, -1, -1, 0, 1, 1, -1, -1, -1, -1, -1, -1, 0, -1, 1, -1, 0, -1, 1, 1, -1, -1, -1, -1];
      } else {
        _size = 6;
        _grid = [1, 0, 1, -1, 0, -1, -1, -1, -1, 0, 1, -1, -1, -1, 0, -1, -1, 1, 1, -1, 0, -1, -1, -1, -1, 0, -1, 1, -1, -1, -1, -1, -1, 0, 1, -1];
      }
      _locked = _grid.map((e) => e != -1).toList();
    });
  }

  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_binairo') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_binairo', _currentLevel + 1);
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
    if (_grid.any((e) => e == -1)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill all cells!')));
      return;
    }
    bool isValid = true;
    bool checkLine(List<int> line) {
      int zeros = line.where((e) => e == 0).length;
      int ones = line.where((e) => e == 1).length;
      if (zeros != ones) return false;
      for (int i = 0; i < line.length - 2; i++) {
        if (line[i] == line[i + 1] && line[i] == line[i + 2]) return false;
      }
      return true;
    }

    List<List<int>> rows = [];
    List<List<int>> cols = [];
    for (int i = 0; i < _size; i++) {
      List<int> r = [];
      List<int> c = [];
      for (int j = 0; j < _size; j++) {
        r.add(_grid[i * _size + j]);
        c.add(_grid[j * _size + i]);
      }
      rows.add(r);
      cols.add(c);
      if (!checkLine(r) || !checkLine(c)) isValid = false;
    }
    for (int i = 0; i < _size; i++) {
      for (int j = i + 1; j < _size; j++) {
        if (rows[i].join() == rows[j].join()) isValid = false;
        if (cols[i].join() == cols[j].join()) isValid = false;
      }
    }
    if (isValid) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rule violation detected!')));
    }
  }

  void _showHint() {
    final solutions = [
      [1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1],
      [0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1],
      [1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0],
      [0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0],
      [1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1],
      [1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 0, 1, 1, 1, 0, 0, 1, 0],
      [1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 0, 1, 1, 1, 0, 0, 1, 0],
      [1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 0, 1, 1, 1, 0, 0, 1, 0],
      [1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 0, 1, 1, 1, 0, 0, 1, 0],
      [1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 0, 1, 1, 1, 0, 0, 1, 0],
    ];
    final sol = solutions[_currentLevel];
    int hintCell = -1;
    for (int i = 0; i < _grid.length; i++) {
      if (_grid[i] != sol[i]) {
        hintCell = i;
        break;
      }
    }
    if (hintCell != -1) {
      settingsNotifier.hapticTap();
      setState(() {
        _grid[hintCell] = sol[hintCell];
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The board is already correctly solved!')));
    }
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text('How to Play Takuzu', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
        content: Text(
          '1. Fill the grid with 0s and 1s.\n\n'
          '2. Each row and column must contain an equal number of 0s and 1s.\n\n'
          '3. No more than two adjacent cells in a row or column can contain the same number.\n\n'
          '4. No two rows or columns can be identical.',
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
        title: Text('Takuzu', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        Text('Fill the grid with 0s and 1s. Equal counts of 0s and 1s, max 2 consecutive.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary)),
                        const SizedBox(height: 24),
                        RepaintBoundary(
                          child: Container(
                            width: 280, height: 280,
                            decoration: BoxDecoration(border: Border.all(color: context.textMuted, width: 2), borderRadius: BorderRadius.circular(12)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _size),
                                itemCount: _size * _size,
                                itemBuilder: (context, idx) {
                                  bool isLock = _locked[idx];
                                  int val = _grid[idx];
                                  return GestureDetector(
                                    onTap: () {
                                      if (isLock) return;
                                      settingsNotifier.hapticTap();
                                      setState(() {
                                        if (val == -1) {
                                          _grid[idx] = 0;
                                        } else if (val == 0) {
                                          _grid[idx] = 1;
                                        } else {
                                          _grid[idx] = -1;
                                        }
                                      });
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isLock ? context.bgSurface.withAlpha(200) : context.bgSurface,
                                        border: Border.all(color: context.textMuted.withAlpha(40), width: 0.5),
                                      ),
                                      child: Center(
                                        child: Text(
                                          val == -1 ? '' : '$val',
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: isLock
                                                ? context.textMuted
                                                : (val == 0 ? Colors.blue : Colors.red),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                    '💡 Rule Details:\n• Fill every cell with 0 or 1.\n• No more than two of the same number adjacent in a row or column.\n• Each row and column has an equal count of 0s and 1s.\n• No two rows (or two columns) are identical.',
                    style: GoogleFonts.outfit(fontSize: 12, color: context.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),
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
