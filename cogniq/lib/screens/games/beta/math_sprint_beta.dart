import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';

class MathSprintBetaScreen extends StatefulWidget {
  const MathSprintBetaScreen({super.key});
  @override
  State<MathSprintBetaScreen> createState() => _MathSprintBetaScreenState();
}
class _MathSprintBetaScreenState extends State<MathSprintBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  int _score = 0;
  String _equation = "";
  bool _correctAnswer = true;

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }
  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      _score = 0;
      _generateEquation();
    });
  }
  void _generateEquation() {
    int a = 3 + _score;
    int b = 4 + _score;
    bool isTrue = (a + b) % 2 == 0;
    setState(() {
      _correctAnswer = isTrue;
      if (isTrue) {
        _equation = "$a + $b = ${a + b}";
      } else {
        _equation = "$a + $b = ${a + b + 2}";
      }
    });
  }
  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_mathsprint') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_mathsprint', _currentLevel + 1);
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
  void _answer(bool val) {
    if (val == _correctAnswer) {
      settingsNotifier.hapticTap();
      setState(() {
        _score++;
        if (_score >= 5) {
          _onLevelCleared();
        } else {
          _generateEquation();
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wrong answer! Score reset.')));
      setState(() {
        _score = 0;
        _generateEquation();
      });
    }
  }
  void _showHint() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Hint: The current equation is ${_correctAnswer ? "True" : "False"}.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Math Sprint', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        Text('Get 5 correct answers in a row to clear the level.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary)),
                        const SizedBox(height: 32),
                        Text('Score: $_score/5', style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.dustyMauve)),
                        const SizedBox(height: 32),
                        Text(_equation, style: GoogleFonts.spaceGrotesk(fontSize: 40, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: () => _answer(false), icon: const Icon(Icons.close), label: const Text('False'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      onPressed: () => _answer(true), icon: const Icon(Icons.check), label: const Text('True'),
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
