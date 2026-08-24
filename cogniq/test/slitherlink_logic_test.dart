import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:cogniq/screens/games/slitherlink/slitherlink_logic.dart';

/// Regression tests for Slitherlink generation.
///
/// The defect recorded in the release plan — "the stuck-growth fallback
/// force-adds a hole, producing a two-loop board" — was **refuted**: that branch
/// exists but never fired across 9,000 simulated boards.
///
/// The real defect was a **diagonal pinch**: two cells touching only at a corner
/// pass the edge-connectivity check while making the boundary cross itself,
/// giving a degree-4 vertex. The screen's win check rejects any vertex whose
/// degree is not 0 or 2, so those boards stored a solution that failed the game's
/// own validator — measured at 0% (3x3), 0.7% (4x4) and **2.4% (5x5)**.
void main() {
  const levels = [0, 3, 4, 5, 8, 11, 12, 15, 30, 60, 99];

  group('geometry', () {
    test('a diagonal pair is detected as a pinch', () {
      // (0,0) and (1,1) in, (0,1) and (1,0) out — touching only at a corner.
      expect(SlitherlinkLogic.hasDiagonalPinch({0, 4}, 3), isTrue);
    });

    test('an edge-adjacent pair is not a pinch', () {
      expect(SlitherlinkLogic.hasDiagonalPinch({0, 1}, 3), isFalse);
    });

    test('a single cell derives a valid four-edge loop', () {
      for (final size in [3, 4, 5]) {
        final sol = SlitherlinkLogic.deriveEdges({0}, size);
        expect(SlitherlinkLogic.isSingleLoop(sol, size), isTrue);
        expect(sol.where((e) => e).length, 4);
      }
    });

    test('a diagonal pair derives a solution that FAILS the win check', () {
      // This is the bug, reproduced directly: the shape is edge-disconnected
      // here, but even when a larger region merely *contains* such a corner the
      // derived edges give a degree-4 vertex.
      final sol = SlitherlinkLogic.deriveEdges({0, 4}, 3);
      expect(SlitherlinkLogic.isSingleLoop(sol, 3), isFalse,
          reason: 'a corner-touching region is not a simple loop');
    });

    test('an empty edge set is not a loop', () {
      final sol = List<bool>.filled(SlitherlinkBoard.edgeCount(4), false);
      expect(SlitherlinkLogic.isSingleLoop(sol, 4), isFalse);
    });
  });

  group('generation', () {
    for (final level in levels) {
      test('level $level: the stored solution passes the win check', () {
        final b = SlitherlinkLogic.generate(Random(level * 7919 + 3), level);

        expect(b.size, SlitherlinkLogic.sizeFor(level));
        expect(b.solution.length, SlitherlinkBoard.edgeCount(b.size));
        expect(b.clues.length, b.size * b.size);

        // THE assertion. 2.4% of 5x5 boards failed this before.
        expect(
          SlitherlinkLogic.isSingleLoop(b.solution, b.size),
          isTrue,
          reason: 'level $level shipped a solution its own win check rejects',
        );
      });
    }

    test('no board in a wide sweep fails the win check', () {
      var checked = 0;
      for (var level = 0; level < 100; level += 3) {
        for (var seed = 0; seed < 6; seed++) {
          final b = SlitherlinkLogic.generate(Random(level * 31 + seed), level);
          checked++;
          expect(SlitherlinkLogic.isSingleLoop(b.solution, b.size), isTrue,
              reason: 'level $level seed $seed');
        }
      }
      expect(checked, greaterThan(100));
    });

    test('every clue matches the stored solution', () {
      for (final level in levels) {
        final b = SlitherlinkLogic.generate(Random(level + 500), level);
        for (var i = 0; i < b.clues.length; i++) {
          expect(b.clues[i],
              SlitherlinkLogic.edgesAroundCell(b.solution, b.size, i),
              reason: 'level $level cell $i clue disagrees with the solution');
        }
      }
    });

    test('generation is deterministic for a given seed', () {
      for (final level in [0, 8, 20, 60]) {
        final a = SlitherlinkLogic.generate(Random(42), level);
        final b = SlitherlinkLogic.generate(Random(42), level);
        expect(a.solution, b.solution);
        expect(a.clues, b.clues);
      }
    });

    test('grid size climbs and never shrinks', () {
      var previous = 0;
      for (var level = 0; level < 100; level++) {
        final s = SlitherlinkLogic.sizeFor(level);
        expect(s, greaterThanOrEqualTo(previous));
        previous = s;
      }
    });

    test('generation never falls back to the degenerate single-cell board', () {
      for (var level = 0; level < 60; level += 2) {
        final b = SlitherlinkLogic.generate(Random(level * 977), level);
        expect(b.attempts, lessThan(40),
            reason: 'level $level exhausted its attempts');
        expect(b.solution.where((e) => e).length, greaterThan(4),
            reason: 'level $level produced a one-cell loop');
      }
    });
  });

  group('performance', () {
    test('generation stays fast enough for the UI isolate', () {
      var slowest = 0;
      for (var level = 0; level < 100; level++) {
        final lap = Stopwatch()..start();
        SlitherlinkLogic.generate(Random(level), level);
        lap.stop();
        if (lap.elapsedMilliseconds > slowest) slowest = lap.elapsedMilliseconds;
      }
      // Per level, not aggregate: a player generates one board at a time, and an
      // aggregate measures machine contention as much as this code.
      expect(slowest, lessThan(300),
          reason: 'slowest level took ${slowest}ms');
    });
  });
}
