import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// `momentum` — "Combo Streak", the first reward-positive modifier.
///
/// Correct actions that land inside [MomentumController.window] of each other
/// chain a multiplier from x1 up to x5. Mistakes and idling break the chain.
/// On a clear the level pays a bonus on top of the normal award.
///
/// ## The points economy — read this before changing any of it
///
/// The builder's handbook says to "REPLACE `addPoints(10)`" on win with
/// `addPoints((10 * averageMultiplier).round())`. **There is no
/// `addPoints(10)` in any game screen to replace.** In this codebase:
///
///  * `HintManager.onLevelCleared` awards the flat base 10 (and 5 in Zen), from
///    one shared place used by all 22 games. A game screen cannot remove it.
///  * The `PointManager.addPoints(5)` that most screens do call is a *speed
///    bonus*, gated on `_timeLeft > 0 && _timeBonusEarned`. It is not the base
///    award and momentum must not swallow or multiply it.
///
/// So following the handbook literally pays `10 + 10 * avg` — the base plus a
/// full second award. Momentum therefore pays only the **difference above the
/// base**, [momentumBonusPoints], leaving the shared base and the speed bonus
/// exactly as they were.
///
/// A cleared level under momentum is worth:
///
///     10  (HintManager base)
///   +  0..40  (momentumBonusPoints, x1 pays nothing)
///   +  5  (speed bonus, only if the level was timed and beaten)
///
/// Zen pays 5 and no bonus: `RotationEngine.getActiveModifiers` returns nothing
/// in Zen, so `momentum` can never be active there. Daily challenges pay
/// through `DailyChallengeManager` and never call `HintManager.onLevelCleared`,
/// so hosts must gate the bonus on `!isDailyMode` too.
int momentumBonusPoints(double averageMultiplier) =>
    ((10 * averageMultiplier).round() - 10).clamp(0, 40);

/// Tracks the combo chain for one level.
///
/// Deliberately has no `Timer.periodic`: the only timer is a one-shot started
/// by [correct]/[mistake], so a screen that is merely rendered (the layout and
/// all-levels tests) never creates one and never leaves one pending.
class MomentumController {
  /// How close together two correct actions have to be to chain.
  final Duration window;

  /// Called whenever [multiplier] changes, so the host can rebuild the meter.
  final void Function() onChanged;

  /// Injectable clock so tests do not have to sleep.
  final DateTime Function() _clock;

  MomentumController({
    required this.onChanged,
    this.window = const Duration(seconds: 4),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  int _multiplier = 1;
  int _events = 0;
  int _multSum = 0;
  DateTime? _lastCorrect;
  Timer? _decay;
  bool _disposed = false;

  /// The live multiplier, 1..5.
  int get multiplier => _multiplier;

  /// Scored actions so far this level.
  int get events => _events;

  /// Mean multiplier across every scored action, 1.0 when nothing has happened.
  ///
  /// The handbook's version credits the *incremented* multiplier for the very
  /// first correct action, so a level with a single correct action — Odd Colour
  /// Out is exactly that — always averages 2.0 and always pays double. Here the
  /// first action of a chain scores x1 and only a *chained* action climbs, so a
  /// lone correct action is worth the base award and nothing more.
  double get averageMultiplier => _events == 0 ? 1.0 : _multSum / _events;

  /// The bonus this level has earned so far, in points.
  int get bonusPoints => momentumBonusPoints(averageMultiplier);

  /// Records a correct action.
  void correct() {
    if (_disposed) return;
    final now = _clock();
    final last = _lastCorrect;
    final chained = last != null && now.difference(last) <= window;
    _multiplier = chained ? (_multiplier + 1).clamp(1, 5) : 1;
    _lastCorrect = now;
    _events++;
    _multSum += _multiplier;
    _restartDecay();
    onChanged();
  }

  /// Records a mistake. It breaks the chain *and* scores as an x1 action, so a
  /// player cannot keep a high average by spraying wrong guesses between good
  /// ones.
  void mistake() {
    if (_disposed) return;
    _multiplier = 1;
    _lastCorrect = null;
    _events++;
    _multSum += 1;
    _decay?.cancel();
    onChanged();
  }

  /// Clears the chain without scoring anything — for a level restart.
  void reset() {
    _multiplier = 1;
    _events = 0;
    _multSum = 0;
    _lastCorrect = null;
    _decay?.cancel();
  }

  void _restartDecay() {
    _decay?.cancel();
    _decay = Timer(window, () {
      if (_disposed) return;
      _multiplier = 1;
      _lastCorrect = null;
      onChanged();
    });
  }

  void dispose() {
    _disposed = true;
    _decay?.cancel();
    _decay = null;
  }
}

/// The flame chip. Sized like every other modifier chip in the app — a fixed
/// 11px label, never a size that grows with the multiplier, because a chip that
/// grows is a chip that overflows the row it sits in.
class MomentumMeter extends StatelessWidget {
  final MomentumController controller;

  const MomentumMeter({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final m = controller.multiplier;
    // Heat rises with the multiplier, but only the fill does — never the size.
    final fill = AppTheme.warmAmber.withValues(alpha: 0.08 + 0.06 * m);
    final border = AppTheme.warmAmber.withValues(alpha: 0.30 + 0.10 * m);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department,
              size: 12, color: AppTheme.warmAmber),
          const SizedBox(width: 4),
          Text(
            'Combo  x$m',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              // warmAmber clears contrast on both the light linen and the dark
              // charcoal card, so one colour serves both themes.
              color: AppTheme.warmAmber,
            ),
          ),
        ],
      ),
    );
  }
}
