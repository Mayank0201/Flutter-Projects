import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// S1 — streak depth.
///
/// A second, parallel streak that counts **active days**: any day on which the
/// player opened a game — Challenge, Zen or a daily challenge — sustains it.
///
/// This is deliberately *additive*. The daily-challenge streak
/// (`PrefsKeys.dailyV2Streak` / `dailyStreak`, owned by `DailyChallengeManager`)
/// keeps its own keys, its own rules and its own achievements, and is neither
/// read nor written here. Nothing in this file can change what a
/// daily-challenge streak reports.
///
/// Three rules drive every decision below:
///
///  * **A day is a calendar date, not 24 hours.** Everything is decided from
///    the *local* year/month/day. Millisecond arithmetic is never used for a
///    day boundary, because a DST shift makes a local day 23 or 25 hours long
///    and a timezone change makes it anything at all. Day gaps are measured by
///    projecting the local calendar fields onto UTC midnights, which is a
///    DST-free space, so "yesterday" means yesterday's date and not
///    "24 hours ago".
///  * **Forward only.** A streak can rise by at most 1 per calendar day, and
///    only when the recorded date actually changes. A clock moved backwards
///    awards nothing at all.
///  * **One free skip per calendar month.** Missing exactly one day does not
///    end a streak if this month's skip is unused; the skip is consumed and
///    the streak carries on. Miss two days, or miss a second day in the same
///    month, and the streak restarts at 1. The skip is charged to the calendar
///    month in which it is *used*, so [isSkipAvailable] always describes the
///    skip that a recovery today would actually spend.
///
/// All entry points take an optional `now`, and the ambient clock is the
/// injectable [clock], so every rule above is testable without `DateTime.now()`.
class StreakManager {
  StreakManager._();

  // ---------------------------------------------------------------------------
  // Storage keys.
  //
  // Declared here rather than in PrefsKeys only because that file is owned
  // elsewhere; they are plain strings and should be mirrored into PrefsKeys
  // verbatim when it is next touched.
  // ---------------------------------------------------------------------------

  /// int — the current active-day streak.
  static const String activeStreakKey = 'streak_active_count';

  /// String `yyyy-MM-dd` (local) — the last day that counted as active.
  static const String lastActiveDateKey = 'streak_active_last_date';

  /// int — the best active-day streak ever reached.
  static const String longestActiveStreakKey = 'streak_active_longest';

  /// String `yyyy-MM` — the calendar month whose free skip has been spent.
  static const String skipMonthUsedKey = 'streak_skip_month_used';

  /// Milestones that award a badge, in ascending order.
  static const List<int> milestoneDays = <int>[7, 30, 100];

  /// Milestone length -> achievement id in [AchievementManager.allAchievements].
  static const Map<int, String> milestoneAchievementIds = <int, String>{
    7: 'streak_active_7',
    30: 'streak_active_30',
    100: 'streak_active_100',
  };

  /// The hour of the local day at which the streak reminder prefers to fire.
  static const int defaultReminderHour = 20;

  /// Ambient clock. Overridable so tests never depend on the wall clock.
  static DateTime Function() clock = DateTime.now;

  // ---------------------------------------------------------------------------
  // Calendar helpers — pure, and the only place dates are interpreted.
  // ---------------------------------------------------------------------------

  /// `yyyy-MM-dd` from the *local* calendar fields of [d].
  static String dateKeyFor(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// `yyyy-MM` from the *local* calendar fields of [d].
  static String monthKeyFor(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}';

  /// Whole calendar days from [from] to [to]; negative if [to] is earlier.
  ///
  /// The two dates are reduced to their local calendar fields and compared as
  /// UTC midnights. Subtracting local `DateTime`s directly would return 0 or 2
  /// across a daylight-saving boundary, because the elapsed time between two
  /// consecutive local midnights is then 23 or 25 hours.
  static int dayDifference(DateTime from, DateTime to) {
    final DateTime a = DateTime.utc(from.year, from.month, from.day);
    final DateTime b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  /// Parses a stored `yyyy-MM-dd` key back into a local midnight.
  ///
  /// Returns null for anything unparseable, so corrupt storage degrades to
  /// "no history" instead of throwing on a hot path.
  static DateTime? parseDateKey(String? raw) {
    if (raw == null || raw.length != 10) return null;
    final int? y = int.tryParse(raw.substring(0, 4));
    final int? m = int.tryParse(raw.substring(5, 7));
    final int? d = int.tryParse(raw.substring(8, 10));
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DateTime(y, m, d);
  }

  // ---------------------------------------------------------------------------
  // Reading.
  // ---------------------------------------------------------------------------

  /// The streak as it stands, without writing anything.
  ///
  /// [StreakState.streak] is the *effective* value: a streak whose last active
  /// day is too far back to be rescued reads as 0 even though the stored
  /// counter has not been cleared yet. Clearing happens in [reconcile] or on
  /// the next [recordActivity].
  static Future<StreakState> currentState({DateTime? now}) async {
    final DateTime today = now ?? clock();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return _stateFrom(prefs, today);
  }

  static StreakState _stateFrom(SharedPreferences prefs, DateTime today) {
    final int stored = prefs.getInt(activeStreakKey) ?? 0;
    final int longest = prefs.getInt(longestActiveStreakKey) ?? 0;
    final String? lastRaw = prefs.getString(lastActiveDateKey);
    final DateTime? last = parseDateKey(lastRaw);
    final bool skipAvailable = _skipAvailable(prefs, today);

    if (last == null) {
      return StreakState(
        streak: 0,
        longest: longest,
        lastActiveDate: null,
        skipAvailable: skipAvailable,
        playedToday: false,
      );
    }

    final int diff = dayDifference(last, today);

    // Clock moved backwards (manual change, or a timezone jump westwards past
    // a date line). Report what is stored and claim nothing.
    if (diff < 0) {
      return StreakState(
        streak: stored,
        longest: longest,
        lastActiveDate: lastRaw,
        skipAvailable: skipAvailable,
        playedToday: false,
      );
    }

    final bool alive = diff <= 1 || (diff == 2 && skipAvailable);
    return StreakState(
      streak: alive ? stored : 0,
      longest: longest,
      lastActiveDate: lastRaw,
      skipAvailable: skipAvailable,
      playedToday: diff == 0,
    );
  }

  /// Whether this calendar month's free skip is still unspent.
  static Future<bool> isSkipAvailable({DateTime? now}) async {
    final DateTime today = now ?? clock();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return _skipAvailable(prefs, today);
  }

  static bool _skipAvailable(SharedPreferences prefs, DateTime today) =>
      prefs.getString(skipMonthUsedKey) != monthKeyFor(today);

  // ---------------------------------------------------------------------------
  // Writing.
  // ---------------------------------------------------------------------------

  /// Records that the player was active today and returns what changed.
  ///
  /// Safe to call on every game launch: the second and later calls on the same
  /// calendar day are no-ops ([StreakEvent.sameDay]).
  static Future<StreakUpdate> recordActivity({DateTime? now}) async {
    final DateTime today = now ?? clock();
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final int stored = prefs.getInt(activeStreakKey) ?? 0;
    final int longest = prefs.getInt(longestActiveStreakKey) ?? 0;
    final DateTime? last = parseDateKey(prefs.getString(lastActiveDateKey));

    // First ever launch, or unreadable history: today starts a streak of 1.
    if (last == null) {
      return _commit(
        prefs,
        today: today,
        previous: stored,
        next: 1,
        longest: longest,
        event: StreakEvent.firstDay,
        consumeSkip: false,
      );
    }

    final int diff = dayDifference(last, today);

    // Never award anything for time travel. The stored state is left exactly
    // as it is, so moving the clock forward again resumes normally.
    if (diff < 0) {
      return StreakUpdate(
        event: StreakEvent.clockWentBackwards,
        previousStreak: stored,
        streak: stored,
        longest: longest,
        skipConsumed: false,
        skipAvailable: _skipAvailable(prefs, today),
        milestoneReached: null,
      );
    }

    // Already counted today. Playing ten games in a day is still one day.
    if (diff == 0) {
      return StreakUpdate(
        event: StreakEvent.sameDay,
        previousStreak: stored,
        streak: stored,
        longest: longest,
        skipConsumed: false,
        skipAvailable: _skipAvailable(prefs, today),
        milestoneReached: null,
      );
    }

    if (diff == 1) {
      return _commit(
        prefs,
        today: today,
        previous: stored,
        next: stored + 1,
        longest: longest,
        event: StreakEvent.extended,
        consumeSkip: false,
      );
    }

    // Exactly one missed day, and this month's skip is unspent: the streak
    // survives and the skip is burned. This is the whole point of the feature —
    // one bad day should not be a reason to stop playing altogether.
    if (diff == 2 && _skipAvailable(prefs, today)) {
      return _commit(
        prefs,
        today: today,
        previous: stored,
        next: stored + 1,
        longest: longest,
        event: StreakEvent.recovered,
        consumeSkip: true,
      );
    }

    return _commit(
      prefs,
      today: today,
      previous: stored,
      next: 1,
      longest: longest,
      event: StreakEvent.broken,
      consumeSkip: false,
    );
  }

  static Future<StreakUpdate> _commit(
    SharedPreferences prefs, {
    required DateTime today,
    required int previous,
    required int next,
    required int longest,
    required StreakEvent event,
    required bool consumeSkip,
  }) async {
    // Forward-only guard. Nothing above can produce a bigger jump, but the
    // invariant is cheap to enforce and expensive to lose.
    final int safeNext = next > previous + 1 ? previous + 1 : (next < 1 ? 1 : next);
    final int newLongest = safeNext > longest ? safeNext : longest;

    await prefs.setInt(activeStreakKey, safeNext);
    await prefs.setString(lastActiveDateKey, dateKeyFor(today));
    if (newLongest != longest) {
      await prefs.setInt(longestActiveStreakKey, newLongest);
    }
    if (consumeSkip) {
      await prefs.setString(skipMonthUsedKey, monthKeyFor(today));
    }

    final int? milestone = (safeNext > previous && milestoneDays.contains(safeNext))
        ? safeNext
        : null;

    return StreakUpdate(
      event: event,
      previousStreak: previous,
      streak: safeNext,
      longest: newLongest,
      skipConsumed: consumeSkip,
      skipAvailable: _skipAvailable(prefs, today),
      milestoneReached: milestone,
    );
  }

  /// Persists a break that has already happened, without counting today as
  /// active. Useful at app start so the UI and the achievement checks do not
  /// read a stale counter for a streak that has in fact lapsed.
  ///
  /// Returns the state after reconciling. Writes nothing unless the stored
  /// counter is genuinely stale.
  static Future<StreakState> reconcile({DateTime? now}) async {
    final DateTime today = now ?? clock();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final StreakState state = _stateFrom(prefs, today);

    final int stored = prefs.getInt(activeStreakKey) ?? 0;
    if (state.streak == 0 && stored != 0 && state.lastActiveDate != null) {
      final DateTime? last = parseDateKey(state.lastActiveDate);
      // Only clear on a real forward-moving lapse; a backwards clock must not
      // wipe a streak the player earned.
      if (last != null && dayDifference(last, today) > 0) {
        await prefs.setInt(activeStreakKey, 0);
      }
    }
    return state;
  }

  /// Test/debug hook: wipes the active-day streak only. The daily-challenge
  /// streak is untouched.
  @visibleForTesting
  static Future<void> resetAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(activeStreakKey);
    await prefs.remove(lastActiveDateKey);
    await prefs.remove(longestActiveStreakKey);
    await prefs.remove(skipMonthUsedKey);
  }

  // ---------------------------------------------------------------------------
  // Reminder scheduling (pure — NotificationManager just obeys the result).
  // ---------------------------------------------------------------------------

  /// The moment later *today* at which a "your streak is still open" reminder
  /// should fire, or null if the day has no usable window left.
  ///
  /// Prefers [preferredHour] local. If that has passed (or is too close to be
  /// worth scheduling) it falls back to a short delay, provided the reminder
  /// would still land before the day ends — a nudge after midnight is about a
  /// streak the player can no longer save.
  static DateTime? reminderTimeFor(
    DateTime now, {
    int preferredHour = defaultReminderHour,
    Duration minimumLead = const Duration(minutes: 15),
    Duration fallbackDelay = const Duration(minutes: 45),
  }) {
    final DateTime preferred =
        DateTime(now.year, now.month, now.day, preferredHour);
    if (preferred.isAfter(now.add(minimumLead))) return preferred;

    final DateTime latest = DateTime(now.year, now.month, now.day, 23, 45);
    final DateTime fallback = now.add(fallbackDelay);
    if (fallback.isAfter(latest)) return null;
    return fallback;
  }

  /// When the next streak reminder should fire, whatever the current state.
  ///
  /// Already played today (or too late in the day to act) -> tomorrow at
  /// [preferredHour]. Otherwise the remaining window of today.
  static DateTime nextReminderTime({
    required DateTime now,
    required bool playedToday,
    int preferredHour = defaultReminderHour,
  }) {
    if (!playedToday) {
      final DateTime? todaySlot =
          reminderTimeFor(now, preferredHour: preferredHour);
      if (todaySlot != null) return todaySlot;
    }
    // DateTime normalises a day overflow, so this is correct on the 28th,
    // 30th, 31st and on 31 December alike.
    return DateTime(now.year, now.month, now.day + 1, preferredHour);
  }
}

/// What [StreakManager.recordActivity] did.
enum StreakEvent {
  /// No prior history — the streak starts at 1.
  firstDay,

  /// Today was already counted; nothing changed.
  sameDay,

  /// Played on consecutive days; the streak grew by 1.
  extended,

  /// One day was missed and the month's free skip rescued the streak.
  recovered,

  /// Too long a gap (or no skip left); the streak restarts at 1.
  broken,

  /// The device clock is behind the last recorded day. Nothing was awarded and
  /// nothing was written.
  clockWentBackwards,
}

/// A read-only snapshot of the active-day streak.
@immutable
class StreakState {
  const StreakState({
    required this.streak,
    required this.longest,
    required this.lastActiveDate,
    required this.skipAvailable,
    required this.playedToday,
  });

  /// Effective current streak (0 once it has lapsed beyond rescue).
  final int streak;

  /// Best streak ever reached.
  final int longest;

  /// `yyyy-MM-dd` of the last active day, or null if there has never been one.
  final String? lastActiveDate;

  /// Whether this calendar month's free skip is still unspent.
  final bool skipAvailable;

  /// Whether today already counts as an active day.
  final bool playedToday;

  @override
  String toString() =>
      'StreakState(streak: $streak, longest: $longest, last: $lastActiveDate, '
      'skipAvailable: $skipAvailable, playedToday: $playedToday)';
}

/// The result of recording a day of activity.
@immutable
class StreakUpdate {
  const StreakUpdate({
    required this.event,
    required this.previousStreak,
    required this.streak,
    required this.longest,
    required this.skipConsumed,
    required this.skipAvailable,
    required this.milestoneReached,
  });

  final StreakEvent event;
  final int previousStreak;
  final int streak;
  final int longest;

  /// True when this call spent the month's free skip.
  final bool skipConsumed;

  /// Whether a skip remains after this call.
  final bool skipAvailable;

  /// 7, 30 or 100 when this call crossed that milestone; otherwise null.
  /// The badge itself is granted through `AchievementManager.checkAndUnlock`,
  /// which marks it unlocked-but-unclaimed — rewards stay manual.
  final int? milestoneReached;

  @override
  String toString() =>
      'StreakUpdate($event, $previousStreak -> $streak, skipConsumed: '
      '$skipConsumed, milestone: $milestoneReached)';
}
