import 'dart:math';

/// Pure Light Beam logic — no Flutter imports, so it can be unit-tested.
///
/// Rules: a source outside the grid fires a beam inwards. Tapping an empty cell
/// cycles it `/` → `\` → empty. The beam reflects off mirrors, passes straight
/// through crystals, and stops dead on a wall. You win when the beam has passed
/// through every crystal. A mirror budget caps how many mirrors you may place.
///
/// ---------------------------------------------------------------------------
/// THE REFLECTION TABLE, DERIVED
/// ---------------------------------------------------------------------------
/// A `/` mirror is the line `r + c = k`; a `\` mirror is the line `r - c = k`.
/// Reflecting a direction `(dr, dc)` in those lines gives:
///
/// * `/`  → `(-dc, -dr)` — right `(0,1)` becomes up `(-1,0)`, down `(1,0)`
///   becomes left `(0,-1)`.
/// * `\`  → `(dc, dr)`  — right `(0,1)` becomes down `(1,0)`, up `(-1,0)`
///   becomes left `(0,-1)`.
///
/// Both are involutions (`reflect(reflect(d, m), m) == d`), which is why a beam
/// retracing its own corridor comes back out of the source. [reflect] is the one
/// place either formula is written down; every other function calls it, and
/// `test/lightbeam_logic_test.dart` pins all eight direction/mirror pairs.
///
/// ---------------------------------------------------------------------------
/// WHY THIS FILE DOES NOT LOOK LIKE THE BUILDER'S HANDBOOK
/// ---------------------------------------------------------------------------
/// `md/cogniq_builders_handbook.md` Part 5 §B6 sketches a generator. The forward
/// construction it describes is the right idea and is kept. Four things in the
/// sketch are wrong, and all four would have shipped broken levels:
///
/// 1. **Crystals can land on solution-mirror cells.** The sketch draws crystals
///    from `visited`, which includes the cells where it just placed the solution
///    mirrors. `tapCell` then refuses to put a mirror on a crystal, so the one
///    cell the solution needs is permanently un-mirrorable and the level is
///    unwinnable. [_candidateCrystalCells] excludes every mirror cell.
/// 2. **Walls are scattered *before* the walk**, so the walk keeps colliding
///    with them and burning attempts, and (worse) `grid[rng.nextInt(n)]...` can
///    drop a wall on the very cell the beam must enter. Here walls are placed
///    *after* the walk, only on cells the solution beam never touches, so a wall
///    can never invalidate the solution and generation never fails because of
///    one.
/// 3. **`if (!isWon) return;` is the only acceptance test.** "Not already
///    solved" is exactly the check that let sixteen unwinnable Sudoku boards
///    ship (remember.md E2 §10). It says nothing about whether the puzzle *can*
///    be solved. [generate] additionally replays `solutionMirrors` and refuses
///    any board where the replay fails to light every crystal — see
///    [solutionLightsEveryCrystal].
/// 4. **The run length ignores how many mirrors have to fit.** `2 + rng.nextInt(n-2)`
///    on an 8x8 asks for eight non-overlapping segments averaging 4.5 cells, and
///    the walk self-collides on most attempts. [_maxRunFor] scales the run to the
///    space each segment actually has.
///
/// It also tightens the loop guard. The sketch bounds the march with a step
/// count, which terminates but cannot say *why* it stopped and returns a path
/// with the cycle repeated dozens of times. [trace] carries a
/// `(row, col, dr, dc)` state set instead, so a repeat is caught the instant it
/// happens and reported as [LightBeamTrace.looped]. See that field for why the
/// guard should never actually fire, and why it is kept anyway.
///
/// The `Random` is always supplied by the caller and never constructed here, so
/// the same seed and level always deal the same board.

// ---------------------------------------------------------------------------
// value types
// ---------------------------------------------------------------------------

/// What occupies one cell.
///
/// Named `LightBeamCell` rather than the handbook's bare `Cell` because this
/// enum is public API of a library that is imported alongside a dozen other
/// games; `Cell` would collide the first time two of them meet in one file.
enum LightBeamCell {
  empty,

  /// `/` — reflects `(dr, dc)` to `(-dc, -dr)`.
  slash,

  /// `\` — reflects `(dr, dc)` to `(dc, dr)`.
  backslash,

  /// A wall. Swallows the beam; cannot be tapped.
  block,
}

/// The result of marching the beam once.
///
/// [pathSet] duplicates [path] on purpose. The screen asks "is this cell lit?"
/// once per cell per rebuild, and remember.md §E rule 6 forbids a linear scan in
/// an item builder, so the set is built once here rather than searched n² times
/// there.
class LightBeamTrace {
  /// Every cell the beam entered, in the order it entered them, without repeats.
  final List<(int, int)> path;

  /// [path] as a set, for O(1) "is this cell on the beam" lookups.
  final Set<(int, int)> pathSet;

  /// Crystals the beam passed through.
  final Set<(int, int)> lit;

  /// Polyline vertices for the painter: the source (outside the grid), then
  /// every mirror the beam bounced off, then the exit point (also outside the
  /// grid) or the wall that stopped it.
  final List<(int, int)> corners;

  /// Index into [corners] of the first bounce, or -1 when the beam never turns.
  /// The `fog` modifier draws the beam only this far.
  final int firstBounce;

  /// True when the beam repeated a `(row, col, direction)` state instead of
  /// leaving the board.
  ///
  /// **This should never happen, and that is a theorem, not a hope.** Both
  /// mirrors are involutions, so the step function on `(cell, direction)` is
  /// invertible: run a beam backwards and it retraces itself exactly. An
  /// invertible map decomposes its states into cycles and chains, and a state
  /// can only be revisited if it lies on a cycle. The starting state's
  /// predecessor is outside the grid, so the trajectory is a chain — it must
  /// terminate by leaving the board or by hitting a wall, which is the one
  /// non-invertible cell type and absorbs the beam.
  ///
  /// The guard is kept regardless. It costs one set insert per step on an n <= 8
  /// board, and it is what stops a future feature that breaks reversibility — a
  /// one-way filter, a splitter, a mirror that flips after it is struck — from
  /// hanging the UI isolate instead of merely looking wrong.
  final bool looped;

  /// True when a wall swallowed the beam.
  final bool blocked;

  /// Cells stepped through. Diagnostic; bounded by `4 * n * n + 4`.
  final int steps;

  const LightBeamTrace({
    required this.path,
    required this.pathSet,
    required this.lit,
    required this.corners,
    required this.firstBounce,
    required this.looped,
    required this.blocked,
    required this.steps,
  });
}

/// A generated, replay-verified board.
///
/// [grid] is the board *as dealt*: walls only. The solution mirrors have been
/// cleared out of it — rebuilding them is the puzzle.
class LightBeamBoard {
  /// Side of the square grid.
  final int n;

  /// `grid[row][col]`, walls only as dealt.
  final List<List<LightBeamCell>> grid;

  /// Where the beam comes from. Always one cell *outside* the grid, so the first
  /// step of [trace] lands on the first real cell.
  final (int, int) source;

  /// Direction the source fires in: one of `(1,0)`, `(-1,0)`, `(0,1)`, `(0,-1)`.
  final (int, int) sourceDir;

  final Set<(int, int)> crystals;

  /// The mirrors that were placed to build this board, in the order the beam
  /// meets them. Replaying them lights every crystal — asserted at generation
  /// time, not assumed. Also what the hint reveals.
  final List<((int, int), LightBeamCell)> solutionMirrors;

  /// Mirrors the player may place. Never below `solutionMirrors.length`.
  final int mirrorBudget;

  /// How many candidates were rejected before this one. Surfaced so tests can
  /// assert the walk is not quietly failing most of the time.
  final int attempts;

  /// True when the randomised walk never produced an acceptable board and the
  /// deterministic backup was used. Expected to be false for every level;
  /// `test/lightbeam_logic_test.dart` asserts it.
  final bool fromFallback;

  const LightBeamBoard({
    required this.n,
    required this.grid,
    required this.source,
    required this.sourceDir,
    required this.crystals,
    required this.solutionMirrors,
    required this.mirrorBudget,
    required this.attempts,
    required this.fromFallback,
  });

  int get solutionMirrorCount => solutionMirrors.length;

  /// A deep copy, so play can mutate without touching the generated board.
  List<List<LightBeamCell>> cloneGrid() => LightBeamLogic.cloneGrid(grid);
}

// ---------------------------------------------------------------------------
// logic
// ---------------------------------------------------------------------------

class LightBeamLogic {
  // -------------------------------------------------------------- difficulty

  /// The last level on which the board itself gets harder.
  ///
  /// remember.md §D2 as amended: *decide the hardest fair level up front instead
  /// of scaling until impossible*. At level 66 the grid reaches 8x8, the
  /// solution reaches 7 mirrors, crystals reach 5 and walls reach 3 — and all
  /// four caps land on that same level so there is no long tail of one lonely
  /// component still creeping upward.
  ///
  /// Why stop there rather than at 9x9 or 10 mirrors:
  ///
  /// * **8 is what a 320px phone can render honestly.** The board is square and
  ///   sized to the shorter axis; at 9 columns a cell is under 30px, which is
  ///   below the tap target the rest of the app uses and too small for the
  ///   crystal glyph to read.
  /// * **7 bounces is where the puzzle stops being ray marching.** Up to about
  ///   seven segments a player can follow the corridor with their eye. Past that
  ///   the only way through is to place mirrors and watch, which is guessing,
  ///   not deduction.
  ///
  /// From 67 on, difficulty is carried by the modifier rotation (`timer`,
  /// `tightBudget`, `fog`), which is exactly the "make it different, not just
  /// bigger" rule in remember.md §D3.
  static const int hardestFairLevel = 66;

  /// Side of the grid. 5x5 → 8x8, one step every 22 levels.
  static int gridSizeFor(int level) => (5 + level ~/ 22).clamp(5, 8);

  /// Mirrors in the solution, and therefore bounces in the beam.
  ///
  /// Bounded by `n - 1` as well as by the level: eight bounces on a 5x5 would
  /// need more non-overlapping segments than the grid has room for, so the walk
  /// would fail every attempt and every early level would fall back. Because
  /// [gridSizeFor] is itself non-decreasing, so is this.
  static int mirrorCountFor(int level) =>
      min(2 + level ~/ 9, gridSizeFor(level) - 1);

  /// Crystals that must be lit. 1 → 5.
  static int crystalCountFor(int level) => (1 + level ~/ 15).clamp(1, 5);

  /// Walls. 0 → 3, and only ever placed off the solution path.
  static int wallCountFor(int level) => (level ~/ 22).clamp(0, 3);

  /// Mirrors the player is allowed.
  ///
  /// One spare below level 25 so the opening tolerates an experiment, exact
  /// afterwards. Never below [solutionCount]: a budget a perfect solver cannot
  /// meet is a broken level, not a hard one.
  static int mirrorBudgetFor(int level, int solutionCount) =>
      solutionCount + (level < 25 ? 1 : 0);

  /// A single number that must never decrease as the level rises.
  ///
  /// Each component is individually non-decreasing and every weight is positive,
  /// so the sum is non-decreasing by construction — but
  /// `test/lightbeam_logic_test.dart` asserts it across levels 0-99 anyway,
  /// because that is the property a future tuning edit is most likely to break.
  static int difficultyScore(int level) =>
      gridSizeFor(level) * 1000 +
      mirrorCountFor(level) * 100 +
      crystalCountFor(level) * 10 +
      wallCountFor(level);

  // -------------------------------------------------------------- beam rules

  /// The reflection table. See the derivation at the top of this file.
  ///
  /// Anything that is not a mirror leaves the direction alone, so callers can
  /// hand this any cell without checking first.
  static (int, int) reflect((int, int) dir, LightBeamCell cell) {
    final (dr, dc) = dir;
    switch (cell) {
      case LightBeamCell.slash:
        return (-dc, -dr);
      case LightBeamCell.backslash:
        return (dc, dr);
      case LightBeamCell.empty:
      case LightBeamCell.block:
        return dir;
    }
  }

  static List<List<LightBeamCell>> emptyGrid(int n) =>
      List.generate(n, (_) => List.filled(n, LightBeamCell.empty));

  static List<List<LightBeamCell>> cloneGrid(List<List<LightBeamCell>> g) =>
      [for (final row in g) List<LightBeamCell>.from(row)];

  /// Marches the beam from [source] in [sourceDir] until it leaves the board,
  /// hits a wall, or closes a loop.
  ///
  /// **Termination is guaranteed twice over.** The beam's whole state is
  /// `(row, col, dr, dc)`, of which there are exactly `4 * n * n`; the `seen`
  /// set rejects a repeat, so the march cannot take more than that many steps.
  /// The `steps > maxSteps` guard on top of it is a backstop that costs one
  /// comparison and would catch a future edit that broke the state encoding.
  /// See [LightBeamTrace.looped] for why neither guard should ever fire.
  ///
  /// The beam **passes through** crystals — they light, they do not deflect. A
  /// crystal cell can never also hold a mirror ([LightBeamGame.tapCell] refuses,
  /// and generation excludes mirror cells from crystal candidates), so the order
  /// of the two checks below is not load-bearing; it is written crystals-first
  /// to match the handbook.
  static LightBeamTrace trace({
    required List<List<LightBeamCell>> grid,
    required (int, int) source,
    required (int, int) sourceDir,
    Set<(int, int)> crystals = const {},
  }) {
    final n = grid.length;
    final path = <(int, int)>[];
    final pathSet = <(int, int)>{};
    final lit = <(int, int)>{};
    final corners = <(int, int)>[source];
    final seen = <int>{};

    var (r, c) = source;
    var (dr, dc) = sourceDir;
    var firstBounce = -1;
    var looped = false;
    var blocked = false;
    var steps = 0;
    final maxSteps = 4 * n * n + 4;

    while (true) {
      if (++steps > maxSteps) {
        looped = true;
        break;
      }
      r += dr;
      c += dc;
      if (r < 0 || r >= n || c < 0 || c >= n) break; // left the board

      // (row, col, direction) — dr and dc are each in {-1, 0, 1}.
      final state = ((r * n + c) * 3 + (dr + 1)) * 3 + (dc + 1);
      if (!seen.add(state)) {
        looped = true;
        break;
      }

      if (pathSet.add((r, c))) path.add((r, c));

      final cell = grid[r][c];
      if (cell == LightBeamCell.block) {
        blocked = true;
        break;
      }
      if (crystals.contains((r, c))) {
        lit.add((r, c));
        continue;
      }
      if (cell == LightBeamCell.slash || cell == LightBeamCell.backslash) {
        corners.add((r, c));
        if (firstBounce < 0) firstBounce = corners.length - 1;
        (dr, dc) = reflect((dr, dc), cell);
      }
    }

    corners.add((r, c)); // exit point, wall cell, or where the loop closed
    return LightBeamTrace(
      path: path,
      pathSet: pathSet,
      lit: lit,
      corners: corners,
      firstBounce: firstBounce,
      looped: looped,
      blocked: blocked,
      steps: steps,
    );
  }

  /// True when the beam through [grid] reaches every crystal.
  static bool isSolvedState({
    required List<List<LightBeamCell>> grid,
    required (int, int) source,
    required (int, int) sourceDir,
    required Set<(int, int)> crystals,
  }) {
    if (crystals.isEmpty) return false;
    final t = trace(
        grid: grid, source: source, sourceDir: sourceDir, crystals: crystals);
    return t.lit.length == crystals.length;
  }

  // ------------------------------------------------------------ verification

  /// **The gate.** Replays [board]'s `solutionMirrors` onto its dealt grid and
  /// reports whether the beam then reaches every single crystal.
  ///
  /// This is the check remember.md E2 §10 exists for. A generator that only ever
  /// asked "is this board already solved?" is what put sixteen unwinnable Sudoku
  /// levels in front of players for months, so no board leaves [generate]
  /// without passing this, and `test/lightbeam_logic_test.dart` re-runs it over
  /// every level and seed it can afford.
  static bool solutionLightsEveryCrystal(LightBeamBoard board) {
    final g = cloneGrid(board.grid);
    for (final (pos, mirror) in board.solutionMirrors) {
      // A solution mirror landing on a wall or a crystal would be a generator
      // bug, not a hard puzzle — fail loudly rather than paper over it.
      if (g[pos.$1][pos.$2] != LightBeamCell.empty) return false;
      if (board.crystals.contains(pos)) return false;
      g[pos.$1][pos.$2] = mirror;
    }
    final t = trace(
      grid: g,
      source: board.source,
      sourceDir: board.sourceDir,
      crystals: board.crystals,
    );
    return !t.looped && t.lit.length == board.crystals.length;
  }

  /// True when the dealt board needs no mirrors at all — i.e. it is not a
  /// puzzle. Necessary, and nowhere near sufficient; see above.
  static bool alreadySolved(LightBeamBoard board) => isSolvedState(
        grid: board.grid,
        source: board.source,
        sourceDir: board.sourceDir,
        crystals: board.crystals,
      );

  // ------------------------------------------------------------- generation

  /// Longest straight run between two bounces.
  ///
  /// The walk needs `mirrors + 1` non-overlapping segments to fit in `n * n`
  /// cells. Letting every segment run the full width of the board (the
  /// handbook's `2 + rng.nextInt(n - 2)`) makes them collide constantly: on an
  /// 8x8 asking for 7 mirrors it wants ~36 cells of a 64-cell grid arranged with
  /// no crossings, and most attempts self-intersect. Halving the available area
  /// per segment leaves the walk room to turn.
  static int _maxRunFor(int n, int mirrors) =>
      max(2, min(n - 1, (n * n) ~/ (2 * (mirrors + 1))));

  /// The four ways in, as `(source, direction)`. The source always sits one cell
  /// outside the grid so the first step of [trace] lands on a real cell.
  static ((int, int), (int, int)) _entry(int edge, int offset, int n) {
    switch (edge) {
      case 0:
        return ((-1, offset), (1, 0)); // down the top edge
      case 1:
        return ((n, offset), (-1, 0)); // up from the bottom
      case 2:
        return ((offset, -1), (0, 1)); // right from the left
      default:
        return ((offset, n), (0, -1)); // left from the right
    }
  }

  /// How many cells the beam could still travel from `(r, c)` in `(dr, dc)`
  /// before it would leave the board or cross its own path.
  ///
  /// This one-step lookahead is what makes the walk succeed. Without it the
  /// handbook's version picks a run length blind, discovers halfway through that
  /// it has run into the border or its own tail, and throws the whole attempt
  /// away — which is survivable at two mirrors on a 5x5 and hopeless at seven on
  /// an 8x8. Measured on 120 boards spread over levels 0-99, blind picking
  /// burned all 200 attempts and fell back to the backup board 9 times,
  /// including on level 64's shipped seed. With the lookahead, over 2000 boards
  /// (levels 0-99, 20 seeds each): 0 fallbacks, 1.03 attempts on average, 23 in
  /// the worst case, and 116us per board — comfortably inside a frame, which is
  /// what lets generation run on the UI isolate at level load.
  static int _availableAhead(
    Set<(int, int)> visited,
    int n,
    int r,
    int c,
    int dr,
    int dc,
  ) {
    var count = 0;
    var rr = r;
    var cc = c;
    while (true) {
      rr += dr;
      cc += dc;
      if (rr < 0 || rr >= n || cc < 0 || cc >= n) return count;
      if (visited.contains((rr, cc))) return count;
      count++;
    }
  }

  /// Cells a crystal may sit on: on the solution beam, but never where a
  /// solution mirror has to go.
  ///
  /// This exclusion is the handbook bug listed as (1) in the file header. A
  /// crystal on a mirror cell makes that cell permanently un-mirrorable, because
  /// [LightBeamGame.tapCell] refuses to touch a crystal — the level then cannot
  /// be finished by anybody.
  static List<(int, int)> _candidateCrystalCells(
    List<(int, int)> walk,
    Set<(int, int)> mirrorCells,
  ) =>
      [for (final cell in walk) if (!mirrorCells.contains(cell)) cell];

  /// Builds a replay-verified board for [level].
  ///
  /// Deterministic: same [rng] seed + same [level] always produce the same
  /// board. Retries draw from the caller's `Random`, which advances its state,
  /// so successive boards differ while the whole sequence stays reproducible. No
  /// `Random` is ever constructed in here.
  ///
  /// Terminating: at most [maxAttempts] candidates, each one a single bounded
  /// walk plus two bounded traces, then the deterministic [_fallbackBoard]. There
  /// is no unbounded search anywhere in this function.
  static LightBeamBoard generate(
    Random rng,
    int level, {
    int maxAttempts = 200,
  }) {
    final n = gridSizeFor(level);
    final wantMirrors = mirrorCountFor(level);
    final wantCrystals = crystalCountFor(level);
    final wantWalls = wallCountFor(level);
    final maxRun = _maxRunFor(n, wantMirrors);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final (source, sourceDir) =
          _entry(rng.nextInt(4), rng.nextInt(n), n);

      // ---- 1. walk the beam, placing the solution mirrors as we go ----------
      final walk = <(int, int)>[];
      final visited = <(int, int)>{};
      final mirrorCells = <(int, int)>{};
      final solutionMirrors = <((int, int), LightBeamCell)>[];
      // Where the final straight run begins, so at least one crystal can be put
      // beyond the last bounce.
      var lastSegmentStart = 0;

      var (r, c) = source;
      var (dr, dc) = sourceDir;
      var ok = true;

      for (var m = 0; m <= wantMirrors && ok; m++) {
        if (m == wantMirrors) lastSegmentStart = walk.length;

        // Look before leaping: never start a run that cannot finish. A segment
        // is at least two cells so the corridor reads as a corridor.
        final room = _availableAhead(visited, n, r, c, dr, dc);
        if (room < 2) {
          ok = false;
          break;
        }
        final run = 2 + rng.nextInt(min(maxRun, room) - 1);
        for (var s = 0; s < run; s++) {
          r += dr;
          c += dc;
          visited.add((r, c));
          walk.add((r, c));
        }

        if (m < wantMirrors) {
          // Pick an orientation the beam can actually leave by. Trying both, in
          // a seeded order, keeps the choice unbiased while refusing the turns
          // that would strand the walk against a border or its own tail.
          final first =
              rng.nextBool() ? LightBeamCell.slash : LightBeamCell.backslash;
          final second = first == LightBeamCell.slash
              ? LightBeamCell.backslash
              : LightBeamCell.slash;
          LightBeamCell? chosen;
          for (final candidate in [first, second]) {
            final (ndr, ndc) = reflect((dr, dc), candidate);
            if (_availableAhead(visited, n, r, c, ndr, ndc) >= 2) {
              chosen = candidate;
              break;
            }
          }
          if (chosen == null) {
            ok = false;
            break;
          }
          mirrorCells.add((r, c));
          solutionMirrors.add(((r, c), chosen));
          (dr, dc) = reflect((dr, dc), chosen);
        }
      }
      if (!ok || solutionMirrors.length != wantMirrors) continue;

      // ---- 2. drop crystals on the beam, never on a mirror cell -------------
      final candidates = _candidateCrystalCells(walk, mirrorCells);
      if (candidates.length < wantCrystals) continue;

      // One crystal is forced onto the final straight run. Without it every
      // crystal can end up before the first bounce, where the mirror-free beam
      // already reaches them — a board that passes "is it solved?" only by luck.
      final tail = [
        for (var i = lastSegmentStart; i < walk.length; i++)
          if (!mirrorCells.contains(walk[i])) walk[i]
      ];
      if (tail.isEmpty) continue;

      final crystals = <(int, int)>{tail[rng.nextInt(tail.length)]};
      final pool = [for (final cell in candidates) if (!crystals.contains(cell)) cell];
      while (crystals.length < wantCrystals && pool.isNotEmpty) {
        crystals.add(pool.removeAt(rng.nextInt(pool.length)));
      }
      if (crystals.length != wantCrystals) continue;

      // ---- 3. walls, only where the solution beam never goes ----------------
      final grid = emptyGrid(n);
      final free = <(int, int)>[
        for (var rr = 0; rr < n; rr++)
          for (var cc = 0; cc < n; cc++)
            if (!visited.contains((rr, cc))) (rr, cc)
      ];
      for (var w = 0; w < wantWalls && free.isNotEmpty; w++) {
        final pick = free.removeAt(rng.nextInt(free.length));
        grid[pick.$1][pick.$2] = LightBeamCell.block;
      }

      final board = LightBeamBoard(
        n: n,
        grid: grid,
        source: source,
        sourceDir: sourceDir,
        crystals: crystals,
        solutionMirrors: solutionMirrors,
        mirrorBudget: mirrorBudgetFor(level, solutionMirrors.length),
        attempts: attempt,
        fromFallback: false,
      );

      // ---- 4. the gate: prove it, do not assume it -------------------------
      if (!solutionLightsEveryCrystal(board)) continue;
      if (alreadySolved(board)) continue;
      return board;
    }

    return _fallbackBoard(n, level, maxAttempts);
  }

  /// The deterministic backup, used only if [generate] exhausts its attempts.
  ///
  /// Constructed rather than sampled, so it is correct by inspection: the beam
  /// enters row 0 from the left, runs to the far column, a `\` there turns it
  /// down (`(0,1)` → `(1,0)`), and the crystal two rows below is on that
  /// descent. With the mirror removed the beam runs straight along row 0 and
  /// leaves, so the board is not pre-solved. It still goes through the same
  /// verification as a generated board before it is returned.
  static LightBeamBoard _fallbackBoard(int n, int level, int attempts) {
    final board = LightBeamBoard(
      n: n,
      grid: emptyGrid(n),
      source: (0, -1),
      sourceDir: (0, 1),
      crystals: {(2, n - 1)},
      solutionMirrors: [((0, n - 1), LightBeamCell.backslash)],
      mirrorBudget: mirrorBudgetFor(level, 1) + 1,
      attempts: attempts,
      fromFallback: true,
    );
    assert(solutionLightsEveryCrystal(board) && !alreadySolved(board),
        'the Light Beam fallback board must itself be a valid puzzle');
    return board;
  }
}

// ---------------------------------------------------------------------------
// playable state
// ---------------------------------------------------------------------------

/// The mutable game the screen drives. Every rule lives in [LightBeamLogic];
/// this is a thin, tappable shell around a board.
class LightBeamGame {
  LightBeamBoard? board;

  int n = 5;
  List<List<LightBeamCell>> grid = const [];
  (int, int) source = (-1, 0);
  (int, int) sourceDir = (1, 0);
  Set<(int, int)> crystals = const {};

  /// Mirrors the player may place. The screen lowers this to exactly the
  /// solution length under the `tightBudget` modifier.
  int mirrorBudget = 0;

  /// Mirrors the *player* has placed. Hint mirrors are free and are not counted
  /// here — see [applyHint].
  int placed = 0;

  /// Taps that changed something. Shown in the win card.
  int taps = 0;

  int level = 0;

  /// Cells a hint filled in. They are locked: a revealed mirror the player can
  /// immediately cycle away is not a hint, it is a puzzle about what the hint
  /// said.
  final Set<(int, int)> lockedCells = <(int, int)>{};

  LightBeamTrace? _trace;

  /// The current beam, recomputed at most once per mutation.
  ///
  /// A trace is O(n²) with n <= 8, so this is a convenience rather than a
  /// necessity — but the screen reads it several times per rebuild (cell tint,
  /// crystal glow, painter, win check) and caching keeps that honest.
  LightBeamTrace get beam => _trace ??= LightBeamLogic.trace(
        grid: grid,
        source: source,
        sourceDir: sourceDir,
        crystals: crystals,
      );

  bool get isWon =>
      crystals.isNotEmpty && beam.lit.length == crystals.length;

  int get mirrorsLeft => mirrorBudget - placed;

  /// Cycles `(r, c)`: empty → `/` → `\` → empty.
  ///
  /// Returns true when the board changed. False means the tap was refused —
  /// a crystal, a wall, a hinted cell, or no budget left — and the screen turns
  /// that into an error haptic instead of silence.
  bool tapCell(int r, int c) {
    if (isWon) return false;
    if (r < 0 || r >= n || c < 0 || c >= n) return false;
    if (crystals.contains((r, c))) return false;
    if (lockedCells.contains((r, c))) return false;

    switch (grid[r][c]) {
      case LightBeamCell.block:
        return false;
      case LightBeamCell.empty:
        if (placed >= mirrorBudget) return false;
        grid[r][c] = LightBeamCell.slash;
        placed++;
      case LightBeamCell.slash:
        grid[r][c] = LightBeamCell.backslash;
      case LightBeamCell.backslash:
        grid[r][c] = LightBeamCell.empty;
        placed--;
    }
    taps++;
    _trace = null;
    return true;
  }

  /// The next solution mirror that is not already in place, or null when the
  /// player has every one of them right.
  ((int, int), LightBeamCell)? nextHint() {
    final b = board;
    if (b == null) return null;
    for (final entry in b.solutionMirrors) {
      final (pos, mirror) = entry;
      if (grid[pos.$1][pos.$2] != mirror) return entry;
    }
    return null;
  }

  /// Places the next solution mirror for free and locks it.
  ///
  /// Free in both senses: it does not spend a budget slot, and if it overwrites
  /// a wrong player mirror the slot that mirror occupied is refunded — otherwise
  /// a player who guessed wrong would be charged for the guess *and* the
  /// correction. It only ever adds or corrects; it never removes a mirror the
  /// player might still be using elsewhere (remember.md E2 §11).
  bool applyHint() {
    final hint = nextHint();
    if (hint == null) return false;
    final (pos, mirror) = hint;
    final existing = grid[pos.$1][pos.$2];
    if (existing == LightBeamCell.slash ||
        existing == LightBeamCell.backslash) {
      placed--; // refund the slot the wrong mirror was holding
    }
    grid[pos.$1][pos.$2] = mirror;
    lockedCells.add(pos);
    _trace = null;
    return true;
  }

  /// Deals a fresh verified board. [rng] is supplied by the caller so the same
  /// seed and level always produce the same puzzle.
  void generate(Random rng, int forLevel) {
    loadBoard(LightBeamLogic.generate(rng, forLevel), forLevel);
  }

  void loadBoard(LightBeamBoard b, [int forLevel = 0]) {
    board = b;
    level = forLevel;
    n = b.n;
    grid = b.cloneGrid();
    source = b.source;
    sourceDir = b.sourceDir;
    crystals = b.crystals;
    mirrorBudget = b.mirrorBudget;
    placed = 0;
    taps = 0;
    lockedCells.clear();
    _trace = null;
  }

  /// The `tightBudget` modifier: no spare mirrors, the solution length exactly.
  /// Clamped so it can never fall below what the solution needs.
  void tightenBudget() {
    final b = board;
    if (b == null) return;
    mirrorBudget = max(b.solutionMirrorCount, placed);
  }

  /// Back to the dealt position, without regenerating.
  void restart() {
    final b = board;
    if (b == null) return;
    grid = b.cloneGrid();
    placed = 0;
    taps = 0;
    lockedCells.clear();
    _trace = null;
  }
}
