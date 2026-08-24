import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:cogniq/screens/games/hitori/hitori_logic.dart';

/// Regression tests for the three defects that made Hitori unplayable.
///
/// 1. The generator dealt a shuffled permutation **per row** and never
///    constrained columns, so the mask it stored as `_solution` was illegal on
///    ~96% of shipped boards. The win check is rule-based so the player could
///    still win — but the hint button is exact-match against that stored
///    solution, so one hint tap destroyed a winning board, charged a hint, and
///    then claimed success while the Check button disagreed.
/// 2. The solution enumerator branched on every cell and only checked the
///    duplicate rule at the leaf: 5.7M nodes at 6x6, ~31s per call, up to 100
///    calls per level load. Opening Level 6 froze the UI for 22 minutes.
/// 3. The hardcoded fallback board had **zero** valid solutions and was reached
///    ~3% of the time at 4x4 and always at 6x6+.
void main() {
  const levels = [0, 3, 4, 5, 8, 11, 12, 15, 30, 60, 99];

  group('rules', () {
    test('a Latin square with nothing shaded satisfies every rule', () {
      for (final size in [4, 6, 8]) {
        final latin = HitoriLogic.latinSquare(size, Random(size));
        final none = List<bool>.filled(size * size, false);
        expect(HitoriLogic.satisfiesRules(latin, none, size), isTrue);
      }
    });

    test('latinSquare has no repeat in any row or column', () {
      for (final size in [4, 6, 8]) {
        final sq = HitoriLogic.latinSquare(size, Random(size * 7));
        for (var r = 0; r < size; r++) {
          final row = {for (var c = 0; c < size; c++) sq[r * size + c]};
          expect(row.length, size, reason: 'row $r of ${size}x$size repeats');
        }
        for (var c = 0; c < size; c++) {
          final col = {for (var r = 0; r < size; r++) sq[r * size + c]};
          expect(col.length, size, reason: 'column $c of ${size}x$size repeats');
        }
      }
    });

    test('adjacent shaded cells are rejected', () {
      final values = HitoriLogic.latinSquare(4, Random(1));
      final mask = List<bool>.filled(16, false);
      mask[0] = true;
      mask[1] = true; // orthogonally adjacent
      expect(HitoriLogic.satisfiesRules(values, mask, 4), isFalse);
    });

    test('a disconnected white group is rejected', () {
      // Shading the two cells around a corner islands cell 0.
      final values = HitoriLogic.latinSquare(4, Random(2));
      final mask = List<bool>.filled(16, false);
      mask[1] = true;
      mask[4] = true;
      expect(HitoriLogic.isConnected(mask, 4), isFalse);
      expect(HitoriLogic.satisfiesRules(values, mask, 4), isFalse);
    });
  });

  group('generation', () {
    for (final level in levels) {
      test('level $level: the stored solution is actually legal', () {
        final b = HitoriLogic.generate(Random(level * 7919 + 11), level);

        expect(b.size, HitoriLogic.sizeFor(level));
        expect(b.values.length, b.size * b.size);
        expect(b.solution.length, b.size * b.size);

        // THE assertion. This is what was false on ~96% of boards before, and
        // it is mandatory because the hint path matches against it exactly.
        expect(
          HitoriLogic.satisfiesRules(b.values, b.solution, b.size),
          isTrue,
          reason: 'level $level stored an ILLEGAL solution — a hint would '
              'destroy a winning board. values=${b.values} mask=${b.solution}',
        );
      });
    }

    test('every board has at least one legal shading', () {
      // Independent of the stored solution: prove the puzzle is winnable at all.
      for (final level in levels) {
        for (var seed = 0; seed < 3; seed++) {
          final b = HitoriLogic.generate(Random(level * 31 + seed), level);
          final count = HitoriLogic.countSolutions(b.values, b.size);
          expect(count, isNot(0),
              reason: 'UNWINNABLE board at level $level seed $seed');
        }
      }
    });

    test('generation is deterministic for a given seed', () {
      for (final level in [0, 8, 20, 60]) {
        final a = HitoriLogic.generate(Random(42), level);
        final b = HitoriLogic.generate(Random(42), level);
        expect(a.values, b.values);
        expect(a.solution, b.solution);
      }
    });

    test('board size climbs and never shrinks', () {
      var previous = 0;
      for (var level = 0; level < 100; level++) {
        final s = HitoriLogic.sizeFor(level);
        expect(s, greaterThanOrEqualTo(previous));
        previous = s;
      }
    });
  });

  group('performance', () {
    test('6x6 generation does not freeze — it used to take 22 minutes', () {
      // Level 6 is the first 6x6. The old enumerator needed ~31s for a single
      // uniqueness call and ran up to 100 of them, all on the UI isolate.
      final sw = Stopwatch()..start();
      for (var level = 5; level < 12; level++) {
        HitoriLogic.generate(Random(level), level);
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(3000),
          reason: 'seven 6x6 boards took ${sw.elapsedMilliseconds}ms — the '
              'candidate pruning has regressed');
    });

    test('8x8 generation does not freeze — it used to be months', () {
      final sw = Stopwatch()..start();
      for (var level = 12; level < 20; level++) {
        HitoriLogic.generate(Random(level), level);
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(4000),
          reason: 'eight 8x8 boards took ${sw.elapsedMilliseconds}ms');
    });

    test('the solver is bounded on a hostile board', () {
      // An all-same-value grid makes every cell a shade candidate.
      const size = 8;
      final values = List<int>.filled(size * size, 1);
      final n = HitoriLogic.countSolutions(values, size, budget: 500);
      expect(n, -1, reason: 'a starved budget must report -1, not a false 0');
    });
  });
}
