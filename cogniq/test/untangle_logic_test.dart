import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:cogniq/screens/games/untangle/untangle_logic.dart';

/// Regression tests for Untangle generation.
///
/// Each group below corresponds to a defect **measured** in the handbook §B1
/// generator over 4,000 boards, before any of this was written:
///
///  * 54% of level-1 boards were already untangled when dealt;
///  * two nodes overlapped on the scramble circle on 99% of boards at level 24+;
///  * 6–10% of boards contained a node with no edges at all;
///  * board size, and therefore difficulty, went flat from level 24.
///
/// The one claim that held — the solved layout is always crossing-free — is
/// asserted here too, because it is the property that makes every board
/// winnable and it must never silently regress.
void main() {
  const levels = [0, 2, 5, 6, 9, 13, 14, 20, 40, 75, 120];

  group('geometry', () {
    test('a proper X is a crossing', () {
      expect(
        UntangleLogic.segmentsCross(const Point(0, 0), const Point(1, 1),
            const Point(0, 1), const Point(1, 0)),
        isTrue,
      );
    });

    test('parallel segments do not cross', () {
      expect(
        UntangleLogic.segmentsCross(const Point(0, 0), const Point(1, 0),
            const Point(0, 1), const Point(1, 1)),
        isFalse,
      );
    });

    test('segments meeting at a shared endpoint do not cross', () {
      // Two edges of a triangle. Visually they meet; they must not be a crossing
      // or every board would be permanently unwinnable.
      expect(
        UntangleLogic.segmentsCross(const Point(0, 0), const Point(1, 1),
            const Point(1, 1), const Point(2, 0)),
        isFalse,
      );
    });

    test('edges sharing a node are excluded from the crossing scan', () {
      const edges = [Edge(0, 1), Edge(1, 2)];
      final pts = [
        const Point<double>(0, 0),
        const Point<double>(1, 1),
        const Point<double>(2, 0),
      ];
      expect(UntangleLogic.crossingEdges(edges, pts), isEmpty);
      expect(UntangleLogic.isSolved(edges, pts), isTrue);
    });

    test('a crossing pair is reported as two bad edges and one crossing', () {
      const edges = [Edge(0, 1), Edge(2, 3)];
      final pts = [
        const Point<double>(0, 0),
        const Point<double>(1, 1),
        const Point<double>(0, 1),
        const Point<double>(1, 0),
      ];
      expect(UntangleLogic.crossingEdges(edges, pts), {0, 1});
      expect(UntangleLogic.crossingCount(edges, pts), 1);
      expect(UntangleLogic.isSolved(edges, pts), isFalse);
    });
  });

  group('every board is winnable', () {
    test('the solved layout has zero crossings, at every level', () {
      for (final level in levels) {
        for (var seed = 0; seed < 12; seed++) {
          final b = UntangleLogic.generate(Random(level * 31 + seed), level);
          expect(
            UntangleLogic.isSolved(b.edges, b.solved),
            isTrue,
            reason: 'level $level seed $seed ships a board that cannot be won',
          );
        }
      }
    });

    test('dragging every node onto the solved layout wins the board', () {
      // The hint promises this. If it were not true the hint would be a lie.
      for (final level in levels) {
        final b = UntangleLogic.generate(Random(level + 909), level);
        expect(UntangleLogic.isSolved(b.edges, b.nodes), isFalse);
        expect(UntangleLogic.isSolved(b.edges, b.solved), isTrue,
            reason: 'level $level');
      }
    });
  });

  group('no board is dealt already finished', () {
    // The headline defect: 54% of the handbook's level-1 boards were solved on
    // arrival, and 48% at level 5.
    for (final level in levels) {
      test('level $level is dealt tangled', () {
        for (var seed = 0; seed < 15; seed++) {
          final b = UntangleLogic.generate(Random(level * 7919 + seed), level);
          expect(b.dealtCrossings, greaterThan(0),
              reason: 'level $level seed $seed was already solved when dealt');
          expect(UntangleLogic.isSolved(b.edges, b.nodes), isFalse);
        }
      });
    }

    test('the dealt tangle meets the level target', () {
      for (final level in levels) {
        final b = UntangleLogic.generate(Random(level * 13 + 5), level);
        expect(b.dealtCrossings,
            greaterThanOrEqualTo(UntangleLogic.minCrossingsFor(level)),
            reason: 'level $level fell back to a weaker board than intended');
      }
    });

    test('the reported crossing count agrees with the crossing scan', () {
      for (final level in levels) {
        final b = UntangleLogic.generate(Random(level + 41), level);
        expect(b.dealtCrossings,
            UntangleLogic.crossingCount(b.edges, b.nodes),
            reason: 'level $level advertises a count it did not measure');
      }
    });
  });

  group('every node is draggable and meaningful', () {
    test('no two nodes overlap on the scramble circle', () {
      // 99% of the handbook's boards at level 24+ failed this. Two nodes drawn
      // on top of each other cannot be told apart or dragged independently.
      const minSeparation = 0.04;
      for (final level in levels) {
        for (var seed = 0; seed < 8; seed++) {
          final b = UntangleLogic.generate(Random(level * 17 + seed), level);
          for (var i = 0; i < b.nodes.length; i++) {
            for (var j = i + 1; j < b.nodes.length; j++) {
              final dx = b.nodes[i].x - b.nodes[j].x;
              final dy = b.nodes[i].y - b.nodes[j].y;
              expect(sqrt(dx * dx + dy * dy), greaterThan(minSeparation),
                  reason: 'level $level seed $seed: nodes $i and $j overlap');
            }
          }
        }
      }
    });

    test('no node is left without an edge', () {
      // A node with no edges can never be part of a crossing, so nothing the
      // player does with it can matter. 6-10% of handbook boards had one.
      for (final level in levels) {
        for (var seed = 0; seed < 10; seed++) {
          final b = UntangleLogic.generate(Random(level * 53 + seed), level);
          final degree = List<int>.filled(b.nodeCount, 0);
          for (final e in b.edges) {
            degree[e.a]++;
            degree[e.b]++;
          }
          expect(degree.every((d) => d > 0), isTrue,
              reason: 'level $level seed $seed has an isolated node');
        }
      }
    });

    test('every node stays inside the unit board', () {
      for (final level in levels) {
        final b = UntangleLogic.generate(Random(level * 5 + 2), level);
        for (final p in [...b.nodes, ...b.solved]) {
          expect(p.x, inInclusiveRange(0.0, 1.0));
          expect(p.y, inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('no edge joins a node to itself', () {
      for (final level in levels) {
        final b = UntangleLogic.generate(Random(level + 77), level);
        for (final e in b.edges) {
          expect(e.a, isNot(e.b), reason: 'level $level has a self-loop');
        }
      }
    });

    test('no edge is duplicated', () {
      for (final level in levels) {
        final b = UntangleLogic.generate(Random(level + 78), level);
        expect(b.edges.toSet().length, b.edges.length,
            reason: 'level $level draws the same line twice');
      }
    });
  });

  group('difficulty climbs and never regresses', () {
    test('grid side never shrinks', () {
      var previous = 0;
      for (var level = 0; level < 150; level++) {
        final s = UntangleLogic.sideFor(level);
        expect(s, greaterThanOrEqualTo(previous));
        previous = s;
      }
    });

    test('edge density keeps climbing after board size plateaus', () {
      // sideFor caps at 5 from level 14, so without another lever difficulty
      // would be flat for every level after that -- which is what the handbook
      // shipped. The tangle *floor* is not that lever: measured, it almost never
      // binds. Edge density is.
      expect(UntangleLogic.sideFor(14), UntangleLogic.sideFor(140));
      expect(UntangleLogic.diagonalChanceFor(140),
          greaterThan(UntangleLogic.diagonalChanceFor(14)),
          reason: 'board size plateaus, so graph density must not');
    });

    test('edge density never decreases and stays bounded', () {
      var previous = 0.0;
      for (var level = 0; level < 200; level++) {
        final d = UntangleLogic.diagonalChanceFor(level);
        expect(d, greaterThanOrEqualTo(previous), reason: 'at level $level');
        expect(d, lessThanOrEqualTo(0.70));
        previous = d;
      }
    });

    test('the SHIPPED edge count climbs past the size plateau', () {
      int avgEdges(int level) {
        var total = 0;
        for (var seed = 0; seed < 12; seed++) {
          total += UntangleLogic.generate(Random(level * 61 + seed), level)
              .edges.length;
        }
        return total ~/ 12;
      }

      // Both are side 5 / 25 nodes, so any difference is density alone.
      expect(avgEdges(120), greaterThan(avgEdges(14)),
          reason: 'measured density, not just the knob, must climb');
    });

    test('the required tangle never decreases', () {
      var previous = 0;
      for (var level = 0; level < 150; level++) {
        final m = UntangleLogic.minCrossingsFor(level);
        expect(m, greaterThanOrEqualTo(previous), reason: 'at level $level');
        previous = m;
      }
    });

    test('the SHIPPED tangle trends upward across the curve', () {
      int avgAt(int level) {
        var total = 0;
        for (var seed = 0; seed < 10; seed++) {
          total += UntangleLogic.generate(Random(level * 97 + seed), level)
              .dealtCrossings;
        }
        return total ~/ 10;
      }

      expect(avgAt(60), greaterThan(avgAt(0)),
          reason: 'measured difficulty, not just the knob, must climb');
    });
  });

  group('determinism', () {
    test('the same seed produces an identical board', () {
      for (final level in [0, 7, 20, 60, 120]) {
        final a = UntangleLogic.generate(Random(42), level);
        final b = UntangleLogic.generate(Random(42), level);
        expect(a.nodes, b.nodes, reason: 'level $level');
        expect(a.solved, b.solved);
        expect(a.edges, b.edges);
        expect(a.dealtCrossings, b.dealtCrossings);
      }
    });

    test('different seeds produce different boards', () {
      final a = UntangleLogic.generate(Random(1), 20);
      final b = UntangleLogic.generate(Random(2), 20);
      expect(a.nodes, isNot(b.nodes));
    });
  });

  group('performance', () {
    test('generation stays fast enough for the UI isolate', () {
      // Warm up so the first-call JIT cost is not attributed to a level.
      for (var i = 0; i < 5; i++) {
        UntangleLogic.generate(Random(i), 20);
      }
      var slowest = 0;
      var slowestLevel = -1;
      for (var level = 0; level < 150; level++) {
        final lap = Stopwatch()..start();
        UntangleLogic.generate(Random(level), level);
        lap.stop();
        if (lap.elapsedMilliseconds > slowest) {
          slowest = lap.elapsedMilliseconds;
          slowestLevel = level;
        }
      }
      // Per level, one at a time. An aggregate would measure machine contention
      // as much as this code.
      expect(slowest, lessThan(150),
          reason: 'level $slowestLevel took ${slowest}ms');
    });

    test('boards rarely exhaust their attempt budget', () {
      var exhausted = 0;
      for (var level = 0; level < 150; level += 3) {
        final b = UntangleLogic.generate(Random(level * 3 + 1), level);
        if (b.attempts >= 59) exhausted++;
      }
      expect(exhausted, 0,
          reason: '$exhausted levels fell back to a near-miss board');
    });
  });
}
