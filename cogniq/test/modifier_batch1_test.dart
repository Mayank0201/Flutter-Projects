import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cogniq/utils/rotation_engine.dart';
import 'package:cogniq/utils/zen_mode.dart';

import 'package:cogniq/screens/games/sudoku/sudoku_screen.dart';
import 'package:cogniq/screens/games/mine_finder/mine_finder_screen.dart';
import 'package:cogniq/screens/games/star_battle/star_battle_screen.dart';
import 'package:cogniq/screens/games/grid_path/grid_path_screen.dart';
import 'package:cogniq/screens/games/killer_sudoku/killer_sudoku_screen.dart';
import 'package:cogniq/screens/games/circuit_guide/circuit_guide_screen.dart';

/// Guards modifier batch 1 — `silence`, `quota`, `ratchet`, `wildcard`.
///
/// The pools imported here are the ones the screens actually pass to
/// [RotationEngine.getActiveModifiers], not a copy, so a pool edited in a game
/// screen is checked by these tests rather than by a stale mirror. The mirror
/// in test/difficulty_curve_test.dart still has to be kept in step by hand.

/// Every free-play pool that batch 1 touches, keyed by the game id the screen
/// passes to RotationEngine (not the catalogue id — see remember.md §12).
const poolsUnderTest = <String, List<String>>{
  'sudoku': kSudokuModifierPool,
  'mines': kMineFinderModifierPool,
  'queens': kStarBattleModifierPool,
  'zip': kGridPathModifierPool,
  'killersudoku': kKillerSudokuModifierPool,
  'circuitguide': kCircuitGuideEndgamePool,
};

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

Set<String> modsAt(String gameId, List<String> pool, int level) =>
    RotationEngine.getActiveModifiers(
      gameId: gameId,
      levelIndex: level,
      pool: pool,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ZenMode.setEnabled(false);
  });

  group('pool safety', () {
    test('ratchet and silence never share a pool', () {
      // One defers every judgement to a Submit, the other punishes the moment
      // a piece lands. A level carrying both would contradict itself, and
      // RotationEngine enumerates every pair, so the only place to keep them
      // apart is the pool.
      for (final entry in poolsUnderTest.entries) {
        final hasBoth = entry.value.contains('ratchet') &&
            entry.value.contains('silence');
        expect(hasBoth, isFalse,
            reason: '${entry.key} carries both ratchet and silence');
      }
      // Also true of Circuit Guide's second, presentation-only pool.
      expect(
        kCircuitGuidePresentationPool.contains('ratchet') &&
            kCircuitGuidePresentationPool.contains('silence'),
        isFalse,
      );
    });

    test('every pool is large enough for the pairs tier', () {
      // RotationEngine runs a singles tier and then a pairs tier that lasts at
      // least 35 levels. A two-entry pool has exactly one pair, so it would
      // serve the same combination for all 35 of them.
      for (final entry in poolsUnderTest.entries) {
        expect(entry.value.length, greaterThanOrEqualTo(3),
            reason: '${entry.key} cannot fill the pairs tier');
      }
      expect(kCircuitGuidePresentationPool.length, greaterThanOrEqualTo(3));
    });

    test('no pool lists the same modifier twice', () {
      for (final entry in poolsUnderTest.entries) {
        expect(entry.value.toSet().length, entry.value.length,
            reason: '${entry.key} repeats a modifier');
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
          final mods = modsAt(entry.key, entry.value, l);
          expect(mods.every(entry.value.contains), isTrue,
              reason: '${entry.key} produced a modifier outside its pool');
        }
      }
    });
  });

  group('the new modifiers actually reach the player', () {
    // remember.md E2 §8: a modifier named in a pool must actually turn up on
    // levels a player will reach, in free play and not only in daily mode.
    void expectReached(String gameId, List<String> pool, String modifier) {
      final start = RotationEngine.modifierStartLevel(gameId);
      var seenAlone = false;
      var seen = false;
      for (var l = start; l < start + 60; l++) {
        final mods = modsAt(gameId, pool, l);
        if (mods.contains(modifier)) {
          seen = true;
          if (mods.length == 1) seenAlone = true;
        }
      }
      expect(seen, isTrue, reason: '$modifier never fires in $gameId');
      expect(seenAlone, isTrue,
          reason: '$modifier never appears on its own in $gameId');
    }

    test('silence reaches Sudoku and Mine Finder', () {
      expectReached('sudoku', kSudokuModifierPool, 'silence');
      expectReached('mines', kMineFinderModifierPool, 'silence');
    });

    test('ratchet reaches Star Battle and Grid Path', () {
      expectReached('queens', kStarBattleModifierPool, 'ratchet');
      expectReached('zip', kGridPathModifierPool, 'ratchet');
    });

    test('wildcard reaches Killer Sudoku', () {
      expectReached('killersudoku', kKillerSudokuModifierPool, 'wildcard');
    });

    test('quota reaches Circuit Guide in both of its pools', () {
      expectReached('circuitguide', kCircuitGuideEndgamePool, 'quota');
      // Below the endgame Circuit Guide draws from a presentation-only pool,
      // which is where its modifiers begin (level 14).
      final start = RotationEngine.modifierStartLevel('circuitguide');
      var seen = false;
      for (var l = start; l < 30; l++) {
        if (modsAt('circuitguide', kCircuitGuidePresentationPool, l)
            .contains('quota')) {
          seen = true;
        }
      }
      expect(seen, isTrue,
          reason: 'quota never fires below Circuit Guide\'s endgame');
    });

    test('Zen Mode still suppresses all of them', () async {
      await ZenMode.setEnabled(true);
      for (final entry in poolsUnderTest.entries) {
        for (var l = 0; l < 120; l += 7) {
          expect(modsAt(entry.key, entry.value, l), isEmpty,
              reason: '${entry.key} applied modifiers in Zen');
        }
      }
      await ZenMode.setEnabled(false);
    });
  });

  group('quota — Circuit Guide move budget', () {
    test('a perfect player always has room to spare', () {
      // A budget below the optimum is a broken level, not a hard one.
      for (var level = 0; level < 200; level += 7) {
        for (var optimum = 0; optimum < 90; optimum++) {
          final budget =
              circuitGuideQuotaBudget(optimalMoves: optimum, level: level);
          expect(budget, greaterThanOrEqualTo(optimum + 2),
              reason: 'L$level optimum $optimum got only $budget moves');
        }
      }
    });

    test('the budget tightens as the campaign goes on', () {
      const optimum = 40;
      final early = circuitGuideQuotaBudget(optimalMoves: optimum, level: 14);
      final late = circuitGuideQuotaBudget(optimalMoves: optimum, level: 120);
      expect(late, lessThan(early));
      // ...but never below the floor, and never below the optimum itself.
      expect(late, greaterThan(optimum));
    });

    test('the same level always yields the same budget', () {
      for (var level = 10; level < 60; level += 3) {
        expect(
          circuitGuideQuotaBudget(optimalMoves: 23, level: level),
          circuitGuideQuotaBudget(optimalMoves: 23, level: level),
        );
      }
    });
  });

  group('wildcard — Killer Sudoku mystery clues', () {
    test('the same level hides the same cages every time', () {
      for (var level = 12; level < 60; level += 5) {
        final a = killerSudokuHiddenCages(cageCount: 27, level: level);
        final b = killerSudokuHiddenCages(cageCount: 27, level: level);
        expect(a, b, reason: 'L$level was not reproducible');
      }
    });

    test('different levels hide different cages', () {
      final sets = <String>{
        for (var level = 12; level < 40; level++)
          (killerSudokuHiddenCages(cageCount: 27, level: level).toList()
                ..sort())
              .join(',')
      };
      // Not every level need differ, but they must not all be identical.
      expect(sets.length, greaterThan(10));
    });

    test('the salted seed differs from the board seed at the same level', () {
      // 'killersudoku' already seeds the board itself. Reusing it would tie
      // the hidden clues to the generator's own choices.
      var differed = 0;
      for (var level = 12; level < 60; level++) {
        final salted = RotationEngine.getDeterminism('killersudoku_wild', level);
        final board = RotationEngine.getDeterminism('killersudoku', level);
        if (salted.nextDouble() != board.nextDouble()) differed++;
      }
      expect(differed, 48);
    });

    test('roughly three clues in ten are hidden over many cages', () {
      var hidden = 0, total = 0;
      for (var level = 0; level < 400; level++) {
        hidden += killerSudokuHiddenCages(cageCount: 27, level: level).length;
        total += 27;
      }
      final ratio = hidden / total;
      expect(ratio, greaterThan(0.25));
      expect(ratio, lessThan(0.35));
    });

    test('the spy cage is never hidden', () {
      for (var level = 12; level < 80; level++) {
        for (var spy = 0; spy < 27; spy += 4) {
          expect(
            killerSudokuHiddenCages(
                cageCount: 27, level: level, spyCageId: spy),
            isNot(contains(spy)),
          );
        }
      }
    });

    test('an empty board hides nothing', () {
      expect(killerSudokuHiddenCages(cageCount: 0, level: 20), isEmpty);
    });
  });
}
