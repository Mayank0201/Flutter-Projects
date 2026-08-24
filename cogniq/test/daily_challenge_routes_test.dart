import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cogniq/models/game_info.dart';
import 'package:cogniq/utils/daily_challenge_manager.dart';

/// Guards the crash found on 2026-08-22.
///
/// The 30-day daily plan scheduled 16 of its 90 slots on stashed games — wordle,
/// hangman, flagle, memory, numbermemory, sequence, wordbuilder. Their routes are
/// commented out in `main.dart`, and `MaterialApp` declares no `onUnknownRoute`,
/// so `daily_screen.dart`'s `Navigator.pushNamed(context, game.routeName)` threw
/// an unhandled exception. Every one of those days crashed the app when tapped.
///
/// The resolver now substitutes a live challenge. These tests fail if a stashed
/// game can ever reach a player again — including via a game stashed in future.
///
/// 2.3 deleted those ten games outright. The plan still names them, deliberately:
/// `_isLiveGame` treats an unknown id exactly as it treats a stashed one, so the
/// substitution — and therefore the challenge every date resolves to — is
/// unchanged, whereas rewriting the plan's slots would move every player's daily.
void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test('no daily challenge ever resolves to a stashed game', () {
    final stashed = {
      for (final g in kAllGames)
        if (g.isStashed) g.id,
    };
    // NOTE: this was `expect(stashed, isNotEmpty)` as a guard against a vacuous
    // test — and it was right to worry. With nothing stashed,
    // `stashed.contains(...)` below is always false and this test proves
    // nothing. But the guard itself breaks the moment the stashed set legitimately
    // empties (2.3 deletes ten stashed games and revives Cipher Decoder, the
    // last one).
    //
    // So assert the property positively instead: every offered game must be a
    // real, live, routable entry. That is strictly stronger than "not stashed",
    // and it cannot go vacuous however `kAllGames` changes.
    final liveIds = {
      for (final g in kAllGames)
        if (!g.isStashed) g.id,
    };
    expect(liveIds, isNotEmpty, reason: 'sanity: some games must be live');

    // A full cycle of the plan, several times over, to cover the rotation.
    for (var day = 0; day < 14 * 7 * 3; day++) {
      final challenges = DailyChallengeManager.getChallengesForDay(day);
      expect(challenges, hasLength(3), reason: 'day $day did not yield 3 slots');
      for (final c in challenges) {
        expect(stashed.contains(c.game.id), isFalse,
            reason: 'day $day offers stashed game "${c.game.id}" — tapping it '
                'would throw an unknown-route exception');
        expect(liveIds.contains(c.game.id), isTrue,
            reason: 'day $day offers "${c.game.id}", which is not a live game '
                '— tapping it would throw an unknown-route exception');
        expect(c.game.routeName, isNotEmpty,
            reason: 'day $day offers "${c.game.id}" with no route');
        expect(c.game.isStashed, isFalse);
      }
    }
  });

  test('every offered game has a non-empty route name', () {
    for (var day = 0; day < 100; day++) {
      for (final c in DailyChallengeManager.getChallengesForDay(day)) {
        expect(c.game.routeName, startsWith('/'),
            reason: 'day $day: "${c.game.id}" has no usable route');
      }
    }
  });

  test('the same day always yields the same challenges', () {
    // Substitution must be deterministic, or a player could see the daily change
    // under them between two openings of the screen.
    for (final day in [0, 1, 7, 13, 40, 97]) {
      final a = DailyChallengeManager.getChallengesForDay(day);
      final b = DailyChallengeManager.getChallengesForDay(day);
      expect(a.map((c) => c.game.id).toList(), b.map((c) => c.game.id).toList());
      expect(a.map((c) => c.levelIndex).toList(),
          b.map((c) => c.levelIndex).toList());
    }
  });
}
