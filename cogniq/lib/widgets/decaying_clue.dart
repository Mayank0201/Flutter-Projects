/// `decay` — "Fading Clues".
///
/// Every clue starts fully readable, holds for [kDecayHoldSeconds], then fades
/// to [kDecayFloorOpacity] over [kDecayFadeSeconds]. Tapping a faded clue
/// brings it back, but only for [kDecayRevealSeconds] — long enough to read,
/// not long enough to leave it up.
///
/// ## Two things the builder's handbook gets wrong here
///
/// 1. **It charges 5 points per re-reveal.** Points are the currency hints are
///    bought with. A clue fades every 25 seconds and a Kakuro board has dozens
///    of them, so an untimed level is an *unbounded* points sink — the mirror
///    image of the double-pay bug in `momentum`. Worse, the handbook ignores
///    `PointManager.consumePoints`'s return value, so a player with a full
///    balance is charged and a broke player re-reveals for free. There is no
///    points cost here at all: the cost is the short reveal window, plus two
///    seconds off the clock when the level is also timed, which is a cost the
///    game can actually meter.
/// 2. **Its code and its prose disagree.** The prose promises a 3-second
///    re-reveal; the code writes `_revealedAt[i] = _clock` and therefore hands
///    back the *full* 25-second hold. A re-reveal that restores the clue
///    permanently is not a modifier. The reveal schedule below is separate from
///    and much shorter than the opening one.
///
/// Never mutate the underlying clue value — only what is drawn.
library;

import 'dart:async';

/// Seconds a clue stays fully readable when the level starts.
const int kDecayHoldSeconds = 25;

/// Seconds a clue spends fading from full to [kDecayFloorOpacity].
const int kDecayFadeSeconds = 5;

/// Seconds a *re-revealed* clue stays fully readable.
const int kDecayRevealSeconds = 6;

/// Seconds a re-revealed clue spends fading back out.
const int kDecayRevealFadeSeconds = 2;

/// A faded clue never disappears completely — its position stays legible, so
/// the player can still find and tap it.
const double kDecayFloorOpacity = 0.15;

/// Seconds taken off the clock for a re-reveal on a timed level.
const int kDecayRevealTimeCostSeconds = 2;

/// Opacity of a clue that has been on screen for [secondsShown] seconds.
///
/// [wasRevealed] selects the short post-tap schedule instead of the long
/// opening one.
double decayClueOpacity({
  required int secondsShown,
  required bool wasRevealed,
}) {
  final hold = wasRevealed ? kDecayRevealSeconds : kDecayHoldSeconds;
  final fade = wasRevealed ? kDecayRevealFadeSeconds : kDecayFadeSeconds;
  if (secondsShown < hold) return 1.0;
  if (secondsShown >= hold + fade) return kDecayFloorOpacity;
  final t = (secondsShown - hold) / fade;
  return 1.0 - (1.0 - kDecayFloorOpacity) * t;
}

/// Drives `decay` for one level: a one-second clock plus the per-clue reveal
/// times. Games keep the clue values themselves; this only says how faint each
/// one should be drawn.
class DecayController {
  /// Called on every tick and every reveal, so the host can repaint.
  final void Function() onChanged;

  DecayController({required this.onChanged});

  Timer? _tick;
  int _clock = 0;
  final Map<int, int> _revealedAt = {};

  /// Seconds since [start].
  int get clock => _clock;

  /// True while the clock is running.
  bool get isRunning => _tick != null;

  /// Begins a fresh level. Safe to call repeatedly — it never stacks timers.
  void start() {
    stop();
    _clock = 0;
    _revealedAt.clear();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      _clock++;
      onChanged();
    });
  }

  /// Stops the clock and restores every clue to full opacity.
  void stop() {
    _tick?.cancel();
    _tick = null;
    _clock = 0;
    _revealedAt.clear();
  }

  double opacityFor(int clueIndex) {
    if (!isRunning) return 1.0;
    final revealedAt = _revealedAt[clueIndex];
    return decayClueOpacity(
      secondsShown: _clock - (revealedAt ?? 0),
      wasRevealed: revealedAt != null,
    );
  }

  /// Whether [clueIndex] has faded far enough to be worth tapping.
  bool isFaded(int clueIndex) => opacityFor(clueIndex) < 0.9;

  /// Re-reveals [clueIndex]. Returns false — and charges nothing — when the
  /// clue was already readable, so a stray tap on a bright clue is free.
  bool reveal(int clueIndex) {
    if (!isRunning || !isFaded(clueIndex)) return false;
    _revealedAt[clueIndex] = _clock;
    onChanged();
    return true;
  }

  void dispose() {
    _tick?.cancel();
    _tick = null;
  }
}
