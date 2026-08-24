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
import '../../../widgets/pulse_vision.dart';
import 'sandsort_logic.dart';

/// Sand Sort's free-play modifier pool.
///
/// Exported so test/modifier_batch2_test.dart checks the pool the screen really
/// uses rather than a copy that can drift.
///
/// Three entries, not two. RotationEngine runs a singles tier then a pairs
/// tier; with only two entries the pairs tier has exactly one combination and
/// serves it for 35 straight levels — difficulty_curve_test caught that as 30
/// identical sets back to back. `heartbeat` makes it four, which gives the
/// pairs tier six combinations instead of three.
///
/// `quota` is here rather than `fog`. Fog was tried and removed: it reveals
/// roughly two tubes at a time, and Sand Sort is a planning puzzle where you
/// must compare tube contents before choosing a pour, so fog turned it into a
/// memory game.
///
/// `heartbeat` is deliberately the memory game fog was rejected for being — but
/// on the whole board at once and on a predictable rhythm, so it is a thing you
/// learn to play around rather than a randomly placed blindfold. It is safe to
/// pair with `monochrome` (shapes stay on the layers) and it earns its
/// difficulty from `timer`, which shares this pool.
const List<String> kSandSortModifierPool = [
  'timer',
  'monochrome',
  'quota',
  'heartbeat',
];

/// Sand Sort — tap a source tube, tap a destination, pour the top block.
///
/// Every rule, the generator, the solver and the hint live in
/// `sandsort_logic.dart`, which has no Flutter imports and is covered by
/// `test/sandsort_logic_test.dart`. This file is presentation and app plumbing
/// only; it must never re-implement a rule.
///
/// Performance notes (remember.md section E):
///  * Taps never call `setState`. Selection lives in [_selected] and board
///    mutations bump [_boardRevision]; only the `AnimatedBuilder` around the
///    tubes rebuilds, and it sits inside a `RepaintBoundary` so the app bar,
///    background and buttons are not dirtied.
///  * Nothing is written to disk during a pour. The only disk writes happen on
///    level load and after a win.
class SandSortScreen extends StatefulWidget {
  const SandSortScreen({super.key});

  @override
  State<SandSortScreen> createState() => _SandSortScreenState();
}

class _SandSortScreenState extends State<SandSortScreen> {
  /// The game's accent.
  ///
  /// Hardcoded to the constant the handbook assigns Sand Sort (**terracotta**)
  /// only because `AppTheme.accentFor` has no `sandsort` case yet — until that
  /// case exists it would fall through to the grey default. Once registration
  /// adds `case 'sandsort': return terracotta;`, swap this single line for
  /// `static final Color _accent = AppTheme.accentFor('sandsort');`. Nothing
  /// else has to change: no `const` widget depends on it.
  static final Color _accent = AppTheme.accentFor('sandsort');

  /// One entry per colour id. `SandSortLogic.colorsFor` is capped at 6 precisely
  /// because this list has six entries.
  static const List<Color> _sandColors = [
    AppTheme.terracotta,
    AppTheme.slateBlue,
    AppTheme.softSage,
    AppTheme.warmAmber,
    AppTheme.dustyMauve,
    AppTheme.roseGold,
  ];

  /// A distinct glyph per colour id, drawn on every layer in every mode.
  ///
  /// Colour-matching games are unplayable for a red/green colour-blind player if
  /// hue is the only signal, so the shape is always there — and it is what makes
  /// the `monochrome` modifier fair rather than cruel.
  static const List<IconData> _sandIcons = [
    Icons.circle,
    Icons.square,
    Icons.change_history,
    Icons.star,
    Icons.favorite,
    Icons.hexagon,
  ];

  final SandSortGame _game = SandSortGame();

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

  /// The tube the player picked up, or null. A `ValueNotifier` rather than page
  /// state so tapping a tube rebuilds the tubes and nothing else.
  final ValueNotifier<int?> _selected = ValueNotifier<int?>(null);

  /// Bumped whenever the tubes change. Drives the board's `AnimatedBuilder`.
  final ValueNotifier<int> _boardRevision = ValueNotifier<int>(0);

  /// Pours allowed under the `quota` modifier, or -1 when it is not active.
  ///
  /// Derived from the logic's exact optimum rather than from the level number:
  /// a level-99 board has a scramble depth of 78 but an optimal solution of only
  /// ~15-18 pours, so a level-derived budget would be meaninglessly generous.
  int _moveBudget = -1;

  /// The pair the last hint played, highlighted until the next tap. -1 = none.
  int _hintFrom = -1;
  int _hintTo = -1;

  /// True when modifier [name] applies, in either daily or free-play mode.
  /// Mirrors the `_isModActive` helper the live games use so a modifier can
  /// never be selected by the pool yet silently do nothing.
  bool _isModActive(String name) {
    if (_playDailyMode) return _dailyModifierType == name;
    return _modsOn && _activeModifiers.contains(name);
  }

  bool get _modsOn =>
      !_playDailyMode && RotationEngine.hasModifiers('sandsort', _currentLevel);

  /// `heartbeat`: the visible/hidden loop for the level on screen.
  ///
  /// Flipping the phase bumps [_boardRevision] rather than calling `setState`,
  /// so a pulse repaints the tubes inside their `RepaintBoundary` and nothing
  /// else — the same rule the rest of this file follows.
  late final PulseController _pulse = PulseController(
    onChanged: () {
      if (mounted) _boardRevision.value++;
    },
    onReveal: settingsNotifier.hapticTap,
  );

  @override
  void initState() {
    super.initState();
    _loadProgressAndGenerate();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _pulse.dispose();
    _selected.dispose();
    _boardRevision.dispose();
    _timeLeft.dispose();
    super.dispose();
  }

  Future<void> _loadProgressAndGenerate() async {
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
    _dailyModifierType =
        _playDailyMode ? (prefs.getString(PrefsKeys.dailyModifierType) ?? '') : '';

    // Mode-aware key: in Zen Mode this resolves to `zen_level_sandsort`, which
    // is what keeps Zen a parallel progression (remember.md E2 section 13).
    // Never a hand-rolled 'sandsort_level' string.
    final level = prefs.getInt(PrefsKeys.gameLevel('sandsort')) ?? 0;

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
              child: Text('Jump',
                  style: GoogleFonts.outfit(color: _accent)),
            ),
          ],
        );
      },
    );
  }

  void _startLevel() {
    _gameTimer?.cancel();
    _timeLeft.value = -1;
    _selected.value = null;
    _hintFrom = -1;
    _hintTo = -1;
    _moveBudget = -1;

    if (_modsOn) {
      // remember.md E2 section 8: everything in this pool must actually change
      // the level and be visible to the player. All four are implemented in
      // this file and shown in the modifier strip under the caption. See
      // kSandSortModifierPool for why each one is there.
      //
      // Deliberately still NOT listed: `momentum`. Sand Sort has no per-move
      // notion of a correct action — a legal pour can be a setup move or a
      // blunder, and only the BFS solver knows which. Scoring a combo off
      // "legal pour" would pay the player for pouring back and forth.
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'sandsort',
        levelIndex: _currentLevel,
        // Four entries, not two. RotationEngine runs a singles tier then a pairs
        // tier; with only two entries the pairs tier has exactly one combination and
        // serves it for 35 straight levels — difficulty_curve_test caught that as 30
        // identical sets back to back.
        //
        // The third entry is `quota`, not `fog`. Fog was tried and removed: it
        // reveals roughly two tubes at a time, and Sand Sort is a planning puzzle
        // where you must compare tube contents before choosing a pour, so fog turned
        // it into a memory game. A move budget raises difficulty along the axis the
        // game is actually about, and the logic already computes the exact optimum.
        pool: kSandSortModifierPool,
        minActive: 1,
        maxActive: 2,
      );
    } else {
      _activeModifiers = {};
    }

    // Seeded, never a bare Random(): the same (gameId, level) must deal the same
    // board on every device and every replay, or saves, hints and bug reports
    // stop being reproducible. Generation is solver-verified inside
    // SandSortLogic.generate and is bounded, so it cannot stall this frame.
    _game.generate(
      RotationEngine.getDeterminism('sandsort', _currentLevel),
      _currentLevel,
    );

    // `quota`: a pour budget derived from the board's own optimum, not the level.
    // Generous early, tightening with level, but never below the optimum + 2 — a
    // budget a perfect player cannot meet is a broken level, not a hard one.
    if (_isModActive('quota')) {
      final slack = RotationEngine.getDecayValue(
          level: _currentLevel, start: 1.8, floor: 1.15, rate: 40);
      _moveBudget = (_game.optimalHint * slack).ceil().clamp(
            _game.optimalHint + 2,
            999,
          );
    }

    // The one place per level load that resets the no-hint-used flag.
    unawaited(HintManager.startLevel('sandsort'));

    setState(() {
      _isSuccess = false;
      _isLoading = false;
    });
    _boardRevision.value++;

    // `heartbeat`: start the pulse for the new board, or make sure it is off.
    if (_isModActive('heartbeat')) {
      _pulse.start();
    } else {
      _pulse.stop();
    }

    if (_isModActive('timer')) {
      _timeLeft.value = 45 + _game.tubes.length * 15;
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

  /// The whole game loop. Deliberately free of `setState`: a tap changes at most
  /// the selection and the tubes, and both are notifiers.
  void _tapTube(int t) {
    if (_isSuccess || _isLoading) return;

    final selected = _selected.value;

    if (selected == null) {
      if (_game.tubes[t].isEmpty) return; // nothing to pick up
      settingsNotifier.hapticTap();

    // Out of budget and not yet sorted: the level is lost. Checked after the
    // pour so a final pour that wins still counts.
    if (_moveBudget >= 0 && !_game.isWon && _game.pours >= _moveBudget) {
      _gameTimer?.cancel();
      AudioManager.playFail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Out of pours! Restarting level...'),
          duration: Duration(seconds: 1),
        ));
      }
      _startLevel();
      return;
    }
      _selected.value = t;
      return;
    }

    if (selected == t) {
      _selected.value = null; // tap again to put it back down
      return;
    }

    final moved = _game.pour(selected, t);
    if (moved == 0) {
      // Illegal: move the selection to the tapped tube instead of scolding the
      // player. Picking a new source is almost always what they meant.
      settingsNotifier.hapticError();
      _selected.value = _game.tubes[t].isEmpty ? null : t;
      return;
    }

    settingsNotifier.hapticTap();
    AudioManager.playClick();
    _hintFrom = -1;
    _hintTo = -1;
    _selected.value = null;
    _boardRevision.value++;

    if (_game.isWon) _onLevelCleared();
  }

  Future<void> _onLevelCleared() async {
    _gameTimer?.cancel();
    // The pulse must stop on the clear, not just on dispose, or it keeps
    // flipping the board and buzzing behind the win overlay.
    _pulse.stop();
    settingsNotifier.hapticSuccess();
    AudioManager.playSuccess();

    // Routed through the shared managers rather than writing prefs by hand.
    // Bumping `globalLevelClearedCount` here would break Zen accounting:
    // HintManager.onLevelCleared is what decides whether a clear counts against
    // the Challenge tally or the Zen one. ProgressGuard.saveLevel is
    // forward-only and refuses to write during a daily challenge.
    if (!_playDailyMode) {
      await ProgressGuard.saveLevel('sandsort', _currentLevel + 1, isDaily: false);
      await HintManager.onLevelCleared('sandsort');
      // Base award is HintManager.onLevelCleared's own 10 points. The extra 5 the
      // other games grant is a speed bonus for beating the timer, not a flat
      // per-clear payment — so it is gated, not unconditional.
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
    if (_isSuccess) return;
    _game.restart();
    _selected.value = null;
    _hintFrom = -1;
    _hintTo = -1;
    _boardRevision.value++;
  }

  /// Plays the first move of a *shortest* solution.
  ///
  /// `bestPour` is BFS-backed, so the distance to the goal drops by exactly one
  /// every time — tapping hint repeatedly always finishes the board and can
  /// never cycle. Nothing the player did is ever undone, and a hint that has no
  /// move to offer is not charged for (remember.md E2 section 11).
  Future<void> _showHint() async {
    if (_isSuccess || _isLoading) return;

    final pair = _game.bestPour();
    if (pair == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pour left to suggest — try Restart.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final hints = await HintManager.getHints('sandsort');
    if (!mounted) return;

    if (hints <= 0) {
      BuyHintsDialog.show(
        context,
        initialGameId: 'sandsort',
        isFromGameScreen: true,
        onPurchaseComplete: () {
          if (mounted) setState(() {});
        },
      );
      return;
    }

    await HintManager.useHint('sandsort');
    if (!mounted) return;

    // Re-check: awaiting the hint spend gave the player time to tap.
    if (!_game.canPour(pair.$1, pair.$2)) return;

    _hintFrom = pair.$1;
    _hintTo = pair.$2;
    _selected.value = null;
    _game.pour(pair.$1, pair.$2);
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
          'How to Play Sand Sort',
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        content: Text(
          '1. Tap a tube to pick up its top block of sand, then tap another '
          'tube to pour it.\n\n'
          '2. Sand only pours onto matching sand, or into an empty tube.\n\n'
          '3. Every layer of the same colour touching the top moves together.\n\n'
          '4. You win when every tube is empty or filled with a single colour.\n\n'
          'Each colour also carries its own symbol, so you never have to rely on '
          'hue alone.',
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
        title: const GameTitle('Sand Sort'),
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
          // timer and the level chip overflow the app bar by 8px on a 320px
          // phone, so the clock sits in the modifier strip instead — beside the
          // "Timer" chip that explains where it came from.
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
                    'Tap a tube, then tap where the sand should go.',
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
        if (_isModActive('monochrome')) (Icons.filter_b_and_w, 'Monochrome'),
        if (_isModActive('quota')) (Icons.speed, 'Move Budget'),
        if (_isModActive('heartbeat'))
          (Icons.favorite_outline, 'Pulse Vision'),
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
    final color = urgent ? Colors.red : _accent;
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

  Widget _buildBoard(BuildContext context) {
    const double spacing = 12;
    const double runSpacing = 16;
    const double tubeW = 52;
    const double maxUnitH = 34;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tubeCount = _game.tubes.length;

        // How many tubes fit on one row, and therefore how many rows the Wrap
        // will produce. Computed rather than guessed so the layer height can be
        // shrunk to fit the rows that actually result.
        final perRow = ((constraints.maxWidth + spacing) ~/ (tubeW + spacing))
            .clamp(1, tubeCount);
        final rows = (tubeCount / perRow).ceil();

        var unitH = maxUnitH;
        final available = constraints.maxHeight - (rows - 1) * runSpacing;
        final tubeH = unitH * _game.capacity + 12;
        if (rows * tubeH > available) {
          unitH = ((available / rows - 12) / _game.capacity)
              .clamp(12.0, maxUnitH);
        }

        // RepaintBoundary keeps pour animations from dirtying the app bar,
        // background and footer (remember.md section E, rule 2).
        return RepaintBoundary(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_selected, _boardRevision]),
                  builder: (context, _) {
                    final selected = _selected.value;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: runSpacing,
                      alignment: WrapAlignment.center,
                      children: [
                        for (var t = 0; t < _game.tubes.length; t++)
                          _buildTube(context, t, tubeW, unitH, selected == t),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTube(
    BuildContext context,
    int t,
    double tubeW,
    double unitH,
    bool selected,
  ) {
    final tube = _game.tubes[t];
    final isHintSource = t == _hintFrom;
    final isHintTarget = t == _hintTo;
    final mono = _isModActive('monochrome');

    final Color borderColor = selected
        ? _accent
        : (isHintSource || isHintTarget)
            ? AppTheme.warmAmber
            : context.textMuted.withAlpha(90);

    return GestureDetector(
      key: ValueKey('sandsort_tube_$t'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _tapTube(t),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: tubeW,
        height: unitH * _game.capacity + 12,
        // The classic sort-game affordance: the picked-up tube lifts 8px.
        transform: Matrix4.translationValues(0, selected ? -8 : 0, 0),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: context.bgSurface,
          border: Border.all(
            color: borderColor,
            width: selected || isHintSource || isHintTarget ? 2 : 1,
          ),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(8),
            bottom: Radius.circular(16),
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end, // sand settles at the bottom
          children: [
            for (var i = tube.length - 1; i >= 0; i--)
              _buildLayer(t, i, tube, unitH, mono),
          ],
        ),
      ),
    );
  }

  Widget _buildLayer(
    int t,
    int i,
    List<int> tube,
    double unitH,
    bool mono,
  ) {
    final colorId = tube[i];
    // `monochrome`: every layer is drawn in one neutral tone, so the shape on it
    // is the only way to tell colours apart. The shapes are always there, which
    // is what makes this a fair difficulty step rather than a punishment — and
    // what makes the game playable for a colour-blind player in every mode.
    final trueFill = mono ? context.textSecondary : _sandColors[colorId];
    final iconSize = min(15.0, (unitH - 4) * 0.55);

    // `heartbeat`: during the blank phase the layer is drawn as a flat
    // silhouette in the surface tone with no glyph. The layer keeps its exact
    // size and place, so the tube still shows how full it is and every tap
    // target is where it was — the player is playing from memory, not from a
    // moved board. The tube's *contents* are all that hide; `_game` is never
    // touched, so the solver, the hint and the win check are unaffected.
    final hidden = !_pulse.isVisible;
    final fill = hidden ? context.textMuted.withValues(alpha: 0.22) : trueFill;

    return AnimatedContainer(
      key: ValueKey('sandsort_layer_${t}_$i'),
      duration: const Duration(milliseconds: 180),
      height: unitH - 4,
      width: double.infinity,
      margin: const EdgeInsets.only(top: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(i == tube.length - 1 ? 6 : 2),
          bottom: Radius.circular(i == 0 ? 12 : 2),
        ),
      ),
      child: AnimatedOpacity(
        opacity: hidden ? 0 : 1,
        duration: kPulseFade,
        child: Icon(
          _sandIcons[colorId],
          size: iconSize,
          // Chosen against the sand fill, not the page background, so the glyph
          // stays legible on both the coloured and the monochrome palettes.
          color: trueFill.computeLuminance() > 0.5
              ? Colors.black.withAlpha(140)
              : Colors.white.withAlpha(150),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _boardRevision,
      builder: (context, revision, child) {
        final target = _game.optimalHint;
        final targetLabel = _game.optimalIsExact ? 'best $target' : 'about $target';
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _moveBudget >= 0
                  ? 'Pours: ${_game.pours} / $_moveBudget   ·   $targetLabel'
                  : 'Pours: ${_game.pours}   ·   $targetLabel',
              style: GoogleFonts.outfit(
                  fontSize: 12, color: context.textSecondary),
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
                        'Sorted in ${_game.pours} pours!',
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
