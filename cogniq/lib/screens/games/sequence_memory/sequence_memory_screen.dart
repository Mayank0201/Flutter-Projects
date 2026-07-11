import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cogniq/widgets/buy_hints_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/rules_helper.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/audio_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/loss_overlay.dart';
import '../../../widgets/animated_level_indicator.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import 'package:flutter_animate/flutter_animate.dart';

const List<int> _kStartLen = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 12,
  13, 14, 15, 16, 17, 18, 19, 20, 21, 22,
  23, 24, 25, 26, 27, 28, 29, 30, 31, 32,
  // 10 new levels
  33, 34, 35, 36, 37, 38, 39, 40, 41, 42,
];

enum _Phase { idle, playing, input, correct, wrong }

class SequenceMemoryScreen extends StatefulWidget {
  const SequenceMemoryScreen({super.key});
  @override
  State<SequenceMemoryScreen> createState() => _SequenceMemoryScreenState();
}

class _SequenceMemoryScreenState extends State<SequenceMemoryScreen> {
  int _levelIndex = 0;
  _Phase _phase = _Phase.idle;
  int _seqLen = 2;
  List<int> _sequence = [];
  int _inputIndex = 0;
  int _activeHighlight = -1;
  bool _gameOver = false;
  bool _won = false;
  final _rng = Random();
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  String _dailyModifierName = '';
  Timer? _inputTimer;
  int _inputTimeLeft = 0;

  static const _gridSize = 9; // 3x3
  static const List<Color> _tileColors = [
    Color(0xFF86A380),
    Color(0xFF8FA8C4),
    Color(0xFFD29891),
    Color(0xFFD8B28B),
    Color(0xFFB1A2C6),
    Color(0xFF8EBEB5),
    Color(0xFFDEAA94),
    Color(0xFF98B8A6),
    Color(0xFFA5A5BC),
  ];

  int _hintCount = 0;

  @override
  void initState() {
    super.initState();
    _initLevel();
  }

  @override
  void dispose() {
    _inputTimer?.cancel();
    super.dispose();
  }

  int get _targetSeqLen {
    if (_levelIndex < _kStartLen.length) {
      return _kStartLen[_levelIndex];
    }
    final extra = _levelIndex - _kStartLen.length;
    return 42 + extra;
  }

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('sequence');
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool('play_daily_mode') ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString('daily_modifier_type') ?? '';
      _dailyModifierName = prefs.getString('daily_modifier_name') ?? '';
    } else {
      _dailyModifierType = '';
      _dailyModifierName = '';
    }
    final saved = prefs.getInt('level_sequence') ?? 0;

    if (mounted) {
      setState(() {
        _levelIndex = saved;
        _resetGame();
      });
    }
  }

  Future<void> _savePersistedLevel(int lvl) async {
    if (_playDailyMode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_sequence', lvl);
    final earned = await HintManager.onLevelCleared('sequence');
    final newCount = await HintManager.getHints('sequence');
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
          backgroundColor: AppTheme.accentFor('sequence'),
        ),
      );
    }
  }

  Future<void> _useHint() async {
    if (_phase != _Phase.input || _won || _hintCount <= 0 || _sequence.isEmpty)
      return;

    final correctTile = _sequence[_inputIndex];
    await HintManager.useHint('sequence');
    final newCount = await HintManager.getHints('sequence');

    setState(() {
      _hintCount = newCount;
      _activeHighlight = correctTile;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() {
      _activeHighlight = -1;
      _inputIndex++;
      if (_inputIndex >= _sequence.length) {
        settingsNotifier.hapticSuccess();
        _inputTimer?.cancel();
        _won = true;
        _gameOver = true;
        _phase = _Phase.correct;
        AudioManager.playSuccess();
        _savePersistedLevel(_levelIndex + 1);
      } else {
        AudioManager.playClick();
      }
    });
  }

  void _resetGame() {
    _inputTimer?.cancel();
    _inputTimer = null;
    _inputTimeLeft = 0;
    _seqLen = _targetSeqLen;
    _phase = _Phase.idle;
    _gameOver = false;
    _won = false;
    _sequence = [];
    _inputIndex = 0;
    _activeHighlight = -1;
  }

  void _startPlaying() {
    _sequence = List.generate(_seqLen, (_) => _rng.nextInt(_gridSize));
    _inputIndex = 0;
    _phase = _Phase.playing;
    _playSequence();
  }

  Future<void> _playSequence() async {
    setState(() => _activeHighlight = -1);
    final speedFactor =
        _playDailyMode && _dailyModifierType == 'time_warp' ? 0.5 : 1.0;
    await Future.delayed(Duration(milliseconds: (400 * speedFactor).round()));
    for (int i = 0; i < _sequence.length; i++) {
      if (!mounted || _phase != _Phase.playing) return;
      setState(() => _activeHighlight = _sequence[i]);
      AudioManager.playClick();
      final litMs = ((_seqLen > 10 ? 350 : 500) * speedFactor).round();
      await Future.delayed(Duration(milliseconds: litMs));
      if (!mounted || _phase != _Phase.playing) return;
      setState(() => _activeHighlight = -1);
      await Future.delayed(Duration(milliseconds: (150 * speedFactor).round()));
    }
    if (mounted && _phase == _Phase.playing) {
      setState(() {
        _phase = _Phase.input;
        _inputIndex = 0;
      });
      _startInputTimerIfNeeded();
    }
  }

  void _startInputTimerIfNeeded() {
    _inputTimer?.cancel();
    if (!_playDailyMode || _dailyModifierType != 'time_warp') return;
    _inputTimeLeft = max(5, _seqLen);
    _inputTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _phase != _Phase.input || _won) {
        timer.cancel();
        return;
      }
      setState(() {
        _inputTimeLeft--;
        if (_inputTimeLeft <= 0) {
          _gameOver = true;
          _phase = _Phase.wrong;
          AudioManager.playFail();
          timer.cancel();
        }
      });
    });
  }

  void _onTileTap(int idx) {
    if (_phase != _Phase.input) return;
    settingsNotifier.hapticTap();
    setState(() {
      _activeHighlight = idx;
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _activeHighlight = -1);
    });

    if (idx == _sequence[_inputIndex]) {
      _inputIndex++;
      if (_inputIndex >= _sequence.length) {
        // Win the level
        settingsNotifier.hapticSuccess();
        _inputTimer?.cancel();
        setState(() {
          _won = true;
          _gameOver = true;
          _phase = _Phase.correct;
          AudioManager.playSuccess();
          _savePersistedLevel(_levelIndex + 1);
        });
      } else {
        AudioManager.playClick();
      }
    } else {
      settingsNotifier.hapticError();
      _inputTimer?.cancel();
      setState(() {
        _gameOver = true;
        _phase = _Phase.wrong;
        AudioManager.playFail();
      });
    }
  }

  void _nextLevel() {
    if (!_won) return;
    if (_playDailyMode) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _levelIndex = _levelIndex + 1;
      _resetGame();
    });
  }

  void _reset() => setState(() => _resetGame());

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentFor('sequence');
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: Text(
          'Sequence Memory',
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
            onPressed: _phase == _Phase.input && !_won
                ? () async {
                    if (_hintCount > 0) {
                      _useHint();
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'sequence',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('sequence');
                          if (mounted) setState(() => _hintCount = newCount);
                        },
                      );
                    }
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            color: context.textMuted,
            onPressed: () => RulesHelper.showRulesBottomSheet(
              context,
              'sequence',
              'Sequence Memory',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _reset,
            color: context.textMuted,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AnimatedLevelIndicator(
              level: _levelIndex + 1,
              accentColor: accent,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Status
                Text(
                  _phase == _Phase.idle
                      ? 'Tap Start to begin'
                      : _phase == _Phase.playing
                      ? 'Watch the sequence...'
                      : _phase == _Phase.input
                      ? 'Your turn! (${_inputIndex}/${_sequence.length})'
                      : _won
                      ? 'Perfect!'
                      : 'Wrong tile!',
                  style: GoogleFonts.outfit(
                    fontSize: context.scale(16),
                    fontWeight: FontWeight.w600,
                    color: _won
                        ? accent
                        : _phase == _Phase.wrong
                        ? Colors.redAccent
                        : context.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sequence length: $_seqLen',
                  style: GoogleFonts.outfit(
                    color: context.textMuted,
                    fontSize: context.scale(12),
                  ),
                ),
                if (_playDailyMode && _dailyModifierName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _dailyModifierName,
                    style: GoogleFonts.outfit(
                      color: accent,
                      fontSize: context.scale(12),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (_phase == _Phase.input &&
                    _playDailyMode &&
                    _dailyModifierType == 'time_warp') ...[
                  const SizedBox(height: 6),
                  Text(
                    '$_inputTimeLeft seconds',
                    style: AppTheme.numberStyle(
                      color: _inputTimeLeft <= 3 ? Colors.redAccent : accent,
                      fontSize: context.scale(13),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // 3x3 Grid
                Center(
                  child: SizedBox(
                    width: context.scale(260),
                    height: context.scale(260),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: _gridSize,
                      itemBuilder: (ctx, idx) {
                        final isHighlighted = _activeHighlight == idx;
                        final baseColor = _tileColors[idx];
                        final hideGridLines = _playDailyMode &&
                            _dailyModifierType == 'eclipse' &&
                            _phase == _Phase.input;
                        return GestureDetector(
                          onTap: () => _onTileTap(idx),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: isHighlighted
                                  ? baseColor
                                  : (hideGridLines
                                      ? Colors.transparent
                                      : context.bgCard),
                              borderRadius: BorderRadius.circular(12),
                              border: isHighlighted
                                  ? Border.all(color: Colors.white, width: 3)
                                  : hideGridLines
                                      ? Border.all(color: Colors.transparent)
                                      : Border.all(
                                          color: context.textMuted.withAlpha(45),
                                          width: 1.0,
                                        ),
                              boxShadow: isHighlighted
                                  ? [
                                      BoxShadow(
                                        color: baseColor.withAlpha(120),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : (hideGridLines ? null : AppTheme.cardShadow),
                            ),
                          )
                              .animate(target: isHighlighted ? 1.0 : 0.0)
                              .scale(
                                begin: const Offset(1.0, 1.0),
                                end: const Offset(1.08, 1.08),
                                duration: 150.ms,
                                curve: Curves.easeOut,
                              ),
                        );
                      },
                    ),
                  ),
                ),
                if (_won) ...[
                  const SizedBox(height: 16),
                  AutoNextCountdown(
                    onNext: _nextLevel,
                    accentColor: accent,
                  ),
                ],
                if (_phase == _Phase.idle && !_gameOver) ...[
                  const SizedBox(height: 20),
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
                    onPressed: _startPlaying,
                    child: Text(
                      'Start',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: context.scale(16),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomSheet: _won && _playDailyMode
          ? ChallengeClearedOverlay(
              accentColor: accent,
              onComplete: () => Navigator.pop(context, true),
            )
          : null,
      floatingActionButton: _gameOver && !_won
          ? LossOverlay(
              onTryAgain: _reset,
              subtitle: 'You reached sequence length $_seqLen on level ${_levelIndex + 1}.',
              accentColor: accent,
            )
          : null,
    );
  }
}
