import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/audio_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/challenge_cleared_overlay.dart';

class HueTile {
  final int id;
  final int correctRow;
  final int correctCol;
  final Color color;
  final bool isLocked;

  HueTile({
    required this.id,
    required this.correctRow,
    required this.correctCol,
    required this.color,
    required this.isLocked,
  });
}

class SpectrumScreen extends StatefulWidget {
  const SpectrumScreen({super.key});

  @override
  State<SpectrumScreen> createState() => _SpectrumScreenState();
}

class _SpectrumScreenState extends State<SpectrumScreen> {
  int _levelIndex = 0;
  int _hintCount = 0;
  bool _won = false;
  bool _isDailyMode = false;
  String _dailyModifierType = '';
  bool _isInitializing = true;
  double _prismHueOffset = 0.0;
  Timer? _prismTimer;

  late int _rows;
  late int _cols;

  late Color _cTL;
  late Color _cTR;
  late Color _cBL;
  late Color _cBR;

  // Grid containing the current tiles in their current positions
  late List<List<HueTile>> _grid;

  // Keep track of the currently selected tile coordinates for swapping
  int? _selectedRow;
  int? _selectedCol;

  // Preview mode: shows which tiles are in correct position
  bool _showingPreview = false;

  @override
  void initState() {
    super.initState();
    _generateSpectrum();
    _loadPersistedLevel();
  }

  @override
  void dispose() {
    _prismTimer?.cancel();
    super.dispose();
  }

  /// Returns how many unlocked tiles are currently in their correct position.
  int _correctCount() {
    int count = 0;
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        final t = _grid[r][c];
        if (!t.isLocked && t.correctRow == r && t.correctCol == c) count++;
      }
    }
    return count;
  }

  int _totalUnlocked() {
    int count = 0;
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        if (!_grid[r][c].isLocked) count++;
      }
    }
    return count;
  }

  void _togglePreview() {
    setState(() {
      _showingPreview = !_showingPreview;
    });
  }

  void _showTutorial(BuildContext ctx) {
    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'How to Play Spectrum',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _tutRow(
                '🎨',
                'The grid holds color tiles scrambled out of order.',
              ),
              _tutRow(
                '🔒',
                'Corner tiles (black dot) are locked in place as anchors.',
              ),
              _tutRow(
                '👆',
                'Tap one tile to SELECT it, then tap another to SWAP them.',
              ),
              _tutRow(
                '🌈',
                'Arrange tiles so colors blend smoothly — no sudden jumps.',
              ),
              _tutRow(
                '✅',
                'Tap PREVIEW (👁) to toggle showing which tiles are correct.',
              ),
              _tutRow('💡', 'Use Hint to auto-fix the most misplaced tile.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Got it!',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tutRow(String emoji, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(fontSize: 13, height: 1.5),
          ),
        ),
      ],
    ),
  );

  void _setupGridDimensions() {
    if (_isDailyMode && _dailyModifierType == 'prism') {
      _rows = 5;
      _cols = 5;
      return;
    }
    final tier = _levelIndex ~/ 5; // 0-based tier, each tier = 5 levels
    switch (tier) {
      case 0:
        _rows = 3;
        _cols = 3;
        break; // level 1-5
      case 1:
        _rows = 4;
        _cols = 4;
        break; // level 6-10
      case 2:
        _rows = 5;
        _cols = 5;
        break; // level 11-15
      case 3:
        _rows = 6;
        _cols = 6;
        break; // level 16-20
      case 4:
        _rows = 7;
        _cols = 7;
        break; // level 21-25
      case 5:
        _rows = 8;
        _cols = 8;
        break; // level 26-30
      case 6:
        _rows = 9;
        _cols = 9;
        break; // level 31-35
      case 7:
        _rows = 9;
        _cols = 10;
        break; // level 36-40
      case 8:
        _rows = 10;
        _cols = 10;
        break; // level 41-45
      default:
        _rows = 10;
        _cols = 11;
        break; // level 46-50
    }
  }

  bool _isTileLocked(int r, int c) {
    if ((r == 0 && c == 0) ||
        (r == 0 && c == _cols - 1) ||
        (r == _rows - 1 && c == 0) ||
        (r == _rows - 1 && c == _cols - 1)) {
      return true;
    }
    if (_rows >= 6 && _cols >= 6) {
      final midR = _rows ~/ 2;
      final midC = _cols ~/ 2;
      if ((r == 0 && c == midC) ||
          (r == _rows - 1 && c == midC) ||
          (r == midR && c == 0) ||
          (r == midR && c == _cols - 1)) {
        return true;
      }
      if (_rows % 2 != 0 && _cols % 2 != 0) {
        if (r == midR && c == midC) {
          return true;
        }
      }
    }
    return false;
  }

  void _generateSpectrum() {
    _setupGridDimensions();
    final rand = _isDailyMode ? Random(_levelIndex * 12345) : Random();

    if (_isDailyMode && _dailyModifierType == 'monochrome') {
      _cTL = const Color(0xFFFFFFFF);
      _cTR = const Color(0xFFB0B0B0);
      _cBL = const Color(0xFF505050);
      _cBR = const Color(0xFF101010);
    } else {
      double startHue = rand.nextDouble() * 360.0;
      double h1 = startHue;
      double h2 = (h1 + 70.0 + rand.nextDouble() * 40.0) % 360.0;
      double h3 = (h2 + 70.0 + rand.nextDouble() * 40.0) % 360.0;
      double h4 = (h3 + 70.0 + rand.nextDouble() * 40.0) % 360.0;

      _cTL = HSLColor.fromAHSL(1.0, h1, 0.80, 0.55).toColor();
      _cTR = HSLColor.fromAHSL(1.0, h2, 0.80, 0.55).toColor();
      _cBL = HSLColor.fromAHSL(1.0, h3, 0.80, 0.55).toColor();
      _cBR = HSLColor.fromAHSL(1.0, h4, 0.80, 0.55).toColor();
    }

    // Create correct list of tiles
    int tileId = 0;
    final List<HueTile> allTiles = [];

    for (int r = 0; r < _rows; r++) {
      double v = r / (_rows - 1);
      for (int c = 0; c < _cols; c++) {
        double u = c / (_cols - 1);

        Color topColor = Color.lerp(_cTL, _cTR, u)!;
        Color bottomColor = Color.lerp(_cBL, _cBR, u)!;
        Color cellColor = Color.lerp(topColor, bottomColor, v)!;

        bool isLocked = _isTileLocked(r, c);

        allTiles.add(
          HueTile(
            id: tileId++,
            correctRow: r,
            correctCol: c,
            color: cellColor,
            isLocked: isLocked,
          ),
        );
      }
    }

    // Separate unlocked tiles to scramble them
    final List<HueTile> unlocked = allTiles.where((t) => !t.isLocked).toList();

    // Ensure we don't accidentally get the solved state immediately
    bool isSolved = true;
    while (isSolved) {
      unlocked.shuffle(rand);

      // Check if it's already solved
      isSolved = true;
      int unlockedIdx = 0;
      for (int r = 0; r < _rows; r++) {
        for (int c = 0; c < _cols; c++) {
          bool isLocked = _isTileLocked(r, c);
          if (!isLocked) {
            final t = unlocked[unlockedIdx++];
            if (t.correctRow != r || t.correctCol != c) {
              isSolved = false;
              break;
            }
          }
        }
        if (!isSolved) break;
      }
    }

    // Reconstruct the board grid using List.generate to avoid fixed-length lists
    _grid = List.generate(
      _rows,
      (r) => List.generate(_cols, (c) => allTiles[0]),
    );
    int unlockedIndex = 0;

    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        bool isLocked = _isTileLocked(r, c);
        if (isLocked) {
          // Find the correct tile from the original lists
          _grid[r][c] = allTiles.firstWhere(
            (t) => t.correctRow == r && t.correctCol == c,
          );
        } else {
          _grid[r][c] = unlocked[unlockedIndex++];
        }
      }
    }

    _selectedRow = null;
    _selectedCol = null;
    _won = false;

    if (!_isInitializing) {
      _saveMidLevelState();
    }
    _startPrismTimer();
  }

  Future<void> _saveMidLevelState() async {
    if (_isDailyMode) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('spectrum_mid_levelIndex', _levelIndex);
      await prefs.setInt('spectrum_mid_cTL', _cTL.value);
      await prefs.setInt('spectrum_mid_cTR', _cTR.value);
      await prefs.setInt('spectrum_mid_cBL', _cBL.value);
      await prefs.setInt('spectrum_mid_cBR', _cBR.value);

      final List<int> tileIds = [];
      for (int r = 0; r < _rows; r++) {
        for (int c = 0; c < _cols; c++) {
          tileIds.add(_grid[r][c].id);
        }
      }
      await prefs.setString('spectrum_mid_layout', tileIds.join(','));
    } catch (_) {}
  }

  Future<void> _clearMidLevelState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('spectrum_mid_levelIndex');
      await prefs.remove('spectrum_mid_cTL');
      await prefs.remove('spectrum_mid_cTR');
      await prefs.remove('spectrum_mid_cBL');
      await prefs.remove('spectrum_mid_cBR');
      await prefs.remove('spectrum_mid_layout');
    } catch (_) {}
  }

  void _startPrismTimer() {
    _prismTimer?.cancel();
    if (_isDailyMode && _dailyModifierType == 'prism') {
      _prismHueOffset = 0.0;
      _prismTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (!mounted || _won) {
          timer.cancel();
          return;
        }
        setState(() {
          _prismHueOffset = (_prismHueOffset + 2.0) % 360.0;
        });
      });
    }
  }

  Future<void> _loadPersistedLevel() async {
    _hintCount = await HintManager.getHints('hue');
    final prefs = await SharedPreferences.getInstance();
    _isDailyMode = prefs.getBool('play_daily_mode') ?? false;
    if (_isDailyMode) {
      _dailyModifierType = prefs.getString('daily_modifier_type') ?? '';
    }
    final savedLevel = prefs.getInt('level_hue') ?? 0;

    if (mounted) {
      setState(() {
        _levelIndex = savedLevel;

        final midLevelIndex = prefs.getInt('spectrum_mid_levelIndex');
        final midLayoutStr = prefs.getString('spectrum_mid_layout');
        if (!_isDailyMode &&
            midLevelIndex == _levelIndex &&
            midLayoutStr != null &&
            midLayoutStr.isNotEmpty) {
          _setupGridDimensions();
          final cTLVal = prefs.getInt('spectrum_mid_cTL')!;
          final cTRVal = prefs.getInt('spectrum_mid_cTR')!;
          final cBLVal = prefs.getInt('spectrum_mid_cBL')!;
          final cBRVal = prefs.getInt('spectrum_mid_cBR')!;
          _cTL = Color(cTLVal);
          _cTR = Color(cTRVal);
          _cBL = Color(cBLVal);
          _cBR = Color(cBRVal);

          int tileId = 0;
          final List<HueTile> allTiles = [];
          for (int r = 0; r < _rows; r++) {
            double v = r / (_rows - 1);
            for (int c = 0; c < _cols; c++) {
              double u = c / (_cols - 1);
              Color topColor = Color.lerp(_cTL, _cTR, u)!;
              Color bottomColor = Color.lerp(_cBL, _cBR, u)!;
              Color cellColor = Color.lerp(topColor, bottomColor, v)!;
              bool isLocked = _isTileLocked(r, c);
              allTiles.add(
                HueTile(
                  id: tileId++,
                  correctRow: r,
                  correctCol: c,
                  color: cellColor,
                  isLocked: isLocked,
                ),
              );
            }
          }

          final layoutIds = midLayoutStr.split(',').map(int.parse).toList();
          _grid = List.generate(
            _rows,
            (r) => List.generate(_cols, (c) => allTiles[0]),
          );
          int layoutIdx = 0;
          for (int r = 0; r < _rows; r++) {
            for (int c = 0; c < _cols; c++) {
              final id = layoutIds[layoutIdx++];
              _grid[r][c] = allTiles.firstWhere((t) => t.id == id);
            }
          }
          _selectedRow = null;
          _selectedCol = null;
          _won = false;
          _isInitializing = false;
        } else {
          _isInitializing = false;
          _generateSpectrum();
        }
      });
      _startPrismTimer();
    }
  }

  Future<void> _savePersistedLevel(int lvl) async {
    if (_isDailyMode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_hue', lvl);
    final earned = await HintManager.onLevelCleared('hue');
    final newCount = await HintManager.getHints('hue');
    if (mounted) {
      setState(() {
        _hintCount = newCount;
      });
    }
    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hint earned! (Total: $newCount)',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.accentFor('hue'),
        ),
      );
    }
  }

  void _onTileTap(int r, int c) {
    if (_won) return;

    final tile = _grid[r][c];
    if (tile.isLocked) return;

    AudioManager.playClick();

    setState(() {
      if (_selectedRow == r && _selectedCol == c) {
        // Deselect
        _selectedRow = null;
        _selectedCol = null;
      } else if (_selectedRow == null) {
        // Select
        _selectedRow = r;
        _selectedCol = c;
      } else {
        // Swap
        final temp = _grid[r][c];
        _grid[r][c] = _grid[_selectedRow!][_selectedCol!];
        _grid[_selectedRow!][_selectedCol!] = temp;

        _selectedRow = null;
        _selectedCol = null;

        _checkWinCondition();
        _saveMidLevelState();
      }
    });
  }

  void _checkWinCondition() {
    bool correct = true;
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        final t = _grid[r][c];
        if (t.correctRow != r || t.correctCol != c) {
          correct = false;
          break;
        }
      }
      if (!correct) break;
    }

    if (correct) {
      _won = true;
      _showingPreview = false;
      AudioManager.playSuccess();
      _savePersistedLevel(_levelIndex + 1);
      _clearMidLevelState();
    }
  }

  Future<void> _useHint() async {
    if (_won || _hintCount <= 0) return;

    // Find the first misplaced tile
    int? wrongR, wrongC;
    outerLoop:
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        final t = _grid[r][c];
        if (t.correctRow != r || t.correctCol != c) {
          wrongR = r;
          wrongC = c;
          break outerLoop;
        }
      }
    }

    if (wrongR == null || wrongC == null) return;

    // The tile at (wrongR, wrongC) belongs elsewhere, but we want to put the correct tile at (wrongR, wrongC).
    // Let's find where the tile that *belongs* at (wrongR, wrongC) is currently located.
    int? sourceR, sourceC;
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        final t = _grid[r][c];
        if (t.correctRow == wrongR && t.correctCol == wrongC) {
          sourceR = r;
          sourceC = c;
          break;
        }
      }
    }

    if (sourceR == null || sourceC == null) return;

    await HintManager.useHint('hue');
    final newCount = await HintManager.getHints('hue');

    setState(() {
      _hintCount = newCount;
      // Swap them to resolve the spot!
      final temp = _grid[wrongR!][wrongC!];
      _grid[wrongR][wrongC] = _grid[sourceR!][sourceC!];
      _grid[sourceR][sourceC] = temp;

      _selectedRow = null;
      _selectedCol = null;

      _checkWinCondition();
      _saveMidLevelState();
    });
  }

  void _nextLevel() {
    if (!_won) return;
    if (_isDailyMode) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _levelIndex++;
      _generateSpectrum();
      _clearMidLevelState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AppTheme.accentFor('hue');

    // Grid sizes
    final double screenW = context.screenWidth;
    final double gridW = min(screenW - 32, 420.0);

    // Dynamic cell width and height calculations to maintain layout
    final double cellW = (gridW - (_cols - 1) * 4) / _cols;
    final int correct = _correctCount();
    final int total = _totalUnlocked();
    final double pct = total == 0 ? 0 : correct / total;

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: Text(
          'Spectrum',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: context.scale(18),
          ),
        ),
        actions: [
          // Preview button
          if (!_won)
            IconButton(
              tooltip: 'Toggle correct tiles preview',
              icon: Icon(
                Icons.visibility_outlined,
                color: _showingPreview ? accentColor : null,
              ),
              onPressed: _togglePreview,
            ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showTutorial(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                if (_isDailyMode)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    color: Colors.amber.withOpacity(0.15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'DAILY CHALLENGE: BLACK & WHITE SPECTRUM',
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
                // Header — progress counter
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isDailyMode
                                ? 'Daily Challenge  •  ${_rows}×${_cols}'
                                : 'Level ${_levelIndex + 1}  •  ${_rows}×${_cols}',
                            style: AppTheme.numberStyle(
                              fontSize: context.scale(14),
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _won
                                ? '✓ Solved!'
                                : 'Swap tiles · tap 👁 to preview',
                            style: GoogleFonts.outfit(
                              fontSize: context.scale(11),
                              color: _won
                                  ? Colors.green
                                  : context.textSecondary,
                              fontWeight: _won
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Correct tiles badge
                      if (!_won)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$correct / $total',
                              style: AppTheme.numberStyle(
                                fontSize: context.scale(18),
                                fontWeight: FontWeight.bold,
                                color: pct > 0.7
                                    ? Colors.green
                                    : pct > 0.4
                                    ? Colors.amber
                                    : accentColor,
                              ),
                            ),
                            Text(
                              'correct',
                              style: GoogleFonts.outfit(
                                fontSize: context.scale(10),
                                color: context.textMuted,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                // Progress bar
                if (!_won)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 5,
                        backgroundColor: context.bgSurface,
                        valueColor: AlwaysStoppedAnimation(
                          pct > 0.7
                              ? Colors.green
                              : pct > 0.4
                              ? Colors.amber
                              : accentColor,
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                // Gradient board
                Center(
                  child: Container(
                    width: gridW,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_rows, (r) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_cols, (c) {
                            final tile = _grid[r][c];
                            final isSelected =
                                _selectedRow == r && _selectedCol == c;
                            final isCorrect =
                                tile.correctRow == r && tile.correctCol == c;
                            final showGreen =
                                _showingPreview && !tile.isLocked && isCorrect;

                            return GestureDetector(
                              onTap: () => _onTileTap(r, c),
                              child: AnimatedScale(
                                scale: isSelected ? 0.88 : 1.0,
                                duration: const Duration(milliseconds: 150),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: cellW - 2,
                                  height: cellW - 2,
                                  margin: const EdgeInsets.all(1),
                                  decoration: BoxDecoration(
                                    color: (_isDailyMode && _dailyModifierType == 'prism')
                                        ? (() {
                                            final hsl = HSLColor.fromColor(tile.color);
                                            return HSLColor.fromAHSL(
                                              hsl.alpha,
                                              (hsl.hue + _prismHueOffset) % 360.0,
                                              hsl.saturation,
                                              hsl.lightness,
                                            ).toColor();
                                          })()
                                        : tile.color,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: showGreen
                                          ? Colors.greenAccent
                                          : isSelected
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: showGreen
                                          ? 2.5
                                          : isSelected
                                          ? 2.5
                                          : 0,
                                    ),
                                    boxShadow: (isSelected || showGreen)
                                        ? [
                                            BoxShadow(
                                              color:
                                                  (showGreen
                                                          ? Colors.green
                                                          : Colors.black)
                                                      .withOpacity(0.5),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: tile.isLocked
                                        ? Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(
                                                0.5,
                                              ),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white.withOpacity(
                                                  0.7,
                                                ),
                                                width: 1.5,
                                              ),
                                            ),
                                          )
                                        : showGreen
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 10,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      }),
                    ),
                  ),
                ),
                const Spacer(),
                // Bottom buttons
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: _won
                      ? Center(
                          child: _isDailyMode
                              ? const SizedBox.shrink()
                              : AutoNextCountdown(
                                  onNext: _nextLevel,
                                  accentColor: accentColor,
                                ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _won ? null : _useHint,
                              icon: Icon(
                                Icons.lightbulb_outline,
                                size: context.scale(18),
                              ),
                              label: Text(
                                'Hint ($_hintCount)',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  fontSize: context.scale(13),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.amber,
                                side: const BorderSide(
                                  color: Colors.amber,
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _generateSpectrum,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.bgSurface,
                                foregroundColor: context.textPrimary,
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              child: Text(
                                'Reset',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: context.scale(13),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          if (_won && _isDailyMode)
            Positioned.fill(
              child: ChallengeClearedOverlay(
                accentColor: accentColor,
                onComplete: () {
                  Navigator.pop(context, true);
                },
              ),
            ),
        ],
      ),
    );
  }
}
