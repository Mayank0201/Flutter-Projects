import'dart:math';
import'package:flutter/material.dart';
import'package:google_fonts/google_fonts.dart';
import'package:shared_preferences/shared_preferences.dart';
import'../../../utils/rules_helper.dart';
import'../../../theme/app_theme.dart';
import'../../../utils/hint_manager.dart';

// Chimp Test: numbers appear, tap 1 to hide them, then tap in order from memory.
// Grid and number count grow each level.

class ChimpScreen extends StatefulWidget {
  const ChimpScreen({super.key});
  @override
  State<ChimpScreen> createState() => _ChimpScreenState();
}

class _ChimpScreenState extends State<ChimpScreen> {
  // Level config: (gridSize, numCount)
  static const List<(int, int)> _levels = [
    (3, 4), (3, 5), (3, 6),
    (4, 7), (4, 8), (4, 10),
    (5, 12), (5, 14), (5, 16), (5, 18),
    (5, 20), (6, 22), (6, 24), (6, 26), (6, 28),
    (6, 30), (6, 32), (7, 34), (7, 36), (7, 38),
    (7, 40), (8, 42), (8, 44), (8, 46), (8, 48),
    (8, 50), (9, 52), (9, 54), (9, 56), (9, 60),
    // 10 new levels
    (3, 4), (3, 5), (4, 6), // Easy
    (5, 10), (5, 11), (6, 15), // Medium
    (7, 25), (8, 35), (9, 45), (9, 50), // Hard
  ];

  int _levelIndex = 0;
  late int _gridSize;
  late int _n;
  late Map<int, (int,int)> _positions;
  bool _started = false;   // user tapped 1 → numbers hide
  int _nextToTap = 1;
  bool _won = false;
  bool _failed = false;
  final Set<(int, int)> _glowingCells = {};

  bool _isHintShowing = false;
  int _hintCount = 0;

  @override
  void initState() {
    super.initState();
    _loadLevel();
    _loadPersistedLevel();
  }

  Future<void> _loadPersistedLevel() async {
    _hintCount = await HintManager.getHints('chimp');
    final prefs = await SharedPreferences.getInstance();
    final savedLevel = prefs.getInt('level_chimp') ?? 0;
    if (mounted) {
      setState(() {
        _levelIndex = savedLevel;
        _loadLevel();
      });
    }
  }

  Future<void> _savePersistedLevel(int lvl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_chimp', lvl);
    final earned = await HintManager.onLevelCleared('chimp');
    final newCount = await HintManager.getHints('chimp');
    setState(() {
      _hintCount = newCount;
    });
    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hint earned! (Total: $newCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.accentFor('chimp'),
        ),
      );
    }
  }

  Future<void> _useHint() async {
    if (_won || _failed || _hintCount <= 0 || !_started) return;

    await HintManager.useHint('chimp');
    final newCount = await HintManager.getHints('chimp');

    setState(() {
      _hintCount = newCount;
      _isHintShowing = true;
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isHintShowing = false;
        });
      }
    });
  }

  void _loadLevel() {
    final cfg = _levels[_levelIndex % _levels.length];
    _gridSize = cfg.$1; _n = cfg.$2;
    _positions = _randomPositions();
    _started = false;
    _nextToTap = 1; _won = false; _failed = false;
  }

  Map<int,(int,int)> _randomPositions() {
    final rng = Random(); final used = <(int,int)>{}; final map = <int,(int,int)>{};
    int num = 1;
    while (num <= _n) {
      final r = rng.nextInt(_gridSize); final c = rng.nextInt(_gridSize);
      if (!used.contains((r,c))) { used.add((r,c)); map[num] = (r,c); num++; }
    }
    return map;
  }

  void _reset() => setState(() => _loadLevel());

  int? _numberAt(int r, int c) {
    for (final e in _positions.entries) { if (e.value.$1 == r && e.value.$2 == c) { return e.key; } }
    return null;
  }

  void _onTap(int r, int c) {
    if (_won || _failed) return;
    final num = _numberAt(r, c);

    setState(() {
      _glowingCells.add((r, c));
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _glowingCells.remove((r, c));
        });
      }
    });

    if (num == null) { if (_started) { setState(() => _failed = true); } return; }

    if (!_started && num == 1) {
      // First tap of 1: hide all numbers except already-tapped
      setState(() { _started = true; _nextToTap = 2; });
      return;
    }
    if (!_started) { setState(() => _failed = true); return; } // must tap 1 first

    if (num == _nextToTap) {
      setState(() {
        _nextToTap++;
        if (_nextToTap > _n) {
          _won = true;
          _savePersistedLevel(_levelIndex);
        }
      });
    } else {
      setState(() => _failed = true);
    }
  }

  bool _isCellVisible(int r, int c) {
    final num = _numberAt(r, c);
    if (num == null) return false;
    if (!_started) return true;          // show all before first tap
    if (_isHintShowing && num == _nextToTap) return true;
    return false;                        // hide all numbers after first tap
  }

  void _nextLevel() {
    setState(() {
      _levelIndex = (_levelIndex + 1) % _levels.length;
      _loadLevel();
      _savePersistedLevel(_levelIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark, foregroundColor: context.textPrimary,
        title: Text('Chimp Test', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
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
            onPressed: _hintCount > 0 && _started && !_won && !_failed && !_isHintShowing ? _useHint : null,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            color: context.textMuted,
            onPressed: () => RulesHelper.showRulesBottomSheet(context,'chimp','Chimp Test'),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _reset, color: context.textMuted),
          Padding(padding: const EdgeInsets.only(right: 12),
            child: Center(child: Text('Level ${_levelIndex + 1}', style: GoogleFonts.outfit(color: AppTheme.patchesTeal, fontSize: context.scale(13))))),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (ctx, constraints) {
          final available = constraints.maxWidth - 40;
          final cellSize = available / _gridSize;
          // Clamp cell size so grid doesn't overflow vertically
          final maxCellH = (constraints.maxHeight - 130) / _gridSize;
          final cs = min(cellSize, maxCellH);
          final gridW = cs * _gridSize;

          return Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Status
                  if (!_started && !_won && !_failed)
                    Text('Memorize 1 → $_n, then tap 1 to begin',
                      style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(13)), textAlign: TextAlign.center)
                  else if (_started && !_won && !_failed)
                    Text('Tap 1 → $_n in order',
                      style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(13)))
                  else
                    Text(_won ?'✓  Level ${_levelIndex+1} cleared!':'✗  Wrong! Try again.',
                      style: GoogleFonts.outfit(fontSize: context.scale(17), fontWeight: FontWeight.w700,
                        color: _won ? AppTheme.patchesTeal : Colors.redAccent)),
                  const SizedBox(height: 16),
                  // Grid
                  SizedBox(
                    width: gridW,
                    height: cs * _gridSize,
                    child: Column(children: List.generate(_gridSize, (r) =>
                      Row(children: List.generate(_gridSize, (c) {
                        final num = _numberAt(r, c);
                        final visible = _isCellVisible(r, c);
                        final isTapped = num != null && num < _nextToTap && _started;
                        final isHintHighlighted = _isHintShowing && num == _nextToTap;
                        final isGlowing = _glowingCells.contains((r, c));
                        return GestureDetector(
                          onTap: () => _onTap(r, c),
                          child: Container(
                            width: cs - 6, height: cs - 6, margin: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: isTapped
                                  ? Colors.transparent
                                  : (isGlowing
                                      ? AppTheme.patchesTeal.withAlpha(80)
                                      : (isHintHighlighted ? Colors.amber.withOpacity(0.2) : context.bgCard)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isGlowing
                                    ? AppTheme.patchesTeal
                                    : (isHintHighlighted
                                        ? Colors.amber
                                        : (isTapped
                                            ? context.bgCard.withOpacity(0.1)
                                            : context.textMuted.withAlpha(75))),
                                width: (isHintHighlighted || isGlowing) ? 2.5 : 1.2,
                              ),
                              boxShadow: isGlowing
                                  ? [BoxShadow(color: AppTheme.patchesTeal.withAlpha(120), blurRadius: 10, spreadRadius: 1)]
                                  : (isTapped ? null : AppTheme.cardShadow),
                            ),
                            child: Center(child: visible && num != null
                              ? Text('$num', style: GoogleFonts.outfit(fontSize: cs * 0.36, fontWeight: FontWeight.w800,
                                  color: AppTheme.patchesTeal))
                              : null),
                          ),
                        );
                      })),
                    )),
                  ),
                  const SizedBox(height: 24),
                  if (_won) TextButton(onPressed: _nextLevel,
                    child: Text('Next →', style: GoogleFonts.outfit(color: AppTheme.patchesTeal, fontWeight: FontWeight.w700, fontSize: context.scale(16)))),
                  if (_failed) TextButton(onPressed: _reset,
                    child: Text('Retry', style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(15)))),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
