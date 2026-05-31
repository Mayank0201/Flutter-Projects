import'dart:async';
import'package:flutter/material.dart';
import'package:google_fonts/google_fonts.dart';
import'package:shared_preferences/shared_preferences.dart';
import'../../../utils/rules_helper.dart';
import'../../../theme/app_theme.dart';
import'../../../utils/hint_manager.dart';

class MemoryLevel {
  final int rows;
  final int cols;
  final List<IconData> iconsPool;
  const MemoryLevel({required this.rows, required this.cols, required this.iconsPool});
}

// Expanded pool of icons for pairs (24 icons)
const List<IconData> _kIcons = [
  Icons.celebration, Icons.favorite, Icons.star, Icons.lightbulb,
  Icons.pets, Icons.flight, Icons.directions_car, Icons.palette,
  Icons.music_note, Icons.sports_basketball, Icons.sunny, Icons.ac_unit,
  Icons.local_cafe, Icons.anchor, Icons.cookie, Icons.face,
  Icons.work, Icons.phone, Icons.camera, Icons.home,
  Icons.eco, Icons.science, Icons.key, Icons.brush
];

const List<MemoryLevel> _kLevels = [
  // Easy (2x2, 2x4, 3x4)
  MemoryLevel(rows: 2, cols: 2, iconsPool: _kIcons), // 2 pairs
  MemoryLevel(rows: 2, cols: 4, iconsPool: _kIcons), // 4 pairs
  MemoryLevel(rows: 3, cols: 4, iconsPool: _kIcons), // 6 pairs
  // Medium (4x4, 4x5, 4x6)
  MemoryLevel(rows: 4, cols: 4, iconsPool: _kIcons), // 8 pairs
  MemoryLevel(rows: 4, cols: 5, iconsPool: _kIcons), // 10 pairs
  MemoryLevel(rows: 4, cols: 6, iconsPool: _kIcons), // 12 pairs
  // Hard (5x6, 6x6)
  MemoryLevel(rows: 5, cols: 6, iconsPool: _kIcons), // 15 pairs
  MemoryLevel(rows: 6, cols: 6, iconsPool: _kIcons), // 18 pairs
  // Expansions
  MemoryLevel(rows: 2, cols: 6, iconsPool: _kIcons), // 6 pairs
  MemoryLevel(rows: 3, cols: 6, iconsPool: _kIcons), // 9 pairs
  MemoryLevel(rows: 4, cols: 3, iconsPool: _kIcons), // 6 pairs
  MemoryLevel(rows: 5, cols: 4, iconsPool: _kIcons), // 10 pairs
  MemoryLevel(rows: 2, cols: 2, iconsPool: _kIcons),
  MemoryLevel(rows: 2, cols: 4, iconsPool: _kIcons),
  MemoryLevel(rows: 3, cols: 4, iconsPool: _kIcons),
  MemoryLevel(rows: 4, cols: 3, iconsPool: _kIcons),
  MemoryLevel(rows: 4, cols: 4, iconsPool: _kIcons),
  MemoryLevel(rows: 4, cols: 5, iconsPool: _kIcons),
  MemoryLevel(rows: 4, cols: 6, iconsPool: _kIcons),
  MemoryLevel(rows: 5, cols: 4, iconsPool: _kIcons),
  MemoryLevel(rows: 5, cols: 6, iconsPool: _kIcons),
  MemoryLevel(rows: 6, cols: 6, iconsPool: _kIcons),
  MemoryLevel(rows: 2, cols: 2, iconsPool: _kIcons),
  MemoryLevel(rows: 2, cols: 4, iconsPool: _kIcons),
  MemoryLevel(rows: 3, cols: 4, iconsPool: _kIcons),
  MemoryLevel(rows: 4, cols: 3, iconsPool: _kIcons),
  MemoryLevel(rows: 4, cols: 4, iconsPool: _kIcons),
  MemoryLevel(rows: 4, cols: 5, iconsPool: _kIcons),
  MemoryLevel(rows: 4, cols: 6, iconsPool: _kIcons),
  MemoryLevel(rows: 6, cols: 6, iconsPool: _kIcons),
  MemoryLevel(rows: 5, cols: 6, iconsPool: _kIcons),
  MemoryLevel(rows: 6, cols: 6, iconsPool: _kIcons),
  MemoryLevel(rows: 5, cols: 6, iconsPool: _kIcons),
  MemoryLevel(rows: 6, cols: 6, iconsPool: _kIcons),
  MemoryLevel(rows: 5, cols: 6, iconsPool: _kIcons),
  MemoryLevel(rows: 6, cols: 6, iconsPool: _kIcons),
  MemoryLevel(rows: 5, cols: 6, iconsPool: _kIcons),
  MemoryLevel(rows: 6, cols: 6, iconsPool: _kIcons),
  MemoryLevel(rows: 5, cols: 6, iconsPool: _kIcons),
  MemoryLevel(rows: 6, cols: 6, iconsPool: _kIcons),
  // 10 new levels
  MemoryLevel(rows: 2, cols: 2, iconsPool: _kIcons),
  MemoryLevel(rows: 2, cols: 4, iconsPool: _kIcons),
  MemoryLevel(rows: 3, cols: 4, iconsPool: _kIcons),
  MemoryLevel(rows: 4, cols: 4, iconsPool: _kIcons),
  MemoryLevel(rows: 4, cols: 5, iconsPool: _kIcons),
  MemoryLevel(rows: 4, cols: 6, iconsPool: _kIcons),
  MemoryLevel(rows: 5, cols: 6, iconsPool: _kIcons),
  MemoryLevel(rows: 6, cols: 6, iconsPool: _kIcons),
  MemoryLevel(rows: 6, cols: 6, iconsPool: _kIcons),
  MemoryLevel(rows: 6, cols: 6, iconsPool: _kIcons),
];

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});
  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  int _levelIndex = 0;
  late MemoryLevel _level;
  late List<IconData> _board;
  late List<bool> _flipped;
  late List<bool> _matched;
  int? _firstSelectedIndex;
  bool _busy = false;
  int _moves = 0;
  bool _won = false;

  int _hintCount = 0;

  @override
  void initState() {
    super.initState();
    // Default synchronous initialization to avoid LateInitializationError
    _level = _kLevels[0];
    _board = [];
    _flipped = [];
    _matched = [];
    _initLevel();
  }

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('memory');
    final prefs = await SharedPreferences.getInstance();
    final savedLevel = prefs.getInt('level_memory') ?? 0;
    if (mounted) {
      setState(() {
        _levelIndex = savedLevel % _kLevels.length;
        _loadLevel();
      });
    }
  }

  Future<void> _savePersistedLevel(int lvl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_memory', lvl);
    final earned = await HintManager.onLevelCleared('memory');
    final newCount = await HintManager.getHints('memory');
    setState(() {
      _hintCount = newCount;
    });
    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hint earned! (Total: $newCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.accentFor('memory'),
        ),
      );
    }
  }

  Future<void> _useHint() async {
    if (_won || _busy || _hintCount <= 0) return;

    // Find first unmatched card index
    int firstUnmatchedIdx = -1;
    for (int i = 0; i < _matched.length; i++) {
      if (!_matched[i]) {
        firstUnmatchedIdx = i;
        break;
      }
    }
    if (firstUnmatchedIdx == -1) return;

    // Find its match
    int matchIdx = -1;
    for (int i = 0; i < _board.length; i++) {
      if (i != firstUnmatchedIdx && _board[i] == _board[firstUnmatchedIdx]) {
        matchIdx = i;
        break;
      }
    }
    if (matchIdx == -1) return;

    await HintManager.useHint('memory');
    final newCount = await HintManager.getHints('memory');

    setState(() {
      _hintCount = newCount;
      _flipped[firstUnmatchedIdx] = true;
      _flipped[matchIdx] = true;
      _busy = true;
    });

    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          // If they weren't matched in the meantime, flip them back
          if (!_matched[firstUnmatchedIdx]) {
            _flipped[firstUnmatchedIdx] = false;
          }
          if (!_matched[matchIdx]) {
            _flipped[matchIdx] = false;
          }
          _busy = false;
        });
      }
    });
  }

  void _loadLevel() {
    _level = _kLevels[_levelIndex % _kLevels.length];
    final numPairs = (_level.rows * _level.cols) ~/ 2;
    
    // Take required amount of icons randomly and double them
    final selectedIcons = (_level.iconsPool.toList()..shuffle()).take(numPairs).toList();
    _board = [...selectedIcons, ...selectedIcons]..shuffle();
    
    _flipped = List.filled(_level.rows * _level.cols, false);
    _matched = List.filled(_level.rows * _level.cols, false);
    _firstSelectedIndex = null;
    _busy = false;
    _moves = 0;
    _won = false;
  }

  void _reset() => setState(() => _loadLevel());

  void _onCardTap(int idx) {
    if (_busy || _flipped[idx] || _matched[idx] || _won) return;

    setState(() {
      _flipped[idx] = true;
    });

    if (_firstSelectedIndex == null) {
      _firstSelectedIndex = idx;
    } else {
      _moves++;
      final firstIdx = _firstSelectedIndex!;
      if (_board[firstIdx] == _board[idx]) {
        // Match!
        setState(() {
          _matched[firstIdx] = true;
          _matched[idx] = true;
          _firstSelectedIndex = null;
          
          if (_matched.every((m) => m)) {
            _won = true;
            _savePersistedLevel(_levelIndex);
          }
        });
      } else {
        // No match
        _busy = true;
        Timer(const Duration(milliseconds: 700), () {
          if (mounted) {
            setState(() {
              _flipped[firstIdx] = false;
              _flipped[idx] = false;
              _firstSelectedIndex = null;
              _busy = false;
            });
          }
        });
      }
    }
  }

  void _nextLevel() {
    setState(() {
      _levelIndex = (_levelIndex + 1) % _kLevels.length;
      _savePersistedLevel(_levelIndex);
      _loadLevel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AppTheme.accentFor('memory');
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: Text('Memory Match', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
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
            onPressed: _hintCount > 0 && !_won && !_busy ? _useHint : null,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            color: context.textMuted,
            onPressed: () => RulesHelper.showRulesBottomSheet(context,'memory','Memory Match'),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _reset, color: context.textMuted),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
'Level ${_levelIndex + 1}',
                style: GoogleFonts.outfit(color: accentColor, fontSize: context.scale(13)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (ctx, constraints) {
          final maxW = constraints.maxWidth - 32;
          final maxH = constraints.maxHeight - 120;
          
          final cellW = maxW / _level.cols;
          final cellH = maxH / _level.rows;
          final size = cellW < cellH ? cellW : cellH;
          
          final gridW = size * _level.cols;
          final gridH = size * _level.rows;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
'Find all matching pairs in minimal moves',
                style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(13)),
              ),
              const SizedBox(height: 8),
              Text(
'Moves: $_moves',
                style: GoogleFonts.outfit(color: accentColor, fontSize: context.scale(13), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: gridW,
                  height: gridH,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _level.cols,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: _board.length,
                    itemBuilder: (ctx, idx) {
                      final isOpen = _flipped[idx] || _matched[idx];
                      return GestureDetector(
                        onTap: () => _onCardTap(idx),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          decoration: BoxDecoration(
                            color: isOpen ? context.bgSurface : context.bgCard,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isOpen ? accentColor.withAlpha(120) : context.textMuted.withAlpha(50),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: isOpen
                                ? Icon(
                                    _board[idx],
                                    color: _matched[idx] ? accentColor : context.textPrimary,
                                    size: size * 0.45,
                                  )
                                : Icon(
                                    Icons.help_outline,
                                    color: context.textMuted.withAlpha(120),
                                    size: size * 0.4,
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_won) ...[
                Text(
'Level Complete in $_moves moves!',
                  style: GoogleFonts.outfit(color: accentColor, fontSize: context.scale(16), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: _nextLevel,
                  child: Text('Next Level →', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: context.scale(14))),
                ),
              ],
            ],
          );
        }),
      ),
    );
  }
}
