import'dart:math';
import'package:flutter/material.dart';
import'package:google_fonts/google_fonts.dart';
import'package:shared_preferences/shared_preferences.dart';
import'../../../utils/rules_helper.dart';
import'../../../theme/app_theme.dart';
import'../../../theme/settings_manager.dart';
import'../../../utils/hint_manager.dart';

// 30 levels with target scores and move limits
class _Level {
  final int target;
  final int maxMoves;
  const _Level(this.target, this.maxMoves);
}

const List<_Level> _kLevels = [
  _Level(128, 999),  _Level(256, 999),  _Level(512, 999),  _Level(1024, 999), _Level(2048, 999),
  _Level(256, 120),  _Level(512, 150),  _Level(1024, 200), _Level(2048, 300), _Level(4096, 500),
  _Level(256, 80),   _Level(512, 100),  _Level(1024, 140), _Level(2048, 200), _Level(4096, 350),
  _Level(256, 60),   _Level(512, 75),   _Level(1024, 100), _Level(2048, 150), _Level(4096, 250),
  _Level(512, 60),   _Level(1024, 80),  _Level(2048, 100), _Level(4096, 150), _Level(8192, 300),
  _Level(1024, 60),  _Level(2048, 80),  _Level(4096, 100), _Level(8192, 150), _Level(16384, 300),
  // 10 new levels
  _Level(128, 50),   _Level(256, 100),  _Level(512, 200),  // Easy
  _Level(1024, 150), _Level(2048, 250), _Level(4096, 400), // Medium
  _Level(4096, 200), _Level(8192, 250), _Level(16384, 250), _Level(32768, 500), // Hard
];

class TwentyFortyEightScreen extends StatefulWidget {
  const TwentyFortyEightScreen({super.key});
  @override
  State<TwentyFortyEightScreen> createState() => _TwentyFortyEightScreenState();
}

class _TwentyFortyEightScreenState extends State<TwentyFortyEightScreen> with TickerProviderStateMixin {
  int _levelIndex = 0;
  List<List<int>> _grid = List.generate(4, (_) => List.filled(4, 0));
  int _score = 0;
  int _moves = 0;
  bool _gameOver = false;
  bool _won = false;
  final _rng = Random();

  int _hintCount = 0;

  @override
  void initState() {
    super.initState();
    _initLevel();
  }

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('twentyfortyeight');
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('level_twentyfortyeight') ?? 0;
    if (mounted) setState(() { _levelIndex = saved % _kLevels.length; _startGame(); });
  }

  Future<void> _saveLevel(int lvl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_twentyfortyeight', lvl);
    final earned = await HintManager.onLevelCleared('twentyfortyeight');
    final newCount = await HintManager.getHints('twentyfortyeight');
    setState(() {
      _hintCount = newCount;
    });
    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hint earned! (Total: $newCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.accentFor('twentyfortyeight'),
        ),
      );
    }
  }

  Future<void> _useHint() async {
    if (_won || _gameOver || _hintCount <= 0) return;

    // Find the highest tile value on the board
    int maxVal = 0;
    int maxR = -1;
    int maxC = -1;
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        if (_grid[r][c] > maxVal) {
          maxVal = _grid[r][c];
          maxR = r;
          maxC = c;
        }
      }
    }

    if (maxR == -1 || maxC == -1) return;

    await HintManager.useHint('twentyfortyeight');
    final newCount = await HintManager.getHints('twentyfortyeight');

    setState(() {
      _hintCount = newCount;
      final doubled = _grid[maxR][maxC] * 2;
      _grid[maxR][maxC] = doubled;
      _score += doubled;
      
      final target = _kLevels[_levelIndex % _kLevels.length].target;
      if (doubled >= target) {
        _won = true;
        _gameOver = true;
        _saveLevel(_levelIndex);
      }
    });
  }

  void _startGame() {
    _grid = List.generate(4, (_) => List.filled(4, 0));
    _score = 0;
    _moves = 0;
    _gameOver = false;
    _won = false;
    _addRandomTile();
    _addRandomTile();
  }

  void _addRandomTile() {
    final empty = <List<int>>[];
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        if (_grid[r][c] == 0) empty.add([r, c]);
      }
    }
    if (empty.isEmpty) return;
    final pos = empty[_rng.nextInt(empty.length)];
    _grid[pos[0]][pos[1]] = _rng.nextDouble() < 0.9 ? 2 : 4;
  }

  List<int> _merge(List<int> row) {
    final filtered = row.where((v) => v != 0).toList();
    final result = <int>[];
    int i = 0;
    while (i < filtered.length) {
      if (i + 1 < filtered.length && filtered[i] == filtered[i + 1]) {
        final merged = filtered[i] * 2;
        result.add(merged);
        _score += merged;
        i += 2;
      } else {
        result.add(filtered[i]);
        i++;
      }
    }
    while (result.length < 4) result.add(0);
    return result;
  }

  bool _swipe(String direction) {
    final oldGrid = _grid.map((r) => List<int>.from(r)).toList();
    switch (direction) {
      case'left':
        for (int r = 0; r < 4; r++) _grid[r] = _merge(_grid[r]);
        break;
      case'right':
        for (int r = 0; r < 4; r++) _grid[r] = _merge(_grid[r].reversed.toList()).reversed.toList();
        break;
      case'up':
        for (int c = 0; c < 4; c++) {
          final col = [_grid[0][c], _grid[1][c], _grid[2][c], _grid[3][c]];
          final merged = _merge(col);
          for (int r = 0; r < 4; r++) _grid[r][c] = merged[r];
        }
        break;
      case'down':
        for (int c = 0; c < 4; c++) {
          final col = [_grid[3][c], _grid[2][c], _grid[1][c], _grid[0][c]];
          final merged = _merge(col);
          for (int r = 0; r < 4; r++) _grid[3 - r][c] = merged[r];
        }
        break;
    }
    bool changed = false;
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        if (oldGrid[r][c] != _grid[r][c]) { changed = true; break; }
      }
      if (changed) break;
    }
    return changed;
  }

  void _handleSwipe(String direction) {
    if (_gameOver) return;
    setState(() {
      if (_swipe(direction)) {
        _moves++;
        _addRandomTile();
        settingsNotifier.hapticTap();
        // Check win
        final level = _kLevels[_levelIndex % _kLevels.length];
        int maxTile = 0;
        for (final row in _grid) {
          for (final v in row) {
            if (v > maxTile) maxTile = v;
          }
        }
        if (maxTile >= level.target) {
          _won = true;
          _gameOver = true;
          settingsNotifier.hapticSuccess();
          _saveLevel(_levelIndex);
        } else if (_moves >= level.maxMoves) {
          _gameOver = true;
        } else if (!_canMove()) {
          _gameOver = true;
        }
      }
    });
  }

  bool _canMove() {
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        if (_grid[r][c] == 0) return true;
        if (c + 1 < 4 && _grid[r][c] == _grid[r][c + 1]) return true;
        if (r + 1 < 4 && _grid[r][c] == _grid[r + 1][c]) return true;
      }
    }
    return false;
  }

  void _nextLevel() {
    setState(() {
      _levelIndex = (_levelIndex + 1) % _kLevels.length;
      _saveLevel(_levelIndex);
      _startGame();
    });
  }

  void _reset() => setState(() => _startGame());

  Color _tileColor(int val) {
    switch (val) {
      case 2: return const Color(0xFFEEE4DA);
      case 4: return const Color(0xFFEDE0C8);
      case 8: return const Color(0xFFF2B179);
      case 16: return const Color(0xFFF59563);
      case 32: return const Color(0xFFF67C5F);
      case 64: return const Color(0xFFF65E3B);
      case 128: return const Color(0xFFEDCF72);
      case 256: return const Color(0xFFEDCC61);
      case 512: return const Color(0xFFEDC850);
      case 1024: return const Color(0xFFEDC53F);
      case 2048: return const Color(0xFFEDC22E);
      case 4096: return const Color(0xFF3C3A32);
      case 8192: return const Color(0xFF3C3A32);
      default: return context.isDarkMode ? const Color(0xFF2A2A35) : const Color(0xFFCDC1B4);
    }
  }

  Color _textColor(int val) {
    return val <= 4 ? const Color(0xFF776E65) : Colors.white;
  }

  double _fontSize(int val) {
    if (val >= 1024) return context.scale(18);
    if (val >= 128) return context.scale(22);
    return context.scale(26);
  }

  @override
  Widget build(BuildContext context) {
    final level = _kLevels[_levelIndex % _kLevels.length];
    final accent = AppTheme.accentFor('twentyfortyeight');
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: Text('2048', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
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
            onPressed: _hintCount > 0 && !_won && !_gameOver ? _useHint : null,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            color: context.textMuted,
            onPressed: () => RulesHelper.showRulesBottomSheet(context,'twentyfortyeight','2048'),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _reset, color: context.textMuted),
          Padding(padding: const EdgeInsets.only(right: 12),
            child: Center(child: Text('Level ${_levelIndex + 1}', style: GoogleFonts.outfit(color: accent, fontSize: context.scale(13))))),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragEnd: (d) {
            if (d.primaryVelocity == null) return;
            if (d.primaryVelocity! < -100) _handleSwipe('left');
            else if (d.primaryVelocity! > 100) _handleSwipe('right');
          },
          onVerticalDragEnd: (d) {
            if (d.primaryVelocity == null) return;
            if (d.primaryVelocity! < -100) _handleSwipe('up');
            else if (d.primaryVelocity! > 100) _handleSwipe('down');
          },
          child: Column(
            children: [
              // Stats bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatChip(label:'SCORE', value:'$_score', color: accent),
                    _StatChip(label:'MOVES', value:'$_moves${level.maxMoves < 999 ?"/${level.maxMoves}":""}', color: context.textSecondary),
                    _StatChip(label:'TARGET', value:'${level.target}', color: accent),
                  ],
                ),
              ),
              const Spacer(),
              // Grid
              Center(
                child: Container(
                  width: context.scale(320),
                  height: context.scale(320),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.isDarkMode ? const Color(0xFF1E1E28) : const Color(0xFFBBADA0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: 16,
                    itemBuilder: (ctx, idx) {
                      final r = idx ~/ 4;
                      final c = idx % 4;
                      final val = _grid[r][c];
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: _tileColor(val),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: val > 0
                              ? Text(
'$val',
                                  style: GoogleFonts.outfit(
                                    fontSize: _fontSize(val),
                                    fontWeight: FontWeight.w800,
                                    color: _textColor(val),
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const Spacer(),
              // Game over / win
              if (_gameOver) ...[
                Text(
                  _won ?'Target Reached!':'Game Over',
                  style: GoogleFonts.outfit(
                    fontSize: context.scale(20),
                    fontWeight: FontWeight.w700,
                    color: _won ? accent : Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: _won ? _nextLevel : _reset,
                  child: Text(
                    _won ?'Next Level →':'Try Again',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: context.scale(14)),
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                Text(
'Swipe to merge tiles',
                  style: GoogleFonts.outfit(color: context.textMuted, fontSize: context.scale(12)),
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: GoogleFonts.outfit(color: context.textMuted, fontSize: context.scale(10), fontWeight: FontWeight.w700, letterSpacing: 1)),
      const SizedBox(height: 2),
      Text(value, style: GoogleFonts.outfit(color: color, fontSize: context.scale(18), fontWeight: FontWeight.w800)),
    ]);
  }
}
