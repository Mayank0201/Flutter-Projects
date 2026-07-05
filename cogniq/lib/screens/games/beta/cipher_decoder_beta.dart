import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';

class CipherDecoderBetaScreen extends StatefulWidget {
  const CipherDecoderBetaScreen({super.key});
  @override
  State<CipherDecoderBetaScreen> createState() => _CipherDecoderBetaScreenState();
}

class _CipherDecoderBetaScreenState extends State<CipherDecoderBetaScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  String _encoded = "";
  String _target = "";
  int _currentShift = 1;
  // One editable guess per cipher position. Letter positions start at 'A';
  // non-letter positions (spaces/punctuation) store the character itself and
  // are not editable.
  List<String> _guesses = [];

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  bool _isLetter(String c) => c.length == 1 && c.codeUnitAt(0) >= 65 && c.codeUnitAt(0) <= 90;

  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      if (_currentLevel == 0) {
        _target = "HELLO";
        _encoded = "IFMMP"; // Shift +1
        _currentShift = 1;
      } else if (_currentLevel == 1) {
        _target = "WORLD";
        _encoded = "YQTNF"; // Shift +2
        _currentShift = 2;
      } else if (_currentLevel == 2) {
        _target = "COGNIQ";
        _encoded = "FRJQLT"; // Shift +3
        _currentShift = 3;
      } else if (_currentLevel == 3) {
        _target = "PUZZLE";
        _encoded = "TYDDPI"; // Shift +4
        _currentShift = 4;
      } else if (_currentLevel == 4) {
        _target = "CIPHER";
        _encoded = "HNUMJW"; // Shift +5
        _currentShift = 5;
      } else if (_currentLevel == 5) {
        _target = "FLUTTER";
        _encoded = "GMVUUFS"; // Shift +1
        _currentShift = 1;
      } else if (_currentLevel == 6) {
        _target = "MOBILE";
        _encoded = "OQDKNG"; // Shift +2
        _currentShift = 2;
      } else if (_currentLevel == 7) {
        _target = "SECRET";
        _encoded = "VHFUHW"; // Shift +3
        _currentShift = 3;
      } else if (_currentLevel == 8) {
        _target = "LOGICAL";
        _encoded = "PSKMGEP"; // Shift +4
        _currentShift = 4;
      } else {
        _target = "BRAIN";
        _encoded = "GWFNS"; // Shift +5
        _currentShift = 5;
      }

      _guesses = [
        for (int i = 0; i < _encoded.length; i++)
          _isLetter(_encoded[i]) ? 'A' : _encoded[i],
      ];
    });
  }

  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_cipherdecoder') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_cipherdecoder', _currentLevel + 1);
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

  // Shift a single letter one step. dir = +1 (A->B->...->Z->A) or -1 (A->Z wrap).
  void _step(int i, int dir) {
    if (!_isLetter(_guesses[i])) return;
    settingsNotifier.hapticTap();
    int code = _guesses[i].codeUnitAt(0) - 65;
    code = (code + dir) % 26;
    if (code < 0) code += 26;
    setState(() {
      _guesses[i] = String.fromCharCode(65 + code);
    });
  }

  void _checkSolution() {
    final userText = _guesses.join();
    if (userText == _target) {
      settingsNotifier.hapticTap();
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Decoded word is incorrect! Hint: The Caesar Shift is +$_currentShift.'),
      ));
    }
  }

  void _showHint() {
    int hintIdx = -1;
    for (int i = 0; i < _target.length; i++) {
      if (_isLetter(_encoded[i]) && _guesses[i] != _target[i]) {
        hintIdx = i;
        break;
      }
    }

    if (hintIdx != -1) {
      setState(() {
        _guesses[hintIdx] = _target[hintIdx];
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Hint: The Caesar Shift for this level is +$_currentShift. Filled in one character for you.'),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('All characters are already correctly filled!'),
      ));
    }
  }

  Widget _buildCaret(IconData icon, VoidCallback onTap) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Icon(icon, size: 24, color: AppTheme.dustyMauve),
      ),
    );
  }

  Widget _buildSlot(int i) {
    final ch = _encoded[i];
    final isLetter = _isLetter(ch);

    if (!isLetter) {
      // Non-editable character (space, punctuation) shown as-is.
      return SizedBox(
        width: ch.trim().isEmpty ? 20 : 32,
        height: 132,
        child: Center(
          child: Text(
            ch,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: context.textMuted,
            ),
          ),
        ),
      );
    }

    final isCorrect = _guesses[i] == _target[i];

    return SizedBox(
      width: 54,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cipher symbol reference.
          Text(
            ch,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.dustyMauve.withAlpha(160),
            ),
          ),
          const SizedBox(height: 2),
          _buildCaret(Icons.keyboard_arrow_up, () => _step(i, 1)),
          Container(
            width: 48,
            height: 52,
            decoration: BoxDecoration(
              color: isCorrect
                  ? AppTheme.dustyMauve.withAlpha(38)
                  : context.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isCorrect
                    ? AppTheme.dustyMauve.withAlpha(140)
                    : context.textMuted.withAlpha(50),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _guesses[i],
              style: GoogleFonts.spaceGrotesk(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
          ),
          _buildCaret(Icons.keyboard_arrow_down, () => _step(i, -1)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Cipher Decoder', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Each level is a Caesar Cipher — every letter is shifted forward by the same constant amount. Find the pattern for one letter, and all others will match!',
                              style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 16,
                            children: [
                              for (int i = 0; i < _encoded.length; i++) _buildSlot(i),
                            ],
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
                              '💡 Rule Details:\n• Each symbol maps to one hidden letter.\n• Use the ▲ / ▼ carets to shift a letter one step at a time.\n• Decode the full quote, then press Check.',
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
