import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/rules_helper.dart';
import 'dart:math';

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
  'ABACK', 'FLOUT', 'GHOUL', 'FLAIR', 'BLITZ', 'SPRYLY', 'KNOLL', 'VAGUE',
  'GNASH', 'DOUBT', 'CLIMB', 'KNACK', 'GHOST', 'KNIFE', 'KNEAD', 'KNELL',
  'PSALM', 'WREAK', 'WRITE', 'WHOLE', 'WRONG', 'GNOME', 'PUPPY', 'FUZZY',
  'MUMMY', 'CHEEK', 'GEESE', 'DROLL', 'SKULL', 'ERROR', 'FLOOD', 'SPOON',
  'KRILL', 'STIFF', 'CLIFF', 'TOOTH', 'SHEEP', 'STEER', 'SPOOF', 'STAFF',
  'DRESS', 'CROSS', 'FLICK', 'SPARK', 'BRICK', 'PROXY'
];

class WordleScreen extends StatefulWidget {
  final int? dailyLevelIndex;
  const WordleScreen({super.key, this.dailyLevelIndex});
  @override
  State<WordleScreen> createState() => _WordleScreenState();
}

class _WordleScreenState extends State<WordleScreen> {
  int _levelIndex = 0;
  late String _targetWord;
  final List<List<String>> _guesses = List.generate(6, (_) => List.filled(5, ''));
  final List<List<_TileState>> _states = List.generate(6, (_) => List.filled(5, _TileState.empty));
  int _currentRow = 0;
  String _currentInput = '';
  bool _gameOver = false;
  bool _won = false;
  String _message = '';
  bool _useSystemKeyboard = false;

  late final FocusNode _focusNode;
  late final FocusNode _keyboardFocusNode;
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _keyboardFocusNode = FocusNode();
    _textController = TextEditingController();
    // Default synchronous initialization to avoid LateInitializationError
    _targetWord = _k5Words[0];
    _initLevel();
  }

  int _hintCount = 0;

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('wordle');
    if (widget.dailyLevelIndex != null) {
      if (mounted) {
        setState(() {
          _levelIndex = widget.dailyLevelIndex!;
          _loadLevel();
        });
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final savedLevel = prefs.getInt('level_wordle') ?? 0;
    if (mounted) {
      setState(() {
        _levelIndex = savedLevel % _k5Words.length;
        _loadLevel();
      });
    }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Hint earned! (Total: $newCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            backgroundColor: AppTheme.wordleGreen,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _keyboardFocusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _loadLevel() {
    _targetWord = _k5Words[_levelIndex % _k5Words.length];
    for (int r = 0; r < 6; r++) {
      for (int c = 0; c < 5; c++) {
        _guesses[r][c] = '';
        _states[r][c] = _TileState.empty;
      }
    }
    _currentRow = 0;
    _currentInput = '';
    _gameOver = false;
    _won = false;
    _message = '';
    _textController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_gameOver) {
        if (_useSystemKeyboard) {
          _focusNode.requestFocus();
        } else {
          _keyboardFocusNode.requestFocus();
        }
      }
    });
  }

  void _reset() => setState(() => _loadLevel());

  void _handleSystemInput(String val) {
    if (_gameOver) {
      _textController.clear();
      return;
    }
    final clean = val.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (clean.length > 5) {
      _textController.text = clean.substring(0, 5);
      _textController.selection = TextSelection.fromPosition(TextPosition(offset: 5));
      return;
    }
    setState(() {
      _currentInput = clean;
      for (int i = 0; i < 5; i++) {
        _guesses[_currentRow][i] = i < _currentInput.length ? _currentInput[i] : '';
      }
    });
  }

  void _onKey(String key) {
    if (_gameOver) return;
    if (key == '⌫') {
      if (_currentInput.isNotEmpty) {
        final newVal = _currentInput.substring(0, _currentInput.length - 1);
        _textController.text = newVal;
        _textController.selection = TextSelection.fromPosition(TextPosition(offset: newVal.length));
        _handleSystemInput(newVal);
      }
    } else if (key == '↵') {
      if (_currentInput.length == 5) _submitGuess();
    } else if (_currentInput.length < 5) {
      final newVal = _currentInput + key;
      _textController.text = newVal;
      _textController.selection = TextSelection.fromPosition(TextPosition(offset: newVal.length));
      _handleSystemInput(newVal);
    }
  }

  void _submitGuess() {
    final guess = _currentInput;
    final target = _targetWord;
    final ns = List.filled(5, _TileState.absent);
    final tc = target.split('');
    final gc = guess.split('');
    for (int i = 0; i < 5; i++) {
      if (gc[i] == tc[i]) { ns[i] = _TileState.correct; tc[i] = '_'; gc[i] = '*'; }
    }
    for (int i = 0; i < 5; i++) {
      if (gc[i] != '*') { final j = tc.indexOf(gc[i]); if (j != -1) { ns[i] = _TileState.present; tc[j] = '_'; } }
    }
    setState(() {
      _states[_currentRow] = ns;
      if (guess == target) {
        _won = true;
        _gameOver = true;
        _message = 'Correct! It was $target';
        _savePersistedLevel(_levelIndex);
      } else if (_currentRow == 5) {
        _gameOver = true;
        _message = 'Game Over! The word was $target';
      } else {
        _currentRow++;
        _currentInput = '';
        _textController.clear();
      }
    });
  }

  void _nextLevel() {
    if (widget.dailyLevelIndex != null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _levelIndex = (_levelIndex + 1) % _k5Words.length;
      _savePersistedLevel(_levelIndex);
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
    
    final unrevealed = targetLetters.where((l) => !guessedCorrectly.contains(l)).toList();
    if (unrevealed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You\'ve already found all letters!', style: GoogleFonts.outfit())),
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
        content: Text('Hint: The word contains the letter "$hintLetter"', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.wordleGreen,
      ),
    );
  }

  Widget _buildSystemInput(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              autofocus: true,
              maxLength: 5,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.outfit(
                color: context.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: context.scale(18),
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'TYPE GUESS',
                hintStyle: GoogleFonts.outfit(
                  color: context.textMuted.withAlpha(120),
                  fontWeight: FontWeight.w600,
                  fontSize: context.scale(14),
                  letterSpacing: 2,
                ),
                filled: true,
                fillColor: context.bgCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.textMuted.withAlpha(50)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.wordleGreen, width: 2),
                ),
              ),
              onChanged: (val) {
                _handleSystemInput(val);
              },
              onSubmitted: (_) {
                if (_currentInput.length == 5) {
                  _submitGuess();
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.wordleGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: _currentInput.length == 5 ? _submitGuess : null,
            child: Text(
              'SUBMIT',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: context.scale(13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (_useSystemKeyboard) return;
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
          backgroundColor: context.bgDark, foregroundColor: context.textPrimary,
          title: Text('Word Guess', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline, size: 20),
              color: context.textMuted,
              onPressed: () => RulesHelper.showRulesBottomSheet(context, 'wordle', 'Word Guess'),
            ),
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
              onPressed: _hintCount > 0 && !_gameOver ? _useWordleHint : null,
            ),
            IconButton(
              icon: Icon(_useSystemKeyboard ? Icons.grid_on : Icons.keyboard, size: 20),
              onPressed: () {
                setState(() {
                  _useSystemKeyboard = !_useSystemKeyboard;
                  if (_useSystemKeyboard) {
                    _focusNode.requestFocus();
                  } else {
                    _keyboardFocusNode.requestFocus();
                  }
                });
              },
              color: context.textMuted,
            ),
            IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _reset, color: context.textMuted),
            Padding(padding: const EdgeInsets.only(right: 12),
              child: Center(child: Text('Level ${_levelIndex + 1}', style: GoogleFonts.outfit(color: AppTheme.wordleGreen, fontSize: context.scale(13))))),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_message.isNotEmpty) Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8),
                color: _won ? AppTheme.wordleGreen : const Color(0xFFB94040),
                child: Text(_message, textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: context.scale(14))),
              ),
              const SizedBox(height: 10),
              // Grid — compact
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(6, (row) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (col) =>
                            _WordleTile(letter: _guesses[row][col], state: _states[row][col])),
                        ),
                      )),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (!_gameOver) ...[
                if (_useSystemKeyboard)
                  _buildSystemInput(context)
                else
                  _WordleKeyboard(onKey: _onKey),
              ] else Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: _won
                  ? ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.wordleGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _nextLevel,
                      child: Text('Next Level →', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: context.scale(14))),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB94040),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _reset,
                      child: Text('Try Again', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: context.scale(14))),
                    ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TileState { empty, correct, present, absent }

class _WordleTile extends StatelessWidget {
  final String letter; final _TileState state;
  const _WordleTile({required this.letter, required this.state});
  Color getBg(BuildContext context) { switch (state) {
    case _TileState.correct: return AppTheme.wordleGreen;
    case _TileState.present: return AppTheme.wordleYellow;
    case _TileState.absent:  return context.isDarkMode ? const Color(0xFF3A3A3C) : const Color(0xFF9CA3AF);
    case _TileState.empty:   return Colors.transparent;
  }}
  @override
  Widget build(BuildContext context) => Container(
    width: context.scale(52), height: context.scale(52), margin: const EdgeInsets.symmetric(horizontal: 3),
    decoration: BoxDecoration(color: getBg(context), border: Border.all(
      color: letter.isNotEmpty && state == _TileState.empty ? context.textPrimary
           : state == _TileState.empty ? (context.isDarkMode ? const Color(0xFF3A3A3C) : const Color(0xFFD1D5DB)) : Colors.transparent,
      width: 2)),
    child: Center(child: Text(letter, style: GoogleFonts.outfit(fontSize: context.scale(22), fontWeight: FontWeight.w800, color: state == _TileState.empty ? context.textPrimary : Colors.white))),
  );
}

class _WordleKeyboard extends StatelessWidget {
  final void Function(String) onKey;
  const _WordleKeyboard({required this.onKey});
  static const _rows = [['Q','W','E','R','T','Y','U','I','O','P'],['A','S','D','F','G','H','J','K','L'],['↵','Z','X','C','V','B','N','M','⌫']];
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
    child: Column(mainAxisSize: MainAxisSize.min, children: _rows.map((row) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: row.map((key) {
        final isWide = key == '↵' || key == '⌫';
        return GestureDetector(onTap: () => onKey(key),
          child: Container(
            width: isWide ? context.scale(48) : context.scale(32), height: context.scale(42), margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: context.isDarkMode ? const Color(0xFF818384) : const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(child: Text(key, style: GoogleFonts.outfit(fontSize: isWide ? context.scale(14) : context.scale(13), fontWeight: FontWeight.w600, color: context.textPrimary))),
          ));
      }).toList()),
    )).toList()),
  );
}
