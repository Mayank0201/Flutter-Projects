/// `heartbeat` — "Pulse Vision".
///
/// The board's *contents* appear and disappear on a loop. Input keeps working
/// during the blank phase, so the modifier is a memory tax rather than a lock.
///
/// ## Where this differs from the builder's handbook
///
///  * **Rhythm.** The handbook proposes 1.5s visible against 2.5s hidden — the
///    board is gone 62% of the time. In a turn-based puzzle that does not make
///    the puzzle harder, it makes it *slower*: a patient player simply waits out
///    every blank phase for free. [kPulseVisible]/[kPulseHidden] tilt the loop
///    towards the visible phase so it reads as a pulse to play through rather
///    than a blackout to sit out. The modifier gets its real bite when the
///    rotation pairs it with `timer`, where waiting has a price — which is why
///    it is only ever pooled alongside one.
///  * **It never stops.** The handbook's `schedule()` re-arms itself with no
///    check for a finished level, so the loop — and its haptic tick — keeps
///    running after the win overlay is up. [stop] is called on clear here.
///  * **No second grid.** The handbook covers the board with a freshly built
///    ghost `GridView`. That is a whole extra layout pass every 4 seconds, and
///    it does not generalise to a board that is not a grid (Sand Sort's tubes
///    are a `Wrap`). Hosts here fade the contents *in place*, so the real
///    layout, hit testing and tap targets are untouched and the player can
///    still aim at the right tube or tile while it is blank.
library;

import 'dart:async';

/// How long the board's contents stay visible each cycle.
const Duration kPulseVisible = Duration(milliseconds: 1800);

/// How long they stay hidden each cycle.
const Duration kPulseHidden = Duration(milliseconds: 2200);

/// How long the fade between the two phases takes.
const Duration kPulseFade = Duration(milliseconds: 260);

/// Drives the visible/hidden loop for one level.
///
/// Uses a chain of one-shot timers rather than `Timer.periodic` so the two
/// phases can have different lengths. Nothing is scheduled until [start], so a
/// screen rendered on a level without the modifier never creates a timer.
class PulseController {
  /// Called on every phase flip so the host can rebuild.
  final void Function() onChanged;

  /// Called when the board becomes visible again, for a haptic tick. Optional
  /// so a host with no haptics does not have to pass anything.
  final void Function()? onReveal;

  final Duration visible;
  final Duration hidden;

  PulseController({
    required this.onChanged,
    this.onReveal,
    this.visible = kPulseVisible,
    this.hidden = kPulseHidden,
  });

  Timer? _timer;
  bool _running = false;
  bool _visible = true;

  /// True while the loop is going.
  bool get isRunning => _running;

  /// Whether the board's contents should be drawn right now.
  ///
  /// Always true when the loop is not running, so a host can read this
  /// unconditionally and get normal rendering on a level without `heartbeat`.
  bool get isVisible => !_running || _visible;

  /// Begins a fresh level. Safe to call repeatedly — it never stacks timers.
  void start() {
    stop();
    _running = true;
    _visible = true;
    _schedule();
  }

  /// Stops the loop and leaves the board fully visible. Call this on a clear as
  /// well as in dispose, or the pulse keeps flipping behind the win overlay.
  ///
  /// Deliberately does not fire [onChanged]: hosts call this from inside their
  /// own level-start and win paths, which already rebuild, and firing a
  /// `setState` from inside one is how you get a nested-build assertion.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    _visible = true;
  }

  void _schedule() {
    _timer = Timer(_visible ? visible : hidden, () {
      if (!_running) return;
      _visible = !_visible;
      onChanged();
      if (_visible) onReveal?.call();
      _schedule();
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }
}
