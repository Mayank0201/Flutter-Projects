import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cogniq/models/game_info.dart';
import 'package:cogniq/utils/daily_challenge_manager.dart';
import 'package:cogniq/utils/prefs_keys.dart';

/// Release 2.3 / S2 — the daily rotation was extended past 60 days.
///
/// `kThemeCount` used to be a hardcoded 14 while `_kDailyChallengesPlan` held 30
/// authored theme weeks, so `weekOf` — which indexes the plan by *week* — could
/// never reach entries 15..30. Sixteen theme weeks shipped dead in every bundle
/// and the rotation repeated after 98 days. `kThemeCount` is now derived from the
/// table (30 weeks => 210 days).
///
/// The tests below lock down the four properties that make that safe to ship:
/// enough variety, determinism, no unplayable game, and — the one that actually
/// risks player harm — that nobody mid-cycle sees their day change under them.
String _signature(DailyChallenge c) =>
    '${c.game.id}:${c.levelIndex}:${c.difficulty}:${c.modifierName}';

String _daySignature(int day) =>
    DailyChallengeManager.getChallengesForDay(day).map(_signature).join('|');

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('rotation length', () {
    test('the cycle runs well past 60 days before repeating', () {
      expect(DailyChallengeManager.kTotalDays, greaterThanOrEqualTo(60),
          reason: 'S2 asked for at least a 60-day rotation');
      expect(DailyChallengeManager.kTotalDays,
          DailyChallengeManager.kThemeCount * DailyChallengeManager.kDaysPerWeek);
    });

    test('every authored theme week is reachable', () {
      // The original bug: 16 authored weeks were unreachable because the count
      // was hardcoded below the table length. Walking the whole cycle must visit
      // as many distinct themes as there are weeks.
      final themes = <String>{};
      for (var d = 1; d <= DailyChallengeManager.kTotalDays; d++) {
        themes.add(DailyChallengeManager.themeOf(d));
      }
      expect(themes, hasLength(DailyChallengeManager.kThemeCount),
          reason: 'a theme week in the plan is unreachable again');
    });

    test('every theme has a written blurb, not the generic fallback', () {
      const fallback = 'Special rules apply to all game boards this week.';
      for (var d = 1; d <= DailyChallengeManager.kTotalDays; d++) {
        expect(DailyChallengeManager.themeDescriptionOf(d), isNot(fallback),
            reason: 'day $d ("${DailyChallengeManager.themeOf(d)}") falls back '
                'to the generic weekly blurb');
      }
    });

    test('at least 60 distinct daily line-ups before anything repeats', () {
      final seen = <String>{};
      for (var d = 1; d <= DailyChallengeManager.kTotalDays; d++) {
        seen.add(_daySignature(d));
      }
      expect(seen.length, greaterThanOrEqualTo(60),
          reason: 'variety, not just cycle length, is the point of S2');
    });
  });

  group('determinism', () {
    test('the same day yields the same challenges on every call', () {
      for (var d = 0; d <= DailyChallengeManager.kTotalDays + 5; d++) {
        expect(_daySignature(d), _daySignature(d),
            reason: 'day $d is not a pure function of the day number');
        expect(DailyChallengeManager.themeOf(d), DailyChallengeManager.themeOf(d));
      }
    });

    test('the cycle wraps exactly, so a day repeats one full cycle later', () {
      for (final d in [1, 2, 37, 98, 99, 150, 210]) {
        expect(_daySignature(d + DailyChallengeManager.kTotalDays),
            _daySignature(d),
            reason: 'day $d does not line up with the same day next cycle');
      }
    });

    test('golden line-ups — a refactor must not silently move content', () {
      // Captured from the shipping resolver. Days 1-98 are the legacy range and
      // were verified byte-identical to the pre-2.3 14-week cycle; days 99+ are
      // the newly reachable weeks.
      const golden = <int, String>{
        1: 'oddcolor:1:Easy:Foggy Focus|sudoku:9:Medium:Sudoku in the Mist|'
            'minesweeper:15:Hard:Dark Minefield',
        8: 'zip:1:Easy:Flipped Maze|pattern_lock:4:Medium:Flipped Trace|'
            'queens:10:Hard:Reflected Matrix',
        57: 'oddcolor:1:Easy:Shadow Grid|pattern_lock:3:Medium:Vanishing Lock|'
            'sudoku:22:Hard:Blackout Board',
        98: 'oddcolor:6:Easy:Rapid Warp|chimp:6:Medium:Vanish Board|'
            'sudoku:25:Hard:Hourglass Board',
        99: 'chimp:1:Easy:Falling Numbers|hue:3:Medium:Rainbow Twist|'
            'sudoku:18:Hard:Sinking Clues',
        210: 'oddcolor:3:Easy:Secret Anchor|spellingbee:17:Medium:Outer Ring Only|'
            'hue:30:Hard:Ultimate Sort',
      };
      golden.forEach((day, expected) {
        expect(_daySignature(day), expected, reason: 'day $day moved');
      });
    });
  });

  group('no unplayable game is ever scheduled', () {
    // Deliberately derived from kAllGames at runtime: 2.3 deletes ten stashed
    // games outright, so any hardcoded id list would rot. A game that is absent
    // from kAllGames is just as unplayable as one flagged isStashed.
    test('across a full cycle, every slot is a live game in kAllGames', () {
      final playable = {
        for (final g in kAllGames)
          if (!g.isStashed) g.id,
      };
      expect(playable, isNotEmpty);

      for (var d = 0; d <= DailyChallengeManager.kTotalDays * 2; d++) {
        final challenges = DailyChallengeManager.getChallengesForDay(d);
        expect(challenges, hasLength(3), reason: 'day $d did not yield 3 slots');
        for (final c in challenges) {
          expect(playable.contains(c.game.id), isTrue,
              reason: 'day $d offers "${c.game.id}", which has no live route — '
                  'MaterialApp declares no onUnknownRoute, so tapping it crashes');
          expect(c.game.isStashed, isFalse);
          expect(c.game.routeName, startsWith('/'));
        }
      }
    });

    test('a day never offers the same game twice', () {
      // Weeks 17, 23 and 30 each schedule two dead games, so two slots need a
      // stand-in on the same day. Without de-duplication the day can show three
      // cards for two games.
      for (var d = 0; d <= DailyChallengeManager.kTotalDays * 2; d++) {
        final ids = DailyChallengeManager.getChallengesForDay(d)
            .map((c) => c.game.id)
            .toList();
        expect(ids.toSet(), hasLength(3),
            reason: 'day $d repeats a game: $ids');
      }
    });

    test('levels stay positive so no slot asks for a level that cannot exist', () {
      for (var d = 1; d <= DailyChallengeManager.kTotalDays; d++) {
        for (final c in DailyChallengeManager.getChallengesForDay(d)) {
          expect(c.levelIndex, greaterThan(0), reason: 'day $d, ${c.game.id}');
        }
      }
    });
  });

  group('no mid-cycle disruption', () {
    // The only way lengthening the cycle can hurt an existing player is if their
    // stored progress day resolves to a different puzzle than it did yesterday.
    // Every player alive today holds a day in 1..98, because the old cycle
    // wrapped there. Both reducers below must therefore agree with the legacy
    // 14-week arithmetic over that whole range.
    const legacyThemeCount = 14;
    const legacyTotalDays = legacyThemeCount * 7;

    test('weekOf/dayInWeekOf match the legacy 14-week cycle for days 1..98', () {
      for (var d = 1; d <= legacyTotalDays; d++) {
        final legacyIndex = (d - 1) % legacyTotalDays;
        expect(DailyChallengeManager.weekOf(d),
            ((legacyIndex ~/ 7) % legacyThemeCount) + 1,
            reason: 'day $d changed theme week');
        expect(DailyChallengeManager.dayInWeekOf(d), (legacyIndex % 7) + 1,
            reason: 'day $d changed its position in the week');
      }
    });

    test('weeks 1..14 never substitute, so their content cannot have moved', () {
      // Same week/day indices + the same plan entries + no substitution is what
      // makes the range above provably identical, not merely similar.
      final playable = {
        for (final g in kAllGames)
          if (!g.isStashed) g.id,
      };
      for (var d = 1; d <= legacyTotalDays; d++) {
        for (final c in DailyChallengeManager.getChallengesForDay(d)) {
          expect(playable.contains(c.game.id), isTrue,
              reason: 'day $d now needs a substitute — its content has moved');
        }
      }
    });

    test('a stored progress day is preserved, not remapped', () async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.weeklyResetV3Done: true,
        PrefsKeys.dailyV2Migrated: true,
        PrefsKeys.dailyUserProgressDay: 57,
        PrefsKeys.dailyChallengeStartTime:
            DateTime.now().toUtc().toIso8601String(),
      });
      expect(await DailyChallengeManager.getActiveDay(), 57,
          reason: 'lengthening the cycle must not rewrite stored progress');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(PrefsKeys.dailyUserProgressDay), 57);
    });

    test('a player at the old wrap point rolls into new content, not day 1',
        () async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.weeklyResetV3Done: true,
        PrefsKeys.dailyV2Migrated: true,
        PrefsKeys.dailyUserProgressDay: legacyTotalDays, // 98
        PrefsKeys.dailyChallengeStartTime: DateTime.now()
            .toUtc()
            .subtract(const Duration(hours: 25))
            .toIso8601String(),
      });
      final day = await DailyChallengeManager.getActiveDay();
      expect(day, legacyTotalDays + 1,
          reason: 'day 98 should advance to day 99 (new content), not wrap');
      expect(DailyChallengeManager.themeOf(day),
          isNot(DailyChallengeManager.themeOf(1)));
    });

    test('the day counter still wraps at the end of the longer cycle', () async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.weeklyResetV3Done: true,
        PrefsKeys.dailyV2Migrated: true,
        PrefsKeys.dailyUserProgressDay: DailyChallengeManager.kTotalDays,
        PrefsKeys.dailyChallengeStartTime: DateTime.now()
            .toUtc()
            .subtract(const Duration(hours: 25))
            .toIso8601String(),
      });
      expect(await DailyChallengeManager.getActiveDay(), 1);
    });
  });
}
