import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../zen_mode.dart';
import 'analytics_event.dart';
import 'analytics_sink.dart';
import 'local_buffer.dart';

export 'analytics_event.dart';
export 'analytics_sink.dart';

/// The one door analytics goes through.
///
/// Games and screens call the recorder methods on this class. They do not touch
/// [LocalBuffer], they do not touch an [AnalyticsSink], and they never check
/// whether the player consented — that check lives here, once, at [record].
///
/// ---------------------------------------------------------------------------
/// WHY CONSENT IS ENFORCED HERE AND NOWHERE ELSE
/// ---------------------------------------------------------------------------
/// The tempting alternative is `if (Analytics.isEnabled) Analytics.levelStarted(...)`
/// at each call site. That is a rule which must be remembered at every one of
/// dozens of call sites across sixteen games, forever, including in the game
/// somebody adds in 2.3 while copying an older screen that happened to have the
/// check inlined. It will be forgotten, and the failure mode is silent: data is
/// collected from a player who declined, and nothing looks wrong.
///
/// So [record] is the only place that can put an event into the buffer, and it
/// is the only place that reads consent. A call site that forgets the check is
/// harmless — the event is discarded here. Correctness does not depend on
/// anybody remembering anything.
///
/// The default is **off**. [_consentGranted] starts `false`, and it starts
/// `false` again on every launch until [initialize] has read the stored answer
/// from disk. Any event recorded during that window is dropped. Failing closed
/// costs a handful of startup events; failing open would mean collecting from
/// someone who said no.
///
/// ---------------------------------------------------------------------------
/// WHAT THIS CLASS COLLECTS, AND WHAT IT REFUSES TO
/// ---------------------------------------------------------------------------
/// The full, reviewable list is the doc comment at the top of
/// `analytics_event.dart` and it is the basis of the Play Console data-safety
/// declaration. In summary: game ids, level numbers, mode (`zen`/`challenge`),
/// durations in seconds, hint counts, our own product ids, and minute-resolution
/// timestamps. No names, no accounts, no device or advertising identifiers, no
/// location, no free text of any kind.
///
/// The single identifier that exists is [installId]:
///
/// * It is a **locally generated random UUID v4** from [Random.secure]. It is
///   derived from nothing — not the device, not the OS, not the install time,
///   not any hardware id. Two installs on the same phone produce unrelated
///   values, and the same install on two phones is impossible to correlate.
/// * It exists so a backend can tell "one player played 40 levels" from "40
///   players played one level each". Without it, every aggregate is unusable;
///   with it, nothing about a person is knowable.
/// * It is created **only when consent is granted**, and [setConsent] `false`
///   deletes it. Opting back in mints a brand-new one, so an opt-out is a real
///   break in continuity rather than a pause.
///
/// ---------------------------------------------------------------------------
/// THIS LAYER MAKES NO NETWORK CALLS
/// ---------------------------------------------------------------------------
/// Nothing under `lib/utils/analytics/` opens a socket, and no dependency was
/// added to `pubspec.yaml` for it. Events go to an in-memory queue backed by
/// `SharedPreferences`, and the default [AnalyticsSink] is [NoopSink]. The
/// app's zero-network property (`md/RELEASE_PLAN.md` §1) is unchanged by this
/// release. See `analytics_sink.dart` for how a backend is added later.
///
/// Static-class singleton to match `HintManager`, `PointManager` and `ZenMode`.
class Analytics {
  Analytics._();

  /// `SharedPreferences` key: has the player opted in? Absent means "not
  /// answered", which is treated as "no".
  ///
  /// These four keys live here rather than in `PrefsKeys` only because that
  /// file belongs to another workstream this release. The string values are
  /// final — move them to `PrefsKeys` verbatim.
  static const String prefsKeyConsentGranted = 'analytics_consent_granted';

  /// `SharedPreferences` key: has the first-run consent dialog been shown and
  /// answered? Kept separate from the answer itself so that "declined" and
  /// "never asked" are distinguishable — otherwise the dialog would reappear
  /// forever for anyone who said no.
  static const String prefsKeyConsentPromptSeen = 'analytics_consent_prompt_seen';

  /// `SharedPreferences` key: the locally generated install UUID. Written only
  /// while consent is granted, removed when it is withdrawn.
  static const String prefsKeyInstallId = 'analytics_install_id';

  /// The schema version this build produces. Mirrors
  /// [AnalyticsEvent.schemaVersion] so callers have one thing to import.
  static const int schemaVersion = AnalyticsEvent.schemaVersion;

  static bool _initialized = false;
  static bool _consentGranted = false;
  static bool _consentPromptSeen = false;
  static String? _installId;
  static AnalyticsSink _sink = const NoopSink();
  static int? _sessionStartMillis;

  /// Rebuild trigger for the Settings toggle, mirroring the pattern
  /// `ZenMode.enabledNotifier` uses.
  static final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(false);

  /// Whether the player has opted in. Read it for UI; do **not** use it to
  /// guard call sites — [record] already does.
  static bool get isEnabled => _consentGranted;

  static bool get isInitialized => _initialized;

  /// True when the first-run dialog still needs to be shown.
  static bool get needsConsentPrompt => _initialized && !_consentPromptSeen;

  /// The locally generated random install UUID, or `null` when there is no
  /// consent. Exposed to sinks; never placed inside an event payload.
  static String? get installId => _consentGranted ? _installId : null;

  /// The sink batches are delivered to. [NoopSink] until a backend is chosen.
  static AnalyticsSink get sink => _sink;

  /// Number of events waiting for delivery.
  static int get pendingCount => LocalBuffer.length;

  /// The mode the player is currently in.
  ///
  /// Derived from [ZenMode] here rather than passed by call sites, because a
  /// screen that hand-passes the mode will eventually pass the wrong one, and
  /// mixing the two progressions makes every level-level statistic meaningless
  /// (`md/remember.md` rule 13).
  static GameMode get currentMode =>
      ZenMode.isEnabled ? GameMode.zen : GameMode.challenge;

  /// Loads the stored consent answer and the pending buffer.
  ///
  /// Call once during startup, ideally after `ZenMode.initialize()`. Until this
  /// completes nothing is recorded, which is the fail-closed default described
  /// above.
  ///
  /// [sink] is optional; leaving it out keeps [NoopSink] and therefore keeps
  /// the app free of network calls.
  static Future<void> initialize({AnalyticsSink? sink}) async {
    if (sink != null) _sink = sink;

    final prefs = await SharedPreferences.getInstance();
    _consentGranted = prefs.getBool(prefsKeyConsentGranted) ?? false;
    _consentPromptSeen = prefs.getBool(prefsKeyConsentPromptSeen) ?? false;
    _installId = _consentGranted ? prefs.getString(prefsKeyInstallId) : null;

    // Defensive: an install id must never outlive consent. If a previous build
    // (or an interrupted opt-out) left one behind, drop it now rather than
    // carry an identifier for someone who has not agreed to one.
    if (!_consentGranted && prefs.containsKey(prefsKeyInstallId)) {
      await prefs.remove(prefsKeyInstallId);
    }

    await LocalBuffer.load();

    // Same reasoning one level up: if consent is off, whatever is on disk was
    // either written before an opt-out completed or by a downgraded build.
    // Either way it must not survive startup.
    if (!_consentGranted && !LocalBuffer.isEmpty) {
      await LocalBuffer.purge();
    }

    _initialized = true;
    enabledNotifier.value = _consentGranted;
  }

  /// Installs the sink a backend implements. See `analytics_sink.dart`.
  static void setSink(AnalyticsSink sink) => _sink = sink;

  /// Records the player's answer to the consent question.
  ///
  /// Granting mints a fresh random [installId] and records a single
  /// [ConsentGrantedEvent].
  ///
  /// Withdrawing **purges everything**: the pending buffer is erased from
  /// memory and from disk, and the install id is deleted, before this future
  /// completes. It does not merely stop future collection — data already
  /// gathered but not yet delivered is destroyed, because a player who turns
  /// this off has withdrawn permission for that data too, not just for the next
  /// event. The purge happens before the flag is written, so an opt-out that is
  /// interrupted mid-way leaves consent still granted with an empty buffer
  /// (recoverable) rather than consent withdrawn with data still on disk.
  static Future<void> setConsent(bool granted) async {
    final prefs = await SharedPreferences.getInstance();

    if (!granted) {
      await LocalBuffer.purge();
      await prefs.remove(prefsKeyInstallId);
      _installId = null;
      _sessionStartMillis = null;
    }

    _consentGranted = granted;
    _consentPromptSeen = true;
    await prefs.setBool(prefsKeyConsentGranted, granted);
    await prefs.setBool(prefsKeyConsentPromptSeen, true);

    if (granted) {
      _installId = prefs.getString(prefsKeyInstallId) ?? _generateInstallId();
      await prefs.setString(prefsKeyInstallId, _installId!);
      record(ConsentGrantedEvent());
    }

    enabledNotifier.value = granted;
  }

  /// Marks the first-run prompt as answered without changing the answer. For a
  /// "not now" affordance, should the dialog ever grow one.
  static Future<void> markConsentPromptSeen() async {
    _consentPromptSeen = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKeyConsentPromptSeen, true);
  }

  // -------------------------------------------------------------------------
  // the choke point
  // -------------------------------------------------------------------------

  /// The only path an event can take into the buffer.
  ///
  /// Synchronous and cheap on purpose — see [LocalBuffer.add]. Every guard the
  /// privacy story depends on is enforced right here:
  ///
  /// * not initialised → dropped (fail closed);
  /// * no consent → dropped;
  /// * a payload that could carry free text → asserts in debug and tests.
  static void record(AnalyticsEvent event) {
    if (!_initialized || !_consentGranted) return;
    assert(
      event.debugParametersAreSafe(),
      'Event ${event.name.wireName} carries a parameter that is not an int, '
      'a bool, or a sanitized token. See AnalyticsEvent.sanitizeToken.',
    );
    LocalBuffer.add(event);
  }

  // -------------------------------------------------------------------------
  // typed recorders — what call sites actually use
  // -------------------------------------------------------------------------

  /// A game screen was opened.
  static void gameOpened(String gameId) =>
      record(GameOpenedEvent(gameId: gameId, mode: currentMode));

  /// A level was presented. Pair with [levelCompleted] or [levelAbandoned].
  static void levelStarted(String gameId, int level) =>
      record(LevelStartedEvent(gameId: gameId, level: level, mode: currentMode));

  /// A level was solved. [durationMillis] is wall-clock time the level was
  /// open; it is reduced to whole seconds before it reaches the wire.
  static void levelCompleted(
    String gameId,
    int level, {
    required int durationMillis,
    int hintsUsed = 0,
  }) =>
      record(LevelCompletedEvent(
        gameId: gameId,
        level: level,
        mode: currentMode,
        durationMillis: durationMillis,
        hintsUsed: hintsUsed,
      ));

  /// A level was left unsolved.
  static void levelAbandoned(
    String gameId,
    int level, {
    required AbandonReason reason,
    int durationMillis = 0,
  }) =>
      record(LevelAbandonedEvent(
        gameId: gameId,
        level: level,
        mode: currentMode,
        reason: reason,
        durationMillis: durationMillis,
      ));

  /// A hint was spent.
  static void hintUsed(String gameId, int level) =>
      record(HintUsedEvent(gameId: gameId, level: level, mode: currentMode));

  /// A purchase moved through a lifecycle step. [productId] must be one of our
  /// own catalog ids — never a store order id or receipt.
  static void purchase(String productId, PurchaseStep step) =>
      record(PurchaseEvent(productId: productId, step: step));

  /// The app came to the foreground.
  ///
  /// The start time is remembered even when consent is off, because it is only
  /// an in-memory integer and nothing is recorded from it. That way a player
  /// who opts in mid-session still gets a truthful duration on [sessionEnded]
  /// instead of a zero.
  static void startSession() {
    _sessionStartMillis = DateTime.now().millisecondsSinceEpoch;
    record(SessionStartedEvent());
  }

  /// The app left the foreground. Records the session duration and flushes the
  /// buffer to disk, since the process may not get another chance.
  static Future<void> endSession() async {
    final start = _sessionStartMillis;
    _sessionStartMillis = null;
    if (start != null) {
      record(SessionEndedEvent(
        durationMillis: DateTime.now().millisecondsSinceEpoch - start,
      ));
    }
    await flush();
  }

  // -------------------------------------------------------------------------
  // delivery and durability
  // -------------------------------------------------------------------------

  /// Writes pending events to disk now. Call before backgrounding.
  static Future<void> flush() => LocalBuffer.flush();

  /// Offers the pending events to the current [sink] and, if it accepts,
  /// removes them from the buffer. Returns how many were handed over.
  ///
  /// Nothing calls this on a schedule yet — with [NoopSink] there would be no
  /// point. Whoever adds a backend wires it to a timer or to app resume; until
  /// then this method is what makes that wiring a one-liner.
  ///
  /// A sink that throws is treated as a failed delivery and the events are
  /// **kept**, because losing data to a buggy sink is worse than delivering it
  /// late. A sink that returns `false` (offline, throttled) is likewise a
  /// no-op: this is the whole of the offline-queuing behaviour the release plan
  /// asks for.
  static Future<int> deliverPending() async {
    if (!_initialized || !_consentGranted) return 0;
    final batch = LocalBuffer.snapshot();
    if (batch.isEmpty) return 0;

    bool accepted;
    try {
      accepted = await _sink.deliver(batch);
    } catch (_) {
      accepted = false;
    }
    if (!accepted) return 0;

    await LocalBuffer.acknowledge(batch.length);
    return batch.length;
  }

  /// A random UUID v4, generated locally from [Random.secure].
  ///
  /// Deliberately *not* derived from anything: no Android id, no vendor id, no
  /// MAC, no install timestamp, no seed the device could reproduce. It carries
  /// no information about the device or the person, which is the only reason it
  /// is acceptable to have an identifier at all. [Random.secure] rather than
  /// [Random] so two installs cannot collide through a predictable seed.
  static String _generateInstallId() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  /// Returns this class to its pre-[initialize] state without touching prefs,
  /// so a test can simulate a process restart.
  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    _consentGranted = false;
    _consentPromptSeen = false;
    _installId = null;
    _sessionStartMillis = null;
    _sink = const NoopSink();
    enabledNotifier.value = false;
    LocalBuffer.resetForTesting();
  }
}
