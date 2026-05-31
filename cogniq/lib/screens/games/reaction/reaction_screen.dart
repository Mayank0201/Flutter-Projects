import'dart:async';
import'package:flutter/material.dart';
import'package:google_fonts/google_fonts.dart';
import'package:shared_preferences/shared_preferences.dart';
import'../../../utils/rules_helper.dart';
import'../../../theme/app_theme.dart';
import'../../../theme/settings_manager.dart';
import'../../../utils/hint_manager.dart';

// 30 levels with decreasing target reaction times (ms)
const List<int> _kTargets = [
  500, 480, 460, 440, 420, 400, 380, 360, 340, 320,
  310, 300, 290, 280, 270, 260, 250, 240, 230, 220,
  215, 210, 205, 200, 195, 190, 185, 180, 175, 170,
  // 10 new targets
  450, 430, 410, // Easy
  350, 330, 310, // Medium
  250, 230, 210, 160, // Hard
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

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('reaction');
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('level_reaction') ?? 0;
    if (mounted) setState(() { _levelIndex = saved % _kTargets.length; _resetGame(); });
  }

  Future<void> _saveLevel(int lvl) async {
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
    if (_won || _gameOver || _hintCount <= 0) return;

    await HintManager.useHint('reaction');
    final newCount = await HintManager.getHints('reaction');

    setState(() {
      _hintCount = newCount;
      final target = _kTargets[_levelIndex % _kTargets.length];
      // Fill results with target - 10 ms so average is guaranteed winning
      while (_results.length < 5) {
        _results.add(target - 10);
      }
      _round = 5;
      _reactionMs = target - 10;
      _won = true;
      _gameOver = true;
      _saveLevel(_levelIndex);
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
    setState(() => _phase = _Phase.ready);
    final delay = Duration(milliseconds: 1500 + (DateTime.now().millisecondsSinceEpoch % 3500));
    _delayTimer = Timer(delay, () {
      if (mounted) {
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
        _startRound();
        break;
      case _Phase.ready:
        _delayTimer?.cancel();
        settingsNotifier.hapticError();
        setState(() => _phase = _Phase.tooEarly);
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _phase = _Phase.waiting);
        });
        break;
      case _Phase.go:
        _reactionMs = DateTime.now().difference(_goTime!).inMilliseconds;
        settingsNotifier.hapticTap();
        _results.add(_reactionMs);
        _round++;
        setState(() => _phase = _Phase.result);
        if (_round >= 5) {
          final avg = _results.reduce((a, b) => a + b) ~/ _results.length;
          final target = _kTargets[_levelIndex % _kTargets.length];
          _won = avg <= target;
          _gameOver = true;
          if (_won) {
            _saveLevel(_levelIndex);
          }
        }
        break;
      case _Phase.result:
        if (_gameOver) return;
        _startRound();
        break;
      case _Phase.tooEarly:
        break;
    }
  }

  void _nextLevel() {
    setState(() {
      _levelIndex = (_levelIndex + 1) % _kTargets.length;
      _saveLevel(_levelIndex);
      _resetGame();
    });
  }

  void _reset() => setState(() => _resetGame());

  Color _bgColor() {
    switch (_phase) {
      case _Phase.waiting: return context.bgDark;
      case _Phase.ready: return const Color(0xFFDC2626);
      case _Phase.go: return const Color(0xFF16A34A);
      case _Phase.result: return context.bgDark;
      case _Phase.tooEarly: return const Color(0xFFEA580C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentFor('reaction');
    final target = _kTargets[_levelIndex % _kTargets.length];
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
'$_hintCount',
                      style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            onPressed: _hintCount > 0 && !_won && !_gameOver ? _useHint : null,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            color: _phase == _Phase.waiting || _phase == _Phase.result ? context.textMuted : Colors.white70,
            onPressed: () => RulesHelper.showRulesBottomSheet(context,'reaction','Reaction Time'),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _reset, color: _phase == _Phase.waiting || _phase == _Phase.result ? context.textMuted : Colors.white70),
          Padding(padding: const EdgeInsets.only(right: 12),
            child: Center(child: Text('Level ${_levelIndex + 1}', style: GoogleFonts.outfit(color: accent, fontSize: context.scale(13))))),
        ],
      ),
      body: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.expand(
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_phase == _Phase.waiting && !_gameOver) ...[
                  Icon(Icons.touch_app_outlined, size: context.scale(64), color: context.textMuted),
                  const SizedBox(height: 20),
                  Text('Tap to Start', style: GoogleFonts.outfit(fontSize: context.scale(24), fontWeight: FontWeight.w700, color: context.textPrimary)),
                  const SizedBox(height: 8),
                  Text('Round ${_round + 1}/5 • Target: ${target}ms avg', style: GoogleFonts.outfit(fontSize: context.scale(13), color: context.textSecondary)),
                ],
                if (_phase == _Phase.ready) ...[
                  Text('Wait...', style: GoogleFonts.outfit(fontSize: context.scale(32), fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('Tap when the screen turns GREEN', style: GoogleFonts.outfit(fontSize: context.scale(14), color: Colors.white70)),
                ],
                if (_phase == _Phase.go) ...[
                  Text('TAP!', style: GoogleFonts.outfit(fontSize: context.scale(48), fontWeight: FontWeight.w900, color: Colors.white)),
                ],
                if (_phase == _Phase.tooEarly) ...[
                  Icon(Icons.warning_amber_rounded, size: context.scale(48), color: Colors.white),
                  const SizedBox(height: 12),
                  Text('Too Early!', style: GoogleFonts.outfit(fontSize: context.scale(28), fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('Wait for green before tapping', style: GoogleFonts.outfit(fontSize: context.scale(14), color: Colors.white70)),
                ],
                if (_phase == _Phase.result && !_gameOver) ...[
                  Text('${_reactionMs}ms', style: GoogleFonts.outfit(fontSize: context.scale(48), fontWeight: FontWeight.w900, color: accent)),
                  const SizedBox(height: 8),
                  Text('Round $_round/5 • Tap to continue', style: GoogleFonts.outfit(fontSize: context.scale(14), color: context.textSecondary)),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: _results.map((ms) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('${ms}ms', style: GoogleFonts.outfit(fontSize: context.scale(12), color: context.textMuted)),
                  )).toList()),
                ],
                if (_gameOver) ...[
                  Text(
'${_results.reduce((a, b) => a + b) ~/ _results.length}ms',
                    style: GoogleFonts.outfit(fontSize: context.scale(48), fontWeight: FontWeight.w900, color: _won ? accent : Colors.redAccent),
                  ),
                  const SizedBox(height: 4),
                  Text('Average of 5 rounds', style: GoogleFonts.outfit(fontSize: context.scale(13), color: context.textSecondary)),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: _results.map((ms) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('${ms}ms', style: GoogleFonts.outfit(fontSize: context.scale(12), color: context.textMuted)),
                  )).toList()),
                  const SizedBox(height: 16),
                  Text(
                    _won ?'Under ${target}ms target!':'Target was ${target}ms avg',
                    style: GoogleFonts.outfit(fontSize: context.scale(16), fontWeight: FontWeight.w600, color: _won ? accent : Colors.redAccent),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: _won ? _nextLevel : _reset,
                    child: Text(_won ?'Next Level →':'Try Again', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: context.scale(14))),
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
