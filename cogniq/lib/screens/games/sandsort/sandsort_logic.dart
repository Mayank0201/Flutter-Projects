import 'dart:collection';
import 'dart:math';

/// Pure Sand Sort logic — no Flutter imports, so it can be unit-tested.
///
/// Rules: every tube is a stack of colour ids (index 0 = bottom). Tap a source
/// tube then a destination; the *whole contiguous top block* of one colour pours
/// if the destination is empty or its top layer is the same colour, truncated by
/// the space left in the destination. You win when every tube is either empty or
/// full of a single colour.
///
/// ---------------------------------------------------------------------------
/// WHY THIS FILE DOES NOT LOOK LIKE THE BUILDER'S HANDBOOK
/// ---------------------------------------------------------------------------
/// `md/cogniq_builders_handbook.md` §5.7.1 ships a generator commented
/// "Deterministic, ALWAYS-solvable generation". It is neither of those things.
///
/// 1. Its `_reversePourOk` ends in a bare `return true`. A reverse walk from the
///    solved state is only guaranteed to be solvable if every reverse step has a
///    *legal forward counterpart*. Returning `true` unconditionally lets the walk
///    step into states no forward pour can undo, so the finished board is a dead
///    end. Measured by simulation, 300 boards per level: levels 0-24 were fine,
///    but level 25 produced 25% unsolvable boards, level 40 34%, level 60 55%,
///    level 80 61%.
/// 2. The cliff is exactly its line `final empties = level < 25 ? 2 : 1;`. One
///    free tube is not enough slack for a 4-deep, 6-colour board. Re-measuring
///    with two empty tubes at every level dropped the failure rate to 0-1 per
///    300 — so [emptyTubesFor] returns 2 for every level, forever.
/// 3. Its "ultra-rare re-roll" calls `generate(Random(rng.nextInt(...)), level)`,
///    constructing a fresh `Random` inside generation. That breaks the one
///    property save-games depend on: same seed + same level = same board.
///
/// This file fixes all three, and then refuses to trust the fix:
///
/// * [reverseMoves] enumerates only reverse pours whose forward counterpart is
///   provably legal (the derivation is written out above it), so a board is
///   solvable *by construction*.
/// * [generate] still runs a real [solve] over every candidate and only returns
///   boards the solver proved solvable, re-rolling from the caller's `Random`
///   otherwise. Belt and braces, because this project has already shipped 16
///   unwinnable Sudoku levels off the back of a "looks fine" generator.
/// * Every search — the DFS solver, the BFS optimal-length pass, the generation
///   retry loop — is bounded by an explicit budget, so nothing can ever hang the
///   UI isolate.
///
/// The `Random` is always supplied by the caller and never constructed here.

// ---------------------------------------------------------------------------
// value types
// ---------------------------------------------------------------------------

/// One pour: [units] layers of [color] moving from tube [from] to tube [to].
///
/// The same type describes a *reverse* pour during generation, where the sand
/// travels from → to but the forward move it stands for is to → from. See
/// [SandSortLogic.reverseMoves].
class SandSortMove {
  final int from;
  final int to;
  final int units;
  final int color;

  const SandSortMove(this.from, this.to, this.units, this.color);

  /// The `(from, to)` pair the screen and the hint button care about.
  (int, int) get pair => (from, to);

  @override
  String toString() => '$from->$to x$units (colour $color)';

  @override
  bool operator ==(Object other) =>
      other is SandSortMove &&
      other.from == from &&
      other.to == to &&
      other.units == units &&
      other.color == color;

  @override
  int get hashCode => Object.hash(from, to, units, color);
}

/// What the solver found.
///
/// [solved] and [exhausted] are deliberately separate: "no solution exists" and
/// "I ran out of budget before I could tell" must never be confused, because the
/// first is a reason to throw a generated board away and the second is a reason
/// to be honest that we do not know.
class SandSortSolution {
  final List<SandSortMove> moves;
  final bool solved;
  final bool exhausted;
  final int nodes;

  const SandSortSolution({
    required this.moves,
    required this.solved,
    required this.exhausted,
    required this.nodes,
  });

  int get length => moves.length;

  /// The solver reached a verdict of "unsolvable" — not merely ran out of road.
  bool get provedUnsolvable => !solved && !exhausted;
}

/// A generated, solver-verified board.
class SandSortBoard {
  /// `tubes[t]` is a stack of colour ids, index 0 = bottom, `last` = top.
  final List<List<int>> tubes;

  /// Layers a tube holds when full.
  final int capacity;

  /// How many distinct sand colours are in play (each has exactly [capacity]
  /// layers in total, so a colour is "done" when one tube holds all of them).
  final int colors;

  /// Tubes that started empty. Always 2 — see the file header.
  final int emptyTubes;

  /// How many reverse pours the scrambler applied. Also an upper bound on the
  /// solution length, since undoing them one by one is a valid solution.
  final int scrambleDepth;

  /// Move count the `quota` modifier should base its budget on.
  ///
  /// Exact shortest solution when [optimalIsExact]; otherwise a guaranteed-
  /// achievable upper bound (never an under-estimate, so a quota derived from it
  /// can never be impossible).
  final int optimalMoves;

  /// True when [optimalMoves] is the provably shortest solution (the bounded BFS
  /// finished), false when it is the safe upper bound.
  final bool optimalIsExact;

  /// How many candidate boards the solver rejected before this one. Expected to
  /// be 0; surfaced so tests can assert the reverse walk is not quietly broken.
  final int attempts;

  /// Nodes the verifying solver visited. Diagnostic only.
  final int solverNodes;

  const SandSortBoard({
    required this.tubes,
    required this.capacity,
    required this.colors,
    required this.emptyTubes,
    required this.scrambleDepth,
    required this.optimalMoves,
    required this.optimalIsExact,
    required this.attempts,
    required this.solverNodes,
  });

  int get tubeCount => tubes.length;

  /// A deep copy, so play can mutate without touching the generated board.
  List<List<int>> cloneTubes() => SandSortLogic.cloneTubes(tubes);
}

// ---------------------------------------------------------------------------
// logic
// ---------------------------------------------------------------------------

class SandSortLogic {
  // -------------------------------------------------------------- difficulty

  /// Layers per tube. Fixed at 4: it is the depth the Tier 1 screen's 34px
  /// layers were sized for, and difficulty is ramped with colours and scramble
  /// depth instead so the board never has to be re-laid-out.
  static const int capacity = 4;

  /// 3 → 6 colours. Capped at 6 because the screen's `_sandColors` palette has
  /// exactly six entries and a seventh would have to repeat one, which in a
  /// colour-matching game is not a difficulty increase, it is a bug.
  ///
  /// Spread over `~/ 18` rather than the handbook's `~/ 15` so the last step
  /// lands at level 54 and the ramp covers more of the 100-level run.
  static int colorsFor(int level) => 3 + (level ~/ 18).clamp(0, 3);

  /// Shortest solution a level should require, before the board is accepted.
  ///
  /// Scramble depth alone does NOT control difficulty: a deeper shuffle can land
  /// on an easy position. Measured on the depth-only generator, level 130 came out
  /// at 12 pours while level 98 needed 14 — later levels were *easier*, which is
  /// exactly what remember.md E2 section 9 forbids. Gating on the solved length
  /// instead ties difficulty to the thing the player actually experiences.
  ///
  /// The cap matters as much as the ramp. Measured at 6 colours the reachable
  /// optimum is 15-19 with a median of 16, so a target of 18 was rejected by
  /// nearly every candidate — generation burned its whole retry budget on every
  /// high level and took 426ms, far too slow for the UI isolate. Capping at
  /// ~2.7x the colour count lands just under the median, so most boards pass on
  /// the first or second attempt while the curve still rises.
  static int minimumOptimumFor(int level) {
    final c = colorsFor(level);
    return (c * 2 + level ~/ 12).clamp(3, (c * 2.7).round());
  }

  /// Always 2. One free tube is where the handbook's generator falls off a
  /// cliff (see the file header) and it is also miserable to play: with a single
  /// empty tube most boards have one forced line and no room to think.
  static int emptyTubesFor(int level) => 2;

  /// How many reverse pours to apply when scrambling. Monotonically rising, so
  /// difficulty never dips as the player advances.
  static int scrambleDepthFor(int level) =>
      (10 + level * 0.7).round().clamp(10, 78);

  /// Total tubes on screen for [level].
  static int tubeCountFor(int level) => colorsFor(level) + emptyTubesFor(level);

  // ------------------------------------------------------------- state rules

  /// Layers in the contiguous single-colour block on top of [tube].
  static int topRunLength(List<int> tube) {
    if (tube.isEmpty) return 0;
    final color = tube.last;
    var n = 0;
    for (var i = tube.length - 1; i >= 0 && tube[i] == color; i--) {
      n++;
    }
    return n;
  }

  /// A tube is finished when it is empty, or full of one colour. A *partly*
  /// filled single-colour tube is not finished: the rest of that colour is still
  /// somewhere else, so the board cannot be won.
  static bool isTubeDone(List<int> tube, int cap) =>
      tube.isEmpty || (tube.length == cap && _isUniform(tube));

  static bool _isUniform(List<int> tube) {
    for (var i = 1; i < tube.length; i++) {
      if (tube[i] != tube[0]) return false;
    }
    return true;
  }

  static bool isWonState(List<List<int>> tubes, int cap) {
    for (final t in tubes) {
      if (!isTubeDone(t, cap)) return false;
    }
    return true;
  }

  static bool canPourState(
      List<List<int>> tubes, int cap, int from, int to) {
    if (from == to) return false;
    if (from < 0 || to < 0 || from >= tubes.length || to >= tubes.length) {
      return false;
    }
    final f = tubes[from];
    final t = tubes[to];
    if (f.isEmpty || t.length >= cap) return false;
    return t.isEmpty || t.last == f.last;
  }

  /// Pours the contiguous top block of [from] onto [to], truncated by the space
  /// left. Mutates [tubes]. Returns the number of layers moved; 0 means the move
  /// was illegal and nothing changed.
  static int pourState(List<List<int>> tubes, int cap, int from, int to) {
    if (!canPourState(tubes, cap, from, to)) return 0;
    final f = tubes[from];
    final t = tubes[to];
    final color = f.last;
    final moved = min(topRunLength(f), cap - t.length);
    for (var i = 0; i < moved; i++) {
      f.removeLast();
      t.add(color);
    }
    return moved;
  }

  static List<List<int>> cloneTubes(List<List<int>> tubes) =>
      [for (final t in tubes) List<int>.from(t)];

  // -------------------------------------------------------------- encoding

  /// Tubes are encoded as one integer each so states can be hashed cheaply.
  ///
  /// The code starts at 1 rather than 0 so leading empties are not lost: `[]`
  /// encodes to 1, `[0]` to `base`, `[0,0]` to `base*base` — different lengths
  /// can never collide.
  static int _baseFor(List<List<int>> tubes) {
    var maxColor = 0;
    for (final t in tubes) {
      for (final c in t) {
        if (c > maxColor) maxColor = c;
      }
    }
    return max(2, maxColor + 1);
  }

  static int _encodeTube(List<int> tube, int base) {
    var code = 1;
    for (final c in tube) {
      code = code * base + c;
    }
    return code;
  }

  static List<int> _decodeTube(int code, int base) {
    final out = <int>[];
    var c = code;
    while (c > 1) {
      out.add(c % base);
      c = c ~/ base;
    }
    return out.reversed.toList();
  }

  /// A key that is identical for two states that differ only in tube *order*.
  ///
  /// Tube identity is meaningless in this game — "the red tube" is wherever the
  /// red sand is — so without this canonicalisation the search re-explores every
  /// permutation of the same position and the visited set stops helping.
  static String canonicalKey(List<List<int>> tubes) {
    final base = _baseFor(tubes);
    final codes = [for (final t in tubes) _encodeTube(t, base)]..sort();
    // Codes are tiny (base <= 7, capacity 4 -> under 2500) so they pack into
    // UTF-16 code units. The guard keeps the function honest if a caller ever
    // hands us a deeper board; joining is slower but always correct.
    var maxCode = 0;
    for (final c in codes) {
      if (c > maxCode) maxCode = c;
    }
    if (maxCode < 0xD000) return String.fromCharCodes(codes);
    return codes.join(',');
  }

  // --------------------------------------------------------------- solving

  /// Admissible lower bound on the number of pours still needed.
  ///
  /// Count every maximal single-colour run in every tube. The finished board has
  /// exactly one run per colour, and a single pour moves one block, so it can
  /// reduce the run count by at most one (the source loses a run; the
  /// destination either merges — no new run — or gains one). Hence
  /// `runs - colours` pours are needed at minimum.
  static int lowerBoundMoves(List<List<int>> tubes) {
    var runs = 0;
    final colors = <int>{};
    for (final t in tubes) {
      for (var i = 0; i < t.length; i++) {
        colors.add(t[i]);
        if (i == 0 || t[i] != t[i - 1]) runs++;
      }
    }
    return max(0, runs - colors.length);
  }

  /// All legal pours from [tubes], best-looking first.
  ///
  /// Two prunes, both safe for boards where each colour has exactly [cap]
  /// layers (which is every board this game creates, and stays true under
  /// pouring since pours conserve sand):
  ///
  /// * Never pour *out of* a full single-colour tube. Full + uniform means that
  ///   tube already holds every layer of that colour, so it is finished; any
  ///   solution that empties it must refill it, and deleting those moves leaves
  ///   a shorter valid solution.
  /// * Never pour a whole uniform tube into an empty tube. That just renames
  ///   which tube is empty — the canonical key proves it is the same position,
  ///   so it can only waste search.
  static List<SandSortMove> legalMoves(List<List<int>> tubes, int cap) {
    final out = <SandSortMove>[];
    for (var from = 0; from < tubes.length; from++) {
      final src = tubes[from];
      if (src.isEmpty) continue;
      final color = src.last;
      final run = topRunLength(src);
      final srcUniform = run == src.length;
      if (srcUniform && src.length == cap) continue; // finished tube
      for (var to = 0; to < tubes.length; to++) {
        if (to == from) continue;
        final dst = tubes[to];
        if (dst.length >= cap) continue;
        if (dst.isNotEmpty && dst.last != color) continue;
        if (dst.isEmpty && srcUniform) continue; // pure relabelling
        final units = min(run, cap - dst.length);
        out.add(SandSortMove(from, to, units, color));
      }
    }
    out.sort((a, b) => _moveScore(tubes, cap, b) - _moveScore(tubes, cap, a));
    return out;
  }

  /// Ordering heuristic. It does not affect correctness, only how fast the DFS
  /// stumbles into a solution — which is what keeps generation off the UI
  /// thread's critical path.
  static int _moveScore(List<List<int>> tubes, int cap, SandSortMove m) {
    final src = tubes[m.from];
    final dst = tubes[m.to];
    var s = 0;
    if (dst.isEmpty) {
      s -= 20; // spending an empty tube is a last resort
    } else {
      s += 20; // merging onto matching sand is almost always progress
      if (dst.length + m.units == cap) s += 60; // completes a colour
    }
    if (m.units == src.length) s += 30; // frees a tube
    s += m.units;
    return s;
  }

  /// Depth-first search for *a* solution, with a canonical visited set and a hard
  /// node budget.
  ///
  /// Iterative rather than recursive on purpose: a DFS guided by a visited set
  /// can walk a path thousands of states long before it backtracks, and that is
  /// a stack overflow waiting to happen on a phone.
  ///
  /// Returns `solved: true` with a replayable move list, or `exhausted: true`
  /// when [budget] ran out before a verdict, or neither when the state space was
  /// searched exhaustively and no solution exists.
  static SandSortSolution solve(
    List<List<int>> tubes,
    int cap, {
    int budget = 200000,
  }) {
    final work = cloneTubes(tubes);
    if (isWonState(work, cap)) {
      return const SandSortSolution(
          moves: [], solved: true, exhausted: false, nodes: 0);
    }

    final visited = <String>{canonicalKey(work)};
    final path = <SandSortMove>[];
    final frames = <_Frame>[_Frame(legalMoves(work, cap))];
    var nodes = 0;

    while (frames.isNotEmpty) {
      final frame = frames.last;
      if (frame.index >= frame.moves.length) {
        frames.removeLast();
        if (path.isNotEmpty) {
          _undo(work, path.removeLast());
        }
        continue;
      }
      final move = frame.moves[frame.index++];

      if (++nodes > budget) {
        return SandSortSolution(
            moves: const [], solved: false, exhausted: true, nodes: nodes);
      }

      final moved = pourState(work, cap, move.from, move.to);
      if (moved == 0) continue; // defensive; legalMoves should never emit these
      final applied = SandSortMove(move.from, move.to, moved, move.color);

      final key = canonicalKey(work);
      if (!visited.add(key)) {
        _undo(work, applied);
        continue;
      }
      path.add(applied);

      if (isWonState(work, cap)) {
        return SandSortSolution(
            moves: List<SandSortMove>.from(path),
            solved: true,
            exhausted: false,
            nodes: nodes);
      }
      frames.add(_Frame(legalMoves(work, cap)));
    }

    return SandSortSolution(
        moves: const [], solved: false, exhausted: false, nodes: nodes);
  }

  static void _undo(List<List<int>> tubes, SandSortMove m) {
    for (var i = 0; i < m.units; i++) {
      tubes[m.to].removeLast();
      tubes[m.from].add(m.color);
    }
  }

  /// Breadth-first search for the *shortest* solution.
  ///
  /// Returns `(distance, firstMove)`. `distance` is -1 when no shortest solution
  /// is available — either [budget] distinct states were reached without finding
  /// the goal, or the position is genuinely unsolvable — and `firstMove` is null
  /// on a won or hopeless board.
  ///
  /// `firstMove` is carried down from the root the same way `zenslide`'s BFS
  /// carries `firstDir`: every queue entry remembers which move off the start
  /// state its branch began with, so the winning entry hands back the move to
  /// play without any parent bookkeeping.
  ///
  /// The budget counts *discovered* states, not expansions, because that is what
  /// bounds memory — a board near the cap fans out ~30 ways per node, so
  /// budgeting expansions alone would let the frontier grow an order of
  /// magnitude past the intended ceiling. Measured across levels 0-99, four
  /// boards each, the search finished inside 25 000 states every single time,
  /// so the budget is headroom rather than a routine cut-off.
  static (int, SandSortMove?) shortestSolution(
    List<List<int>> tubes,
    int cap, {
    int budget = 25000,
  }) {
    if (isWonState(tubes, cap)) return (0, null);
    final base = _baseFor(tubes);

    final seen = <String>{canonicalKey(tubes)};
    final queue = Queue<(List<int>, SandSortMove)>();
    var depth = 0;

    // Seed the queue with the root's own moves so each branch owns a first move.
    for (final m in legalMoves(tubes, cap)) {
      final next = cloneTubes(tubes);
      final moved = pourState(next, cap, m.from, m.to);
      if (moved == 0) continue;
      final applied = SandSortMove(m.from, m.to, moved, m.color);
      if (!seen.add(canonicalKey(next))) continue;
      if (isWonState(next, cap)) return (1, applied);
      queue.add(([for (final t in next) _encodeTube(t, base)], applied));
    }
    if (queue.isNotEmpty) depth = 1;

    while (queue.isNotEmpty) {
      var levelSize = queue.length;
      depth++;
      while (levelSize-- > 0) {
        final (codes, first) = queue.removeFirst();
        final state = [for (final c in codes) _decodeTube(c, base)];
        for (final m in legalMoves(state, cap)) {
          final next = cloneTubes(state);
          if (pourState(next, cap, m.from, m.to) == 0) continue;
          if (!seen.add(canonicalKey(next))) continue;
          if (isWonState(next, cap)) return (depth, first);
          if (seen.length > budget) return (-1, null);
          queue.add(([for (final t in next) _encodeTube(t, base)], first));
        }
      }
    }
    return (-1, null); // searched out without reaching a won state
  }

  /// Length of the shortest solution, or -1 when the bounded BFS could not say.
  ///
  /// Used to give the `quota` modifier an honest target. It is allowed to give
  /// up: [generate] falls back to a guaranteed-achievable upper bound, and an
  /// over-generous quota is a fair puzzle while an under-generous one is an
  /// unwinnable level.
  static int shortestSolutionLength(
    List<List<int>> tubes,
    int cap, {
    int budget = 25000,
  }) =>
      shortestSolution(tubes, cap, budget: budget).$1;

  /// Hint: the first move of a *shortest* solution from [tubes].
  ///
  /// Shortest, not merely any: a DFS hint can cycle. The DFS from state B is a
  /// fresh search with its own visited set, so nothing stops it returning a
  /// solution that begins by undoing the move it just recommended at state A —
  /// and since the solver is deterministic, a player tapping hint repeatedly
  /// would be walked A → B → A → B forever. Taking the first move of a shortest
  /// path makes the distance to the goal strictly decrease every tap, so
  /// following hints always finishes the board, in exactly the optimal number of
  /// pours.
  ///
  /// Falls back to a DFS first move and then to a greedy pick if BFS runs out of
  /// budget. Never returns an illegal move; returns null on a won board or a
  /// board with no legal pours at all.
  static (int, int)? bestPourState(
    List<List<int>> tubes,
    int cap, {
    int budget = 40000,
  }) {
    if (isWonState(tubes, cap)) return null;

    final (distance, first) = shortestSolution(tubes, cap, budget: budget);
    if (distance > 0 && first != null) return first.pair;

    final solution = solve(tubes, cap, budget: budget);
    if (solution.solved && solution.moves.isNotEmpty) {
      return solution.moves.first.pair;
    }
    return _greedyPour(tubes, cap);
  }

  /// Last-resort hint when the solver has no answer (the player has already
  /// wedged the board, or the budget ran out). Prefers a merge onto matching
  /// sand over spending an empty tube, exactly like the handbook's version, but
  /// checks legality itself so an illegal pair can never escape.
  static (int, int)? _greedyPour(List<List<int>> tubes, int cap) {
    (int, int)? fallback;
    for (var a = 0; a < tubes.length; a++) {
      for (var b = 0; b < tubes.length; b++) {
        if (!canPourState(tubes, cap, a, b)) continue;
        fallback ??= (a, b);
        if (tubes[b].isNotEmpty) return (a, b);
      }
    }
    return fallback;
  }

  // ------------------------------------------------------------- generation

  /// Every reverse pour whose forward counterpart is provably legal.
  ///
  /// This is the function the handbook gets wrong (`return true`), so the
  /// derivation is spelled out.
  ///
  /// A forward pour `P -> Q` of `m` layers of colour X requires, in the state
  /// *before* it: P's top run is X and has length `b >= m`; Q is empty or its
  /// top is X; and `m == min(b, cap - |Q|)`.
  ///
  /// A reverse pour takes `m` layers of X off tube `q` (where the sand currently
  /// sits) and puts them on tube `p`, producing the pre-state. For the forward
  /// move `p -> q` to reproduce the current state exactly:
  ///
  /// * **(1)** `p != q` and `|p| + m <= cap`.
  /// * **(2)** After removal, `q` must be empty or still topped by X — otherwise
  ///   the forward pour could not have targeted it. Removing `m` of a top run of
  ///   length `r`: if `m < r` the top stays X (fine); if `m == r` the tube must
  ///   become empty, i.e. `m == |q|`.
  /// * **(3)** `b = m + e`, where `e` is the run of X already on top of `p`. The
  ///   forward pour moves `min(b, cap - (|q| - m))` layers and that must equal
  ///   `m`. With `e == 0`, `b == m` and it holds for free. With `e > 0` we need
  ///   the pour to have been truncated by lack of space, i.e.
  ///   `cap - |q| + m == m`, i.e. `q` was already full.
  ///
  /// Because every step satisfies these, replaying the walk backwards is a valid
  /// solution — the scrambled board is solvable by construction, before the
  /// solver is even asked.
  static List<SandSortMove> reverseMoves(List<List<int>> tubes, int cap) {
    final out = <SandSortMove>[];
    for (var q = 0; q < tubes.length; q++) {
      final src = tubes[q];
      if (src.isEmpty) continue;
      final color = src.last;
      final run = topRunLength(src);
      for (var m = 1; m <= run; m++) {
        if (m == run && m != src.length) continue; // condition (2)
        for (var p = 0; p < tubes.length; p++) {
          if (p == q) continue; // condition (1)
          final dst = tubes[p];
          if (dst.length + m > cap) continue; // condition (1)
          final e = (dst.isNotEmpty && dst.last == color) ? topRunLength(dst) : 0;
          if (e > 0 && src.length != cap) continue; // condition (3)
          out.add(SandSortMove(q, p, m, color));
        }
      }
    }
    return out;
  }

  /// Applies a reverse pour produced by [reverseMoves]: the sand moves
  /// `from -> to`, which is the *undo* of the forward pour `to -> from`.
  static void applyReverse(List<List<int>> tubes, SandSortMove m) {
    for (var i = 0; i < m.units; i++) {
      tubes[m.from].removeLast();
      tubes[m.to].add(m.color);
    }
  }

  /// Builds one scrambled candidate. Solvable by construction; not yet verified.
  static List<List<int>> _scramble(
    Random rng,
    int colors,
    int empties,
    int cap,
    int depth,
  ) {
    final tubes = <List<int>>[
      for (var c = 0; c < colors; c++) List<int>.filled(cap, c, growable: true),
      for (var e = 0; e < empties; e++) <int>[],
    ];

    SandSortMove? last;
    for (var applied = 0; applied < depth; applied++) {
      final all = reverseMoves(tubes, cap);
      if (all.isEmpty) break;
      // Drop the exact inverse of the previous step. Without this the walk
      // spends much of its budget shuffling one block back and forth, and a
      // "depth 78" board comes out looking like a depth 20 one.
      final previous = last;
      final pool = previous == null
          ? all
          : all
              .where((m) =>
                  !(m.from == previous.to &&
                      m.to == previous.from &&
                      m.units == previous.units))
              .toList();
      final choices = pool.isEmpty ? all : pool;
      final move = choices[rng.nextInt(choices.length)];
      applyReverse(tubes, move);
      last = move;
    }
    return tubes;
  }

  /// Builds a solver-verified board for [level].
  ///
  /// Deterministic: same [rng] seed + same [level] always produce the same
  /// board. Re-rolls draw from the caller's `Random`, which advances its state,
  /// so retries differ from each other while the whole sequence stays
  /// reproducible. No `Random` is ever constructed in here.
  ///
  /// Terminating: at most [maxAttempts] candidates, each solved under a node
  /// budget, and the scramble depth eases off after each rejection so the loop
  /// converges on a board the solver can certify rather than spinning on one it
  /// cannot.
  static SandSortBoard generate(
    Random rng,
    int level, {
    int maxAttempts = 12,
    int solveBudget = 200000,
    int exactBudget = 25000,
  }) {
    final colors = colorsFor(level);
    final empties = emptyTubesFor(level);
    final cap = capacity;
    final baseDepth = scrambleDepthFor(level);

    final wantOptimum = minimumOptimumFor(level);
    SandSortBoard? best; // highest optimum seen, in case the target is unmet

    // Difficulty retries are capped separately from solvability retries. Each one
    // costs a full exact-optimum BFS, so an uncapped search for a hard board took
    // 342ms on the worst level — a visible hitch on the UI isolate. Three probes
    // and keep the best is plenty: the curve measurably stops sagging, and the
    // slowest level drops back under ~100ms.
    const maxDifficultyRetries = 2;
    var difficultyRetries = 0;

    var depth = baseDepth;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final tubes = _scramble(rng, colors, empties, cap, depth);

      // A scramble that lands back on a finished board is not a puzzle.
      if (isWonState(tubes, cap)) {
        depth = max(4, depth - 2);
        continue;
      }

      final solution = solve(tubes, cap, budget: solveBudget);
      if (!solution.solved) {
        // Should be unreachable: reverseMoves only emits invertible steps. If it
        // ever fires, the board is thrown away rather than shipped — an
        // unverified board never leaves this function.
        depth = max(4, (depth * 3) ~/ 4);
        continue;
      }

      final exact = shortestSolutionLength(tubes, cap, budget: exactBudget);
      final upperBound = min(depth, solution.length);
      final board = SandSortBoard(
        tubes: tubes,
        capacity: cap,
        colors: colors,
        emptyTubes: empties,
        scrambleDepth: depth,
        optimalMoves: exact >= 0 ? exact : upperBound,
        optimalIsExact: exact >= 0,
        attempts: attempt,
        solverNodes: solution.nodes,
      );

      // Hard enough: ship it.
      if (board.optimalMoves >= wantOptimum) return board;

      // Too easy. Keep it only if it is the hardest so far, shuffle deeper, and
      // try again. Every candidate here is already solver-verified, so the
      // fallback is a valid board rather than a hopeful one.
      if (best == null || board.optimalMoves > best.optimalMoves) best = board;
      if (++difficultyRetries >= maxDifficultyRetries) return best;
      depth = min(depth + 10, scrambleDepthFor(level) + 30);
    }

    // Target never met within the attempt budget. The hardest verified board we
    // saw still beats re-rolling blindly, and it is never easier than the old
    // depth-only generator would have produced.
    if (best != null) return best;

    // Absolute fallback. A 4-step scramble is solvable by construction *and*
    // trivially inside any solver budget, so this still returns a verified
    // board rather than a hopeful one.
    final tubes = _scramble(rng, colors, empties, cap, 4);
    final solution = solve(tubes, cap, budget: solveBudget);
    return SandSortBoard(
      tubes: tubes,
      capacity: cap,
      colors: colors,
      emptyTubes: empties,
      scrambleDepth: 4,
      optimalMoves: solution.solved ? solution.length : 4,
      optimalIsExact: false,
      attempts: maxAttempts,
      solverNodes: solution.nodes,
    );
  }
}

/// One level of the iterative DFS: the moves to try from a state, and how many
/// have been tried.
class _Frame {
  final List<SandSortMove> moves;
  int index = 0;
  _Frame(this.moves);
}

// ---------------------------------------------------------------------------
// playable state
// ---------------------------------------------------------------------------

/// The mutable game the screen drives. All the rules live in [SandSortLogic];
/// this is a thin, tappable shell around a board.
class SandSortGame {
  /// `tubes[t]` is a stack of colour ids, index 0 = bottom, `last` = top.
  List<List<int>> tubes = <List<int>>[];

  int capacity = SandSortLogic.capacity;
  int colors = 3;
  int level = 0;

  /// Pours the player has made.
  int pours = 0;

  /// Move target for the `quota` modifier: `ceil(optimalHint * mult)`.
  int optimalHint = 0;

  /// True when [optimalHint] is the exact shortest solution rather than a safe
  /// upper bound.
  bool optimalIsExact = false;

  /// The board this game was dealt from, kept so the screen can offer a restart
  /// without regenerating (and without re-running the solver).
  SandSortBoard? board;

  bool get isWon => SandSortLogic.isWonState(tubes, capacity);

  bool canPour(int from, int to) =>
      SandSortLogic.canPourState(tubes, capacity, from, to);

  /// Pours the contiguous top block. Returns how many layers moved; 0 = illegal
  /// move, nothing changed, nothing counted.
  int pour(int from, int to) {
    final moved = SandSortLogic.pourState(tubes, capacity, from, to);
    if (moved > 0) pours++;
    return moved;
  }

  /// Hint. Null when the board is won or truly stuck; otherwise a legal
  /// `(from, to)` that is the first move of an actual solution when one is
  /// visible inside the budget.
  (int, int)? bestPour() => SandSortLogic.bestPourState(tubes, capacity);

  /// Minimum pours still needed — cheap, admissible, safe to show live.
  int get movesRemainingLowerBound => SandSortLogic.lowerBoundMoves(tubes);

  /// Deals a fresh solver-verified board. [rng] is supplied by the caller so the
  /// same seed and level always produce the same puzzle.
  void generate(Random rng, int level) {
    loadBoard(SandSortLogic.generate(rng, level), level);
  }

  void loadBoard(SandSortBoard b, [int forLevel = 0]) {
    board = b;
    level = forLevel;
    capacity = b.capacity;
    colors = b.colors;
    tubes = b.cloneTubes();
    optimalHint = b.optimalMoves;
    optimalIsExact = b.optimalIsExact;
    pours = 0;
  }

  /// Back to the dealt position, without regenerating.
  void restart() {
    final b = board;
    if (b == null) return;
    tubes = b.cloneTubes();
    pours = 0;
  }
}
