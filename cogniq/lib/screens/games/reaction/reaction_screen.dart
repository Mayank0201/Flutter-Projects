import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cogniq/widgets/buy_hints_dialog.dart';
import'package:google_fonts/google_fonts.dart';
import'package:shared_preferences/shared_preferences.dart';
import'../../../utils/rules_helper.dart';
import'../../../theme/app_theme.dart';
import'../../../theme/settings_manager.dart';
import'../../../utils/hint_manager.dart';
import'../../../utils/audio_manager.dart';
import'../../../widgets/auto_next_countdown.dart';
import'../../../widgets/loss_overlay.dart';
import'../../../widgets/animated_level_indicator.dart';
// 30 levels with decreasing target reaction times (ms)
const List<int> _kTargets = [
  500, 480, 460, 440, 420, 400, 380, 360, 340, 320,
  310, 300, 290, 280, 270, 260, 250, 240, 230, 220,
  215, 210, 205, 200, 195, 190, 185, 180, 175, 170,
];

enum _Phase { waiting, ready, go, result, tooEarly }

class ReactionScreen extends StatefulWidget {
  const ReactionScreen({super.key});
  @override
  State<ReactionScreen> createState() => _ReactionScreenState();
}

class _ReactionScreenState extends State<ReactionScreen> {
  int _levelIndex = 0;
  _Phase _phase = _Phase.waiting;
  int _reactionMs = 0;
  int _round = 0;
  final List<int> _results = [];
  Timer? _delayTimer;
  DateTime? _goTime;
  bool _gameOver = false;
  bool _won = false;
  bool _isDailyMode = false;
  bool _isDistractor = false;
  Color _distractorColor = Colors.red;
  bool _isFakeStart = false;

  int _hintCount = 0;

  @override
  void initState() {
    super.initState();
    _initLevel();
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    super.dispose();
  }

  int get _targetMs {
    if (_levelIndex < _kTargets.length) {
      return _kTargets[_levelIndex];
    }
    final extra = _levelIndex - _kTargets.length;
    return (170 - extra * 2).clamp(120, 170);
  }

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('reaction');
    final prefs = await SharedPreferences.getInstance();
    _isDailyMode = prefs.getBool('play_daily_mode') ?? false;
    final saved = prefs.getInt('level_reaction') ?? 0;
    if (mounted) setState(() { _levelIndex = saved; _resetGame(); });
  }

  Future<void> _saveLevel(int lvl) async {
    if (_isDailyMode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_reaction', lvl);
    final earned = await HintManager.onLevelCleared('reaction');
    final newCount = await HintManager.getHints('reaction');
    setState(() {
      _hintCount = newCount;
    });
    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hint earned! (Total: $newCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.accentFor('reaction'),
        ),
      );
    }
  }

  Future<void> _useHint() async {
    if (_won || _gameOver || _hintCount <= 0 || _phase == _Phase.result || _phase == _Phase.tooEarly) return;

    _delayTimer?.cancel();
    await HintManager.useHint('reaction');
    final newCount = await HintManager.getHints('reaction');

    setState(() {
      _hintCount = newCount;
      final target = _targetMs;
      final score = target - 15;
      _results.add(score);
      _round++;
      _reactionMs = score;
      _phase = _Phase.result;
      
      if (_round >= 5) {
        final avg = _results.reduce((a, b) => a + b) ~/ _results.length;
        _won = avg <= target;
        _gameOver = true;
        if (_won) {
          AudioManager.playSuccess();
          _saveLevel(_levelIndex + 1);
        } else {
          AudioManager.playFail();
        }
      } else {
        AudioManager.playClick();
      }
    });
  }

  void _resetGame() {
    _delayTimer?.cancel();
    _phase = _Phase.waiting;
    _round = 0;
    _results.clear();
    _gameOver = false;
    _won = false;
    _reactionMs = 0;
  }

  void _startRound() {
    setState(() {
      _phase = _Phase.ready;
      _isDistractor = false;
      _isFakeStart = false;
    });
    final delay = Duration(milliseconds: 1500 + (DateTime.now().millisecondsSinceEpoch % 3500));
    _delayTimer = Timer(delay, () {
      if (!mounted) return;
      
      final rand = Random();
      if (_isDailyMode && rand.nextDouble() < 0.5) {
        // Show distractor!
        setState(() {
          _isDistractor = true;
          _phase = _Phase.go; // so it's tappable/active
          _distractorColor = rand.nextBool() ? const Color(0xFFD32F2F) : const Color(0xFF1976D2); // Red or Blue
        });
        
        // Wait 1.0 second for the user to NOT tap
        _delayTimer = Timer(const Duration(milliseconds: 1000), () {
          if (!mounted) return;
          // User successfully avoided the distractor!
          setState(() {
            _phase = _Phase.ready;
            _isDistractor = false;
          });
          // Now proceed to the real green light after a short delay
          final nextDelay = Duration(milliseconds: 800 + rand.nextInt(1000));
          _delayTimer = Timer(nextDelay, () {
            if (!mounted) return;
            setState(() {
              _phase = _Phase.go;
              _goTime = DateTime.now();
            });
          });
        });
      } else {
        // Normal green light!
        setState(() {
          _phase = _Phase.go;
          _goTime = DateTime.now();
        });
      }
    });
  }

  void _onTap() {
    switch (_phase) {
      case _Phase.waiting:
        AudioManager.playClick();
        _startRound();
        break;
      case _Phase.ready:
        _delayTimer?.cancel();
        settingsNotifier.hapticError();
        AudioManager.playFail();
        setState(() {
          _phase = _Phase.tooEarly;
          _isFakeStart = false;
        });
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _phase = _Phase.waiting);
        });
        break;
      case _Phase.go:
        if (_isDistractor) {
          // Tapped on a distractor! Apply +1500ms penalty to this round.
          _delayTimer?.cancel();
          settingsNotifier.hapticError();
          AudioManager.playFail();
          const int penaltyMs = 1500;
          _reactionMs = penaltyMs;
          _results.add(penaltyMs);
          _round++;
          setState(() {
            _isDistractor = false;
            _isFakeStart = true;
            _phase = _Phase.tooEarly;
          });
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (!mounted) return;
            if (_round >= 5) {
              final avg = _results.reduce((a, b) => a + b) ~/ _results.length;
              final target = _targetMs;
              final won = avg <= target;
              setState(() { _gameOver = true; _won = won; _phase = _Phase.result; });
              if (won) { AudioManager.playSuccess(); _saveLevel(_levelIndex + 1); }
              else { AudioManager.playFail(); }
            } else {
              setState(() => _phase = _Phase.waiting);
            }
          });
          break;
        }
        _reactionMs = DateTime.now().difference(_goTime!).inMilliseconds;
        settingsNotifier.hapticTap();
        _results.add(_reactionMs);
        _round++;
        setState(() => _phase = _Phase.result);
        if (_round >= 5) {
          final avg = _results.reduce((a, b) => a + b) ~/ _results.length;
          final target = _targetMs;
          _won = avg <= target;
          _gameOver = true;
          if (_won) {
            AudioManager.playSuccess();
            _saveLevel(_levelIndex + 1);
          } else {
            AudioManager.playFail();
          }
        } else {
          AudioManager.playClick();
        }
        break;
      case _Phase.result:
        if (_gameOver) return;
        AudioManager.playClick();
        _startRound();
        break;
      case _Phase.tooEarly:
        break;
    }
  }

  void _nextLevel() {
    if (!_won) return;
    if (_isDailyMode) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _levelIndex = _levelIndex + 1;
      _resetGame();
    });
  }

  void _reset() => setState(() => _resetGame());

  Color _bgColor() {
    switch (_phase) {
      case _Phase.waiting: return context.bgDark;
      case _Phase.ready: return const Color(0xFFC05C55); // Terracotta
      case _Phase.go: return _isDistractor ? _distractorColor : const Color(0xFF6E8C6A); // Sage Green
      case _Phase.result: return context.bgDark;
      case _Phase.tooEarly: return const Color(0xFFC48F65); // Clay/Ochre
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentFor('reaction');
    final target = _targetMs;
    return Scaffold(
      backgroundColor: _bgColor(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: _phase == _Phase.waiting || _phase == _Phase.result ? context.textPrimary : Colors.white,
        title: Text('Reaction Time', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.lightbulb_outline, size: 20, color: _phase == _Phase.waiting || _phase == _Phase.result ? context.textMuted : Colors.white70),
                Positioned(
                  right: -4,
                  top: -4,
                  child: CircleAvatar(
                    radius: 6,
                    backgroundColor: Colors.amber,
                    child: Text(
_hintCount == 0 ? '+' : '$_hintCount',
                      style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            onPressed: !_won && !_gameOver
                ? () async {
                    if (_hintCount > 0) {
                      _useHint();
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'reaction',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('reaction');
                          if (mounted) setState(() => _hintCount = newCount);
                        },
                      );
                    }
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            color: _phase == _Phase.waiting || _phase == _Phase.result ? context.textMuted : Colors.white70,
            onPressed: () => RulesHelper.showRulesBottomSheet(context,'reaction','Reaction Time'),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _reset, color: _phase == _Phase.waiting || _phase == _Phase.result ? context.textMuted : Colors.white70),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AnimatedLevelIndicator(
              level: _levelIndex + 1,
              accentColor: accent,
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.expand(
          child: SafeArea(
            child: Column(
              children: [
                if (_isDailyMode)
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
                          'DAILY CHALLENGE: DISTRACTOR MODE',
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
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (_phase == _Phase.waiting && !_gameOver) ...[
                          Icon(Icons.touch_app_outlined, size: context.scale(64), color: context.textMuted),
                          const SizedBox(height: 20),
                          Text('Tap to Start', style: GoogleFonts.outfit(fontSize: context.scale(24), fontWeight: FontWeight.w700, color: context.textPrimary)),
                          const SizedBox(height: 8),
                          Text('Round ${_round + 1}/5 • Target: ${target}ms avg', style: AppTheme.numberStyle(fontSize: context.scale(13), color: context.textSecondary)),
                        ],
                        if (_phase == _Phase.ready) ...[
                          Text('Wait...', style: GoogleFonts.outfit(fontSize: context.scale(32), fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(height: 8),
                          Text('Tap when the screen turns GREEN', style: GoogleFonts.outfit(fontSize: context.scale(14), color: Colors.white70)),
                        ],
                        if (_phase == _Phase.go) ...[
                          Text(
                            // Distractor shows 'GO!' on red/blue — misleading!
                            // Real green shows 'TAP!'
                            _isDistractor ? 'GO!' : 'TAP!',
                            style: GoogleFonts.outfit(fontSize: context.scale(48), fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          if (_isDistractor) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Don\'t tap!',
                              style: GoogleFonts.outfit(fontSize: context.scale(14), color: Colors.white60),
                            ),
                          ],
                        ],
                        if (_phase == _Phase.tooEarly) ...[
                          Icon(Icons.warning_amber_rounded, size: context.scale(48), color: Colors.white),
                          const SizedBox(height: 12),
                          Text(
                            _isFakeStart ? '+1500ms Penalty!' : 'Too Early!',
                            style: GoogleFonts.outfit(fontSize: context.scale(28), fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isFakeStart ? 'You fell for the distractor!' : 'Wait for green before tapping',
                            style: GoogleFonts.outfit(fontSize: context.scale(14), color: Colors.white70),
                          ),
                        ],
                        if (_phase == _Phase.result && !_gameOver) ...[
                          Text('${_reactionMs}ms', style: AppTheme.numberStyle(fontSize: context.scale(48), fontWeight: FontWeight.w900, color: accent)),
                          const SizedBox(height: 8),
                          Text('Round $_round/5 • Tap to continue', style: AppTheme.numberStyle(fontSize: context.scale(14), color: context.textSecondary)),
                          const SizedBox(height: 16),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: _results.map((ms) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text('${ms}ms', style: AppTheme.numberStyle(fontSize: context.scale(12), color: context.textMuted)),
                          )).toList()),
                        ],
                        if (_gameOver && _won) ...[
                          Text(
                            '${_results.reduce((a, b) => a + b) ~/ _results.length}ms',
                            style: AppTheme.numberStyle(fontSize: context.scale(48), fontWeight: FontWeight.w900, color: accent),
                          ),
                          const SizedBox(height: 4),
                          Text('Average of 5 rounds', style: AppTheme.numberStyle(fontSize: context.scale(13), color: context.textSecondary)),
                          const SizedBox(height: 12),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: _results.map((ms) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text('${ms}ms', style: AppTheme.numberStyle(fontSize: context.scale(12), color: context.textMuted)),
                          )).toList()),
                          const SizedBox(height: 16),
                          Text(
                            'Under ${target}ms target!',
                            style: GoogleFonts.outfit(fontSize: context.scale(16), fontWeight: FontWeight.w600, color: accent),
                          ),
                          const SizedBox(height: 20),
                          AutoNextCountdown(
                            onNext: _nextLevel,
                            accentColor: accent,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _gameOver && !_won
          ? LossOverlay(
              onTryAgain: _reset,
              subtitle: 'You averaged ${_results.reduce((a, b) => a + b) ~/ _results.length}ms over 5 rounds. Target was ${target}ms avg.',
              accentColor: accent,
              extraContent: [
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _results.map((ms) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('${ms}ms', style: AppTheme.numberStyle(fontSize: context.scale(12), color: context.textMuted)),
                  )).toList(),
                ),
              ],
            )
          : null,
    );
  }
}
