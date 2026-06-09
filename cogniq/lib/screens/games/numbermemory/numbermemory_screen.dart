import'dart:math';
import'package:flutter/material.dart';
import'package:google_fonts/google_fonts.dart';
import'package:shared_preferences/shared_preferences.dart';
import'../../../utils/rules_helper.dart';
import'../../../theme/app_theme.dart';
import'../../../theme/settings_manager.dart';
import'../../../utils/hint_manager.dart';

// 30 levels: digit count required to pass
const List<int> _kDigitTargets = [
  3, 3, 4, 4, 5, 5, 6, 6, 7, 7,
  8, 8, 9, 9, 10, 10, 11, 11, 12, 12,
  13, 14, 15, 16, 17, 18, 19, 20, 22, 25,
  // 10 new targets
  4, 4, 5, // Easy
  6, 7, 8, // Medium
  10, 12, 15, 20, // Hard
];

enum _Phase { showing, input, correct, wrong }

class NumberMemoryScreen extends StatefulWidget {
  const NumberMemoryScreen({super.key});
  @override
  State<NumberMemoryScreen> createState() => _NumberMemoryScreenState();
}

class _NumberMemoryScreenState extends State<NumberMemoryScreen> {
  int _levelIndex = 0;
  _Phase _phase = _Phase.showing;
  String _number ='';
  int _digits = 3;
  int _currentStreak = 0;
  final _rng = Random();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _gameOver = false;
  bool _won = false;

  int _hintCount = 0;

  @override
  void initState() {
    super.initState();
    _initLevel();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('numbermemory');
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('level_numbermemory') ?? 0;
    if (mounted) setState(() { _levelIndex = saved % _kDigitTargets.length; _startRound(); });
  }

  Future<void> _savePersistedLevel(int lvl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_numbermemory', lvl);
    final earned = await HintManager.onLevelCleared('numbermemory');
    final newCount = await HintManager.getHints('numbermemory');
    setState(() {
      _hintCount = newCount;
    });
    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hint earned! (Total: $newCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.accentFor('numbermemory'),
        ),
      );
    }
  }

  Future<void> _useHint() async {
    if (_phase != _Phase.input || _won || _hintCount <= 0) return;
    await HintManager.useHint('numbermemory');
    final newCount = await HintManager.getHints('numbermemory');
    setState(() {
      _hintCount = newCount;
      _controller.text = _number;
    });
  }

  void _startRound() {
    _digits = 3 + _currentStreak; // starts at 3 digits, grows
    _number = _generateNumber(_digits);
    _controller.clear();
    _phase = _Phase.showing;
    _gameOver = false;
    _won = false;

    // Show number for (digits * 400ms + 500ms) then switch to input
    Future.delayed(Duration(milliseconds: _digits * 400 + 500), () {
      if (mounted && _phase == _Phase.showing) {
        setState(() {
          _phase = _Phase.input;
          _focusNode.requestFocus();
        });
      }
    });
  }

  String _generateNumber(int len) {
    final sb = StringBuffer();
    sb.write(_rng.nextInt(9) + 1); // first digit non-zero
    for (int i = 1; i < len; i++) {
      sb.write(_rng.nextInt(10));
    }
    return sb.toString();
  }

  void _submit() {
    final guess = _controller.text.trim();
    if (guess.isEmpty) return;
    final target = _kDigitTargets[_levelIndex % _kDigitTargets.length];
    setState(() {
      if (guess == _number) {
        _currentStreak++;
        settingsNotifier.hapticSuccess();
        if (_currentStreak >= target) {
          _won = true;
          _gameOver = true;
          _phase = _Phase.correct;
          _savePersistedLevel(_levelIndex);
        } else {
          _phase = _Phase.correct;
        }
      } else {
        settingsNotifier.hapticError();
        _phase = _Phase.wrong;
        _gameOver = true;
      }
    });
  }

  void _continueAfterCorrect() {
    setState(() => _startRound());
  }

  void _reset() {
    setState(() {
      _currentStreak = 0;
      _startRound();
    });
  }

  void _nextLevel() {
    setState(() {
      _levelIndex = (_levelIndex + 1) % _kDigitTargets.length;
      _savePersistedLevel(_levelIndex);
      _currentStreak = 0;
      _startRound();
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentFor('numbermemory');
    final target = _kDigitTargets[_levelIndex % _kDigitTargets.length];
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: Text('Number Memory', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
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
            onPressed: _hintCount > 0 && _phase == _Phase.input && !_won ? _useHint : null,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            color: context.textMuted,
            onPressed: () => RulesHelper.showRulesBottomSheet(context,'numbermemory','Number Memory'),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _reset, color: context.textMuted),
          Padding(padding: const EdgeInsets.only(right: 12),
            child: Center(child: Text('Level ${_levelIndex + 1}', style: GoogleFonts.outfit(color: accent, fontSize: context.scale(13))))),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Progress
                Text(
'Streak: $_currentStreak / $target digits',
                  style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(13)),
                ),
                const SizedBox(height: 30),

                if (_phase == _Phase.showing) ...[
                  Text('Memorize this number', style: GoogleFonts.outfit(color: context.textMuted, fontSize: context.scale(14))),
                  const SizedBox(height: 20),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _number,
                      style: GoogleFonts.outfit(
                        fontSize: context.scale(40),
                        fontWeight: FontWeight.w900,
                        color: accent,
                        letterSpacing: 6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: _digits * 400 + 500),
                    tween: Tween<double>(begin: 1.0, end: 0.0),
                    builder: (context, value, child) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: value,
                          color: accent,
                          backgroundColor: context.bgSurface,
                          minHeight: 6,
                        ),
                      );
                    },
                  ),
                ],

                if (_phase == _Phase.input) ...[
                  Text('What was the number?', style: GoogleFonts.outfit(color: context.textMuted, fontSize: context.scale(14))),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    style: GoogleFonts.outfit(
                      color: context.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: context.scale(24),
                      letterSpacing: 4,
                    ),
                    decoration: InputDecoration(
                      counterText:'',
                      hintText:'...',
                      hintStyle: GoogleFonts.outfit(color: context.textMuted.withAlpha(100), fontSize: context.scale(24)),
                      filled: true,
                      fillColor: context.bgCard,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.textMuted.withAlpha(50)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: accent, width: 2),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: _submit,
                    child: Text('Submit', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: context.scale(15))),
                  ),
                ],

                if (_phase == _Phase.correct) ...[
                  Icon(Icons.check_circle, color: accent, size: context.scale(56)),
                  const SizedBox(height: 12),
                  Text('Correct!', style: GoogleFonts.outfit(fontSize: context.scale(24), fontWeight: FontWeight.w700, color: accent)),
                  const SizedBox(height: 4),
                  Text('$_digits digits', style: GoogleFonts.outfit(fontSize: context.scale(14), color: context.textSecondary)),
                  const SizedBox(height: 20),
                  if (!_gameOver)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: _continueAfterCorrect,
                      child: Text('Continue →', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: context.scale(14))),
                    ),
                  if (_won) ...[
                    const SizedBox(height: 8),
                    Text('Level cleared!', style: GoogleFonts.outfit(fontSize: context.scale(16), fontWeight: FontWeight.w600, color: accent)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: _nextLevel,
                      child: Text('Next Level →', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: context.scale(14))),
                    ),
                  ],
                ],

                if (_phase == _Phase.wrong) ...[
                  Icon(Icons.cancel, color: Colors.redAccent, size: context.scale(56)),
                  const SizedBox(height: 12),
                  Text('Wrong!', style: GoogleFonts.outfit(fontSize: context.scale(24), fontWeight: FontWeight.w700, color: Colors.redAccent)),
                  const SizedBox(height: 8),
                  Text('The number was', style: GoogleFonts.outfit(fontSize: context.scale(13), color: context.textMuted)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(_number, style: GoogleFonts.outfit(fontSize: context.scale(28), fontWeight: FontWeight.w800, color: context.textPrimary, letterSpacing: 4)),
                  ),
                  const SizedBox(height: 4),
                  Text('You typed: ${_controller.text}', style: GoogleFonts.outfit(fontSize: context.scale(13), color: Colors.redAccent)),
                  const SizedBox(height: 4),
                  Text('Reached $_currentStreak / $target digits streak', style: GoogleFonts.outfit(fontSize: context.scale(13), color: context.textSecondary)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: _reset,
                    child: Text('Try Again', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: context.scale(14))),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
