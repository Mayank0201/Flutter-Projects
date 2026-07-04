import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../theme/settings_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/rules_helper.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/audio_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../game_completed_screen.dart';
import '../../../widgets/loss_overlay.dart';
import '../../../widgets/challenge_cleared_overlay.dart';

const List<String> _kGameWords = [
  // Easy (length 4-6)
  'APPLE', 'TIGER', 'HOUSE', 'PLANT', 'TRAIN', 'RIVER', 'STORM', 'BREAD', 'MUSIC', 'FLUTE',
  'BEAR', 'CHAIR', 'WATER', 'CLOCK', 'SNAKE', 'SHARK', 'CLOUD', 'LIGHT', 'PAPER', 'GREEN',
  'FLOWER', 'GARDEN', 'PENCIL', 'PLAZA', 'OASIS', 'BRIDGE',
  // Medium (length 7-8)
  'FLUTTER', 'ANDROID', 'CAPSULE', 'DOLPHIN', 'BLANKET', 'CRYSTAL', 'JOURNEY', 'PHANTOM', 'OCTOPUS', 'PENGUIN',
  'HARMONY', 'VICTORY', 'FEATHER', 'SILENCE', 'MONSTER', 'PYRAMID', 'LANTERN', 'STADIUM', 'GALAXY', 'SPARROW',
  'MONUMENT', 'TREASURE', 'KEYBOARD', 'HORIZON', 'ARCHIVE', 'BLOSSOM',
  // Hard (length 8+ with complex letter combinations)
  'QUANTUM', 'EMPEROR', 'SATELLITE', 'SPAGHETTI', 'ASTRONOMY', 'LABYRINTH', 'XENOPHOBE', 'ZUCCHINI', 'METAMORPH', 'DICHOTOMY',
  'ALGORITHM', 'SYMPHONY', 'HIEROGLYPH', 'EUCALYPTUS', 'LABORATORY', 'CATASTROPHE', 'ARCHAEOLOGY', 'KALEIDOSCOPE', 'QUINTESSENTIAL', 'AMBIDEXTROUS',
  'JUXTAPOSE', 'OBFUSCATE', 'NEBULOUS', 'EPHEMERAL', 'VINDICATE', 'PERPLEXED', 'EQUILIBRIUM', 'CONUNDRUM', 'SOLILOQUY', 'CACOPHONY',
  'COMPLEXITY', 'VICISSITUDE', 'ANACHRONISM', 'KILOBYTE', 'SYNDROME', 'VOCABULARY', 'LABYRINTHINE', 'AERODYNAMIC', 'CENTRIFUGAL',
  'THERMODYNAMICS', 'PHOTOSYNTHESIS', 'BIODIVERSITY', 'METEOROLOGY', 'SEISMOLOGY', 'GEOTHERMAL', 'PALEONTOLOGY', 'BIBLIOGRAPHY',
  'PHILANTHROPY', 'OSCILLOSCOPE', 'SPECTROSCOPY', 'METALLURGY', 'CRYSTALLOGRAPHY', 'THERAPEUTIC', 'NEUROLOGICAL'
];

class HangmanScreen extends StatefulWidget {
  const HangmanScreen({super.key});
  @override
  State<HangmanScreen> createState() => _HangmanScreenState();
}

class _HangmanScreenState extends State<HangmanScreen> {
  int _levelIndex = 0;
  late String _word;
  late Set<String> _guessed;
  int _wrong = 0;
  int get _maxWrong {
    if (_playDailyMode && _dailyModifierType == 'whisper') return 3;
    if (_levelIndex < 100) return 6;
    if (_levelIndex < 200) return 5;
    return 4;
  }
  bool _gameOver = false;
  bool _won = false;

  int _hintCount = 0;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  String _failedWord = '';

  @override
  void initState() {
    super.initState();
    // Default synchronous initialization to avoid LateInitializationError
    _word = _kGameWords[0];
    _guessed = {};
    _initLevel();
  }

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('hangman');
    final prefs = await SharedPreferences.getInstance();
    _failedWord = prefs.getString('failed_hangman_word') ?? '';
    _playDailyMode = prefs.getBool('play_daily_mode') ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString('daily_modifier_type') ?? '';
    }

    final savedLevel = prefs.getInt('level_hangman') ?? 0;
    if (savedLevel >= _kGameWords.length && !_playDailyMode) {
      if (mounted) {
        GameCompletedScreen.show(
          context,
          gameName: 'Hangman',
          prefKey: 'level_hangman',
          routeName: '/hangman',
        );
      }
      return;
    }
    if (mounted) {
      setState(() {
        _levelIndex = savedLevel;
        _loadLevel(prefs);
      });
    }

    if (_playDailyMode) {
      Future.delayed(Duration.zero, () async {
        if (!mounted) return;
        final savedStateStr = prefs.getString('daily_hangman_state');
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
                    'You have an ongoing game. Do you want to continue?',
                    style: GoogleFonts.outfit(color: context.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('New Game', style: GoogleFonts.outfit(color: context.textMuted)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Continue', style: GoogleFonts.outfit(color: AppTheme.dustyMauve)),
                    ),
                  ],
                ),
              );
              if (continueGame == true && mounted) {
                setState(() {
                  _word = data['word'];
                  _guessed = List<String>.from(data['guessed']).toSet();
                  _wrong = data['wrong'];
                  _won = data['won'];
                  _gameOver = data['gameOver'];
                });
              } else {
                await _clearDailyState();
                if (mounted) {
                  setState(() {
                    _loadLevel(null, true);
                  });
                }
              }
            }
          } catch (e) {
            // ignore
          }
        }
      });
    }
  }

  Future<void> _saveDailyState() async {
    if (!_playDailyMode || _won) return;
    final prefs = await SharedPreferences.getInstance();
    final state = {
      'levelIndex': _levelIndex,
      'word': _word,
      'guessed': _guessed.toList(),
      'wrong': _wrong,
      'won': _won,
      'gameOver': _gameOver,
    };
    await prefs.setString('daily_hangman_state', jsonEncode(state));
  }

  Future<void> _clearDailyState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('daily_hangman_state');
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hangman_word', _word);
    await prefs.setStringList('hangman_guessed', _guessed.toList());
    await prefs.setInt('hangman_wrong', _wrong);
    await prefs.setBool('hangman_won', _won);
    await prefs.setBool('hangman_gameover', _gameOver);
  }

  Future<void> _clearState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('hangman_word');
    await prefs.remove('hangman_guessed');
    await prefs.remove('hangman_wrong');
    await prefs.remove('hangman_won');
    await prefs.remove('hangman_gameover');
  }

  Future<void> _savePersistedLevel(int lvl) async {
    if (_playDailyMode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_hangman', lvl);
    final earned = await HintManager.onLevelCleared('hangman');
    final newCount = await HintManager.getHints('hangman');
    setState(() {
      _hintCount = newCount;
    });
    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hint earned! (Total: $newCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.accentFor('hangman'),
        ),
      );
    }
  }

  Future<void> _useHint() async {
    if (_gameOver || _hintCount <= 0) return;
    final unrevealed = _word.split('').where((c) => !_guessed.contains(c)).toSet().toList();
    if (unrevealed.isEmpty) return;

    final hintLetter = unrevealed[Random().nextInt(unrevealed.length)];
    await HintManager.useHint('hangman');
    final newCount = await HintManager.getHints('hangman');
    setState(() {
      _hintCount = newCount;
      _guess(hintLetter);
    });
  }

  String _pickWordForLevel(int level) {
    final rng = Random();
    if (level < 15) {
      return _kGameWords[rng.nextInt(26)];
    } else if (level < 35) {
      return _kGameWords[26 + rng.nextInt(26)];
    } else {
      final hardCount = _kGameWords.length - 52;
      return _kGameWords[52 + rng.nextInt(hardCount)];
    }
  }

  void _loadLevel([SharedPreferences? prefs, bool forceNewWord = false]) {
    if (prefs != null && !forceNewWord) {
      final savedWord = prefs.getString('hangman_word');
      if (savedWord != null) {
        _word = savedWord;
        _guessed = (prefs.getStringList('hangman_guessed') ?? []).toSet();
        _wrong = prefs.getInt('hangman_wrong') ?? 0;
        _won = prefs.getBool('hangman_won') ?? false;
        _gameOver = prefs.getBool('hangman_gameover') ?? false;
        return;
      }
    }
    _word = _pickWordForLevel(_levelIndex);
    if (_word == _failedWord) {
      int attempts = 0;
      while (_word == _failedWord && attempts < 10) {
        _word = _pickWordForLevel(_levelIndex);
        attempts++;
      }
    }
    _guessed = {};
    _wrong = 0;
    _gameOver = false;
    _won = false;
    _clearState();

    if (_playDailyMode && _dailyModifierType == 'whisper') {
      final vowels = {'A', 'E', 'I', 'O', 'U'};
      for (final letter in _word.split('')) {
        if (vowels.contains(letter)) {
          _guessed.add(letter);
        }
      }
    }
  }

  void _reset() {
    _clearState();
    if (_playDailyMode) {
      _clearDailyState();
    }
    if (_gameOver && !_won) {
      _failedWord = _word;
      SharedPreferences.getInstance().then((p) => p.setString('failed_hangman_word', _word));
    }
    setState(() => _loadLevel(null, true));
  }

  void _guess(String letter) {
    if (_gameOver || _guessed.contains(letter)) return;
    setState(() {
      _guessed.add(letter);
      bool correct = _word.contains(letter);
      if (!correct) {
        _wrong++;
        if (_wrong >= _maxWrong) {
          _gameOver = true;
          _failedWord = _word;
          SharedPreferences.getInstance().then((p) => p.setString('failed_hangman_word', _word));
          AudioManager.playFail();
        } else {
          AudioManager.playFail();
        }
      }
      if (_word.split('').every(_guessed.contains)) {
        _gameOver = true;
        _won = true;
        AudioManager.playSuccess();
        _savePersistedLevel(_levelIndex + 1);
        _failedWord = '';
        SharedPreferences.getInstance().then((p) => p.remove('failed_hangman_word'));
      } else if (correct) {
        AudioManager.playClick();
      }
      _saveState();

      if (_playDailyMode) {
        if (_won || _gameOver) {
          _clearDailyState();
        } else {
          _saveDailyState();
        }
      }
    });
  }

  void _nextLevel() {
    if (!_won) return;
    if (_playDailyMode) {
      Navigator.pop(context, true);
      return;
    }
    if (_levelIndex >= _kGameWords.length - 1) {
      GameCompletedScreen.show(
        context,
        gameName: 'Hangman',
        prefKey: 'level_hangman',
        routeName: '/hangman',
      );
      return;
    }
    _clearState();
    setState(() {
      _levelIndex = _levelIndex + 1;
      _loadLevel(null, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayWord = _word.split('').map((c) => _guessed.contains(c) ? c : '_').join('  ');
    final accentColor = AppTheme.accentFor('hangman');
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark, foregroundColor: context.textPrimary,
        title: Text('Hangman', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.lightbulb_outline, size: 20, color: context.textMuted),
                Positioned(
                  right: -4,
                  top: -4,
                  child: CircleAvatar(
                    radius: 6,
                    backgroundColor: Colors.amber,
                    child: Text(
                      '$_hintCount',
                      style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            onPressed: _hintCount > 0 && !_gameOver ? _useHint : null,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            color: context.textMuted,
            onPressed: () => RulesHelper.showRulesBottomSheet(context, 'hangman', 'Hangman'),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _reset, color: context.textMuted),
          Padding(padding: const EdgeInsets.only(right: 12),
            child: Center(child: Text(_playDailyMode ? 'Daily' : 'Level ${_levelIndex + 1}', style: AppTheme.numberStyle(color: accentColor, fontSize: context.scale(13))))),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                child: Builder(
                  builder: (context) {
                    Widget hangmanContent = Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Drawing + word side-by-side — compact top section
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                            CustomPaint(size: Size(context.scale(130), context.scale(140)), painter: _HangmanPainter(_wrong, accentColor)),
                            Column(mainAxisSize: MainAxisSize.min, children: [
                              Text(displayWord, style: GoogleFonts.outfit(fontSize: context.scale(20), fontWeight: FontWeight.w700, color: context.textPrimary, letterSpacing: 3)),
                              const SizedBox(height: 8),
                              Row(children: List.generate(_maxWrong, (i) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: Icon(i < _wrong ? Icons.close : Icons.favorite_outline, size: 15,
                                  color: i < _wrong ? Colors.redAccent : context.textMuted),
                              ))),
                            ]),
                          ]),
                        ),
                        if (_gameOver && _won && !_playDailyMode) ...[
                          Text(
                            'Correct! The word was $_word',
                            style: GoogleFonts.outfit(fontSize: context.scale(15), fontWeight: FontWeight.w700,
                              color: accentColor),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          AutoNextCountdown(
                            onNext: _nextLevel,
                            accentColor: accentColor,
                          ),
                        ],
                        const SizedBox(height: 4),
                        // Keyboard directly below
                        if (!_gameOver) _buildKeyboard(context, accentColor),
                        const SizedBox(height: 8),
                      ],
                    );

                    if (_playDailyMode && _dailyModifierType == 'mirror') {
                      hangmanContent = Transform(
                        transform: Matrix4.identity()..scale(-1.0, 1.0),
                        alignment: Alignment.center,
                        child: hangmanContent,
                      );
                    }
                    return hangmanContent;
                  },
                ),
              ),
            ),
            if (_gameOver && _won && _playDailyMode)
              Positioned.fill(
                child: ChallengeClearedOverlay(
                  accentColor: accentColor,
                  onComplete: () {
                    Navigator.pop(context, true);
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _gameOver && !_won
          ? LossOverlay(
              onTryAgain: _reset,
              subtitle: 'Failed on level ${_levelIndex + 1}.',
              accentColor: accentColor,
              extraContent: [
                const SizedBox(height: 12),
                Text('The word was:', style: GoogleFonts.outfit(fontSize: 13, color: context.textMuted)),
                const SizedBox(height: 4),
                Text(_word, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary, letterSpacing: 2)),
              ],
            )
          : null,
    );
  }

  Widget _buildKeyboard(BuildContext context, Color accentColor) {
    const rows = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];
    return Column(mainAxisSize: MainAxisSize.min,
      children: rows.map((row) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: row.split('').map((l) {
          final used = _guessed.contains(l);
          final correct = used && _word.contains(l);
          final wrong = used && !_word.contains(l);
          return GestureDetector(onTap: () => _guess(l),
            child: Container(
              width: context.scale(32), height: context.scale(40), margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: correct 
                    ? accentColor 
                    : wrong 
                        ? (context.isDarkMode ? const Color(0xFF222232) : const Color(0xFFEFEFF4)) 
                        : context.bgCard,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: correct 
                      ? accentColor 
                      : wrong 
                          ? Colors.transparent 
                          : context.textMuted.withAlpha(65),
                  width: 1.0,
                ),
                boxShadow: (correct || wrong) ? null : AppTheme.cardShadow,
              ),
              child: Center(child: Text(l, style: GoogleFonts.outfit(fontSize: context.scale(13), fontWeight: FontWeight.bold,
                color: correct
                    ? Colors.white
                    : wrong 
                        ? context.textMuted.withAlpha(120) 
                        : context.textPrimary))),
            ));
        }).toList()),
      )).toList(),
    );
  }
}

class _HangmanPainter extends CustomPainter {
  final int wrong;
  final Color strokeColor;
  _HangmanPainter(this.wrong, this.strokeColor);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = strokeColor..strokeWidth = 3..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(10, size.height - 5), Offset(size.width - 10, size.height - 5), p);
    canvas.drawLine(Offset(40, size.height - 5), const Offset(40, 5), p);
    canvas.drawLine(const Offset(40, 5), Offset(size.width - 25, 5), p);
    canvas.drawLine(Offset(size.width - 25, 5), Offset(size.width - 25, 25), p);
    if (wrong < 1) return;
    canvas.drawCircle(Offset(size.width - 25, 37), 11, p);
    if (wrong < 2) return;
    canvas.drawLine(Offset(size.width - 25, 48), Offset(size.width - 25, 85), p);
    if (wrong < 3) return;
    canvas.drawLine(Offset(size.width - 25, 60), Offset(size.width - 44, 76), p);
    if (wrong < 4) return;
    canvas.drawLine(Offset(size.width - 25, 60), Offset(size.width - 6, 76), p);
    if (wrong < 5) return;
    canvas.drawLine(Offset(size.width - 25, 85), Offset(size.width - 44, 108), p);
    if (wrong < 6) return;
    canvas.drawLine(Offset(size.width - 25, 85), Offset(size.width - 6, 108), p);
  }
  @override
  bool shouldRepaint(_HangmanPainter old) => old.wrong != wrong || old.strokeColor != strokeColor;
}
