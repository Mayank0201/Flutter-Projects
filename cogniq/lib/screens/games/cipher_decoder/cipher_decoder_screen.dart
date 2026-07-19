import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/buy_hints_dialog.dart';
import '../../../widgets/fog_overlay.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../utils/prefs_keys.dart';
import '../../../utils/hint_manager.dart';

class CipherDecoderScreen extends StatefulWidget {
  const CipherDecoderScreen({super.key});

  @override
  State<CipherDecoderScreen> createState() => _CipherDecoderScreenState();
}

class _CipherDecoderScreenState extends State<CipherDecoderScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  double _dailyRadius = 1.5;

  String _phrase = ""; // Original target phrase (e.g., "HELLO WORLD")
  String _encoded = ""; // Encrypted phrase (e.g., "IFMMP XQSME")
  
  // Maps the encrypted character ('A'-'Z') to the player's guessed character ('A'-'Z')
  Map<String, String> _mappings = {};

  int _selectedIdx = -1; // Index in the phrase string
  bool _isLoading = true;

  static const List<String> _kSingleWords = [
    "LOGIC", "BRAIN", "CIPHER", "DECODE", "MYSTERY", "SECRET", "SOLVER", "PUZZLE", "MATRIX"
  ];
  static const List<String> _kTwoWords = [
    "THINK FAST", "KEEP FOCUS", "SOLVE THIS", "CODE BREAKER", "MIND SHIFT", "SHARP BRAIN", "DEEP THINK"
  ];
  static const List<String> _kThreeWords = [
    "DREAM WORK FOCUS", "LOGIC LEADS WAY", "SOLVE THE CODE", "KNOWLEDGE IS POWER", "NEVER GIVE UP"
  ];
  static const List<String> _kPhrases = [
    "LOGIC IS THE BEGINNING OF WISDOM",
    "NEVER TRUST A COMPUTER YOU CANNOT THROW",
    "TO BE OR NOT TO BE THAT IS THE QUESTION",
    "DO OR DO NOT THERE IS NO TRY",
    "STAY HUNGRY STAY FOOLISH ALWAYS",
    "SIMPLICITY IS THE ULTIMATE SOPHISTICATION",
    "I THINK THEREFORE I AM ALIVE",
    "INNOVATION DISTINGUISHES LEADERS FROM FOLLOWERS",
    "THE ONLY WAY TO DO GREAT WORK IS TO LOVE IT",
    "PRACTICE MAKES PERFECT IN EVERY WAY",
    "CREATIVITY IS INTELLIGENCE HAVING FUN",
    "DETERMINATION LEADS TO GRAND SUCCESS",
    "FOCUS ON THE JOURNEY NOT THE DESTINATION",
    "DREAM BIG WORK HARD STAY FOCUSED",
  ];

  @override
  void initState() {
    super.initState();
    _loadProgressAndGenerate();
  }

  Future<void> _loadProgressAndGenerate() async {
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString(PrefsKeys.dailyModifierType) ?? '';
      final extraParamsStr = prefs.getString(PrefsKeys.dailyModifierExtraParams) ?? '';
      if (extraParamsStr.isNotEmpty) {
        try {
          final extraParams = jsonDecode(extraParamsStr) as Map<String, dynamic>;
          if (extraParams.containsKey('radius')) {
            _dailyRadius = (extraParams['radius'] as num).toDouble();
          } else {
            _dailyRadius = 1.5;
          }
        } catch (_) {
          _dailyRadius = 1.5;
        }
      } else {
        _dailyRadius = 1.5;
      }
    } else {
      _dailyModifierType = '';
      _dailyRadius = 1.5;
    }

    int level = prefs.getInt(PrefsKeys.gameLevel('cipherdecoder')) ?? 0;
    if (mounted) {
      setState(() {
        _currentLevel = level;
        _isLoading = true;
      });
      _generatePuzzle();
    }
  }

  bool _isLetter(String c) {
    if (c.isEmpty) return false;
    int code = c.codeUnitAt(0);
    return code >= 65 && code <= 90;
  }

  bool _isVowel(String c) {
    return c == 'A' || c == 'E' || c == 'I' || c == 'O' || c == 'U';
  }

  void _generatePuzzle() {
    final rand = Random();
    
    // 1. Pick a phrase based on progressive level difficulty
    if (_currentLevel < 3) {
      _phrase = _kSingleWords[_currentLevel % _kSingleWords.length].toUpperCase();
    } else if (_currentLevel < 6) {
      _phrase = _kTwoWords[(_currentLevel - 3) % _kTwoWords.length].toUpperCase();
    } else if (_currentLevel < 9) {
      _phrase = _kThreeWords[(_currentLevel - 6) % _kThreeWords.length].toUpperCase();
    } else {
      _phrase = _kPhrases[(_currentLevel - 9) % _kPhrases.length].toUpperCase();
    }

    // 2. Encrypt based on level difficulty scaling
    _mappings.clear();

    if (_currentLevel < 5) {
      // Easy: Uniform Shift
      int shift = rand.nextInt(25) + 1;
      _encoded = _encryptUniform(_phrase, shift);
    } else if (_currentLevel < 12) {
      // Medium: Vowel vs Consonant Shift
      int vShift = rand.nextInt(25) + 1;
      int cShift = rand.nextInt(25) + 1;
      while (vShift == cShift) {
        cShift = rand.nextInt(25) + 1;
      }
      _encoded = _encryptVowelConsonant(_phrase, vShift, cShift);
    } else {
      // Hard: Progressive Word Shift
      int baseShift = rand.nextInt(25) + 1;
      _encoded = _encryptProgressive(_phrase, baseShift);
    }

    setState(() {
      _isSuccess = false;
      _selectedIdx = -1;
      _isLoading = false;
    });
  }

  String _encryptUniform(String phrase, int shift) {
    final buffer = StringBuffer();
    for (int i = 0; i < phrase.length; i++) {
      String char = phrase[i];
      if (_isLetter(char)) {
        int code = ((char.codeUnitAt(0) - 65 + shift) % 26) + 65;
        buffer.write(String.fromCharCode(code));
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  String _encryptVowelConsonant(String phrase, int vShift, int cShift) {
    final buffer = StringBuffer();
    for (int i = 0; i < phrase.length; i++) {
      String char = phrase[i];
      if (_isLetter(char)) {
        int shift = _isVowel(char) ? vShift : cShift;
        int code = ((char.codeUnitAt(0) - 65 + shift) % 26) + 65;
        buffer.write(String.fromCharCode(code));
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  String _encryptProgressive(String phrase, int baseShift) {
    final words = phrase.split(" ");
    final encryptedWords = <String>[];

    for (int w = 0; w < words.length; w++) {
      final word = words[w];
      final wordShift = (baseShift + w) % 26;
      final buffer = StringBuffer();
      for (int i = 0; i < word.length; i++) {
        String char = word[i];
        if (_isLetter(char)) {
          int code = ((char.codeUnitAt(0) - 65 + wordShift) % 26) + 65;
          buffer.write(String.fromCharCode(code));
        } else {
          buffer.write(char);
        }
      }
      encryptedWords.add(buffer.toString());
    }

    return encryptedWords.join(" ");
  }

  void _checkSolution() {
    bool isSolved = true;
    for (int i = 0; i < _phrase.length; i++) {
      String origChar = _phrase[i];
      if (_isLetter(origChar)) {
        String encChar = _encoded[i];
        String guess = _mappings[encChar] ?? "";
        if (guess != origChar) {
          isSolved = false;
          break;
        }
      }
    }

    if (isSolved) {
      settingsNotifier.hapticSuccess();
      _onLevelCleared();
    } else {
      settingsNotifier.hapticError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect translation! Keep decoding the cipher shift.')),
      );
    }
  }

  Future<void> _onLevelCleared() async {
    if (!_playDailyMode) {
      final prefs = await SharedPreferences.getInstance();
      int highest = prefs.getInt('beta_level_cipherdecoder') ?? 0;
      if (_currentLevel + 1 > highest) {
        await prefs.setInt('beta_level_cipherdecoder', _currentLevel + 1);
      }
      await prefs.setInt(PrefsKeys.gameLevel('cipherdecoder'), _currentLevel + 1);

      int currentClears = prefs.getInt(PrefsKeys.globalLevelClearedCount) ?? 0;
      await prefs.setInt(PrefsKeys.globalLevelClearedCount, currentClears + 1);
    }

    setState(() => _isSuccess = true);
  }

  void _nextLevel() {
    setState(() {
      _currentLevel++;
      _isLoading = true;
    });
    _generatePuzzle();
  }

  void _showHint() async {
    if (_selectedIdx == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a letter slot first!')),
      );
      return;
    }

    String encChar = _encoded[_selectedIdx];
    if (!_isLetter(encChar)) return;

    final hints = await HintManager.getHints('cipherdecoder');
    if (hints > 0) {
      await HintManager.useHint('cipherdecoder');
      String targetChar = _phrase[_selectedIdx];
      setState(() {
        _mappings[encChar] = targetChar;
      });
    } else {
      BuyHintsDialog.show(context, initialGameId: 'cipherdecoder', onPurchaseComplete: () {
        setState(() {});
      });
    }
  }

  void _onKeyboardTap(String key) {
    if (_selectedIdx == -1) return;
    String encChar = _encoded[_selectedIdx];
    if (!_isLetter(encChar)) return;

    settingsNotifier.hapticTap();
    setState(() {
      _mappings[encChar] = key;
    });
  }

  void _clearMapping() {
    if (_selectedIdx == -1) return;
    String encChar = _encoded[_selectedIdx];
    if (!_isLetter(encChar)) return;

    settingsNotifier.hapticTap();
    setState(() {
      _mappings.remove(encChar);
    });
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text(
          'How to Play Cipher Decoder',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        content: Text(
          '1. Decode the secret encrypted sentence.\n\n'
          '2. Select any letter block and type a letter on the keyboard to map it.\n\n'
          '3. Assigning a letter updates all matching cipher letters across the screen.\n\n'
          '4. Easy ciphers use a single shift. Harder levels use multi-pattern or word-by-word progressive shifts.',
          style: GoogleFonts.outfit(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style: GoogleFonts.outfit(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.bgDark,
        body: const Center(child: CircularProgressIndicator(color: AppTheme.dustyMauve)),
      );
    }

    // Split phrase into words for clean wrapped rendering
    final List<String> encWords = _encoded.split(" ");
    int globalCharOffset = 0;

    final double screenW = MediaQuery.of(context).size.width;
    final double keyWidth = min(36.0, (screenW - 68) / 10);

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Cipher Decoder', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
            child: Center(
              child: Text(
                _playDailyMode ? 'Challenge' : 'Level ${_currentLevel + 1}',
                style: AppTheme.numberStyle(
                  color: AppTheme.dustyMauve,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Text(
                          _currentLevel < 5
                              ? 'Difficulty: Easy (Uniform Caesar Shift)'
                              : _currentLevel < 12
                                  ? 'Difficulty: Medium (Dual-Pattern Shift)'
                                  : 'Difficulty: Hard (Progressive Word Shift)',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.dustyMauve,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Encrypted Phrase wraps words
                        FogOverlay(
                          enabled: _playDailyMode && _dailyModifierType == 'fog',
                          radius: 120.0 * _dailyRadius,
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 16,
                            alignment: WrapAlignment.center,
                            children: [
                              for (int w = 0; w < encWords.length; w++)
                                _buildWordRow(encWords[w], w, globalCharOffset += (w > 0 ? encWords[w - 1].length + 1 : 0)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Virtual Keyboard
                Container(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildKeyboardRow(["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"], keyWidth),
                      const SizedBox(height: 6),
                      _buildKeyboardRow(["A", "S", "D", "F", "G", "H", "J", "K", "L"], keyWidth),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildKeyboardKey("CLR", keyWidth, onPressed: _clearMapping),
                          const SizedBox(width: 4),
                          ...List.generate(7 * 2 - 1, (index) {
                            if (index.isOdd) return const SizedBox(width: 4);
                            final key = ["Z", "X", "C", "V", "B", "N", "M"][index ~/ 2];
                            return _buildKeyboardKey(key, keyWidth, onPressed: () => _onKeyboardTap(key));
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.bgCard,
                        foregroundColor: context.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          _mappings.clear();
                          _selectedIdx = -1;
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.dustyMauve,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _checkSolution,
                      icon: const Icon(Icons.check),
                      label: const Text('Check'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isSuccess)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: _playDailyMode
                      ? ChallengeClearedOverlay(
                          accentColor: AppTheme.dustyMauve,
                          onComplete: () {
                            Navigator.pop(context, true);
                          },
                        )
                      : Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: context.bgCard,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
                              const SizedBox(height: 16),
                              Text(
                                'Level ${_currentLevel + 1} Cleared!',
                                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
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
            ),
        ],
      ),
    );
  }

  Widget _buildWordRow(String word, int wordIdx, int charOffset) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < word.length; i++) ...[
          _buildLetterCard(word[i], charOffset + i),
          if (i < word.length - 1) const SizedBox(width: 4),
        ]
      ],
    );
  }

  Widget _buildLetterCard(String encChar, int globalIdx) {
    if (!_isLetter(encChar)) {
      // Punctuation slot
      return Container(
        width: 32,
        height: 52,
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          encChar,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
      );
    }

    final isSelected = _selectedIdx == globalIdx;
    final guess = _mappings[encChar] ?? "";

    return Semantics(
      label: 'Character index $globalIdx. Cipher letter $encChar. '
          '${guess.isEmpty ? "Not translated" : "Guess is $guess"}. '
          '${isSelected ? "Selected" : ""}',
      child: GestureDetector(
        onTap: () {
          settingsNotifier.hapticTap();
          setState(() {
            _selectedIdx = globalIdx;
          });
        },
        child: Container(
          width: 32,
          height: 52,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.dustyMauve.withAlpha(40) : context.bgCard,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? AppTheme.dustyMauve : context.textMuted.withAlpha(40),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Player Guess Letter
              Text(
                guess,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.dustyMauve,
                ),
              ),
              const Divider(height: 6, thickness: 1, indent: 4, endIndent: 4),
              // Encrypted Cipher Letter
              Text(
                encChar,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboardRow(List<String> keys, double keyWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(keys.length * 2 - 1, (index) {
        if (index.isOdd) return const SizedBox(width: 4);
        final key = keys[index ~/ 2];
        return _buildKeyboardKey(key, keyWidth, onPressed: () => _onKeyboardTap(key));
      }),
    );
  }

  Widget _buildKeyboardKey(String text, double keyWidth, {required VoidCallback onPressed}) {
    final isClear = text == "CLR";
    final double width = isClear ? keyWidth * 1.5 : keyWidth;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 42,
        width: width,
        decoration: BoxDecoration(
          color: isClear ? Colors.red.shade900 : context.bgCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: context.textMuted.withAlpha(30)),
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: isClear ? 12 : 16,
              fontWeight: FontWeight.bold,
              color: isClear ? Colors.white : context.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
