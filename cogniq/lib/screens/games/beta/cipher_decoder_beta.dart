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
  List<TextEditingController> _controllers = [];
  List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _loadLevel() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    _controllers = [];
    _focusNodes = [];

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

      for (int i = 0; i < _encoded.length; i++) {
        _controllers.add(TextEditingController());
        _focusNodes.add(FocusNode());
      }
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

  void _checkSolution() {
    String userText = _controllers.map((c) => c.text.trim().toUpperCase()).join();
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
      if (_controllers[i].text.toUpperCase() != _target[i]) {
        hintIdx = i;
        break;
      }
    }
    
    if (hintIdx != -1) {
      setState(() {
        _controllers[hintIdx].text = _target[hintIdx];
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
                          const SizedBox(height: 32),
                          // Column based layout
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 16,
                            children: [
                              for (int i = 0; i < _encoded.length; i++)
                                Container(
                                  width: 48,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _encoded[i],
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.dustyMauve,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Icon(
                                        Icons.arrow_downward,
                                        size: 16,
                                        color: context.textMuted.withOpacity(0.5),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: context.bgCard,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: context.textMuted.withAlpha(50)),
                                        ),
                                        child: TextField(
                                          controller: _controllers[i],
                                          focusNode: _focusNodes[i],
                                          maxLength: 1,
                                          textAlign: TextAlign.center,
                                          textCapitalization: TextCapitalization.characters,
                                          style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary),
                                          decoration: const InputDecoration(
                                            counterText: "",
                                            border: InputBorder.none,
                                          ),
                                          onChanged: (val) {
                                            if (val.isNotEmpty && i < _encoded.length - 1) {
                                              _focusNodes[i + 1].requestFocus();
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
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
