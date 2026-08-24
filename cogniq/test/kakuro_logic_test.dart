import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:cogniq/screens/games/kakuro/kakuro_logic.dart';

/// Regression tests for the bug that made Kakuro levels 5+ impossible to generate.
///
/// The cause: several runs in the 6x6 and 8x8 layouts began after a plain wall, so
/// they never received a clue. The sum check then compared against clue 0 with
/// `sum >= clue`, which is true for every digit, so the solver rejected the first
/// digit it placed, found zero solutions, exhausted its retries and fell back to a
/// hardcoded 4x4 — while also resetting the player's saved level to 0.
void main() {
  group('layout integrity', () {
    final layouts = {
      '4x4': (KakuroLogic.layout4x4, 4),
      '6x6': (KakuroLogic.layout6x6, 6),
      '8x8': (KakuroLogic.layout8x8, 8),
      '8x8b': (KakuroLogic.layout8x8b, 8),
    };

    layouts.forEach((name, spec) {
      final (raw, size) = spec;

      test('$name: every run is headed by a clue cell after normalization', () {
        final types = KakuroLogic.normalizeLayout(raw, size);
        expect(
          KakuroLogic.unheadedRuns(types, size),
          isEmpty,
          reason: '$name has runs with no clue cell. Those runs get clue 0, which '
              'the sum check rejects for every digit, so no board can generate.',
        );
      });

      test('$name: no run is longer than 9 cells', () {
        final types = KakuroLogic.normalizeLayout(raw, size);
        expect(KakuroLogic.longestRun(types, size), lessThanOrEqualTo(9),
            reason: 'a run longer than 9 cannot hold distinct digits 1-9');
      });
    });

    test('the raw 6x6 and 8x8 layouts really did have unheaded runs', () {
      // Guards the fix itself: if someone "tidies" normalizeLayout away, this fails.
      expect(KakuroLogic.unheadedRuns(KakuroLogic.layout6x6, 6), isNotEmpty);
      expect(KakuroLogic.unheadedRuns(KakuroLogic.layout8x8, 8), isNotEmpty);
    });
  });

  group('generation', () {
    // One level from each size band, plus the boundaries where the band changes.
    const levels = [0, 3, 4, 5, 8, 11, 12, 14, 25, 40, 70];

    for (final level in levels) {
      test('level $level generates a solvable board of the right size', () {
        final board = KakuroLogic.generate(level, Random(level * 7919 + 13));

        expect(board.size, KakuroLogic.sizeFor(level),
            reason: 'generation fell back to a smaller board');

        // Every white cell is filled...
        for (int i = 0; i < board.types.length; i++) {
          if (board.types[i] == 1) {
            expect(board.solution[i], inInclusiveRange(1, 9));
          }
        }

        // ...and the stored solution actually satisfies every clue, which is what
        // the game's win check tests. This is the real "is it winnable" assertion.
        _expectSolutionSatisfiesClues(board);
      });
    }

    test('generation is deterministic for a given seed', () {
      final a = KakuroLogic.generate(14, Random(42));
      final b = KakuroLogic.generate(14, Random(42));
      expect(a.solution, b.solution);
      expect(a.hClues, b.hClues);
      expect(a.types, b.types);
    });

    test('levels 5-11 produce a real 6x6, not the old 4x4 fallback', () {
      for (int level = 5; level < 12; level++) {
        final board = KakuroLogic.generate(level, Random(level));
        expect(board.size, 6, reason: 'level $level regressed to the fallback');
      }
    });

    test('8x8 generation stays bounded — no UI-freezing search', () {
      // The clue fix exposed a real search space on 8x8. Without a node budget a
      // single level took over a minute and blocked the main thread. Each call must
      // stay well under a second so it can run inline without freezing the screen.
      final sw = Stopwatch()..start();
      for (int level = 12; level <= 20; level += 2) {
        KakuroLogic.generate(level, Random(level));
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(4000),
          reason: 'five 8x8 boards took ${sw.elapsedMilliseconds}ms — the solver '
              'budget or the layout conditioning has regressed');
    });

    test('most boards have a unique solution', () {
      // Uniqueness is a quality goal, not a correctness one: Kakuro's win check
      // validates sums rather than matching a stored answer, so a board with two
      // valid solutions is still winnable. Track it so quality cannot quietly rot.
      var unique = 0;
      const sample = 30;
      for (int i = 0; i < sample; i++) {
        final level = i % 12; // 4x4 and 6x6 bands, where uniqueness is cheap
        if (KakuroLogic.generate(level, Random(i * 31 + 5)).isUnique) unique++;
      }
      expect(unique, greaterThan(sample ~/ 2),
          reason: 'only $unique/$sample boards were unique');
    });
  });
}

void _expectSolutionSatisfiesClues(KakuroBoard b) {
  for (int i = 0; i < b.types.length; i++) {
    if (b.types[i] != 2) continue;

    if (b.hClues[i] > 0) {
      final run = KakuroLogic.rowRun(b.types, b.size, i + 1);
      final vals = run.map((x) => b.solution[x]).toList();
      expect(vals.fold<int>(0, (a, x) => a + x), b.hClues[i],
          reason: 'horizontal clue at $i does not match its run');
      expect(vals.toSet().length, vals.length,
          reason: 'horizontal run at $i repeats a digit');
    }

    if (b.vClues[i] > 0) {
      final run = KakuroLogic.colRun(b.types, b.size, i + b.size);
      final vals = run.map((x) => b.solution[x]).toList();
      expect(vals.fold<int>(0, (a, x) => a + x), b.vClues[i],
          reason: 'vertical clue at $i does not match its run');
      expect(vals.toSet().length, vals.length,
          reason: 'vertical run at $i repeats a digit');
    }
  }
}
