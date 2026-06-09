import'dart:async';
import'dart:math';
import'package:flutter/material.dart';
import'package:google_fonts/google_fonts.dart';
import'package:shared_preferences/shared_preferences.dart';
import'../../../utils/rules_helper.dart';
import'../../../theme/app_theme.dart';
import'../../../theme/settings_manager.dart';
import'../../../utils/hint_manager.dart';

const List<int> _kStartLen = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 12,
  13, 14, 15, 16, 17, 18, 19, 20, 21, 22,
  23, 24, 25, 26, 27, 28, 29, 30, 31, 32,
  // 10 new levels
  33, 34, 35, 36, 37, 38, 39, 40, 41, 42,
];

enum _Phase { idle, playing, input, correct, wrong }

class SequenceScreen extends StatefulWidget {
  const SequenceScreen({super.key});
  @override
  State<SequenceScreen> createState() => _SequenceScreenState();
}

class _SequenceScreenState extends State<SequenceScreen> {
  int _levelIndex = 0;
  _Phase _phase = _Phase.idle;
  int _seqLen = 2;
  List<int> _sequence = [];
  int _inputIndex = 0;
  int _activeHighlight = -1;
  bool _gameOver = false;
  bool _won = false;
  final _rng = Random();

  static const _gridSize = 9; // 3x3
  static const List<Color> _tileColors = [
    Color(0xFF86A380), Color(0xFF8FA8C4), Color(0xFFD29891),
    Color(0xFFD8B28B), Color(0xFFB1A2C6), Color(0xFF8EBEB5),
    Color(0xFFDEAA94), Color(0xFF98B8A6), Color(0xFFA5A5BC),
  ];

  int _hintCount = 0;

  @override
  void initState() {
    super.initState();
    _initLevel();
  }

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('sequence');
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('level_sequence') ?? 0;
    if (mounted) setState(() { _levelIndex = saved % _kStartLen.length; _resetGame(); });
  }

  Future<void> _savePersistedLevel(int lvl) async {
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
          content: Text('Hint earned! (Total: $newCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.accentFor('sequence'),
        ),
      );
    }
  }

  Future<void> _useHint() async {
    if (_phase != _Phase.input || _won || _hintCount <= 0 || _sequence.isEmpty) return;
    
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
        _won = true;
        _gameOver = true;
        _phase = _Phase.correct;
        _savePersistedLevel(_levelIndex);
      }
    });
  }

  void _resetGame() {
    _seqLen = _kStartLen[_levelIndex % _kStartLen.length];
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
    await Future.delayed(const Duration(milliseconds: 400));
    for (int i = 0; i < _sequence.length; i++) {
      if (!mounted || _phase != _Phase.playing) return;
      setState(() => _activeHighlight = _sequence[i]);
      await Future.delayed(Duration(milliseconds: _seqLen > 10 ? 350 : 500));
      if (!mounted || _phase != _Phase.playing) return;
      setState(() => _activeHighlight = -1);
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (mounted && _phase == _Phase.playing) {
      setState(() {
        _phase = _Phase.input;
        _inputIndex = 0;
      });
    }
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
        setState(() {
          _won = true;
          _gameOver = true;
          _phase = _Phase.correct;
          _savePersistedLevel(_levelIndex);
        });
      }
    } else {
      settingsNotifier.hapticError();
      setState(() {
        _gameOver = true;
        _phase = _Phase.wrong;
      });
    }
  }

  void _nextLevel() {
    setState(() {
      _levelIndex = (_levelIndex + 1) % _kStartLen.length;
      _savePersistedLevel(_levelIndex);
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
        title: Text('Sequence Memory', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
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
            onPressed: () => RulesHelper.showRulesBottomSheet(context,'sequence','Sequence Memory'),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _reset, color: context.textMuted),
          Padding(padding: const EdgeInsets.only(right: 12),
            child: Center(child: Text('Level ${_levelIndex + 1}', style: GoogleFonts.outfit(color: accent, fontSize: context.scale(13))))),
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
                      ?'Tap Start to begin'
                      : _phase == _Phase.playing
                          ?'Watch the sequence...'
                          : _phase == _Phase.input
                              ?'Your turn! (${_inputIndex}/${_sequence.length})'
                              : _won
                                  ?'Perfect!'
                                  :'❌ Wrong tile!',
                  style: GoogleFonts.outfit(
                    fontSize: context.scale(16),
                    fontWeight: FontWeight.w600,
                    color: _won ? accent : _phase == _Phase.wrong ? Colors.redAccent : context.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sequence length: $_seqLen',
                  style: GoogleFonts.outfit(color: context.textMuted, fontSize: context.scale(12)),
                ),
                const SizedBox(height: 24),
                // 3x3 Grid
                Center(
                  child: SizedBox(
                    width: context.scale(260),
                    height: context.scale(260),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _gridSize,
                      itemBuilder: (ctx, idx) {
                        final isHighlighted = _activeHighlight == idx;
                        final baseColor = _tileColors[idx];
                        return GestureDetector(
                          onTap: () => _onTileTap(idx),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: isHighlighted ? baseColor : context.bgCard,
                              borderRadius: BorderRadius.circular(12),
                              border: isHighlighted
                                  ? Border.all(color: Colors.white, width: 3)
                                  : Border.all(color: context.textMuted.withAlpha(45), width: 1.0),
                              boxShadow: isHighlighted
                                  ? [BoxShadow(color: baseColor.withAlpha(120), blurRadius: 16, spreadRadius: 2)]
                                  : AppTheme.cardShadow,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Action buttons
                if (_phase == _Phase.idle && !_gameOver)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: _startPlaying,
                    child: Text('Start', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: context.scale(16))),
                  ),
                if (_gameOver) ...[
                  const SizedBox(height: 8),
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
