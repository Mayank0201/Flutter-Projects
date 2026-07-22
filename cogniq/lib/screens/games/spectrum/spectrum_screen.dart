import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/prefs_keys.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/audio_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../widgets/game_tutorial_dialog.dart';
import '../../../widgets/buy_hints_dialog.dart';
import '../../../utils/rotation_engine.dart';
import '../../../utils/point_manager.dart';
import '../../../utils/shuffle_manager.dart';

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
  bool _shuffleActive = false;
  int _hintCount = 0;
  bool _won = false;
  bool _isTutorialMode = false;
  bool _tutorialCompleted = false;
  int _actualGameLevel = 0;
  bool _isDailyMode = false;
  String _dailyModifierType = '';
  bool _isInitializing = true;
  double _prismHueOffset = 0.0;
  Timer? _prismTimer;
  Set<String> _activeModifiers = {};
  int _resetCount = 0;

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
  List<int> _distractorIndices = [];
  Timer? _gameTimer;
  int _timeLeft = -1;
  bool _timeBonusEarned = false;
  int _movesLeft = -1;

  @override
  void initState() {
    super.initState();
    _generateSpectrum();
    _loadPersistedLevel();
  }

  @override
  void dispose() {
    _prismTimer?.cancel();
    _gameTimer?.cancel();
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



  void _setupGridDimensions() {
    if (_isDailyMode && _dailyModifierType == 'prism') {
      _rows = 5;
      _cols = 5;
      return;
    }
    if (!_isDailyMode && _levelIndex >= 30) {
      if (_levelIndex >= 80) {
        _rows = 10;
        _cols = 10;
      } else if (_levelIndex >= 60 && _levelIndex < 80) {
        // Stage 4: Progressive grid size
        int tier = (_levelIndex - 60) ~/ 5;
        if (tier == 0) {
          _rows = 8; _cols = 8;
        } else if (tier == 1) {
          _rows = 9; _cols = 9;
        } else if (tier == 2) {
          _rows = 9; _cols = 10;
        } else {
          _rows = 10; _cols = 10;
        }
      } else if (_levelIndex >= 45 && _levelIndex < 60) {
        // Stage 3: Three-color mixing
        _rows = 7;
        _cols = 7;
      } else {
        // Stage 2: Distractor cards
        _rows = 6;
        _cols = 6;
      }
      return;
    }
    final tier = _levelIndex ~/ 5;
    switch (tier) {
      case 0:
        _rows = 3;
        _cols = 3;
        break;
      case 1:
        _rows = 4;
        _cols = 4;
        break;
      case 2:
        _rows = 5;
        _cols = 5;
        break;
      case 3:
        _rows = 6;
        _cols = 6;
        break;
      case 4:
        _rows = 7;
        _cols = 7;
        break;
      case 5:
        _rows = 8;
        _cols = 8;
        break;
      case 6:
        _rows = 9;
        _cols = 9;
        break;
      case 7:
        _rows = 9;
        _cols = 10;
        break;
      case 8:
        _rows = 10;
        _cols = 10;
        break;
      default:
        final extraTiers = tier - 9;
        _rows = (10 + extraTiers ~/ 2).clamp(10, 12);
        _cols = (11 + (extraTiers + 1) ~/ 2).clamp(11, 13);
        break;
    }
  }

  bool _isTileLocked(int r, int c) {
    if ((r == 0 && c == 0) ||
        (r == 0 && c == _cols - 1) ||
        (r == _rows - 1 && c == 0) ||
        (r == _rows - 1 && c == _cols - 1)) {
      return true;
    }
    if (!_isDailyMode && _levelIndex >= 30) {
      return false;
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
    _gameTimer?.cancel();
    _timeLeft = -1;
    _timeBonusEarned = false;
    _movesLeft = -1;

    _setupGridDimensions();
    if (!_isDailyMode && _levelIndex >= 30) {
      bool isSmallGrid = (_rows * _cols <= 16);
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'spectrum',
        levelIndex: _levelIndex,
        pool: ['monochrome', 'prism', 'timer', 'moveLimit', 'gradientComplexity', 'distractors'],
        minActive: 2,
        maxActive: 3,
        smallGrid: isSmallGrid,
      );
    } else {
      _activeModifiers = {};
    }

    final rand = (_isDailyMode || _levelIndex < 30)
        ? Random()
        : RotationEngine.getDeterminism('spectrum', _levelIndex + _resetCount);

    bool isMonochrome = (_isDailyMode && _dailyModifierType == 'monochrome') ||
        (!_isDailyMode && _levelIndex >= 30 && _activeModifiers.contains('monochrome'));

    if (isMonochrome) {
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

      bool isThreeColor = (!_isDailyMode && _levelIndex >= 30 && _activeModifiers.contains('gradientComplexity'));
      if (isThreeColor) {
        _cBR = Color.lerp(_cBL, _cTR, 0.5)!;
      }
    }

    int distractorCount = 0;
    if (!_isDailyMode && _levelIndex >= 30) {
      if (_activeModifiers.contains('distractors')) {
        distractorCount = 2 + (_levelIndex - 30) ~/ 10;
        if (distractorCount > 5) distractorCount = 5;
      }
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

    // Apply distractors if needed
    _distractorIndices = [];
    if (distractorCount > 0) {
      final List<int> candidates = [];
      for (int i = 0; i < allTiles.length; i++) {
        if (!allTiles[i].isLocked) {
          candidates.add(i);
        }
      }
      candidates.shuffle(rand);
      _distractorIndices = candidates.take(distractorCount).toList();
      for (int idx in _distractorIndices) {
        double dHue = (rand.nextDouble() * 360.0);
        Color distractorColor = HSLColor.fromAHSL(1.0, dHue, 0.95, 0.45).toColor();
        final original = allTiles[idx];
        allTiles[idx] = HueTile(
          id: original.id,
          correctRow: original.correctRow,
          correctCol: original.correctCol,
          color: distractorColor,
          isLocked: original.isLocked,
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

    if (!_isDailyMode && _levelIndex >= 30) {
      if (_activeModifiers.contains('moveLimit')) {
        _movesLeft = 15 + (_rows * _cols ~/ 3);
      }
      if (_activeModifiers.contains('timer')) {
        _timeLeft = 5 * _rows * _cols;
        _timeBonusEarned = true;
        _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            if (_timeLeft > 0) {
              setState(() {
                _timeLeft--;
              });
            } else {
              _gameTimer?.cancel();
              AudioManager.playFail();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Time is up! Restarting level...'), duration: Duration(seconds: 1)),
              );
              _generateSpectrum();
            }
          }
        });
      }
    }

    if (!_isInitializing) {
      _saveMidLevelState();
    }
    _startPrismTimer();
  }

  void _showJumpToLevelDialog() {
    final controller = TextEditingController(text: '${_levelIndex + 1}');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text('Jump to Level', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter level number:', style: GoogleFonts.outfit(color: context.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: GoogleFonts.outfit(color: context.textPrimary),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'e.g. 100',
                hintStyle: GoogleFonts.outfit(color: context.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: context.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentFor('hue')),
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val >= 1) {
                Navigator.pop(context);
                setState(() {
                  _levelIndex = val - 1;
                  _resetCount = 0;
                  _generateSpectrum();
                });
              }
            },
            child: Text('Go', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveMidLevelState() async {
    if (_isDailyMode) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(PrefsKeys.spectrumMidLevelIndex, _levelIndex);
      await prefs.setInt(PrefsKeys.spectrumMidCTL, _cTL.value);
      await prefs.setInt(PrefsKeys.spectrumMidCTR, _cTR.value);
      await prefs.setInt(PrefsKeys.spectrumMidCBL, _cBL.value);
      await prefs.setInt(PrefsKeys.spectrumMidCBR, _cBR.value);

      final List<int> tileIds = [];
      for (int r = 0; r < _rows; r++) {
        for (int c = 0; c < _cols; c++) {
          tileIds.add(_grid[r][c].id);
        }
      }
      await prefs.setString(PrefsKeys.spectrumMidLayout, tileIds.join(','));
    } catch (_) {}
  }

  Future<void> _clearMidLevelState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(PrefsKeys.spectrumMidLevelIndex);
      await prefs.remove(PrefsKeys.spectrumMidCTL);
      await prefs.remove(PrefsKeys.spectrumMidCTR);
      await prefs.remove(PrefsKeys.spectrumMidCBL);
      await prefs.remove(PrefsKeys.spectrumMidCBR);
      await prefs.remove(PrefsKeys.spectrumMidLayout);
    } catch (_) {}
  }

  void _startPrismTimer() {
    _prismTimer?.cancel();
    bool isPrism = (_isDailyMode && _dailyModifierType == 'prism') ||
        (!_isDailyMode && _levelIndex >= 30 && _activeModifiers.contains('prism'));
    if (isPrism) {
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
    _isDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    if (_isDailyMode) {
      _dailyModifierType = prefs.getString(PrefsKeys.dailyModifierType) ?? '';
    }
    final savedLevel = prefs.getInt(PrefsKeys.gameLevel('hue')) ?? 0;
    final active = await ShuffleManager.isActive();

    _isTutorialMode = false;
    _levelIndex = savedLevel;

    if (mounted) {
      setState(() {
        _shuffleActive = active;

        final midLevelIndex = prefs.getInt(PrefsKeys.spectrumMidLevelIndex);
        final midLayoutStr = prefs.getString(PrefsKeys.spectrumMidLayout);
        if (!_isDailyMode &&
            midLevelIndex == _levelIndex &&
            midLayoutStr != null &&
            midLayoutStr.isNotEmpty) {
          _setupGridDimensions();
          final cTLVal = prefs.getInt(PrefsKeys.spectrumMidCTL)!;
          final cTRVal = prefs.getInt(PrefsKeys.spectrumMidCTR)!;
          final cBLVal = prefs.getInt(PrefsKeys.spectrumMidCBL)!;
          final cBRVal = prefs.getInt(PrefsKeys.spectrumMidCBR)!;
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
    await prefs.setInt(PrefsKeys.gameLevel('hue'), lvl);
    final earned = await HintManager.onLevelCleared('hue');
    final newCount = await HintManager.getHints('hue');
    if (mounted) {
      setState(() {
        _hintCount = newCount;
      });
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

        if (_movesLeft > 0) {
          _movesLeft--;
        }

        _checkWinCondition();
        _saveMidLevelState();

        if (_movesLeft == 0 && !_won) {
          AudioManager.playFail();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No swaps left! Resetting...', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.redAccent,
            ),
          );
          _resetCount++;
          _generateSpectrum();
        }
      }
    });
  }

  void _checkWinCondition() {
    bool correct = true;
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        final t = _grid[r][c];
        if (t.correctRow != r || t.correctCol != c) {
          final targetTile = _grid[t.correctRow][t.correctCol];
          if (t.color.value != targetTile.color.value) {
            correct = false;
            break;
          }
        }
      }
      if (!correct) break;
    }

    if (correct) {
      if (_isTutorialMode) {
        setState(() {
          _tutorialCompleted = true;
          _showingPreview = false;
        });
        AudioManager.playSuccess();
      } else {
        _gameTimer?.cancel();
        _won = true;
        _showingPreview = false;
        AudioManager.playSuccess();
        _savePersistedLevel(_levelIndex + 1);
        _clearMidLevelState();

        if (_timeLeft > 0 && _timeBonusEarned) {
          PointManager.addPoints(5);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Speed Bonus! Earned +5 Points!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.black)),
              backgroundColor: Colors.amber,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
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

  void _nextLevel() async {
    if (!_won) return;
    if (_isDailyMode) {
      Navigator.pop(context, true);
      return;
    }
    if (await ShuffleManager.tryShuffleNavigate(context, 'hue')) return;
 
    setState(() {
      _levelIndex++;
      _resetCount = 0;
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
          _isTutorialMode ? 'Tutorial' : 'Spectrum',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: context.scale(18),
          ),
        ),
        actions: [
          if (_shuffleActive && !_isTutorialMode)
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              tooltip: 'Skip Game',
              onPressed: () => ShuffleManager.tryShuffleNavigate(context, 'hue'),
            ),
          // Preview button
          if (!_won && !_isTutorialMode)
            IconButton(
              tooltip: 'Toggle correct tiles preview',
              icon: Icon(
                Icons.visibility_outlined,
                color: _showingPreview ? accentColor : null,
              ),
              onPressed: _togglePreview,
            ),
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
                      _hintCount == 0 ? '+' : '$_hintCount',
                      style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            onPressed: !_won && !_isTutorialMode
                ? () async {
                    if (_hintCount > 0) {
                      _useHint();
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'hue',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('hue');
                          if (mounted) setState(() => _hintCount = newCount);
                        },
                      );
                    }
                  }
                : null,
          ),
          if (_timeLeft >= 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Row(
                  children: [
                    Icon(
                      Icons.timer,
                      color: _timeLeft <= 10 ? Colors.red : Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_timeLeft s',
                      style: GoogleFonts.spaceGrotesk(
                        color: _timeLeft <= 10 ? Colors.red : Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => GameTutorialDialog.show(context, 'hue', 'Spectrum'),
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
                          GestureDetector(
                            onTap: (_isTutorialMode || _isDailyMode) ? null : _showJumpToLevelDialog,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _isTutorialMode
                                      ? 'Tutorial  •  ${_rows}×${_cols}'
                                      : _isDailyMode
                                          ? 'Daily Challenge  •  ${_rows}×${_cols}'
                                          : 'Level ${_levelIndex + 1}  •  ${_rows}×${_cols}',
                                  style: AppTheme.numberStyle(
                                    fontSize: context.scale(14),
                                    fontWeight: FontWeight.bold,
                                    color: context.textPrimary,
                                  ),
                                ),
                                if (!_isTutorialMode && !_isDailyMode) ...[
                                  const SizedBox(width: 4),
                                  Icon(null, size: 12, color: context.textPrimary),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isTutorialMode
                                ? (_tutorialCompleted ? '✓ Solved!' : 'Drag/Swap tiles to order the spectrum')
                                : _won
                                    ? '✓ Solved!'
                                    : (_movesLeft >= 0
                                        ? 'Swaps left: $_movesLeft · tap 👁 to preview'
                                        : 'Swap tiles · tap 👁 to preview'),
                            style: GoogleFonts.outfit(
                              fontSize: context.scale(11),
                              color: (_won || _tutorialCompleted)
                                  ? Colors.green
                                  : context.textSecondary,
                              fontWeight: (_won || _tutorialCompleted)
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
                                    color: ((_isDailyMode && _dailyModifierType == 'prism') ||
                                            (!_isDailyMode && _levelIndex >= 30 && _activeModifiers.contains('prism')))
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
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: (_won && !_isTutorialMode)
                      ? Center(
                          child: _isDailyMode
                              ? const SizedBox.shrink()
                              : AutoNextCountdown(
                                  onNext: _nextLevel,
                                  accentColor: accentColor,
                                ),
                        )
                      : const SizedBox(height: 48),
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
          // if (_isTutorialMode)
          //   InteractiveTutorialOverlay(
          //     instruction: _tutorialCompleted
          //         ? "Nice! You successfully arranged the colors in order."
          //         : "Tap a tile, then tap an adjacent tile to swap them. Arrange all tiles so they form a smooth color gradient from corner to corner. The circles represent locked guide tiles!",
          //     isCompleted: _tutorialCompleted,
          //     onSkip: _finishTutorial,
          //     onStartGame: _finishTutorial,
          //   ),
        ],
      ),
    );
  }
}
