import 'dart:collection';
import 'dart:math';

/// Pure Hitori logic — no Flutter imports, so it is unit-testable.
///
/// Extracted from `hitori_screen.dart` on 2026-08-22 while fixing three defects
/// that made the game unplayable. See `md/RELEASE_PLAN.md` §4.2A.
///
/// **Rules.** Shade cells so that: (1) no two shaded cells are orthogonally
/// adjacent, (2) no value repeats among the unshaded cells of any row or column,
/// and (3) all unshaded cells form one orthogonally-connected group.
class HitoriBoard {
  final int size;

  /// The number printed in each cell.
  final List<int> values;

  /// The shading the generator intends. Guaranteed to satisfy all three rules —
  /// see the note on `_populate` for why that guarantee did not hold before.
  final List<bool> solution;

  /// Solutions found by the bounded search: 1 = unique, 2 = at least two,
  /// -1 = the budget ran out before it could tell.
  final int solutionCount;

  final int attempts;

  const HitoriBoard({
    required this.size,
    required this.values,
    required this.solution,
    required this.solutionCount,
    required this.attempts,
  });

  bool get isUnique => solutionCount == 1;
}

class HitoriLogic {
  /// 4x4 to level 5, 6x6 to level 12, 8x8 after. Unchanged from the original.
  static int sizeFor(int level) => level < 5 ? 4 : (level < 12 ? 6 : 8);

  /// Fraction of cells the generator tries to shade. Rises gently with level so
  /// later boards need more deductions; the mask builder enforces the rules, so
  /// a higher number just means "try harder", never "produce something illegal".
  static double shadeDensityFor(int level) =>
      (0.18 + level * 0.002).clamp(0.18, 0.30);

  // --------------------------------------------------------------- rules

  static bool hasAdjacentShaded(List<bool> mask, int size, int idx) {
    final r = idx ~/ size;
    final c = idx % size;
    if (r > 0 && mask[idx - size]) return true;
    if (r + 1 < size && mask[idx + size]) return true;
    if (c > 0 && mask[idx - 1]) return true;
    if (c + 1 < size && mask[idx + 1]) return true;
    return false;
  }

  static bool isConnected(List<bool> mask, int size) {
    final n = size * size;
    var start = -1;
    var whites = 0;
    for (var i = 0; i < n; i++) {
      if (!mask[i]) {
        whites++;
        if (start < 0) start = i;
      }
    }
    if (start < 0) return false; // everything shaded is not a board

    final seen = List<bool>.filled(n, false);
    seen[start] = true;
    var found = 1;
    final q = Queue<int>()..add(start);
    while (q.isNotEmpty) {
      final i = q.removeFirst();
      final r = i ~/ size;
      final c = i % size;
      void visit(int j) {
        if (!mask[j] && !seen[j]) {
          seen[j] = true;
          found++;
          q.add(j);
        }
      }

      if (r > 0) visit(i - size);
      if (r + 1 < size) visit(i + size);
      if (c > 0) visit(i - 1);
      if (c + 1 < size) visit(i + 1);
    }
    return found == whites;
  }

  /// All three rules. This is exactly what the screen's win check tests, so a
  /// board is winnable iff some mask satisfies this.
  static bool satisfiesRules(List<int> values, List<bool> mask, int size) {
    for (var i = 0; i < mask.length; i++) {
      if (mask[i] && hasAdjacentShaded(mask, size, i)) return false;
    }
    for (var r = 0; r < size; r++) {
      final seen = <int>{};
      for (var c = 0; c < size; c++) {
        final i = r * size + c;
        if (mask[i]) continue;
        if (!seen.add(values[i])) return false;
      }
    }
    for (var c = 0; c < size; c++) {
      final seen = <int>{};
      for (var r = 0; r < size; r++) {
        final i = r * size + c;
        if (mask[i]) continue;
        if (!seen.add(values[i])) return false;
      }
    }
    return isConnected(mask, size);
  }

  // ---------------------------------------------------------- generation

  /// A Latin square: every row *and every column* is a permutation of 1..size.
  ///
  /// This is the fix for the generator's central bug. The old
  /// `_populateBoardValues` dealt a shuffled permutation **per row** and never
  /// constrained columns, so the mask it had just built was almost never a legal
  /// solution of the board it produced — measured at 99.2% illegal, and 96% of
  /// every board that shipped stored a wrong `_solution`. Because the win check
  /// is rule-based the player could still win, but the hint button is
  /// exact-match against the stored solution, so **one hint tap destroyed a
  /// winning board, charged for the privilege, and then reported success while
  /// the Check button disagreed.**
  ///
  /// Starting from a Latin square makes unshaded cells duplicate-free in both
  /// directions, so the mask is legal by construction.
  static List<int> latinSquare(int size, Random rng) {
    final base = List<int>.generate(size, (i) => i + 1)..shuffle(rng);
    final rowOrder = List<int>.generate(size, (i) => i)..shuffle(rng);
    final colShift = List<int>.generate(size, (i) => i)..shuffle(rng);

    final out = List<int>.filled(size * size, 0);
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        // Cyclic Latin square, then permute rows and columns so it does not look
        // mechanical.
        out[r * size + c] = base[(colShift[c] + rowOrder[r]) % size];
      }
    }
    return out;
  }

  /// A shading that already satisfies rules 1 and 3. Rule 2 is satisfied later
  /// by construction, because unshaded cells keep their Latin-square values.
  static List<bool> buildMask(int size, Random rng, double density) {
    final n = size * size;
    final mask = List<bool>.filled(n, false);
    final order = List<int>.generate(n, (i) => i)..shuffle(rng);

    for (final i in order) {
      if (rng.nextDouble() >= density) continue;
      if (hasAdjacentShaded(mask, size, i)) continue;
      mask[i] = true;
      if (!isConnected(mask, size)) mask[i] = false; // undo, keep the group whole
    }
    return mask;
  }

  /// Unshaded cells keep the Latin-square value. Shaded cells get a *duplicate*
  /// drawn from their own row or column, which is what gives the player
  /// something to deduce — the shaded cell is the one breaking the rule.
  static List<int> populate(
      List<int> latin, List<bool> mask, int size, Random rng) {
    final values = List<int>.from(latin);
    for (var i = 0; i < mask.length; i++) {
      if (!mask[i]) continue;
      final r = i ~/ size;
      final c = i % size;

      final candidates = <int>[];
      if (rng.nextBool()) {
        for (var x = 0; x < size; x++) {
          final j = r * size + x;
          if (j != i && !mask[j]) candidates.add(latin[j]);
        }
      } else {
        for (var y = 0; y < size; y++) {
          final j = y * size + c;
          if (j != i && !mask[j]) candidates.add(latin[j]);
        }
      }
      if (candidates.isNotEmpty) {
        values[i] = candidates[rng.nextInt(candidates.length)];
      }
    }
    return values;
  }

  // -------------------------------------------------------------- solver

  /// Cells that could possibly be shaded: only those whose value repeats
  /// somewhere in its own row or column.
  ///
  /// This is what makes the search tractable. The original enumerator branched
  /// on *every* cell and only checked the duplicate rule at the leaf, giving
  /// 5,744,650 nodes on a 6x6 — 31 seconds per call, run up to 100 times per
  /// level load, so opening Level 6 blocked the UI thread for 22 minutes. An
  /// 8x8 was ~4.6x10^11 nodes: months. Restricting the branch set to real
  /// candidates collapses that to a handful of cells.
  static List<int> shadeCandidates(List<int> values, int size) {
    final out = <int>[];
    for (var i = 0; i < values.length; i++) {
      final r = i ~/ size;
      final c = i % size;
      var dup = false;
      for (var x = 0; x < size && !dup; x++) {
        final j = r * size + x;
        if (j != i && values[j] == values[i]) dup = true;
      }
      for (var y = 0; y < size && !dup; y++) {
        final j = y * size + c;
        if (j != i && values[j] == values[i]) dup = true;
      }
      if (dup) out.add(i);
    }
    return out;
  }

  /// Counts rule-satisfying shadings, stopping at [maxSolutions] or when
  /// [budget] node visits are spent. Returns -1 if the budget ran out.
  static int countSolutions(
    List<int> values,
    int size, {
    int maxSolutions = 2,
    int budget = 300000,
  }) {
    final candidates = shadeCandidates(values, size);
    final mask = List<bool>.filled(size * size, false);
    var nodes = 0;
    var found = 0;
    var exhausted = false;

    void walk(int k) {
      if (exhausted || found >= maxSolutions) return;
      if (++nodes > budget) {
        exhausted = true;
        return;
      }
      if (k >= candidates.length) {
        if (satisfiesRules(values, mask, size)) found++;
        return;
      }
      final i = candidates[k];

      // leave it white
      walk(k + 1);
      if (exhausted || found >= maxSolutions) return;

      // or shade it, if that stays legal
      if (!hasAdjacentShaded(mask, size, i)) {
        mask[i] = true;
        walk(k + 1);
        mask[i] = false;
      }
    }

    walk(0);
    return exhausted ? -1 : found;
  }

  /// Builds a board for [level].
  ///
  /// Every returned board has a **legal** stored solution — asserted here, not
  /// hoped for. There is deliberately no hardcoded fallback: the original one
  /// had **zero** valid solutions (verified by exhaustive search over all 65,536
  /// masks) and was reached ~3% of the time at 4x4 and always at 6x6+, so it
  /// shipped an unwinnable board with no way out. If every attempt somehow
  /// failed, this drops the shade density rather than serving a dead grid.
  static HitoriBoard generate(Random rng, int level, {int? maxAttempts}) {
    final size = sizeFor(level);
    var density = shadeDensityFor(level);

    // Uniqueness is a QUALITY goal here, not a correctness one: the win check is
    // rule-based, so a board with a second legal shading is still winnable and
    // still fair. That matters for cost — hunting uniqueness on an 8x8 took 1.8s
    // per board, far too slow for the UI isolate, while a 4x4 finds one almost
    // immediately. So large boards get a few probes and then accept the first
    // legal board; small boards can afford to be picky.
    final attempts = maxAttempts ?? (size >= 8 ? 4 : (size >= 6 ? 12 : 40));

    HitoriBoard? fallback;

    for (var attempt = 0; attempt < attempts; attempt++) {
      final latin = latinSquare(size, rng);
      final mask = buildMask(size, rng, density);

      // A board with nothing shaded is not a puzzle.
      if (!mask.contains(true)) {
        density = (density + 0.03).clamp(0.18, 0.40);
        continue;
      }

      final values = populate(latin, mask, size, rng);

      // The guarantee that used to be missing.
      if (!satisfiesRules(values, mask, size)) continue;

      final count =
          countSolutions(values, size, budget: size >= 8 ? 60000 : 300000);
      final board = HitoriBoard(
        size: size,
        values: values,
        solution: mask,
        solutionCount: count,
        attempts: attempt,
      );
      if (count == 1) return board;
      fallback ??= board;
    }

    // Still solvable — `satisfiesRules` passed for every candidate kept here.
    // Uniqueness is a quality goal, not a correctness one: the win check is
    // rule-based, so a second legal shading still wins.
    return fallback ??
        _trivialBoard(size, rng);
  }

  /// Last resort: a board generated at minimum density, still rule-checked.
  /// Never a hardcoded grid.
  static HitoriBoard _trivialBoard(int size, Random rng) {
    for (var i = 0; i < 200; i++) {
      final latin = latinSquare(size, rng);
      final mask = buildMask(size, rng, 0.15);
      if (!mask.contains(true)) continue;
      final values = populate(latin, mask, size, rng);
      if (satisfiesRules(values, mask, size)) {
        return HitoriBoard(
          size: size,
          values: values,
          solution: mask,
          solutionCount: -1,
          attempts: 200,
        );
      }
    }
    // A Latin square with nothing shaded satisfies every rule trivially: no
    // adjacency, no duplicates, fully connected. Degenerate but never illegal.
    final latin = latinSquare(size, rng);
    return HitoriBoard(
      size: size,
      values: latin,
      solution: List<bool>.filled(size * size, false),
      solutionCount: 1,
      attempts: 200,
    );
  }
}
