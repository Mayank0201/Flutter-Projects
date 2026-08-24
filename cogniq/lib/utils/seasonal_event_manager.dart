import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_info.dart';
import 'achievement_manager.dart';
import 'point_manager.dart';
import 'prefs_keys.dart';

/// S3 — the seasonal event framework (release 2.1).
///
/// A *framework*, not a holiday. It answers three questions and nothing else:
///
///  1. Is an event running on a given local calendar date, and which one?
///  2. How far through that event's badge requirement is the player?
///  3. Has the badge been earned — and is it sitting unlocked-but-unclaimed?
///
/// Everything an event *does* to gameplay (featured games, featured modifiers)
/// is data on [SeasonalEventDefinition]; this file never applies a modifier and
/// never schedules a challenge. The daily-challenge system
/// ([DailyChallengeManager]) is neither read nor written here — `remember.md`
/// Section A puts it off-limits, and S3 was approved to be built *alongside* it.
///
/// ## Offline by construction
///
/// Definitions are `const` and ship in the app binary. There is no fetch, no
/// remote config and no clock server. That is deliberate: the app is
/// offline-first and this feature must not be the thing that breaks it.
///
/// Because definitions cannot be updated between releases, windows are
/// **annually recurring** (month/day → month/day) rather than absolute dates.
/// A winter event shipped in 2.2 therefore still runs in 2029 on a device that
/// never updates. One-off events are still expressible via
/// [SeasonalEventDefinition.firstYear] / [SeasonalEventDefinition.lastYear].
///
/// ## Time handling
///
/// This is the part that has already bitten this project, so the rules are
/// explicit:
///
///  * **A day is a local calendar date.** Never UTC, never "24 hours".
///  * **Never subtract two local `DateTime`s to get a day count.** Consecutive
///    local midnights are 23 or 25 hours apart across a DST boundary, so the
///    subtraction yields 0 or 2 days. Day gaps are measured by [dayDifference],
///    which projects the local year/month/day onto UTC midnights — a DST-free
///    space — before subtracting.
///  * **The clock is injected.** [clock] is overridable and every entry point
///    takes an optional `now`, so DST, year boundaries, an event spanning New
///    Year, a clock moved backwards and a device in another timezone are all
///    reachable from a test.
///  * **Deterministic.** Resolution is a pure function of the local date and
///    the const definition list. The same date always yields the same event.
class SeasonalEventManager {
  SeasonalEventManager._();

  // ---------------------------------------------------------------------------
  // Storage keys.
  //
  // Declared here rather than in PrefsKeys only because that file is owned
  // elsewhere; they are plain strings and should be mirrored into PrefsKeys
  // verbatim when it is next touched. (StreakManager does the same for S1.)
  // ---------------------------------------------------------------------------

  /// int — qualifying actions recorded for one event *occurrence*.
  ///
  /// Keyed by occurrence, not by event, so next year's run of the same event
  /// starts from zero without a migration.
  static String progressKey(String eventId, String occurrenceKey) =>
      'seasonal_event_progress_${eventId}_$occurrenceKey';

  /// bool — the player dismissed the home banner for this occurrence.
  static String bannerDismissedKey(String eventId, String occurrenceKey) =>
      'seasonal_event_banner_dismissed_${eventId}_$occurrenceKey';

  /// String list — the day indices (1-based, as strings) of every day of one
  /// occurrence on which the player was active.
  ///
  /// This is the *shape* a nineteen-day event needs and a single 5-level badge
  /// cannot provide: the badge is a first-week goal, the night trail runs the
  /// whole window. Stored as day indices rather than dates because the
  /// occurrence key already pins the start date — a definition whose start
  /// moves produces a different occurrence key and therefore a fresh trail,
  /// so an index can never be reinterpreted against a different start.
  static String nightsKey(String eventId, String occurrenceKey) =>
      'seasonal_event_nights_${eventId}_$occurrenceKey';

  /// String — occurrence key of the last event the player was shown an intro
  /// for. Lets the home screen greet a new event exactly once.
  static const String lastSeenOccurrenceKey = 'seasonal_event_last_seen';

  /// Ambient clock. Overridable so nothing here depends on the wall clock.
  static DateTime Function() clock = DateTime.now;

  // ---------------------------------------------------------------------------
  // Shipped definitions.
  // ---------------------------------------------------------------------------

  /// Every event that ships in this binary.
  ///
  /// Four events on a quarterly rhythm, anchored to the 18th of Dec / Mar /
  /// Jun / Sep so the gaps are even and the dates are easy to remember. Each
  /// runs a little over two weeks, which leaves ~10 weeks of quiet between
  /// events — long enough that a returning event still feels like an occasion.
  ///
  /// Winter deliberately spans the year boundary (18 Dec - 5 Jan) so the
  /// year-rollover path is exercised by real shipped content, not only by tests.
  ///
  /// Featured *content* is still thin; the framework is the 2.1 deliverable and
  /// per-event content lands in 2.2. What matters here is that the calendar is
  /// real, every featured id is live, and every badge exists in
  /// `AchievementManager.allAchievements`.
  static const List<SeasonalEventDefinition> kSeasonalEvents =
      <SeasonalEventDefinition>[
    SeasonalEventDefinition(
      id: 'winter_lights',
      name: 'Winter Lights',
      tagline: 'Light the long nights — nineteen days of cold, bright puzzles.',
      emoji: '❄️',
      window: EventWindow(
        start: MonthDay(12, 18),
        end: MonthDay(1, 5),
      ),
      // Every id here is a live, non-stashed game with a real route. A stashed
      // id would send the player at an unregistered route and crash the app —
      // exactly the bug `DailyChallengeManager._isLiveGame` was added to stop.
      // [validate] re-checks this against kAllGames.
      featuredGameIds: <String>[
        'masyu',
        'zip',
        'colour_link',
        'pattern_lock',
        'queens',
      ],
      // Modifier *types*, matching the strings the daily system already uses.
      // Naming one here does not apply it, and 2.2 did NOT wire them in — see
      // the note on [SeasonalEventDefinition.featuredModifierTypes] for why
      // that was refused rather than deferred. Rule 8 of remember.md ("never
      // announce what you do not apply") is why nothing in the UI shows these.
      featuredModifierTypes: <String>['ice', 'fog'],
      badge: EventBadge(
        id: 'event_winter_lights',
        name: 'Winter Lights',
        description: 'Clear 5 levels during the Winter Lights event',
        icon: '❄️',
        rewardPoints: 200,
        requiredProgress: 5,
      ),
      // The nineteen-night trail. The badge is a first-week goal — five levels
      // is one sitting for a regular player — so it cannot carry nineteen days
      // on its own. These name the long tail instead, and every one is
      // reachable: [validate] refuses a milestone past the last night.
      milestones: <EventMilestone>[
        EventMilestone(
          nights: 1,
          name: 'First Light',
          description: 'A lantern lit on your first night of the event',
        ),
        EventMilestone(
          nights: 5,
          name: 'Five Nights',
          description: 'Five of the nineteen nights lit',
        ),
        EventMilestone(
          nights: 12,
          name: 'Twelve Nights',
          description: 'Twelve of the nineteen nights lit',
        ),
        EventMilestone(
          nights: 19,
          name: 'The Whole Winter',
          description: 'A lantern on every night of the event',
        ),
      ],
      priority: 10,
    ),
    SeasonalEventDefinition(
      id: 'spring_thaw',
      name: 'Spring Thaw',
      tagline: 'The ice lets go — fifteen days of loosening knots.',
      emoji: '🌱',
      window: EventWindow(
        start: MonthDay(3, 18),
        end: MonthDay(4, 1),
      ),
      featuredGameIds: <String>[
        'colour_link',
        'bridges',
        'hue',
        'masyu',
        'zip',
      ],
      featuredModifierTypes: <String>['fog', 'mirror'],
      badge: EventBadge(
        id: 'event_spring_thaw',
        name: 'Spring Thaw',
        description: 'Clear 5 levels during the Spring Thaw event',
        icon: '🌱',
        rewardPoints: 200,
        requiredProgress: 5,
      ),
      priority: 10,
    ),
    SeasonalEventDefinition(
      id: 'summer_light',
      name: 'Long Light',
      tagline: 'The longest days — fifteen days of bright, open puzzles.',
      emoji: '☀️',
      window: EventWindow(
        start: MonthDay(6, 18),
        end: MonthDay(7, 2),
      ),
      featuredGameIds: <String>[
        'circuit_guide',
        'color_flood',
        'oddcolor',
        'zip',
        'hue',
      ],
      featuredModifierTypes: <String>['timer', 'zoom'],
      badge: EventBadge(
        id: 'event_summer_light',
        name: 'Long Light',
        description: 'Clear 5 levels during the Long Light event',
        icon: '☀️',
        rewardPoints: 200,
        requiredProgress: 5,
      ),
      priority: 10,
    ),
    SeasonalEventDefinition(
      id: 'autumn_harvest',
      name: 'Gathering In',
      tagline: 'Bring it all home — fifteen days of counting and sorting.',
      emoji: '🍂',
      window: EventWindow(
        start: MonthDay(9, 18),
        end: MonthDay(10, 2),
      ),
      featuredGameIds: <String>[
        'sumstrike',
        'killersudoku',
        'sudoku',
        'minesweeper',
        'chimp',
      ],
      featuredModifierTypes: <String>['eclipse', 'quota'],
      badge: EventBadge(
        id: 'event_autumn_harvest',
        name: 'Gathering In',
        description: 'Clear 5 levels during the Gathering In event',
        icon: '🍂',
        rewardPoints: 200,
        requiredProgress: 5,
      ),
      priority: 10,
    ),
  ];

  // ---------------------------------------------------------------------------
  // Calendar helpers — pure, and the only place dates are interpreted.
  // ---------------------------------------------------------------------------

  /// `yyyy-MM-dd` from the *local* calendar fields of [d].
  static String dateKeyFor(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

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

  /// Local midnight for [year]/[month]/[day], with [day] clamped to the last
  /// day the month actually has.
  ///
  /// Without the clamp, `DateTime(2027, 2, 29)` silently rolls forward to
  /// 1 March, which would move an event's boundary in non-leap years.
  static DateTime clampedDate(int year, int month, int day) {
    final int lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final int safeDay = day < 1 ? 1 : (day > lastDayOfMonth ? lastDayOfMonth : day);
    return DateTime(year, month, safeDay);
  }

  // ---------------------------------------------------------------------------
  // Scheduling — pure. No storage, no clock unless you let it default.
  // ---------------------------------------------------------------------------

  /// The occurrence of [definition] covering [date], or null if it is not
  /// running then.
  static SeasonalEventOccurrence? occurrenceOf(
    SeasonalEventDefinition definition,
    DateTime date,
  ) {
    final EventWindow w = definition.window;

    // A window that wraps New Year can be entered from either side of the
    // boundary, so both candidate start years have to be considered. They are
    // tried newest first so a (malformed) self-overlapping definition still
    // resolves deterministically.
    for (final int startYear in <int>[date.year, date.year - 1]) {
      final DateTime start = clampedDate(startYear, w.start.month, w.start.day);
      final int endYear = w.spansYearBoundary ? startYear + 1 : startYear;
      final DateTime end = clampedDate(endYear, w.end.month, w.end.day);
      if (dayDifference(start, end) < 0) continue; // malformed; skip quietly

      if (dayDifference(start, date) < 0) continue; // date is before the start
      if (dayDifference(date, end) < 0) continue; // date is after the end

      final int? first = definition.firstYear;
      final int? last = definition.lastYear;
      if (first != null && startYear < first) continue;
      if (last != null && startYear > last) continue;

      return SeasonalEventOccurrence(
        definition: definition,
        start: start,
        end: end,
        date: DateTime(date.year, date.month, date.day),
      );
    }
    return null;
  }

  /// Every event running on [now], best match first.
  ///
  /// Ordering is total and deterministic — overlapping windows never resolve
  /// arbitrarily:
  ///
  ///  1. higher [SeasonalEventDefinition.priority] wins;
  ///  2. then the shorter (more specific) window wins;
  ///  3. then the lexicographically smaller id wins.
  ///
  /// Rule 3 alone would already be deterministic; 1 and 2 exist so the ordering
  /// is also *sensible* — a short, high-priority event laid over a long ambient
  /// one is the normal way seasonal content gets layered.
  static List<SeasonalEventOccurrence> activeEvents({
    DateTime? now,
    List<SeasonalEventDefinition>? definitions,
  }) {
    final DateTime date = now ?? clock();
    final List<SeasonalEventDefinition> defs = definitions ?? kSeasonalEvents;

    final List<SeasonalEventOccurrence> found = <SeasonalEventOccurrence>[];
    for (final SeasonalEventDefinition d in defs) {
      final SeasonalEventOccurrence? o = occurrenceOf(d, date);
      if (o != null) found.add(o);
    }

    found.sort((SeasonalEventOccurrence a, SeasonalEventOccurrence b) {
      final int byPriority =
          b.definition.priority.compareTo(a.definition.priority);
      if (byPriority != 0) return byPriority;
      final int byLength = a.definition.window.nominalLengthDays
          .compareTo(b.definition.window.nominalLengthDays);
      if (byLength != 0) return byLength;
      return a.definition.id.compareTo(b.definition.id);
    });
    return found;
  }

  /// The single event in force on [now], or null when none is running.
  static SeasonalEventOccurrence? activeEvent({
    DateTime? now,
    List<SeasonalEventDefinition>? definitions,
  }) {
    final List<SeasonalEventOccurrence> all =
        activeEvents(now: now, definitions: definitions);
    return all.isEmpty ? null : all.first;
  }

  /// The next event to start after [now], searching up to [withinDays] ahead.
  ///
  /// Used for a "starts in 3 days" teaser. Returns null if nothing starts in
  /// that horizon. Walks calendar days rather than adding milliseconds, so a
  /// DST shift inside the horizon cannot skip or double-count a day.
  static SeasonalEventOccurrence? nextEvent({
    DateTime? now,
    List<SeasonalEventDefinition>? definitions,
    int withinDays = 366,
  }) {
    final DateTime date = now ?? clock();
    for (int i = 1; i <= withinDays; i++) {
      final DateTime probe = DateTime(date.year, date.month, date.day + i);
      final SeasonalEventOccurrence? o =
          activeEvent(now: probe, definitions: definitions);
      // Only report an event that actually *starts* later; an event already
      // running today is not "next".
      if (o != null && activeEvent(now: date, definitions: definitions) == null) {
        return o;
      }
    }
    return null;
  }

  /// Games this occurrence features that the app can actually open.
  ///
  /// A stashed game has no route in `main.dart`, and `MaterialApp` here declares
  /// no `onUnknownRoute`, so offering one is an unhandled crash rather than a
  /// graceful failure. Filtering here means a definition can name a game that
  /// is still stashed today and it simply will not be offered until it goes
  /// live — the same guard `DailyChallengeManager` needed.
  static List<GameInfo> liveFeaturedGames(SeasonalEventDefinition definition) {
    final List<GameInfo> out = <GameInfo>[];
    for (final String id in definition.featuredGameIds) {
      for (final GameInfo g in kAllGames) {
        if (g.id == id && !g.isStashed) {
          out.add(g);
          break;
        }
      }
    }
    return out;
  }

  /// Definition problems worth knowing about, as human-readable strings.
  ///
  /// Empty means everything checks out. Called by the test suite so a bad
  /// definition fails CI rather than a player's device; also logged in debug
  /// builds from [debugLogValidation].
  static List<String> validate([
    List<SeasonalEventDefinition>? definitions,
  ]) {
    final List<SeasonalEventDefinition> defs = definitions ?? kSeasonalEvents;
    final List<String> problems = <String>[];
    final Set<String> seenIds = <String>{};
    final Set<String> seenBadgeIds = <String>{};

    for (final SeasonalEventDefinition d in defs) {
      if (!seenIds.add(d.id)) {
        problems.add('duplicate event id "${d.id}"');
      }
      if (!seenBadgeIds.add(d.badge.id)) {
        problems.add('duplicate badge id "${d.badge.id}"');
      }
      if (d.id.isEmpty) problems.add('an event has an empty id');
      if (d.badge.requiredProgress < 1) {
        problems.add('"${d.id}" badge requires < 1 progress');
      }
      if (!d.window.isWellFormed) {
        problems.add('"${d.id}" has an out-of-range window');
      }
      if (d.featuredGameIds.isEmpty) {
        problems.add('"${d.id}" features no games');
      }
      for (final String gameId in d.featuredGameIds) {
        final bool known = kAllGames.any((GameInfo g) => g.id == gameId);
        if (!known) {
          problems.add('"${d.id}" features unknown game "$gameId"');
        }
      }
      if (liveFeaturedGames(d).isEmpty) {
        problems.add('"${d.id}" features no *live* game — nothing to offer');
      }
      final int? first = d.firstYear;
      final int? last = d.lastYear;
      if (first != null && last != null && last < first) {
        problems.add('"${d.id}" has lastYear before firstYear');
      }

      // Milestones. An unreachable one is the §8 failure in miniature: the
      // banner would show a stage the calendar makes impossible, and nobody
      // would find out until a player counted the nights.
      final int nightsAvailable = d.window.nominalLengthDays;
      int previousNights = 0;
      final Set<String> seenMilestoneNames = <String>{};
      for (final EventMilestone m in d.milestones) {
        if (m.nights < 1) {
          problems.add('"${d.id}" milestone "${m.name}" needs < 1 night');
        }
        if (m.nights > nightsAvailable) {
          problems.add('"${d.id}" milestone "${m.name}" needs ${m.nights} '
              'nights but the window is only $nightsAvailable days long');
        }
        if (m.nights <= previousNights) {
          problems.add('"${d.id}" milestones are not in ascending order at '
              '"${m.name}"');
        }
        previousNights = m.nights;
        if (m.name.trim().isEmpty) {
          problems.add('"${d.id}" has an unnamed milestone');
        } else if (!seenMilestoneNames.add(m.name)) {
          problems.add('"${d.id}" has two milestones called "${m.name}"');
        }
        if (m.description.trim().isEmpty) {
          problems.add('"${d.id}" milestone "${m.name}" has no description');
        }
      }
    }
    return problems;
  }

  /// Logs [validate]'s findings in debug builds. No-op in release.
  static void debugLogValidation() {
    if (!kDebugMode) return;
    for (final String p in validate()) {
      debugPrint('SeasonalEventManager: $p');
    }
  }

  // ---------------------------------------------------------------------------
  // Progress + badges.
  //
  // Badges follow the existing manual-claim flow exactly: a met requirement
  // marks the id unlocked-but-UNCLAIMED in PrefsKeys.unlockedAchievements and
  // stops. Nothing here ever writes PrefsKeys.claimedAchievements or dispatches
  // a reward — that only happens when the player taps Claim.
  // ---------------------------------------------------------------------------

  /// A read-only snapshot of the event state on [now].
  static Future<SeasonalEventState> currentState({
    DateTime? now,
    List<SeasonalEventDefinition>? definitions,
  }) async {
    final DateTime date = now ?? clock();
    final SeasonalEventOccurrence? occurrence =
        activeEvent(now: date, definitions: definitions);
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    if (occurrence == null) {
      return const SeasonalEventState(
        occurrence: null,
        progress: 0,
        requiredProgress: 0,
        badgeUnlocked: false,
        badgeClaimed: false,
        bannerDismissed: false,
        litNights: <int>{},
      );
    }

    final EventBadge badge = occurrence.definition.badge;
    final List<String> unlocked =
        prefs.getStringList(PrefsKeys.unlockedAchievements) ?? <String>[];
    final List<String> claimed =
        prefs.getStringList(PrefsKeys.claimedAchievements) ?? <String>[];

    return SeasonalEventState(
      occurrence: occurrence,
      progress: prefs.getInt(
              progressKey(occurrence.definition.id, occurrence.occurrenceKey)) ??
          0,
      requiredProgress: badge.requiredProgress,
      badgeUnlocked: unlocked.contains(badge.id),
      badgeClaimed: claimed.contains(badge.id),
      bannerDismissed: prefs.getBool(bannerDismissedKey(
              occurrence.definition.id, occurrence.occurrenceKey)) ??
          false,
      litNights: _readNights(prefs, occurrence),
    );
  }

  /// The 1-based day indices of [occurrence] the player has been active on.
  ///
  /// Anything stored that is not a day index inside the window is dropped
  /// rather than trusted: a shortened window in a later release must not be
  /// able to report "20 of 19 nights lit".
  static Set<int> _readNights(
    SharedPreferences prefs,
    SeasonalEventOccurrence occurrence,
  ) {
    final List<String> raw = prefs.getStringList(
            nightsKey(occurrence.definition.id, occurrence.occurrenceKey)) ??
        <String>[];
    final int total = occurrence.totalDays;
    final Set<int> out = <int>{};
    for (final String s in raw) {
      final int? n = int.tryParse(s);
      if (n != null && n >= 1 && n <= total) out.add(n);
    }
    return out;
  }

  /// The night trail for the occurrence running on [now].
  static Future<Set<int>> litNights({
    DateTime? now,
    List<SeasonalEventDefinition>? definitions,
  }) async {
    final SeasonalEventOccurrence? o =
        activeEvent(now: now ?? clock(), definitions: definitions);
    if (o == null) return <int>{};
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return _readNights(prefs, o);
  }

  /// The stages of [definition] a player with [nights] lit has reached.
  static List<EventMilestone> reachedMilestones(
    SeasonalEventDefinition definition,
    int nights,
  ) =>
      <EventMilestone>[
        for (final EventMilestone m in definition.milestones)
          if (nights >= m.nights) m,
      ];

  /// The next stage of [definition] above [nights], or null once they are all
  /// reached (or the event names none).
  static EventMilestone? nextMilestone(
    SeasonalEventDefinition definition,
    int nights,
  ) {
    for (final EventMilestone m in definition.milestones) {
      if (nights < m.nights) return m;
    }
    return null;
  }

  /// Progress recorded so far for the occurrence running on [now].
  static Future<int> progressFor({
    DateTime? now,
    List<SeasonalEventDefinition>? definitions,
  }) async =>
      (await currentState(now: now, definitions: definitions)).progress;

  /// Records [amount] qualifying actions (normally one cleared level) against
  /// whichever event is running on [now].
  ///
  /// Safe to call unconditionally after any level clear: outside an event
  /// window it writes nothing and reports [EventProgressOutcome.noEvent].
  ///
  /// A badge whose requirement is met is marked unlocked-but-unclaimed and
  /// nothing else — no points, no title, no claim. Re-crossing the threshold
  /// (more clears after the badge is earned) reports
  /// [EventProgressOutcome.alreadyEarned] and never re-unlocks.
  static Future<EventProgressUpdate> recordProgress({
    DateTime? now,
    List<SeasonalEventDefinition>? definitions,
    int amount = 1,
  }) async {
    final DateTime date = now ?? clock();
    final SeasonalEventOccurrence? occurrence =
        activeEvent(now: date, definitions: definitions);

    if (occurrence == null) {
      return const EventProgressUpdate(
        outcome: EventProgressOutcome.noEvent,
        occurrence: null,
        progress: 0,
        requiredProgress: 0,
        badgeId: null,
      );
    }

    final SeasonalEventDefinition def = occurrence.definition;
    final EventBadge badge = def.badge;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String key = progressKey(def.id, occurrence.occurrenceKey);

    // Progress is monotonic. A negative or zero amount can never claw anything
    // back, so a caller bug (or a replayed event) cannot un-earn a badge.
    final int step = amount < 1 ? 0 : amount;
    final int before = prefs.getInt(key) ?? 0;
    final int after = before + step;
    final int capped = after > badge.requiredProgress ? badge.requiredProgress : after;
    if (capped != before) {
      await prefs.setInt(key, capped);
    }

    // Light tonight's lantern. This keeps counting after the badge is earned
    // and after the progress counter has hit its cap, which is the whole point:
    // it is the part of the event that lasts all nineteen days. A no-op amount
    // lights nothing — an activity that did not count towards progress must not
    // count towards the trail either.
    final Set<int> nights = _readNights(prefs, occurrence);
    final bool newNight = step >= 1 && nights.add(occurrence.dayIndex);
    if (newNight) {
      final List<int> sorted = nights.toList()..sort();
      await prefs.setStringList(
        nightsKey(def.id, occurrence.occurrenceKey),
        <String>[for (final int n in sorted) '$n'],
      );
    }

    final List<String> unlocked =
        prefs.getStringList(PrefsKeys.unlockedAchievements) ?? <String>[];
    final bool wasUnlocked = unlocked.contains(badge.id);

    if (capped < badge.requiredProgress) {
      return EventProgressUpdate(
        outcome: wasUnlocked
            ? EventProgressOutcome.alreadyEarned
            : EventProgressOutcome.recorded,
        occurrence: occurrence,
        progress: capped,
        requiredProgress: badge.requiredProgress,
        badgeId: badge.id,
        litNights: nights,
        newNightLit: newNight,
      );
    }

    if (wasUnlocked) {
      return EventProgressUpdate(
        outcome: EventProgressOutcome.alreadyEarned,
        occurrence: occurrence,
        progress: capped,
        requiredProgress: badge.requiredProgress,
        badgeId: badge.id,
        litNights: nights,
        newNightLit: newNight,
      );
    }

    // Unlocked-but-unclaimed. Deliberately does NOT touch claimedAchievements,
    // unlockedTitles or the point balance — see AchievementManager.claim.
    unlocked.add(badge.id);
    await prefs.setStringList(PrefsKeys.unlockedAchievements, unlocked);

    return EventProgressUpdate(
      outcome: EventProgressOutcome.badgeUnlocked,
      occurrence: occurrence,
      progress: capped,
      requiredProgress: badge.requiredProgress,
      badgeId: badge.id,
      litNights: nights,
      newNightLit: newNight,
    );
  }

  /// Whether [badgeId] is unlocked (earned, claimed or not).
  static Future<bool> isBadgeUnlocked(String badgeId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(PrefsKeys.unlockedAchievements) ?? <String>[])
        .contains(badgeId);
  }

  /// Whether [badgeId] has been claimed by the player.
  static Future<bool> isBadgeClaimed(String badgeId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(PrefsKeys.claimedAchievements) ?? <String>[])
        .contains(badgeId);
  }

  /// Every event badge this binary can award, in definition order.
  static List<EventBadge> get allBadges => <EventBadge>[
        for (final SeasonalEventDefinition d in kSeasonalEvents) d.badge,
      ];

  /// The badge with [badgeId], or null if this binary does not define it.
  static EventBadge? badgeById(String badgeId) {
    for (final SeasonalEventDefinition d in kSeasonalEvents) {
      if (d.badge.id == badgeId) return d.badge;
    }
    return null;
  }

  /// Claims an event badge, dispatching its reward exactly once.
  ///
  /// Delegates to [AchievementManager.claim] first, so that once the owner adds
  /// the event badges to `AchievementManager.allAchievements` (the const entries
  /// are listed in this work order's report) the existing achievements screen
  /// owns the whole flow and this method becomes a pass-through.
  ///
  /// Until then `claim` cannot find the id and returns false, so the fallback
  /// below dispatches the reward using the *same* keys and the same guards. It
  /// can never double-grant: both paths gate on
  /// `PrefsKeys.claimedAchievements`.
  static Future<bool> claimBadge(String badgeId) async {
    if (await AchievementManager.claim(badgeId)) return true;

    final EventBadge? badge = badgeById(badgeId);
    if (badge == null) return false;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> unlocked =
        prefs.getStringList(PrefsKeys.unlockedAchievements) ?? <String>[];
    final List<String> claimed =
        prefs.getStringList(PrefsKeys.claimedAchievements) ?? <String>[];
    if (!unlocked.contains(badgeId) || claimed.contains(badgeId)) return false;

    if (badge.rewardPoints > 0) {
      await PointManager.addPoints(badge.rewardPoints);
    }
    final String? title = badge.rewardTitle;
    if (title != null) {
      final List<String> titles =
          prefs.getStringList(PrefsKeys.unlockedTitles) ?? <String>[];
      if (!titles.contains(title)) {
        titles.add(title);
        await prefs.setStringList(PrefsKeys.unlockedTitles, titles);
      }
    }

    claimed.add(badgeId);
    await prefs.setStringList(PrefsKeys.claimedAchievements, claimed);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Banner bookkeeping.
  // ---------------------------------------------------------------------------

  /// Hides the home banner for the occurrence running on [now].
  ///
  /// Scoped to the occurrence, so dismissing this December's banner does not
  /// hide next December's.
  static Future<void> dismissBanner({
    DateTime? now,
    List<SeasonalEventDefinition>? definitions,
  }) async {
    final SeasonalEventOccurrence? o =
        activeEvent(now: now ?? clock(), definitions: definitions);
    if (o == null) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
        bannerDismissedKey(o.definition.id, o.occurrenceKey), true);
  }

  /// True the first time an occurrence is seen; records it so the caller can
  /// greet a new event exactly once.
  static Future<bool> markOccurrenceSeen({
    DateTime? now,
    List<SeasonalEventDefinition>? definitions,
  }) async {
    final SeasonalEventOccurrence? o =
        activeEvent(now: now ?? clock(), definitions: definitions);
    if (o == null) return false;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String token = '${o.definition.id}@${o.occurrenceKey}';
    if (prefs.getString(lastSeenOccurrenceKey) == token) return false;
    await prefs.setString(lastSeenOccurrenceKey, token);
    return true;
  }

  /// Test/debug hook: wipes S3 state only.
  ///
  /// Achievement state is left alone — an earned badge belongs to the
  /// achievements system, not to this one.
  @visibleForTesting
  static Future<void> resetProgress() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    for (final String k in prefs.getKeys().toList()) {
      if (k.startsWith('seasonal_event_')) {
        await prefs.remove(k);
      }
    }
  }
}

// =============================================================================
// Value types.
// =============================================================================

/// A month and a day, with no year — the recurring half of an [EventWindow].
@immutable
class MonthDay {
  const MonthDay(this.month, this.day);

  final int month;
  final int day;

  /// Sortable within a year. Not a day-of-year: only ever compared to another
  /// [ordinal], never used for arithmetic.
  int get ordinal => month * 100 + day;

  bool get isWellFormed => month >= 1 && month <= 12 && day >= 1 && day <= 31;

  @override
  String toString() => '$month/$day';

  @override
  bool operator ==(Object other) =>
      other is MonthDay && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(month, day);
}

/// An annually recurring date window, inclusive at both ends.
///
/// `MonthDay(12, 18) → MonthDay(1, 5)` spans New Year and is nineteen days
/// long; the framework treats 31 December and 1 January as consecutive days of
/// one occurrence, not as two separate runs.
@immutable
class EventWindow {
  const EventWindow({required this.start, required this.end});

  final MonthDay start;
  final MonthDay end;

  /// True when the window runs past 31 December into the following year.
  bool get spansYearBoundary => end.ordinal < start.ordinal;

  bool get isWellFormed => start.isWellFormed && end.isWellFormed;

  /// Length in days, measured in a fixed non-leap reference year.
  ///
  /// Used only as a deterministic tie-break between overlapping events, so it
  /// must not vary with the year being resolved — a leap year would otherwise
  /// silently reorder two events whose windows differ by a day.
  int get nominalLengthDays {
    const int refYear = 2025; // not a leap year
    final DateTime s =
        SeasonalEventManager.clampedDate(refYear, start.month, start.day);
    final DateTime e = SeasonalEventManager.clampedDate(
        spansYearBoundary ? refYear + 1 : refYear, end.month, end.day);
    return SeasonalEventManager.dayDifference(s, e) + 1;
  }

  @override
  String toString() => '$start–$end';
}

/// The badge an event awards. Routed through the manual-claim achievement flow;
/// never auto-granted.
@immutable
class EventBadge {
  const EventBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.requiredProgress,
    this.rewardPoints = 0,
    this.rewardTitle,
  });

  /// Must match the achievement id the owner adds to
  /// `AchievementManager.allAchievements`. Prefixed `event_` by convention so
  /// the achievements screen can group seasonal badges.
  final String id;
  final String name;
  final String description;

  /// Emoji, matching `Achievement.icon`.
  final String icon;

  /// Qualifying actions needed during one occurrence.
  final int requiredProgress;

  final int rewardPoints;
  final String? rewardTitle;
}

/// A named stage on an event's night trail.
///
/// Deliberately reward-free. A milestone that paid out would need its own id in
/// `AchievementManager.allAchievements` (`remember.md` §12b rule 2), and an
/// unbacked payout is exactly the "announce what you do not apply" failure §8
/// exists to stop. These name progress; they do not buy anything.
@immutable
class EventMilestone {
  const EventMilestone({
    required this.nights,
    required this.name,
    required this.description,
  });

  /// Nights lit needed to reach this stage. Must be at least 1 and no more than
  /// the number of nights the window actually has — [SeasonalEventManager
  /// .validate] refuses an unreachable one.
  final int nights;

  final String name;
  final String description;

  @override
  String toString() => 'EventMilestone($nights, $name)';
}

/// One seasonal event, as shipped in the binary.
@immutable
class SeasonalEventDefinition {
  const SeasonalEventDefinition({
    required this.id,
    required this.name,
    required this.tagline,
    required this.emoji,
    required this.window,
    required this.featuredGameIds,
    required this.badge,
    this.featuredModifierTypes = const <String>[],
    this.milestones = const <EventMilestone>[],
    this.priority = 0,
    this.firstYear,
    this.lastYear,
  });

  final String id;
  final String name;

  /// One line for the banner. Kept short — the banner is a single row on a
  /// 320px phone.
  final String tagline;

  final String emoji;
  final EventWindow window;

  /// Games the event puts forward. Filter through
  /// [SeasonalEventManager.liveFeaturedGames] before offering any of them.
  final List<String> featuredGameIds;

  /// Modifier types the event leans on. **Naming one here does not apply it,
  /// and nothing in the UI may show them.**
  ///
  /// 2.2 looked at wiring these into play and refused. Every route runs through
  /// a file `remember.md` Section A protects: the pool a level draws from is
  /// assembled per game screen and handed to `RotationEngine.getActiveModifiers`
  /// (game screens are off limits), `ice` exists only inside
  /// `DailyChallengeManager` (off limits), and the schedule that engine walks is
  /// a pure function of game id and level index — making it depend on the
  /// calendar would mean the same level renders differently in December than in
  /// June, which breaks the determinism `test/difficulty_curve_test.dart`
  /// asserts and the "difficulty must climb" rule it exists to protect. The
  /// data stays as a marker for whoever owns those files.
  final List<String> featuredModifierTypes;

  final EventBadge badge;

  /// Named stages along the night trail, ascending. Optional: an event with
  /// none still records nights, it just does not name any of them.
  ///
  /// These are labels, not rewards. Nothing here grants points, a title or an
  /// achievement — the badge is the only thing this framework awards.
  final List<EventMilestone> milestones;

  /// Higher wins when two windows overlap.
  final int priority;

  /// Optional bounds for a one-off event. Both refer to the year the occurrence
  /// *starts* in, so a window spanning New Year is bounded by its December.
  final int? firstYear;
  final int? lastYear;
}

/// A definition resolved against a concrete date.
@immutable
class SeasonalEventOccurrence {
  const SeasonalEventOccurrence({
    required this.definition,
    required this.start,
    required this.end,
    required this.date,
  });

  final SeasonalEventDefinition definition;

  /// Local midnight of the first day of this run.
  final DateTime start;

  /// Local midnight of the last day of this run (inclusive).
  final DateTime end;

  /// The local date this occurrence was resolved for.
  final DateTime date;

  /// Stable identity for this run — `yyyy-MM-dd` of [start]. Every date inside
  /// a window that spans New Year shares the December key, so progress does not
  /// reset at midnight on the 31st.
  String get occurrenceKey => SeasonalEventManager.dateKeyFor(start);

  /// 1 on the first day of the event.
  int get dayIndex => SeasonalEventManager.dayDifference(start, date) + 1;

  /// Total days in this run, both ends inclusive.
  int get totalDays => SeasonalEventManager.dayDifference(start, end) + 1;

  /// 0 on the last day.
  int get daysRemaining => SeasonalEventManager.dayDifference(date, end);

  bool get isFirstDay => dayIndex == 1;
  bool get isLastDay => daysRemaining == 0;

  @override
  String toString() => 'SeasonalEventOccurrence(${definition.id}, '
      'day $dayIndex/$totalDays, key $occurrenceKey)';
}

/// What [SeasonalEventManager.recordProgress] did.
enum EventProgressOutcome {
  /// No event is running; nothing was written.
  noEvent,

  /// Progress went up, and the badge is not earned yet.
  recorded,

  /// This call took the player over the line. The badge is now
  /// unlocked-but-unclaimed.
  badgeUnlocked,

  /// The badge was already unlocked. Nothing was re-awarded.
  alreadyEarned,
}

/// The result of recording event progress.
@immutable
class EventProgressUpdate {
  const EventProgressUpdate({
    required this.outcome,
    required this.occurrence,
    required this.progress,
    required this.requiredProgress,
    required this.badgeId,
    this.litNights = const <int>{},
    this.newNightLit = false,
  });

  final EventProgressOutcome outcome;
  final SeasonalEventOccurrence? occurrence;
  final int progress;
  final int requiredProgress;
  final String? badgeId;

  /// Day indices of this occurrence the player has now been active on.
  final Set<int> litNights;

  /// True when this call lit a night that was not lit before — i.e. the
  /// player's first activity today. Lets a caller celebrate once a day rather
  /// than once a level.
  final bool newNightLit;

  bool get justUnlocked => outcome == EventProgressOutcome.badgeUnlocked;

  /// The stage this call reached, or null when it crossed none. Null-safe
  /// outside an event.
  EventMilestone? get milestoneReached {
    final SeasonalEventOccurrence? o = occurrence;
    if (o == null || !newNightLit) return null;
    for (final EventMilestone m in o.definition.milestones) {
      if (m.nights == litNights.length) return m;
    }
    return null;
  }

  @override
  String toString() =>
      'EventProgressUpdate($outcome, $progress/$requiredProgress, badge: $badgeId, '
      'nights: ${litNights.length})';
}

/// A read-only snapshot for the UI.
@immutable
class SeasonalEventState {
  const SeasonalEventState({
    required this.occurrence,
    required this.progress,
    required this.requiredProgress,
    required this.badgeUnlocked,
    required this.badgeClaimed,
    required this.bannerDismissed,
    this.litNights = const <int>{},
  });

  /// Null when no event is running.
  final SeasonalEventOccurrence? occurrence;

  final int progress;
  final int requiredProgress;

  /// Earned. Says nothing about whether the reward was handed over.
  final bool badgeUnlocked;

  /// The player tapped Claim and the reward was dispatched.
  final bool badgeClaimed;

  final bool bannerDismissed;

  /// 1-based day indices of this occurrence the player has been active on.
  final Set<int> litNights;

  bool get isActive => occurrence != null;

  /// Nights lit so far. Never exceeds [totalNights] — [SeasonalEventManager
  /// ._readNights] drops anything outside the window.
  int get nightsLit => litNights.length;

  /// Nights this occurrence has in total. Zero when no event is running.
  int get totalNights => occurrence?.totalDays ?? 0;

  /// Whether the player has already been active today.
  bool get litTonight =>
      occurrence != null && litNights.contains(occurrence!.dayIndex);

  /// Stages named by this event, in ascending order. Empty when it names none.
  List<EventMilestone> get milestones =>
      occurrence?.definition.milestones ?? const <EventMilestone>[];

  /// The highest stage reached, or null if none is.
  EventMilestone? get currentMilestone {
    final SeasonalEventOccurrence? o = occurrence;
    if (o == null) return null;
    final List<EventMilestone> reached =
        SeasonalEventManager.reachedMilestones(o.definition, nightsLit);
    return reached.isEmpty ? null : reached.last;
  }

  /// The next stage above where the player is, or null once all are reached.
  EventMilestone? get nextMilestone {
    final SeasonalEventOccurrence? o = occurrence;
    if (o == null) return null;
    return SeasonalEventManager.nextMilestone(o.definition, nightsLit);
  }

  /// Games this event puts forward that the app can actually open. Empty
  /// outside an event.
  List<GameInfo> get featuredGames {
    final SeasonalEventOccurrence? o = occurrence;
    if (o == null) return const <GameInfo>[];
    return SeasonalEventManager.liveFeaturedGames(o.definition);
  }

  /// True exactly when there is a reward waiting to be collected.
  bool get hasUnclaimedBadge => badgeUnlocked && !badgeClaimed;

  /// 0.0–1.0. Zero when no event is running.
  double get fraction {
    if (requiredProgress <= 0) return 0.0;
    final double f = progress / requiredProgress;
    return f < 0.0 ? 0.0 : (f > 1.0 ? 1.0 : f);
  }

  @override
  String toString() => 'SeasonalEventState(${occurrence?.definition.id}, '
      '$progress/$requiredProgress, unlocked: $badgeUnlocked, '
      'claimed: $badgeClaimed, nights: $nightsLit/$totalNights)';
}
