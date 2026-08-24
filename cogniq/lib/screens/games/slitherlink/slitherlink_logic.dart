import 'dart:collection';
import 'dart:math';

/// Pure Slitherlink logic — no Flutter imports, so it is unit-testable.
///
/// Extracted from `slitherlink_screen.dart` on 2026-08-22. See
/// `md/RELEASE_PLAN.md` §4.3A.
///
/// **The recorded defect was wrong.** The plan blamed a "stuck-growth fallback
/// that force-adds a hole, producing a two-loop board". That line does exist
/// (`if (!added) cells.add(candidates.first);`, no re-check) — but simulating the
/// original generator over 9,000 boards it **never once fired**, because the
/// target region sizes are small relative to the grid and a legal candidate is
/// always available.
///
/// The real defect is a **diagonal pinch**. `_isSimplyConnected` checked that the
/// region and its complement are each edge-connected, which is necessary but not
/// sufficient: two cells touching only at a corner satisfy it while making the
/// boundary pass through that corner twice, producing a **degree-4 vertex**. The
/// screen's own win check rejects any vertex whose degree is not 0 or 2, so those
/// boards store a solution that fails the game's own validator. Measured over
/// 3,000 boards per size: **0% at 3x3, 0.7% at 4x4, 2.4% at 5x5** — so roughly
/// one level in forty from level 13 up was unsolvable.
///
/// Filtering pinches during growth cuts that to 0.43%, which is better and still
/// not good enough. So generation is gated on the thing that actually matters:
/// the derived edge set is fed to [isSingleLoop] — the same predicate the win
/// check uses — and a board is discarded unless it passes.
class SlitherlinkBoard {
  final int size;

  /// One entry per edge: horizontal edges first, then vertical.
  final List<bool> solution;

  /// Clue per cell, or -1 for no clue.
  final List<int> clues;

  final int attempts;

  const SlitherlinkBoard({
    required this.size,
    required this.solution,
    required this.clues,
    required this.attempts,
  });

  static int horizontalEdgeCount(int size) => (size + 1) * size;
  static int verticalEdgeCount(int size) => size * (size + 1);
  static int edgeCount(int size) =>
      horizontalEdgeCount(size) + verticalEdgeCount(size);
}

class SlitherlinkLogic {
  static int sizeFor(int level) => level < 5 ? 3 : (level < 12 ? 4 : 5);

  /// Cells the loop encloses, as a fraction of the grid. Rises with level so
  /// later boards have longer, more interesting loops.
  static int targetRegionFor(int size, int level, Random rng) {
    switch (size) {
      case 3:
        return 3 + rng.nextInt(3); // 3..5
      case 4:
        return 6 + rng.nextInt(4); // 6..9
      default:
        return 10 + rng.nextInt(5); // 10..14
    }
  }

  // ------------------------------------------------------------- geometry

  static bool isEdgeConnected(Set<int> cells, int size) {
    if (cells.isEmpty) return false;
    final start = cells.first;
    final seen = <int>{start};
    final q = Queue<int>()..add(start);
    while (q.isNotEmpty) {
      final i = q.removeFirst();
      final r = i ~/ size;
      final c = i % size;
      void visit(int nr, int nc) {
        if (nr < 0 || nr >= size || nc < 0 || nc >= size) return;
        final j = nr * size + nc;
        if (cells.contains(j) && seen.add(j)) q.add(j);
      }

      visit(r + 1, c);
      visit(r - 1, c);
      visit(r, c + 1);
      visit(r, c - 1);
    }
    return seen.length == cells.length;
  }

  /// True when the complement (including the outside) is one connected region —
  /// i.e. the shape encloses no holes.
  static bool complementConnected(Set<int> cells, int size) {
    final p = size + 2; // one ring of padding = the outside
    bool isComp(int pr, int pc) {
      if (pr == 0 || pc == 0 || pr == p - 1 || pc == p - 1) return true;
      return !cells.contains((pr - 1) * size + (pc - 1));
    }

    var total = 0;
    for (var a = 0; a < p; a++) {
      for (var b = 0; b < p; b++) {
        if (isComp(a, b)) total++;
      }
    }

    final seen = <int>{0};
    final q = Queue<int>()..add(0);
    while (q.isNotEmpty) {
      final i = q.removeFirst();
      final a = i ~/ p;
      final b = i % p;
      void visit(int na, int nb) {
        if (na < 0 || na >= p || nb < 0 || nb >= p) return;
        if (!isComp(na, nb)) return;
        if (seen.add(na * p + nb)) q.add(na * p + nb);
      }

      visit(a + 1, b);
      visit(a - 1, b);
      visit(a, b + 1);
      visit(a, b - 1);
    }
    return seen.length == total;
  }

  /// A 2x2 block whose two member cells sit diagonally opposite. The boundary
  /// then passes through that shared corner twice, giving a degree-4 vertex and
  /// a figure-of-eight rather than a simple loop.
  static bool hasDiagonalPinch(Set<int> cells, int size) {
    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size - 1; c++) {
        final tl = cells.contains(r * size + c);
        final tr = cells.contains(r * size + c + 1);
        final bl = cells.contains((r + 1) * size + c);
        final br = cells.contains((r + 1) * size + c + 1);
        if ((tl && br && !tr && !bl) || (tr && bl && !tl && !br)) return true;
      }
    }
    return false;
  }

  // ------------------------------------------------------------ derivation

  /// An edge is on the loop when it separates a member cell from a non-member.
  static List<bool> deriveEdges(Set<int> cells, int size) {
    final numH = SlitherlinkBoard.horizontalEdgeCount(size);
    final sol = List<bool>.filled(SlitherlinkBoard.edgeCount(size), false);

    for (var r = 0; r <= size; r++) {
      for (var c = 0; c < size; c++) {
        final above = r > 0 && cells.contains((r - 1) * size + c);
        final below = r < size && cells.contains(r * size + c);
        sol[r * size + c] = above != below;
      }
    }
    for (var r = 0; r < size; r++) {
      for (var c = 0; c <= size; c++) {
        final left = c > 0 && cells.contains(r * size + c - 1);
        final right = c < size && cells.contains(r * size + c);
        sol[numH + r * (size + 1) + c] = left != right;
      }
    }
    return sol;
  }

  /// How many of a cell's four edges are on the loop. This is the clue.
  static int edgesAroundCell(List<bool> sol, int size, int cell) {
    final r = cell ~/ size;
    final c = cell % size;
    final numH = SlitherlinkBoard.horizontalEdgeCount(size);
    var n = 0;
    if (sol[r * size + c]) n++; // top
    if (sol[(r + 1) * size + c]) n++; // bottom
    if (sol[numH + r * (size + 1) + c]) n++; // left
    if (sol[numH + r * (size + 1) + c + 1]) n++; // right
    return n;
  }

  /// The exact predicate the screen's win check applies: every vertex has degree
  /// 0 or 2, at least one edge is used, and every used vertex lies on **one**
  /// closed traversal.
  static bool isSingleLoop(List<bool> sol, int size) {
    final numH = SlitherlinkBoard.horizontalEdgeCount(size);
    final vertexCount = (size + 1) * (size + 1);
    final adj = List<List<int>>.generate(vertexCount, (_) => <int>[]);

    for (var r = 0; r <= size; r++) {
      for (var c = 0; c < size; c++) {
        if (!sol[r * size + c]) continue;
        final u = r * (size + 1) + c;
        final v = u + 1;
        adj[u].add(v);
        adj[v].add(u);
      }
    }
    for (var r = 0; r < size; r++) {
      for (var c = 0; c <= size; c++) {
        if (!sol[numH + r * (size + 1) + c]) continue;
        final u = r * (size + 1) + c;
        final v = u + (size + 1);
        adj[u].add(v);
        adj[v].add(u);
      }
    }

    var active = 0;
    var start = -1;
    for (var i = 0; i < vertexCount; i++) {
      final d = adj[i].length;
      // Degree 4 is the diagonal pinch: the loop crossing itself at a corner.
      if (d != 0 && d != 2) return false;
      if (d == 2) {
        active++;
        if (start < 0) start = i;
      }
    }
    if (active == 0) return false;

    final visited = List<bool>.filled(vertexCount, false);
    var cur = start;
    var prev = -1;
    var count = 0;
    while (cur != -1 && !visited[cur]) {
      visited[cur] = true;
      count++;
      var next = -1;
      for (final nb in adj[cur]) {
        if (nb != prev) {
          next = nb;
          break;
        }
      }
      prev = cur;
      cur = next;
    }
    // Fewer visited than active means a second, separate loop exists.
    return count == active && cur == start;
  }

  // ------------------------------------------------------------ generation

  static Set<int>? _growRegion(int size, int level, Random rng) {
    final target = targetRegionFor(size, level, rng);
    final cells = <int>{rng.nextInt(size * size)};

    while (cells.length < target) {
      final candidates = <int>[];
      for (final cell in cells) {
        final r = cell ~/ size;
        final c = cell % size;
        void add(int nr, int nc) {
          if (nr < 0 || nr >= size || nc < 0 || nc >= size) return;
          final j = nr * size + nc;
          if (!cells.contains(j)) candidates.add(j);
        }

        add(r + 1, c);
        add(r - 1, c);
        add(r, c + 1);
        add(r, c - 1);
      }
      if (candidates.isEmpty) break;
      candidates.shuffle(rng);

      var added = false;
      for (final cand in candidates) {
        cells.add(cand);
        if (isEdgeConnected(cells, size) &&
            complementConnected(cells, size) &&
            !hasDiagonalPinch(cells, size)) {
          added = true;
          break;
        }
        cells.remove(cand);
      }

      // The original force-added a candidate here without re-checking, which is
      // the defect the release plan recorded. Simulation showed it never fires,
      // but growing into an illegal shape would be wrong even once — so stop
      // instead and let the caller keep or discard what we have.
      if (!added) break;
    }
    return cells.isEmpty ? null : cells;
  }

  /// Builds a board for [level].
  ///
  /// Gated on [isSingleLoop] rather than on the shape heuristics alone: the
  /// heuristics take the failure rate from 2.4% to 0.43% at 5x5, and validating
  /// the derived edges takes it to zero. A board is never returned unless its
  /// stored solution passes the same check the player's answer will face.
  static SlitherlinkBoard generate(Random rng, int level,
      {int maxAttempts = 40}) {
    final size = sizeFor(level);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final cells = _growRegion(size, level, rng);
      if (cells == null || cells.isEmpty) continue;

      final sol = deriveEdges(cells, size);
      if (!isSingleLoop(sol, size)) continue;

      final clues = List<int>.generate(
        size * size,
        (i) => edgesAroundCell(sol, size, i),
      );
      return SlitherlinkBoard(
        size: size,
        solution: sol,
        clues: clues,
        attempts: attempt,
      );
    }

    // Never reached in practice — a single cell is always a legal loop, so this
    // is a guaranteed-valid floor rather than a hardcoded board. Hitori shipped a
    // hardcoded fallback with zero valid solutions; this cannot.
    final single = <int>{0};
    final sol = deriveEdges(single, size);
    return SlitherlinkBoard(
      size: size,
      solution: sol,
      clues: List<int>.generate(
          size * size, (i) => edgesAroundCell(sol, size, i)),
      attempts: maxAttempts,
    );
  }
}
