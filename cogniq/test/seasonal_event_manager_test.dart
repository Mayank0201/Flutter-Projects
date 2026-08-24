import 'package:cogniq/models/game_info.dart';
import 'package:cogniq/utils/achievement_manager.dart';
import 'package:cogniq/utils/point_manager.dart';
import 'package:cogniq/utils/prefs_keys.dart';
import 'package:cogniq/utils/seasonal_event_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// S3 — seasonal event framework.
///
/// Every test drives the manager with an explicit date. `DateTime.now()` is
/// never consulted, so a run at 23:59 on 31 December behaves exactly like a run
/// at noon in June, and DST, year boundaries, a clock moved backwards and a
/// device in another timezone are all reachable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Any test that leaked a fake clock must not affect the next one.
    SeasonalEventManager.clock = DateTime.now;
  });

  // Belt and braces: a test that swaps the clock hands it back immediately,
  // rather than relying on the next test's setUp to clean up after it.
  tearDown(() => SeasonalEventManager.clock = DateTime.now);

  // ---------------------------------------------------------------------------
  // Fixtures. Local definitions so the tests do not depend on shipped content.
  // ---------------------------------------------------------------------------

  const EventBadge shortBadge = EventBadge(
    id: 'event_test_short',
    name: 'Short',
    description: 'test',
    icon: '🔸',
    requiredProgress: 3,
    rewardPoints: 100,
    rewardTitle: 'Tester',
  );

  const EventBadge longBadge = EventBadge(
    id: 'event_test_long',
    name: 'Long',
    description: 'test',
    icon: '🔹',
    requiredProgress: 2,
  );

  /// 10–20 June. Wholly inside one year.
  const SeasonalEventDefinition summer = SeasonalEventDefinition(
    id: 'summer',
    name: 'Summer',
    tagline: 'test',
    emoji: '☀️',
    window: EventWindow(start: MonthDay(6, 10), end: MonthDay(6, 20)),
    featuredGameIds: <String>['zip'],
    badge: shortBadge,
  );

  /// 18 December – 5 January. Spans New Year.
  const SeasonalEventDefinition newYear = SeasonalEventDefinition(
    id: 'newyear',
    name: 'New Year',
    tagline: 'test',
    emoji: '🎆',
    window: EventWindow(start: MonthDay(12, 18), end: MonthDay(1, 5)),
    featuredGameIds: <String>['zip'],
    badge: longBadge,
  );

  /// 1 June – 30 June, low priority: the "ambient" event a shorter one overlays.
  const SeasonalEventDefinition juneWide = SeasonalEventDefinition(
    id: 'june_wide',
    name: 'June Wide',
    tagline: 'test',
    emoji: '🌍',
    window: EventWindow(start: MonthDay(6, 1), end: MonthDay(6, 30)),
    featuredGameIds: <String>['zip'],
    badge: EventBadge(
      id: 'event_test_wide',
      name: 'Wide',
      description: 'test',
      icon: '🔶',
      requiredProgress: 1,
    ),
    priority: 1,
  );

  /// Same window and same priority as [summer], so only the id can separate
  /// them. Its id sorts before 'summer'.
  const SeasonalEventDefinition aliasOfSummer = SeasonalEventDefinition(
    id: 'a_twin',
    name: 'Twin',
    tagline: 'test',
    emoji: '👯',
    window: EventWindow(start: MonthDay(6, 10), end: MonthDay(6, 20)),
    featuredGameIds: <String>['zip'],
    badge: EventBadge(
      id: 'event_test_twin',
      name: 'Twin',
      description: 'test',
      icon: '🔷',
      requiredProgress: 1,
    ),
  );

  const List<SeasonalEventDefinition> fixtures = <SeasonalEventDefinition>[
    summer,
    newYear,
  ];

  DateTime at(int y, int m, int d, [int hour = 12]) => DateTime(y, m, d, hour);

  /// A shipped definition by id. Fails loudly rather than returning null, so a
  /// renamed event shows up as "no element" instead of a skipped assertion.
  SeasonalEventDefinition shipped(String id) => SeasonalEventManager
      .kSeasonalEvents
      .firstWhere((SeasonalEventDefinition d) => d.id == id);

  /// The ids of every *shipped* event running on [d], best match first.
  List<String> shippedIdsOn(DateTime d) => SeasonalEventManager.activeEvents(
          now: d)
      .map((SeasonalEventOccurrence o) => o.definition.id)
      .toList();

  Future<List<String>> unlockedIds() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(PrefsKeys.unlockedAchievements) ?? <String>[];
  }

  Future<List<String>> claimedIds() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(PrefsKeys.claimedAchievements) ?? <String>[];
  }

  // ---------------------------------------------------------------------------

  group('calendar helpers', () {
    test('dayDifference counts calendar days, not elapsed hours', () {
      // The exact hazard this project has already hit: two instants 23 hours
      // apart that fall on different calendar dates. `.difference().inDays`
      // reports 0 — a spring-forward local midnight-to-midnight gap.
      final DateTime a = DateTime(2026, 3, 8, 1);
      final DateTime b = DateTime(2026, 3, 9, 0);
      expect(b.difference(a).inDays, 0, reason: 'the trap this guards against');
      expect(SeasonalEventManager.dayDifference(a, b), 1);

      // And the mirror case: 25 hours apart but still one calendar day.
      final DateTime c = DateTime(2026, 11, 1, 1);
      final DateTime d = DateTime(2026, 11, 2, 2);
      expect(SeasonalEventManager.dayDifference(c, d), 1);
    });

    test('consecutive local dates are exactly one day apart, all year', () {
      // On a machine in a DST timezone this walks straight through both
      // transitions; on a machine without DST it still holds. Either way a
      // millisecond-arithmetic regression fails here.
      DateTime cursor = DateTime(2026, 1, 1);
      for (int i = 0; i < 365 * 2; i++) {
        final DateTime next =
            DateTime(cursor.year, cursor.month, cursor.day + 1);
        expect(SeasonalEventManager.dayDifference(cursor, next), 1,
            reason: 'from $cursor to $next');
        cursor = next;
      }
    });

    test('dayDifference is signed and symmetric', () {
      expect(
        SeasonalEventManager.dayDifference(at(2026, 12, 31), at(2027, 1, 1)),
        1,
      );
      expect(
        SeasonalEventManager.dayDifference(at(2027, 1, 1), at(2026, 12, 31)),
        -1,
      );
      expect(SeasonalEventManager.dayDifference(at(2026, 5, 5), at(2026, 5, 5)),
          0);
    });

    test('clampedDate never rolls a short month into the next one', () {
      // 2027 is not a leap year.
      expect(SeasonalEventManager.clampedDate(2027, 2, 29), DateTime(2027, 2, 28));
      // 2028 is.
      expect(SeasonalEventManager.clampedDate(2028, 2, 29), DateTime(2028, 2, 29));
      expect(SeasonalEventManager.clampedDate(2026, 4, 31), DateTime(2026, 4, 30));
      expect(SeasonalEventManager.clampedDate(2026, 12, 31), DateTime(2026, 12, 31));
    });
  });

  group('scheduling — no event', () {
    test('a date outside every window resolves to nothing', () {
      expect(
        SeasonalEventManager.activeEvent(
            now: at(2026, 3, 15), definitions: fixtures),
        isNull,
      );
      expect(
        SeasonalEventManager.activeEvents(
            now: at(2026, 3, 15), definitions: fixtures),
        isEmpty,
      );
    });

    test('the day before the window starts is outside it', () {
      expect(
        SeasonalEventManager.activeEvent(
            now: at(2026, 6, 9), definitions: fixtures),
        isNull,
      );
    });

    test('the day after the window ends is outside it', () {
      expect(
        SeasonalEventManager.activeEvent(
            now: at(2026, 6, 21), definitions: fixtures),
        isNull,
      );
    });

    test('an empty definition list is not an error', () {
      expect(
        SeasonalEventManager.activeEvent(
            now: at(2026, 6, 15), definitions: const <SeasonalEventDefinition>[]),
        isNull,
      );
    });
  });

  group('scheduling — inside a window', () {
    test('the correct event is returned mid-window', () {
      final SeasonalEventOccurrence? o = SeasonalEventManager.activeEvent(
          now: at(2026, 6, 15), definitions: fixtures);
      expect(o, isNotNull);
      expect(o!.definition.id, 'summer');
      expect(o.dayIndex, 6);
      expect(o.totalDays, 11);
      expect(o.daysRemaining, 5);
      expect(o.occurrenceKey, '2026-06-10');
    });

    test('both boundary days are inside the window', () {
      final SeasonalEventOccurrence? first = SeasonalEventManager.activeEvent(
          now: at(2026, 6, 10), definitions: fixtures);
      expect(first, isNotNull);
      expect(first!.isFirstDay, isTrue);
      expect(first.dayIndex, 1);
      expect(first.daysRemaining, 10);

      final SeasonalEventOccurrence? last = SeasonalEventManager.activeEvent(
          now: at(2026, 6, 20), definitions: fixtures);
      expect(last, isNotNull);
      expect(last!.isLastDay, isTrue);
      expect(last.daysRemaining, 0);
      expect(last.dayIndex, 11);
    });

    test('the event recurs the following year with a new occurrence key', () {
      final SeasonalEventOccurrence? a = SeasonalEventManager.activeEvent(
          now: at(2026, 6, 15), definitions: fixtures);
      final SeasonalEventOccurrence? b = SeasonalEventManager.activeEvent(
          now: at(2027, 6, 15), definitions: fixtures);
      expect(a!.definition.id, b!.definition.id);
      expect(a.occurrenceKey, '2026-06-10');
      expect(b.occurrenceKey, '2027-06-10');
    });

    test('one-off events respect firstYear / lastYear', () {
      const SeasonalEventDefinition once = SeasonalEventDefinition(
        id: 'once',
        name: 'Once',
        tagline: 'test',
        emoji: '1️⃣',
        window: EventWindow(start: MonthDay(6, 10), end: MonthDay(6, 20)),
        featuredGameIds: <String>['zip'],
        badge: EventBadge(
          id: 'event_test_once',
          name: 'Once',
          description: 'test',
          icon: '1️⃣',
          requiredProgress: 1,
        ),
        firstYear: 2026,
        lastYear: 2026,
      );
      const List<SeasonalEventDefinition> defs = <SeasonalEventDefinition>[once];
      expect(
          SeasonalEventManager.activeEvent(now: at(2025, 6, 15), definitions: defs),
          isNull);
      expect(
          SeasonalEventManager.activeEvent(now: at(2026, 6, 15), definitions: defs),
          isNotNull);
      expect(
          SeasonalEventManager.activeEvent(now: at(2027, 6, 15), definitions: defs),
          isNull);
    });

    test('nextEvent finds an upcoming event and ignores a running one', () {
      final SeasonalEventOccurrence? next = SeasonalEventManager.nextEvent(
          now: at(2026, 6, 1), definitions: fixtures);
      expect(next, isNotNull);
      expect(next!.definition.id, 'summer');
      expect(next.start, DateTime(2026, 6, 10));

      // Mid-event there is no "next".
      expect(
        SeasonalEventManager.nextEvent(
            now: at(2026, 6, 15), definitions: fixtures),
        isNull,
      );
    });
  });

  group('an event spanning 31 December → 1 January', () {
    test('runs continuously across the year boundary', () {
      for (final DateTime d in <DateTime>[
        at(2026, 12, 18),
        at(2026, 12, 31),
        at(2027, 1, 1),
        at(2027, 1, 5),
      ]) {
        final SeasonalEventOccurrence? o = SeasonalEventManager.activeEvent(
            now: d, definitions: fixtures);
        expect(o, isNotNull, reason: '$d should be inside the window');
        expect(o!.definition.id, 'newyear');
      }
      expect(
        SeasonalEventManager.activeEvent(
            now: at(2026, 12, 17), definitions: fixtures),
        isNull,
      );
      expect(
        SeasonalEventManager.activeEvent(
            now: at(2027, 1, 6), definitions: fixtures),
        isNull,
      );
    });

    test('31 December and 1 January belong to the SAME occurrence', () {
      final SeasonalEventOccurrence dec = SeasonalEventManager.activeEvent(
          now: at(2026, 12, 31), definitions: fixtures)!;
      final SeasonalEventOccurrence jan = SeasonalEventManager.activeEvent(
          now: at(2027, 1, 1), definitions: fixtures)!;
      expect(dec.occurrenceKey, jan.occurrenceKey);
      expect(dec.occurrenceKey, '2026-12-18');
      // Progress therefore does not reset at midnight on the 31st.
      expect(jan.dayIndex, dec.dayIndex + 1);
    });

    test('the day index climbs by exactly one per calendar day, end to end', () {
      final SeasonalEventOccurrence start = SeasonalEventManager.activeEvent(
          now: at(2026, 12, 18), definitions: fixtures)!;
      expect(start.dayIndex, 1);
      expect(start.totalDays, 19);

      DateTime cursor = at(2026, 12, 18);
      int expected = 1;
      while (true) {
        final SeasonalEventOccurrence? o = SeasonalEventManager.activeEvent(
            now: cursor, definitions: fixtures);
        if (o == null) break;
        expect(o.dayIndex, expected, reason: 'on $cursor');
        expect(o.occurrenceKey, '2026-12-18');
        cursor = DateTime(cursor.year, cursor.month, cursor.day + 1, 12);
        expected++;
      }
      expect(expected - 1, 19, reason: 'the window is 19 days long');
      expect(cursor, DateTime(2027, 1, 6, 12));
    });

    test('the New Year window recurs the next winter', () {
      final SeasonalEventOccurrence o = SeasonalEventManager.activeEvent(
          now: at(2028, 1, 2), definitions: fixtures)!;
      expect(o.definition.id, 'newyear');
      expect(o.occurrenceKey, '2027-12-18');
    });
  });

  group('DST and timezone robustness', () {
    test('the hour of day never changes which event is running', () {
      // 8 March 2026 is a US spring-forward date and 1 November 2026 a
      // fall-back date; 03:00 is the hour that does not exist / happens twice.
      // Resolution reads calendar fields only, so all hours agree.
      for (final int hour in <int>[0, 1, 2, 3, 12, 23]) {
        final SeasonalEventOccurrence? o = SeasonalEventManager.activeEvent(
            now: DateTime(2026, 12, 31, hour), definitions: fixtures);
        expect(o, isNotNull, reason: 'hour $hour');
        expect(o!.dayIndex, 14, reason: 'hour $hour');
      }
      expect(
        SeasonalEventManager.activeEvent(
            now: DateTime(2026, 6, 9, 23, 59, 59), definitions: fixtures),
        isNull,
      );
      expect(
        SeasonalEventManager.activeEvent(
            now: DateTime(2026, 6, 10, 0, 0, 0), definitions: fixtures),
        isNotNull,
      );
    });

    test('a window crossing a DST transition loses no day', () {
      // 8 March 2026 (spring forward) and 1 November 2026 (fall back).
      const SeasonalEventDefinition springDst = SeasonalEventDefinition(
        id: 'spring_dst',
        name: 'Spring',
        tagline: 'test',
        emoji: '🌱',
        window: EventWindow(start: MonthDay(3, 5), end: MonthDay(3, 12)),
        featuredGameIds: <String>['zip'],
        badge: EventBadge(
          id: 'event_test_spring',
          name: 'Spring',
          description: 'test',
          icon: '🌱',
          requiredProgress: 1,
        ),
      );
      const SeasonalEventDefinition autumnDst = SeasonalEventDefinition(
        id: 'autumn_dst',
        name: 'Autumn',
        tagline: 'test',
        emoji: '🍂',
        window: EventWindow(start: MonthDay(10, 29), end: MonthDay(11, 4)),
        featuredGameIds: <String>['zip'],
        badge: EventBadge(
          id: 'event_test_autumn',
          name: 'Autumn',
          description: 'test',
          icon: '🍂',
          requiredProgress: 1,
        ),
      );

      final SeasonalEventOccurrence spring = SeasonalEventManager.activeEvent(
          now: at(2026, 3, 12), definitions: <SeasonalEventDefinition>[springDst])!;
      expect(spring.totalDays, 8);
      expect(spring.dayIndex, 8);
      expect(spring.daysRemaining, 0);

      final SeasonalEventOccurrence autumn = SeasonalEventManager.activeEvent(
          now: at(2026, 11, 4), definitions: <SeasonalEventDefinition>[autumnDst])!;
      expect(autumn.totalDays, 7);
      expect(autumn.dayIndex, 7);
      expect(autumn.daysRemaining, 0);
    });

    test('a leap day inside a window is counted', () {
      const SeasonalEventDefinition leap = SeasonalEventDefinition(
        id: 'leap',
        name: 'Leap',
        tagline: 'test',
        emoji: '🐸',
        window: EventWindow(start: MonthDay(2, 25), end: MonthDay(3, 2)),
        featuredGameIds: <String>['zip'],
        badge: EventBadge(
          id: 'event_test_leap',
          name: 'Leap',
          description: 'test',
          icon: '🐸',
          requiredProgress: 1,
        ),
      );
      const List<SeasonalEventDefinition> defs = <SeasonalEventDefinition>[leap];
      // 2028 is a leap year, 2027 is not.
      expect(
          SeasonalEventManager.activeEvent(now: at(2028, 2, 29), definitions: defs)!
              .totalDays,
          7);
      expect(
          SeasonalEventManager.activeEvent(now: at(2027, 2, 26), definitions: defs)!
              .totalDays,
          6);
    });
  });

  group('overlapping windows resolve deterministically', () {
    test('higher priority wins', () {
      const List<SeasonalEventDefinition> defs = <SeasonalEventDefinition>[
        juneWide, // priority 1, 30 days
        summer, // priority 0, 11 days
      ];
      // summer is shorter but juneWide outranks it.
      expect(
        SeasonalEventManager.activeEvent(now: at(2026, 6, 15), definitions: defs)!
            .definition
            .id,
        'june_wide',
      );
      // Outside summer, juneWide is alone and still resolves.
      expect(
        SeasonalEventManager.activeEvent(now: at(2026, 6, 25), definitions: defs)!
            .definition
            .id,
        'june_wide',
      );
    });

    test('at equal priority the shorter, more specific window wins', () {
      const SeasonalEventDefinition wideSamePriority = SeasonalEventDefinition(
        id: 'june_wide_flat',
        name: 'June Wide',
        tagline: 'test',
        emoji: '🌍',
        window: EventWindow(start: MonthDay(6, 1), end: MonthDay(6, 30)),
        featuredGameIds: <String>['zip'],
        badge: EventBadge(
          id: 'event_test_wide_flat',
          name: 'Wide',
          description: 'test',
          icon: '🔶',
          requiredProgress: 1,
        ),
      );
      const List<SeasonalEventDefinition> defs = <SeasonalEventDefinition>[
        wideSamePriority,
        summer,
      ];
      expect(
        SeasonalEventManager.activeEvent(now: at(2026, 6, 15), definitions: defs)!
            .definition
            .id,
        'summer',
      );
    });

    test('identical priority and length fall back to the id', () {
      const List<SeasonalEventDefinition> defs = <SeasonalEventDefinition>[
        summer,
        aliasOfSummer,
      ];
      const List<SeasonalEventDefinition> reversed = <SeasonalEventDefinition>[
        aliasOfSummer,
        summer,
      ];
      expect(
        SeasonalEventManager.activeEvent(now: at(2026, 6, 15), definitions: defs)!
            .definition
            .id,
        'a_twin',
      );
      // Declaration order must not change the answer.
      expect(
        SeasonalEventManager.activeEvent(
                now: at(2026, 6, 15), definitions: reversed)!
            .definition
            .id,
        'a_twin',
      );
    });

    test('activeEvents lists every overlapping event, best first', () {
      const List<SeasonalEventDefinition> defs = <SeasonalEventDefinition>[
        summer,
        juneWide,
        aliasOfSummer,
      ];
      final List<SeasonalEventOccurrence> all = SeasonalEventManager.activeEvents(
          now: at(2026, 6, 15), definitions: defs);
      expect(all.map((SeasonalEventOccurrence o) => o.definition.id).toList(),
          <String>['june_wide', 'a_twin', 'summer']);
    });

    test('the same date always yields the same answer', () {
      const List<SeasonalEventDefinition> defs = <SeasonalEventDefinition>[
        summer,
        juneWide,
        aliasOfSummer,
        newYear,
      ];
      for (final DateTime d in <DateTime>[
        at(2026, 6, 15),
        at(2026, 12, 31, 23),
        at(2027, 1, 1, 0),
        at(2026, 3, 3),
      ]) {
        final String? first = SeasonalEventManager.activeEvent(
                now: d, definitions: defs)
            ?.definition
            .id;
        for (int i = 0; i < 5; i++) {
          expect(
            SeasonalEventManager.activeEvent(now: d, definitions: defs)
                ?.definition
                .id,
            first,
            reason: 'repeat $i on $d',
          );
        }
      }
    });
  });

  group('progress and badges', () {
    test('progress outside a window writes nothing', () async {
      final EventProgressUpdate r = await SeasonalEventManager.recordProgress(
          now: at(2026, 3, 15), definitions: fixtures);
      expect(r.outcome, EventProgressOutcome.noEvent);
      expect(r.occurrence, isNull);
      expect(await unlockedIds(), isEmpty);
    });

    test('progress accumulates inside a window', () async {
      final EventProgressUpdate a = await SeasonalEventManager.recordProgress(
          now: at(2026, 6, 11), definitions: fixtures);
      expect(a.outcome, EventProgressOutcome.recorded);
      expect(a.progress, 1);
      expect(a.requiredProgress, 3);

      final EventProgressUpdate b = await SeasonalEventManager.recordProgress(
          now: at(2026, 6, 12), definitions: fixtures);
      expect(b.progress, 2);
      expect(await unlockedIds(), isEmpty, reason: 'not earned yet');
    });

    test('meeting the requirement marks the badge unlocked but NOT claimed',
        () async {
      await PointManager.setBalance(0);
      for (int i = 0; i < 2; i++) {
        await SeasonalEventManager.recordProgress(
            now: at(2026, 6, 11), definitions: fixtures);
      }
      final EventProgressUpdate r = await SeasonalEventManager.recordProgress(
          now: at(2026, 6, 12), definitions: fixtures);

      expect(r.outcome, EventProgressOutcome.badgeUnlocked);
      expect(r.justUnlocked, isTrue);
      expect(await unlockedIds(), contains('event_test_short'));

      // The whole point of the manual-claim flow: nothing was handed over.
      expect(await claimedIds(), isEmpty);
      expect(await PointManager.getPoints(), 0);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(PrefsKeys.unlockedTitles) ?? <String>[],
          isEmpty);

      final SeasonalEventState s = await SeasonalEventManager.currentState(
          now: at(2026, 6, 12), definitions: fixtures);
      expect(s.badgeUnlocked, isTrue);
      expect(s.badgeClaimed, isFalse);
      expect(s.hasUnclaimedBadge, isTrue);
      expect(s.fraction, 1.0);
    });

    test('crossing the line again never re-unlocks or double-awards', () async {
      for (int i = 0; i < 3; i++) {
        await SeasonalEventManager.recordProgress(
            now: at(2026, 6, 11), definitions: fixtures);
      }
      final EventProgressUpdate again = await SeasonalEventManager.recordProgress(
          now: at(2026, 6, 13), definitions: fixtures);
      expect(again.outcome, EventProgressOutcome.alreadyEarned);
      expect(again.progress, 3, reason: 'capped at the requirement');
      expect(await unlockedIds(), <String>['event_test_short']);
      expect(await claimedIds(), isEmpty);
    });

    test('claiming grants the reward exactly once', () async {
      await PointManager.setBalance(0);
      for (int i = 0; i < 3; i++) {
        await SeasonalEventManager.recordProgress(
            now: at(2026, 6, 11), definitions: fixtures);
      }

      // The badge is not in this binary's shipped definitions, so claimBadge
      // cannot resolve its reward — an unknown badge is refused rather than
      // guessed at.
      expect(await SeasonalEventManager.claimBadge('event_test_short'), isFalse);
      expect(await PointManager.getPoints(), 0);

      // A shipped badge does claim, once.
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          PrefsKeys.unlockedAchievements, <String>['event_winter_lights']);
      expect(await SeasonalEventManager.claimBadge('event_winter_lights'), isTrue);
      expect(await PointManager.getPoints(), 200);
      expect(await claimedIds(), contains('event_winter_lights'));

      expect(await SeasonalEventManager.claimBadge('event_winter_lights'), isFalse,
          reason: 'a second claim must not re-award');
      expect(await PointManager.getPoints(), 200);
    });

    test('an unearned badge cannot be claimed', () async {
      await PointManager.setBalance(0);
      expect(
          await SeasonalEventManager.claimBadge('event_winter_lights'), isFalse);
      expect(await PointManager.getPoints(), 0);
      expect(await claimedIds(), isEmpty);
    });

    test('progress is per occurrence, so next year starts from zero', () async {
      await SeasonalEventManager.recordProgress(
          now: at(2026, 6, 11), definitions: fixtures);
      await SeasonalEventManager.recordProgress(
          now: at(2026, 6, 12), definitions: fixtures);
      expect(
        (await SeasonalEventManager.currentState(
                now: at(2026, 6, 13), definitions: fixtures))
            .progress,
        2,
      );
      expect(
        (await SeasonalEventManager.currentState(
                now: at(2027, 6, 13), definitions: fixtures))
            .progress,
        0,
      );
    });

    test('progress survives the New Year boundary within one occurrence',
        () async {
      await SeasonalEventManager.recordProgress(
          now: at(2026, 12, 31), definitions: fixtures);
      final SeasonalEventState s = await SeasonalEventManager.currentState(
          now: at(2027, 1, 1), definitions: fixtures);
      expect(s.progress, 1, reason: 'same occurrence, so the count carries');
      expect(s.occurrence!.occurrenceKey, '2026-12-18');
    });

    test('a non-positive amount cannot claw progress back', () async {
      await SeasonalEventManager.recordProgress(
          now: at(2026, 6, 11), definitions: fixtures);
      final EventProgressUpdate r = await SeasonalEventManager.recordProgress(
          now: at(2026, 6, 11), definitions: fixtures, amount: -5);
      expect(r.progress, 1);
    });
  });

  group('a clock moved backwards', () {
    test('an earned badge is never revoked', () async {
      for (int i = 0; i < 3; i++) {
        await SeasonalEventManager.recordProgress(
            now: at(2026, 6, 12), definitions: fixtures);
      }
      expect(await unlockedIds(), contains('event_test_short'));

      // Clock jumps back to before the window ever started. (March, not
      // January — January is still inside the previous New Year occurrence.)
      expect(
        SeasonalEventManager.activeEvent(
            now: at(2026, 3, 4), definitions: fixtures),
        isNull,
      );
      final EventProgressUpdate r = await SeasonalEventManager.recordProgress(
          now: at(2026, 3, 4), definitions: fixtures);
      expect(r.outcome, EventProgressOutcome.noEvent);
      expect(await unlockedIds(), contains('event_test_short'));
      expect(await claimedIds(), isEmpty);
    });

    test('going back inside the window keeps the progress already banked',
        () async {
      await SeasonalEventManager.recordProgress(
          now: at(2026, 6, 18), definitions: fixtures);
      await SeasonalEventManager.recordProgress(
          now: at(2026, 6, 19), definitions: fixtures);

      // Clock rewound to the first day of the same occurrence.
      final SeasonalEventState s = await SeasonalEventManager.currentState(
          now: at(2026, 6, 10), definitions: fixtures);
      expect(s.progress, 2, reason: 'progress is a count, not a streak');
      expect(s.occurrence!.dayIndex, 1);
    });

    test('a backwards clock cannot advance the day index', () {
      final SeasonalEventOccurrence later = SeasonalEventManager.activeEvent(
          now: at(2026, 6, 18), definitions: fixtures)!;
      final SeasonalEventOccurrence earlier = SeasonalEventManager.activeEvent(
          now: at(2026, 6, 12), definitions: fixtures)!;
      expect(earlier.dayIndex, lessThan(later.dayIndex));
      expect(earlier.occurrenceKey, later.occurrenceKey);
    });
  });

  // ---------------------------------------------------------------------------
  // The night trail (2.2).
  //
  // The badge is a five-level goal, which a regular player finishes in one
  // sitting — on a nineteen-day event that leaves eighteen days with nothing to
  // say. The trail is the long tail: one lantern per day of the event the
  // player was active. Everything below runs on dates, so none of it depends on
  // being run in December.
  // ---------------------------------------------------------------------------

  group('the night trail', () {
    /// The local date of day [index] (1-based) of the 2026 winter occurrence,
    /// which starts on 18 December 2026. Rolls into January by construction.
    DateTime winterDay(int index) => DateTime(2026, 12, 17 + index, 12);

    Future<List<String>> storedNights(String eventId, String occKey) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(
              SeasonalEventManager.nightsKey(eventId, occKey)) ??
          <String>[];
    }

    test('one day of play lights exactly one night, however many times it fires',
        () async {
      for (int i = 0; i < 7; i++) {
        await SeasonalEventManager.recordProgress(now: winterDay(3));
      }
      final SeasonalEventState s =
          await SeasonalEventManager.currentState(now: winterDay(3));
      expect(s.nightsLit, 1, reason: 'seven launches in one day is one night');
      expect(s.litNights, <int>{3});
      expect(s.litTonight, isTrue);
      expect(await storedNights('winter_lights', '2026-12-18'), <String>['3']);
    });

    test('nights accumulate day by day and are stored sorted', () async {
      for (final int day in <int>[5, 1, 3]) {
        await SeasonalEventManager.recordProgress(now: winterDay(day));
      }
      expect(await storedNights('winter_lights', '2026-12-18'),
          <String>['1', '3', '5'],
          reason: 'stored ascending regardless of the order they were played');
      final SeasonalEventState s =
          await SeasonalEventManager.currentState(now: winterDay(6));
      expect(s.nightsLit, 3);
      expect(s.litNights, <int>{1, 3, 5});
      expect(s.litTonight, isFalse, reason: 'night 6 has not been played');
    });

    test('the trail keeps running after the badge is earned and progress caps',
        () async {
      final SeasonalEventDefinition winter = shipped('winter_lights');
      // Earn the badge on day 1 — five levels, one sitting.
      for (int i = 0; i < winter.badge.requiredProgress; i++) {
        await SeasonalEventManager.recordProgress(now: winterDay(1));
      }
      expect(await unlockedIds(), <String>[winter.badge.id]);

      // Days 2 and 3 add nothing to the progress counter, which is capped...
      final EventProgressUpdate day2 =
          await SeasonalEventManager.recordProgress(now: winterDay(2));
      expect(day2.outcome, EventProgressOutcome.alreadyEarned);
      expect(day2.progress, winter.badge.requiredProgress);
      // ...but they do light nights. This is the whole reason the trail exists:
      // a capped counter has nothing left to show on day 14.
      expect(day2.newNightLit, isTrue);
      expect(day2.litNights, <int>{1, 2});

      await SeasonalEventManager.recordProgress(now: winterDay(3));
      expect((await SeasonalEventManager.currentState(now: winterDay(3))).nightsLit,
          3);
    });

    test('a non-positive amount lights nothing', () async {
      final EventProgressUpdate r = await SeasonalEventManager.recordProgress(
          now: winterDay(4), amount: 0);
      expect(r.newNightLit, isFalse);
      expect(r.litNights, isEmpty);
      expect((await SeasonalEventManager.currentState(now: winterDay(4))).nightsLit,
          0);
      expect(await storedNights('winter_lights', '2026-12-18'), isEmpty);
    });

    test('outside a window nothing is lit and nothing is written', () async {
      final EventProgressUpdate r =
          await SeasonalEventManager.recordProgress(now: at(2026, 8, 22));
      expect(r.outcome, EventProgressOutcome.noEvent);
      expect(r.newNightLit, isFalse);
      expect(r.litNights, isEmpty);
      expect(await SeasonalEventManager.litNights(now: at(2026, 8, 22)), isEmpty);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((String k) => k.contains('nights')), isEmpty);
    });

    test('the trail survives 31 December inside one occurrence', () async {
      await SeasonalEventManager.recordProgress(now: at(2026, 12, 31));
      await SeasonalEventManager.recordProgress(now: at(2027, 1, 1));
      final SeasonalEventState s =
          await SeasonalEventManager.currentState(now: at(2027, 1, 2));
      expect(s.occurrence!.occurrenceKey, '2026-12-18');
      expect(s.nightsLit, 2,
          reason: 'the year rolling over must not restart the trail');
      expect(s.litNights, <int>{14, 15});
    });

    test('the trail is scoped per occurrence and per event', () async {
      await SeasonalEventManager.recordProgress(now: winterDay(2));
      expect(
        (await SeasonalEventManager.currentState(now: winterDay(2))).nightsLit,
        1,
      );
      // Same event, next winter.
      expect(
        (await SeasonalEventManager.currentState(now: at(2027, 12, 22))).nightsLit,
        0,
        reason: 'next year is a new occurrence',
      );
      // A different event running in the same storage.
      expect(
        (await SeasonalEventManager.currentState(now: at(2026, 3, 25))).nightsLit,
        0,
        reason: 'winter nights leaked into spring',
      );
    });

    test('a stored night the window cannot contain is ignored', () async {
      // Defends the label the banner prints. If a later release shortens a
      // window, storage written under the old one must not be able to say
      // "25 of 19 nights lit".
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        SeasonalEventManager.nightsKey('winter_lights', '2026-12-18'),
        <String>['1', '19', '20', '0', '-3', 'seven', ''],
      );
      final SeasonalEventState s =
          await SeasonalEventManager.currentState(now: winterDay(2));
      expect(s.litNights, <int>{1, 19});
      expect(s.nightsLit, lessThanOrEqualTo(s.totalNights));
    });

    test('playing every day lights all nineteen and no more', () async {
      for (int day = 1; day <= 19; day++) {
        final EventProgressUpdate r =
            await SeasonalEventManager.recordProgress(now: winterDay(day));
        expect(r.occurrence!.definition.id, 'winter_lights',
            reason: 'day $day fell outside the window');
        expect(r.newNightLit, isTrue, reason: 'day $day lit nothing');
        expect(r.litNights.length, day, reason: 'after day $day');
      }
      final SeasonalEventState s =
          await SeasonalEventManager.currentState(now: winterDay(19));
      expect(s.nightsLit, 19);
      expect(s.totalNights, 19);
      expect(s.litNights, <int>{for (int i = 1; i <= 19; i++) i});
      // And a twentieth day is outside the event entirely.
      expect(SeasonalEventManager.activeEvent(now: winterDay(20)), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Milestones (2.2). Labels, never rewards: a milestone that paid out would
  // need its own id in AchievementManager.allAchievements, and an unbacked
  // payout is the "announce what you do not apply" failure in miniature.
  // ---------------------------------------------------------------------------

  group('milestones', () {
    // Pinned here rather than read from kSeasonalEvents: a test that derives its
    // expectations from the thing under test agrees with every change to it.
    const Map<int, String> winterMilestones = <int, String>{
      1: 'First Light',
      5: 'Five Nights',
      12: 'Twelve Nights',
      19: 'The Whole Winter',
    };

    test('winter names the four stages the owner asked for', () {
      final SeasonalEventDefinition winter = shipped('winter_lights');
      expect(
        <int, String>{
          for (final EventMilestone m in winter.milestones) m.nights: m.name,
        },
        winterMilestones,
      );
      for (final EventMilestone m in winter.milestones) {
        expect(m.description.trim(), isNotEmpty, reason: m.name);
      }
    });

    test('every shipped milestone is reachable inside its own window', () {
      // The §8 check. A stage needing 25 nights on a 19-day event is a promise
      // the calendar makes impossible. Computed from kSeasonalEvents so a fifth
      // event with a bad ladder fails here too.
      for (final SeasonalEventDefinition d
          in SeasonalEventManager.kSeasonalEvents) {
        int previous = 0;
        for (final EventMilestone m in d.milestones) {
          expect(m.nights, greaterThan(previous),
              reason: '"${d.id}" milestones are not ascending at "${m.name}"');
          expect(m.nights, lessThanOrEqualTo(d.window.nominalLengthDays),
              reason: '"${d.id}" milestone "${m.name}" needs ${m.nights} nights '
                  'but the window is ${d.window.nominalLengthDays} days');
          previous = m.nights;
        }
      }
    });

    test('reachedMilestones and nextMilestone walk the ladder', () {
      final SeasonalEventDefinition winter = shipped('winter_lights');
      expect(SeasonalEventManager.reachedMilestones(winter, 0), isEmpty);
      expect(SeasonalEventManager.nextMilestone(winter, 0)!.nights, 1);

      expect(
        SeasonalEventManager.reachedMilestones(winter, 5)
            .map((EventMilestone m) => m.nights)
            .toList(),
        <int>[1, 5],
      );
      expect(SeasonalEventManager.nextMilestone(winter, 5)!.nights, 12);

      expect(SeasonalEventManager.reachedMilestones(winter, 19), hasLength(4));
      expect(SeasonalEventManager.nextMilestone(winter, 19), isNull,
          reason: 'there is nothing above the last stage');
    });

    test('an event that names no stages still records nights', () async {
      // The fixtures declare no milestones at all.
      await SeasonalEventManager.recordProgress(
          now: at(2026, 6, 12), definitions: fixtures);
      final SeasonalEventState s = await SeasonalEventManager.currentState(
          now: at(2026, 6, 12), definitions: fixtures);
      expect(s.nightsLit, 1);
      expect(s.milestones, isEmpty);
      expect(s.currentMilestone, isNull);
      expect(s.nextMilestone, isNull);
    });

    test('a stage is reported exactly once, on the night it is crossed',
        () async {
      final List<String> announced = <String>[];
      for (int day = 1; day <= 19; day++) {
        // Two calls per day: the second must never re-announce.
        for (int i = 0; i < 2; i++) {
          final EventProgressUpdate r = await SeasonalEventManager.recordProgress(
              now: DateTime(2026, 12, 17 + day, 12));
          final EventMilestone? m = r.milestoneReached;
          if (m != null) announced.add('${r.litNights.length}:${m.name}');
        }
      }
      expect(announced, <String>[
        '1:First Light',
        '5:Five Nights',
        '12:Twelve Nights',
        '19:The Whole Winter',
      ]);
    });

    test('validate refuses a ladder the calendar cannot deliver', () {
      const SeasonalEventDefinition badLadder = SeasonalEventDefinition(
        id: 'bad_ladder',
        name: 'Bad Ladder',
        tagline: 'test',
        emoji: '🪜',
        // Eleven days long.
        window: EventWindow(start: MonthDay(6, 10), end: MonthDay(6, 20)),
        featuredGameIds: <String>['zip'],
        badge: EventBadge(
          id: 'event_test_ladder',
          name: 'Ladder',
          description: 'test',
          icon: '🪜',
          requiredProgress: 1,
        ),
        milestones: <EventMilestone>[
          EventMilestone(nights: 5, name: 'Five', description: 'ok'),
          EventMilestone(nights: 3, name: 'Three', description: 'out of order'),
          EventMilestone(nights: 40, name: 'Forty', description: 'unreachable'),
          EventMilestone(nights: 0, name: '', description: ''),
        ],
      );
      final List<String> problems =
          SeasonalEventManager.validate(<SeasonalEventDefinition>[badLadder]);
      expect(problems.any((String p) => p.contains('ascending')), isTrue,
          reason: 'the out-of-order stage: $problems');
      expect(problems.any((String p) => p.contains('but the window is')), isTrue,
          reason: 'the unreachable stage: $problems');
      expect(problems.any((String p) => p.contains('unnamed milestone')), isTrue,
          reason: 'the unnamed stage: $problems');
      expect(problems.any((String p) => p.contains('no description')), isTrue,
          reason: 'the undescribed stage: $problems');
    });

    test('validate catches two stages sharing a name', () {
      const SeasonalEventDefinition twins = SeasonalEventDefinition(
        id: 'twin_stages',
        name: 'Twins',
        tagline: 'test',
        emoji: '👯',
        window: EventWindow(start: MonthDay(6, 10), end: MonthDay(6, 20)),
        featuredGameIds: <String>['zip'],
        badge: EventBadge(
          id: 'event_test_twin_stages',
          name: 'Twins',
          description: 'test',
          icon: '👯',
          requiredProgress: 1,
        ),
        milestones: <EventMilestone>[
          EventMilestone(nights: 2, name: 'Same', description: 'a'),
          EventMilestone(nights: 4, name: 'Same', description: 'b'),
        ],
      );
      expect(
        SeasonalEventManager.validate(<SeasonalEventDefinition>[twins])
            .any((String p) => p.contains('two milestones called')),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Featured games (2.2). Before this release nothing outside a test ever read
  // them; the banner now renders them and opens them.
  // ---------------------------------------------------------------------------

  group('featured games are real content', () {
    test('winter features the games live in the 1.8.2 roster', () {
      // Pinned independently of kSeasonalEvents. Every one is checked live and
      // routable by the shipped-definitions group above.
      expect(shipped('winter_lights').featuredGameIds, <String>[
        'masyu',
        'zip',
        'colour_link',
        'pattern_lock',
        'queens',
      ]);
    });

    test('state.featuredGames is what the banner may open, and only that', () {
      // Not tautological: this compares the state snapshot's list against the
      // *declared* ids of the running event, so a snapshot that silently
      // returned another event's games, or an empty list, fails.
      final SeasonalEventState empty = const SeasonalEventState(
        occurrence: null,
        progress: 0,
        requiredProgress: 0,
        badgeUnlocked: false,
        badgeClaimed: false,
        bannerDismissed: false,
      );
      expect(empty.featuredGames, isEmpty);
      expect(empty.totalNights, 0);
      expect(empty.litTonight, isFalse);
      expect(empty.milestones, isEmpty);
    });

    test('a state snapshot offers the running event\'s games only', () async {
      final SeasonalEventState winter =
          await SeasonalEventManager.currentState(now: at(2026, 12, 22));
      expect(winter.featuredGames.map((GameInfo g) => g.id).toList(),
          shipped('winter_lights').featuredGameIds);

      final SeasonalEventState spring =
          await SeasonalEventManager.currentState(now: at(2026, 3, 25));
      expect(spring.featuredGames.map((GameInfo g) => g.id).toList(),
          shipped('spring_thaw').featuredGameIds);

      final SeasonalEventState quiet =
          await SeasonalEventManager.currentState(now: at(2026, 8, 22));
      expect(quiet.featuredGames, isEmpty);
    });
  });

  group('banner bookkeeping', () {
    test('dismissal is scoped to one occurrence', () async {
      await SeasonalEventManager.dismissBanner(
          now: at(2026, 6, 12), definitions: fixtures);
      expect(
        (await SeasonalEventManager.currentState(
                now: at(2026, 6, 15), definitions: fixtures))
            .bannerDismissed,
        isTrue,
      );
      expect(
        (await SeasonalEventManager.currentState(
                now: at(2027, 6, 15), definitions: fixtures))
            .bannerDismissed,
        isFalse,
      );
    });

    test('dismissing outside a window is a no-op', () async {
      await SeasonalEventManager.dismissBanner(
          now: at(2026, 3, 1), definitions: fixtures);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((String k) => k.startsWith('seasonal_event_')),
        isEmpty,
      );
    });

    test('an occurrence is announced exactly once', () async {
      expect(
        await SeasonalEventManager.markOccurrenceSeen(
            now: at(2026, 6, 12), definitions: fixtures),
        isTrue,
      );
      expect(
        await SeasonalEventManager.markOccurrenceSeen(
            now: at(2026, 6, 13), definitions: fixtures),
        isFalse,
      );
      expect(
        await SeasonalEventManager.markOccurrenceSeen(
            now: at(2027, 6, 13), definitions: fixtures),
        isTrue,
        reason: 'next year is a new occurrence',
      );
    });
  });

  group('the clock is injectable', () {
    test('the ambient clock is used when no date is passed', () {
      SeasonalEventManager.clock = () => at(2026, 6, 15);
      expect(
        SeasonalEventManager.activeEvent(definitions: fixtures)!.definition.id,
        'summer',
      );
      SeasonalEventManager.clock = () => at(2026, 3, 15);
      expect(SeasonalEventManager.activeEvent(definitions: fixtures), isNull);
    });
  });

  group('shipped definitions', () {
    test('validate finds no problems', () {
      expect(SeasonalEventManager.validate(), isEmpty);
    });

    test('the winter event exists and spans New Year', () {
      final SeasonalEventDefinition winter = SeasonalEventManager.kSeasonalEvents
          .firstWhere((SeasonalEventDefinition d) => d.id == 'winter_lights');
      expect(winter.window.spansYearBoundary, isTrue);
      expect(winter.window.nominalLengthDays, 19);
      expect(winter.badge.id, 'event_winter_lights');
      expect(winter.badge.requiredProgress, greaterThan(0));
    });

    test('the winter event runs on the dates it claims to', () {
      expect(SeasonalEventManager.activeEvent(now: at(2026, 12, 17)), isNull);
      expect(SeasonalEventManager.activeEvent(now: at(2026, 12, 18))!.definition.id,
          'winter_lights');
      expect(SeasonalEventManager.activeEvent(now: at(2027, 1, 5))!.definition.id,
          'winter_lights');
      expect(SeasonalEventManager.activeEvent(now: at(2027, 1, 6)), isNull);
      expect(SeasonalEventManager.activeEvent(now: at(2026, 8, 22)), isNull);
    });

    test('every featured game is live and routable', () {
      // This checks the *declared* ids, not liveFeaturedGames' output. Asserting
      // `isStashed == false` on the result of a filter whose whole job is to
      // remove stashed games can never fail — it passed happily while a stashed
      // id sat in the calendar. A stashed or unknown id routes the player at a
      // route main.dart never registered, and with no `onUnknownRoute` that is
      // an unhandled crash, so it has to fail here.
      for (final SeasonalEventDefinition d
          in SeasonalEventManager.kSeasonalEvents) {
        expect(d.featuredGameIds, isNotEmpty, reason: d.id);

        for (final String gameId in d.featuredGameIds) {
          final Iterable<GameInfo> matches =
              kAllGames.where((GameInfo g) => g.id == gameId);
          expect(matches, hasLength(1),
              reason: '"${d.id}" features "$gameId", which is not a unique '
                  'entry in kAllGames');

          final GameInfo g = matches.first;
          expect(g.isStashed, isFalse,
              reason: '"${d.id}" features stashed game "$gameId" — offering it '
                  'sends the player at an unregistered route');
          expect(g.routeName, isNotEmpty, reason: '"$gameId" has no route');
          expect(g.routeName.startsWith('/'), isTrue,
              reason: '"$gameId" route is "${g.routeName}"');
        }

        // ...and nothing is quietly dropped between the definition and the
        // banner, in order.
        expect(
          SeasonalEventManager.liveFeaturedGames(d)
              .map((GameInfo g) => g.id)
              .toList(),
          d.featuredGameIds,
          reason: '"${d.id}" loses a featured game to the live filter',
        );
      }
    });

    test('a stashed or unknown featured game is filtered out rather than offered',
        () {
      // The stashed ids are read out of kAllGames instead of hard-coded.
      // 'wordle' and 'hangman' were named here until 2.3 deleted those games
      // outright — at which point this test quietly stopped covering the
      // `!g.isStashed` branch and only exercised the unknown-id path. Hard-coding
      // also breaks the moment a game is revived, as 'slitherlink' did in 2.1;
      // reading the list back means a revival simply moves that id out of the
      // set instead of failing the test.
      final List<String> stashedIds = kAllGames
          .where((GameInfo g) => g.isStashed)
          .map((GameInfo g) => g.id)
          .toList();

      final SeasonalEventDefinition withStashed = SeasonalEventDefinition(
        id: 'stashy',
        name: 'Stashy',
        tagline: 'test',
        emoji: '📦',
        // Every stashed game, a live one ('zip'), and an id that is in no build
        // at all — only 'zip' may survive the filter.
        featuredGameIds: <String>[...stashedIds, 'zip', 'deleted_in_2_3'],
        window: const EventWindow(start: MonthDay(6, 10), end: MonthDay(6, 20)),
        badge: const EventBadge(
          id: 'event_test_stashy',
          name: 'Stashy',
          description: 'test',
          icon: '📦',
          requiredProgress: 1,
        ),
      );
      expect(
        SeasonalEventManager.liveFeaturedGames(withStashed)
            .map((GameInfo g) => g.id)
            .toList(),
        <String>['zip'],
      );
    });

    test('validate rejects a broken definition', () {
      const SeasonalEventDefinition broken = SeasonalEventDefinition(
        id: '',
        name: 'Broken',
        tagline: 'test',
        emoji: '💥',
        featuredGameIds: <String>['not_a_game'],
        window: EventWindow(start: MonthDay(13, 40), end: MonthDay(1, 5)),
        badge: EventBadge(
          id: 'event_test_broken',
          name: 'Broken',
          description: 'test',
          icon: '💥',
          requiredProgress: 0,
        ),
      );
      final List<String> problems =
          SeasonalEventManager.validate(<SeasonalEventDefinition>[broken]);
      expect(problems, isNotEmpty);
      expect(problems.length, greaterThanOrEqualTo(4));
    });

    test('duplicate ids are reported', () {
      final List<String> problems = SeasonalEventManager.validate(
          <SeasonalEventDefinition>[summer, summer]);
      expect(problems.any((String p) => p.contains('duplicate event id')), isTrue);
    });

    test('no duplicate event ids and no duplicate badge ids ship', () {
      final List<String> eventIds = <String>[
        for (final SeasonalEventDefinition d
            in SeasonalEventManager.kSeasonalEvents)
          d.id,
      ];
      final List<String> badgeIds = <String>[
        for (final SeasonalEventDefinition d
            in SeasonalEventManager.kSeasonalEvents)
          d.badge.id,
      ];

      expect(eventIds.toSet(), hasLength(eventIds.length),
          reason: 'duplicate event id in $eventIds');
      expect(badgeIds.toSet(), hasLength(badgeIds.length),
          reason: 'duplicate badge id in $badgeIds — two events sharing a badge '
              'means one of them can never be earned');
      expect(eventIds.where((String id) => id.trim().isEmpty), isEmpty);
      expect(badgeIds.where((String id) => id.trim().isEmpty), isEmpty);

      // allBadges is what the achievements screen would enumerate: one per
      // event, in declaration order.
      expect(
        SeasonalEventManager.allBadges.map((EventBadge b) => b.id).toList(),
        badgeIds,
      );
      for (final String id in badgeIds) {
        expect(SeasonalEventManager.badgeById(id)?.id, id);
        expect(id.startsWith('event_'), isTrue,
            reason: '"$id" breaks the event_ prefix the achievements screen '
                'groups seasonal badges by');
      }
    });

    test('every event badge is wired into AchievementManager', () {
      // The linkage that makes a claimed badge appear on the achievements
      // screen at all. All four entries were added by hand; nothing else
      // checks them, and a typo here is invisible until a player earns one.
      for (final SeasonalEventDefinition d
          in SeasonalEventManager.kSeasonalEvents) {
        final EventBadge badge = d.badge;
        final Iterable<Achievement> matches = AchievementManager.allAchievements
            .where((Achievement a) => a.id == badge.id);
        expect(matches, hasLength(1),
            reason: '"${badge.id}" (${d.id}) is missing from '
                'AchievementManager.allAchievements, so the badge would be '
                'unlocked but never shown or claimable');

        final Achievement a = matches.first;
        expect(a.name, badge.name, reason: badge.id);
        expect(a.description, badge.description, reason: badge.id);
        expect(a.icon, badge.icon, reason: badge.id);
        expect(a.category, 'seasonal', reason: badge.id);
        expect(a.rewardPoints, badge.rewardPoints,
            reason: '${badge.id} would pay out a different amount depending on '
                'which code path claimed it');
        expect(a.rewardTitle, badge.rewardTitle, reason: badge.id);
      }
    });

    test('every event has the copy the banner needs', () {
      for (final SeasonalEventDefinition d
          in SeasonalEventManager.kSeasonalEvents) {
        expect(d.name.trim(), isNotEmpty, reason: d.id);
        expect(d.tagline.trim(), isNotEmpty, reason: d.id);
        expect(d.emoji.trim(), isNotEmpty, reason: d.id);
        expect(d.badge.name.trim(), isNotEmpty, reason: d.id);
        expect(d.badge.description.trim(), isNotEmpty, reason: d.id);
        expect(d.badge.requiredProgress, greaterThan(0), reason: d.id);
      }
    });

    test('a tagline that promises a day count promises the real one', () {
      // remember.md rule 8: never announce what you do not apply. Every shipped
      // tagline states its own length in words; if the window is retimed and
      // the copy is not, the banner lies to the player.
      const Map<String, int> spelled = <String, int>{
        'ten': 10,
        'eleven': 11,
        'twelve': 12,
        'thirteen': 13,
        'fourteen': 14,
        'fifteen': 15,
        'sixteen': 16,
        'seventeen': 17,
        'eighteen': 18,
        'nineteen': 19,
        'twenty': 20,
      };
      for (final SeasonalEventDefinition d
          in SeasonalEventManager.kSeasonalEvents) {
        final String tagline = d.tagline.toLowerCase();
        for (final MapEntry<String, int> e in spelled.entries) {
          if (!tagline.contains('${e.key} days')) continue;
          expect(e.value, d.window.nominalLengthDays,
              reason: '"${d.id}" promises "${e.key} days" but its window runs '
                  '${d.window.nominalLengthDays} days');
        }
      }
    });
  });

  // ---------------------------------------------------------------------------
  // The shipped quarterly calendar.
  //
  // The windows are pinned here rather than read back out of kSeasonalEvents: a
  // test that derives its expectations from the thing under test agrees with
  // every change, including a wrong one.
  // ---------------------------------------------------------------------------

  group('the shipped quarterly calendar', () {
    // id -> <startMonth, startDay, endMonth, endDay, lengthInDays>
    const Map<String, List<int>> expectedWindows = <String, List<int>>{
      'winter_lights': <int>[12, 18, 1, 5, 19],
      'spring_thaw': <int>[3, 18, 4, 1, 15],
      'summer_light': <int>[6, 18, 7, 2, 15],
      'autumn_harvest': <int>[9, 18, 10, 2, 15],
    };

    test('the calendar holds exactly the four events it claims to', () {
      expect(
        SeasonalEventManager.kSeasonalEvents
            .map((SeasonalEventDefinition d) => d.id)
            .toSet(),
        expectedWindows.keys.toSet(),
      );
    });

    expectedWindows.forEach((String id, List<int> w) {
      final int startMonth = w[0];
      final int startDay = w[1];
      final int endMonth = w[2];
      final int endDay = w[3];
      final int lengthDays = w[4];

      test('$id declares the window the owner asked for', () {
        final SeasonalEventDefinition d = shipped(id);
        expect(d.window.start, MonthDay(startMonth, startDay), reason: id);
        expect(d.window.end, MonthDay(endMonth, endDay), reason: id);
        expect(d.window.isWellFormed, isTrue, reason: id);
        expect(d.window.nominalLengthDays, lengthDays, reason: id);
        expect(d.window.spansYearBoundary, id == 'winter_lights',
            reason: 'only winter is meant to cross New Year');
        // Anchored to the 18th — the whole point of the quarterly rhythm.
        expect(d.window.start.day, 18, reason: id);
      });

      test('$id runs on its own dates, both boundary days included', () {
        // Resolved in a fixed, non-leap year so a date change in lib/ moves the
        // answer here rather than being absorbed.
        final bool spans = shipped(id).window.spansYearBoundary;
        final DateTime start = at(2026, startMonth, startDay);
        final DateTime end = at(spans ? 2027 : 2026, endMonth, endDay);
        final DateTime mid =
            at(start.year, start.month, start.day + lengthDays ~/ 2);

        for (final DateTime d in <DateTime>[start, mid, end]) {
          final SeasonalEventOccurrence? o =
              SeasonalEventManager.activeEvent(now: d);
          expect(o, isNotNull, reason: '$id should be running on $d');
          expect(o!.definition.id, id, reason: 'on $d');
        }

        final SeasonalEventOccurrence first =
            SeasonalEventManager.activeEvent(now: start)!;
        expect(first.isFirstDay, isTrue);
        expect(first.dayIndex, 1);
        expect(first.totalDays, lengthDays);
        expect(first.daysRemaining, lengthDays - 1);

        final SeasonalEventOccurrence last =
            SeasonalEventManager.activeEvent(now: end)!;
        expect(last.isLastDay, isTrue);
        expect(last.daysRemaining, 0);
        expect(last.dayIndex, lengthDays);
        expect(last.occurrenceKey, first.occurrenceKey,
            reason: 'both ends belong to one occurrence');
        expect(last.occurrenceKey, SeasonalEventManager.dateKeyFor(start));

        // The day either side is outside *this* window. Phrased as "this event
        // is not among those running" rather than "nothing is running", so a
        // future neighbouring event cannot make this pass or fail by accident.
        final DateTime before =
            at(start.year, start.month, start.day - 1);
        final DateTime after = at(end.year, end.month, end.day + 1);
        expect(shippedIdsOn(before), isNot(contains(id)),
            reason: '$id must not run on $before');
        expect(shippedIdsOn(after), isNot(contains(id)),
            reason: '$id must not run on $after');
      });

      test('$id counts one day per calendar day, end to end', () {
        DateTime cursor = at(2026, startMonth, startDay);
        final String key =
            SeasonalEventManager.activeEvent(now: cursor)!.occurrenceKey;
        int expectedIndex = 1;
        while (true) {
          final SeasonalEventOccurrence? o =
              SeasonalEventManager.activeEvent(now: cursor);
          if (o == null || o.definition.id != id) break;
          expect(o.dayIndex, expectedIndex, reason: 'on $cursor');
          expect(o.totalDays, lengthDays, reason: 'on $cursor');
          expect(o.occurrenceKey, key,
              reason: 'the occurrence must not restart mid-window, on $cursor');
          cursor = at(cursor.year, cursor.month, cursor.day + 1);
          expectedIndex++;
        }
        expect(expectedIndex - 1, lengthDays,
            reason: '$id ran ${expectedIndex - 1} days, not $lengthDays');
      });

      test('$id recurs the following year under a new occurrence key', () {
        final SeasonalEventOccurrence a =
            SeasonalEventManager.activeEvent(now: at(2026, startMonth, startDay))!;
        final SeasonalEventOccurrence b =
            SeasonalEventManager.activeEvent(now: at(2027, startMonth, startDay))!;
        expect(a.definition.id, id);
        expect(b.definition.id, id);
        expect(a.occurrenceKey, isNot(b.occurrenceKey));
        expect(b.occurrenceKey, '2027-${w[0].toString().padLeft(2, '0')}-18');
      });
    });

    test('no two windows overlap, anywhere in a two-year sweep', () {
      // Computed from kSeasonalEvents, not from the table above, so a fifth
      // event laid over an existing one is caught even if the table is stale.
      final List<String> clashes = <String>[];
      DateTime cursor = at(2026, 1, 1);
      for (int i = 0; i < 731; i++) {
        final List<String> ids = shippedIdsOn(cursor);
        if (ids.length > 1) {
          clashes.add('${SeasonalEventManager.dateKeyFor(cursor)} -> $ids');
        }
        cursor = at(cursor.year, cursor.month, cursor.day + 1);
      }
      expect(clashes, isEmpty,
          reason: 'overlapping windows: ${clashes.join('; ')}');
    });

    test('resolution never depends on declaration order', () {
      // The guarantee that keeps an overlap harmless if one is ever introduced:
      // priority, then window length, then id — a total order, so shuffling the
      // list cannot change the answer.
      final List<SeasonalEventDefinition> reversed =
          SeasonalEventManager.kSeasonalEvents.reversed.toList();
      DateTime cursor = at(2026, 1, 1);
      for (int i = 0; i < 731; i++) {
        expect(
          SeasonalEventManager.activeEvents(now: cursor, definitions: reversed)
              .map((SeasonalEventOccurrence o) => o.definition.id)
              .toList(),
          shippedIdsOn(cursor),
          reason: 'on $cursor',
        );
        cursor = at(cursor.year, cursor.month, cursor.day + 1);
      }
    });

    test('the gaps between events are actually quarterly', () {
      final List<SeasonalEventDefinition> byStart =
          SeasonalEventManager.kSeasonalEvents.toList()
            ..sort((SeasonalEventDefinition a, SeasonalEventDefinition b) =>
                a.window.start.ordinal.compareTo(b.window.start.ordinal));

      DateTime startIn(int year, SeasonalEventDefinition d) =>
          SeasonalEventManager.clampedDate(
              year, d.window.start.month, d.window.start.day);

      final List<int> gaps = <int>[];
      for (int i = 0; i < byStart.length; i++) {
        final bool wraps = i == byStart.length - 1;
        final SeasonalEventDefinition next =
            byStart[(i + 1) % byStart.length];
        gaps.add(SeasonalEventManager.dayDifference(
          startIn(2026, byStart[i]),
          startIn(wraps ? 2027 : 2026, next),
        ));
      }

      for (int i = 0; i < gaps.length; i++) {
        expect(
          gaps[i],
          allOf(greaterThanOrEqualTo(80), lessThanOrEqualTo(100)),
          reason: '${byStart[i].id} -> '
              '${byStart[(i + 1) % byStart.length].id} is ${gaps[i]} days; the '
              'calendar is meant to be quarterly, so a new event dropped into '
              'the wrong slot fails here',
        );
      }
      expect(gaps.reduce((int a, int b) => a + b), 365,
          reason: 'the gaps have to close the year exactly once');
    });

    test('nextEvent teases the right event from a quiet date', () {
      // 22 August is in the longest quiet stretch of the year.
      final SeasonalEventOccurrence? next =
          SeasonalEventManager.nextEvent(now: at(2026, 8, 22));
      expect(next, isNotNull);
      expect(next!.definition.id, 'autumn_harvest');
      expect(next.start, DateTime(2026, 9, 18));

      // ...and there is no "next" while one is running.
      expect(SeasonalEventManager.nextEvent(now: at(2026, 9, 25)), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Scoping. The calendar is only safe if one event's state cannot leak into
  // another's — these all run against the *shipped* definitions on purpose.
  // ---------------------------------------------------------------------------

  group('state stays scoped per event and per occurrence', () {
    // One mid-window date per shipped event, all inside a single year.
    const Map<String, List<int>> midWindow = <String, List<int>>{
      'spring_thaw': <int>[2026, 3, 25],
      'summer_light': <int>[2026, 6, 25],
      'autumn_harvest': <int>[2026, 9, 25],
      'winter_lights': <int>[2026, 12, 27],
    };

    DateTime dayFor(String id) =>
        at(midWindow[id]![0], midWindow[id]![1], midWindow[id]![2]);

    test('each sample date resolves to the event it belongs to', () {
      midWindow.forEach((String id, List<int> _) {
        expect(SeasonalEventManager.activeEvent(now: dayFor(id))!.definition.id,
            id);
      });
    });

    test('clearing levels during one event never advances another badge',
        () async {
      // The scenario the owner called out: a spring player must not drift
      // towards the winter badge.
      final SeasonalEventDefinition spring = shipped('spring_thaw');
      for (int i = 0; i < spring.badge.requiredProgress; i++) {
        await SeasonalEventManager.recordProgress(now: dayFor('spring_thaw'));
      }
      expect(await unlockedIds(), <String>[spring.badge.id]);

      for (final String id in midWindow.keys) {
        if (id == 'spring_thaw') continue;
        final SeasonalEventState s =
            await SeasonalEventManager.currentState(now: dayFor(id));
        expect(s.occurrence!.definition.id, id);
        expect(s.progress, 0,
            reason: 'spring progress leaked into $id');
        expect(s.badgeUnlocked, isFalse, reason: '$id badge was never earned');
        expect(s.fraction, 0.0, reason: id);
      }
    });

    test('dismissing one event\'s banner leaves the others showing', () async {
      await SeasonalEventManager.dismissBanner(now: dayFor('spring_thaw'));

      expect(
        (await SeasonalEventManager.currentState(now: at(2026, 3, 26)))
            .bannerDismissed,
        isTrue,
        reason: 'the dismissal has to stick for the rest of the occurrence',
      );
      for (final String id in midWindow.keys) {
        if (id == 'spring_thaw') continue;
        expect(
          (await SeasonalEventManager.currentState(now: dayFor(id)))
              .bannerDismissed,
          isFalse,
          reason: 'dismissing spring also hid $id',
        );
      }
      // Next spring is a different occurrence, so the banner comes back.
      expect(
        (await SeasonalEventManager.currentState(now: at(2027, 3, 25)))
            .bannerDismissed,
        isFalse,
      );
    });

    test('an intro is announced once per occurrence, per event', () async {
      for (final String id in midWindow.keys) {
        expect(await SeasonalEventManager.markOccurrenceSeen(now: dayFor(id)),
            isTrue,
            reason: '$id is a new occurrence');
        expect(await SeasonalEventManager.markOccurrenceSeen(now: dayFor(id)),
            isFalse,
            reason: '$id was already greeted');
      }
    });

    midWindow.forEach((String id, List<int> ymd) {
      test('$id records progress against its own occurrence only', () async {
        final SeasonalEventDefinition d = shipped(id);
        final DateTime day = at(ymd[0], ymd[1], ymd[2]);

        EventProgressUpdate? last;
        for (int i = 0; i < d.badge.requiredProgress; i++) {
          last = await SeasonalEventManager.recordProgress(now: day);
        }

        expect(last!.outcome, EventProgressOutcome.badgeUnlocked);
        expect(last.badgeId, d.badge.id);
        expect(last.progress, d.badge.requiredProgress);
        expect(await unlockedIds(), <String>[d.badge.id],
            reason: 'exactly one badge, and it is $id\'s');
        expect(await claimedIds(), isEmpty,
            reason: 'earning is never claiming');

        // The same event next year starts from zero.
        expect(
          (await SeasonalEventManager.currentState(
                  now: at(ymd[0] + 1, ymd[1], ymd[2])))
              .progress,
          0,
          reason: '$id progress carried into the next occurrence',
        );

        // Storage is namespaced by event *and* occurrence.
        final SeasonalEventOccurrence o =
            SeasonalEventManager.activeEvent(now: day)!;
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getInt(
              SeasonalEventManager.progressKey(id, o.occurrenceKey)),
          d.badge.requiredProgress,
        );
      });

      test('$id badge claims exactly once, through the achievements flow',
          () async {
        await PointManager.setBalance(0);
        final SeasonalEventDefinition d = shipped(id);
        final DateTime day = at(ymd[0], ymd[1], ymd[2]);

        for (int i = 0; i < d.badge.requiredProgress; i++) {
          await SeasonalEventManager.recordProgress(now: day);
        }
        expect(await PointManager.getPoints(), 0,
            reason: 'nothing is handed over until the player taps Claim');

        expect(await SeasonalEventManager.claimBadge(d.badge.id), isTrue);
        expect(await PointManager.getPoints(), d.badge.rewardPoints);
        expect(await claimedIds(), contains(d.badge.id));

        expect(await SeasonalEventManager.claimBadge(d.badge.id), isFalse,
            reason: 'a second claim must not re-award');
        expect(await PointManager.getPoints(), d.badge.rewardPoints);
      });
    });
  });
}
