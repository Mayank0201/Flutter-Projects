import 'dart:convert';

/// The CogniQ analytics **taxonomy** — the closed set of things the app is ever
/// allowed to say about itself.
///
/// This file is pure Dart: no Flutter, no `SharedPreferences`, no I/O. That is
/// deliberate, because the taxonomy is the part that has to be reviewable in
/// isolation. A privacy reviewer (or the Play Console data-safety form) should
/// be able to read this one file and know the complete list of facts that can
/// leave the device, without also having to reason about buffering, consent or
/// transport.
///
/// ---------------------------------------------------------------------------
/// WHY A SEALED CLASS AND NOT `log(String name, Map params)`
/// ---------------------------------------------------------------------------
/// The obvious shape for an analytics API is a free-form `log(name, params)`.
/// Every project that ships one ends up with `level_complete`, `level_completed`
/// and `levelComplete` in the same dashboard within a quarter, and with a stray
/// `params['note'] = userTypedText` that nobody notices until a privacy audit.
///
/// So instead:
///
/// * [AnalyticsEvent] is `sealed`. The complete event list is the subclass list
///   below and the compiler enforces exhaustiveness in every `switch` over it —
///   adding an event forces every consumer to acknowledge it.
/// * Event names come from the [AnalyticsEventName] enum, never from a string
///   literal at a call site, so a typo cannot invent a new event.
/// * Every payload field is a typed constructor parameter. There is **no**
///   `Map<String, dynamic>` entry point, so there is no place for free text to
///   enter even by accident.
/// * Every string that does reach the wire is forced through [sanitizeToken],
///   which does not *clean* the input but **rejects** it: anything that is not
///   already a `[a-z0-9_]{1,40}` id is replaced wholesale by a constant. Even
///   if a caller passed a player-authored string, nothing of it survives — not
///   a slugified remnant, not a truncated prefix.
///
/// ---------------------------------------------------------------------------
/// WHAT IS COLLECTED (the basis of the data-safety declaration)
/// ---------------------------------------------------------------------------
/// Per event: a schema version, an event name from the enum below, a coarse
/// timestamp, and a handful of closed-vocabulary tokens and small integers:
///
/// * `game`   — a game id from `lib/models/game_info.dart` (e.g. `sandsort`).
/// * `level`  — the level index inside that game, an int.
/// * `mode`   — `challenge` or `zen`.
/// * `dur_s`  — an elapsed duration in whole seconds.
/// * `hints`  — how many hints were spent on a level, an int.
/// * `reason` — why a level ended, from [AbandonReason].
/// * `product`/`step` — an in-app product id from our own catalog and a
///   lifecycle step from [PurchaseStep].
///
/// ---------------------------------------------------------------------------
/// WHAT IS DELIBERATELY NOT COLLECTED
/// ---------------------------------------------------------------------------
/// * No name, email, account or any user identifier — the app has no accounts
///   and this layer must not be the thing that gives it one.
/// * No device id, IMEI, MAC, Android ID, advertising id, or any other
///   hardware- or OS-provided identifier.
/// * No IP-derived data, no coarse or fine location, no timezone, no locale.
/// * No free text of any kind: no guessed words, no puzzle contents, no
///   feedback strings, no exception messages, no stack traces.
/// * No screen/recording/heatmap capture, no contacts, no photos, no files.
/// * No cross-app or cross-device linkage of any kind.
/// * Timestamps are truncated to the minute (see [timestampMs]) so that an
///   event stream cannot be used as a millisecond-resolution behavioural
///   fingerprint.
///
/// The one identifier that exists at all is the install id described in
/// `analytics.dart` — a locally generated random UUID with no relationship to
/// the device. It is not part of an event payload; it belongs to the transport,
/// and it is destroyed the moment consent is withdrawn.
sealed class AnalyticsEvent {
  /// Wire schema version, stamped into **every** event.
  ///
  /// It travels with the event rather than being applied at the sink, because
  /// events can sit in the on-disk buffer across an app update: a payload
  /// written by 2.0 can be delivered by 2.1. Without a per-event stamp the
  /// backend would have to guess which shape it is looking at. The local buffer
  /// also uses it as a discard trigger (see `local_buffer.dart`).
  static const int schemaVersion = 1;

  /// Longest token the wire accepts. Long enough for every id in
  /// `lib/models/game_info.dart` and `lib/utils/iap_catalog.dart`, short enough
  /// that no sentence survives it.
  static const int maxTokenLength = 40;

  /// The shape every wire string must have after sanitising. Tests assert
  /// against this same pattern, so the guarantee and its check cannot drift.
  static final RegExp tokenPattern = RegExp(r'^[a-z0-9_]{1,40}$');

  /// What [sanitizeToken] substitutes for anything that is not already a valid
  /// token. A constant, so it carries exactly zero bits about the input.
  static const String invalidToken = 'invalid';

  AnalyticsEvent({int? timestampMs})
      : timestampMs = _truncateToMinute(
          timestampMs ?? DateTime.now().millisecondsSinceEpoch,
        );

  /// Unix epoch milliseconds, **truncated down to the whole minute**.
  ///
  /// Minute resolution is all any of the questions this taxonomy exists to
  /// answer actually need ("do people play in the evening", "how long is a
  /// session"). Millisecond timestamps, by contrast, are close to a unique
  /// fingerprint when a few of them are strung together, so the precision is
  /// dropped here at the source rather than promised away in a policy document.
  final int timestampMs;

  /// Which event this is. Comes from the enum, never from a literal.
  AnalyticsEventName get name;

  /// The typed payload, flattened for the wire.
  ///
  /// Implementations may only return `int`, `bool`, or a string that has been
  /// through [sanitizeToken]. Nothing else is representable, which is the whole
  /// point.
  Map<String, Object?> get parameters;

  /// Lowercases, and then **accepts or rejects**: a string that already matches
  /// [tokenPattern] passes through; anything else becomes [invalidToken].
  ///
  /// Every call site in this app passes an id straight out of
  /// `lib/models/game_info.dart` or `lib/utils/iap_catalog.dart`, so in practice
  /// this only lowercases. It exists for the call site that does not exist yet —
  /// the one that some day passes a player-authored string. This function is
  /// why "no free text" is a property of the code rather than a convention.
  ///
  /// It is an allow-list rather than a scrubber, and the difference is not
  /// academic. The obvious implementation slugifies: lowercase, swap disallowed
  /// characters for `_`, truncate. That produces a string matching
  /// [tokenPattern] and is therefore *shaped* safe while remaining perfectly
  /// readable — `Jane Doe <jane@example.com>` slugifies to
  /// `jane_doe_jane_example_com`, which is still a name and still a domain.
  /// Truncation does not help; it just shortens the leak. A scrubber that
  /// preserves the input's words has not removed the personal data, it has
  /// reformatted it.
  ///
  /// Rejecting outright is the only version with a guarantee behind it: the
  /// output is either a value that was already a legal id, or a fixed constant.
  /// The cost is that a future call site passing a malformed id loses that
  /// dimension — it shows up as `invalid` in the dashboard, which is loud,
  /// obvious and fixable. The alternative failure mode is quiet and shows up in
  /// a privacy audit instead.
  static String sanitizeToken(String raw) {
    final lowered = raw.toLowerCase();
    return tokenPattern.hasMatch(lowered) ? lowered : invalidToken;
  }

  /// Clamps a duration into a sane range and converts to whole seconds.
  ///
  /// A device clock can jump (manual change, NTP correction, timezone shift)
  /// while a level is open, which otherwise produces negative or century-long
  /// durations that poison every average downstream. 24 hours is far past any
  /// real puzzle session, so anything beyond it is clock noise, not data.
  static int sanitizeDurationSeconds(int rawMilliseconds) {
    const maxSeconds = 24 * 60 * 60;
    if (rawMilliseconds <= 0) return 0;
    final seconds = rawMilliseconds ~/ 1000;
    return seconds > maxSeconds ? maxSeconds : seconds;
  }

  /// Clamps a level index. Levels are never negative; the ceiling keeps a
  /// corrupted save from writing an absurd integer into the stream.
  static int sanitizeLevel(int raw) {
    if (raw < 0) return 0;
    return raw > 100000 ? 100000 : raw;
  }

  static int _truncateToMinute(int millis) {
    const minute = 60 * 1000;
    if (millis <= 0) return 0;
    return (millis ~/ minute) * minute;
  }

  /// The full wire form: version, name, coarse timestamp, payload.
  ///
  /// Short keys (`v`/`n`/`t`/`p`) are not premature cleverness — up to
  /// a few hundred of these are JSON-encoded into a single
  /// `SharedPreferences` string list, and that whole list is rewritten on every
  /// flush. Roughly halving the payload halves the disk churn on the UI
  /// isolate, which `md/remember.md` Section E rule 5 cares about.
  Map<String, Object?> toJson() => <String, Object?>{
        'v': schemaVersion,
        'n': name.wireName,
        't': timestampMs,
        'p': parameters,
      };

  String encode() => jsonEncode(toJson());

  /// Rebuilds a typed event from its wire form, or returns `null` if it cannot.
  ///
  /// Returning `null` rather than throwing is deliberate: the caller is the
  /// buffer restoring from disk at app start, and a single unparseable row —
  /// truncated write, downgraded install, hand-edited prefs — must cost that
  /// row and nothing else. Analytics is never a reason for the app not to open.
  static AnalyticsEvent? tryDecode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      if (decoded['v'] != schemaVersion) return null;
      final wireName = decoded['n'];
      if (wireName is! String) return null;
      final eventName = AnalyticsEventName.fromWire(wireName);
      if (eventName == null) return null;
      final timestamp = decoded['t'];
      if (timestamp is! int) return null;
      final params = decoded['p'];
      if (params is! Map) return null;
      return _fromParts(eventName, timestamp, params);
    } on FormatException {
      return null;
    }
  }

  static AnalyticsEvent? _fromParts(
    AnalyticsEventName name,
    int timestampMs,
    Map<Object?, Object?> p,
  ) {
    String? token(String key) => p[key] is String ? p[key] as String : null;
    int intOr(String key, int fallback) => p[key] is int ? p[key] as int : fallback;

    final mode = GameMode.fromWire(token('mode') ?? '');

    switch (name) {
      case AnalyticsEventName.gameOpened:
        final game = token('game');
        if (game == null || mode == null) return null;
        return GameOpenedEvent(gameId: game, mode: mode, timestampMs: timestampMs);

      case AnalyticsEventName.levelStarted:
        final game = token('game');
        if (game == null || mode == null) return null;
        return LevelStartedEvent(
          gameId: game,
          level: intOr('level', 0),
          mode: mode,
          timestampMs: timestampMs,
        );

      case AnalyticsEventName.levelCompleted:
        final game = token('game');
        if (game == null || mode == null) return null;
        return LevelCompletedEvent(
          gameId: game,
          level: intOr('level', 0),
          mode: mode,
          durationMillis: intOr('dur_s', 0) * 1000,
          hintsUsed: intOr('hints', 0),
          timestampMs: timestampMs,
        );

      case AnalyticsEventName.levelAbandoned:
        final game = token('game');
        final reason = AbandonReason.fromWire(token('reason') ?? '');
        if (game == null || mode == null || reason == null) return null;
        return LevelAbandonedEvent(
          gameId: game,
          level: intOr('level', 0),
          mode: mode,
          reason: reason,
          durationMillis: intOr('dur_s', 0) * 1000,
          timestampMs: timestampMs,
        );

      case AnalyticsEventName.hintUsed:
        final game = token('game');
        if (game == null || mode == null) return null;
        return HintUsedEvent(
          gameId: game,
          level: intOr('level', 0),
          mode: mode,
          timestampMs: timestampMs,
        );

      case AnalyticsEventName.purchase:
        final product = token('product');
        final step = PurchaseStep.fromWire(token('step') ?? '');
        if (product == null || step == null) return null;
        return PurchaseEvent(
          productId: product,
          step: step,
          timestampMs: timestampMs,
        );

      case AnalyticsEventName.sessionStarted:
        return SessionStartedEvent(timestampMs: timestampMs);

      case AnalyticsEventName.sessionEnded:
        return SessionEndedEvent(
          durationMillis: intOr('dur_s', 0) * 1000,
          timestampMs: timestampMs,
        );

      case AnalyticsEventName.consentGranted:
        return ConsentGrantedEvent(timestampMs: timestampMs);
    }
  }

  /// True when every parameter value is a small int, a bool, or a token that
  /// matches [tokenPattern].
  ///
  /// Called from an `assert` at the single recording choke point, so a payload
  /// that could carry free text fails loudly in debug and in tests rather than
  /// quietly in production. It is a guard rail for future edits to this file,
  /// not a runtime cost — asserts are stripped from release builds.
  bool debugParametersAreSafe() {
    for (final value in parameters.values) {
      if (value is int || value is bool) continue;
      if (value is String && tokenPattern.hasMatch(value)) continue;
      return false;
    }
    return true;
  }

  @override
  String toString() => encode();
}

/// The complete list of event names. The wire name is the string a backend
/// sees; the enum case is the only way to reach it from Dart.
enum AnalyticsEventName {
  /// A game's screen was opened from the library or a shortcut.
  gameOpened('game_opened'),

  /// A level was presented to the player.
  levelStarted('level_started'),

  /// A level was solved.
  levelCompleted('level_completed'),

  /// A level was left without being solved. The `reason` says how.
  levelAbandoned('level_abandoned'),

  /// A hint was spent.
  hintUsed('hint_used'),

  /// An in-app purchase moved through a lifecycle step.
  purchase('purchase'),

  /// The app came to the foreground.
  sessionStarted('session_started'),

  /// The app left the foreground; carries the session duration.
  sessionEnded('session_ended'),

  /// The player opted in. Recorded so the backend can tell "no data because
  /// nobody plays" apart from "no data because nobody consented".
  ///
  /// There is deliberately no matching `consent_revoked` event: revoking
  /// consent purges the buffer, so such an event could never be delivered
  /// honestly, and manufacturing one would mean transmitting a fact about a
  /// player immediately after they asked us to stop.
  consentGranted('consent_granted');

  const AnalyticsEventName(this.wireName);

  final String wireName;

  static AnalyticsEventName? fromWire(String wire) {
    for (final value in values) {
      if (value.wireName == wire) return value;
    }
    return null;
  }
}

/// Which progression the event happened in.
///
/// Zen and Challenge are parallel progressions (`md/remember.md` rule 13), so
/// mixing their numbers would make both meaningless: Zen strips the modifiers
/// that make late Challenge levels hard, so a "level 40 completion rate" that
/// pooled the two would measure nothing at all.
enum GameMode {
  challenge('challenge'),
  zen('zen');

  const GameMode(this.wireName);

  final String wireName;

  static GameMode? fromWire(String wire) {
    for (final value in values) {
      if (value.wireName == wire) return value;
    }
    return null;
  }
}

/// How a level ended without being solved.
///
/// The distinction matters for the only question this event is worth sending
/// for: `quit` on level 12 of one game repeatedly is a difficulty-curve
/// problem, whereas `backgrounded` is a phone call.
enum AbandonReason {
  /// The player used back / quit deliberately.
  quit('quit'),

  /// The app went to the background while the level was open.
  backgrounded('backgrounded'),

  /// The player jumped to a different level or game without finishing.
  switchedAway('switched_away'),

  /// The level was replaced by a restart or shuffle.
  restarted('restarted');

  const AbandonReason(this.wireName);

  final String wireName;

  static AbandonReason? fromWire(String wire) {
    for (final value in values) {
      if (value.wireName == wire) return value;
    }
    return null;
  }
}

/// A step in the purchase lifecycle.
///
/// Note what is absent: no order id, no receipt, no token, no price, no
/// currency. A store order id is a durable per-user identifier and would drag
/// this app into "collects financial identifiers" territory on the data-safety
/// form for no product benefit — the store console already reports revenue.
/// What is genuinely unknown without this event is the *funnel*: how many
/// people open the purchase sheet versus finish, which is what `initiated` and
/// `completed` answer.
enum PurchaseStep {
  initiated('initiated'),
  completed('completed'),
  failed('failed'),
  restored('restored');

  const PurchaseStep(this.wireName);

  final String wireName;

  static PurchaseStep? fromWire(String wire) {
    for (final value in values) {
      if (value.wireName == wire) return value;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// the events
// ---------------------------------------------------------------------------

/// A game screen was opened. Answers "which of the 16 games do people actually
/// touch", which is the discovery/curation question in `md/RELEASE_PLAN.md`
/// §4.3 A.
class GameOpenedEvent extends AnalyticsEvent {
  GameOpenedEvent({
    required String gameId,
    required this.mode,
    super.timestampMs,
  }) : gameId = AnalyticsEvent.sanitizeToken(gameId);

  final String gameId;
  final GameMode mode;

  @override
  AnalyticsEventName get name => AnalyticsEventName.gameOpened;

  @override
  Map<String, Object?> get parameters => <String, Object?>{
        'game': gameId,
        'mode': mode.wireName,
      };
}

/// A level was presented. Paired with [LevelCompletedEvent] and
/// [LevelAbandonedEvent] this gives a per-level completion rate, which is the
/// only honest way to find the difficulty cliffs the release plan keeps
/// guessing at.
class LevelStartedEvent extends AnalyticsEvent {
  LevelStartedEvent({
    required String gameId,
    required int level,
    required this.mode,
    super.timestampMs,
  })  : gameId = AnalyticsEvent.sanitizeToken(gameId),
        level = AnalyticsEvent.sanitizeLevel(level);

  final String gameId;
  final int level;
  final GameMode mode;

  @override
  AnalyticsEventName get name => AnalyticsEventName.levelStarted;

  @override
  Map<String, Object?> get parameters => <String, Object?>{
        'game': gameId,
        'level': level,
        'mode': mode.wireName,
      };
}

/// A level was solved.
class LevelCompletedEvent extends AnalyticsEvent {
  LevelCompletedEvent({
    required String gameId,
    required int level,
    required this.mode,
    required int durationMillis,
    required this.hintsUsed,
    super.timestampMs,
  })  : gameId = AnalyticsEvent.sanitizeToken(gameId),
        level = AnalyticsEvent.sanitizeLevel(level),
        durationSeconds =
            AnalyticsEvent.sanitizeDurationSeconds(durationMillis);

  final String gameId;
  final int level;
  final GameMode mode;

  /// Wall-clock seconds the level was open. Seconds, not milliseconds: nobody
  /// will ever ask a question that needs sub-second solve times, and coarser
  /// numbers are both smaller on the wire and less identifying.
  final int durationSeconds;

  /// Hints spent on this level. The signal the release plan wants for tuning
  /// the hint economy without a per-player history.
  final int hintsUsed;

  @override
  AnalyticsEventName get name => AnalyticsEventName.levelCompleted;

  @override
  Map<String, Object?> get parameters => <String, Object?>{
        'game': gameId,
        'level': level,
        'mode': mode.wireName,
        'dur_s': durationSeconds,
        'hints': hintsUsed,
      };
}

/// A level was left unsolved.
class LevelAbandonedEvent extends AnalyticsEvent {
  LevelAbandonedEvent({
    required String gameId,
    required int level,
    required this.mode,
    required this.reason,
    required int durationMillis,
    super.timestampMs,
  })  : gameId = AnalyticsEvent.sanitizeToken(gameId),
        level = AnalyticsEvent.sanitizeLevel(level),
        durationSeconds =
            AnalyticsEvent.sanitizeDurationSeconds(durationMillis);

  final String gameId;
  final int level;
  final GameMode mode;
  final AbandonReason reason;
  final int durationSeconds;

  @override
  AnalyticsEventName get name => AnalyticsEventName.levelAbandoned;

  @override
  Map<String, Object?> get parameters => <String, Object?>{
        'game': gameId,
        'level': level,
        'mode': mode.wireName,
        'reason': reason.wireName,
        'dur_s': durationSeconds,
      };
}

/// A hint was spent on a level.
class HintUsedEvent extends AnalyticsEvent {
  HintUsedEvent({
    required String gameId,
    required int level,
    required this.mode,
    super.timestampMs,
  })  : gameId = AnalyticsEvent.sanitizeToken(gameId),
        level = AnalyticsEvent.sanitizeLevel(level);

  final String gameId;
  final int level;
  final GameMode mode;

  @override
  AnalyticsEventName get name => AnalyticsEventName.hintUsed;

  @override
  Map<String, Object?> get parameters => <String, Object?>{
        'game': gameId,
        'level': level,
        'mode': mode.wireName,
      };
}

/// An in-app purchase moved through a lifecycle step.
///
/// [productId] is one of *our own* catalog ids (`ad_free`, `starter_bundle`,
/// point packs) — a constant that ships in the binary, identical for every
/// install, and therefore not an identifier of anyone.
class PurchaseEvent extends AnalyticsEvent {
  PurchaseEvent({
    required String productId,
    required this.step,
    super.timestampMs,
  }) : productId = AnalyticsEvent.sanitizeToken(productId);

  final String productId;
  final PurchaseStep step;

  @override
  AnalyticsEventName get name => AnalyticsEventName.purchase;

  @override
  Map<String, Object?> get parameters => <String, Object?>{
        'product': productId,
        'step': step.wireName,
      };
}

/// The app came to the foreground. Carries no payload on purpose — the session
/// is identified only by its position in the stream, not by any token.
class SessionStartedEvent extends AnalyticsEvent {
  SessionStartedEvent({super.timestampMs});

  @override
  AnalyticsEventName get name => AnalyticsEventName.sessionStarted;

  @override
  Map<String, Object?> get parameters => const <String, Object?>{};
}

/// The app left the foreground, with how long it was there.
class SessionEndedEvent extends AnalyticsEvent {
  SessionEndedEvent({
    required int durationMillis,
    super.timestampMs,
  }) : durationSeconds =
            AnalyticsEvent.sanitizeDurationSeconds(durationMillis);

  final int durationSeconds;

  @override
  AnalyticsEventName get name => AnalyticsEventName.sessionEnded;

  @override
  Map<String, Object?> get parameters => <String, Object?>{
        'dur_s': durationSeconds,
      };
}

/// The player opted in. See [AnalyticsEventName.consentGranted] for why there
/// is no revocation counterpart.
class ConsentGrantedEvent extends AnalyticsEvent {
  ConsentGrantedEvent({super.timestampMs});

  @override
  AnalyticsEventName get name => AnalyticsEventName.consentGranted;

  @override
  Map<String, Object?> get parameters => const <String, Object?>{};
}
