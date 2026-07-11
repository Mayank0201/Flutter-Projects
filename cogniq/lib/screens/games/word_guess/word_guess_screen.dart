import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cogniq/widgets/buy_hints_dialog.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/rules_helper.dart';
import '../../../utils/audio_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import 'word_guess_dictionary.dart';

const List<String> _k5Words = [
  // Easy/Medium (Minimalist, universal, but interesting)
  'CRANE', 'GLOOM', 'FROWN', 'GRAPE', 'APPLE', 'PLANT', 'TRAIN', 'SMART',
  'BEACH', 'DREAM', 'STAGE', 'HOUSE', 'LIGHT', 'PEACH', 'SHINE', 'SMILE',
  'WATER', 'WORLD', 'FLOAT', 'CHAIR', 'GRASS', 'BREAD', 'CROWN', 'FLAME',
  'GLASS', 'MUSIC', 'RIVER', 'STORM', 'TIGER', 'STONE', 'BEAST', 'CLOTH',
  'STARE', 'GUIDE', 'BLAND', 'STEEP', 'JUMBO', 'SWELL', 'GREEN', 'QUEEN',
  // Hard/Tricky (Double letters, silent letters, low vowel density)
  'WALTZ', 'TRYST', 'QUAFF', 'HYDRA', 'GLYPH', 'PIXEL', 'FJORD', 'PLUCK',
  'CRYPT', 'VIXEN', 'DWELT', 'EQUIP', 'GIZMO', 'JAZZY', 'NYMPH', 'QUIRK',
  'SHYLY', 'WHACK', 'ZESTY', 'SYNOD', 'PLUMB', 'WRACK', 'CHUTE', 'GAUNT',
  'ABACK', 'FLOUT', 'GHOUL', 'FLAIR', 'BLITZ', 'SPRIG', 'KNOLL', 'VAGUE',
  'GNASH', 'DOUBT', 'CLIMB', 'KNACK', 'GHOST', 'KNIFE', 'KNEAD', 'KNELL',
  'PSALM', 'WREAK', 'WRITE', 'WHOLE', 'WRONG', 'GNOME', 'PUPPY', 'FUZZY',
  'MUMMY', 'CHEEK', 'GEESE', 'DROLL', 'SKULL', 'ERROR', 'FLOOD', 'SPOON',
  'KRILL', 'STIFF', 'CLIFF', 'TOOTH', 'SHEEP', 'STEER', 'SPOOF', 'STAFF',
  'BOOTH', 'SNOOT', 'DRAFT', 'GRAFT', 'CRAFT', 'BLUFE', 'FLUFF', 'CLIQU',
  'CLACK', 'CLICK', 'CLOCK', 'BLACK', 'BLOCK', 'BRICK', 'BROOD', 'BRASS',
  'GLASS', 'CLASS', 'GRASS', 'PRESS', 'CRESS', 'DRESS', 'BLESS', 'GLOSS',
  'FLOSS', 'SPORE', 'SHORE', 'CHORE', 'STORE', 'SCORE', 'SNORE', 'SHARE',
  'SPARE', 'STARE', 'FLARE', 'SCARE', 'BLARE', 'GLARE', 'SWILL', 'DRILL',
  'SPILL', 'STILL', 'SKILL', 'GRILL', 'FRILL', 'CHILL', 'SHILL', 'KRILL',
  // Very Hard (Extremely rare letter placement/combinations)
  'MYRRH', 'XYLEM', 'PHLOX', 'CYNIC', 'SKIFF', 'VODKA', 'PLAZA', 'GAVEL',
  'SNOUT', 'SPOUT', 'EPOXY', 'COYLY', 'ZIPPY', 'ZILCH', 'AFFIX', 'ABYSS',
  'KAPPA', 'AORTA', 'MAMBA', 'CIVIC', 'LYNCH', 'VIGOR', 'FLESH', 'GIPSY',
];

class WordGuessScreen extends StatefulWidget {
  final int? dailyLevelIndex;
  const WordGuessScreen({super.key, this.dailyLevelIndex});
  @override
  State<WordGuessScreen> createState() => _WordGuessScreenState();
}

class _WordGuessScreenState extends State<WordGuessScreen> {
  int _levelIndex = 0;
  late String _targetWord;
  List<List<String>> _guesses = List.generate(6, (_) => List.filled(5, ''));
  List<List<_TileState>> _states = List.generate(
    6,
    (_) => List.filled(5, _TileState.empty),
  );
  final Map<String, _TileState> _letterStates = {};
  int get _maxGuesses {
    if (_playDailyMode && _dailyModifierType == 'minimal') {
      return 4;
    }
    return 6;
  }

  int _currentRow = 0;
  String _currentInput = '';
  bool _gameOver = false;
  bool _won = false;
  String _message = '';
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  String _dailyModifierName = '';

  late final FocusNode _keyboardFocusNode;

  @override
  void initState() {
    super.initState();
    _keyboardFocusNode = FocusNode();
    // Default synchronous initialization to avoid LateInitializationError
    _targetWord = _k5Words[0];
    _initLevel();
  }

  int _hintCount = 0;

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('wordle');
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool('play_daily_mode') ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString('daily_modifier_type') ?? '';
      _dailyModifierName = prefs.getString('daily_modifier_name') ?? '';
    } else {
      _dailyModifierType = '';
      _dailyModifierName = '';
    }
    
    int targetLevel = 0;
    if (widget.dailyLevelIndex != null) {
      targetLevel = widget.dailyLevelIndex!;
    } else {
      targetLevel = prefs.getInt('level_wordle') ?? 0;
    }

    if (mounted) {
      setState(() {
        _levelIndex = targetLevel;
        _loadLevel();
      });
    }

    if (!_playDailyMode) {
      Future.delayed(Duration.zero, () async {
        if (!mounted) return;
        final savedStateStr = prefs.getString('normal_wordle_state');
        if (savedStateStr != null) {
          try {
            final data = jsonDecode(savedStateStr);
            if (data['levelIndex'] == _levelIndex) {
              final continueGame = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  backgroundColor: context.bgCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: context.textMuted.withAlpha(40)),
                  ),
                  title: Text(
                    'Continue Game?',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
                  ),
                  content: Text(
                    'We found a saved state for this level. Would you like to continue playing or start a new game?',
                    style: GoogleFonts.outfit(color: context.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx, false); // New Game
                      },
                      child: Text(
                        'New Game',
                        style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx, true); // Continue
                      },
                      child: Text(
                        'Continue',
                        style: GoogleFonts.outfit(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ) ?? false;

              if (continueGame) {
                final String targetWord = data['targetWord'];
                final List<dynamic> guessesData = data['guesses'];
                final List<List<String>> loadedGuesses = guessesData.map((row) => List<String>.from(row)).toList();
                
                final List<dynamic> statesData = data['states'];
                final List<List<_TileState>> loadedStates = statesData.map<List<_TileState>>((row) => 
                  (row as List<dynamic>).map((idx) => _TileState.values[idx as int]).toList()
                ).toList();

                final Map<String, dynamic> letterStatesData = data['letterStates'] ?? {};
                final Map<String, _TileState> loadedLetterStates = letterStatesData.map((k, v) => 
                  MapEntry(k, _TileState.values[v as int])
                );

                setState(() {
                  _targetWord = targetWord;
                  _guesses = loadedGuesses;
                  _states = loadedStates;
                  _letterStates.clear();
                  _letterStates.addAll(loadedLetterStates);
                  _currentRow = data['currentRow'];
                  _currentInput = data['currentInput'];
                  _gameOver = data['gameOver'];
                  _won = data['won'];
                  _message = data['message'] ?? '';
                });
              } else {
                await _clearNormalState();
              }
            } else {
              await _clearNormalState();
            }
          } catch (_) {
            await _clearNormalState();
          }
        }
      });
    }
  }

  Future<void> _saveNormalState() async {
    if (_playDailyMode || _won) return;
    final prefs = await SharedPreferences.getInstance();
    final state = {
      'levelIndex': _levelIndex,
      'targetWord': _targetWord,
      'guesses': _guesses,
      'states': _states.map((row) => row.map((s) => s.index).toList()).toList(),
      'letterStates': _letterStates.map((k, v) => MapEntry(k, v.index)),
      'currentRow': _currentRow,
      'currentInput': _currentInput,
      'gameOver': _gameOver,
      'won': _won,
      'message': _message,
    };
    await prefs.setString('normal_wordle_state', jsonEncode(state));
  }

  Future<void> _clearNormalState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('normal_wordle_state');
  }

  Future<void> _savePersistedLevel(int lvl) async {
    if (widget.dailyLevelIndex != null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_wordle', lvl);
    final earned = await HintManager.onLevelCleared('wordle');
    if (earned) {
      final newCount = await HintManager.getHints('wordle');
      setState(() {
        _hintCount = newCount;
      });
      
    }
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _loadLevel({String? customWord}) {
    _targetWord = customWord ?? _k5Words[_levelIndex % _k5Words.length];
    final maxG = _maxGuesses;
    _guesses = List.generate(maxG, (_) => List.filled(5, ''));
    _states = List.generate(maxG, (_) => List.filled(5, _TileState.empty));
    _letterStates.clear();
    _currentRow = 0;
    _currentInput = '';
    _gameOver = false;
    _won = false;
    _message = '';

    if (_playDailyMode && _dailyModifierType == 'minimal') {
      final rng = Random();
      final idx = rng.nextInt(5);
      final char = _targetWord[idx];
      for (int k = 0; k < 5; k++) {
        _guesses[0][k] = (k == idx) ? char : '_';
        _states[0][k] = (k == idx) ? _TileState.correct : _TileState.absent;
      }
      _letterStates[char] = _TileState.correct;
      _currentRow = 1;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_gameOver) {
        _keyboardFocusNode.requestFocus();
      }
    });
  }

  void _reset() {
    final currentWord = _targetWord;
    final rng = Random();
    String nextWord = _k5Words[rng.nextInt(_k5Words.length)];
    while (nextWord == currentWord && _k5Words.length > 1) {
      nextWord = _k5Words[rng.nextInt(_k5Words.length)];
    }
    setState(() {
      _loadLevel(customWord: nextWord);
    });
  }

  void _onKey(String key) {
    if (_gameOver) return;
    if (key == '⌫') {
      AudioManager.playClick();
      if (_currentInput.isNotEmpty) {
        setState(() {
          _currentInput = _currentInput.substring(0, _currentInput.length - 1);
          for (int i = 0; i < 5; i++) {
            _guesses[_currentRow][i] = i < _currentInput.length ? _currentInput[i] : '';
          }
        });
        _saveNormalState();
      }
    } else if (key == '↵') {
      AudioManager.playClick();
      if (_currentInput.length == 5) _submitGuess();
    } else if (_currentInput.length < 5) {
      setState(() {
        _currentInput = _currentInput + key;
        for (int i = 0; i < 5; i++) {
          _guesses[_currentRow][i] = i < _currentInput.length ? _currentInput[i] : '';
        }
      });
      _saveNormalState();
    }
  }

  void _submitGuess() {
    final guess = _currentInput;
    if (!kWordGuessDictionary.contains(guess)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Not a valid word',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFB94040),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    final target = _targetWord;
    final ns = List.filled(5, _TileState.absent);
    final tc = target.split('');
    final gc = guess.split('');
    for (int i = 0; i < 5; i++) {
      if (gc[i] == tc[i]) {
        ns[i] = _TileState.correct;
        tc[i] = '_';
        gc[i] = '*';
      }
    }
    for (int i = 0; i < 5; i++) {
      if (gc[i] != '*') {
        final j = tc.indexOf(gc[i]);
        if (j != -1) {
          ns[i] = _TileState.present;
          tc[j] = '_';
        }
      }
    }
    if (_playDailyMode && _dailyModifierType == 'glitch') {
      final swappableIndices = <int>[];
      for (int i = 0; i < 5; i++) {
        if (ns[i] == _TileState.correct || ns[i] == _TileState.present) {
          swappableIndices.add(i);
        }
      }
      if (swappableIndices.isNotEmpty) {
        final rng = Random();
        if (rng.nextDouble() < 0.5) {
          final idxToSwap = swappableIndices[rng.nextInt(swappableIndices.length)];
          if (ns[idxToSwap] == _TileState.correct) {
            ns[idxToSwap] = _TileState.present;
          } else {
            ns[idxToSwap] = _TileState.correct;
          }
          _message = 'Glitch detected in feedback!';
        }
      }
    }
    if (_playDailyMode && _dailyModifierType == 'spy' && guess != target) {
      final rng = Random();
      final idx = rng.nextInt(5);
      if (ns[idx] == _TileState.correct) {
        ns[idx] = _TileState.present;
      } else if (ns[idx] == _TileState.present) {
        ns[idx] = _TileState.absent;
      } else if (ns[idx] == _TileState.absent) {
        ns[idx] = _TileState.present;
      }
      _message = 'A Double Agent has modified your feedback!';
    }
    for (int i = 0; i < 5; i++) {
      final letter = guess[i];
      final tileState = ns[i];
      final current = _letterStates[letter];
      if (current == null ||
          tileState == _TileState.correct ||
          (tileState == _TileState.present && current == _TileState.absent)) {
        _letterStates[letter] = tileState;
      }
    }
    setState(() {
      _states[_currentRow] = ns;
      if (guess == target) {
        _won = true;
        _gameOver = true;
        _message = 'Correct! It was $target';
        AudioManager.playSuccess();
        _savePersistedLevel(_levelIndex + 1);
        _clearNormalState();
      } else if (_currentRow == _maxGuesses - 1) {
        _gameOver = true;
        _message = 'Game Over! The word was $target';
        AudioManager.playFail();
        _clearNormalState();
      } else {
        _currentRow++;
        _currentInput = '';
        _saveNormalState();
      }
    });
  }

  void _nextLevel() {
    if (!_won) return;
    if (widget.dailyLevelIndex != null) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _levelIndex = _levelIndex + 1;
      _loadLevel();
    });
  }

  Future<void> _useWordleHint() async {
    if (_hintCount <= 0 || _gameOver) return;

    final targetLetters = _targetWord.split('');
    final guessedCorrectly = <String>[];
    for (int r = 0; r < _currentRow; r++) {
      for (int c = 0; c < 5; c++) {
        if (_states[r][c] == _TileState.correct) {
          guessedCorrectly.add(_guesses[r][c]);
        }
      }
    }

    final unrevealed = targetLetters
        .where((l) => !guessedCorrectly.contains(l))
        .toList();
    if (unrevealed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You\'ve already found all letters!',
            style: GoogleFonts.outfit(),
          ),
        ),
      );
      return;
    }

    final hintLetter = unrevealed[Random().nextInt(unrevealed.length)];

    await HintManager.useHint('wordle');
    final newCount = await HintManager.getHints('wordle');
    setState(() {
      _hintCount = newCount;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Hint: The word contains the letter "$hintLetter"',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.wordleGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          final logicalKey = event.logicalKey;
          if (logicalKey == LogicalKeyboardKey.backspace) {
            _onKey('⌫');
          } else if (logicalKey == LogicalKeyboardKey.enter) {
            _onKey('↵');
          } else {
            final keyLabel = logicalKey.keyLabel.toUpperCase();
            if (keyLabel.length == 1 && RegExp(r'^[A-Z]$').hasMatch(keyLabel)) {
              _onKey(keyLabel);
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: context.bgDark,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: context.bgDark,
          foregroundColor: context.textPrimary,
          title: Text(
            'Word Guess',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline, size: 20),
              color: context.textMuted,
              onPressed: () => RulesHelper.showRulesBottomSheet(
                context,
                'wordle',
                'Word Guess',
              ),
            ),
            IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 20,
                    color: context.textMuted,
                  ),
                  Positioned(
                    right: -4,
                    top: -4,
                    child: CircleAvatar(
                      radius: 6,
                      backgroundColor: Colors.amber,
                      child: Text(
                        _hintCount == 0 ? '+' : '$_hintCount',
                        style: GoogleFonts.outfit(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              onPressed: !_gameOver
                ? () async {
                    if (_hintCount > 0) {
                      _useWordleHint();
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'wordle',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('wordle');
                          if (mounted) setState(() => _hintCount = newCount);
                        },
                      );
                    }
                  }
                : null,
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _reset,
              color: context.textMuted,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  _playDailyMode ? 'Daily' : 'Level ${_levelIndex + 1}',
                  style: AppTheme.numberStyle(
                    color: AppTheme.wordleGreen,
                    fontSize: context.scale(13),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  if (_playDailyMode)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      color: Colors.amber.withOpacity(0.15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'DAILY CHALLENGE: ${_dailyModifierName.toUpperCase()}',
                            style: GoogleFonts.outfit(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_message.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: _won ? AppTheme.wordleGreen : const Color(0xFFB94040),
                  child: Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: context.scale(14),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              // Grid — compact
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        _maxGuesses,
                        (row) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              5,
                              (col) => _WordleTile(
                                letter: _guesses[row][col],
                                state: _states[row][col],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (!_gameOver)
                _WordleKeyboard(onKey: _onKey, letterStates: _letterStates)
              else if (!_won)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB94040),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _reset,
                    child: Text(
                      'Try Again',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: context.scale(14),
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: AutoNextCountdown(
                    onNext: _nextLevel,
                    accentColor: AppTheme.wordleGreen,
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        if (_won && _playDailyMode)
          Positioned.fill(
            child: ChallengeClearedOverlay(
              accentColor: AppTheme.wordleGreen,
              onComplete: () {
                Navigator.pop(context, true);
              },
            ),
          ),
      ],
    ),
  ),
);

  }
}

enum _TileState { empty, correct, present, absent }

class _WordleTile extends StatelessWidget {
  final String letter;
  final _TileState state;
  const _WordleTile({required this.letter, required this.state});
  Color getBg(BuildContext context) {
    switch (state) {
      case _TileState.correct:
        return AppTheme.wordleGreen;
      case _TileState.present:
        return AppTheme.wordleYellow;
      case _TileState.absent:
        return context.isDarkMode
            ? const Color(0xFF3A3A3C)
            : const Color(0xFF9CA3AF);
      case _TileState.empty:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    width: context.scale(52),
    height: context.scale(52),
    margin: const EdgeInsets.symmetric(horizontal: 3),
    decoration: BoxDecoration(
      color: getBg(context),
      border: Border.all(
        color: letter.isNotEmpty && state == _TileState.empty
            ? context.textPrimary
            : state == _TileState.empty
            ? (context.isDarkMode
                  ? const Color(0xFF3A3A3C)
                  : const Color(0xFFD1D5DB))
            : Colors.transparent,
        width: 2,
      ),
    ),
    child: Center(
      child: Text(
        letter,
        style: GoogleFonts.outfit(
          fontSize: context.scale(22),
          fontWeight: FontWeight.w800,
          color: state == _TileState.empty ? context.textPrimary : Colors.white,
        ),
      ),
    ),
  );
}

class _WordleKeyboard extends StatelessWidget {
  final void Function(String) onKey;
  final Map<String, _TileState> letterStates;
  const _WordleKeyboard({required this.onKey, required this.letterStates});
  static const _rows = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['↵', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '⌫'],
  ];

  Color _getKeyBgColor(BuildContext context, String key) {
    final state = letterStates[key];
    switch (state) {
      case _TileState.correct:
        return AppTheme.wordleGreen;
      case _TileState.present:
        return AppTheme.wordleYellow;
      case _TileState.absent:
        return context.isDarkMode
            ? const Color(0xFF3A3A3C)
            : const Color(0xFF9CA3AF);
      default:
        return context.isDarkMode
            ? const Color(0xFF818384)
            : const Color(0xFFD1D5DB);
    }
  }

  Color _getKeyTextColor(BuildContext context, String key) {
    final state = letterStates[key];
    if (state == null) {
      return context.textPrimary;
    }
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: _rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((key) {
                  final isWide = key == '↵' || key == '⌫';
                  return GestureDetector(
                    onTap: () => onKey(key),
                    child: Container(
                      width: isWide ? context.scale(48) : context.scale(32),
                      height: context.scale(42),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: _getKeyBgColor(context, key),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          key,
                          style: GoogleFonts.outfit(
                            fontSize: isWide
                                ? context.scale(14)
                                : context.scale(13),
                            fontWeight: FontWeight.w600,
                            color: _getKeyTextColor(context, key),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          )
          .toList(),
    ),
  );
}
