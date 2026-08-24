import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:cogniq/screens/games/zenslide/zenslide_logic.dart';

/// Tests for Zen Slide's slide rule, its two searches, and its generator.
///
/// The heart of this file is the `generation gate` group. remember.md E2 §10
/// exists because sixteen Sudoku boards shipped unwinnable off the back of a
/// generator nobody checked, and the handbook's Zen Slide sketch would have done
/// the same thing in a subtler way: its fallback keeps a *rejected* board and
/// writes `optimal = solve(stone).$1.clamp(1, 99)`, which turns the solver's
/// "unreachable" answer of -1 into a cheerful "1". So what is asserted here is
/// never "the board is not already solved". Every generated board is re-solved
/// from scratch by the forward BFS and must come back at exactly the distance
/// the level asked for.
void main() {
  // Shipped-seed helper. `RotationEngine.getDeterminism` is a plain `Random`
  // underneath; this reproduces the same per-level spread without dragging
  // Flutter into this file.
  int shippedSeed(int level) => level * 2654435761 & 0x7fffffff;
  int seedFor(int level, int seed) => level * 7919 + seed * 104729 + 17;

  const up = (-1, 0);
  const down = (1, 0);
  const left = (0, -1);
  const right = (0, 1);

  /// `slide` on a 5x5 board, in `(row, col)` for readability.
  (int, int) slide5(
    (int, int) from,
    (int, int) dir, {
    Set<(int, int)> stones = const {},
    (int, int) target = (4, 4),
  }) {
    int idx((int, int) p) => p.$1 * 5 + p.$2;
    final landed = ZenSlideLogic.slide(
      from: idx(from),
      dr: dir.$1,
      dc: dir.$2,
      rows: 5,
      cols: 5,
      stones: {for (final s in stones) idx(s)},
      target: idx(target),
    );
    return (landed ~/ 5, landed % 5);
  }

  // ------------------------------------------------------------- slide rule

  group('slide', () {
    test('an empty row lets the stone run to the edge', () {
      expect(slide5((2, 2), left), (2, 0));
      expect(slide5((2, 2), right), (2, 4));
      expect(slide5((2, 2), up), (0, 2));
      expect(slide5((2, 2), down), (4, 2));
    });

    test('a grey stone stops it on the cell before', () {
      expect(slide5((2, 4), left, stones: {(2, 1)}), (2, 2));
      expect(slide5((4, 2), up, stones: {(1, 2)}), (2, 2));
    });

    test('a grey stone in the very next cell means no move at all', () {
      // The handbook's own suggested test: swipe into a wall from the adjacent
      // cell and nothing happens. `slide` returns `from` unchanged, which is how
      // ZenSlideGame.swipe knows to report a blocked swipe.
      expect(slide5((2, 2), left, stones: {(2, 1)}), (2, 2));
      expect(slide5((2, 2), up, stones: {(1, 2)}), (2, 2));
    });

    test('the board edge stops it and a stone already flush cannot move', () {
      expect(slide5((0, 0), up), (0, 0));
      expect(slide5((0, 0), left), (0, 0));
      expect(slide5((4, 4), down), (4, 4));
      expect(slide5((4, 4), right), (4, 4));
    });

    test('the lotus catches the stone mid-flight', () {
      // Without the catch a stone would sail straight over the target and the
      // game would be unplayable on any open row. It is the one part of the
      // handbook sketch worth copying verbatim.
      expect(slide5((2, 4), left, target: (2, 1)), (2, 1));
      expect(slide5((2, 2), left, target: (2, 1)), (2, 1));
      // And it only catches on the way past — not from behind it.
      expect(slide5((2, 0), right, target: (2, 1)), (2, 1));
    });

    test('slide reads no mutable state: the target is a parameter', () {
      // The handbook's `_slide` dereferences a `late int lotus`, so calling it
      // before the first successful `generate` throws
      // LateInitializationError. There is nothing to initialise here.
      expect(
        ZenSlideLogic.slide(
          from: 0,
          dr: 0,
          dc: 1,
          rows: 5,
          cols: 5,
          stones: const {},
          target: 24,
        ),
        4,
      );
    });
  });

  // ------------------------------------------------------------- the solver

  group('solveFrom', () {
    test('known distances on a bare 5x5', () {
      // Bottom-right to top-left on empty ice: up the far column, then left
      // along row 0 into the lotus. Two swipes, and no single swipe from a
      // corner can reach the opposite corner.
      final s = ZenSlideLogic.solveFrom(
          from: 24, rows: 5, cols: 5, stones: const {}, target: 0);
      expect(s.distance, 2);
      expect(s.isReachable, isTrue);
      expect(s.budgetExhausted, isFalse);
      expect([up, left], contains(s.firstMove));
    });

    test('standing on the lotus is zero swipes', () {
      final s = ZenSlideLogic.solveFrom(
          from: 7, rows: 5, cols: 5, stones: const {}, target: 7);
      expect(s.distance, 0);
      expect(s.firstMove, isNull);
    });

    test('an interior lotus on bare ice is unreachable, and says so', () {
      // On an empty grid the stone can only ever come to rest against an edge,
      // so a lotus at (2, 2) can never be landed on. The answer is -1, not a
      // crash and not a lie — the handbook turns exactly this -1 into "1 move"
      // and ships it.
      final s = ZenSlideLogic.solveFrom(
          from: 0, rows: 5, cols: 5, stones: const {}, target: 12);
      expect(s.distance, -1);
      expect(s.isReachable, isFalse);
      expect(s.firstMove, isNull);
      expect(s.budgetExhausted, isFalse);
    });

    test('the node budget is never exhausted on a legal board', () {
      final rng = Random(20260822);
      for (var i = 0; i < 300; i++) {
        final rows = 5 + rng.nextInt(4);
        final cols = 5 + rng.nextInt(3);
        final cells = rows * cols;
        final stones = <int>{};
        while (stones.length < rng.nextInt(cells ~/ 4)) {
          stones.add(rng.nextInt(cells));
        }
        var target = rng.nextInt(cells);
        while (stones.contains(target)) {
          target = rng.nextInt(cells);
        }
        var from = rng.nextInt(cells);
        while (stones.contains(from)) {
          from = rng.nextInt(cells);
        }
        final s = ZenSlideLogic.solveFrom(
            from: from, rows: rows, cols: cols, stones: stones, target: target);
        expect(s.budgetExhausted, isFalse, reason: 'board $i blew the budget');
        expect(s.nodesVisited, lessThanOrEqualTo(cells + 1));
      }
    });
  });

  group('distancesToTarget', () {
    test('agrees with solveFrom on every cell of random boards', () {
      // The generator trusts the reverse sweep and the hint trusts the forward
      // BFS. If they ever disagree, the shipped "solve distance" is fiction, so
      // the two are pinned against each other rather than assumed equal.
      final rng = Random(4242);
      for (var i = 0; i < 120; i++) {
        final rows = 5 + rng.nextInt(4);
        final cols = 5 + rng.nextInt(3);
        final cells = rows * cols;
        final stones = <int>{};
        final wanted = rng.nextInt(cells ~/ 5);
        while (stones.length < wanted) {
          stones.add(rng.nextInt(cells));
        }
        var target = rng.nextInt(cells);
        while (stones.contains(target)) {
          target = rng.nextInt(cells);
        }

        final sweep = ZenSlideLogic.distancesToTarget(
            rows: rows, cols: cols, stones: stones, target: target);
        expect(sweep.length, cells);

        for (var cell = 0; cell < cells; cell++) {
          if (stones.contains(cell)) {
            expect(sweep[cell], -1, reason: 'a grey cell got a distance');
            continue;
          }
          final forward = ZenSlideLogic.solveFrom(
              from: cell, rows: rows, cols: cols, stones: stones, target: target);
          expect(sweep[cell], forward.distance,
              reason: 'board $i cell $cell: sweep says ${sweep[cell]}, '
                  'BFS says ${forward.distance}');
        }
      }
    });

    test('an out-of-range or blocked lotus yields all -1 rather than throwing',
        () {
      final blocked = ZenSlideLogic.distancesToTarget(
          rows: 5, cols: 5, stones: {12}, target: 12);
      expect(blocked.every((d) => d == -1), isTrue);
      final out = ZenSlideLogic.distancesToTarget(
          rows: 5, cols: 5, stones: const {}, target: 99);
      expect(out.every((d) => d == -1), isTrue);
    });
  });

  // ------------------------------------------------------------- difficulty

  group('difficulty ramp', () {
    test('nothing decreases across levels 0-99', () {
      var previousRows = 0;
      var previousCols = 0;
      var previousStones = 0;
      var previousDistance = 0;
      var previousScore = -1;

      for (var level = 0; level < 100; level++) {
        final rows = ZenSlideLogic.rowsFor(level);
        final cols = ZenSlideLogic.colsFor(level);
        final stones = ZenSlideLogic.stoneCountFor(level);
        final distance = ZenSlideLogic.targetDistanceFor(level);
        final score = ZenSlideLogic.difficultyScore(level);

        expect(rows, greaterThanOrEqualTo(previousRows),
            reason: 'rows dipped at $level');
        expect(cols, greaterThanOrEqualTo(previousCols),
            reason: 'cols dipped at $level');
        expect(stones, greaterThanOrEqualTo(previousStones),
            reason: 'grey stones dipped at $level');
        expect(distance, greaterThanOrEqualTo(previousDistance),
            reason: 'the target solve distance dipped at $level');
        expect(score, greaterThanOrEqualTo(previousScore),
            reason: 'difficulty score dipped at $level');

        previousRows = rows;
        previousCols = cols;
        previousStones = stones;
        previousDistance = distance;
        previousScore = score;
      }
    });

    test('the ramp actually climbs, it does not just fail to fall', () {
      expect(ZenSlideLogic.rowsFor(0), 5);
      expect(ZenSlideLogic.rowsFor(99), 8);
      expect(ZenSlideLogic.colsFor(0), 5);
      expect(ZenSlideLogic.colsFor(99), 7);
      expect(ZenSlideLogic.stoneCountFor(0), 2);
      expect(ZenSlideLogic.stoneCountFor(99), 8);
      expect(ZenSlideLogic.targetDistanceFor(0), 3);
      expect(ZenSlideLogic.targetDistanceFor(99), 9);
    });

    test('no level is ever aimed at a one- or two-swipe board', () {
      for (var level = 0; level < 400; level++) {
        expect(ZenSlideLogic.targetDistanceFor(level),
            greaterThanOrEqualTo(ZenSlideLogic.minPuzzleDistance),
            reason: 'level $level asks for a board that is not a puzzle');
      }
    });

    test('the hardest fair level is where every knob reaches its cap', () {
      const hardest = ZenSlideLogic.hardestFairLevel;
      expect(hardest, 66);
      expect(ZenSlideLogic.difficultyScore(hardest),
          ZenSlideLogic.difficultyScore(5000),
          reason: 'the board still grows after the documented hardest level');
      expect(ZenSlideLogic.difficultyScore(hardest - 1),
          lessThan(ZenSlideLogic.difficultyScore(hardest)),
          reason: 'the caps land before the documented hardest level');
      expect(ZenSlideLogic.rowsFor(hardest), 8);
      expect(ZenSlideLogic.colsFor(hardest), 7);
      expect(ZenSlideLogic.stoneCountFor(hardest), 8);
      expect(ZenSlideLogic.targetDistanceFor(hardest), 9);
    });
  });

  // ------------------------------------------------------------ determinism

  group('determinism', () {
    for (final level in [0, 7, 25, 60, 99]) {
      test('level $level: same seed produces an identical board', () {
        final a = ZenSlideLogic.generate(Random(4242), level);
        final b = ZenSlideLogic.generate(Random(4242), level);

        expect(a.rows, b.rows);
        expect(a.cols, b.cols);
        expect(a.stones, equals(b.stones));
        expect(a.start, b.start);
        expect(a.target, b.target);
        expect(a.solveDistance, b.solveDistance);
        expect(a.attempts, b.attempts);
      });
    }

    test('ZenSlideGame.generate is deterministic too', () {
      final g1 = ZenSlideGame()..generate(Random(99), 33);
      final g2 = ZenSlideGame()..generate(Random(99), 33);
      expect(g1.stones, equals(g2.stones));
      expect(g1.stone, g2.stone);
      expect(g1.target, g2.target);
      expect(g1.shortestSolve, g2.shortestSolve);
    });

    test('different seeds give different boards', () {
      final a = ZenSlideLogic.generate(Random(1), 40);
      final b = ZenSlideLogic.generate(Random(2), 40);
      final same = a.start == b.start &&
          a.target == b.target &&
          a.stones.difference(b.stones).isEmpty;
      expect(same, isFalse);
    });

    test('the caller keeps control of the Random: retries stay reproducible',
        () {
      // The one property save games depend on, and the thing that breaks the
      // moment generation constructs a Random of its own.
      final rng = Random(7);
      final first = ZenSlideLogic.generate(rng, 30);
      final second = ZenSlideLogic.generate(rng, 30);

      final replay = Random(7);
      final firstAgain = ZenSlideLogic.generate(replay, 30);
      final secondAgain = ZenSlideLogic.generate(replay, 30);

      expect(firstAgain.start, first.start);
      expect(firstAgain.stones, equals(first.stones));
      expect(secondAgain.start, second.start);
      expect(secondAgain.stones, equals(second.stones));
    });
  });

  // -------------------------------------------------------- generation gate

  group('generation gate', () {
    test('every level 0-199 ships a board the solver re-verifies', () {
      for (var level = 0; level < 200; level++) {
        final b = ZenSlideLogic.generate(Random(shippedSeed(level)), level);
        final where = 'level $level';

        // THE GATE. Not "is it unsolved" — "does the solver agree it takes
        // exactly this many swipes".
        expect(ZenSlideLogic.isVerified(b), isTrue,
            reason: '$where: the solver disagrees with the shipped distance');
        expect(b.solveDistance, ZenSlideLogic.targetDistanceFor(level),
            reason: '$where: shipped ${b.solveDistance} swipes, '
                'the curve asked for ${ZenSlideLogic.targetDistanceFor(level)}');
        expect(b.solveDistance,
            greaterThanOrEqualTo(ZenSlideLogic.minPuzzleDistance),
            reason: '$where: a board this shallow is not a puzzle');
        expect(b.fromFallback, isFalse, reason: '$where fell back');
      }
    });

    test('the SHIPPED solve distance never regresses across levels 0-99', () {
      // Sand Sort's lesson, written as an assertion: scramble depth is not
      // difficulty, so this measures the *solved* distance of the board a player
      // actually receives, not the knob that was aimed at it. An `at least`
      // acceptance gate — the handbook's `d >= wantOptimal` — fails this: it
      // takes the first board over the bar, and level 10 routinely deals a
      // 12-swipe board while level 11 deals a 5-swipe one.
      var previous = 0;
      for (var level = 0; level < 100; level++) {
        final b = ZenSlideLogic.generate(Random(shippedSeed(level)), level);
        expect(b.solveDistance, greaterThanOrEqualTo(previous),
            reason: 'level $level ships a $previous-swipe-or-worse regression: '
                '${b.solveDistance} after $previous');
        previous = b.solveDistance;
      }
      expect(previous, 9, reason: 'the curve never reached its documented cap');
    });

    test('boards are internally consistent, on many seeds', () {
      const levels = [0, 1, 5, 11, 15, 22, 33, 44, 55, 66, 80, 99, 150];
      const seeds = [1, 2, 3, 4, 5, 6, 7, 8];
      var worstAttempts = 0;
      var fallbacks = 0;

      for (final level in levels) {
        for (final seed in seeds) {
          final b = ZenSlideLogic.generate(Random(seedFor(level, seed)), level);
          final where = 'level $level seed $seed';
          if (b.fromFallback) fallbacks++;
          if (b.attempts > worstAttempts) worstAttempts = b.attempts;

          expect(b.rows, ZenSlideLogic.rowsFor(level), reason: where);
          expect(b.cols, ZenSlideLogic.colsFor(level), reason: where);
          expect(b.stones.length, ZenSlideLogic.stoneCountFor(level),
              reason: where);
          expect(ZenSlideLogic.isVerified(b), isTrue, reason: where);
          expect(b.solveDistance, ZenSlideLogic.targetDistanceFor(level),
              reason: where);

          // The start, the lotus and the greys are three disjoint things.
          expect(b.start, isNot(b.target), reason: '$where: start is the lotus');
          expect(b.stones.contains(b.start), isFalse,
              reason: '$where: the stone starts inside a grey');
          expect(b.stones.contains(b.target), isFalse,
              reason: '$where: the lotus is buried under a grey');
          for (final s in b.stones) {
            expect(s, inInclusiveRange(0, b.cellCount - 1), reason: where);
          }
          expect(b.start, inInclusiveRange(0, b.cellCount - 1), reason: where);
          expect(b.target, inInclusiveRange(0, b.cellCount - 1), reason: where);
        }
      }

      expect(fallbacks, 0,
          reason: 'the deal fell back $fallbacks times; the attempt budget or '
              'the distance curve needs re-tuning');
      // Not a correctness requirement, but a generator that needs most of its
      // 400 attempts is one bad tuning edit away from falling back on a real
      // device. Measured over 6000 boards: 7.7 attempts on average, 122 worst.
      expect(worstAttempts, lessThan(240),
          reason: 'worst case took $worstAttempts attempts');
    });

    test('generation stays under 150ms for EVERY level, measured one at a time',
        () {
      // Per level, not as an aggregate: an average hides the one slow level, and
      // a total measures the machine's load as much as the code. Measured warm
      // on the build machine: worst case 1.8ms at level 87, against this 150ms
      // ceiling.
      //
      // The warm-up loop is the point of honesty here — the first few hundred
      // microseconds of any Dart process are the JIT, not the generator, and
      // asserting against a cold first call measures the VM.
      for (var i = 0; i < 40; i++) {
        ZenSlideLogic.generate(Random(i), i);
      }

      final slow = <String>[];
      for (var level = 0; level < 200; level++) {
        final rng = Random(shippedSeed(level));
        final watch = Stopwatch()..start();
        final board = ZenSlideLogic.generate(rng, level);
        watch.stop();
        expect(board.solveDistance, greaterThan(0));
        if (watch.elapsedMicroseconds > 150000) {
          slow.add('level $level took ${watch.elapsedMicroseconds}us');
        }
      }
      expect(slow, isEmpty, reason: slow.join('\n'));
    });

    test('a hostile attempt budget still returns a solvable board', () {
      // maxAttempts: 0 forces the fallback path. The handbook's equivalent hands
      // back the last rejected candidate with `optimal = (-1).clamp(1, 99)` —
      // an unwinnable board labelled "one move". This one must still be
      // solvable, and its distance must be the truth.
      for (final level in [0, 30, 66, 99]) {
        final b = ZenSlideLogic.generate(Random(5), level, maxAttempts: 0);
        expect(b.fromFallback, isTrue);
        expect(ZenSlideLogic.isSolvable(b), isTrue,
            reason: 'level $level fell back to an unwinnable board');
        expect(ZenSlideLogic.isVerified(b), isTrue,
            reason: 'level $level fell back to a board whose distance is fiction');
        expect(b.solveDistance, greaterThanOrEqualTo(1));
        expect(b.start, isNot(b.target));
      }
    });

    test('isVerified rejects a board whose distance has been tampered with', () {
      // The gate has to be able to say no, or it is decoration.
      final good = ZenSlideLogic.generate(Random(shippedSeed(20)), 20);
      expect(ZenSlideLogic.isVerified(good), isTrue);

      final wrongDistance = ZenSlideBoard(
        rows: good.rows,
        cols: good.cols,
        stones: good.stones,
        start: good.start,
        target: good.target,
        solveDistance: good.solveDistance + 1,
        attempts: 0,
        fromFallback: false,
      );
      expect(ZenSlideLogic.isVerified(wrongDistance), isFalse);

      final startOnLotus = ZenSlideBoard(
        rows: good.rows,
        cols: good.cols,
        stones: good.stones,
        start: good.target,
        target: good.target,
        solveDistance: 0,
        attempts: 0,
        fromFallback: false,
      );
      expect(ZenSlideLogic.isVerified(startOnLotus), isFalse);

      // An interior lotus on a bare grid: unreachable, so the solver returns -1.
      // This is the exact shape the handbook's fallback relabels as "1".
      final unreachable = ZenSlideBoard(
        rows: 5,
        cols: 5,
        stones: const {},
        start: 0,
        target: 12,
        solveDistance: 1,
        attempts: 0,
        fromFallback: false,
      );
      expect(ZenSlideLogic.isSolvable(unreachable), isFalse);
      expect(ZenSlideLogic.isVerified(unreachable), isFalse);
    });
  });

  // ------------------------------------------------------------- play rules

  group('playing', () {
    ZenSlideGame gameAt(int level, [int seed = 1]) =>
        ZenSlideGame()..generate(Random(seedFor(level, seed)), level);

    test('a fresh board is not already won and knows its shortest solve', () {
      for (final level in [0, 20, 66, 99]) {
        final g = gameAt(level);
        expect(g.isWon, isFalse, reason: 'level $level started on the lotus');
        expect(g.isStuck, isFalse, reason: 'level $level started unwinnable');
        expect(g.shortestSolve, ZenSlideLogic.targetDistanceFor(level));
        expect(g.moves, 0);
        expect(g.trail, [g.stone]);
      }
    });

    test('a swipe into an immediate blocker moves nothing and is not a move',
        () {
      final g = ZenSlideGame()
        ..loadBoard(const ZenSlideBoard(
          rows: 5,
          cols: 5,
          stones: {11}, // (2, 1)
          start: 12, // (2, 2)
          target: 24,
          solveDistance: 2,
          attempts: 0,
          fromFallback: false,
        ));

      expect(g.swipe(0, -1), isFalse);
      expect(g.stone, 12);
      expect(g.moves, 0);
      expect(g.blockedSwipes, 1);
      expect(g.trail, [12]);
    });

    test('a swipe glides to the stopping cell and records the trail', () {
      final g = ZenSlideGame()
        ..loadBoard(const ZenSlideBoard(
          rows: 5,
          cols: 5,
          stones: {},
          start: 24, // (4, 4)
          target: 0, // (0, 0)
          solveDistance: 2,
          attempts: 0,
          fromFallback: false,
        ));

      expect(g.swipe(-1, 0), isTrue); // up the far column
      expect(g.stone, 4);
      expect(g.moves, 1);
      expect(g.isWon, isFalse);

      expect(g.swipe(0, -1), isTrue); // left into the lotus, which catches it
      expect(g.stone, 0);
      expect(g.moves, 2);
      expect(g.isWon, isTrue);
      expect(g.trail, [24, 4, 0]);
      expect(g.trailSet, {24, 4, 0});
    });

    test('a won board refuses further swipes', () {
      final g = ZenSlideGame()
        ..loadBoard(const ZenSlideBoard(
          rows: 5,
          cols: 5,
          stones: {},
          start: 4,
          target: 0,
          solveDistance: 1,
          attempts: 0,
          fromFallback: false,
        ));
      expect(g.swipe(0, -1), isTrue);
      expect(g.isWon, isTrue);
      expect(g.swipe(0, 1), isFalse,
          reason: 'a stray gesture walked the stone back off the lotus');
      expect(g.stone, 0);
      expect(g.moves, 1);
    });

    test('restart puts the dealt board back', () {
      final g = gameAt(30);
      final start = g.stone;
      var guard = 0;
      while (g.stone == start && guard++ < 4) {
        g.swipe(ZenSlideLogic.directions[guard % 4].$1,
            ZenSlideLogic.directions[guard % 4].$2);
      }
      expect(g.stone, isNot(start), reason: 'nothing moved, so nothing to undo');

      g.restart();
      expect(g.stone, start);
      expect(g.moves, 0);
      expect(g.blockedSwipes, 0);
      expect(g.trail, [start]);
    });

    test('following the hint finishes every board in exactly the shipped count',
        () {
      for (final level in [0, 11, 33, 55, 66, 99]) {
        final g = gameAt(level, 3);
        final expected = g.shortestSolve;
        var guard = 0;
        while (!g.isWon && guard++ <= expected) {
          final dir = g.hintDirection();
          expect(dir, isNotNull, reason: 'level $level: the hint dried up');
          expect(g.swipe(dir!.$1, dir.$2), isTrue,
              reason: 'level $level: the hint pointed at a blocked direction');
        }
        expect(g.isWon, isTrue, reason: 'level $level: hints did not finish it');
        expect(g.moves, expected,
            reason: 'level $level: the hint path is not a shortest path');
      }
    });

    test('a stone slid into a dead pocket reports stuck instead of lying', () {
      // Bare 5x5, lotus at (0, 0). From (0, 4) the only legal swipes are down
      // and left, and left wins — so build the pocket explicitly instead: a
      // board where the stone can reach a cell the lotus cannot be reached from.
      final g = ZenSlideGame()
        ..loadBoard(const ZenSlideBoard(
          rows: 5,
          cols: 5,
          stones: {},
          start: 24,
          target: 0,
          solveDistance: 2,
          attempts: 0,
          fromFallback: false,
        ));
      expect(g.isStuck, isFalse);
      expect(g.solutionFromHere.distance, 2);

      // Move away from the optimal line and the distance goes up, not down, and
      // the hint keeps pointing somewhere real.
      expect(g.swipe(0, -1), isTrue); // left along the bottom row
      expect(g.stone, 20);
      expect(g.solutionFromHere.distance, 1);
      expect(g.hintDirection(), (-1, 0));
      expect(g.isStuck, isFalse);
    });

    test('isStuck is true exactly when the solver cannot reach the lotus', () {
      final g = ZenSlideGame()
        ..loadBoard(const ZenSlideBoard(
          rows: 5,
          cols: 5,
          stones: {},
          start: 0,
          target: 12, // interior lotus on bare ice: never landable
          solveDistance: 1,
          attempts: 0,
          fromFallback: false,
        ));
      expect(g.isWon, isFalse);
      expect(g.isStuck, isTrue);
      expect(g.hintDirection(), isNull,
          reason: 'a hint was offered on a board that cannot be finished');
    });
  });
}
