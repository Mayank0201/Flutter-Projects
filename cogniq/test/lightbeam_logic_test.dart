import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:cogniq/screens/games/lightbeam/lightbeam_logic.dart';

/// Tests for Light Beam's reflection table, generator and rules.
///
/// The heart of this file is the `generation gate` group. remember.md E2 §10
/// exists because sixteen Sudoku boards shipped unwinnable off the back of a
/// generator nobody checked, so "the board is not already solved" is explicitly
/// *not* what is asserted here. Every generated board has its `solutionMirrors`
/// replayed onto the dealt grid and the beam re-marched, and the test fails
/// unless every crystal lights.
void main() {
  const slash = LightBeamCell.slash;
  const backslash = LightBeamCell.backslash;
  const empty = LightBeamCell.empty;
  const block = LightBeamCell.block;

  const right = (0, 1);
  const left = (0, -1);
  const up = (-1, 0);
  const down = (1, 0);

  int seedFor(int level, int seed) => level * 7919 + seed * 104729 + 17;

  // -------------------------------------------------------------- reflection

  group('reflection table', () {
    // Derived in the file header: '/' is the line r + c = k, '\' is r - c = k.
    // All eight direction/mirror pairs are pinned, because a single sign slip
    // here silently turns every generated board into a different puzzle.
    test("'/' sends a beam to (-dc, -dr)", () {
      expect(LightBeamLogic.reflect(right, slash), up);
      expect(LightBeamLogic.reflect(left, slash), down);
      expect(LightBeamLogic.reflect(up, slash), right);
      expect(LightBeamLogic.reflect(down, slash), left);
    });

    test(r"'\' sends a beam to (dc, dr)", () {
      expect(LightBeamLogic.reflect(right, backslash), down);
      expect(LightBeamLogic.reflect(left, backslash), up);
      expect(LightBeamLogic.reflect(up, backslash), left);
      expect(LightBeamLogic.reflect(down, backslash), right);
    });

    test('empty cells and walls never bend the beam', () {
      for (final dir in [right, left, up, down]) {
        expect(LightBeamLogic.reflect(dir, empty), dir);
        expect(LightBeamLogic.reflect(dir, block), dir);
      }
    });

    test('both mirrors are involutions', () {
      // This is the property the no-loops argument in LightBeamTrace.looped
      // rests on, so it is asserted rather than assumed.
      for (final dir in [right, left, up, down]) {
        for (final m in [slash, backslash]) {
          expect(LightBeamLogic.reflect(LightBeamLogic.reflect(dir, m), m), dir,
              reason: 'reflecting $dir twice in $m did not return it');
        }
      }
    });
  });

  // ------------------------------------------------------------------ trace

  group('trace', () {
    /// A 5x5 grid with the given mirrors/walls placed.
    List<List<LightBeamCell>> grid5(Map<(int, int), LightBeamCell> cells) {
      final g = LightBeamLogic.emptyGrid(5);
      cells.forEach((pos, cell) => g[pos.$1][pos.$2] = cell);
      return g;
    }

    test('an empty board lets the beam straight through', () {
      final t = LightBeamLogic.trace(
          grid: grid5({}), source: (2, -1), sourceDir: right);
      expect(t.path, [(2, 0), (2, 1), (2, 2), (2, 3), (2, 4)]);
      expect(t.looped, isFalse);
      expect(t.blocked, isFalse);
      // Source, then the exit cell one step outside the board.
      expect(t.corners, [(2, -1), (2, 5)]);
      expect(t.firstBounce, -1);
    });

    test("a beam going right off a '/' turns up", () {
      final t = LightBeamLogic.trace(
          grid: grid5({(2, 2): slash}), source: (2, -1), sourceDir: right);
      expect(t.path, [(2, 0), (2, 1), (2, 2), (1, 2), (0, 2)]);
      expect(t.corners, [(2, -1), (2, 2), (-1, 2)]);
      expect(t.firstBounce, 1);
    });

    test(r"a beam going right off a '\' turns down", () {
      final t = LightBeamLogic.trace(
          grid: grid5({(2, 2): backslash}), source: (2, -1), sourceDir: right);
      expect(t.path, [(2, 0), (2, 1), (2, 2), (3, 2), (4, 2)]);
      expect(t.corners, [(2, -1), (2, 2), (5, 2)]);
    });

    test('a wall swallows the beam', () {
      final t = LightBeamLogic.trace(
          grid: grid5({(2, 3): block}), source: (2, -1), sourceDir: right);
      expect(t.blocked, isTrue);
      expect(t.path, [(2, 0), (2, 1), (2, 2), (2, 3)]);
      expect(t.corners.last, (2, 3));
    });

    test('the beam passes through crystals and lights them', () {
      final t = LightBeamLogic.trace(
        grid: grid5({(0, 2): backslash}),
        source: (0, -1),
        sourceDir: right,
        crystals: {(0, 1), (3, 2)},
      );
      expect(t.lit, {(0, 1), (3, 2)});
      // (0,1) did not stop or bend it: it carried on to the mirror and turned.
      expect(t.path.contains((4, 2)), isTrue);
    });

    test('a hall of mirrors still terminates, and does not report a loop', () {
      // Four mirrors arranged as a would-be square. The beam spirals through
      // them and leaves, because reflection is invertible and the entry state
      // has no predecessor inside the grid (see LightBeamTrace.looped).
      final t = LightBeamLogic.trace(
        grid: grid5({
          (1, 1): backslash,
          (3, 1): slash,
          (1, 3): slash,
          (3, 3): backslash,
        }),
        source: (1, -1),
        sourceDir: right,
      );
      expect(t.looped, isFalse);
      expect(t.steps, lessThanOrEqualTo(4 * 5 * 5 + 4));
    });

    test('a beam reflected back into itself leaves through the source', () {
      // '/' at (2,2) sends a rightward beam up; '\' at (0,2) sends it left; it
      // exits the left edge. Nothing repeats a state.
      final t = LightBeamLogic.trace(
        grid: grid5({(2, 2): slash, (0, 2): backslash}),
        source: (2, -1),
        sourceDir: right,
      );
      expect(t.looped, isFalse);
      expect(t.corners.last, (0, -1));
    });

    test('every trace terminates inside its step bound, on random boards', () {
      // A fuzz sweep over dense random mirror fields — the states a player can
      // reach by mashing taps. Nothing may loop and nothing may run away.
      final rng = Random(20260822);
      for (var i = 0; i < 400; i++) {
        final n = 5 + rng.nextInt(4);
        final g = LightBeamLogic.emptyGrid(n);
        for (var r = 0; r < n; r++) {
          for (var c = 0; c < n; c++) {
            final roll = rng.nextInt(10);
            if (roll < 4) {
              g[r][c] = rng.nextBool() ? slash : backslash;
            } else if (roll == 4) {
              g[r][c] = block;
            }
          }
        }
        final t = LightBeamLogic.trace(
            grid: g, source: (-1, rng.nextInt(n)), sourceDir: down);
        expect(t.looped, isFalse, reason: 'board $i reported a loop');
        expect(t.steps, lessThanOrEqualTo(4 * n * n + 4));
      }
    });
  });

  // ------------------------------------------------------------ difficulty

  group('difficulty ramp', () {
    test('nothing decreases across levels 0-99', () {
      var previousScore = -1;
      var previousN = 0;
      var previousMirrors = 0;
      var previousCrystals = 0;
      var previousWalls = 0;

      for (var level = 0; level < 100; level++) {
        final n = LightBeamLogic.gridSizeFor(level);
        final m = LightBeamLogic.mirrorCountFor(level);
        final c = LightBeamLogic.crystalCountFor(level);
        final w = LightBeamLogic.wallCountFor(level);
        final s = LightBeamLogic.difficultyScore(level);

        expect(n, greaterThanOrEqualTo(previousN), reason: 'grid dipped at $level');
        expect(m, greaterThanOrEqualTo(previousMirrors),
            reason: 'mirror count dipped at $level');
        expect(c, greaterThanOrEqualTo(previousCrystals),
            reason: 'crystal count dipped at $level');
        expect(w, greaterThanOrEqualTo(previousWalls),
            reason: 'wall count dipped at $level');
        expect(s, greaterThanOrEqualTo(previousScore),
            reason: 'difficulty score dipped at $level');

        previousN = n;
        previousMirrors = m;
        previousCrystals = c;
        previousWalls = w;
        previousScore = s;
      }
    });

    test('the ramp actually climbs, it does not just fail to fall', () {
      expect(LightBeamLogic.gridSizeFor(0), 5);
      expect(LightBeamLogic.gridSizeFor(99), 8);
      expect(LightBeamLogic.mirrorCountFor(0), 2);
      expect(LightBeamLogic.mirrorCountFor(99), 7);
      expect(LightBeamLogic.crystalCountFor(0), 1);
      expect(LightBeamLogic.crystalCountFor(99), 5);
    });

    test('the hardest fair level is where every component reaches its cap', () {
      // The documented decision (remember.md §D2 as amended: decide the hardest
      // fair level rather than scaling forever). If a tuning edit moves a cap,
      // this fails until hardestFairLevel is moved with it.
      const hardest = LightBeamLogic.hardestFairLevel;
      expect(hardest, 66);
      expect(LightBeamLogic.difficultyScore(hardest),
          LightBeamLogic.difficultyScore(500),
          reason: 'the board still grows after the documented hardest level');
      expect(LightBeamLogic.difficultyScore(hardest - 1),
          lessThan(LightBeamLogic.difficultyScore(hardest)),
          reason: 'the caps land before the documented hardest level');
      expect(LightBeamLogic.gridSizeFor(hardest), 8);
      expect(LightBeamLogic.mirrorCountFor(hardest), 7);
      expect(LightBeamLogic.crystalCountFor(hardest), 5);
      expect(LightBeamLogic.wallCountFor(hardest), 3);
    });

    test('the mirror budget is never below what the solution needs', () {
      for (var level = 0; level < 120; level++) {
        final needed = LightBeamLogic.mirrorCountFor(level);
        expect(LightBeamLogic.mirrorBudgetFor(level, needed),
            greaterThanOrEqualTo(needed),
            reason: 'level $level cannot be finished within its own budget');
      }
      expect(LightBeamLogic.mirrorBudgetFor(0, 2), 3, reason: 'a spare early on');
      expect(LightBeamLogic.mirrorBudgetFor(40, 6), 6, reason: 'exact later on');
    });
  });

  // ---------------------------------------------------------- determinism

  group('determinism', () {
    for (final level in [0, 7, 25, 60, 99]) {
      test('level $level: same seed produces an identical board', () {
        final a = LightBeamLogic.generate(Random(4242), level);
        final b = LightBeamLogic.generate(Random(4242), level);

        expect(a.n, b.n);
        expect(a.grid, equals(b.grid));
        expect(a.source, b.source);
        expect(a.sourceDir, b.sourceDir);
        expect(a.crystals, equals(b.crystals));
        expect(a.solutionMirrors, equals(b.solutionMirrors));
        expect(a.mirrorBudget, b.mirrorBudget);
      });
    }

    test('LightBeamGame.generate is deterministic too', () {
      final g1 = LightBeamGame()..generate(Random(99), 33);
      final g2 = LightBeamGame()..generate(Random(99), 33);
      expect(g1.grid, equals(g2.grid));
      expect(g1.crystals, equals(g2.crystals));
      expect(g1.mirrorBudget, g2.mirrorBudget);
    });

    test('different seeds give different boards', () {
      final a = LightBeamLogic.generate(Random(1), 40);
      final b = LightBeamLogic.generate(Random(2), 40);
      final same = a.source == b.source &&
          a.crystals.difference(b.crystals).isEmpty &&
          a.solutionMirrors.toString() == b.solutionMirrors.toString();
      expect(same, isFalse);
    });

    test('the caller keeps control of the Random: retries stay reproducible',
        () {
      // The one property save games depend on. It is what breaks the moment
      // generation constructs a Random of its own, the way the handbook's
      // re-roll does.
      final rng = Random(7);
      final first = LightBeamLogic.generate(rng, 30);
      final second = LightBeamLogic.generate(rng, 30);

      final replay = Random(7);
      final firstAgain = LightBeamLogic.generate(replay, 30);
      final secondAgain = LightBeamLogic.generate(replay, 30);

      expect(firstAgain.solutionMirrors, equals(first.solutionMirrors));
      expect(firstAgain.crystals, equals(first.crystals));
      expect(secondAgain.solutionMirrors, equals(second.solutionMirrors));
      expect(secondAgain.crystals, equals(second.crystals));
    });
  });

  // ------------------------------------------------------- generation gate

  group('generation gate', () {
    const levels = [0, 1, 5, 9, 14, 15, 22, 25, 30, 44, 50, 60, 66, 80, 99];
    const seeds = [1, 2, 3, 4, 5, 6, 7, 8];

    test('replaying solutionMirrors lights EVERY crystal, on every board', () {
      var boards = 0;
      var worstAttempts = 0;
      var fallbacks = 0;

      for (final level in levels) {
        for (final seed in seeds) {
          final board =
              LightBeamLogic.generate(Random(seedFor(level, seed)), level);
          boards++;
          if (board.fromFallback) fallbacks++;
          if (board.attempts > worstAttempts) worstAttempts = board.attempts;

          // THE GATE. Not "is it unsolved" — "does the solution actually work".
          expect(LightBeamLogic.solutionLightsEveryCrystal(board), isTrue,
              reason: 'level $level seed $seed: replaying the solution left a '
                  'crystal dark');
          expect(LightBeamLogic.alreadySolved(board), isFalse,
              reason: 'level $level seed $seed: solved with zero mirrors');
        }
      }

      expect(boards, levels.length * seeds.length);
      expect(fallbacks, 0,
          reason: 'the randomised walk fell back $fallbacks times; the run '
              'length or attempt budget needs re-tuning');
      // Not a correctness requirement, but a generator that needs most of its
      // 200 attempts is one bad tuning edit away from falling back on a real
      // device. Measured over 2000 boards: 1.03 attempts on average, 23 worst.
      expect(worstAttempts, lessThan(60),
          reason: 'worst case took $worstAttempts attempts');
    });

    test('boards are internally consistent', () {
      for (final level in levels) {
        for (final seed in seeds) {
          final b =
              LightBeamLogic.generate(Random(seedFor(level, seed)), level);
          final where = 'level $level seed $seed';

          expect(b.grid.length, b.n);
          expect(b.n, LightBeamLogic.gridSizeFor(level), reason: where);
          expect(b.crystals.length, LightBeamLogic.crystalCountFor(level),
              reason: where);
          expect(b.solutionMirrors.length, LightBeamLogic.mirrorCountFor(level),
              reason: where);
          expect(b.mirrorBudget, greaterThanOrEqualTo(b.solutionMirrorCount),
              reason: '$where: the budget cannot fit the solution');

          // The source sits one cell outside the grid, so the first march step
          // lands on a real cell.
          final outside = b.source.$1 < 0 ||
              b.source.$1 >= b.n ||
              b.source.$2 < 0 ||
              b.source.$2 >= b.n;
          expect(outside, isTrue, reason: '$where: source is inside the grid');

          // The dealt grid holds walls and nothing else — the mirrors are the
          // puzzle and must have been cleared.
          for (var r = 0; r < b.n; r++) {
            for (var c = 0; c < b.n; c++) {
              expect(
                  b.grid[r][c] == LightBeamCell.empty ||
                      b.grid[r][c] == LightBeamCell.block,
                  isTrue,
                  reason: '$where: a mirror was left on the dealt board');
            }
          }

          final mirrorCells = {for (final (pos, _) in b.solutionMirrors) pos};
          expect(mirrorCells.length, b.solutionMirrors.length,
              reason: '$where: two solution mirrors share a cell');

          for (final pos in mirrorCells) {
            // The handbook bug: a crystal on a mirror cell makes that cell
            // un-mirrorable, because tapCell refuses to touch a crystal — the
            // level then cannot be finished by anybody.
            expect(b.crystals.contains(pos), isFalse,
                reason: '$where: a crystal sits on a solution mirror cell');
            expect(b.grid[pos.$1][pos.$2], LightBeamCell.empty,
                reason: '$where: a solution mirror sits on a wall');
          }
          for (final crystal in b.crystals) {
            expect(b.grid[crystal.$1][crystal.$2], LightBeamCell.empty,
                reason: '$where: a crystal sits on a wall');
          }
        }
      }
    });

    test('every level 0-99 generates a verified board on its shipped seed', () {
      // The seed the screen will use is RotationEngine.getDeterminism, which is
      // a plain Random underneath; a fixed derived seed per level covers the
      // same ground without dragging Flutter into this file.
      for (var level = 0; level < 100; level++) {
        final b = LightBeamLogic.generate(Random(level * 2654435761 & 0x7fffffff), level);
        expect(LightBeamLogic.solutionLightsEveryCrystal(b), isTrue,
            reason: 'level $level shipped an unsolvable board');
        expect(LightBeamLogic.alreadySolved(b), isFalse, reason: 'level $level');
        expect(b.fromFallback, isFalse, reason: 'level $level fell back');
      }
    });

    test('generation is bounded even with a hostile attempt budget', () {
      // maxAttempts: 0 forces the fallback path. It must still return a board,
      // and that board must still be a valid puzzle.
      for (final level in [0, 30, 99]) {
        final b = LightBeamLogic.generate(Random(5), level, maxAttempts: 0);
        expect(b.fromFallback, isTrue);
        expect(LightBeamLogic.solutionLightsEveryCrystal(b), isTrue);
        expect(LightBeamLogic.alreadySolved(b), isFalse);
        expect(b.mirrorBudget, greaterThanOrEqualTo(b.solutionMirrorCount));
      }
    });
  });

  // ------------------------------------------------------------- play rules

  group('tapping', () {
    LightBeamGame gameAt(int level, [int seed = 1]) =>
        LightBeamGame()..generate(Random(seedFor(level, seed)), level);

    /// The first cell that is neither a crystal nor a wall.
    (int, int) freeCell(LightBeamGame g) {
      for (var r = 0; r < g.n; r++) {
        for (var c = 0; c < g.n; c++) {
          if (!g.crystals.contains((r, c)) &&
              g.grid[r][c] == LightBeamCell.empty) {
            return (r, c);
          }
        }
      }
      throw StateError('no free cell');
    }

    test('a cell cycles empty -> / -> \\ -> empty', () {
      final g = gameAt(0);
      final (r, c) = freeCell(g);

      expect(g.tapCell(r, c), isTrue);
      expect(g.grid[r][c], slash);
      expect(g.placed, 1);

      expect(g.tapCell(r, c), isTrue);
      expect(g.grid[r][c], backslash);
      expect(g.placed, 1, reason: 'flipping a mirror is not a new placement');

      expect(g.tapCell(r, c), isTrue);
      expect(g.grid[r][c], empty);
      expect(g.placed, 0, reason: 'removing a mirror refunds its slot');
    });

    test('the budget caps placements but never flips', () {
      final g = gameAt(50);
      final placedAt = <(int, int)>[];
      for (var r = 0; r < g.n && placedAt.length < g.mirrorBudget; r++) {
        for (var c = 0; c < g.n && placedAt.length < g.mirrorBudget; c++) {
          if (!g.crystals.contains((r, c)) &&
              g.grid[r][c] == LightBeamCell.empty) {
            g.tapCell(r, c);
            placedAt.add((r, c));
          }
        }
      }
      expect(g.placed, g.mirrorBudget);
      expect(g.mirrorsLeft, 0);

      // One more empty cell must now refuse.
      (int, int)? spare;
      for (var r = 0; r < g.n && spare == null; r++) {
        for (var c = 0; c < g.n; c++) {
          if (g.grid[r][c] == empty && !g.crystals.contains((r, c))) {
            spare = (r, c);
            break;
          }
        }
      }
      expect(spare, isNotNull);
      expect(g.tapCell(spare!.$1, spare.$2), isFalse,
          reason: 'placed a mirror with no budget left');
      expect(g.grid[spare.$1][spare.$2], empty);

      // But an already-placed mirror still flips, and removing one frees a slot.
      expect(g.tapCell(placedAt.first.$1, placedAt.first.$2), isTrue);
      expect(g.grid[placedAt.first.$1][placedAt.first.$2], backslash);
    });

    test('crystals, walls and out-of-bounds cells refuse the tap', () {
      final g = gameAt(80);
      final crystal = g.crystals.first;
      expect(g.tapCell(crystal.$1, crystal.$2), isFalse);
      expect(g.grid[crystal.$1][crystal.$2], empty);

      (int, int)? wall;
      for (var r = 0; r < g.n && wall == null; r++) {
        for (var c = 0; c < g.n; c++) {
          if (g.grid[r][c] == block) {
            wall = (r, c);
            break;
          }
        }
      }
      expect(wall, isNotNull, reason: 'level 80 should carry walls');
      expect(g.tapCell(wall!.$1, wall.$2), isFalse);
      expect(g.grid[wall.$1][wall.$2], block);

      expect(g.tapCell(-1, 0), isFalse);
      expect(g.tapCell(0, g.n), isFalse);
    });

    test('placing every solution mirror wins the board', () {
      for (final level in [0, 15, 40, 66, 99]) {
        final g = gameAt(level, 3);
        expect(g.isWon, isFalse, reason: 'level $level started solved');

        for (final (pos, mirror) in g.board!.solutionMirrors) {
          // A prefix of the solution can already light every crystal — the
          // generator guarantees the full solution works, not that it is
          // minimal. tapCell refuses on a won board, which is correct, so stop.
          if (g.isWon) break;
          // Reached only through tapCell, so the win is proved through the same
          // path a player takes rather than by writing the grid directly.
          var guard = 0;
          while (g.grid[pos.$1][pos.$2] != mirror && guard++ < 4) {
            expect(g.tapCell(pos.$1, pos.$2), isTrue,
                reason: 'level $level: could not build the solution');
          }
          expect(g.grid[pos.$1][pos.$2], mirror);
        }

        expect(g.placed, lessThanOrEqualTo(g.mirrorBudget),
            reason: 'level $level: the solution overran its own budget');
        expect(g.isWon, isTrue, reason: 'level $level did not win');
      }
    });

    test('restart puts the dealt board back', () {
      final g = gameAt(30);
      final dealt = LightBeamLogic.cloneGrid(g.grid);
      final (r, c) = freeCell(g);
      g.tapCell(r, c);
      expect(g.grid, isNot(equals(dealt)));

      g.restart();
      expect(g.grid, equals(dealt));
      expect(g.placed, 0);
      expect(g.taps, 0);
      expect(g.lockedCells, isEmpty);
    });

    test('tightenBudget removes the spare without going below the solution', () {
      final g = gameAt(0);
      expect(g.mirrorBudget, g.board!.solutionMirrorCount + 1);
      g.tightenBudget();
      expect(g.mirrorBudget, g.board!.solutionMirrorCount);
    });
  });

  // ------------------------------------------------------------------ hints

  group('hints', () {
    test('following hints finishes the board and never removes work', () {
      for (final level in [0, 25, 70]) {
        final g = LightBeamGame()..generate(Random(seedFor(level, 2)), level);
        var guard = 0;
        while (!g.isWon && guard++ < 20) {
          expect(g.applyHint(), isTrue, reason: 'level $level ran out of hints');
        }
        expect(g.isWon, isTrue, reason: 'level $level: hints did not finish it');
        expect(g.nextHint(), isNull);
        expect(g.applyHint(), isFalse,
            reason: 'a solved board still offered a hint');
      }
    });

    test('a hinted cell is locked, and a wrong guess is refunded not charged',
        () {
      final g = LightBeamGame()..generate(Random(seedFor(20, 4)), 20);
      final (pos, mirror) = g.board!.solutionMirrors.first;

      // Guess wrong at that cell first: one slot spent. Cycle until the mirror
      // there is the *other* orientation, so the hint really has to correct it.
      expect(g.tapCell(pos.$1, pos.$2), isTrue);
      if (g.grid[pos.$1][pos.$2] == mirror) {
        expect(g.tapCell(pos.$1, pos.$2), isTrue);
      }
      expect(g.grid[pos.$1][pos.$2], isNot(mirror));
      expect(g.placed, 1);

      expect(g.applyHint(), isTrue);
      expect(g.grid[pos.$1][pos.$2], mirror);
      expect(g.placed, 0,
          reason: 'the slot the wrong guess held was not refunded');
      expect(g.lockedCells.contains(pos), isTrue);
      expect(g.tapCell(pos.$1, pos.$2), isFalse,
          reason: 'a revealed mirror must not be cyclable away');
      expect(g.grid[pos.$1][pos.$2], mirror);
    });

    test('a hint on an untouched board costs no budget', () {
      final g = LightBeamGame()..generate(Random(seedFor(45, 5)), 45);
      final budget = g.mirrorBudget;
      expect(g.applyHint(), isTrue);
      expect(g.placed, 0, reason: 'the free mirror consumed a slot');
      expect(g.mirrorBudget, budget);
    });
  });
}
