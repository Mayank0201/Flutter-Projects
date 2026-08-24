import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cogniq/utils/achievement_manager.dart';
import 'package:cogniq/utils/prefs_keys.dart';
import 'package:cogniq/utils/streak_manager.dart';

/// S1 — streak depth.
///
/// Every test drives the manager with explicit dates. `DateTime.now()` is never
/// consulted, so a run at 23:59 behaves exactly like a run at noon, and day
/// boundaries, month boundaries and a clock moved backwards are all reachable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  DateTime day(int y, int m, int d, [int hour = 12]) => DateTime(y, m, d, hour);

  Future<int> storedStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(StreakManager.activeStreakKey) ?? 0;
  }

  /// Plays every day from [start] for [days] days.
  Future<StreakUpdate> playConsecutive(DateTime start, int days) async {
    late StreakUpdate last;
    for (int i = 0; i < days; i++) {
      last = await StreakManager.recordActivity(
        now: start.add(Duration(days: i)),
      );
    }
    return last;
  }

  group('first launch', () {
    test('the very first play starts a streak of 1', () async {
      final r = await StreakManager.recordActivity(now: day(2026, 8, 22));
      expect(r.event, StreakEvent.firstDay);
      expect(r.streak, 1);
      expect(r.previousStreak, 0);
      expect(r.skipConsumed, isFalse);
      expect(await storedStreak(), 1);
    });

    test('with no history at all the state reads as an empty streak', () async {
      final s = await StreakManager.currentState(now: day(2026, 8, 22));
      expect(s.streak, 0);
      expect(s.playedToday, isFalse);
      expect(s.lastActiveDate, isNull);
      expect(s.skipAvailable, isTrue);
    });

    test('corrupt stored date degrades to a fresh start, not a crash', () async {
      SharedPreferences.setMockInitialValues({
        StreakManager.lastActiveDateKey: 'not-a-date',
        StreakManager.activeStreakKey: 9,
      });
      final r = await StreakManager.recordActivity(now: day(2026, 8, 22));
      expect(r.event, StreakEvent.firstDay);
      expect(r.streak, 1);
    });
  });

  group('consecutive days', () {
    test('each new day increments by exactly 1', () async {
      final a = await StreakManager.recordActivity(now: day(2026, 8, 20));
      final b = await StreakManager.recordActivity(now: day(2026, 8, 21));
      final c = await StreakManager.recordActivity(now: day(2026, 8, 22));
      expect(a.streak, 1);
      expect(b.streak, 2);
      expect(b.event, StreakEvent.extended);
      expect(c.streak, 3);
      expect(await storedStreak(), 3);
    });

    test('a day boundary is a calendar change, not 24 elapsed hours', () async {
      // 23:59 then 00:01 the next morning is two minutes apart but two days.
      await StreakManager.recordActivity(now: DateTime(2026, 8, 20, 23, 59));
      final r = await StreakManager.recordActivity(
        now: DateTime(2026, 8, 21, 0, 1),
      );
      expect(r.event, StreakEvent.extended);
      expect(r.streak, 2);
    });

    test('27 hours later on the same calendar day pair still counts once',
        () async {
      // 06:00 Monday -> 09:00 Tuesday is 27 hours: one calendar day, +1.
      await StreakManager.recordActivity(now: DateTime(2026, 8, 20, 6));
      final r = await StreakManager.recordActivity(
        now: DateTime(2026, 8, 21, 9),
      );
      expect(r.streak, 2);
    });

    test('the streak never rises by more than 1 in a day', () async {
      DateTime d = day(2026, 8, 1);
      int previous = 0;
      for (int i = 0; i < 40; i++) {
        final r = await StreakManager.recordActivity(now: d);
        expect(r.streak - previous, lessThanOrEqualTo(1));
        previous = r.streak;
        d = d.add(const Duration(days: 1));
      }
      expect(previous, 40);
    });

    test('a run crosses month and year boundaries cleanly', () async {
      final r = await playConsecutive(day(2026, 12, 28), 8);
      expect(r.streak, 8);
      final s = await StreakManager.currentState(now: day(2027, 1, 4));
      expect(s.streak, 8);
      expect(s.lastActiveDate, '2027-01-04');
    });
  });

  group('same-day double play', () {
    test('a second play on the same day does not double-count', () async {
      await StreakManager.recordActivity(now: day(2026, 8, 20));
      await StreakManager.recordActivity(now: day(2026, 8, 21, 9));
      final r = await StreakManager.recordActivity(now: day(2026, 8, 21, 20));
      expect(r.event, StreakEvent.sameDay);
      expect(r.streak, 2);
      expect(await storedStreak(), 2);
    });

    test('many plays in one day are still one day', () async {
      await StreakManager.recordActivity(now: day(2026, 8, 21, 1));
      for (int h = 2; h < 23; h++) {
        await StreakManager.recordActivity(now: day(2026, 8, 21, h));
      }
      expect(await storedStreak(), 1);
    });
  });

  group('breaking the streak', () {
    test('a gap of two missed days breaks it', () async {
      await playConsecutive(day(2026, 8, 10), 5);
      // Last active 14th; next play on the 17th misses the 15th and 16th.
      final r = await StreakManager.recordActivity(now: day(2026, 8, 17));
      expect(r.event, StreakEvent.broken);
      expect(r.streak, 1);
      expect(r.skipConsumed, isFalse);
      // The skip is untouched: it only rescues a single missed day.
      expect(await StreakManager.isSkipAvailable(now: day(2026, 8, 17)), isTrue);
    });

    test('a long absence breaks it', () async {
      await playConsecutive(day(2026, 8, 1), 20);
      final r = await StreakManager.recordActivity(now: day(2026, 11, 3));
      expect(r.event, StreakEvent.broken);
      expect(r.streak, 1);
    });

    test('the longest-ever streak survives a break', () async {
      await playConsecutive(day(2026, 8, 1), 12);
      final r = await StreakManager.recordActivity(now: day(2026, 9, 20));
      expect(r.streak, 1);
      expect(r.longest, 12);
    });

    test('currentState reports 0 once the streak is beyond rescue', () async {
      await playConsecutive(day(2026, 8, 1), 5);
      // Last active 5 Aug; on 20 Aug there is nothing left to save.
      final s = await StreakManager.currentState(now: day(2026, 8, 20));
      expect(s.streak, 0);
      expect(s.playedToday, isFalse);
    });

    test('reconcile persists a lapse without counting today', () async {
      await playConsecutive(day(2026, 8, 1), 5);
      await StreakManager.reconcile(now: day(2026, 8, 20));
      expect(await storedStreak(), 0);
      final prefs = await SharedPreferences.getInstance();
      // Today was not marked active — only the stale counter was cleared.
      expect(prefs.getString(StreakManager.lastActiveDateKey), '2026-08-05');
    });
  });

  group('streak recovery — one free skip per calendar month', () {
    test('a one-day gap with a skip available survives and spends it',
        () async {
      await playConsecutive(day(2026, 8, 10), 5); // last active 14 Aug
      expect(await StreakManager.isSkipAvailable(now: day(2026, 8, 16)), isTrue);

      // 15 Aug missed; play on the 16th.
      final r = await StreakManager.recordActivity(now: day(2026, 8, 16));
      expect(r.event, StreakEvent.recovered);
      expect(r.streak, 6, reason: 'the streak continues, it does not restart');
      expect(r.skipConsumed, isTrue);
      expect(r.skipAvailable, isFalse);
      expect(
        await StreakManager.isSkipAvailable(now: day(2026, 8, 16)),
        isFalse,
      );
    });

    test('a second one-day gap in the same month breaks the streak', () async {
      await playConsecutive(day(2026, 8, 1), 5); // last active 5 Aug
      final first = await StreakManager.recordActivity(now: day(2026, 8, 7));
      expect(first.event, StreakEvent.recovered);
      expect(first.streak, 6);

      // Miss the 8th, play on the 9th — no skip left this month.
      final second = await StreakManager.recordActivity(now: day(2026, 8, 9));
      expect(second.event, StreakEvent.broken);
      expect(second.streak, 1);
      expect(second.skipConsumed, isFalse);
    });

    test('the skip resets in the next calendar month', () async {
      await playConsecutive(day(2026, 8, 20), 5); // last active 24 Aug
      final august = await StreakManager.recordActivity(now: day(2026, 8, 26));
      expect(august.event, StreakEvent.recovered);
      expect(august.streak, 6);
      expect(await StreakManager.isSkipAvailable(now: day(2026, 8, 26)), isFalse);

      // A fresh skip is available the moment the month turns.
      expect(await StreakManager.isSkipAvailable(now: day(2026, 9, 1)), isTrue);

      // Play through to the end of August, miss 2 Sep, come back on the 3rd.
      for (int d = 27; d <= 31; d++) {
        await StreakManager.recordActivity(now: day(2026, 8, d));
      }
      await StreakManager.recordActivity(now: day(2026, 9, 1));
      final september = await StreakManager.recordActivity(now: day(2026, 9, 3));
      expect(september.event, StreakEvent.recovered);
      expect(september.skipConsumed, isTrue);
      expect(september.streak, 13);
    });

    test('the skip resets across a year boundary too', () async {
      await playConsecutive(day(2026, 12, 20), 3); // last active 22 Dec
      final dec = await StreakManager.recordActivity(now: day(2026, 12, 24));
      expect(dec.event, StreakEvent.recovered);
      expect(
        await StreakManager.isSkipAvailable(now: day(2027, 1, 2)),
        isTrue,
        reason: 'December 2026 and January 2027 are different months',
      );
    });

    test('a rescued streak is still alive to read before the rescue', () async {
      await playConsecutive(day(2026, 8, 10), 5); // last active 14 Aug
      // On the 16th the streak has one missed day but a skip in hand.
      final s = await StreakManager.currentState(now: day(2026, 8, 16));
      expect(s.streak, 5);
      expect(s.playedToday, isFalse);
      expect(s.skipAvailable, isTrue);
    });

    test('without a skip the same gap already reads as broken', () async {
      await playConsecutive(day(2026, 8, 1), 5);
      await StreakManager.recordActivity(now: day(2026, 8, 7)); // spends skip
      // Last active 7 Aug, missed the 8th, and no skip left.
      final s = await StreakManager.currentState(now: day(2026, 8, 9));
      expect(s.streak, 0);
    });
  });

  group('clock moved backwards', () {
    test('a backwards clock awards nothing and writes nothing', () async {
      await playConsecutive(day(2026, 8, 20), 3); // last active 22 Aug
      final prefs = await SharedPreferences.getInstance();
      final before = prefs.getString(StreakManager.lastActiveDateKey);

      final r = await StreakManager.recordActivity(now: day(2026, 8, 19));
      expect(r.event, StreakEvent.clockWentBackwards);
      expect(r.streak, 3, reason: 'unchanged, not incremented');
      expect(r.skipConsumed, isFalse);
      expect(await storedStreak(), 3);
      expect(prefs.getString(StreakManager.lastActiveDateKey), before);
    });

    test('a large backwards jump cannot be farmed for days', () async {
      await playConsecutive(day(2026, 8, 1), 10);
      for (int d = 1; d <= 5; d++) {
        await StreakManager.recordActivity(now: day(2025, 1, d));
      }
      expect(await storedStreak(), 10);
    });

    test('a backwards clock does not spend the monthly skip', () async {
      await playConsecutive(day(2026, 8, 20), 3);
      await StreakManager.recordActivity(now: day(2026, 8, 18));
      expect(await StreakManager.isSkipAvailable(now: day(2026, 8, 22)), isTrue);
    });

    test('reconcile does not wipe a streak when the clock is behind', () async {
      await playConsecutive(day(2026, 8, 20), 3); // last active 22 Aug
      await StreakManager.reconcile(now: day(2026, 7, 1));
      expect(await storedStreak(), 3);
    });

    test('moving the clock forward again resumes normally', () async {
      await playConsecutive(day(2026, 8, 20), 3); // last active 22 Aug
      await StreakManager.recordActivity(now: day(2026, 8, 19)); // ignored
      final r = await StreakManager.recordActivity(now: day(2026, 8, 23));
      expect(r.event, StreakEvent.extended);
      expect(r.streak, 4);
    });
  });

  group('calendar helpers', () {
    test('dayDifference counts calendar days, not elapsed hours', () {
      expect(
        StreakManager.dayDifference(
          DateTime(2026, 8, 20, 23, 59),
          DateTime(2026, 8, 21, 0, 1),
        ),
        1,
      );
      expect(
        StreakManager.dayDifference(
          DateTime(2026, 8, 20, 0, 1),
          DateTime(2026, 8, 20, 23, 59),
        ),
        0,
      );
      expect(
        StreakManager.dayDifference(DateTime(2026, 8, 22), DateTime(2026, 8, 20)),
        -2,
      );
      // Month and year rollovers.
      expect(
        StreakManager.dayDifference(DateTime(2026, 8, 31), DateTime(2026, 9, 1)),
        1,
      );
      expect(
        StreakManager.dayDifference(DateTime(2026, 12, 31), DateTime(2027, 1, 1)),
        1,
      );
      // A leap day is a real day.
      expect(
        StreakManager.dayDifference(DateTime(2028, 2, 28), DateTime(2028, 3, 1)),
        2,
      );
    });

    test('date and month keys are zero padded', () {
      expect(StreakManager.dateKeyFor(DateTime(2026, 1, 5)), '2026-01-05');
      expect(StreakManager.monthKeyFor(DateTime(2026, 1, 5)), '2026-01');
    });

    test('parseDateKey round-trips and rejects junk', () {
      final d = DateTime(2026, 8, 22);
      expect(StreakManager.parseDateKey(StreakManager.dateKeyFor(d)), d);
      expect(StreakManager.parseDateKey(null), isNull);
      expect(StreakManager.parseDateKey(''), isNull);
      expect(StreakManager.parseDateKey('2026-13-01'), isNull);
      expect(StreakManager.parseDateKey('yyyy-MM-dd'), isNull);
    });
  });

  group('reminder window', () {
    test('prefers the evening slot when it is still ahead', () {
      final when = StreakManager.reminderTimeFor(DateTime(2026, 8, 22, 9));
      expect(when, DateTime(2026, 8, 22, 20));
    });

    test('falls back to a short delay once the evening slot has passed', () {
      final when = StreakManager.reminderTimeFor(DateTime(2026, 8, 22, 21));
      expect(when, DateTime(2026, 8, 22, 21, 45));
    });

    test('never schedules past the end of the day', () {
      expect(StreakManager.reminderTimeFor(DateTime(2026, 8, 22, 23, 30)), isNull);
    });

    test('having played today pushes the reminder to tomorrow evening', () {
      final when = StreakManager.nextReminderTime(
        now: DateTime(2026, 8, 22, 9),
        playedToday: true,
      );
      expect(when, DateTime(2026, 8, 23, 20));
    });

    test('not having played keeps the reminder inside today', () {
      final now = DateTime(2026, 8, 22, 9);
      final when = StreakManager.nextReminderTime(now: now, playedToday: false);
      expect(when.isAfter(now), isTrue);
      expect(when.day, 22);
    });

    test('a month-end rollover produces a valid tomorrow', () {
      final when = StreakManager.nextReminderTime(
        now: DateTime(2026, 8, 31, 9),
        playedToday: true,
      );
      expect(when, DateTime(2026, 9, 1, 20));
    });
  });

  group('milestone badges', () {
    Future<List<String>> unlocked() => AchievementManager.getUnlockedIds();
    Future<List<String>> claimed() => AchievementManager.getClaimedIds();

    test('nothing fires below 7 days', () async {
      await playConsecutive(day(2026, 8, 1), 6);
      await AchievementManager.checkAndUnlock('zip');
      expect(await unlocked(), isNot(contains('streak_active_7')));
    });

    test('the 7-day badge fires at exactly 7 and stays unclaimed', () async {
      final r = await playConsecutive(day(2026, 8, 1), 7);
      expect(r.streak, 7);
      expect(r.milestoneReached, 7);

      final newly = await AchievementManager.checkAndUnlock('zip');
      expect(newly.map((a) => a.id), contains('streak_active_7'));
      expect(await unlocked(), contains('streak_active_7'));
      expect(await claimed(), isNot(contains('streak_active_7')));
    });

    test('the 30-day badge fires at exactly 30', () async {
      await playConsecutive(day(2026, 8, 1), 29);
      await AchievementManager.checkAndUnlock('zip');
      expect(await unlocked(), isNot(contains('streak_active_30')));

      final r = await StreakManager.recordActivity(now: day(2026, 8, 30));
      expect(r.streak, 30);
      expect(r.milestoneReached, 30);
      await AchievementManager.checkAndUnlock('zip');
      expect(await unlocked(), contains('streak_active_30'));
      expect(await claimed(), isNot(contains('streak_active_30')));
    });

    test('the 100-day badge fires at exactly 100', () async {
      await playConsecutive(day(2026, 1, 1), 99);
      await AchievementManager.checkAndUnlock('zip');
      expect(await unlocked(), isNot(contains('streak_active_100')));

      final r = await StreakManager.recordActivity(now: day(2026, 4, 10));
      expect(r.streak, 100);
      expect(r.milestoneReached, 100);
      await AchievementManager.checkAndUnlock('zip');
      expect(await unlocked(), contains('streak_active_100'));
      expect(await claimed(), isNot(contains('streak_active_100')));
    });

    test('a milestone reached via a recovery still fires', () async {
      await playConsecutive(day(2026, 8, 1), 6); // streak 6, last active 6 Aug
      final r = await StreakManager.recordActivity(now: day(2026, 8, 8));
      expect(r.event, StreakEvent.recovered);
      expect(r.milestoneReached, 7);
      await AchievementManager.checkAndUnlock('zip');
      expect(await unlocked(), contains('streak_active_7'));
    });

    test('a same-day replay does not re-report the milestone', () async {
      await playConsecutive(day(2026, 8, 1), 7);
      final again = await StreakManager.recordActivity(now: day(2026, 8, 7, 22));
      expect(again.event, StreakEvent.sameDay);
      expect(again.milestoneReached, isNull);
    });

    test('claiming is what dispatches the reward', () async {
      await playConsecutive(day(2026, 8, 1), 7);
      await AchievementManager.checkAndUnlock('zip');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(PrefsKeys.points) ?? 0, 0,
          reason: 'unlocking must not grant points');

      expect(await AchievementManager.claim('streak_active_7'), isTrue);
      expect(await claimed(), contains('streak_active_7'));
      expect(prefs.getInt(PrefsKeys.points) ?? 0, greaterThan(0));

      // Claiming twice must not pay twice.
      expect(await AchievementManager.claim('streak_active_7'), isFalse);
    });

    test('progress reports partial completion for the active streak', () async {
      await playConsecutive(day(2026, 8, 1), 3);
      final a = AchievementManager.allAchievements
          .firstWhere((x) => x.id == 'streak_active_7');
      expect(await AchievementManager.getProgress(a), closeTo(3 / 7, 0.0001));
    });
  });

  group('the daily-challenge streak is left alone', () {
    test('recording activity never touches the daily streak keys', () async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.dailyV2Streak: 12,
        PrefsKeys.dailyV2LastDate: '2026-08-01',
        PrefsKeys.dailyStreak: 4,
        PrefsKeys.dailyLastCompletedDate: '2026-07-30',
      });

      await playConsecutive(day(2026, 8, 20), 5);
      await StreakManager.recordActivity(now: day(2026, 8, 27)); // break
      await StreakManager.reconcile(now: day(2026, 9, 30));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(PrefsKeys.dailyV2Streak), 12);
      expect(prefs.getString(PrefsKeys.dailyV2LastDate), '2026-08-01');
      expect(prefs.getInt(PrefsKeys.dailyStreak), 4);
      expect(prefs.getString(PrefsKeys.dailyLastCompletedDate), '2026-07-30');
    });

    test('an active-day streak does not unlock daily-streak badges', () async {
      await playConsecutive(day(2026, 8, 1), 30);
      await AchievementManager.checkAndUnlock('zip');
      final ids = await AchievementManager.getUnlockedIds();
      expect(ids, contains('streak_active_7'));
      expect(ids, contains('streak_active_30'));
      expect(ids, isNot(contains('consistent')));
      expect(ids, isNot(contains('weekly_warrior')));
      expect(ids, isNot(contains('monthly_grind')));
    });

    test('a daily streak still unlocks its own badges unchanged', () async {
      SharedPreferences.setMockInitialValues({PrefsKeys.dailyV2Streak: 7});
      await AchievementManager.checkAndUnlock('zip');
      final ids = await AchievementManager.getUnlockedIds();
      expect(ids, contains('consistent'));
      expect(ids, contains('weekly_warrior'));
      expect(ids, isNot(contains('streak_active_7')));
    });
  });
}
