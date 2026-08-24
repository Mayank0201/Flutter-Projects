import 'dart:math';

/// Pure Kakuro generation logic — no Flutter imports, so it can be unit-tested.
///
/// Extracted from `kakuro_screen.dart` on 2026-08-22 while fixing the bug that made
/// every level from 5 upward impossible to generate. See `md/RELEASE_PLAN.md` §4.1A.
///
/// Cell types: 0 = wall, 1 = white/fillable, 2 = clue cell.
class KakuroBoard {
  final int size;
  final List<int> types;
  final List<int> solution;
  final List<int> hClues;
  final List<int> vClues;

  /// How many solutions the bounded solver found: 1 = unique (ideal),
  /// 2 = at least two, -1 = the search budget ran out before it could tell.
  final int solutionCount;

  const KakuroBoard({
    required this.size,
    required this.types,
    required this.solution,
    required this.hClues,
    required this.vClues,
    required this.solutionCount,
  });

  bool get isUnique => solutionCount == 1;
}

class KakuroLogic {
  // ---------------------------------------------------------------- layouts

  static const List<int> layout4x4 = [
    0, 2, 2, 0, //
    2, 1, 1, 0, //
    2, 1, 1, 2, //
    0, 0, 2, 0,
  ];

  static const List<int> layout6x6 = [
    0, 2, 2, 2, 2, 0, //
    2, 1, 1, 1, 1, 2, //
    2, 1, 1, 0, 1, 1, //
    2, 1, 0, 2, 1, 1, //
    2, 1, 1, 1, 1, 0, //
    0, 0, 2, 2, 0, 0,
  ];

  /// The original 8x8. Kept because it works, but note its runs are mostly 3 cells
  /// long, which are weak constraints — the solver has to explore a lot before it
  /// can say whether the board is unique. `layout8x8b` is the better-conditioned
  /// alternative; both are used so the shape varies with level.
  static const List<int> layout8x8 = [
    0, 2, 2, 2, 0, 2, 2, 2, //
    2, 1, 1, 1, 2, 1, 1, 1, //
    2, 1, 1, 1, 2, 1, 1, 1, //
    0, 2, 1, 1, 1, 1, 0, 0, //
    0, 0, 1, 1, 1, 1, 2, 0, //
    2, 1, 1, 1, 2, 1, 1, 1, //
    2, 1, 1, 1, 2, 1, 1, 1, //
    0, 0, 0, 0, 0, 0, 0, 0,
  ];

  /// Longer runs (up to 6 cells). A 6-cell run of distinct digits summing to a
  /// given total has far fewer valid combinations than a 3-cell run, so this
  /// prunes much harder and reaches a verdict sooner.
  static const List<int> layout8x8b = [
    0, 2, 2, 0, 2, 2, 2, 0, //
    2, 1, 1, 2, 1, 1, 1, 0, //
    2, 1, 1, 1, 1, 1, 1, 0, //
    0, 2, 1, 1, 1, 1, 0, 0, //
    0, 2, 1, 1, 1, 1, 2, 0, //
    2, 1, 1, 1, 1, 1, 1, 0, //
    2, 1, 1, 2, 1, 1, 1, 0, //
    0, 0, 0, 0, 0, 0, 0, 0,
  ];

  /// Layout options per size band. Generation picks one deterministically from the
  /// level seed, so the grid *shape* varies with level rather than every level
  /// above 12 being the same picture with different digits.
  static List<List<int>> layoutsFor(int level) {
    if (level < 5) return const [layout4x4];
    if (level < 12) return const [layout6x6];
    return const [layout8x8, layout8x8b];
  }

  static int sizeFor(int level) => level < 5 ? 4 : (level < 12 ? 6 : 8);

  // ------------------------------------------------------------ normalization

  /// Every white run must be headed by a clue cell, or it has no sum constraint.
  ///
  /// The hand-authored layouts put a plain wall (0) in front of several runs.
  /// `computeClues` only writes clues outward from clue cells, so those runs kept
  /// clue 0 — and the sum check compares with `sum >= clue`, true for every digit
  /// 1-9, so the solver rejected the first digit placed in such a run, found zero
  /// solutions, and every level from 5 up fell through to the fallback board.
  ///
  /// Promoting a wall that heads a run into a clue cell fixes it for every layout,
  /// including any added later. Only 0 -> 2 promotions happen, so no white cell is
  /// ever touched and reading neighbours while promoting stays correct.
  static List<int> normalizeLayout(List<int> layout, int size) {
    final types = List<int>.from(layout);
    for (int i = 0; i < types.length; i++) {
      if (types[i] != 0) continue;
      final r = i ~/ size;
      final c = i % size;
      final headsRow = c + 1 < size && types[r * size + c + 1] == 1;
      final headsCol = r + 1 < size && types[(r + 1) * size + c] == 1;
      if (headsRow || headsCol) types[i] = 2;
    }
    return types;
  }

  /// White cells that begin a run with no clue cell in front of them. Must be empty
  /// for a layout to be generatable — asserted in `test/kakuro_logic_test.dart`.
  static List<int> unheadedRuns(List<int> types, int size) {
    final bad = <int>[];
    for (int i = 0; i < types.length; i++) {
      if (types[i] != 1) continue;
      final r = i ~/ size;
      final c = i % size;
      if (c == 0 || types[r * size + c - 1] != 1) {
        if (c == 0 || types[r * size + c - 1] != 2) bad.add(i);
      }
      if (r == 0 || types[(r - 1) * size + c] != 1) {
        if (r == 0 || types[(r - 1) * size + c] != 2) bad.add(i);
      }
    }
    return bad;
  }

  /// Longest run in the layout. Runs longer than 9 can never hold distinct digits.
  static int longestRun(List<int> types, int size) {
    var longest = 0;
    for (int i = 0; i < types.length; i++) {
      if (types[i] != 1) continue;
      longest = max(longest, rowRun(types, size, i).length);
      longest = max(longest, colRun(types, size, i).length);
    }
    return longest;
  }

  // -------------------------------------------------------------------- runs

  static List<int> rowRun(List<int> types, int size, int idx) {
    final r = idx ~/ size;
    var c = idx % size;
    while (c >= 0 && types[r * size + c] == 1) {
      c--;
    }
    final out = <int>[];
    var x = c + 1;
    while (x < size && types[r * size + x] == 1) {
      out.add(r * size + x);
      x++;
    }
    return out;
  }

  static List<int> colRun(List<int> types, int size, int idx) {
    final c = idx % size;
    var r = idx ~/ size;
    while (r >= 0 && types[r * size + c] == 1) {
      r--;
    }
    final out = <int>[];
    var y = r + 1;
    while (y < size && types[y * size + c] == 1) {
      out.add(y * size + c);
      y++;
    }
    return out;
  }

  /// Index of the clue cell heading the run containing [idx], or -1.
  static int rowClueCell(List<int> types, int size, int idx) {
    final r = idx ~/ size;
    var c = idx % size;
    while (c >= 0 && types[r * size + c] == 1) {
      c--;
    }
    return c < 0 ? -1 : r * size + c;
  }

  static int colClueCell(List<int> types, int size, int idx) {
    final c = idx % size;
    var r = idx ~/ size;
    while (r >= 0 && types[r * size + c] == 1) {
      r--;
    }
    return r < 0 ? -1 : r * size + c;
  }

  // ------------------------------------------------------------- run indexing

  /// Precomputed run structure for one layout.
  ///
  /// `rowRun`/`colRun` walk the grid and allocate a fresh list every call. The
  /// solver calls them several times per node visit, so on an 8x8 the allocation —
  /// not the search — dominated: five boards took 28 seconds. Building this once
  /// per layout and indexing into it removes that entirely.
  static KakuroRunIndex buildIndex(List<int> types, int size) {
    final n = types.length;
    final rowOf = List<List<int>>.filled(n, const []);
    final colOf = List<List<int>>.filled(n, const []);
    final rowClue = List<int>.filled(n, -1);
    final colClue = List<int>.filled(n, -1);
    final whites = <int>[];

    for (int i = 0; i < n; i++) {
      if (types[i] != 1) continue;
      whites.add(i);
      rowOf[i] = rowRun(types, size, i);
      colOf[i] = colRun(types, size, i);
      rowClue[i] = rowClueCell(types, size, i);
      colClue[i] = colClueCell(types, size, i);
    }
    return KakuroRunIndex(rowOf, colOf, rowClue, colClue, whites);
  }

  // -------------------------------------------------------------- generation

  static bool _fill(KakuroRunIndex ix, List<int> sol, int pos, Random rng) {
    if (pos >= ix.whites.length) return true;
    final idx = ix.whites[pos];

    final digits = [1, 2, 3, 4, 5, 6, 7, 8, 9]..shuffle(rng);
    for (final d in digits) {
      if (_canPlace(ix, sol, idx, d)) {
        sol[idx] = d;
        if (_fill(ix, sol, pos + 1, rng)) return true;
        sol[idx] = 0;
      }
    }
    return false;
  }

  static bool _canPlace(KakuroRunIndex ix, List<int> board, int idx, int d) {
    final rr = ix.rowOf[idx];
    for (int k = 0; k < rr.length; k++) {
      if (rr[k] != idx && board[rr[k]] == d) return false;
    }
    final cr = ix.colOf[idx];
    for (int k = 0; k < cr.length; k++) {
      if (cr[k] != idx && board[cr[k]] == d) return false;
    }
    return true;
  }

  static void computeClues(
      List<int> types, int size, List<int> sol, List<int> h, List<int> v) {
    for (int i = 0; i < types.length; i++) {
      if (types[i] != 2) continue;
      final right = i + 1;
      if (right < types.length && right % size != 0 && types[right] == 1) {
        h[i] = rowRun(types, size, right).fold(0, (a, x) => a + sol[x]);
      }
      final down = i + size;
      if (down < types.length && types[down] == 1) {
        v[i] = colRun(types, size, down).fold(0, (a, x) => a + sol[x]);
      }
    }
  }

  /// Counts solutions, stopping at [maxSolutions] or when [budget] node visits are
  /// used up. Returns -1 if the budget ran out before a verdict.
  ///
  /// The budget is what stops the 8x8 from freezing the UI. Before the clue fix the
  /// solver rejected the first digit of an unheaded run and failed instantly, so
  /// nobody noticed the search space; with valid clues it is real work.
  static int countSolutions(
    List<int> types,
    int size,
    List<int> h,
    List<int> v, {
    int maxSolutions = 2,
    int budget = 40000,
    KakuroRunIndex? index,
  }) {
    final ix = index ?? buildIndex(types, size);
    final board = List<int>.filled(types.length, 0);
    var nodes = 0;
    var found = 0;
    var exhausted = false;

    bool sumsOk(int idx) {
      final rr = ix.rowOf[idx];
      final rc = ix.rowClue[idx];
      final hClue = rc < 0 ? 0 : h[rc];
      var sum = 0;
      var complete = true;
      for (int k = 0; k < rr.length; k++) {
        final val = board[rr[k]];
        if (val == 0) {
          complete = false;
        } else {
          sum += val;
        }
      }
      if (complete ? sum != hClue : sum >= hClue) return false;

      final cr = ix.colOf[idx];
      final cc = ix.colClue[idx];
      final vClue = cc < 0 ? 0 : v[cc];
      sum = 0;
      complete = true;
      for (int k = 0; k < cr.length; k++) {
        final val = board[cr[k]];
        if (val == 0) {
          complete = false;
        } else {
          sum += val;
        }
      }
      if (complete ? sum != vClue : sum >= vClue) return false;
      return true;
    }

    void walk(int pos) {
      if (exhausted || found >= maxSolutions) return;
      if (++nodes > budget) {
        exhausted = true;
        return;
      }
      if (pos >= ix.whites.length) {
        found++;
        return;
      }
      final idx = ix.whites[pos];

      for (int d = 1; d <= 9; d++) {
        if (!_canPlace(ix, board, idx, d)) continue;
        board[idx] = d;
        if (sumsOk(idx)) walk(pos + 1);
        board[idx] = 0;
        if (exhausted || found >= maxSolutions) return;
      }
    }

    walk(0);
    return exhausted ? -1 : found;
  }

  /// Builds a board for [level].
  ///
  /// Prefers a puzzle with exactly one solution. If the budget runs out before that
  /// can be established — realistic on 8x8 — it accepts a board anyway: every filled
  /// board satisfies its own clues by construction, so it is always winnable, and
  /// Kakuro's win check validates sums rather than matching one stored answer, so a
  /// second valid solution still wins. Never returns null, never resets the level.
  static KakuroBoard generate(
    int level,
    Random rng, {
    int? retries,
    int budget = 40000,
  }) {
    final size = sizeFor(level);
    final options = layoutsFor(level);
    final base = options[rng.nextInt(options.length)];
    final types = normalizeLayout(base, size);
    final n = size * size;
    final ix = buildIndex(types, size);

    // Retries are size-aware. Small boards prove uniqueness almost instantly, so
    // they can afford many attempts; an 8x8 attempt costs orders of magnitude more,
    // and if a layout will not yield a unique board quickly it will not yield one on
    // the 60th try either — better to accept a good board than stall the screen.
    final attempts = retries ?? (size >= 8 ? 12 : 120);

    KakuroBoard? fallback;

    for (int attempt = 0; attempt < attempts; attempt++) {
      final sol = List<int>.filled(n, 0);
      if (!_fill(ix, sol, 0, rng)) continue;

      final h = List<int>.filled(n, 0);
      final v = List<int>.filled(n, 0);
      computeClues(types, size, sol, h, v);

      final count =
          countSolutions(types, size, h, v, budget: budget, index: ix);
      final board = KakuroBoard(
        size: size,
        types: types,
        solution: sol,
        hClues: h,
        vClues: v,
        solutionCount: count,
      );
      if (count == 1) return board;
      fallback ??= board;
    }

    // Every candidate here is still solvable — keep the first one rather than
    // dropping the player to a 4x4 (and, as the original code did, wiping progress).
    return fallback ??
        KakuroBoard(
          size: 4,
          types: normalizeLayout(layout4x4, 4),
          solution: const [0, 0, 0, 0, 0, 8, 7, 0, 0, 1, 5, 0, 0, 0, 0, 0],
          hClues: const [0, 0, 0, 0, 15, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0],
          vClues: const [0, 9, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
          solutionCount: 1,
        );
  }
}

/// Precomputed run membership and clue-cell lookup for one layout.
class KakuroRunIndex {
  final List<List<int>> rowOf;
  final List<List<int>> colOf;
  final List<int> rowClue;
  final List<int> colClue;
  final List<int> whites;

  const KakuroRunIndex(
      this.rowOf, this.colOf, this.rowClue, this.colClue, this.whites);
}
