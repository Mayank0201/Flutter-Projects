import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cogniq/utils/analytics/analytics.dart';
import 'package:cogniq/utils/analytics/local_buffer.dart';
import 'package:cogniq/utils/zen_mode.dart';

/// Tests for the analytics layer.
///
/// The interesting properties here are all *negative* ones — that nothing is
/// recorded before consent, that opting out destroys data, that no payload can
/// carry free text — so most of these tests assert an absence. Absences are
/// exactly the things that regress silently, which is why they get a test each.

/// A sink that keeps everything it is handed. Stands in for a future backend
/// and proves the interface is swappable without touching a call site.
class _RecordingSink implements AnalyticsSink {
  final List<List<AnalyticsEvent>> batches = [];

  @override
  String get id => 'recording';

  @override
  Future<bool> deliver(List<AnalyticsEvent> batch) async {
    batches.add(List<AnalyticsEvent>.from(batch));
    return true;
  }
}

/// A sink that is "offline": it refuses every batch. Events must survive.
class _OfflineSink implements AnalyticsSink {
  int attempts = 0;

  @override
  String get id => 'offline';

  @override
  Future<bool> deliver(List<AnalyticsEvent> batch) async {
    attempts++;
    return false;
  }
}

/// A sink that throws. A buggy backend must not be able to eat data.
class _ThrowingSink implements AnalyticsSink {
  @override
  String get id => 'throwing';

  @override
  Future<bool> deliver(List<AnalyticsEvent> batch) async {
    throw StateError('backend exploded');
  }
}

/// One instance of every event in the taxonomy, built with deliberately hostile
/// input so the sanitisers are exercised rather than bypassed.
List<AnalyticsEvent> _allEventSamples() => [
      GameOpenedEvent(gameId: 'sandsort', mode: GameMode.challenge),
      LevelStartedEvent(gameId: 'kakuro', level: 12, mode: GameMode.zen),
      LevelCompletedEvent(
        gameId: 'minesweeper',
        level: 7,
        mode: GameMode.challenge,
        durationMillis: 91_500,
        hintsUsed: 2,
      ),
      LevelAbandonedEvent(
        gameId: 'colour_link',
        level: 3,
        mode: GameMode.zen,
        reason: AbandonReason.quit,
        durationMillis: 4200,
      ),
      HintUsedEvent(gameId: 'sudoku', level: 40, mode: GameMode.challenge),
      PurchaseEvent(productId: 'starter_bundle', step: PurchaseStep.completed),
      SessionStartedEvent(),
      SessionEndedEvent(durationMillis: 300_000),
      ConsentGrantedEvent(),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Park the auto-flush timer far out of reach so every disk write in these
    // tests is one the test asked for. Nothing here should depend on timing.
    LocalBuffer.flushDelay = const Duration(hours: 1);
    Analytics.resetForTesting();
  });

  tearDown(() {
    Analytics.resetForTesting();
  });

  // -------------------------------------------------------------------------
  group('consent gate', () {
    test('nothing is recorded before initialize', () {
      Analytics.levelStarted('sandsort', 1);
      Analytics.gameOpened('kakuro');
      expect(Analytics.pendingCount, 0);
    });

    test('nothing is recorded before consent is granted', () async {
      await Analytics.initialize();

      expect(Analytics.isEnabled, isFalse,
          reason: 'analytics must default to disabled');

      Analytics.gameOpened('sandsort');
      Analytics.levelStarted('sandsort', 3);
      Analytics.hintUsed('sandsort', 3);
      Analytics.levelCompleted('sandsort', 3, durationMillis: 5000);
      Analytics.purchase('ad_free', PurchaseStep.completed);
      Analytics.startSession();
      await Analytics.endSession();

      expect(Analytics.pendingCount, 0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(LocalBuffer.prefsKeyPendingEvents), isNull,
          reason: 'nothing may reach disk without consent');
    });

    test('the first-run prompt is needed until it is answered', () async {
      await Analytics.initialize();
      expect(Analytics.needsConsentPrompt, isTrue);

      await Analytics.setConsent(false);
      expect(Analytics.needsConsentPrompt, isFalse,
          reason: 'declining is an answer; the prompt must not reappear');

      Analytics.resetForTesting();
      await Analytics.initialize();
      expect(Analytics.needsConsentPrompt, isFalse);
      expect(Analytics.isEnabled, isFalse);
    });

    test('events flow once consent is granted', () async {
      await Analytics.initialize();
      await Analytics.setConsent(true);

      expect(Analytics.isEnabled, isTrue);
      // setConsent(true) records exactly one consent event.
      expect(Analytics.pendingCount, 1);

      Analytics.levelStarted('sandsort', 3);
      Analytics.levelCompleted('sandsort', 3,
          durationMillis: 12_000, hintsUsed: 1);
      expect(Analytics.pendingCount, 3);
    });

    test('the notifier mirrors consent for the settings toggle', () async {
      await Analytics.initialize();
      expect(Analytics.enabledNotifier.value, isFalse);

      await Analytics.setConsent(true);
      expect(Analytics.enabledNotifier.value, isTrue);

      await Analytics.setConsent(false);
      expect(Analytics.enabledNotifier.value, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('opting out purges', () {
    test('pending events are erased from memory and from disk', () async {
      await Analytics.initialize();
      await Analytics.setConsent(true);
      for (var i = 0; i < 10; i++) {
        Analytics.levelStarted('sandsort', i);
      }
      await Analytics.flush();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(LocalBuffer.prefsKeyPendingEvents), isNotNull);
      expect(Analytics.pendingCount, 11);

      await Analytics.setConsent(false);

      expect(Analytics.pendingCount, 0);
      expect(prefs.getStringList(LocalBuffer.prefsKeyPendingEvents), isNull,
          reason: 'the key must be removed, not left as an empty list');
    });

    test('the install id is destroyed on opt-out and reminted on opt-in',
        () async {
      await Analytics.initialize();
      await Analytics.setConsent(true);

      final first = Analytics.installId;
      expect(first, isNotNull);

      await Analytics.setConsent(false);
      expect(Analytics.installId, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(Analytics.prefsKeyInstallId), isNull);

      await Analytics.setConsent(true);
      expect(Analytics.installId, isNotNull);
      expect(Analytics.installId, isNot(first),
          reason: 'opting back in must be a clean break, not a resumption');
    });

    test('recording stops immediately after opting out', () async {
      await Analytics.initialize();
      await Analytics.setConsent(true);
      await Analytics.setConsent(false);

      Analytics.gameOpened('sandsort');
      Analytics.levelStarted('sandsort', 1);
      expect(Analytics.pendingCount, 0);
    });

    test('a buffer left on disk without consent is purged at startup',
        () async {
      // Simulates an opt-out interrupted before the purge finished, or a
      // downgraded build: consent is off but rows exist. Startup must clean up.
      SharedPreferences.setMockInitialValues({
        LocalBuffer.prefsKeyPendingEvents: <String>[
          GameOpenedEvent(gameId: 'sandsort', mode: GameMode.challenge)
              .encode(),
        ],
        Analytics.prefsKeyConsentGranted: false,
        Analytics.prefsKeyInstallId: 'leftover-id',
      });
      Analytics.resetForTesting();

      await Analytics.initialize();

      expect(Analytics.pendingCount, 0);
      expect(Analytics.installId, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(Analytics.prefsKeyInstallId), isNull);
      expect(prefs.getStringList(LocalBuffer.prefsKeyPendingEvents), isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('bounded buffer', () {
    test('respects the cap and drops the oldest events', () async {
      await Analytics.initialize();
      await Analytics.setConsent(true);

      // 1 consent event + 400 level starts = 401 recorded, 300 retained.
      for (var i = 0; i < 400; i++) {
        Analytics.levelStarted('sandsort', i);
      }

      expect(Analytics.pendingCount, LocalBuffer.maxEvents);

      final kept = LocalBuffer.snapshot();
      expect(kept.length, 300);

      final first = kept.first;
      expect(first, isA<LevelStartedEvent>());
      expect((first as LevelStartedEvent).level, 100,
          reason: 'the 101 oldest events must be the ones dropped');

      final last = kept.last;
      expect((last as LevelStartedEvent).level, 399,
          reason: 'the newest event must always survive');

      // The consent event was the very first thing recorded, so it is gone.
      expect(kept.any((e) => e is ConsentGrantedEvent), isFalse);
    });

    test('the cap holds across a persist/restore cycle', () async {
      await Analytics.initialize();
      await Analytics.setConsent(true);
      for (var i = 0; i < 500; i++) {
        Analytics.levelStarted('kakuro', i);
      }
      await Analytics.flush();

      Analytics.resetForTesting();
      await Analytics.initialize();

      expect(Analytics.pendingCount, LocalBuffer.maxEvents);
    });
  });

  // -------------------------------------------------------------------------
  group('persistence', () {
    test('events survive a simulated restart', () async {
      await Analytics.initialize();
      await Analytics.setConsent(true);

      Analytics.gameOpened('sandsort');
      Analytics.levelStarted('sandsort', 5);
      Analytics.levelCompleted('sandsort', 5,
          durationMillis: 42_000, hintsUsed: 3);
      await Analytics.flush();

      final before = Analytics.pendingCount;
      expect(before, 4);

      // Drop all in-memory state without touching prefs — a process restart.
      Analytics.resetForTesting();
      expect(Analytics.pendingCount, 0);

      await Analytics.initialize();

      expect(Analytics.isEnabled, isTrue,
          reason: 'consent must persist across restarts');
      expect(Analytics.pendingCount, before);

      final restored = LocalBuffer.snapshot();
      final completed =
          restored.whereType<LevelCompletedEvent>().single;
      expect(completed.gameId, 'sandsort');
      expect(completed.level, 5);
      expect(completed.durationSeconds, 42);
      expect(completed.hintsUsed, 3);
      expect(completed.mode, GameMode.challenge);
    });

    test('every event type round-trips through encode/decode', () {
      for (final event in _allEventSamples()) {
        final decoded = AnalyticsEvent.tryDecode(event.encode());
        expect(decoded, isNotNull, reason: '${event.name.wireName} failed');
        expect(decoded!.runtimeType, event.runtimeType);
        expect(decoded.name, event.name);
        expect(decoded.parameters, event.parameters);
        expect(decoded.timestampMs, event.timestampMs);
      }
    });

    test('the taxonomy has a sample for every event name', () {
      expect(
        _allEventSamples().map((e) => e.name).toSet(),
        AnalyticsEventName.values.toSet(),
      );
    });

    test('corrupt and stale rows are dropped, not crashed on', () async {
      final good =
          GameOpenedEvent(gameId: 'sandsort', mode: GameMode.challenge).encode();
      SharedPreferences.setMockInitialValues({
        Analytics.prefsKeyConsentGranted: true,
        Analytics.prefsKeyConsentPromptSeen: true,
        LocalBuffer.prefsKeyPendingEvents: <String>[
          good,
          'not json at all',
          '{"v":1,"n":"invented_event","t":0,"p":{}}',
          '{"v":99,"n":"game_opened","t":0,"p":{"game":"x","mode":"zen"}}',
          '{}',
        ],
      });
      Analytics.resetForTesting();

      await Analytics.initialize();

      expect(Analytics.pendingCount, 1);
      expect(LocalBuffer.snapshot().single, isA<GameOpenedEvent>());
    });

    test('a schema version bump discards the whole stale buffer', () async {
      SharedPreferences.setMockInitialValues({
        Analytics.prefsKeyConsentGranted: true,
        Analytics.prefsKeyConsentPromptSeen: true,
        LocalBuffer.prefsKeyBufferSchemaVersion:
            AnalyticsEvent.schemaVersion + 1,
        LocalBuffer.prefsKeyPendingEvents: <String>['whatever'],
      });
      Analytics.resetForTesting();

      await Analytics.initialize();
      expect(Analytics.pendingCount, 0);
    });

    test('every encoded event carries the schema version', () {
      for (final event in _allEventSamples()) {
        expect(event.toJson()['v'], AnalyticsEvent.schemaVersion);
        expect(event.encode(), contains('"v":${AnalyticsEvent.schemaVersion}'));
      }
    });
  });

  // -------------------------------------------------------------------------
  group('sink is swappable', () {
    test('the default sink is the no-op one, so nothing leaves the device',
        () async {
      await Analytics.initialize();
      expect(Analytics.sink, isA<NoopSink>());
    });

    test('a custom sink receives typed events and drains the buffer', () async {
      await Analytics.initialize();
      await Analytics.setConsent(true);

      final sink = _RecordingSink();
      Analytics.setSink(sink);

      Analytics.gameOpened('hue');
      Analytics.levelStarted('hue', 2);

      final delivered = await Analytics.deliverPending();

      expect(delivered, 3); // consent + opened + started
      expect(sink.batches, hasLength(1));
      expect(sink.batches.single, hasLength(3));
      expect(sink.batches.single[1], isA<GameOpenedEvent>());
      expect(Analytics.pendingCount, 0);
    });

    test('an offline sink keeps events queued for the next attempt', () async {
      await Analytics.initialize();
      await Analytics.setConsent(true);
      Analytics.setSink(_OfflineSink());

      Analytics.gameOpened('queens');
      final delivered = await Analytics.deliverPending();

      expect(delivered, 0);
      expect(Analytics.pendingCount, 2,
          reason: 'a failed delivery must not lose events');
    });

    test('a throwing sink cannot eat events', () async {
      await Analytics.initialize();
      await Analytics.setConsent(true);
      Analytics.setSink(_ThrowingSink());

      Analytics.gameOpened('queens');
      final delivered = await Analytics.deliverPending();

      expect(delivered, 0);
      expect(Analytics.pendingCount, 2);
    });

    test('no delivery is attempted without consent', () async {
      await Analytics.initialize();
      final sink = _RecordingSink();
      Analytics.setSink(sink);

      Analytics.gameOpened('queens');
      final delivered = await Analytics.deliverPending();

      expect(delivered, 0);
      expect(sink.batches, isEmpty,
          reason: 'an opted-out player must produce no sink traffic at all');
    });

    test('events recorded mid-delivery are not lost', () async {
      await Analytics.initialize();
      await Analytics.setConsent(true);
      Analytics.setSink(_RecordingSink());

      Analytics.gameOpened('hue');
      final batch = LocalBuffer.snapshot();
      // Something arrives after the snapshot, before the acknowledge.
      Analytics.levelStarted('hue', 9);
      await LocalBuffer.acknowledge(batch.length);

      expect(Analytics.pendingCount, 1);
      expect(LocalBuffer.snapshot().single, isA<LevelStartedEvent>());
    });
  });

  // -------------------------------------------------------------------------
  group('no event carries PII', () {
    test('every parameter is an int, a bool, or a closed-vocabulary token', () {
      for (final event in _allEventSamples()) {
        expect(event.debugParametersAreSafe(), isTrue,
            reason: '${event.name.wireName} has an unsafe parameter');

        for (final entry in event.parameters.entries) {
          final value = entry.value;
          if (value is int || value is bool) continue;
          expect(value, isA<String>(),
              reason: '${entry.key} is neither scalar nor token');
          expect(AnalyticsEvent.tokenPattern.hasMatch(value as String), isTrue,
              reason: '${entry.key} = "$value" is not a safe token');
        }
      }
    });

    test('no parameter can contain whitespace, punctuation or an @', () {
      for (final event in _allEventSamples()) {
        for (final value in event.parameters.values) {
          if (value is! String) continue;
          expect(value, isNot(contains(' ')));
          expect(value, isNot(contains('@')));
          expect(value, isNot(contains('.')));
          expect(value, isNot(contains('/')));
        }
      }
    });

    test('free text passed by a future call site is destroyed, not carried',
        () {
      final hostile = GameOpenedEvent(
        gameId: 'Jane Doe <jane.doe@example.com> https://evil.test/?q=secret',
        mode: GameMode.challenge,
      );

      final game = hostile.parameters['game']! as String;
      // Not slugified — replaced. A slug would still read as a name and a
      // domain, which is reformatted personal data, not removed personal data.
      expect(game, AnalyticsEvent.invalidToken);
      for (final fragment in ['jane', 'doe', 'example', 'evil', 'secret']) {
        expect(game, isNot(contains(fragment)));
      }
      expect(AnalyticsEvent.tokenPattern.hasMatch(game), isTrue);
      expect(hostile.debugParametersAreSafe(), isTrue);
    });

    test('sanitizeToken passes real ids and rejects everything else', () {
      // Real ids from game_info.dart / iap_catalog.dart survive untouched.
      for (final id in <String>[
        'zip',
        'sandsort',
        'colour_link',
        'pattern_lock',
        'starter_bundle',
      ]) {
        expect(AnalyticsEvent.sanitizeToken(id), id);
      }
      expect(AnalyticsEvent.sanitizeToken('ZIP'), 'zip');

      // Anything else is replaced wholesale, and never leaks a fragment.
      for (final raw in <String>[
        '',
        '   ',
        '!!!',
        'colour-link',
        'a' * 200,
        'user@example.com',
        'the word was CRANE',
        '你好世界',
        'https://example.com/u/1234',
      ]) {
        final token = AnalyticsEvent.sanitizeToken(raw);
        expect(token, AnalyticsEvent.invalidToken,
            reason: 'sanitize("$raw") produced "$token"');
        expect(AnalyticsEvent.tokenPattern.hasMatch(token), isTrue);
      }
    });

    test('timestamps are truncated to the minute', () {
      final event = GameOpenedEvent(
        gameId: 'sandsort',
        mode: GameMode.challenge,
        timestampMs: 1_700_000_123_456,
      );
      expect(event.timestampMs % 60000, 0);
      expect(event.timestampMs, lessThanOrEqualTo(1_700_000_123_456));
    });

    test('durations are clamped against a jumping device clock', () {
      expect(
        SessionEndedEvent(durationMillis: -5000).durationSeconds,
        0,
      );
      expect(
        SessionEndedEvent(durationMillis: 999_999_999).durationSeconds,
        24 * 60 * 60,
      );
      expect(
        LevelCompletedEvent(
          gameId: 'sudoku',
          level: -4,
          mode: GameMode.zen,
          durationMillis: 61_999,
          hintsUsed: 0,
        ).level,
        0,
      );
    });

    test('the install id is a locally generated random UUID v4', () async {
      await Analytics.initialize();
      await Analytics.setConsent(true);

      final id = Analytics.installId!;
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(id),
        isTrue,
        reason: 'expected a v4 UUID, got "$id"',
      );

      // It is not part of any payload — it belongs to the transport.
      for (final event in _allEventSamples()) {
        expect(event.encode(), isNot(contains(id)));
      }
    });
  });

  // -------------------------------------------------------------------------
  group('session events', () {
    test('session end carries the elapsed duration', () async {
      await Analytics.initialize();
      await Analytics.setConsent(true);

      Analytics.startSession();
      await Analytics.endSession();

      final ended = LocalBuffer.snapshot().whereType<SessionEndedEvent>();
      expect(ended, hasLength(1));
      expect(ended.single.durationSeconds, greaterThanOrEqualTo(0));
      expect(ended.single.parameters.keys, ['dur_s']);
    });

    test('ending a session without a start records nothing', () async {
      await Analytics.initialize();
      await Analytics.setConsent(true);
      final before = Analytics.pendingCount;

      await Analytics.endSession();

      expect(Analytics.pendingCount, before);
    });
  });

  // -------------------------------------------------------------------------
  group('mode tagging', () {
    test('events are tagged with the mode the player is actually in', () async {
      await Analytics.initialize();
      await Analytics.setConsent(true);

      expect(Analytics.currentMode, GameMode.challenge);
      Analytics.levelStarted('sandsort', 1);

      // ZenMode writes its own pref; the analytics layer only reads the flag,
      // so call sites cannot mis-tag an event by forgetting to pass the mode.
      // Always put it back afterwards — Zen leaking into a later test would
      // silently retag its events.
      await ZenMode.setEnabled(true);
      addTearDown(() => ZenMode.setEnabled(false));

      expect(Analytics.currentMode, GameMode.zen);
      Analytics.levelStarted('sandsort', 1);

      final starts = LocalBuffer.snapshot().whereType<LevelStartedEvent>();
      expect(starts.map((e) => e.mode).toList(),
          [GameMode.challenge, GameMode.zen]);
    });
  });
}
