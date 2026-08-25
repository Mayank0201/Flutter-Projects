import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/buy_hints_dialog.dart';
import '../../../widgets/fog_overlay.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../utils/prefs_keys.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/point_manager.dart';
import '../../../utils/progress_guard.dart';
import '../../../utils/rotation_engine.dart';
import '../../../widgets/game_level_chip.dart';
import 'hitori_logic.dart';

class HitoriScreen extends StatefulWidget {
  const HitoriScreen({super.key});

  @override
  State<HitoriScreen> createState() => _HitoriScreenState();
}

class _HitoriScreenState extends State<HitoriScreen> {
  int _currentLevel = 0;
  bool _isSuccess = false;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  String _dailyModifierName = '';
  String _dailyModifierDesc = '';
  String? _forcedModifier;
  Set<String> _activeModifiers = {};

  /// The `timer` modifier. This was pooled from 2.0 with **no implementation at
  /// all** — no Timer, no countdown, nothing — so roughly a third of Hitori's
  /// modifier slots silently did nothing and difficulty did not rise on those
  /// levels. That shipped in 2.0.0+52 and 2.1.0+53. It is the exact breach the
  /// `_isModActive` helper below was added to prevent, and its own comment says
  /// so, which is what makes it worth writing down.
  Timer? _gameTimer;
  int _timeLeft = -1;
  double _dailyRadius = 1.5;
  int _gridSize = 4; // 4, 6, or 8 based on level

  List<int> _grid = []; // Cell values
  List<bool> _shaded = []; // Player's shaded cells
  List<bool> _markedWhite = []; // Player's marked-to-keep-white cells (circle helper)
  List<bool> _solution = []; // Correct solution shaded mask

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgressAndGenerate();
  }

  Future<void> _loadProgressAndGenerate() async {
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString(PrefsKeys.dailyModifierType) ?? '';
      _dailyModifierName = prefs.getString(PrefsKeys.dailyModifierName) ?? '';
      _dailyModifierDesc = prefs.getString(PrefsKeys.dailyModifierDesc) ?? '';
      final extraParamsStr = prefs.getString(PrefsKeys.dailyModifierExtraParams) ?? '';
      if (extraParamsStr.isNotEmpty) {
        try {
          final extraParams = jsonDecode(extraParamsStr) as Map<String, dynamic>;
          if (extraParams.containsKey('radius')) {
            _dailyRadius = (extraParams['radius'] as num).toDouble();
          } else {
            _dailyRadius = 1.5;
          }
        } catch (_) {
          _dailyRadius = 1.5;
        }
      } else {
        _dailyRadius = 1.5;
      }
    } else {
      _dailyModifierType = '';
      _dailyModifierName = '';
      _dailyModifierDesc = '';
      _dailyRadius = 1.5;
    }

    int level = prefs.getInt(PrefsKeys.gameLevel('hitori')) ?? 0;
    if (mounted) {
      setState(() {
        _currentLevel = level;
        _isLoading = true;
      });
      _generatePuzzle();
    }
  }

  /// Debug-only level jump. `GameLevelChip` only wires this up when `kDebugMode`
  /// is true, so it compiles out of release builds.
  void _showJumpToLevelDialog() {
    showDialog(
      context: context,
      builder: (context) {
        int target = _currentLevel + 1;
        return AlertDialog(
          backgroundColor: context.bgCard,
          title: Text('Jump to Level',
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold, color: context.textPrimary)),
          content: TextField(
            autofocus: true,
            keyboardType: TextInputType.number,
            style: GoogleFonts.outfit(color: context.textPrimary),
            decoration: InputDecoration(
              labelText: 'Level Number (1+)',
              labelStyle: GoogleFonts.outfit(color: context.textSecondary),
            ),
            onChanged: (val) => target = int.tryParse(val) ?? target,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: GoogleFonts.outfit(color: context.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (target > 0) {
                  setState(() {
                    _currentLevel = target - 1;
                    _isLoading = true;
                  });
                  _generatePuzzle();
                }
              },
              child: Text('Jump',
                  style: GoogleFonts.outfit(color: AppTheme.dustyMauve)),
            ),
          ],
        );
      },
    );
  }

  // COGNIQ-FIX:mod-active-helper
  bool _isModActive(String name) {
    if (_forcedModifier == name) return true;
    if (_playDailyMode) return _dailyModifierType == name;
    return _currentLevel >= RotationEngine.modifierStartLevel('hitori') &&
        _activeModifiers.contains(name);
  }

  // COGNIQ-FIX:mod-getters
  bool get _isEndgame => _isModActive('timer');
  bool get _isFogActive => _isModActive('fog');
  bool get _isZoomActive => _isModActive('zoom');

  // COGNIQ-FIX:mod-desc-copy
  String _getModifierDescription(String mod) {
    switch (mod) {
      case 'timer':
        return 'Eliminate duplicates before time runs out.';
      case 'fog':
        return 'A dense fog obscures portions of the grid.';
      case 'zoom':
        return 'Grid is magnified with pan-and-scan navigation.';
      default:
        return '';
    }
  }

  String get _modifierBannerText {
    if (_isSuccess) return '';
    if (_playDailyMode) {
      if (_dailyModifierDesc.isNotEmpty) return _dailyModifierDesc;
      if (_dailyModifierName.isNotEmpty) return _dailyModifierName;
      return '';
    }
    return _activeModifiers
        .map(_getModifierDescription)
        .where((d) => d.isNotEmpty)
        .join(' · ');
  }

  bool get _modsOn =>
      !_playDailyMode && RotationEngine.hasModifiers('hitori', _currentLevel);

  @override
  void dispose() {
    // Without this the countdown keeps calling setState on a disposed widget
    // once a second for the rest of the session.
    _gameTimer?.cancel();
    super.dispose();
  }

  void _generatePuzzle() {
    if (_modsOn) {
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'hitori',
        levelIndex: _currentLevel,
        pool: const ['timer', 'fog', 'zoom'],
        minActive: 1,
        maxActive: 2,
        smallGrid: _gridSize <= 4,
      );
      if (_forcedModifier != null) {
        _activeModifiers = {_forcedModifier!};
      }
    } else {
      _activeModifiers = {};
      if (_playDailyMode && _dailyModifierType.isNotEmpty) {
        _activeModifiers.add(_dailyModifierType);
      }
    }

    final board = HitoriLogic.generate(
      RotationEngine.getDeterminism('hitori', _currentLevel),
      _currentLevel,
    );

    _gridSize = board.size;
    _grid = board.values;
    _solution = board.solution;
    _shaded = List.filled(board.values.length, false);
    _markedWhite = List.filled(board.values.length, false);

    setState(() {
      _isSuccess = false;
      _isLoading = false;
    });

    _gameTimer?.cancel();
    if (_isEndgame) {
      // Pure time pressure: it cannot make a board unsolvable, and on expiry the
      // level restarts rather than being lost, matching Slitherlink and Untangle.
      _timeLeft = 60 + _gridSize * _gridSize * 2;
      _gameTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          if (_timeLeft > 0) {
            _timeLeft--;
          } else {
            t.cancel();
            _shaded = List.filled(_grid.length, false);
            _markedWhite = List.filled(_grid.length, false);
            _timeLeft = 60 + _gridSize * _gridSize * 2;
            _gameTimer = null;
          }
        });
        if (_timeLeft == 0) _generatePuzzle();
      });
    } else {
      _timeLeft = -1;
    }
  }


  bool _hasAdjacentShaded(List<bool> mask, int idx) {
    int r = idx ~/ _gridSize;
    int c = idx % _gridSize;
    // Check Left
    if (c > 0 && mask[idx - 1]) return true;
    // Check Right
    if (c < _gridSize - 1 && mask[idx + 1]) return true;
    // Check Up
    if (r > 0 && mask[idx - _gridSize]) return true;
    // Check Down
    if (r < _gridSize - 1 && mask[idx + _gridSize]) return true;
    return false;
  }

  bool _isFullyConnected(List<bool> mask) {
    final totalCells = mask.length;
    int start = -1;
    for (int i = 0; i < totalCells; i++) {
      if (!mask[i]) {
        start = i;
        break;
      }
    }
    if (start == -1) return false;

    List<bool> visited = List.filled(totalCells, false);
    List<int> queue = [start];
    visited[start] = true;
    int count = 1;

    int qHead = 0;
    while (qHead < queue.length) {
      int idx = queue[qHead++];
      int r = idx ~/ _gridSize;
      int c = idx % _gridSize;

      // Neighbors
      final neighbors = <int>[];
      if (c > 0) neighbors.add(idx - 1);
      if (c < _gridSize - 1) neighbors.add(idx + 1);
      if (r > 0) neighbors.add(idx - _gridSize);
      if (r < _gridSize - 1) neighbors.add(idx + _gridSize);

      for (final n in neighbors) {
        if (!mask[n] && !visited[n]) {
          visited[n] = true;
          queue.add(n);
          count++;
        }
      }
    }

    int totalUnshaded = mask.where((shaded) => !shaded).length;
    return count == totalUnshaded;
  }



  bool _checkHitoriRules(List<int> board, List<bool> mask) {
    // 1. Shaded adjacency check
    for (int i = 0; i < mask.length; i++) {
      if (mask[i]) {
        if (_hasAdjacentShaded(mask, i)) return false;
      }
    }

    // 2. Connectivity check
    if (!_isFullyConnected(mask)) return false;

    // 3. Row/Col duplicates check (no duplicates in unshaded cells)
    for (int r = 0; r < _gridSize; r++) {
      final seen = <int>{};
      for (int c = 0; c < _gridSize; c++) {
        int idx = r * _gridSize + c;
        if (!mask[idx]) {
          if (seen.contains(board[idx])) return false;
          seen.add(board[idx]);
        }
      }
    }

    for (int c = 0; c < _gridSize; c++) {
      final seen = <int>{};
      for (int r = 0; r < _gridSize; r++) {
        int idx = r * _gridSize + c;
        if (!mask[idx]) {
          if (seen.contains(board[idx])) return false;
          seen.add(board[idx]);
        }
      }
    }

    return true;
  }

  void _checkSolution() {
    if (_checkHitoriRules(_grid, _shaded)) {
      settingsNotifier.hapticSuccess();
      _onLevelCleared();
    } else {
      settingsNotifier.hapticError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect solution! Ensure shaded cells do not touch orthogonally, all unshaded cells are connected, and no duplicates exist.'),
        ),
      );
    }
  }

  Future<void> _onLevelCleared() async {
    // Routed through the shared managers instead of hand-written prefs writes.
    // The old code kept a private `beta_level_hitori` key and incremented
    // `globalLevelClearedCount` itself, which bypasses the Zen split inside
    // HintManager.onLevelCleared — letting Zen clears farm Challenge-side trails
    // and achievements.
    if (!_playDailyMode) {
      await ProgressGuard.saveLevel('hitori', _currentLevel + 1, isDaily: false);
      await HintManager.onLevelCleared('hitori');
    }

    if (mounted) setState(() => _isSuccess = true);
  }

  void _nextLevel() {
    setState(() {
      _currentLevel++;
      _isLoading = true;
    });
    _generatePuzzle();
  }

  void _showHint() async {
    int hintCell = -1;
    for (int i = 0; i < _shaded.length; i++) {
      if (_shaded[i] != _solution[i]) {
        hintCell = i;
        break;
      }
    }

    if (hintCell != -1) {
      final hints = await HintManager.getHints('hitori');
      if (hints > 0) {
        await HintManager.useHint('hitori');
        setState(() {
          _shaded[hintCell] = _solution[hintCell];
          _markedWhite[hintCell] = !_solution[hintCell];
        });
      } else {
        BuyHintsDialog.show(context, initialGameId: 'hitori', onPurchaseComplete: () {
          setState(() {});
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The board matches correct solution!')),
      );
    }
  }

  void _toggleCellState(int idx) {
    settingsNotifier.hapticTap();
    setState(() {
      if (!_shaded[idx] && !_markedWhite[idx]) {
        // Normal -> Shaded
        _shaded[idx] = true;
      } else if (_shaded[idx]) {
        // Shaded -> Marked White
        _shaded[idx] = false;
        _markedWhite[idx] = true;
      } else {
        // Marked White -> Normal
        _markedWhite[idx] = false;
      }
    });
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text(
          'How to Play Hitori',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        content: Text(
          '1. Shade duplicate numbers in rows and columns so each remains unique.\n\n'
          '2. Shaded (black) cells cannot touch horizontally or vertically.\n\n'
          '3. All unshaded (white) cells must connect in a single continuous group.\n\n'
          '💡 Tap cells to toggle states: White ➔ Shaded ➔ Keep Circle.',
          style: GoogleFonts.outfit(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style: GoogleFonts.outfit(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.bgDark,
        body: const Center(child: CircularProgressIndicator(color: AppTheme.dustyMauve)),
      );
    }

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        title: const GameTitle('Hitori'),
        leading: IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppTheme.dustyMauve),
            tooltip: 'Instructions',
            onPressed: _showInstructions,
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline, color: AppTheme.dustyMauve),
            tooltip: 'Hint',
            onPressed: _showHint,
          ),
          // Standard level indicator, last in actions. Nothing else on screen
          // may show the level (remember.md E2 section 7).
          GameLevelChip(
            level: _currentLevel + 1,
            modeLabel: _playDailyMode ? 'Daily' : null,
            accent: AppTheme.accentFor('hitori'),
            onTap: kDebugMode ? _showJumpToLevelDialog : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      // Size the board from the box this column is ACTUALLY
                      // handed — the app bar, the 16px padding and the button
                      // row are already subtracted from it — rather than
                      // re-deriving it from MediaQuery. Two bugs came out of
                      // guessing at that arithmetic:
                      //
                      //  * `width * 0.85` alone (shipped in 2.0) overflowed a
                      //    wide-short window by 908px: a square sized off a
                      //    1568px width cannot fit in a 696px height.
                      //  * The `height - 320` reserve that replaced it still
                      //    overflowed by 106px at 320x568, because the chrome
                      //    is not a constant. Measured: at 320 wide the hint
                      //    line wraps to 4 rows (80px) and the tap-cycle card
                      //    to 9 rows (162px), so board + gaps + text needs
                      //    538px of the 432px available; at 412 wide the same
                      //    two shrink to 60px and ~110px. No single pixel
                      //    reserve is right for both, and a running modifier
                      //    only adds more chrome.
                      //
                      // So: cap the square at a *fraction* of the height it can
                      // actually see (a ratio scales with the viewport, a pixel
                      // reserve does not), and let the column scroll when the
                      // text below it does not fit. The scroll view is what
                      // makes an overflow structurally impossible here; the
                      // ratio only decides how much of the guide card is
                      // readable before you scroll. Board sizes come out at
                      // 288 / 380 / 448 / 392 across the four tested viewports,
                      // every one of them larger than before, so nothing got
                      // less legible to buy the fix.
                      final double boardSize =
                          min(box.maxWidth, box.maxHeight * 0.7);

                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          // Centred while it fits, scrollable once it does not.
                          constraints: BoxConstraints(minHeight: box.maxHeight),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_modifierBannerText.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Text(
                                    _modifierBannerText,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.dustyMauve.withOpacity(0.9),
                                    ),
                                  ),
                                ),
                              ],
                              if (_timeLeft >= 0) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: (_timeLeft <= 10
                                                ? AppTheme.terracotta
                                                : AppTheme.accentFor('hitori'))
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: (_timeLeft <= 10
                                                  ? AppTheme.terracotta
                                                  : AppTheme.accentFor('hitori'))
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Text(
                                        'Timer ${_timeLeft}s',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _timeLeft <= 10
                                              ? AppTheme.terracotta
                                              : AppTheme.accentFor('hitori'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 24),
                              // `zoom`: pan/zoom the board. Earns its place at
                              // 8x8, where cells and their numbers get small.
                              // Wrapping rather than replacing keeps every tap
                              // handler intact.
                              _ZoomWrap(
                                enabled: _isZoomActive,
                                child: RepaintBoundary(
                                  child: Container(
                                    width: boardSize,
                                    height: boardSize,
                                    decoration: BoxDecoration(
                                      color: context.bgCard,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: context.textMuted.withAlpha(40)),
                                    ),
                                    child: FogOverlay(
                                      enabled: _isFogActive,
                                      radius: (boardSize / _gridSize) * _dailyRadius,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: GridView.builder(
                                          physics: const NeverScrollableScrollPhysics(),
                                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: _gridSize,
                                          ),
                                          itemCount: _gridSize * _gridSize,
                                          itemBuilder: (context, idx) {
                                            final cellVal = _grid[idx];
                                            final isShaded = _shaded[idx];
                                            final isMarked = _markedWhite[idx];

                                            return Semantics(
                                              label: 'Cell row ${idx ~/ _gridSize + 1}, column ${idx % _gridSize + 1}. '
                                                  'Value $cellVal. '
                                                  '${isShaded ? "Shaded/Black" : isMarked ? "Marked to keep white" : "Unshaded"}.',
                                              child: GestureDetector(
                                                onTap: () => _toggleCellState(idx),
                                                child: AnimatedContainer(
                                                  duration: const Duration(milliseconds: 150),
                                                  decoration: BoxDecoration(
                                                    color: isShaded ? Colors.grey[900] : context.bgCard,
                                                    border: Border.all(
                                                      color: context.textMuted.withAlpha(40),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: Stack(
                                                      alignment: Alignment.center,
                                                      children: [
                                                        if (isMarked)
                                                          Container(
                                                            width: boardSize / (_gridSize * 1.5),
                                                            height: boardSize / (_gridSize * 1.5),
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              border: Border.all(
                                                                color: AppTheme.dustyMauve.withAlpha(160),
                                                                width: 2,
                                                              ),
                                                            ),
                                                          ),
                                                        Text(
                                                          "$cellVal",
                                                          style: GoogleFonts.spaceGrotesk(
                                                            fontSize: _gridSize == 4 ? 24 : 18,
                                                            fontWeight: FontWeight.bold,
                                                            color: isShaded
                                                                ? Colors.white30
                                                                : context.textPrimary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: context.bgCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: context.textMuted.withAlpha(20)),
                                ),
                                child: Text(
                                  '💡 Tap cycle guide:\n'
                                  '• First Tap: Shades the cell black.\n'
                                  '• Second Tap: Draws a circle helper (locks cell white).\n'
                                  '• Third Tap: Returns to default.',
                                  style: GoogleFonts.outfit(fontSize: 12, color: context.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Two 144.5px buttons need 289px; a 320px phone leaves 288px
                // between the paddings, which is where the 1px right overflow
                // came from — a striped bar in debug, a silent clip in release.
                // `Flexible` caps each button at its share of the row so it can
                // never push past the edge, and the narrower horizontal padding
                // means it does not have to: natural width drops to 128.5px, so
                // both still render at full size with room to spare at 320.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Flexible(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.bgCard,
                          foregroundColor: context.textPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: () {
                          setState(() {
                            _shaded = List.filled(_gridSize * _gridSize, false);
                            _markedWhite = List.filled(_gridSize * _gridSize, false);
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset', overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    Flexible(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.dustyMauve,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onPressed: _checkSolution,
                        icon: const Icon(Icons.check),
                        label: const Text('Check', overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isSuccess)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: Center(
                  child: _playDailyMode
                      ? ChallengeClearedOverlay(
                          accentColor: AppTheme.dustyMauve,
                          onComplete: () {
                            Navigator.pop(context, true);
                          },
                        )
                      : Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: context.bgCard,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
                              const SizedBox(height: 16),
                              Text(
                                'Level ${_currentLevel + 1} Cleared!',
                                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              AutoNextCountdown(
                                onNext: _nextLevel,
                                accentColor: AppTheme.dustyMauve,
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


/// Wraps the board in an [InteractiveViewer] only while the `zoom` modifier is
/// active, so the ordinary path carries no extra layers.
class _ZoomWrap extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const _ZoomWrap({required this.enabled, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 3.0,
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }
}
