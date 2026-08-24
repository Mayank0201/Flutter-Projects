import 'dart:async';
import 'dart:collection';

import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_event.dart';

/// A bounded, persisted ring buffer of events waiting to be delivered.
///
/// ---------------------------------------------------------------------------
/// WHY A BUFFER AT ALL
/// ---------------------------------------------------------------------------
/// Events are produced at moments when there is no backend to hand them to: on
/// a plane, in a tunnel, before the vendor SDK has finished initialising, and —
/// for the whole of release 2.0 — because no vendor has been chosen yet. The
/// buffer is what makes "record an event" a decision the call site can make
/// without knowing or caring about any of that.
///
/// ---------------------------------------------------------------------------
/// WHY BOUNDED, AND WHY DROP THE *OLDEST*
/// ---------------------------------------------------------------------------
/// An unbounded queue against a backend that never drains is a slow disk leak:
/// this app writes to `SharedPreferences`, whose Android implementation holds
/// the whole file in memory and rewrites it wholesale, so an unbounded list
/// degrades app startup permanently and silently. [maxEvents] caps it.
///
/// When full, the **oldest** event is dropped, not the newest. Both choices
/// lose data; only one loses the right data. Recent events describe the session
/// the player is in now and the app version they are on now, which is what any
/// question worth asking is about. Week-old events that have failed to deliver
/// for a week are the least valuable rows in the buffer.
///
/// ---------------------------------------------------------------------------
/// WHY WRITING IS DEFERRED (`md/remember.md` Section E, rule 5)
/// ---------------------------------------------------------------------------
/// [add] runs on the UI isolate, sometimes inside a gameplay callback. Section
/// E rule 5 forbids disk writes in those paths outright. So [add] does exactly
/// two things — JSON-encode a small map and push a string onto an in-memory
/// [ListQueue] — and then arms a timer. The `SharedPreferences` write happens
/// once per [flushDelay], no matter how many events arrived in between, and
/// rewrites the key in a single `setStringList` call.
///
/// Encoding happens at [add] time rather than at flush time on purpose: it
/// spreads a microsecond of work across many frames instead of concentrating
/// the encode of the entire buffer into the one frame that flushes. It also
/// means [flush] passes an already-built `List<String>` straight through with
/// no transformation.
///
/// The queue is a [ListQueue] rather than a `List` so that both the push and
/// the drop-oldest are O(1); with a plain list the drop would be an O(n) shift
/// on every single event once the buffer is full.
///
/// This class is a static singleton to match the convention used by
/// `HintManager`, `PointManager` and `ZenMode`.
class LocalBuffer {
  LocalBuffer._();

  /// `SharedPreferences` key holding the encoded pending events.
  ///
  /// Declared here rather than in `PrefsKeys` only because that file is owned
  /// by another workstream this release; the string value is final and should
  /// be moved to `PrefsKeys.analyticsPendingEvents` verbatim.
  static const String prefsKeyPendingEvents = 'analytics_pending_events';

  /// `SharedPreferences` key holding the schema version the buffer was written
  /// with. See [load] for why it exists. Destined for
  /// `PrefsKeys.analyticsBufferSchemaVersion`.
  static const String prefsKeyBufferSchemaVersion =
      'analytics_buffer_schema_version';

  /// Hard cap on pending events.
  ///
  /// 300 rows at roughly 110 bytes of JSON each is about 33 KB — small next to
  /// the progress data this app already keeps in `SharedPreferences`, and large
  /// enough to hold several days of ordinary play if delivery is failing.
  static const int maxEvents = 300;

  /// How long [add] waits before the buffer is written to disk.
  ///
  /// Long enough that a burst of events during a level clear (completed, points
  /// awarded, achievement, next level started) collapses into one write; short
  /// enough that a crash loses at most a few seconds of events. Mutable so
  /// tests can drive flushing deterministically.
  static Duration flushDelay = const Duration(seconds: 3);

  static final ListQueue<String> _pending = ListQueue<String>();
  static Timer? _flushTimer;
  static bool _loaded = false;

  /// Number of events currently held, in memory and on disk alike.
  static int get length => _pending.length;

  static bool get isEmpty => _pending.isEmpty;

  /// True once [load] has run. Before that the buffer refuses to write, so a
  /// caller that skipped [load] cannot clobber events persisted by the previous
  /// run of the app.
  static bool get isLoaded => _loaded;

  /// Restores the persisted buffer into memory. Call once during startup.
  ///
  /// Rows that fail to decode are dropped individually, and the whole buffer is
  /// discarded if it was written under a different schema version. Both are the
  /// same judgement: a handful of undeliverable analytics rows is worth nothing,
  /// and no amount of them is worth a crash at startup or a backend receiving
  /// payloads in a shape it cannot parse. Analytics must never be able to stop
  /// the app opening.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _pending.clear();

    final storedVersion = prefs.getInt(prefsKeyBufferSchemaVersion);
    if (storedVersion != null && storedVersion != AnalyticsEvent.schemaVersion) {
      await prefs.remove(prefsKeyPendingEvents);
      await prefs.setInt(
        prefsKeyBufferSchemaVersion,
        AnalyticsEvent.schemaVersion,
      );
      _loaded = true;
      return;
    }

    final raw = prefs.getStringList(prefsKeyPendingEvents) ?? const <String>[];
    for (final row in raw) {
      // Decoding here rather than trusting the row is what keeps a corrupted or
      // hand-edited prefs entry from being forwarded to a backend verbatim.
      if (AnalyticsEvent.tryDecode(row) != null) {
        _pending.add(row);
      }
    }
    _trim();
    _loaded = true;
  }

  /// Appends an event. Cheap by construction: one small `jsonEncode`, one
  /// O(1) queue push, one timer arm. No disk I/O on this path.
  ///
  /// This is intentionally *not* `Future`-returning. An awaitable append would
  /// invite call sites to `await` it inside gameplay callbacks, which is
  /// exactly the thing Section E rule 5 exists to prevent.
  static void add(AnalyticsEvent event) {
    _pending.add(event.encode());
    _trim();
    _scheduleFlush();
  }

  /// The pending events, decoded, oldest first. Used by delivery.
  ///
  /// Rows that no longer decode are skipped rather than surfaced, so a caller
  /// can never be handed a malformed event.
  static List<AnalyticsEvent> snapshot() {
    final out = <AnalyticsEvent>[];
    for (final row in _pending) {
      final event = AnalyticsEvent.tryDecode(row);
      if (event != null) out.add(event);
    }
    return out;
  }

  /// The raw encoded rows, oldest first. Mainly for diagnostics and tests.
  static List<String> rawSnapshot() => List<String>.unmodifiable(_pending);

  /// Drops the [count] oldest events after a sink has accepted them.
  ///
  /// Removing from the front by count rather than by identity is what makes
  /// delivery safe against events arriving mid-flight: anything recorded while
  /// the sink was awaiting sits behind the batch that was snapshotted, so it is
  /// untouched and delivered next time.
  static Future<void> acknowledge(int count) async {
    for (var i = 0; i < count && _pending.isNotEmpty; i++) {
      _pending.removeFirst();
    }
    await flush();
  }

  /// Writes the buffer to disk now and cancels any pending timer.
  ///
  /// Call this when the app is about to go to the background, and anywhere a
  /// guarantee of durability is wanted. Safe to call repeatedly.
  static Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (!_loaded) return;

    final prefs = await SharedPreferences.getInstance();
    if (_pending.isEmpty) {
      await prefs.remove(prefsKeyPendingEvents);
    } else {
      await prefs.setStringList(prefsKeyPendingEvents, _pending.toList());
    }
    await prefs.setInt(
      prefsKeyBufferSchemaVersion,
      AnalyticsEvent.schemaVersion,
    );
  }

  /// Erases every pending event from memory **and** from disk, immediately.
  ///
  /// This is the destructive half of withdrawing consent, so it does not defer
  /// anything to a timer: when a player turns analytics off, the data has to be
  /// gone before the settings screen finishes rebuilding, not three seconds
  /// later and not "at the next convenient flush". It also removes the key
  /// outright rather than storing an empty list, so nothing about the player
  /// survives in prefs at all.
  static Future<void> purge() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    _pending.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKeyPendingEvents);
    await prefs.remove(prefsKeyBufferSchemaVersion);
  }

  /// Returns the buffer to its pre-[load] state without touching prefs. Tests
  /// use it to simulate a process restart.
  static void resetForTesting() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _pending.clear();
    _loaded = false;
  }

  static void _trim() {
    while (_pending.length > maxEvents) {
      _pending.removeFirst();
    }
  }

  static void _scheduleFlush() {
    if (_flushTimer != null) return;
    _flushTimer = Timer(flushDelay, () {
      _flushTimer = null;
      // Fire and forget: the caller of `add` is a gameplay path that must not
      // wait on disk. A failure here costs at most the events since the last
      // successful flush, which is an acceptable price for never blocking a
      // frame — and `purge` does not rely on this path.
      unawaited(flush());
    });
  }
}
