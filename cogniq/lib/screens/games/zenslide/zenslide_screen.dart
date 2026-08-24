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
import 'zenslide_logic.dart';

/// Zen Slide — swipe, and the sage stone glides until something stops it.
///
/// Every rule, the BFS solver, the generator and the hint live in
/// `zenslide_logic.dart`, which has no Flutter imports and is covered by
/// `test/zenslide_logic_test.dart`. This file is presentation and app plumbing
/// only; it must never re-implement a rule.
///
/// Performance notes (remember.md section E):
///  * **No `setState` in a gesture handler.** `onPanUpdate` accumulates into the
///    plain field [_dragTotal] — no rebuild at all while the finger is down —
///    and `onPanEnd` mutates [_game] and bumps [_boardRevision]. Only the
///    `ValueListenableBuilder` around the board rebuilds (rule 1).
///  * The board sits inside a `RepaintBoundary`, so the stone's glide never
///    dirties the app bar, the caption or the footer (rule 2).
///  * Everything that changes on a swipe is a `ValueNotifier`: [_boardRevision],
///    [_hintArrow] and [_timeLeft]. The once-a-second timer tick rebuilds one
///    chip, not the screen (rule 4).
///  * The grid asks "is this cell on the trail?" up to 56 times per rebuild, so
///    it reads `ZenSlideGame.trailSet` rather than scanning the trail list
///    (rule 6). Reachability is one BFS and is asked for once per rebuild, in
///    the footer — never per cell.
///  * Nothing is written to disk during a swipe. The only disk writes happen on
///    level load and after a win (rule 5).
///
/// Two defects in the handbook's screen sketch (§B5 5.5.2) are fixed here and
/// worth naming, because both are easy to reintroduce:
///
/// 1. It decides the swipe from `details.velocity` alone and returns early below
///    150 px/s. A slow, deliberate drag — how anyone plays a puzzle they are
///    thinking about — ends at roughly zero velocity and is silently thrown
///    away. [_onPanEnd] measures the distance the finger actually travelled and
///    only falls back to velocity for a flick that barely moved.
/// 2. It derives one `cellSize` from the width and uses it for both axes. Zen
///    Slide's boards are 5x5 through 8x7, so on a tall narrow phone that
///    overflows the bottom of the board and on a wide short window it wastes
///    most of the screen. [_buildBoard] takes `min(width / cols, height / rows)`.
class ZenSlideScreen extends StatefulWidget {
  const ZenSlideScreen({super.key});

  @override
  State<ZenSlideScreen> createState() => _ZenSlideScreenState();
}

class _ZenSlideScreenState extends State<ZenSlideScreen> {
  /// The game's accent.
  ///
  /// Hardcoded to the constant the handbook assigns Zen Slide (**softSage**)
  /// because `AppTheme.accentFor` has no `zenslide` case yet — until that case
  /// exists it would fall through to the grey default and the game would ship
  /// colourless. Once registration adds `case 'zenslide': return softSage;`,
  /// swap this single line for
  /// `static final Color _accent = AppTheme.accentFor('zenslide');`. Nothing
  /// else has to change: it is deliberately `final` rather than `const`, and no
  /// `const` widget in this file depends on it.
  static final Color _accent = AppTheme.accentFor('zenslide');

  /// The modifier pool. Three entries, not two.
  ///
  /// `RotationEngine` runs a singles tier and then a pairs tier; a two-entry
  /// pool gives the pairs tier exactly one combination, which it then serves for
  /// 35 straight levels — `test/difficulty_curve_test.dart` fails that as a flat
  /// run. Every entry here is implemented in this file and shown to the player
  /// in the modifier strip (remember.md E2 section 8).
  ///
  /// Deliberately NOT listed: `quota`, `ratchet` and `momentum`. Another
  /// workstream owns those three, and naming a modifier this screen cannot apply
  /// is exactly the Sum Strike bug E2 section 8 records.
  static const List<String> _modifierPool = ['timer', 'mirror', 'fog'];

  final ZenSlideGame _game = ZenSlideGame();

  int _currentLevel = 0;
  bool _isLoading = true;
  bool _isSuccess = false;
  bool _playDailyMode = false;
  String _dailyModifierType = '';

  Set<String> _activeModifiers = {};
  Timer? _gameTimer;
  Timer? _hintTimer;

  /// Grey stones the player has bumped into under `fog`, and which therefore
  /// stay on screen once discovered. Plain field, not state: it only ever
  /// changes inside a swipe, which already bumps [_boardRevision].
  final Set<int> _revealedStones = <int>{};

  /// Accumulated finger travel for the swipe in progress.
  ///
  /// A plain field precisely so `onPanUpdate` can run at 120Hz without touching
  /// `setState` (remember.md section E, rule 1).
  Offset _dragTotal = Offset.zero;

  /// Seconds left under the `timer` modifier, or -1 when it is not active.
  final ValueNotifier<int> _timeLeft = ValueNotifier<int>(-1);

  /// Bumped whenever the board changes. Drives the board and the footer.
  final ValueNotifier<int> _boardRevision = ValueNotifier<int>(0);

  /// The direction the hint is currently pointing, or null. Its own notifier so
  /// the arrow can appear and fade without rebuilding the grid.
  final ValueNotifier<ZenSlideDir?> _hintArrow = ValueNotifier<ZenSlideDir?>(null);

  /// The shortest finger travel that counts as a swipe, in logical pixels.
  static const double _minSwipeDistance = 18.0;

  /// The flick speed that counts even when the finger barely moved.
  static const double _minFlickVelocity = 220.0;

  /// True when modifier [name] applies, in either daily or free-play mode.
  bool _isModActive(String name) {
    if (_playDailyMode) return _dailyModifierType == name;
    return _modsOn && _activeModifiers.contains(name);
  }

  bool get _modsOn =>
      !_playDailyMode && RotationEngine.hasModifiers('zenslide', _currentLevel);

  @override
  void initState() {
    super.initState();
    _loadProgressAndGenerate();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _hintTimer?.cancel();
    _timeLeft.dispose();
    _boardRevision.dispose();
    _hintArrow.dispose();
    super.dispose();
  }

  Future<void> _loadProgressAndGenerate() async {
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    _dailyModifierType =
        _playDailyMode ? (prefs.getString(PrefsKeys.dailyModifierType) ?? '') : '';

    // Mode-aware key: in Zen Mode this resolves to `zen_level_zenslide`, which
    // is what keeps Zen a parallel progression (remember.md E2 section 13).
    // Never a hand-rolled 'zenslide_level' string.
    final level = prefs.getInt(PrefsKeys.gameLevel('zenslide')) ?? 0;

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
    _hintTimer?.cancel();
    _timeLeft.value = -1;
    _hintArrow.value = null;
    _dragTotal = Offset.zero;
    _revealedStones.clear();

    _activeModifiers = _modsOn
        ? RotationEngine.getActiveModifiers(
            gameId: 'zenslide',
            levelIndex: _currentLevel,
            pool: _modifierPool,
            minActive: 1,
            maxActive: 2,
          )
        : {};

    // Seeded, never a bare Random(): the same (gameId, level) must deal the same
    // board on every device and every replay, or saves and bug reports stop
    // being reproducible. Generation is solver-verified inside
    // ZenSlideLogic.generate and is bounded — measured worst case 1.8ms warm,
    // average well under 1ms, against a 150ms budget — so it cannot stall this
    // frame.
    _game.generate(
      RotationEngine.getDeterminism('zenslide', _currentLevel),
      _currentLevel,
    );

    // The one place per level load that resets the no-hint-used flag.
    unawaited(HintManager.startLevel('zenslide'));

    setState(() {
      _isSuccess = false;
      _isLoading = false;
    });
    _boardRevision.value++;

    if (_isModActive('timer')) {
      // Enough for one careful read of the board plus a few swipes per move the
      // solution needs. Scales with the puzzle rather than being a flat number,
      // so a nine-swipe board is not harsher than a three-swipe one.
      _timeLeft.value = 30 + _game.shortestSolve * 12;
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
            content: Text('Time is up! Resetting the ice...'),
            duration: Duration(seconds: 1),
          ),
        );
        _startLevel();
      });
    }
  }

  // ------------------------------------------------------------------- play

  /// Finger travel accumulator. Deliberately does no work beyond an addition —
  /// this runs on every pointer move.
  void _onPanUpdate(DragUpdateDetails details) => _dragTotal += details.delta;

  /// Turns the finished gesture into a swipe.
  ///
  /// Distance first, velocity second: the handbook's velocity-only test throws
  /// away every slow deliberate drag, which on a puzzle is most of them. A flick
  /// that covered almost no distance still counts, via the velocity fallback.
  void _onPanEnd(DragEndDetails details) {
    final travelled = _dragTotal;
    _dragTotal = Offset.zero;

    var gesture = travelled;
    if (gesture.distance < _minSwipeDistance) {
      final v = details.velocity.pixelsPerSecond;
      if (v.distance < _minFlickVelocity) return; // a tap or a twitch
      gesture = v;
    }

    final horizontal = gesture.dx.abs() > gesture.dy.abs();
    final dr = horizontal ? 0 : (gesture.dy > 0 ? 1 : -1);
    final dc = horizontal ? (gesture.dx > 0 ? 1 : -1) : 0;
    _onSwipe(dr, dc);
  }

  /// The whole game loop. Deliberately free of `setState`: a swipe changes the
  /// stone's cell and nothing else, and the board listens to a notifier.
  void _onSwipe(int dr, int dc) {
    if (_isSuccess || _isLoading) return;

    // `mirror`: the ice pushes back. The board is untouched — only the mapping
    // from gesture to direction is negated — so the puzzle and its solve
    // distance are exactly the same, which is why this can never make a level
    // unwinnable.
    final mirrored = _isModActive('mirror');
    final boardDr = mirrored ? -dr : dr;
    final boardDc = mirrored ? -dc : dc;

    if (!_game.swipe(boardDr, boardDc)) {
      // The stone was already flush against something. Not a mistake and not a
      // strike — just nothing to do.
      settingsNotifier.hapticError();
      _boardRevision.value++;
      return;
    }

    _revealNeighbouringStones();
    _hintArrow.value = null;
    _hintTimer?.cancel();
    settingsNotifier.hapticTap();
    AudioManager.playClick();
    _boardRevision.value++;

    if (_game.isWon) {
      unawaited(_onLevelCleared());
    }
  }

  /// Under `fog`, a grey the stone has come to rest against is remembered.
  ///
  /// This is what makes the modifier a discovery mechanic rather than a
  /// blindfold: the board teaches you where the greys are as you bump them, and
  /// what you learned stays on screen.
  void _revealNeighbouringStones() {
    final cols = _game.cols;
    final rows = _game.rows;
    final r = _game.stone ~/ cols;
    final c = _game.stone % cols;
    for (final (dr, dc) in ZenSlideLogic.directions) {
      final nr = r + dr;
      final nc = c + dc;
      if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
      final index = nr * cols + nc;
      if (_game.stones.contains(index)) _revealedStones.add(index);
    }
  }

  Future<void> _onLevelCleared() async {
    _gameTimer?.cancel();
    _hintTimer?.cancel();
    settingsNotifier.hapticSuccess();
    AudioManager.playSuccess();

    // Routed through the shared managers rather than writing prefs by hand.
    // HintManager.onLevelCleared is what decides whether a clear counts against
    // the Challenge tally or the Zen one. ProgressGuard.saveLevel is
    // forward-only and refuses to write during a daily challenge.
    if (!_playDailyMode) {
      await ProgressGuard.saveLevel('zenslide', _currentLevel + 1,
          isDaily: false);
      await HintManager.onLevelCleared('zenslide');
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
    _hintTimer?.cancel();
    _hintArrow.value = null;
    _dragTotal = Offset.zero;
    _revealedStones.clear();
    _game.restart();
    _boardRevision.value++;
  }

  /// Points at the first swipe of a shortest path from where the stone is now.
  ///
  /// It only ever *adds* information — there is no move to take away in this
  /// game — and it refuses to charge when it has nothing to offer: a player who
  /// has slid into a pocket the lotus cannot be reached from is sent to Restart
  /// for free (remember.md E2 section 11, "never charge for a hint that did not
  /// help").
  ///
  /// The arrow is drawn in the direction the player must **swipe**, so under
  /// `mirror` it is negated to match. A hint that tells you the truth about the
  /// board and lies about your finger is not a hint.
  Future<void> _showHint() async {
    if (_isSuccess || _isLoading) return;

    final direction = _game.hintDirection();
    if (direction == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The lotus cannot be reached from here — tap Restart.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final hints = await HintManager.getHints('zenslide');
    if (!mounted) return;

    if (hints <= 0) {
      BuyHintsDialog.show(
        context,
        initialGameId: 'zenslide',
        isFromGameScreen: true,
        onPurchaseComplete: () {
          if (mounted) setState(() {});
        },
      );
      return;
    }

    await HintManager.useHint('zenslide');
    if (!mounted) return;

    // Re-read: awaiting the hint spend gave the player time to swipe.
    final live = _game.hintDirection();
    if (live == null) return;
    final mirrored = _isModActive('mirror');
    _hintArrow.value = mirrored ? (-live.$1, -live.$2) : live;
    AudioManager.playClick();

    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) _hintArrow.value = null;
    });
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.bgCard,
        title: Text(
          'How to Play Zen Slide',
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        content: Text(
          '1. Swipe anywhere on the board. The sage stone glides that way — the '
          'floor is ice, so it does not stop until something stops it.\n\n'
          '2. It stops at the edge of the board, or just before a grey stone.\n\n'
          '3. The lotus catches it, so a stone sliding across the lotus comes to '
          'rest there.\n\n'
          '4. Grey stones never move. Getting the sage stone onto the lotus is '
          'the whole puzzle.\n\n'
          '5. If you glide somewhere you cannot get back from, tap Restart — it '
          'costs nothing.',
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
        title: const GameTitle('Zen Slide'),
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
          // The countdown deliberately does NOT live here — two icon buttons, a
          // clock and the level chip overflow the app bar on a 320px phone. It
          // sits in the modifier strip instead, beside the chip that explains
          // where it came from.
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
                    'Swipe to send the stone sliding. Land it on the lotus.',
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
        if (_isModActive('mirror')) (Icons.swap_horiz, 'Mirrored'),
        if (_isModActive('fog')) (Icons.blur_on, 'Icy Fog'),
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

  /// How far the player can see under `fog`, in cells (Chebyshev).
  int get _fogRadius => max(2, min(_game.rows, _game.cols) ~/ 2);

  /// Is this grey stone drawn?
  ///
  /// Without `fog`, always. With it: only when it is inside [_fogRadius] of the
  /// sage stone, or the player has already bumped into it.
  bool _greyIsVisible(int index, bool fog) {
    if (!fog) return true;
    if (_revealedStones.contains(index)) return true;
    final cols = _game.cols;
    final dr = (index ~/ cols) - (_game.stone ~/ cols);
    final dc = (index % cols) - (_game.stone % cols);
    return max(dr.abs(), dc.abs()) <= _fogRadius;
  }

  Widget _buildBoard(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rows = _game.rows;
        final cols = _game.cols;

        // Sized to whichever axis is tighter. The handbook's single
        // width-derived cellSize overflows vertically the moment rows != cols,
        // which for this game is most levels — and it wastes a wide short window
        // entirely.
        final cell = min(constraints.maxWidth / cols, constraints.maxHeight / rows);
        if (!cell.isFinite || cell <= 0) return const SizedBox.shrink();

        // RepaintBoundary keeps the stone's glide from dirtying the app bar,
        // caption and footer (remember.md section E, rule 2).
        return RepaintBoundary(
          child: Center(
            child: GestureDetector(
              key: const ValueKey('zenslide_board'),
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => _dragTotal = Offset.zero,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              onPanCancel: () => _dragTotal = Offset.zero,
              child: ValueListenableBuilder<int>(
                valueListenable: _boardRevision,
                builder: (context, revision, child) {
                  final fog = _isModActive('fog');
                  return SizedBox(
                    width: cell * cols,
                    height: cell * rows,
                    child: Stack(
                      children: [
                        // 1. the ice, the greys and the lotus
                        for (var r = 0; r < rows; r++)
                          for (var c = 0; c < cols; c++)
                            Positioned(
                              left: c * cell,
                              top: r * cell,
                              width: cell,
                              height: cell,
                              child: _buildCell(context, r, c, cell, fog),
                            ),
                        // 2. the sage stone, which glides rather than teleports
                        _buildStone(context, cell),
                        // 3. the hint arrow, over everything and inert
                        _buildHintArrow(context, cell),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell(BuildContext context, int r, int c, double cell, bool fog) {
    final index = r * _game.cols + c;
    final isTarget = index == _game.target;
    final isGrey = _game.stones.contains(index) && _greyIsVisible(index, fog);
    // O(1): the game keeps the trail as a Set beside the list precisely so this
    // is not a linear scan per cell per rebuild (remember.md section E, rule 6).
    final onTrail = !isTarget && !isGrey && _game.trailSet.contains(index);

    Color fill = context.bgSurface;
    if (isGrey) {
      fill = Color.alphaBlend(context.textMuted.withAlpha(160), context.bgSurface);
    } else if (isTarget) {
      fill = Color.alphaBlend(_accent.withAlpha(52), context.bgSurface);
    } else if (onTrail) {
      fill = Color.alphaBlend(_accent.withAlpha(22), context.bgSurface);
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(isGrey ? 6 : 8),
          border: Border.all(
            color: isTarget
                ? _accent
                : context.textMuted.withAlpha(isGrey ? 0 : 60),
            width: isTarget ? 2 : 1,
          ),
        ),
        child: isTarget
            ? Center(
                child: Icon(
                  Icons.spa_outlined,
                  key: const ValueKey('zenslide_lotus'),
                  size: cell * 0.5,
                  color: _accent,
                ),
              )
            : isGrey
                ? SizedBox.expand(
                    key: ValueKey('zenslide_grey_${r}_$c'),
                  )
                : null,
      ),
    );
  }

  /// The one widget that moves.
  ///
  /// `AnimatedPositioned` is `AnimatedContainer`'s sibling for `Positioned`:
  /// change left/top and it glides. `easeOutQuart` is fast then suddenly still,
  /// which is what reads as ice.
  Widget _buildStone(BuildContext context, double cell) {
    final r = _game.stone ~/ _game.cols;
    final c = _game.stone % _game.cols;
    return AnimatedPositioned(
      key: const ValueKey('zenslide_stone'),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutQuart,
      left: c * cell + cell * 0.14,
      top: r * cell + cell * 0.14,
      width: cell * 0.72,
      height: cell * 0.72,
      child: Container(
        decoration: BoxDecoration(
          color: _accent,
          shape: BoxShape.circle,
          boxShadow: AppTheme.cardShadow,
          border: Border.all(color: context.bgDark.withAlpha(60), width: 2),
        ),
        // The position key rides on an inner widget rather than on the
        // AnimatedPositioned: a changing key there would replace the widget and
        // kill the glide. Tests read the stone's cell off this.
        child: SizedBox.expand(
          key: ValueKey('zenslide_stone_at_${r}_$c'),
        ),
      ),
    );
  }

  Widget _buildHintArrow(BuildContext context, double cell) {
    return ValueListenableBuilder<ZenSlideDir?>(
      valueListenable: _hintArrow,
      builder: (context, dir, child) {
        if (dir == null) return const SizedBox.shrink();
        final r = _game.stone ~/ _game.cols;
        final c = _game.stone % _game.cols;
        final icon = switch (dir) {
          (-1, 0) => Icons.arrow_upward,
          (1, 0) => Icons.arrow_downward,
          (0, -1) => Icons.arrow_back,
          _ => Icons.arrow_forward,
        };
        return Positioned(
          left: c * cell,
          top: r * cell,
          width: cell,
          height: cell,
          child: IgnorePointer(
            child: Center(
              child: Icon(
                icon,
                key: const ValueKey('zenslide_hint_arrow'),
                size: cell * 0.55,
                color: context.bgDark,
              ),
            ),
          ),
        );
      },
    );
  }

  // ----------------------------------------------------------------- footer

  Widget _buildFooter(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _boardRevision,
      builder: (context, revision, child) {
        final stuck = _game.isStuck;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              stuck
                  ? 'The lotus is out of reach — restart to try another line.'
                  : 'Slides ${_game.moves}   ·   Best ${_game.shortestSolve}',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: stuck ? AppTheme.terracotta : context.textSecondary,
              ),
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
                        _game.moves <= _game.shortestSolve
                            ? 'Perfect line — ${_game.moves} slides!'
                            : 'Lotus reached in ${_game.moves} slides!',
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
