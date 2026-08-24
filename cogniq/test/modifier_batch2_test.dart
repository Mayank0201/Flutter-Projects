import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cogniq/utils/hint_manager.dart';
import 'package:cogniq/utils/point_manager.dart';
import 'package:cogniq/utils/rotation_engine.dart';
import 'package:cogniq/utils/zen_mode.dart';

import 'package:cogniq/widgets/decaying_clue.dart';
import 'package:cogniq/widgets/momentum_meter.dart';
import 'package:cogniq/widgets/pulse_vision.dart';

import 'package:cogniq/screens/games/kakuro/kakuro_screen.dart';
import 'package:cogniq/screens/games/sandsort/sandsort_screen.dart';
import 'package:cogniq/screens/games/slitherlink/slitherlink_screen.dart';
import 'package:cogniq/screens/games/spectrum/spectrum_screen.dart';
import 'package:cogniq/screens/games/sum_strike/sum_strike_screen.dart';
import 'package:cogniq/screens/games/word_hive/word_hive_screen.dart';

/// Guards modifier batch 2 — `momentum`, `decay` and `heartbeat`.
///
/// The pools imported here are the ones the screens actually pass to
/// [RotationEngine.getActiveModifiers], not copies, so a pool edited in a game
/// screen is checked by these tests rather than by a stale mirror. The mirror
/// in test/difficulty_curve_test.dart still has to be kept in step by hand.

/// Every free-play pool batch 2 touches, keyed by the game id the *screen*
/// passes to RotationEngine — not the catalogue id (remember.md section 12).
const poolsUnderTest = <String, List<String>>{
  'spellingbee': kWordHiveModifierPool,
  'sumstrike': kSumStrikeGeneratedPool,
  'kakuro': kKakuroModifierPool,
  'slitherlink': kSlitherlinkModifierPool,
  'sandsort': kSandSortModifierPool,
  'spectrum': kSpectrumModifierPool,
};

Set<String> modsAt(String gameId, List<String> pool, int level) =>
    RotationEngine.getActiveModifiers(
      gameId: gameId,
      levelIndex: level,
      pool: pool,
    );

/// Longest run of consecutive levels whose modifier set never changes.
int longestFlatRun(List<String> signatures) {
  var longest = 1, run = 1;
  for (var i = 1; i < signatures.length; i++) {
    if (signatures[i] == signatures[i - 1]) {
      run++;
      if (run > longest) longest = run;
    } else {
      run = 1;
    }
  }
  return longest;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ZenMode.setEnabled(false);
  });

  // --------------------------------------------------------------------------
  group('pool safety', () {
    test('every pool is large enough for the pairs tier', () {
      // RotationEngine runs a singles tier and then a pairs tier that lasts at
      // least 35 levels. A two-entry pool has exactly one pair, so it would
      // serve the same combination for all 35 of them. Batch 2 is what lifts
      // Kakuro, Slitherlink and Sand Sort off three entries.
      for (final entry in poolsUnderTest.entries) {
        expect(entry.value.length, greaterThanOrEqualTo(3),
            reason: '${entry.key} cannot fill the pairs tier');
      }
      expect(kSumStrikeCuratedPool.length, greaterThanOrEqualTo(3));
    });

    test('no pool lists the same modifier twice', () {
      for (final entry in poolsUnderTest.entries) {
        expect(entry.value.toSet().length, entry.value.length,
            reason: '${entry.key} repeats a modifier');
      }
    });

    test('heartbeat never shares a pool with eclipse', () {
      // In this codebase `eclipse` IS a periodic blackout — odd_color_out's
      // `_startDailyTimers` toggles `_isShadowed` every three seconds — so a
      // pool holding both would enumerate the pair and run one mechanic under
      // two names. RotationEngine enumerates every pair, so the only place to
      // keep them apart is the pool.
      for (final entry in poolsUnderTest.entries) {
        final both = entry.value.contains('heartbeat') &&
            entry.value.contains('eclipse');
        expect(both, isFalse,
            reason: '${entry.key} carries both heartbeat and eclipse');
      }
    });

    test('heartbeat never shares a pool with another occluder', () {
      // fog, whisper and monochrome-style hiding all take information away
      // spatially; heartbeat takes all of it away temporally. Stacked, the
      // board is never fully readable at any instant. monochrome is the one
      // exception and is allowed: Sand Sort keeps a distinct shape on every
      // layer, so nothing is actually hidden by it.
      const occluders = {'fog', 'eclipse', 'clueThinning', 'whisper',
        'wildcard', 'hiddenCount', 'hiddenIslands', 'hiddenPearls', 'minimal'};
      for (final entry in poolsUnderTest.entries) {
        if (!entry.value.contains('heartbeat')) continue;
        for (final m in entry.value) {
          expect(occluders.contains(m), isFalse,
              reason: '${entry.key} pairs heartbeat with $m');
        }
      }
    });

    test('decay never shares a pool with a clue remover or a clue masker', () {
      // `clueThinning` deletes givens, `wildcard` replaces cage sums with "?",
      // `eclipse` hides the board for a timed recall phase. Fading a clue that
      // has already been deleted or masked does nothing except charge the
      // player for a tap that reveals a "?"; fading one during a recall phase
      // makes that phase unfair. None may co-occur with decay.
      const forbidden = {'clueThinning', 'wildcard', 'eclipse'};
      for (final entry in poolsUnderTest.entries) {
        if (!entry.value.contains('decay')) continue;
        for (final m in entry.value) {
          expect(forbidden.contains(m), isFalse,
              reason: '${entry.key} pairs decay with $m');
        }
      }
    });

    test('heartbeat is only ever pooled alongside timer', () {
      // A blank phase costs a patient player nothing on an untimed board. The
      // modifier earns its difficulty from the pair with `timer`, so a pool
      // that offers heartbeat without one is offering a patience tax.
      for (final entry in poolsUnderTest.entries) {
        if (!entry.value.contains('heartbeat')) continue;
        expect(entry.value, contains('timer'),
            reason: '${entry.key} offers heartbeat with no time pressure');
      }
    });

    test('modifier sets still change from level to level', () {
      for (final entry in poolsUnderTest.entries) {
        final start = RotationEngine.modifierStartLevel(entry.key);
        final sets = <String>[
          for (var l = start; l < start + 60; l++)
            (modsAt(entry.key, entry.value, l).toList()..sort()).join('+')
        ];
        expect(longestFlatRun(sets), 1,
            reason: '${entry.key} repeats a modifier set back to back');
      }
    });

    test('a level never carries a modifier outside its pool', () {
      for (final entry in poolsUnderTest.entries) {
        for (var l = 0; l < 150; l++) {
          expect(modsAt(entry.key, entry.value, l).every(entry.value.contains),
              isTrue,
              reason: '${entry.key} produced a modifier outside its pool');
        }
      }
    });
  });

  // --------------------------------------------------------------------------
  group('the new modifiers actually reach the player in free play', () {
    // remember.md E2 section 8: a modifier named in a pool must actually turn
    // up on levels a player will reach, in FREE PLAY and not only in daily
    // mode. Every id below is the free-play id the screen hands RotationEngine.
    void expectReached(String gameId, List<String> pool, String modifier) {
      final start = RotationEngine.modifierStartLevel(gameId);
      var seen = false;
      var seenAlone = false;
      var seenWithTimer = false;
      for (var l = start; l < start + 60; l++) {
        final mods = modsAt(gameId, pool, l);
        if (!mods.contains(modifier)) continue;
        seen = true;
        if (mods.length == 1) seenAlone = true;
        if (mods.contains('timer')) seenWithTimer = true;
      }
      expect(seen, isTrue, reason: '$modifier never fires in $gameId');
      expect(seenAlone, isTrue,
          reason: '$modifier never appears on its own in $gameId');
      if (modifier == 'heartbeat') {
        expect(seenWithTimer, isTrue,
            reason: 'heartbeat never meets timer in $gameId');
      }
    }

    test('momentum reaches Word Hive and Sum Strike', () {
      expectReached('spellingbee', kWordHiveModifierPool, 'momentum');
      expectReached('sumstrike', kSumStrikeGeneratedPool, 'momentum');
      // Below kSumStrikeLevels.length Sum Strike draws from the curated pool,
      // which is where its modifiers begin.
      final start = RotationEngine.modifierStartLevel('sumstrike');
      var seen = false;
      for (var l = start; l < start + 40; l++) {
        if (modsAt('sumstrike', kSumStrikeCuratedPool, l)
            .contains('momentum')) {
          seen = true;
        }
      }
      expect(seen, isTrue,
          reason: 'momentum never fires on a curated Sum Strike level');
    });

    test('decay reaches Kakuro and Slitherlink', () {
      expectReached('kakuro', kKakuroModifierPool, 'decay');
      expectReached('slitherlink', kSlitherlinkModifierPool, 'decay');
    });

    test('heartbeat reaches Sand Sort and Spectrum', () {
      expectReached('sandsort', kSandSortModifierPool, 'heartbeat');
      expectReached('spectrum', kSpectrumModifierPool, 'heartbeat');
    });

    test('the same level always selects the same modifiers', () {
      // Determinism: no bare Random() anywhere on this path.
      for (final entry in poolsUnderTest.entries) {
        for (var l = 0; l < 120; l += 3) {
          final a = modsAt(entry.key, entry.value, l);
          final b = modsAt(entry.key, entry.value, l);
          expect(a, b, reason: '${entry.key} L$l was not reproducible');
        }
      }
    });

    test('Zen Mode suppresses all three', () async {
      await ZenMode.setEnabled(true);
      for (final entry in poolsUnderTest.entries) {
        for (var l = 0; l < 150; l += 3) {
          expect(modsAt(entry.key, entry.value, l), isEmpty,
              reason: '${entry.key} applied modifiers in Zen');
        }
      }
      expect(kSumStrikeCuratedPool.isNotEmpty, isTrue);
      for (var l = 0; l < 150; l += 3) {
        expect(modsAt('sumstrike', kSumStrikeCuratedPool, l), isEmpty);
      }
      await ZenMode.setEnabled(false);
    });
  });

  // --------------------------------------------------------------------------
  group('momentum — the combo chain', () {
    /// A controller on a clock the test drives, so nothing has to sleep.
    ({MomentumController c, void Function(int) advance}) build() {
      var now = DateTime(2026);
      final c = MomentumController(
        onChanged: () {},
        window: const Duration(seconds: 4),
        clock: () => now,
      );
      return (c: c, advance: (ms) => now = now.add(Duration(milliseconds: ms)));
    }

    test('a lone correct action scores x1, not x2', () {
      // The handbook increments before recording, so the FIRST correct action
      // is credited x2 and every level with a single scored action pays double
      // for nothing. That is why Odd Colour Out — one tap per level — is not a
      // momentum host, and why the first action of a chain scores x1 here.
      final t = build();
      t.c.correct();
      expect(t.c.multiplier, 1);
      expect(t.c.averageMultiplier, 1.0);
      expect(t.c.bonusPoints, 0);
      t.c.dispose();
    });

    test('rapid corrects climb to x5 and stop there', () {
      final t = build();
      final seen = <int>[];
      for (var i = 0; i < 8; i++) {
        t.advance(500);
        t.c.correct();
        seen.add(t.c.multiplier);
      }
      expect(seen, [1, 2, 3, 4, 5, 5, 5, 5]);
      t.c.dispose();
    });

    test('a gap longer than the window breaks the chain', () {
      final t = build();
      t.c.correct();
      t.advance(500);
      t.c.correct();
      expect(t.c.multiplier, 2);
      t.advance(4001);
      t.c.correct();
      expect(t.c.multiplier, 1, reason: 'an idle gap must reset the chain');
      t.c.dispose();
    });

    test('a mistake resets the chain and drags the average down', () {
      final t = build();
      t.advance(100);
      t.c.correct(); // x1
      t.advance(100);
      t.c.correct(); // x2
      expect(t.c.averageMultiplier, 1.5);
      t.c.mistake(); // scores x1
      expect(t.c.multiplier, 1);
      expect(t.c.averageMultiplier, closeTo(4 / 3, 1e-9));
      t.advance(100);
      t.c.correct(); // chain was broken, so x1 again
      expect(t.c.multiplier, 1);
      t.c.dispose();
    });

    test('reset clears the level so nothing is carried over or paid twice', () {
      final t = build();
      for (var i = 0; i < 5; i++) {
        t.advance(200);
        t.c.correct();
      }
      expect(t.c.bonusPoints, greaterThan(0));
      t.c.reset();
      expect(t.c.events, 0);
      expect(t.c.multiplier, 1);
      expect(t.c.averageMultiplier, 1.0);
      expect(t.c.bonusPoints, 0);
      t.c.dispose();
    });

    test('the idle decay timer resets the live multiplier', () async {
      final changes = <int>[];
      final c = MomentumController(
        onChanged: () {},
        window: const Duration(milliseconds: 40),
      );
      c.correct();
      c.correct();
      changes.add(c.multiplier);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(c.multiplier, 1, reason: 'idling must cool the meter off');
      c.dispose();
    });

    test('an untouched controller never creates a timer', () async {
      // A screen rendered on a level without momentum must not leave a pending
      // timer behind — that is what makes the widget tests hang.
      final c = MomentumController(onChanged: () {});
      expect(c.events, 0);
      c.dispose();
    });
  });

  // --------------------------------------------------------------------------
  group('momentum — the points economy, with no double-pay', () {
    // The handbook says to REPLACE `addPoints(10)` on win. There is no
    // `addPoints(10)` in any game screen: HintManager.onLevelCleared holds the
    // base award for all 22 games, and the `addPoints(5)` the screens do call
    // is a speed bonus. Paying `10 * avg` on top therefore pays the base twice.
    // These tests pin the composition that ships instead.

    test('the bonus is the difference above the base, never a second award', () {
      expect(momentumBonusPoints(1.0), 0);
      expect(momentumBonusPoints(1.5), 5);
      expect(momentumBonusPoints(2.0), 10);
      expect(momentumBonusPoints(3.4), 24);
      expect(momentumBonusPoints(5.0), 40);
    });

    test('the bonus can never go negative or run away', () {
      for (var x = 0.0; x <= 12.0; x += 0.05) {
        final b = momentumBonusPoints(x);
        expect(b, greaterThanOrEqualTo(0));
        expect(b, lessThanOrEqualTo(40));
      }
    });

    test('an unchained clear is worth exactly what it was before momentum', () async {
      SharedPreferences.setMockInitialValues({});
      await ZenMode.setEnabled(false);
      expect(await PointManager.getPoints(), 0);

      await HintManager.onLevelCleared('spellingbee');
      await PointManager.addPoints(momentumBonusPoints(1.0));

      expect(await PointManager.getPoints(), 10,
          reason: 'a x1 average must add nothing on top of the base 10');
    });

    test('a perfect chain pays base 10 + bonus 40, and nothing else', () async {
      SharedPreferences.setMockInitialValues({});
      await ZenMode.setEnabled(false);

      await HintManager.onLevelCleared('sumstrike');
      await PointManager.addPoints(momentumBonusPoints(5.0));

      expect(await PointManager.getPoints(), 50,
          reason: 'base 10 + bonus 40 — not 10 + 50, and not 50 + 50');
    });

    test('the speed bonus stays separate and unmultiplied', () async {
      SharedPreferences.setMockInitialValues({});
      await ZenMode.setEnabled(false);

      // Exactly what a screen does on a timed level cleared under momentum.
      await HintManager.onLevelCleared('sumstrike');
      await PointManager.addPoints(momentumBonusPoints(3.0));
      await PointManager.addPoints(5); // _timeLeft > 0 && _timeBonusEarned

      expect(await PointManager.getPoints(), 10 + 20 + 5);
    });

    test('Zen pays its half award and momentum cannot add to it', () async {
      SharedPreferences.setMockInitialValues({});
      await ZenMode.setEnabled(true);

      // Zen suppresses the whole rotation, so `_isModActive('momentum')` is
      // false and the screen never reaches its payout at all.
      expect(modsAt('spellingbee', kWordHiveModifierPool, 40), isEmpty);
      expect(modsAt('sumstrike', kSumStrikeGeneratedPool, 40), isEmpty);

      await HintManager.onLevelCleared('spellingbee');
      expect(await PointManager.getPoints(), 5,
          reason: 'Zen must still pay half, with no combo bonus on top');

      await ZenMode.setEnabled(false);
    });

    test('two clears in a row pay two bases and two bonuses, not four', () async {
      SharedPreferences.setMockInitialValues({});
      await ZenMode.setEnabled(false);

      for (var i = 0; i < 2; i++) {
        await HintManager.onLevelCleared('spellingbee');
        await PointManager.addPoints(momentumBonusPoints(2.0));
      }
      expect(await PointManager.getPoints(), (10 + 10) * 2);
    });
  });

  // --------------------------------------------------------------------------
  group('decay — fading clues', () {
    test('a clue holds, then fades, then floors', () {
      expect(decayClueOpacity(secondsShown: 0, wasRevealed: false), 1.0);
      expect(decayClueOpacity(secondsShown: 24, wasRevealed: false), 1.0);
      expect(decayClueOpacity(secondsShown: 25, wasRevealed: false), 1.0);
      final mid = decayClueOpacity(secondsShown: 27, wasRevealed: false);
      expect(mid, lessThan(1.0));
      expect(mid, greaterThan(kDecayFloorOpacity));
      expect(decayClueOpacity(secondsShown: 30, wasRevealed: false),
          kDecayFloorOpacity);
      expect(decayClueOpacity(secondsShown: 900, wasRevealed: false),
          kDecayFloorOpacity);
    });

    test('a faded clue never vanishes, so it stays findable and tappable', () {
      for (var s = 0; s < 400; s++) {
        for (final revealed in [false, true]) {
          final o = decayClueOpacity(secondsShown: s, wasRevealed: revealed);
          expect(o, greaterThanOrEqualTo(kDecayFloorOpacity));
          expect(o, lessThanOrEqualTo(1.0));
        }
      }
    });

    test('the opacity curve only ever decreases', () {
      for (final revealed in [false, true]) {
        var previous = 1.0;
        for (var s = 0; s < 60; s++) {
          final o = decayClueOpacity(secondsShown: s, wasRevealed: revealed);
          expect(o, lessThanOrEqualTo(previous + 1e-9),
              reason: 'opacity went back up at ${s}s');
          previous = o;
        }
      }
    });

    test('a re-reveal is short, not a permanent restore', () {
      // The handbook promises a 3-second re-reveal in its prose and then writes
      // `_revealedAt[i] = _clock`, which hands back the FULL 25-second hold —
      // a re-reveal that restores the clue permanently is not a modifier.
      expect(kDecayRevealSeconds, lessThan(kDecayHoldSeconds));
      expect(decayClueOpacity(secondsShown: 5, wasRevealed: true), 1.0);
      expect(decayClueOpacity(secondsShown: 10, wasRevealed: true),
          kDecayFloorOpacity);
      // The same elapsed time that a fresh clue is still fully bright at.
      expect(decayClueOpacity(secondsShown: 10, wasRevealed: false), 1.0);
    });

    test('a stopped controller reports every clue fully readable', () {
      final c = DecayController(onChanged: () {});
      expect(c.isRunning, isFalse);
      expect(c.opacityFor(0), 1.0);
      expect(c.isFaded(0), isFalse);
      // Nothing to reveal, and nothing charged, when the modifier is off.
      expect(c.reveal(0), isFalse);
      c.dispose();
    });

    test('reveal refuses — and so charges nothing — on a bright clue', () async {
      var changes = 0;
      final c = DecayController(onChanged: () => changes++);
      c.start();
      expect(c.reveal(3), isFalse,
          reason: 'a stray tap on a readable clue must be free');
      expect(changes, 0);
      c.dispose();
    });

    test('stopping clears the reveal times so the next level starts clean', () {
      final c = DecayController(onChanged: () {});
      c.start();
      c.stop();
      expect(c.clock, 0);
      expect(c.opacityFor(7), 1.0);
      c.dispose();
    });

    test('start never stacks a second clock', () async {
      var ticks = 0;
      final c = DecayController(onChanged: () => ticks++);
      c.start();
      c.start();
      c.start();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(ticks, lessThanOrEqualTo(2),
          reason: 'three start() calls left more than one clock running');
      c.dispose();
    });
  });

  // --------------------------------------------------------------------------
  group('heartbeat — pulse vision', () {
    test('a stopped controller always reports the board visible', () {
      final c = PulseController(onChanged: () {});
      expect(c.isRunning, isFalse);
      expect(c.isVisible, isTrue);
      c.dispose();
    });

    test('the board flips visible and hidden while running', () async {
      final phases = <bool>[];
      final c = PulseController(
        onChanged: () {},
        visible: const Duration(milliseconds: 30),
        hidden: const Duration(milliseconds: 30),
      );
      c.start();
      for (var i = 0; i < 6; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        phases.add(c.isVisible);
      }
      c.dispose();
      expect(phases.contains(true), isTrue);
      expect(phases.contains(false), isTrue,
          reason: 'the board never blanked out');
    });

    test('stop leaves the board visible and silences the loop', () async {
      var reveals = 0;
      final c = PulseController(
        onChanged: () {},
        onReveal: () => reveals++,
        visible: const Duration(milliseconds: 20),
        hidden: const Duration(milliseconds: 20),
      );
      c.start();
      await Future<void>.delayed(const Duration(milliseconds: 70));
      c.stop();
      final after = reveals;
      expect(c.isVisible, isTrue,
          reason: 'a cleared level must not be left blanked out');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(reveals, after,
          reason: 'the pulse kept ticking (and buzzing) after stop');
      expect(c.isVisible, isTrue);
      c.dispose();
    });

    test('start never stacks a second loop', () async {
      var flips = 0;
      final c = PulseController(
        onChanged: () => flips++,
        visible: const Duration(milliseconds: 40),
        hidden: const Duration(milliseconds: 40),
      );
      c.start();
      c.start();
      c.start();
      await Future<void>.delayed(const Duration(milliseconds: 130));
      c.dispose();
      expect(flips, lessThanOrEqualTo(4),
          reason: 'three start() calls left more than one loop running');
    });

    test('dispose stops the loop dead', () async {
      var flips = 0;
      final c = PulseController(
        onChanged: () => flips++,
        visible: const Duration(milliseconds: 20),
        hidden: const Duration(milliseconds: 20),
      );
      c.start();
      c.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 90));
      expect(flips, 0);
    });

    test('the visible phase is not the shorter half of the cycle', () {
      // 1.5s visible against 2.5s hidden leaves the board gone 62% of the time,
      // which in a turn-based puzzle is a patience tax rather than difficulty.
      expect(kPulseVisible.inMilliseconds,
          greaterThan((kPulseHidden.inMilliseconds * 0.7).round()));
    });
  });
}
