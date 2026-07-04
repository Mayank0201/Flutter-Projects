import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/rules_helper.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/audio_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/loss_overlay.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../widgets/challenge_cleared_overlay.dart';

enum _Phase { showing, input, correct, wrong }

class NumberMemoryScreen extends StatefulWidget {
  final int? dailyLevelIndex;
  const NumberMemoryScreen({super.key, this.dailyLevelIndex});
  @override
  State<NumberMemoryScreen> createState() => _NumberMemoryScreenState();
}

class _NumberMemoryScreenState extends State<NumberMemoryScreen> {
  int _levelIndex = 0;
  _Phase _phase = _Phase.showing;
  String _number = '';
  int _digits = 3;
  final _rng = Random();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _won = false;

  int _hintCount = 0;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  String _dailyModifierName = '';

  int get _displayDurationMs {
    if (_playDailyMode && _dailyModifierType == 'time_warp') {
      return 2000;
    }
    return _digits * 400 + 500;
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_saveDailyState);
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
      targetLevel = prefs.getInt('level_numbermemory') ?? 0;
    }



    if (mounted) {
      setState(() {
        _levelIndex = targetLevel;
      });
    }

    if (_playDailyMode) {
      final savedStateStr = prefs.getString('daily_numbermemory_state');
      if (savedStateStr != null) {
        try {
          final data = jsonDecode(savedStateStr);
          if (data['levelIndex'] == _levelIndex) {
            if (mounted) {
              final continueGame = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  backgroundColor: context.bgCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: context.textMuted.withAlpha(40),
                    ),
                  ),
                  title: Text(
                    'Continue Game?',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  content: Text(
                    'We found a saved state for this challenge. Would you like to continue playing or start a new game?',
                    style: GoogleFonts.outfit(color: context.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx, false); // New Game
                      },
                      child: Text(
                        'New Game',
                        style: GoogleFonts.outfit(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx, true); // Continue
                      },
                      child: Text(
                        'Continue',
                        style: GoogleFonts.outfit(
                          color: AppTheme.dustyMauve,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ) ?? false;

              if (continueGame && mounted) {
                final int phaseIndex = data['phase'];
                setState(() {
                  _levelIndex = data['levelIndex'];
                  _phase = _Phase.values[phaseIndex];
                  _number = data['number'];
                  _digits = data['digits'];
                  _won = data['won'];
                  _controller.text = data['typedText'] ?? '';
                });

                if (_phase == _Phase.showing) {
                  // Re-start showing delay
                  Future.delayed(
                    Duration(milliseconds: _displayDurationMs),
                    () {
                      if (mounted && _phase == _Phase.showing) {
                        setState(() {
                          _phase = _Phase.input;
                          _focusNode.requestFocus();
                        });
                        _saveDailyState();
                      }
                    },
                  );
                }
              } else {
                await _clearDailyState();
                if (mounted) {
                  setState(() {
                    _startRound();
                  });
                }
              }
            }
            return;
          }
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _startRound();
      });
    }
  }

  Future<void> _saveDailyState() async {
    if (!_playDailyMode || _won) return;
    final prefs = await SharedPreferences.getInstance();
    final state = {
      'levelIndex': _levelIndex,
      'phase': _phase.index,
      'number': _number,
      'digits': _digits,
      'won': _won,
      'typedText': _controller.text,
    };
    await prefs.setString('daily_numbermemory_state', jsonEncode(state));
  }

  Future<void> _clearDailyState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('daily_numbermemory_state');
  }

  Future<void> _savePersistedLevel(int lvl) async {
    if (_playDailyMode) return;
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
          content: Text(
            'Hint earned! (Total: $newCount)',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.accentFor('numbermemory'),
        ),
      );
    }
    await _clearDailyState();
  }

  String _getHintText(String current, String target) {
    if (current.isEmpty) {
      return target.isNotEmpty ? target[0] : '';
    }
    int mismatchIndex = -1;
    for (int i = 0; i < current.length; i++) {
      if (i >= target.length) {
        mismatchIndex = i;
        break;
      }
      if (current[i] != target[i]) {
        mismatchIndex = i;
        break;
      }
    }
    if (mismatchIndex != -1) {
      if (mismatchIndex < target.length) {
        return target.substring(0, mismatchIndex + 1);
      } else {
        return target;
      }
    } else {
      if (current.length < target.length) {
        return target.substring(0, current.length + 1);
      } else {
        return target;
      }
    }
  }

  Future<void> _useHint() async {
    if (_phase != _Phase.input || _won || _hintCount <= 0) return;
    final currentText = _controller.text.trim();
    if (currentText == _number) return;

    await HintManager.useHint('numbermemory');
    final newCount = await HintManager.getHints('numbermemory');
    setState(() {
      _hintCount = newCount;
      _controller.text = _getHintText(currentText, _number);
      AudioManager.playClick();
    });
  }

  void _startRound() {
    _digits =
        _levelIndex +
        3; // level 1 (index 0) has 3 digits, level 2 (index 1) has 4 digits, etc.
    _number = _generateNumber(_digits);
    _controller.clear();
    _phase = _Phase.showing;
    _won = false;

    // Show number for _displayDurationMs then switch to input
    Future.delayed(Duration(milliseconds: _displayDurationMs), () {
      if (mounted && _phase == _Phase.showing) {
        setState(() {
          _phase = _Phase.input;
          _focusNode.requestFocus();
        });
        _saveDailyState();
      }
    });
    _saveDailyState();
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
    setState(() {
      if (guess == _number) {
        _won = true;
        _phase = _Phase.correct;
        AudioManager.playSuccess();
        _savePersistedLevel(_levelIndex + 1);
      } else {
        settingsNotifier.hapticError();
        _phase = _Phase.wrong;
        AudioManager.playFail();
        _saveDailyState();
      }
    });
  }

  void _reset() {
    setState(() {
      _startRound();
    });
  }

  void _nextLevel() {
    if (!_won) return;

    setState(() {
      _levelIndex = _levelIndex + 1;
      _startRound();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_number.isEmpty) {
      return Scaffold(
        backgroundColor: context.bgDark,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    final accent = AppTheme.accentFor('numbermemory');
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: Text(
          'Number Memory',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
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
                      '$_hintCount',
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
            onPressed: _hintCount > 0 && _phase == _Phase.input && !_won
                ? _useHint
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            color: context.textMuted,
            onPressed: () => RulesHelper.showRulesBottomSheet(
              context,
              'numbermemory',
              'Number Memory',
            ),
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
                style: AppTheme.numberStyle(color: accent, fontSize: context.scale(13)),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    if (_playDailyMode)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
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
                    if (_phase == _Phase.showing) ...[
                      Text(
                        'Memorize this number',
                        style: GoogleFonts.outfit(
                          color: context.textMuted,
                          fontSize: context.scale(14),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: _number.split('').asMap().entries.map((
                            entry,
                          ) {
                            final idx = entry.key;
                            final char = entry.value;
                            return _GlitchedText(
                                  originalChar: char,
                                  style: AppTheme.numberStyle(
                                    fontSize: context.scale(40),
                                    fontWeight: FontWeight.w900,
                                    color: accent,
                                    letterSpacing: 4,
                                  ),
                                  enabled:
                                      _playDailyMode &&
                                      _dailyModifierType == 'glitch',
                                )
                                .animate()
                                .scale(
                                  begin: const Offset(0.4, 0.4),
                                  end: const Offset(1.0, 1.0),
                                  duration: 350.ms,
                                  curve: Curves.easeOutBack,
                                  delay: (idx * 80).ms,
                                )
                                .fadeIn(duration: 250.ms, delay: (idx * 80).ms);
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: _displayDurationMs),
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
                      Text(
                        'What was the number?',
                        style: GoogleFonts.outfit(
                          color: context.textMuted,
                          fontSize: context.scale(14),
                        ),
                      ),
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
                          counterText: '',
                          hintText: '...',
                          hintStyle: GoogleFonts.outfit(
                            color: context.textMuted.withAlpha(100),
                            fontSize: context.scale(24),
                          ),
                          filled: true,
                          fillColor: context.bgCard,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: context.textMuted.withAlpha(50),
                            ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 50,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _submit,
                        child: Text(
                          'Submit',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: context.scale(15),
                          ),
                        ),
                      ),
                    ],

                    if (_phase == _Phase.correct) ...[
                      Icon(
                        Icons.check_circle,
                        color: accent,
                        size: context.scale(56),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Correct!',
                        style: GoogleFonts.outfit(
                          fontSize: context.scale(24),
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_digits digits',
                        style: AppTheme.numberStyle(
                          fontSize: context.scale(14),
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_won) ...[
                        Text(
                          'Level cleared!',
                          style: GoogleFonts.outfit(
                            fontSize: context.scale(16),
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 16),
                        AutoNextCountdown(
                          onNext: _nextLevel,
                          accentColor: accent,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (_won && _playDailyMode)
            Positioned.fill(
              child: ChallengeClearedOverlay(
                accentColor: accent,
                onComplete: () {
                  Navigator.pop(context, true);
                },
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _phase == _Phase.wrong
          ? LossOverlay(
              onTryAgain: _reset,
              subtitle: 'Failed at Level ${_levelIndex + 1} ($_digits digits).',
              accentColor: accent,
              extraContent: [
                const SizedBox(height: 12),
                Text(
                  'The number was:',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _number,
                  style: AppTheme.numberStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You typed: ${_controller.text}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            )
          : null,
    );
  }
}

class _GlitchedText extends StatefulWidget {
  final String originalChar;
  final TextStyle style;
  final bool enabled;

  const _GlitchedText({
    Key? key,
    required this.originalChar,
    required this.style,
    required this.enabled,
  }) : super(key: key);

  @override
  State<_GlitchedText> createState() => _GlitchedTextState();
}

class _GlitchedTextState extends State<_GlitchedText> {
  late String _displayedChar;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _displayedChar = widget.originalChar;
    if (widget.enabled) {
      _startGlitchCycle();
    }
  }

  void _startGlitchCycle() {
    _scheduleNextGlitch();
  }

  void _scheduleNextGlitch() {
    if (!mounted) return;
    final delay = Duration(milliseconds: 300 + _rng.nextInt(900));
    Future.delayed(delay, () {
      if (!mounted) return;
      final glitchChars = ['@', '#', '*', '&', '%', '?', '!', '\$', '0', 'X'];
      setState(() {
        _displayedChar = glitchChars[_rng.nextInt(glitchChars.length)];
      });

      final duration = Duration(milliseconds: 80 + _rng.nextInt(100));
      Future.delayed(duration, () {
        if (!mounted) return;
        setState(() {
          _displayedChar = widget.originalChar;
        });
        _scheduleNextGlitch();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(_displayedChar, style: widget.style);
  }
}
