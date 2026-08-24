import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/settings_manager.dart';
import '../../../utils/audio_manager.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/point_manager.dart';
import '../../../utils/prefs_keys.dart';
import '../../../utils/progress_guard.dart';
import '../../../utils/rotation_engine.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/buy_hints_dialog.dart';
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../widgets/game_level_chip.dart';
import 'lightbeam_logic.dart';

/// Light Beam — tap a cell to cycle a mirror, bend the beam onto every crystal.
///
/// Every rule, the reflection table, the generator and the hint live in
/// `lightbeam_logic.dart`, which has no Flutter imports and is covered by
/// `test/lightbeam_logic_test.dart`. This file is presentation and app plumbing
/// only; it must never re-implement a rule.
///
/// Performance notes (remember.md section E):
///  * Taps never call `setState`. `LightBeamGame` mutates in place and
///    [_boardRevision] is bumped; only the `ValueListenableBuilder` around the
///    board rebuilds, and it sits inside a `RepaintBoundary` so the app bar,
///    caption and footer are not dirtied.
///  * The board asks "is this cell on the beam?" n² times per rebuild, so it
///    reads `LightBeamTrace.pathSet` — a `Set` — rather than scanning the path
///    list (rule 6). The trace itself is computed once per mutation and cached
///    on the game.
///  * [_BeamPainter] has a real `shouldRepaint` and takes [_boardRevision] as
///    its `repaint` listenable (rule 3).
///  * Nothing is written to disk during a tap. The only disk writes happen on
///    level load and after a win.
class LightBeamScreen extends StatefulWidget {
  const LightBeamScreen({super.key});

  @override
  State<LightBeamScreen> createState() => _LightBeamScreenState();
}

class _LightBeamScreenState extends State<LightBeamScreen> {
  /// The game's accent.
  ///
  /// Hardcoded to the constant the handbook assigns Light Beam (**warmAmber**)
  /// only because `AppTheme.accentFor` has no `lightbeam` case yet — until that
  /// case exists it would fall through to the grey default. Once registration
  /// adds `case 'lightbeam': return warmAmber;`, swap this single line for
  /// `static final Color _accent = AppTheme.accentFor('lightbeam');`. Nothing
  /// else has to change — it is deliberately `final` rather than `const`, and no
  /// `const` widget in this file depends on it, so the swap really is one line.
  static final Color _accent = AppTheme.accentFor('lightbeam');

  final LightBeamGame _game = LightBeamGame();

  int _currentLevel = 0;
  bool _isLoading = true;
  bool _isSuccess = false;
  bool _playDailyMode = false;
  String _dailyModifierType = '';

  Set<String> _activeModifiers = {};
  Timer? _gameTimer;

  /// Seconds left under the `timer` modifier, or -1 when it is not active.
  ///
  /// A notifier rather than page state so the once-a-second tick rebuilds one
  /// small chip instead of the whole screen (remember.md section E, rule 4).
  final ValueNotifier<int> _timeLeft = ValueNotifier<int>(-1);

  /// Bumped whenever the board changes. Drives the board's builder and painter.
  final ValueNotifier<int> _boardRevision = ValueNotifier<int>(0);

  /// True when modifier [name] applies, in either daily or free-play mode.
  /// Mirrors the `_isModActive` helper the live games use so a modifier can
  /// never be selected by the pool yet silently do nothing.
  bool _isModActive(String name) {
    if (_playDailyMode) return _dailyModifierType == name;
    return _modsOn && _activeModifiers.contains(name);
  }

  bool get _modsOn =>
      !_playDailyMode && RotationEngine.hasModifiers('lightbeam', _currentLevel);

  @override
  void initState() {
    super.initState();
    _loadProgressAndGenerate();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _timeLeft.dispose();
    _boardRevision.dispose();
    super.dispose();
  }

  Future<void> _loadProgressAndGenerate() async {
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    _dailyModifierType =
        _playDailyMode ? (prefs.getString(PrefsKeys.dailyModifierType) ?? '') : '';

    // Mode-aware key: in Zen Mode this resolves to `zen_level_lightbeam`, which
    // is what keeps Zen a parallel progression (remember.md E2 section 13).
    // Never a hand-rolled 'lightbeam_level' string.
    final level = prefs.getInt(PrefsKeys.gameLevel('lightbeam')) ?? 0;

    if (!mounted) return;
    setState(() {
      _currentLevel = level;
      _isLoading = true;
    });
    _startLevel();
  }

  /// Debug-only level jump. `GameLevelChip` only wires this up when `kDebugMode`
  /// is true, so it is compiled out of release builds.
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
                  _startLevel();
                }
              },
              child: Text('Jump', style: GoogleFonts.outfit(color: _accent)),
            ),
          ],
        );
      },
    );
  }

  void _startLevel() {
    _gameTimer?.cancel();
    _timeLeft.value = -1;

    if (_modsOn) {
      // remember.md E2 section 8: everything in this pool must actually change
      // the level and be visible to the player. All three are implemented in
      // this file and shown in the modifier strip under the caption.
      //
      // Deliberately NOT listed: `quota`, `ratchet` and `momentum`. None of the
      // three exists anywhere in this codebase, and naming a modifier the screen
      // cannot apply is exactly the Sum Strike bug E2 section 8 records.
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'lightbeam',
        levelIndex: _currentLevel,
        // Three entries, not two. RotationEngine runs a singles tier then a
        // pairs tier; with only two entries the pairs tier has exactly one
        // combination and serves it for 35 straight levels, which
        // difficulty_curve_test fails as a flat run.
        pool: const ['timer', 'tightBudget', 'fog'],
        minActive: 1,
        maxActive: 2,
      );
    } else {
      _activeModifiers = {};
    }

    // Seeded, never a bare Random(): the same (gameId, level) must deal the same
    // board on every device and every replay, or saves and bug reports stop
    // being reproducible. Generation is replay-verified inside
    // LightBeamLogic.generate and is bounded (measured 116us per board), so it
    // cannot stall this frame.
    _game.generate(
      RotationEngine.getDeterminism('lightbeam', _currentLevel),
      _currentLevel,
    );

    // `tightBudget`: the spare mirror the opening levels grant is taken away, so
    // every placement has to be the right one. Clamped in the logic so it can
    // never drop below the solution length — a budget a perfect player cannot
    // meet is a broken level, not a hard one.
    if (_isModActive('tightBudget')) _game.tightenBudget();

    // The one place per level load that resets the no-hint-used flag.
    unawaited(HintManager.startLevel('lightbeam'));

    setState(() {
      _isSuccess = false;
      _isLoading = false;
    });
    _boardRevision.value++;

    if (_isModActive('timer')) {
      _timeLeft.value =
          40 + _game.n * 6 + (_game.board?.solutionMirrorCount ?? 0) * 12;
      _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_timeLeft.value > 0) {
          // No setState: only the countdown chip listens to this.
          _timeLeft.value--;
          return;
        }
        _timeLeft.value = 0;
        _gameTimer?.cancel();
        AudioManager.playFail();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Time is up! Restarting level...'),
            duration: Duration(seconds: 1),
          ),
        );
        _startLevel();
      });
    }
  }

  // ------------------------------------------------------------------ play

  /// The whole game loop. Deliberately free of `setState`: a tap changes the
  /// grid and nothing else, and the board listens to a notifier.
  void _tapCell(int r, int c) {
    if (_isSuccess || _isLoading) return;

    if (!_game.tapCell(r, c)) {
      // Refused: a crystal, a wall, a revealed mirror, or no budget left.
      settingsNotifier.hapticError();
      return;
    }

    settingsNotifier.hapticTap();
    AudioManager.playClick();
    _boardRevision.value++;

    if (_game.isWon) _onLevelCleared();
  }

  Future<void> _onLevelCleared() async {
    _gameTimer?.cancel();
    settingsNotifier.hapticSuccess();
    AudioManager.playSuccess();

    // Routed through the shared managers rather than writing prefs by hand.
    // HintManager.onLevelCleared is what decides whether a clear counts against
    // the Challenge tally or the Zen one. ProgressGuard.saveLevel is
    // forward-only and refuses to write during a daily challenge.
    if (!_playDailyMode) {
      await ProgressGuard.saveLevel('lightbeam', _currentLevel + 1,
          isDaily: false);
      await HintManager.onLevelCleared('lightbeam');
      // Base award is HintManager.onLevelCleared's own 10 points. The extra 5
      // that other games grant is a SPEED BONUS for beating the timer, not a
      // flat per-clear payment — so it is gated, not unconditional. Paying it
      // twice is what made two games over-reward a clear last release.
      if (_timeLeft.value > 0) {
        await PointManager.addPoints(5);
      }
    }

    if (mounted) setState(() => _isSuccess = true);
  }

  void _nextLevel() {
    setState(() {
      _currentLevel++;
      _isLoading = true;
    });
    _startLevel();
  }

  void _restart() {
    if (_isSuccess || _isLoading) return;
    _game.restart();
    _boardRevision.value++;
  }

  /// Reveals one solution mirror the player does not have right yet.
  ///
  /// It only ever adds or corrects — it never deletes a mirror that could still
  /// be part of a solution (remember.md E2 section 11) — and it is free: the
  /// revealed mirror does not spend a budget slot, and if it replaces a wrong
  /// guess the slot that guess was holding is refunded. A hint with nothing to
  /// offer is not charged for.
  Future<void> _showHint() async {
    if (_isSuccess || _isLoading) return;

    if (_game.nextHint() == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Every mirror is already where it needs to be.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final hints = await HintManager.getHints('lightbeam');
    if (!mounted) return;

    if (hints <= 0) {
      BuyHintsDialog.show(
        context,
        initialGameId: 'lightbeam',
        isFromGameScreen: true,
        onPurchaseComplete: () {
          if (mounted) setState(() {});
        },
      );
      return;
    }

    await HintManager.useHint('lightbeam');
    if (!mounted) return;

    // Re-check: awaiting the hint spend gave the player time to tap.
    if (!_game.applyHint()) return;
    AudioManager.playClick();
    _boardRevision.value++;

    if (_game.isWon) await _onLevelCleared();
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text(
          'How to Play Light Beam',
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        content: Text(
          '1. The lamp fires a beam across the grid.\n\n'
          '2. Tap an empty cell to place a mirror. Tap it again to flip it, and '
          'once more to take it away.\n\n'
          '3. A / mirror sends a beam travelling right upwards; a \\ mirror '
          'sends it down.\n\n'
          '4. The beam passes straight through crystals and lights them. Walls '
          'swallow it.\n\n'
          '5. Light every crystal without running out of mirrors.',
          style: GoogleFonts.outfit(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style:
                  GoogleFonts.outfit(color: _accent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.bgDark,
        body: Center(child: CircularProgressIndicator(color: _accent)),
      );
    }

    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: const GameTitle('Light Beam'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: _accent),
            tooltip: 'Instructions',
            onPressed: _showInstructions,
          ),
          IconButton(
            icon: Icon(Icons.lightbulb_outline, color: _accent),
            tooltip: 'Hint',
            onPressed: _showHint,
          ),
          // The countdown deliberately does NOT live here. Two icon buttons, a
          // timer and the level chip overflow the app bar on a 320px phone, so
          // the clock sits in the modifier strip instead — beside the "Timer"
          // chip that explains where it came from.
          //
          // The standard level indicator — must be the LAST action, and nothing
          // else on the screen may show the level. See remember.md E2 section 7.
          GameLevelChip(
            level: _currentLevel + 1,
            modeLabel: _playDailyMode ? 'Daily' : null,
            accent: _accent,
            onTap: kDebugMode ? _showJumpToLevelDialog : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  Text(
                    'Bend the beam onto every crystal.',
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: context.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  if (_activeModifierLabels.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildModifierStrip(context),
                  ],
                  const SizedBox(height: 8),
                  Expanded(child: _buildBoard(context)),
                  const SizedBox(height: 8),
                  _buildFooter(context),
                ],
              ),
            ),
          ),
          if (_isSuccess) _buildWinOverlay(context),
        ],
      ),
    );
  }

  /// Active modifiers, as `(icon, label)` pairs. Every entry here is applied by
  /// this file — nothing is announced that the screen does not do.
  List<(IconData, String)> get _activeModifierLabels => [
        if (_isModActive('timer')) (Icons.timer_outlined, 'Timer'),
        if (_isModActive('tightBudget'))
          (Icons.filter_center_focus, 'Exact Mirrors'),
        if (_isModActive('fog')) (Icons.blur_on, 'Beam Fog'),
      ];

  Widget _buildModifierStrip(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        for (final (icon, label) in _activeModifierLabels)
          if (label == 'Timer')
            // The countdown lives inside the chip, so the modifier and its
            // effect are the same object on screen.
            ValueListenableBuilder<int>(
              valueListenable: _timeLeft,
              builder: (context, seconds, child) => _modifierChip(
                icon,
                seconds >= 0 ? 'Timer  ${seconds}s' : 'Timer',
                urgent: seconds >= 0 && seconds <= 10,
              ),
            )
          else
            _modifierChip(icon, label),
      ],
    );
  }

  Widget _modifierChip(IconData icon, String label, {bool urgent = false}) {
    final color = urgent ? AppTheme.terracotta : _accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ board

  /// The corridor the player is allowed to see.
  ///
  /// `fog` hides the beam past its first bounce: crystals still light up, so the
  /// feedback loop is intact, but the player has to march the rest of the ray in
  /// their head instead of reading it off the screen. That is a harder version
  /// of the thing this game is *about*, which is what remember.md section D3
  /// asks a modifier to be.
  Set<(int, int)> _visibleCorridor(LightBeamTrace beam, bool fog) {
    if (!fog || beam.firstBounce < 0) return beam.pathSet;
    final bounceCell = beam.corners[beam.firstBounce];
    final visible = <(int, int)>{};
    for (final cell in beam.path) {
      visible.add(cell);
      if (cell == bounceCell) break;
    }
    return visible;
  }

  Widget _buildBoard(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = _game.n;
        // Square board, sized to the shorter axis, with a half-cell gutter for
        // the lamp. Everything is derived from `cell`, so the painter's polyline
        // and the cell widgets can never drift apart.
        final side = min(constraints.maxWidth, constraints.maxHeight);
        final cell = side / (n + 1.4);
        final margin = cell * 0.7;

        // RepaintBoundary keeps beam animations from dirtying the app bar,
        // caption and footer (remember.md section E, rule 2).
        return RepaintBoundary(
          child: Center(
            child: ValueListenableBuilder<int>(
              valueListenable: _boardRevision,
              builder: (context, revision, child) {
                final beam = _game.beam;
                final fog = _isModActive('fog');
                final corridor = _visibleCorridor(beam, fog);
                final corners = fog && beam.firstBounce >= 0
                    ? beam.corners.sublist(0, beam.firstBounce + 1)
                    : beam.corners;

                return SizedBox(
                  width: side,
                  height: side,
                  child: Stack(
                    children: [
                      // 1. cell backgrounds — the glowing corridor
                      for (var r = 0; r < n; r++)
                        for (var c = 0; c < n; c++)
                          Positioned(
                            left: margin + c * cell,
                            top: margin + r * cell,
                            width: cell,
                            height: cell,
                            child: _buildCellBackground(
                              context,
                              r,
                              c,
                              onBeam: corridor.contains((r, c)),
                              lit: beam.lit.contains((r, c)),
                            ),
                          ),
                      // 2. the beam itself, over the cells but under the glyphs
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _BeamPainter(
                              corners: corners,
                              cell: cell,
                              margin: margin,
                              color: _accent,
                              repaint: _boardRevision,
                            ),
                          ),
                        ),
                      ),
                      // 3. glyphs and the tap targets
                      for (var r = 0; r < n; r++)
                        for (var c = 0; c < n; c++)
                          Positioned(
                            left: margin + c * cell,
                            top: margin + r * cell,
                            width: cell,
                            height: cell,
                            child: _buildCellContent(
                              context,
                              r,
                              c,
                              cell,
                              lit: beam.lit.contains((r, c)),
                            ),
                          ),
                      // 4. the lamp, in the gutter
                      _buildLamp(context, cell, margin, side),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCellBackground(
    BuildContext context,
    int r,
    int c, {
    required bool onBeam,
    required bool lit,
  }) {
    final isWall = _game.grid[r][c] == LightBeamCell.block;
    final isCrystal = _game.crystals.contains((r, c));

    // Blended rather than layered so the AnimatedContainer has one flat colour
    // to tween between, and so the tint reads the same on linen and on charcoal.
    Color fill = context.bgSurface;
    if (isWall) {
      fill = Color.alphaBlend(context.textMuted.withAlpha(120), context.bgSurface);
    } else if (lit) {
      fill = Color.alphaBlend(_accent.withAlpha(110), context.bgSurface);
    } else if (onBeam) {
      fill = Color.alphaBlend(_accent.withAlpha(46), context.bgSurface);
    }

    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isCrystal && lit
                ? _accent
                : context.textMuted.withAlpha(isWall ? 0 : 70),
            width: isCrystal && lit ? 2 : 1,
          ),
        ),
      ),
    );
  }

  Widget _buildCellContent(
    BuildContext context,
    int r,
    int c,
    double cell, {
    required bool lit,
  }) {
    final content = _game.grid[r][c];
    final isCrystal = _game.crystals.contains((r, c));
    final isLocked = _game.lockedCells.contains((r, c));

    Widget? glyph;
    if (isCrystal) {
      glyph = Icon(
        Icons.diamond_outlined,
        key: ValueKey('lightbeam_crystal_${r}_$c'),
        size: cell * 0.55,
        color: lit ? context.bgDark : context.textSecondary,
      );
    } else if (content == LightBeamCell.slash ||
        content == LightBeamCell.backslash) {
      final isSlash = content == LightBeamCell.slash;
      glyph = Text(
        isSlash ? '/' : r'\',
        key: ValueKey(
            'lightbeam_${isSlash ? 'slash' : 'backslash'}_${r}_$c'),
        style: GoogleFonts.outfit(
          fontSize: cell * 0.62,
          height: 1.0,
          fontWeight: FontWeight.w700,
          // A revealed mirror is drawn in the accent so the player can tell
          // which ones the hint gave them and which ones they worked out.
          color: isLocked ? _accent : context.textPrimary,
        ),
      );
    }

    return GestureDetector(
      key: ValueKey('lightbeam_cell_${r}_$c'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _tapCell(r, c),
      child: Center(child: glyph ?? const SizedBox.shrink()),
    );
  }

  /// The lamp, drawn in the gutter on whichever edge the source sits outside.
  Widget _buildLamp(
      BuildContext context, double cell, double margin, double side) {
    final (sr, sc) = _game.source;
    final n = _game.n;
    double x, y;
    if (sc < 0) {
      x = margin * 0.5;
      y = margin + (sr + 0.5) * cell;
    } else if (sc >= n) {
      x = side - margin * 0.5;
      y = margin + (sr + 0.5) * cell;
    } else if (sr < 0) {
      x = margin + (sc + 0.5) * cell;
      y = margin * 0.5;
    } else {
      x = margin + (sc + 0.5) * cell;
      y = side - margin * 0.5;
    }

    final size = cell * 0.6;
    return Positioned(
      left: x - size / 2,
      top: y - size / 2,
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(size / 3),
        ),
        child: Icon(Icons.light_mode, size: size * 0.7, color: context.bgDark),
      ),
    );
  }

  // ----------------------------------------------------------------- footer

  Widget _buildFooter(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _boardRevision,
      builder: (context, revision, child) {
        final lit = _game.beam.lit.length;
        final total = _game.crystals.length;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Mirrors ${_game.mirrorsLeft} / ${_game.mirrorBudget}'
              '   ·   Crystals $lit / $total',
              style:
                  GoogleFonts.outfit(fontSize: 12, color: context.textSecondary),
            ),
            const SizedBox(height: 6),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.bgCard,
                foregroundColor: context.textPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _restart,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('Restart', style: GoogleFonts.outfit()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWinOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withAlpha(150),
        child: Center(
          child: _playDailyMode
              ? ChallengeClearedOverlay(
                  accentColor: _accent,
                  onComplete: () => Navigator.pop(context, true),
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
                      const Icon(Icons.emoji_events,
                          color: AppTheme.warmAmber, size: 56),
                      const SizedBox(height: 12),
                      Text(
                        'Every crystal lit in ${_game.taps} taps!',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      AutoNextCountdown(
                        onNext: _nextLevel,
                        accentColor: _accent,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// Draws the beam as a real polyline: a wide translucent stroke for the glow,
/// then a thin opaque core on top. Two `drawPath` calls, no shader, no blur —
/// which is what keeps it cheap enough to redraw on every tap.
class _BeamPainter extends CustomPainter {
  /// Source, every bounce, then the exit — in grid coordinates, which may be one
  /// cell outside the board at either end.
  final List<(int, int)> corners;
  final double cell;
  final double margin;
  final Color color;

  _BeamPainter({
    required this.corners,
    required this.cell,
    required this.margin,
    required this.color,
    required Listenable repaint,
  }) : super(repaint: repaint);

  Offset _at((int, int) p) =>
      Offset(margin + (p.$2 + 0.5) * cell, margin + (p.$1 + 0.5) * cell);

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length < 2) return;
    final path = Path();
    final start = _at(corners.first);
    path.moveTo(start.dx, start.dy);
    for (var i = 1; i < corners.length; i++) {
      final o = _at(corners[i]);
      path.lineTo(o.dx, o.dy);
    }

    final glow = Paint()
      ..color = color.withAlpha(64)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.30
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final core = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, glow);
    canvas.drawPath(path, core);
  }

  /// A real comparison, never `=> true` (remember.md section E, rule 3).
  @override
  bool shouldRepaint(_BeamPainter old) =>
      old.cell != cell ||
      old.margin != margin ||
      old.color != color ||
      !listEquals(old.corners, corners);
}
