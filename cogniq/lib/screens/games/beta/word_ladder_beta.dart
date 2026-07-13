import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';

class WordLadderBetaScreen extends StatefulWidget {
  const WordLadderBetaScreen({super.key});
  @override
  State<WordLadderBetaScreen> createState() => _WordLadderBetaScreenState();
}

class _WordLadderBetaScreenState extends State<WordLadderBetaScreen> {
  static const Set<String> _validWords = {
    // Level 1: COLD to WARM
    "COLD", "CORD", "WARD", "WARM", "CARD", "WAND", "WILD", "BIRD", "BIND", "FIND",
    // Level 2: HEAD to TAIL
    "HEAD", "HEAL", "TEAL", "TAIL", "HEAR", "TEAR", "DEAL", "PEAL", "FEAL", "ROAD",
    // Level 3: FINE to COIN
    "FINE", "LINE", "LION", "COIN", "MINE", "PINE", "CONE", "BONE", "ZONE", "LIME",
    // Level 4: WIND to WAVE
    "WIND", "WINE", "WANE", "WAVE", "WIDE", "WIFE", "WIRE", "SAVE", "CAVE", "LAVE",
    // Level 5: EAST to WEST
    "EAST", "LAST", "LEST", "WEST", "PAST", "FAST", "BEST", "PEST", "TEST", "REST",
    // Other common 4-letter words to support alternative paths:
    "BOLD", "GOLD", "HOLD", "FOLD", "SOLD", "TOLD", "SOUP", "SOUR", "SOAP", "LOAD",
    "TOAD", "BOAT", "COAT", "GOAT", "MATE", "LATE", "RATE", "GATE", "DATE",
    "CORE", "BORE", "TORE", "FORE", "MORE", "LORE", "HATE", "HAVE", "LOVE", "LIVE"
  };

  int _currentLevel = 0;
  bool _isSuccess = false;
  String _startWord = "COLD";
  String _endWord = "WARM";
  List<String> _steps = ["COLD", "", "", "WARM"];

  @override
  void initState() {
    super.initState();
    _loadLevel();
  }

  void _loadLevel() {
    setState(() {
      _isSuccess = false;
      if (_currentLevel == 0) {
        _startWord = "COLD";
        _endWord = "WARM";
      } else if (_currentLevel == 1) {
        _startWord = "HEAD";
        _endWord = "TAIL";
      } else if (_currentLevel == 2) {
        _startWord = "FINE";
        _endWord = "COIN";
      } else if (_currentLevel == 3) {
        _startWord = "WIND";
        _endWord = "WAVE";
      } else {
        _startWord = "EAST";
        _endWord = "WEST";
      }
      _steps = [_startWord, "", "", _endWord];
    });
  }

  Future<void> _onLevelCleared() async {
    final prefs = await SharedPreferences.getInstance();
    int highest = prefs.getInt('beta_level_wordladder') ?? 0;
    if (_currentLevel + 1 > highest) {
      await prefs.setInt('beta_level_wordladder', _currentLevel + 1);
    }
    setState(() => _isSuccess = true);
  }

  void _checkSolution() {
    bool isValid = true;
    
    // Check if all steps have words
    for (int i = 0; i < _steps.length; i++) {
      if (_steps[i].trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all steps!')));
        return;
      }
      if (!_validWords.contains(_steps[i])) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${_steps[i]}" is not a valid 4-letter word!')));
        return;
      }
    }

    bool diffOne(String w1, String w2) {
      if (w1.length != w2.length) return false;
      int diff = 0;
      for (int i = 0; i < w1.length; i++) {
        if (w1[i] != w2[i]) diff++;
      }
      return diff == 1;
    }

    for (int i = 0; i < _steps.length - 1; i++) {
      if (!diffOne(_steps[i], _steps[i+1])) {
        isValid = false;
      }
    }

    if (isValid) {
      _onLevelCleared();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Each step must differ by exactly one letter!')));
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text('Word Ladder', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
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
                        Text('Change one letter per step from $_startWord to $_endWord.', style: GoogleFonts.outfit(fontSize: 14, color: context.textSecondary)),
                        const SizedBox(height: 32),
                        for (int i = 0; i < _steps.length; i++) ...[
                          if (i == 0 || i == _steps.length - 1)
                            Container(
                              width: 200, padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: context.bgCard, borderRadius: BorderRadius.circular(8)),
                              child: Text(_steps[i], style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.dustyMauve)),
                            )
                          else
                            Container(
                              width: 200,
                              child: TextField(
                                controller: TextEditingController(text: _steps[i])..selection = TextSelection.collapsed(offset: _steps[i].length),
                                style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(hintText: 'Step $i', hintStyle: GoogleFonts.spaceGrotesk(color: context.textMuted.withOpacity(0.5))),
                                onChanged: (val) => _steps[i] = val.toUpperCase(),
                              ),
                            ),
                          if (i < _steps.length - 1) const Icon(Icons.arrow_downward, color: Colors.grey),
                        ],
                      ],
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
