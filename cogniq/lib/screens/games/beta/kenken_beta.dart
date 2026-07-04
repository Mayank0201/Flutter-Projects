import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';

class KenKenBetaScreen extends StatefulWidget {
  const KenKenBetaScreen({super.key});
  @override
  State<KenKenBetaScreen> createState() => _KenKenBetaScreenState();
}
class _KenKenBetaScreenState extends State<KenKenBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  List<int> _grid = List.filled(9, 0);
  List<int> _cages = [0, 0, 1, 2, 3, 1, 2, 3, 4];
  List<String> _cageOps = ["+", "+", "/", "/", "+"];
  List<int> _cageTargets = [5, 3, 3, 2, 3];
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
      _grid = List.filled(9, 0);
      if (_currentLevel == 0) {
        _cages = [0, 0, 1, 2, 3, 1, 2, 3, 4];
        _cageOps = ["+", "+", "/", "/", "+"];
        _cageTargets = [5, 3, 3, 2, 3];
      } else if (_currentLevel == 1) {
        _cages = [0, 1, 2, 0, 1, 2, 3, 4, 4];
        _cageOps = ["-", "+", "*", "+", "*"];
        _cageTargets = [1, 3, 3, 1, 6];
      } else if (_currentLevel == 2) {
        _cages = [0, 0, 1, 2, 3, 1, 4, 3, 5];
        _cageOps = ["/", "*", "+", "*", "+", "+"];
        _cageTargets = [2, 3, 3, 6, 1, 2];
      } else if (_currentLevel == 3) {
        _cages = [0, 0, 1, 2, 2, 1, 3, 3, 4];
        _cageOps = ["/", "-", "/", "+", "+"];
        _cageTargets = [2, 1, 3, 5, 1];
      } else if (_currentLevel == 4) {
        _cages = [0, 0, 1, 2, 3, 1, 4, 4, 5];
        _cageOps = ["-", "+", "+", "+", "/", "+"];
        _cageTargets = [1, 4, 1, 2, 3, 2];
      } else if (_currentLevel == 5) {
        _cages = [0, 1, 1, 0, 2, 2, 3, 3, 4];
        _cageOps = ["-", "+", "*", "+", "+"];
        _cageTargets = [1, 4, 2, 3, 3];
      } else if (_currentLevel == 6) {
        _cages = [0, 0, 1, 2, 3, 3, 2, 4, 4];
        _cageOps = ["+", "+", "/", "-", "*"];
        _cageTargets = [3, 3, 3, 1, 6];
      } else if (_currentLevel == 7) {
        _cages = [0, 1, 1, 2, 2, 3, 4, 4, 3];
        _cageOps = ["+", "+", "-", "*", "+"];
        _cageTargets = [2, 4, 1, 2, 4];
      } else if (_currentLevel == 8) {
        _cages = [0, 0, 1, 2, 2, 1, 3, 3, 4];
        _cageOps = ["*", "+", "+", "-", "+"];
        _cageTargets = [2, 5, 4, 1, 1];
      } else {
        _cages = [0, 1, 1, 2, 2, 3, 4, 4, 3];
        _cageOps = ["+", "-", "+", "*", "/"];
        _cageTargets = [2, 2, 3, 6, 3];
      }
    });
  }

  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_kenken') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_kenken', _currentLevel + 1);
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
    for (int i = 0; i < 9; i++) {
      if (_grid[i] == 0) isValid = false;
    }
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill all cells!')));
      return;
    }
    
    for (int i = 0; i < 3; i++) {
      var row = [_grid[i*3], _grid[i*3+1], _grid[i*3+2]];
      var col = [_grid[i], _grid[i+3], _grid[i+6]];
      if (row.toSet().length != 3 || col.toSet().length != 3) isValid = false;
    }
    
    Map<int, List<int>> cageVals = {};
    for (int i = 0; i < 9; i++) {
      cageVals.putIfAbsent(_cages[i], () => []).add(_grid[i]);
    }
    
    cageVals.forEach((cageId, vals) {
      String op = _cageOps[cageId];
      int target = _cageTargets[cageId];
      if (vals.length == 1) {
        if (vals[0] != target) isValid = false;
        return;
      }
      if (op == "+") {
        int sum = vals.reduce((a, b) => a + b);
        if (sum != target) isValid = false;
      } else if (op == "*") {
        int prod = vals.reduce((a, b) => a * b);
        if (prod != target) isValid = false;
      } else if (op == "-") {
        if (vals.length < 2 || (vals[0] - vals[1]).abs() != target) isValid = false;
      } else if (op == "/") {
        if (vals.length < 2) {
          isValid = false;
        } else {
          double div = vals[0] > vals[1] ? vals[0] / vals[1] : vals[1] / vals[0];
          if (div != target.toDouble()) isValid = false;
        }
      }
    });

    if (isValid) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect solution! Check rows, columns, and cage math.')));
    }
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text('How to Play Calcudoku', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
        content: Text(
          '1. Fill each row and column with digits 1 to 3 without repeating.\n\n'
          '2. The grid is divided into outlined cages.\n\n'
          '3. The numbers in each cage must combine using the mathematical operator (+, -, *, /) to match the target shown in the corner.\n\n'
          '4. Single-cell cages just require placing the target digit.',
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
      [2, 3, 1, 3, 1, 2, 1, 2, 3],
      [2, 1, 3, 3, 2, 1, 1, 3, 2],
      [2, 1, 3, 3, 2, 1, 1, 3, 2],
      [2, 1, 3, 1, 3, 2, 3, 2, 1],
      [2, 3, 1, 1, 2, 3, 3, 1, 2],
      [2, 3, 1, 3, 1, 2, 1, 2, 3],
      [2, 1, 3, 3, 2, 1, 1, 3, 2],
      [2, 1, 3, 3, 2, 1, 1, 3, 2],
      [2, 1, 3, 1, 3, 2, 3, 2, 1],
      [2, 3, 1, 1, 2, 3, 3, 1, 2],
    ];
    final sol = solutions[_currentLevel];
    int hintCell = -1;
    for (int i = 0; i < 9; i++) {
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
        title: Text('Calcudoku', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Fill the 3x3 grid with digits 1-3. Cage cells must combine mathematically to match the target value.',
                            style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                            RepaintBoundary(
                              child: Container(
                                width: 280, height: 280,
                                decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.textMuted.withAlpha(40))),
                                child: GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
                                  itemCount: 9,
                                  itemBuilder: (context, idx) {
                                    int cageId = _cages[idx];
                                    Color cageColor = Colors.primaries[cageId % Colors.primaries.length].withOpacity(0.12);
                                    bool isCageStart = _cages.indexOf(cageId) == idx;
                                    return GestureDetector(
                                      onTap: () {
                                        settingsNotifier.hapticTap();
                                        setState(() => _selectedIdx = idx);
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: cageColor,
                                          border: Border(
                                            top: BorderSide(color: idx >= 3 && _cages[idx - 3] == cageId ? Colors.transparent : Colors.black, width: 1.5),
                                            bottom: BorderSide(color: idx < 6 && _cages[idx + 3] == cageId ? Colors.transparent : Colors.black, width: 1.5),
                                            left: BorderSide(color: idx % 3 > 0 && _cages[idx - 1] == cageId ? Colors.transparent : Colors.black, width: 1.5),
                                            right: BorderSide(color: idx % 3 < 2 && _cages[idx + 1] == cageId ? Colors.transparent : Colors.black, width: 1.5),
                                          ),
                                        ),
                                        child: Stack(
                                          children: [
                                            if (isCageStart)
                                              Positioned(top: 2, left: 2, child: Text('${_cageTargets[cageId]}${_cageOps[cageId]}', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold))),
                                            Center(
                                              child: Text(
                                                _grid[idx] == 0 ? "" : "${_grid[idx]}",
                                                style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary),
                                              ),
                                            ),
                                            if (_selectedIdx == idx)
                                              Container(
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: AppTheme.dustyMauve, width: 2),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (int i = 1; i <= 3; i++) ...[
                                  GestureDetector(
                                    onTap: () {
                                      if (_selectedIdx != -1) {
                                        settingsNotifier.hapticTap();
                                        setState(() {
                                          _grid[_selectedIdx] = i;
                                        });
                                      }
                                    },
                                    child: Container(
                                      width: 44, height: 44,
                                      margin: const EdgeInsets.symmetric(horizontal: 6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.dustyMauve,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text('$i', style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                    ),
                                  ),
                                ],
                                GestureDetector(
                                  onTap: () {
                                    if (_selectedIdx != -1) {
                                      settingsNotifier.hapticTap();
                                      setState(() {
                                        _grid[_selectedIdx] = 0;
                                      });
                                    }
                                  },
                                  child: Container(
                                    width: 44, height: 44,
                                    margin: const EdgeInsets.symmetric(horizontal: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade800,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.clear, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.bgCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.textMuted.withAlpha(20)),
                              ),
                              child: Text(
                                '💡 Rule Details:\n• No repeats: Rows/columns must contain 1, 2, and 3 exactly once.\n• Cage Target: E.g., "5+" means cage cells sum to 5. "2/" means division (large/small) equals 2. "3*" means product is 3.',
                                style: GoogleFonts.outfit(fontSize: 12, color: context.textSecondary),
                              ),
                            ),
                        ],
                      ),
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
