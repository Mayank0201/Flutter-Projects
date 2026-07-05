import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';

class MentalMathBlocksBetaScreen extends StatefulWidget {
  const MentalMathBlocksBetaScreen({super.key});
  @override
  State<MentalMathBlocksBetaScreen> createState() => _MentalMathBlocksBetaScreenState();
}
class _MentalMathBlocksBetaScreenState extends State<MentalMathBlocksBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  int _target = 10;
  final List<int> _blocks = [3, 4, 6, 2, 7, 1, 5, 8, 9];
  List<bool> _selected = List.filled(9, false);

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }
  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      _selected = List.filled(9, false);
      _target = 10 + _currentLevel * 2;
    });
  }
  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_mathblocks') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_mathblocks', _currentLevel + 1);
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
  void _checkSum() {
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      if (_selected[i]) sum += _blocks[i];
    }
    if (sum == _target) {
      settingsNotifier.hapticTap();
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sum is $sum, but target is $_target!')));
    }
  }
  void _showHint() {
    List<int> solutionIndices = [];
    bool found = false;
    void backtrack(int index, int currentSum, List<int> currentIndices) {
      if (found) return;
      if (currentSum == _target) {
        solutionIndices = List.from(currentIndices);
        found = true;
        return;
      }
      if (currentSum > _target || index >= _blocks.length) return;
      
      currentIndices.add(index);
      backtrack(index + 1, currentSum + _blocks[index], currentIndices);
      currentIndices.removeLast();
      
      backtrack(index + 1, currentSum, currentIndices);
    }
    backtrack(0, 0, []);
    
    if (found && solutionIndices.isNotEmpty) {
      setState(() {
        for (int i = 0; i < 9; i++) {
          _selected[i] = solutionIndices.contains(i);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Hint: Selected blocks that sum to $_target!'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Mental Math Blocks', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
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
                        Text('Select blocks whose sum adds up exactly to the target.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary)),
                        const SizedBox(height: 24),
                        Text('Target: $_target', style: GoogleFonts.spaceGrotesk(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.dustyMauve)),
                        const SizedBox(height: 24),
                        Container(
                          width: 240, height: 240,
                          decoration: BoxDecoration(border: Border.all(color: context.textMuted, width: 2)),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
                            itemCount: 9,
                            itemBuilder: (context, idx) {
                              bool isSel = _selected[idx];
                              return GestureDetector(
                                onTap: () => setState(() => _selected[idx] = !isSel),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSel ? AppTheme.dustyMauve : context.bgCard,
                                    border: Border.all(color: Colors.grey.shade900),
                                  ),
                                  child: Center(
                                    child: Text('${_blocks[idx]}', style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold, color: isSel ? Colors.white : context.textPrimary)),
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

                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: context.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.textMuted.withAlpha(20)),
                  ),
                  child: Text(
                    '💡 Rule Details:\n• Blocks with numbers fall down the board.\n• Combine them to reach the target value.\n• Act fast before the blocks pile up.',
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
                      onPressed: _checkSum, icon: const Icon(Icons.check), label: const Text('Check'),
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
