import 'dart:collection';
import 'dart:math';

/// Pure Zen Slide logic — no Flutter imports, so it can be unit-tested.
///
/// Rules: the sage stone slides in the swiped direction until something stops
/// it — the edge of the board, a grey stone, or the lotus. Land it on the lotus
/// to clear the level. Grey stones never move (the shipped Tier 1 rules); the
/// movable-grey variant is a later unlock and deliberately not built here.
///
/// ---------------------------------------------------------------------------
/// THE MOVE GRAPH, AND WHY EVERYTHING IS BUILT ON IT
/// ---------------------------------------------------------------------------
/// Because the greys are static, one board is one fixed directed graph: a node
/// per free cell, and an edge `u -> [slide](u, d)` for each of the four
/// directions that actually moves the stone. Nothing about the graph depends on
/// how the player got to `u`. Three consequences the rest of this file leans on:
///
/// * **The shortest solve is a BFS.** [solveFrom] runs it forwards from a cell;
///   [distancesToTarget] runs it once *backwards* from the lotus and gets the
///   distance of **every** cell in the same O(rows·cols) sweep.
/// * **The generator can hit a distance exactly.** Pick the greys and the lotus,
///   sweep [distancesToTarget], then choose the start cell from the set whose
///   distance already equals the level's target. That is why every shipped board
///   has `solveDistance == targetDistanceFor(level)` on the nose rather than
///   "at least" it — see the difficulty note below.
/// * **Nothing can hang.** Both searches visit each cell at most once and carry
///   an explicit node budget on top of that ([_nodeBudget]).
///
/// ---------------------------------------------------------------------------
/// WHY THIS FILE DOES NOT LOOK LIKE THE BUILDER'S HANDBOOK
/// ---------------------------------------------------------------------------
/// `md/cogniq_builders_handbook.md` Part 5 §B5 sketches `ZenSlideGame`. The
/// ice-slide rule, the lotus-catches-the-stone touch and the "BFS doubles as the
/// generation gate" idea are all right and are kept. Six things in the sketch
/// are wrong, and the first two would have shipped broken levels:
///
/// 1. **The fallback ships unwinnable boards, and hides it.** When the attempt
///    loop runs out, the sketch keeps the last *rejected* board and writes
///    `optimal = solve(stone).$1.clamp(1, 99)`. `solve` returns `-1` for an
///    unreachable lotus — walls are scattered at random, so walling the lotus
///    off is routine — and `(-1).clamp(1, 99)` is **1**. An unsolvable board is
///    therefore relabelled "one move to solve" and dealt to the player. This is
///    the sixteen-unwinnable-Sudoku-boards failure (remember.md E2 §10) with the
///    evidence deleted. Here the fallback ([_fallbackBoard]) is built from the
///    best *verified* candidate the sweep actually saw, its distance is the real
///    BFS number, and it is flagged in [ZenSlideBoard.fromFallback] so a test can
///    assert it never fires.
/// 2. **`d >= wantOptimal` lets difficulty run backwards.** An at-least gate
///    accepts the first board over the bar, and boards vary wildly: level 10 can
///    deal a 12-move puzzle and level 11 a 5-move one. remember.md E2 §9 forbids
///    exactly that, and Sand Sort already taught the project that a *deeper
///    scramble is not a harder board* — the scramble can walk straight back to
///    an easy position. So the gate here is equality against
///    [targetDistanceFor], which is itself non-decreasing, and the property is
///    asserted on the **measured solve distance** of the shipped board, not on
///    the knob that was aimed at it.
/// 3. **Walls are drawn before the lotus and the stone, with no connectivity
///    check.** `walls.add(rng.nextInt(rows * cols))` in a `while` loop is an
///    unbounded rejection loop, and it happily seals cells off. Here the greys,
///    the lotus and the start all come out of one bounded partial Fisher–Yates
///    shuffle, and the reachability question is answered by the sweep instead of
///    being left to chance.
/// 4. **The stone and the lotus are drawn independently**, so `stone == lotus`
///    burns an attempt on a board that was never a puzzle. The start here is
///    chosen *from the distance sweep*, so it is a cell at the wanted distance by
///    construction and can never be the lotus.
/// 5. **`solve` has no node budget.** It terminates because the grid is finite,
///    but rule 3 of this work order wants the bound written down; both searches
///    here carry [_nodeBudget] and report it rather than silently truncating.
/// 6. **`_slide` reads `lotus` before it is assigned.** `lotus` is `late int` and
///    `_slide` dereferences it, so any call ordering that slides before the first
///    successful `generate` throws `LateInitializationError`. [slide] takes the
///    target as a parameter and owns no mutable state at all.
///
/// Two more defects live in the sketch's screen snippets and are fixed in
/// `zenslide_screen.dart`: `onPanEnd` keys off `details.velocity` alone, so a
/// slow deliberate drag is ignored entirely; and one `cellSize` derived from the
/// width overflows vertically on a non-square board (this game is 5x5 to 8x7).
///
/// The `Random` is always supplied by the caller and never constructed here, so
/// the same seed and level always deal the same board.

// ---------------------------------------------------------------------------
// value types
// ---------------------------------------------------------------------------

/// One of the four swipe directions, as `(dRow, dCol)`.
typedef ZenSlideDir = (int, int);

/// A generated, solver-verified board.
///
/// Cells are flat indices, `row * cols + col`. Flat rather than `(int, int)`
/// records because the searches use them as `Set`/`List` keys on a hot path and
/// an `int` key is a great deal cheaper than a record.
class ZenSlideBoard {
  final int rows;
  final int cols;

  /// Static grey stones. Never contains [target] or [start].
  final Set<int> stones;

  /// Where the sage stone begins.
  final int start;

  /// The lotus.
  final int target;

  /// Shortest number of swipes from [start] to [target], measured by BFS at
  /// generation time — not the level's target knob, the number the solver
  /// actually returned. Always >= [ZenSlideLogic.minPuzzleDistance] except on a
  /// fallback board.
  final int solveDistance;

  /// How many candidates were rejected before this one. Surfaced so tests can
  /// assert the sweep is not quietly failing most of the time.
  final int attempts;

  /// True when no candidate hit the level's exact target distance and the
  /// best-effort backup was used. Expected to be false for every level;
  /// `test/zenslide_logic_test.dart` asserts it.
  final bool fromFallback;

  const ZenSlideBoard({
    required this.rows,
    required this.cols,
    required this.stones,
    required this.start,
    required this.target,
    required this.solveDistance,
    required this.attempts,
    required this.fromFallback,
  });

  int get cellCount => rows * cols;

  int rowOf(int index) => index ~/ cols;

  int colOf(int index) => index % cols;
}

/// The answer to "how do I finish from here", used by both the gate and the
/// hint button.
class ZenSlideSolution {
  /// Swipes needed, or -1 when the lotus cannot be reached from the queried
  /// cell. -1 is a real, expected answer: a player can slide into a pocket the
  /// board cannot get back out of, and the screen turns that into "Restart",
  /// not into a crash.
  final int distance;

  /// The first swipe of one shortest path, or null when there is none.
  final ZenSlideDir? firstMove;

  /// Cells the search dequeued. Diagnostic, and the thing
  /// [ZenSlideLogic._nodeBudget] bounds.
  final int nodesVisited;

  /// True when the node budget stopped the search before it finished. Should
  /// never happen — the budget is larger than the number of cells — and is kept
  /// so a future rules change that grows the state space fails loudly instead of
  /// hanging the UI isolate.
  final bool budgetExhausted;

  const ZenSlideSolution({
    required this.distance,
    required this.firstMove,
    required this.nodesVisited,
    required this.budgetExhausted,
  });

  bool get isReachable => distance >= 0;
}

// ---------------------------------------------------------------------------
// logic
// ---------------------------------------------------------------------------

class ZenSlideLogic {
  const ZenSlideLogic._();

  /// Up, down, left, right. Iteration order is fixed so a hint is stable.
  static const List<ZenSlideDir> directions = [
    (-1, 0),
    (1, 0),
    (0, -1),
    (0, 1),
  ];

  /// Shortest solve any shipped board may have. A one-move board is not a
  /// puzzle, and a two-move board is the empty-grid "slide to a corner, slide
  /// along the edge" that every player finds by accident.
  static const int minPuzzleDistance = 3;

  // -------------------------------------------------------------- difficulty

  /// The last level on which the board itself gets harder.
  ///
  /// remember.md §D2 as amended: *decide the hardest fair level up front instead
  /// of scaling until impossible*. All four knobs — rows, columns, grey stones
  /// and solve distance — reach their cap on this same level, so there is no
  /// long tail of one lonely component still creeping upward. From 67 on,
  /// difficulty is carried by the modifier rotation, which is the "make it
  /// different, not just bigger" rule in remember.md §D3.
  ///
  /// Why stop at 8x7 and nine swipes:
  ///
  /// * **8x7 is what a 320px phone can render honestly.** The board is sized to
  ///   whichever axis is tighter; at nine columns a cell drops under 34px, below
  ///   the tap target the rest of the app uses.
  /// * **Nine swipes is where planning stops being planning.** Up to about nine
  ///   an experienced player can hold the corridor in their head. Past that the
  ///   only way through is to swipe and see, which is guessing.
  static const int hardestFairLevel = 66;

  /// Board height. 5 → 8, one step every 22 levels.
  static int rowsFor(int level) => (5 + level ~/ 22).clamp(5, 8);

  /// Board width. 5 → 7, one step every 33 levels.
  static int colsFor(int level) => (5 + level ~/ 33).clamp(5, 7);

  /// Static grey stones. 2 → 8.
  ///
  /// Also the thing that *makes* long solves possible: on a bare grid the stone
  /// can only ever rest on an edge, so nothing is more than a few swipes from
  /// anything. Interior stops are what create a real route.
  static int stoneCountFor(int level) => (2 + level ~/ 11).clamp(2, 8);

  /// **The difficulty knob that matters**: the exact BFS solve distance a board
  /// must have to ship. 3 → 9.
  ///
  /// Non-decreasing by construction (`level ~/ 11` is monotone and `clamp` of a
  /// monotone function is monotone), and — because [generate] gates on equality
  /// rather than "at least" — the *measured* distance of the shipped board is
  /// non-decreasing too. `test/zenslide_logic_test.dart` asserts that on the
  /// generated boards across levels 0-99, not on this function.
  static int targetDistanceFor(int level) =>
      (minPuzzleDistance + level ~/ 11).clamp(minPuzzleDistance, 9);

  /// A single number that must never decrease as the level rises.
  ///
  /// Every component is individually non-decreasing and every weight is
  /// positive, so the sum is non-decreasing by construction — asserted anyway,
  /// because that is the property a future tuning edit is most likely to break.
  static int difficultyScore(int level) =>
      rowsFor(level) * 1000 +
      colsFor(level) * 100 +
      stoneCountFor(level) * 10 +
      targetDistanceFor(level);

  // ------------------------------------------------------------- move rules

  /// Slides from [from] in `(dr, dc)` until something stops the stone, and
  /// returns where it comes to rest.
  ///
  /// Three things stop it: the edge of the board, a grey stone (it rests on the
  /// cell *before*), and the lotus (it rests *on* it — that catch is what makes
  /// a swipe down a long corridor able to finish the level, and it is the one
  /// piece of the handbook sketch worth copying verbatim).
  ///
  /// Returns [from] unchanged when the stone cannot move at all, which is how
  /// callers detect a no-op swipe. Owns no state: [target] and [stones] are
  /// parameters precisely because the handbook's version read a `late` field and
  /// could throw before the first successful generate.
  ///
  /// Terminates in at most `max(rows, cols) - 1` steps.
  static int slide({
    required int from,
    required int dr,
    required int dc,
    required int rows,
    required int cols,
    required Set<int> stones,
    required int target,
  }) {
    var r = from ~/ cols;
    var c = from % cols;
    while (true) {
      final nr = r + dr;
      final nc = c + dc;
      if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) break;
      final next = nr * cols + nc;
      if (stones.contains(next)) break;
      r = nr;
      c = nc;
      if (next == target) break; // the lotus catches the stone
    }
    return r * cols + c;
  }

  /// The explicit node budget both searches carry (work order rule 3).
  ///
  /// A search over cells can visit each cell once, so `cells + 1` can only be
  /// reached by a bug. It is a tripwire, not a tuning parameter: if a future
  /// rules change makes the state bigger than one cell — movable greys, for
  /// instance, whose state is a tuple of positions — this fires and sets
  /// [ZenSlideSolution.budgetExhausted] instead of spinning on the UI isolate.
  static int _nodeBudget(int rows, int cols) => rows * cols + 1;

  /// Shortest swipes from [from] to [target], plus the first swipe of one
  /// shortest path.
  ///
  /// Forward BFS. Used by the hint button, which needs the answer from wherever
  /// the player currently is; the generator uses [distancesToTarget] instead
  /// because it needs every cell's answer at once.
  static ZenSlideSolution solveFrom({
    required int from,
    required int rows,
    required int cols,
    required Set<int> stones,
    required int target,
  }) {
    final budget = _nodeBudget(rows, cols);
    if (from == target) {
      return const ZenSlideSolution(
        distance: 0,
        firstMove: null,
        nodesVisited: 0,
        budgetExhausted: false,
      );
    }

    final dist = <int, int>{from: 0};
    final firstMove = <int, ZenSlideDir?>{from: null};
    final queue = Queue<int>()..add(from);
    var visited = 0;

    while (queue.isNotEmpty) {
      if (++visited > budget) {
        return ZenSlideSolution(
          distance: -1,
          firstMove: null,
          nodesVisited: visited,
          budgetExhausted: true,
        );
      }
      final cell = queue.removeFirst();
      for (final (dr, dc) in directions) {
        final next = slide(
          from: cell,
          dr: dr,
          dc: dc,
          rows: rows,
          cols: cols,
          stones: stones,
          target: target,
        );
        if (next == cell || dist.containsKey(next)) continue;
        dist[next] = dist[cell]! + 1;
        firstMove[next] = firstMove[cell] ?? (dr, dc);
        if (next == target) {
          return ZenSlideSolution(
            distance: dist[next]!,
            firstMove: firstMove[next],
            nodesVisited: visited,
            budgetExhausted: false,
          );
        }
        queue.add(next);
      }
    }

    // The lotus cannot be reached from `from`. A real, expected answer: the
    // board is a directed graph and the player can slide into a pocket it has
    // no edge out of.
    return ZenSlideSolution(
      distance: -1,
      firstMove: null,
      nodesVisited: visited,
      budgetExhausted: false,
    );
  }

  /// Shortest swipes from **every** cell to [target], in one sweep.
  ///
  /// Reverse BFS: build the move graph forwards, invert it, then breadth-first
  /// out of the lotus. Because every edge costs one swipe, the distance this
  /// returns for a cell is exactly what [solveFrom] would return from it —
  /// `test/zenslide_logic_test.dart` pins the two against each other on random
  /// boards, since the generator trusts this one and the hint trusts the other.
  ///
  /// Entries are -1 for a grey stone and for any cell the lotus cannot be
  /// reached from. The lotus itself is 0.
  ///
  /// Cost: `rows * cols` cells x 4 directions x a slide of at most
  /// `max(rows, cols)` steps to build the graph, then a linear BFS. Under 2000
  /// operations on the largest board this game ships.
  static List<int> distancesToTarget({
    required int rows,
    required int cols,
    required Set<int> stones,
    required int target,
  }) {
    final cells = rows * cols;
    final dist = List<int>.filled(cells, -1);
    if (target < 0 || target >= cells || stones.contains(target)) return dist;

    // Reverse adjacency: predecessors[v] lists every u with an edge u -> v.
    final predecessors = List<List<int>>.generate(cells, (_) => <int>[]);
    for (var u = 0; u < cells; u++) {
      if (stones.contains(u)) continue;
      for (final (dr, dc) in directions) {
        final v = slide(
          from: u,
          dr: dr,
          dc: dc,
          rows: rows,
          cols: cols,
          stones: stones,
          target: target,
        );
        if (v != u) predecessors[v].add(u);
      }
    }

    dist[target] = 0;
    final queue = Queue<int>()..add(target);
    var visited = 0;
    final budget = _nodeBudget(rows, cols);
    while (queue.isNotEmpty && ++visited <= budget) {
      final v = queue.removeFirst();
      for (final u in predecessors[v]) {
        if (dist[u] != -1) continue;
        dist[u] = dist[v] + 1;
        queue.add(u);
      }
    }
    return dist;
  }

  // ------------------------------------------------------------ verification

  /// **The gate.** Re-solves [board] from scratch with the forward BFS and
  /// reports whether the lotus really is exactly [ZenSlideBoard.solveDistance]
  /// swipes away.
  ///
  /// The generator already knows the answer — it picked the start cell *from* a
  /// distance sweep — so this is a second, independent opinion, computed by the
  /// other search. remember.md E2 §10 is in the file for a reason: "the board is
  /// not already solved" is what let sixteen unwinnable Sudoku levels ship, and
  /// the handbook's `d >= wantOptimal` is only one step better because its
  /// fallback bypasses it entirely.
  static bool isVerified(ZenSlideBoard board) {
    if (board.stones.contains(board.start)) return false;
    if (board.stones.contains(board.target)) return false;
    if (board.start == board.target) return false;
    final solution = solveFrom(
      from: board.start,
      rows: board.rows,
      cols: board.cols,
      stones: board.stones,
      target: board.target,
    );
    if (solution.budgetExhausted) return false;
    return solution.distance == board.solveDistance && solution.distance >= 1;
  }

  /// True when the board is solvable at all. Necessary, nowhere near sufficient
  /// — a one-swipe board passes this and is still not a puzzle.
  static bool isSolvable(ZenSlideBoard board) => solveFrom(
        from: board.start,
        rows: board.rows,
        cols: board.cols,
        stones: board.stones,
        target: board.target,
      ).isReachable;

  // -------------------------------------------------------------- generation

  /// Builds a solver-verified board for [level].
  ///
  /// Deterministic: same [rng] seed + same [level] always produce the same
  /// board. Retries draw from the caller's `Random`, which advances its state,
  /// so successive boards differ while the whole sequence stays reproducible. No
  /// `Random` is ever constructed in here.
  ///
  /// Terminating: at most [maxAttempts] candidates, each one a bounded partial
  /// shuffle plus one bounded distance sweep, then the deterministic
  /// [_fallbackBoard]. There is no unbounded search and no rejection loop
  /// anywhere in this function — note in particular that the greys, the lotus
  /// and (via the sweep) the start all come out of a single partial
  /// Fisher–Yates pass, rather than the handbook's
  /// `while (walls.length < wallCount) walls.add(rng.nextInt(...))`.
  ///
  /// Acceptance is **equality** with [targetDistanceFor], not "at least". See
  /// defect 2 in the file header for why an at-least gate lets the measured
  /// difficulty run backwards from one level to the next.
  /// The attempt budget is 400 because the endgame deal is the tight one.
  /// Measured over 660 boards at levels 66-99 (8x7, 8 greys, a nine-swipe
  /// target): about one deal in nineteen lands a cell at exactly nine, average
  /// 7.7 attempts across levels 0-99, worst case 122. Four hundred leaves the
  /// worst case observed at under a third of the budget, and a full 400-attempt
  /// exhaustion still costs under 10ms — an order of magnitude inside the 150ms
  /// per-level ceiling this work order sets.
  static ZenSlideBoard generate(
    Random rng,
    int level, {
    int maxAttempts = 400,
  }) {
    final rows = rowsFor(level);
    final cols = colsFor(level);
    final wantStones = stoneCountFor(level);
    final wantDistance = targetDistanceFor(level);
    final cellCount = rows * cols;

    // Best verified candidate seen, in case nothing hits the exact distance.
    var bestDistance = -1;
    Set<int>? bestStones;
    var bestStart = -1;
    var bestTarget = -1;

    final pool = List<int>.generate(cellCount, (i) => i);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      // One bounded partial Fisher-Yates pass deals the greys and the lotus.
      // `pool` is reused across attempts on purpose: it stays a permutation of
      // every cell, so the deal is still uniform, and the loop allocates
      // nothing per attempt.
      for (var i = 0; i <= wantStones; i++) {
        final j = i + rng.nextInt(cellCount - i);
        final swap = pool[i];
        pool[i] = pool[j];
        pool[j] = swap;
      }
      final stones = pool.sublist(0, wantStones).toSet();
      final target = pool[wantStones];

      final dist = distancesToTarget(
        rows: rows,
        cols: cols,
        stones: stones,
        target: target,
      );

      // Every cell that is exactly the wanted number of swipes away. Choosing
      // the start from this set is what makes the shipped distance exact
      // instead of "somewhere above the bar".
      final exact = <int>[];
      for (var cell = 0; cell < cellCount; cell++) {
        final d = dist[cell];
        if (d == wantDistance) exact.add(cell);
        if (d > bestDistance) {
          bestDistance = d;
          bestStones = stones;
          bestStart = cell;
          bestTarget = target;
        }
      }

      if (exact.isNotEmpty) {
        final board = ZenSlideBoard(
          rows: rows,
          cols: cols,
          stones: stones,
          start: exact[rng.nextInt(exact.length)],
          target: target,
          solveDistance: wantDistance,
          attempts: attempt,
          fromFallback: false,
        );
        // The gate: a second opinion from the other search, every single time.
        // Cheap (one BFS on a board of at most 56 cells) and it is the only
        // thing standing between a tuning slip and an unwinnable level.
        if (isVerified(board)) return board;
      }
    }

    return _fallbackBoard(
      rows: rows,
      cols: cols,
      stones: bestStones,
      start: bestStart,
      target: bestTarget,
      distance: bestDistance,
      attempts: maxAttempts,
    );
  }

  /// The backup, used only when no candidate hit the exact target distance.
  ///
  /// It is *still verified*: it is the deepest candidate the sweep actually
  /// measured, so it is solvable by construction and its `solveDistance` is the
  /// real number rather than the handbook's `(-1).clamp(1, 99)`. Only if the
  /// sweep somehow found nothing solvable at all does this construct a board by
  /// hand: an empty grid with the lotus in one corner and the stone in the
  /// opposite one, which is two swipes and is asserted, not assumed.
  ///
  /// `test/zenslide_logic_test.dart` asserts `fromFallback` is false for every
  /// level 0-199 across many seeds, so in practice this is dead code that exists
  /// to keep a bad day from becoming an unwinnable level.
  static ZenSlideBoard _fallbackBoard({
    required int rows,
    required int cols,
    required Set<int>? stones,
    required int start,
    required int target,
    required int distance,
    required int attempts,
  }) {
    if (stones != null && distance >= 1 && start != target) {
      final board = ZenSlideBoard(
        rows: rows,
        cols: cols,
        stones: stones,
        start: start,
        target: target,
        solveDistance: distance,
        attempts: attempts,
        fromFallback: true,
      );
      if (isVerified(board)) return board;
    }

    // Constructed, so it is correct by inspection: on a bare grid the stone
    // slides from the bottom-right corner to the top-right, then along row 0
    // into the lotus at (0, 0). Two swipes, and no shorter route exists because
    // a single swipe from a corner can only reach the two adjacent corners.
    final board = ZenSlideBoard(
      rows: rows,
      cols: cols,
      stones: const <int>{},
      start: rows * cols - 1,
      target: 0,
      solveDistance: 2,
      attempts: attempts,
      fromFallback: true,
    );
    assert(isVerified(board),
        'the Zen Slide constructed fallback must itself be a valid puzzle');
    return board;
  }
}

// ---------------------------------------------------------------------------
// playable state
// ---------------------------------------------------------------------------

/// The mutable game the screen drives. Every rule lives in [ZenSlideLogic];
/// this is a thin, swipeable shell around a board.
class ZenSlideGame {
  ZenSlideBoard? board;

  int rows = 5;
  int cols = 5;
  Set<int> stones = const <int>{};
  int target = 0;

  /// Where the sage stone is right now.
  int stone = 0;

  /// Swipes that moved the stone.
  int moves = 0;

  /// Swipes that did not move it — the stone was already flush against
  /// something. Shown to the player as a nudge, never as a penalty.
  int blockedSwipes = 0;

  int level = 0;

  /// Cells the stone has come to rest on, in order, including the start. The
  /// screen draws this as the trail; it is a `List` because order matters and a
  /// `Set` of the same cells is kept beside it for the O(1) lookup the grid
  /// needs per cell per rebuild (remember.md §E rule 6).
  final List<int> trail = <int>[];
  final Set<int> trailSet = <int>{};

  int get shortestSolve => board?.solveDistance ?? 0;

  bool get isWon => stone == target;

  /// Shortest swipes still needed, or -1 when the player has slid into a pocket
  /// the lotus cannot be reached from. Recomputed on demand rather than cached:
  /// it is one BFS over at most 56 cells and it is only ever asked for by the
  /// hint button and the footer, not per cell per frame.
  ZenSlideSolution get solutionFromHere => ZenSlideLogic.solveFrom(
        from: stone,
        rows: rows,
        cols: cols,
        stones: stones,
        target: target,
      );

  /// Is the level still winnable from where the stone is standing?
  bool get isStuck => !isWon && !solutionFromHere.isReachable;

  /// One swipe. Returns true when the stone actually moved.
  ///
  /// Refuses once the level is won, so a stray gesture during the win overlay
  /// cannot walk the stone back off the lotus.
  bool swipe(int dr, int dc) {
    if (isWon) return false;
    final next = ZenSlideLogic.slide(
      from: stone,
      dr: dr,
      dc: dc,
      rows: rows,
      cols: cols,
      stones: stones,
      target: target,
    );
    if (next == stone) {
      blockedSwipes++;
      return false;
    }
    stone = next;
    moves++;
    trail.add(next);
    trailSet.add(next);
    return true;
  }

  /// The first swipe of one shortest path from here, or null when the lotus is
  /// unreachable (in which case the screen offers Restart instead of charging
  /// for a hint that cannot help — remember.md E2 §11).
  ZenSlideDir? hintDirection() => solutionFromHere.firstMove;

  /// Deals a fresh verified board. [rng] is supplied by the caller so the same
  /// seed and level always produce the same puzzle.
  void generate(Random rng, int forLevel) {
    loadBoard(ZenSlideLogic.generate(rng, forLevel), forLevel);
  }

  void loadBoard(ZenSlideBoard b, [int forLevel = 0]) {
    board = b;
    level = forLevel;
    rows = b.rows;
    cols = b.cols;
    stones = b.stones;
    target = b.target;
    stone = b.start;
    moves = 0;
    blockedSwipes = 0;
    trail
      ..clear()
      ..add(b.start);
    trailSet
      ..clear()
      ..add(b.start);
  }

  /// Back to the dealt position, without regenerating.
  void restart() {
    final b = board;
    if (b == null) return;
    loadBoard(b, level);
  }
}
