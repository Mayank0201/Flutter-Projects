import 'dart:math';

/// Pure Untangle logic — no Flutter imports, so it is unit-testable.
///
/// Built for release 2.2 from `md/cogniq_builders_handbook.md` §B1. **The
/// handbook's generator was measured before anything was built on it**, over
/// 4,000 boards. Its central claim holds and four other things did not:
///
/// | Property | Handbook result |
/// |---|---|
/// | solved layout is crossing-free (planar by construction) | **0 failures in 4,000** ✅ |
/// | dealt board is already solved | **54% at level 1**, 48% at level 5 ❌ |
/// | two nodes overlap on the scramble circle | 87% at level 16, **99% at level 24+** ❌ |
/// | a node has no edges at all | 6–10% at every level ❌ |
/// | difficulty keeps climbing | flat from level 24 ❌ |
///
/// So the planar-by-construction idea is kept exactly as written — it is the
/// part that makes every board guaranteed solvable — and the scramble, the
/// acceptance gate and the edge pass are all replaced.
///
/// The overlap defect was the worst of the four. `nodes` was scrambled with
/// `rng.nextDouble() * 2 * pi` per node, and random angles clump: by the
/// birthday problem, 25 nodes on one circle almost always puts two of them on
/// top of each other, and two overlapping nodes cannot be told apart or dragged
/// independently. [_scramble] spaces them evenly and shuffles *which* node goes
/// to which slot, so the tangle stays random while separation is guaranteed.
class Edge {
  final int a, b;
  const Edge(this.a, this.b);

  bool touches(Edge other) =>
      a == other.a || a == other.b || b == other.a || b == other.b;

  @override
  bool operator ==(Object other) =>
      other is Edge && ((a == other.a && b == other.b) || (a == other.b && b == other.a));

  @override
  int get hashCode => Object.hash(min(a, b), max(a, b));
}

/// A generated board. [nodes] is what the player sees and drags; [solved] is a
/// layout known to have zero crossings, used for the hint.
class UntangleBoard {
  final int side;
  final List<Point<double>> nodes;
  final List<Point<double>> solved;
  final List<Edge> edges;

  /// Crossings present in the dealt layout. Recorded so tests can assert the
  /// board was actually tangled when it was handed over.
  final int dealtCrossings;

  final int attempts;

  const UntangleBoard({
    required this.side,
    required this.nodes,
    required this.solved,
    required this.edges,
    required this.dealtCrossings,
    required this.attempts,
  });

  int get nodeCount => solved.length;
}

class UntangleLogic {
  /// Grid side. Starts at 3, not the handbook's 2.
  ///
  /// A side of 2 is four nodes and about four edges, and **half of those boards
  /// are already untangled when dealt** — the player would open level 1 of a
  /// brand-new game and find it won. Three-by-three is still a gentle on-ramp
  /// and is a real puzzle.
  static int sideFor(int level) {
    if (level < 6) return 3;
    if (level < 14) return 4;
    return 5;
  }

  /// How tangled a board must be before it is worth dealing.
  ///
  /// This is the acceptance gate that stops a pre-solved board shipping. Be
  /// honest about what it is *not*: measured over 4,000 boards it almost never
  /// binds — level 16 asks for 7 crossings and a circle scramble delivers ~322 —
  /// so it is a **floor**, not the difficulty curve. The curve past the
  /// [sideFor] plateau is carried by [diagonalChanceFor] and by modifiers.
  static int minCrossingsFor(int level) {
    final base = sideFor(level);
    final floor = base; // 3, 4 or 5 crossings just to be a puzzle
    final climb = (level ~/ 6).clamp(0, 10);
    return floor + climb;
  }

  /// Chance of a diagonal in any given cell, by level.
  ///
  /// This is the real difficulty lever once [sideFor] plateaus at 5 from level
  /// 14. More diagonals means a denser graph, which means more crossings to
  /// resolve and fewer free choices about where a node can go. Only ever **one**
  /// diagonal per cell, so raising this cannot break planarity.
  static double diagonalChanceFor(int level) =>
      (0.25 + level * 0.006).clamp(0.25, 0.70);

  // ------------------------------------------------------------- geometry

  /// Proper segment crossing. Shared endpoints do not count, and neither does a
  /// merely collinear touch — only a genuine X.
  static bool segmentsCross(
      Point<double> p1, Point<double> p2, Point<double> p3, Point<double> p4) {
    double d(Point<double> a, Point<double> b, Point<double> c) =>
        (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
    final d1 = d(p3, p4, p1), d2 = d(p3, p4, p2);
    final d3 = d(p1, p2, p3), d4 = d(p1, p2, p4);
    return ((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0));
  }

  /// Indices of every edge involved in at least one crossing, for [pts].
  ///
  /// O(E^2). At the largest board that is 1,326 pair tests, which is fine once
  /// per move but must not be called repeatedly inside `build` — the screen
  /// caches the result and recomputes only when a node actually moves.
  static Set<int> crossingEdges(
      List<Edge> edges, List<Point<double>> pts) {
    final bad = <int>{};
    for (var i = 0; i < edges.length; i++) {
      for (var j = i + 1; j < edges.length; j++) {
        if (edges[i].touches(edges[j])) continue;
        if (segmentsCross(pts[edges[i].a], pts[edges[i].b], pts[edges[j].a],
            pts[edges[j].b])) {
          bad..add(i)..add(j);
        }
      }
    }
    return bad;
  }

  /// Number of crossing *pairs* — the figure shown to the player.
  static int crossingCount(List<Edge> edges, List<Point<double>> pts) {
    var n = 0;
    for (var i = 0; i < edges.length; i++) {
      for (var j = i + 1; j < edges.length; j++) {
        if (edges[i].touches(edges[j])) continue;
        if (segmentsCross(pts[edges[i].a], pts[edges[i].b], pts[edges[j].a],
            pts[edges[j].b])) {
          n++;
        }
      }
    }
    return n;
  }

  static bool isSolved(List<Edge> edges, List<Point<double>> pts) =>
      crossingEdges(edges, pts).isEmpty;

  // ------------------------------------------------------------ generation

  /// The planar layout: a jittered grid. Kept from the handbook unchanged —
  /// measurement confirmed it never produces a crossing.
  static List<Point<double>> _planarLayout(int side, Random rng) {
    final pts = <Point<double>>[];
    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        pts.add(Point(
          (c + 0.5) / side + (rng.nextDouble() - 0.5) * 0.4 / side,
          (r + 0.5) / side + (rng.nextDouble() - 0.5) * 0.4 / side,
        ));
      }
    }
    return pts;
  }

  /// Grid-neighbour edges, plus at most one diagonal per cell.
  ///
  /// Two diagonals in the same cell would cross each other in the *solved*
  /// layout, which would make the board unwinnable — hence the `else`, which is
  /// the handbook's and is correct.
  ///
  /// Unlike the handbook this then **repairs isolated nodes**: with an
  /// independent 0.85 roll per edge, 6–10% of boards contained a node with no
  /// edges at all. Such a node is draggable but meaningless — it can never be
  /// part of a crossing, so nothing the player does to it matters.
  static List<Edge> _buildEdges(int side, Random rng, int level) {
    int id(int r, int c) => r * side + c;
    final edges = <Edge>[];

    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        if (c + 1 < side && rng.nextDouble() < 0.85) {
          edges.add(Edge(id(r, c), id(r, c + 1)));
        }
        if (r + 1 < side && rng.nextDouble() < 0.85) {
          edges.add(Edge(id(r, c), id(r + 1, c)));
        }
        if (c + 1 < side && r + 1 < side) {
          final chance = diagonalChanceFor(level);
          if (rng.nextDouble() < chance) {
            edges.add(Edge(id(r, c), id(r + 1, c + 1)));
          } else if (rng.nextDouble() < chance) {
            edges.add(Edge(id(r, c + 1), id(r + 1, c)));
          }
        }
      }
    }

    // Repair pass: connect any node that ended up with no edges to a grid
    // neighbour. A grid-neighbour edge can never cross in the solved layout, so
    // this cannot break planarity.
    final degree = List<int>.filled(side * side, 0);
    for (final e in edges) {
      degree[e.a]++;
      degree[e.b]++;
    }
    for (var i = 0; i < side * side; i++) {
      if (degree[i] != 0) continue;
      final r = i ~/ side, c = i % side;
      final candidates = <int>[
        if (c + 1 < side) id(r, c + 1),
        if (c - 1 >= 0) id(r, c - 1),
        if (r + 1 < side) id(r + 1, c),
        if (r - 1 >= 0) id(r - 1, c),
      ];
      final pick = candidates[rng.nextInt(candidates.length)];
      edges.add(Edge(i, pick));
      degree[i]++;
      degree[pick]++;
    }
    return edges;
  }

  /// Scatter the nodes around a circle so the board reads as a tangle.
  ///
  /// Slots are **evenly spaced and then shuffled**, rather than each node taking
  /// an independent random angle. Independent angles were the handbook's
  /// approach and they clump: two nodes landed within 2% of the board's width of
  /// each other on **99% of boards at level 24+**, and two nodes drawn on top of
  /// one another cannot be told apart or dragged separately.
  ///
  /// Shuffling which node occupies which slot keeps the tangle just as random —
  /// the randomness that matters is the *assignment*, not the spacing.
  static List<Point<double>> _scramble(int count, Random rng) {
    final slots = List<int>.generate(count, (i) => i)..shuffle(rng);
    final step = 2 * pi / count;
    // Enough jitter to stop the ring looking mechanical, capped at a third of a
    // slot so neighbours can never swap places or touch.
    final jitter = step / 3;
    return List<Point<double>>.generate(count, (i) {
      final angle = slots[i] * step + (rng.nextDouble() - 0.5) * jitter;
      final radius = 0.40 + (rng.nextDouble() - 0.5) * 0.06;
      return Point(0.5 + radius * cos(angle), 0.5 + radius * sin(angle));
    });
  }

  /// Builds a board for [level].
  ///
  /// Gated on two things, both measured rather than assumed:
  ///
  ///  1. the **solved** layout has zero crossings — the same predicate the win
  ///     check uses, so a board can never be dealt that cannot be won; and
  ///  2. the **dealt** layout has at least [minCrossingsFor] crossings, so the
  ///     player is never handed a puzzle that is already finished. Half of the
  ///     handbook's level-1 boards were.
  static UntangleBoard generate(Random rng, int level, {int maxAttempts = 60}) {
    final side = sideFor(level);
    final want = minCrossingsFor(level);

    List<Point<double>>? bestNodes;
    List<Point<double>>? bestSolved;
    List<Edge>? bestEdges;
    var bestCrossings = -1;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final solved = _planarLayout(side, rng);
      final edges = _buildEdges(side, rng, level);

      // The board must be winnable. This is by construction, but construction
      // is an argument and this is a check — Hitori shipped a fallback whose
      // stored answer was illegal on 96% of boards because nobody checked.
      if (!isSolved(edges, solved)) continue;

      final nodes = _scramble(solved.length, rng);
      final crossings = crossingCount(edges, nodes);

      if (crossings >= want) {
        return UntangleBoard(
          side: side,
          nodes: nodes,
          solved: solved,
          edges: edges,
          dealtCrossings: crossings,
          attempts: attempt,
        );
      }

      // Keep the most tangled near-miss rather than throwing it away.
      if (crossings > bestCrossings) {
        bestCrossings = crossings;
        bestNodes = nodes;
        bestSolved = solved;
        bestEdges = edges;
      }
    }

    // Fallback. Note what it is NOT: it is not a hardcoded board and not a
    // near-miss relabelled as good. It is the most tangled board actually seen,
    // and it is still asserted to be winnable and still asserted to have at
    // least one crossing before it is returned. If even that is unavailable the
    // caller gets an exception rather than a fake puzzle — a generator that
    // cannot generate must fail loudly, not deal something broken.
    if (bestNodes != null && bestCrossings > 0) {
      return UntangleBoard(
        side: side,
        nodes: bestNodes,
        solved: bestSolved!,
        edges: bestEdges!,
        dealtCrossings: bestCrossings,
        attempts: maxAttempts,
      );
    }
    throw StateError(
        'Untangle: no tangled board for level $level in $maxAttempts attempts');
  }
}
