# Further Masyu & Sum Strike Fixes — Generated Level Sets

> **Companion to** `masyu_sum_level_fix.md` (which holds Masyu L1–150 + the Sum Strike non-trivial-mask fix)
> and `difficulty_scaling_part_2_fix.md` (the scaling/rotation implementation plan).
> **Purpose:** this doc records the newly *generated, solver-verified* level data produced offline so it
> is not lost, and gives an implementing agent everything needed to wire it into the app.
>
> **Audience:** a reading agent (Gemini) to understand what exists, and a planning/coding agent (Opus) to wire it in.

---

## 0. TL;DR — what was generated

| Set | Count | Grid sizes | Guarantees | Status |
|-----|-------|-----------|-----------|--------|
| **Sum Strike** offline levels | **120** | 3×3 ×8, 4×4 ×8, 5×5 ×84, 6×6 ×20 (60 of them use negatives) | z3-verified **unique** + **non-trivial** + **no pre-satisfied line** (negatives can't cancel to a solved line) | ✅ **complete** (Appendix A) |
| **Masyu 8×8** (levels 151–180) | **30** | 8×8 | z3-verified **unique + distinct** | ✅ **complete** (Appendix B) |
| **Masyu 9×9** (levels 181–205) | up to 25 | 9×9 | z3-verified **unique + distinct** | ⏳ **generating** — Appendix C appended on completion |

All generation was crash-safe (full file rewritten after every level). Masyu L1–150 (50× 5×5, 50× 6×6, 50× 7×7)
already live in `masyu_sum_level_fix.md` §1.2 and in the app's `masyu_levels.dart`.

---

## 1. Why these were generated offline (not at runtime)

Both games' runtime generators had correctness holes that only a solver can close:

- **Masyu:** a Masyu puzzle is only well-posed if it has a **single unique** solution loop. Verifying that needs
  loop-enumeration / SAT, which is exponential and **must not run on the device** (it froze the app on level load —
  see `difficulty_scaling_part_2_fix.md` P0-2). Solution: pre-generate and verify offline with z3; the app just
  displays the pearls.
- **Sum Strike:** the runtime generator's fallback (after 50 attempts) shipped **non-unique** boards, and with
  negatives a line's struck cells can sum to 0, so an "all kept" start could already equal its target
  (the "already-solved columns" complaint). Pre-generating with z3 guarantees every line needs real work and the
  whole board has exactly one solution.

### Solver hardening note (important for anyone re-running generation)
The z3 uniqueness checker (`masyu_z3.py`) was patched so that a resource-starved `unknown` result is **never**
conflated with `unsat`. Previously, under CPU contention (multiple solver processes), z3 could return `unknown`,
which the old code read as "no solution" (false) or, on the second solve, as "unique" (a **false positive**).
Two rules now hold:
1. Run generation **single-process** (no parallel solvers) to avoid starving z3.
2. `unknown` → retry, never a verdict. Every emitted level is re-verified in isolation; anything that doesn't
   hold as genuinely unique is dropped and regenerated.

---

## 2. Sum Strike — data shape & wiring

Each generated record (Appendix A):

```dart
SumStrikeLevel(
  gridSize: 5,
  grid:       [ ...n*n ints, row-major... ],  // values 1..maxNum, negatives allowed on L61+
  solution:   [ ...n*n of 0/1... ],           // 1 = KEEP, 0 = STRIKE — the unique solution mask
  rowTargets: [ ...n ints... ],               // = sum of kept cells in each row
  colTargets: [ ...n ints... ],               // = sum of kept cells in each column
)
```

### 2.1 Add the model class

```dart
class SumStrikeLevel {
  final int gridSize;
  final List<int> grid;
  final List<int> solution;   // 1 = keep, 0 = strike
  final List<int> rowTargets;
  final List<int> colTargets;
  const SumStrikeLevel({
    required this.gridSize,
    required this.grid,
    required this.solution,
    required this.rowTargets,
    required this.colTargets,
  });
}

const List<SumStrikeLevel> kSumStrikeLevels = [
  // ...paste Appendix A here...
];
```

### 2.2 Wire into `sum_strike_screen.dart` → `_generatePuzzle`

Replace the risky runtime generate-and-verify loop **for levels covered by the fixed set**:

```dart
if (!_playDailyMode && _currentLevel < kSumStrikeLevels.length) {
  final lvl = kSumStrikeLevels[_currentLevel];
  _gridSize     = lvl.gridSize;
  _grid         = List<int>.from(lvl.grid);
  _rowTargets   = List<int>.from(lvl.rowTargets);
  _colTargets   = List<int>.from(lvl.colTargets);
  _solutionMask = lvl.solution.map((x) => x == 1).toList();
  _keep         = List<bool>.filled(_gridSize * _gridSize, true); // start: all kept
  // NO uniqueness solving needed — already z3-verified.
  return;
}
// else: fall through to procedural generation (endgame / rotation, L120+),
// keeping the non-trivial-mask gate AND extending it so negatives can't pre-satisfy a line.
```

This gives **guaranteed-unique, always-non-trivial** early/mid levels, and leaves procedural generation only for
the rotation endgame beyond the fixed set. It directly resolves `masyu_sum_level_fix.md` §2 for the shipped levels.

### 2.3 Requested visual (from feedback)
Tint the **target-sum row/column headers** a distinct colour so the targets read clearly (see
`difficulty_scaling_part_2_fix.md` §5.15).

---

## 3. Masyu 8×8 / 9×9 — extending L151–205

The app's `masyu_levels.dart` currently ends at L150 (5×5/6×6/7×7). The 8×8 block (Appendix B) becomes
**levels 151–180**; the 9×9 block (Appendix C, when complete) becomes **levels 181–205**.

### 3.1 Splice instructions
Append the Appendix B entries (then Appendix C) to the `kMasyuLevels` list in `masyu_levels.dart`, replacing any
old/ambiguous 8×8/9×9 entries that were flagged as non-unique. Renumber comments continuously (151, 152, …).
After splicing, the full set is **205 unique+distinct levels**: 50× 5×5, 50× 6×6, 50× 7×7, 30× 8×8, ~25× 9×9.

### 3.2 App-side requirement (from `difficulty_scaling_part_2_fix.md` P0-2)
The Masyu screen must **use these curated levels for normal play** and **never run a solver on level load**.
The current build bypasses L31–150 with a synchronous procedural generator that freezes the device — that must be
removed so the verified levels are actually shown, with the solver only invoked lazily on Hint.

---

## 4. Regeneration recipe (for the record)

Scripts live in the working scratchpad; z3 5.0.0 required (`pip install z3-solver`).

- **Sum Strike:** `python sumstrike_gen.py <seed>` → `sumstrike_levels_backup.dart` (fast, ~seconds; linear arithmetic).
- **Masyu N×N:** `python masyu_backup_n.py N COUNT LMIN LMAX PMIN PMAX SEED` → `masyu_{N}x{N}_backup.dart`
  (8×8 used `8 30 18 34 8 17 8080`; 9×9 used `9 25 22 42 9 19 9090`). Slow (loop-uniqueness), run **single-process**.
- **Resume/heal after interruption:** `python masyu_resume_n.py <same args>` — re-verifies existing entries in
  isolation, drops any that don't hold, and generates only the missing levels. Crash-safe.
- **Audit:** `python masyu_audit_backup.py N` reports per-level verdict + solution collisions.

---

## 5. Status & remaining work

- ✅ Sum Strike: 120 levels complete and verified (Appendix A).
- ✅ Masyu 8×8: 30 levels complete and verified (Appendix B, L151–180).
- ⏳ Masyu 9×9: generating single-process; Appendix C + this section updated on completion. (Note: if a
  pathological board fails its attempt budget it is skipped, so the set may finish at 24; a top-up run can fill to 25.)
- ⬜ Wiring: add `SumStrikeLevel` + `kSumStrikeLevels`, load fixed Sum Strike levels; splice Masyu 151–205 and
  remove the on-load Masyu solver (P0-2). Tracked in `difficulty_scaling_part_2_fix.md`.

---

## Appendix A — Sum Strike (120 verified levels)

```dart
// SAFE BACKUP: 120 unique + non-trivial + no-presat Sum Strike levels (z3-verified)
  // #1 (3x3, 5 struck, unique)
  SumStrikeLevel(gridSize: 3, grid: [4, 6, 1, 1, 1, 1, 3, 1, 4], solution: [1, 0, 0, 1, 0, 1, 0, 1, 0], rowTargets: [4, 2, 1], colTargets: [5, 1, 1]),
  // #2 (3x3, 4 struck, unique)
  SumStrikeLevel(gridSize: 3, grid: [4, 1, 2, 6, 4, 6, 3, 5, 2], solution: [1, 1, 0, 0, 0, 1, 1, 0, 1], rowTargets: [5, 6, 5], colTargets: [7, 1, 8]),
  // #3 (3x3, 5 struck, unique)
  SumStrikeLevel(gridSize: 3, grid: [5, 4, 2, 6, 4, 2, 6, 1, 5], solution: [1, 0, 0, 0, 1, 1, 0, 1, 0], rowTargets: [5, 6, 1], colTargets: [5, 5, 2]),
  // #4 (3x3, 5 struck, unique)
  SumStrikeLevel(gridSize: 3, grid: [2, 5, 3, 1, 3, 5, 6, 5, 2], solution: [1, 0, 1, 0, 1, 0, 0, 0, 1], rowTargets: [5, 3, 2], colTargets: [2, 3, 5]),
  // #5 (3x3, 5 struck, unique)
  SumStrikeLevel(gridSize: 3, grid: [3, 6, 1, 5, 2, 4, 6, 5, 2], solution: [0, 1, 0, 1, 0, 0, 1, 0, 1], rowTargets: [6, 5, 8], colTargets: [11, 6, 2]),
  // #6 (3x3, 4 struck, unique)
  SumStrikeLevel(gridSize: 3, grid: [2, 4, 2, 5, 5, 3, 4, 6, 3], solution: [1, 0, 1, 1, 0, 1, 0, 1, 0], rowTargets: [4, 8, 6], colTargets: [7, 6, 5]),
  // #7 (3x3, 4 struck, unique)
  SumStrikeLevel(gridSize: 3, grid: [4, 2, 5, 1, 1, 4, 2, 2, 5], solution: [1, 1, 0, 1, 1, 0, 0, 0, 1], rowTargets: [6, 2, 5], colTargets: [5, 3, 5]),
  // #8 (3x3, 4 struck, unique)
  SumStrikeLevel(gridSize: 3, grid: [4, 4, 1, 2, 2, 6, 5, 1, 5], solution: [1, 0, 0, 1, 0, 1, 0, 1, 1], rowTargets: [4, 8, 6], colTargets: [6, 1, 11]),
  // #9 (4x4, 8 struck, unique)
  SumStrikeLevel(gridSize: 4, grid: [5, 6, 1, 5, 8, 6, 3, 1, 1, 4, 4, 5, 4, 3, 8, 4], solution: [0, 1, 1, 1, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1, 0, 0], rowTargets: [12, 1, 6, 7], colTargets: [5, 9, 1, 11]),
  // #10 (4x4, 8 struck, unique)
  SumStrikeLevel(gridSize: 4, grid: [8, 5, 6, 2, 8, 5, 4, 2, 5, 3, 4, 6, 6, 7, 2, 7], solution: [1, 0, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 0, 0, 0, 1], rowTargets: [10, 14, 7, 7], colTargets: [16, 3, 8, 11]),
  // #11 (4x4, 6 struck, unique)
  SumStrikeLevel(gridSize: 4, grid: [1, 7, 7, 2, 4, 5, 2, 8, 3, 3, 1, 8, 7, 4, 7, 7], solution: [0, 1, 1, 1, 1, 0, 0, 1, 0, 0, 1, 1, 1, 1, 1, 0], rowTargets: [16, 12, 9, 18], colTargets: [11, 11, 15, 18]),
  // #12 (4x4, 8 struck, unique)
  SumStrikeLevel(gridSize: 4, grid: [5, 5, 4, 8, 2, 4, 2, 7, 5, 2, 4, 1, 7, 3, 7, 2], solution: [1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 1, 1, 0], rowTargets: [9, 4, 6, 17], colTargets: [17, 7, 11, 1]),
  // #13 (4x4, 8 struck, unique)
  SumStrikeLevel(gridSize: 4, grid: [5, 4, 4, 6, 4, 2, 5, 2, 4, 5, 8, 7, 4, 3, 6, 1], solution: [0, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1], rowTargets: [4, 6, 9, 11], colTargets: [12, 11, 6, 1]),
  // #14 (4x4, 7 struck, unique)
  SumStrikeLevel(gridSize: 4, grid: [6, 6, 5, 3, 7, 7, 6, 6, 8, 1, 4, 5, 7, 5, 2, 1], solution: [0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 1, 0, 1], rowTargets: [11, 13, 13, 13], colTargets: [15, 18, 5, 12]),
  // #15 (4x4, 5 struck, unique)
  SumStrikeLevel(gridSize: 4, grid: [3, 6, 2, 3, 7, 2, 1, 2, 6, 2, 3, 3, 5, 4, 8, 4], solution: [0, 1, 1, 0, 1, 1, 0, 1, 1, 1, 0, 1, 1, 0, 1, 1], rowTargets: [8, 11, 11, 17], colTargets: [18, 10, 10, 9]),
  // #16 (4x4, 6 struck, unique)
  SumStrikeLevel(gridSize: 4, grid: [2, 1, 5, 8, 6, 4, 6, 6, 3, 3, 2, 7, 6, 5, 3, 6], solution: [0, 1, 0, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 0, 1, 0], rowTargets: [9, 16, 12, 9], colTargets: [15, 5, 5, 21]),
  // #17 (5x5, 13 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [7, 9, 5, 7, 9, 1, 1, 8, 2, 1, 7, 2, 7, 9, 9, 6, 6, 6, 2, 6, 4, 2, 10, 9, 7], solution: [1, 1, 1, 0, 0, 0, 1, 0, 0, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0], rowTargets: [21, 2, 25, 12, 2], colTargets: [20, 14, 18, 9, 1]),
  // #18 (5x5, 15 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [5, 5, 10, 7, 6, 5, 8, 6, 1, 6, 4, 10, 8, 10, 10, 5, 2, 4, 8, 9, 5, 8, 1, 1, 3], solution: [0, 1, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 1, 0, 1], rowTargets: [22, 8, 4, 9, 12], colTargets: [9, 21, 15, 7, 3]),
  // #19 (5x5, 12 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [6, 7, 5, 10, 3, 5, 9, 4, 9, 8, 5, 1, 1, 5, 2, 9, 7, 5, 9, 6, 7, 4, 1, 10, 7], solution: [1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0], rowTargets: [14, 30, 2, 6, 15], colTargets: [6, 14, 11, 19, 17]),
  // #20 (5x5, 9 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [7, 3, 1, 4, 9, 7, 9, 6, 2, 10, 8, 1, 5, 9, 8, 9, 4, 8, 4, 7, 8, 2, 3, 6, 7], solution: [0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1], rowTargets: [13, 15, 18, 23, 16], colTargets: [15, 8, 18, 21, 23]),
  // #21 (5x5, 17 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [8, 7, 3, 4, 6, 4, 9, 5, 10, 9, 9, 10, 4, 4, 6, 2, 3, 6, 2, 4, 9, 9, 6, 9, 1], solution: [0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0], rowTargets: [4, 10, 19, 8, 9], colTargets: [9, 9, 6, 20, 6]),
  // #22 (5x5, 11 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [7, 9, 10, 8, 2, 3, 4, 8, 4, 6, 3, 5, 9, 8, 8, 4, 6, 2, 6, 1, 1, 8, 1, 3, 2], solution: [1, 1, 1, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1, 1, 1, 0, 0, 1], rowTargets: [26, 7, 20, 9, 11], colTargets: [14, 21, 21, 6, 11]),
  // #23 (5x5, 12 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [5, 8, 4, 11, 1, 10, 4, 5, 4, 4, 6, 9, 11, 6, 7, 9, 3, 5, 3, 7, 7, 5, 7, 11, 4], solution: [0, 1, 0, 0, 1, 1, 1, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1], rowTargets: [9, 23, 16, 6, 22], colTargets: [17, 24, 5, 14, 16]),
  // #24 (5x5, 10 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [3, 7, 11, 9, 9, 10, 4, 4, 7, 3, 4, 2, 10, 2, 1, 11, 3, 5, 3, 11, 9, 5, 9, 10, 10], solution: [1, 1, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 1], rowTargets: [30, 4, 14, 28, 24], colTargets: [23, 17, 25, 5, 30]),
  // #25 (5x5, 14 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [3, 9, 8, 11, 10, 4, 5, 3, 11, 3, 11, 9, 1, 4, 3, 10, 11, 5, 2, 4, 2, 1, 9, 2, 3], solution: [0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 0, 1, 1, 0], rowTargets: [9, 9, 18, 14, 13], colTargets: [27, 14, 9, 6, 7]),
  // #26 (5x5, 12 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [5, 9, 9, 8, 10, 7, 10, 2, 11, 4, 7, 8, 8, 6, 7, 11, 10, 3, 3, 7, 7, 7, 1, 1, 10], solution: [0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1], rowTargets: [27, 17, 21, 13, 17], colTargets: [14, 10, 20, 17, 34]),
  // #27 (5x5, 13 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [3, 2, 6, 6, 8, 3, 9, 4, 11, 9, 8, 1, 4, 7, 6, 10, 1, 8, 2, 8, 1, 6, 6, 10, 2], solution: [1, 0, 0, 1, 0, 0, 1, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1], rowTargets: [9, 29, 8, 3, 19], colTargets: [12, 10, 6, 29, 11]),
  // #28 (5x5, 10 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [5, 11, 6, 9, 7, 11, 9, 1, 11, 5, 2, 4, 7, 9, 8, 10, 1, 11, 3, 6, 8, 7, 10, 9, 6], solution: [1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 0, 1, 0], rowTargets: [31, 26, 7, 22, 24], colTargets: [23, 28, 25, 29, 5]),
  // #29 (5x5, 13 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [10, 7, 8, 3, 12, 10, 7, 11, 10, 9, 4, 3, 3, 7, 2, 5, 9, 4, 12, 3, 10, 8, 8, 8, 7], solution: [0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 1, 0, 1, 1], rowTargets: [8, 18, 2, 28, 33], colTargets: [10, 24, 23, 20, 12]),
  // #30 (5x5, 11 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [2, 9, 6, 12, 1, 4, 10, 10, 5, 2, 2, 4, 7, 10, 7, 5, 5, 12, 10, 1, 5, 2, 11, 1, 5], solution: [0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 0], rowTargets: [15, 2, 28, 28, 18], colTargets: [10, 15, 36, 20, 10]),
  // #31 (5x5, 9 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [9, 8, 1, 9, 2, 5, 10, 4, 1, 9, 7, 10, 10, 11, 6, 7, 11, 9, 10, 12, 8, 12, 10, 7, 6], solution: [0, 0, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 0, 1, 0, 0, 1], rowTargets: [10, 28, 34, 40, 18], colTargets: [19, 43, 5, 30, 33]),
  // #32 (5x5, 13 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [3, 4, 8, 1, 9, 1, 4, 3, 12, 9, 9, 2, 6, 5, 5, 7, 9, 1, 4, 6, 1, 1, 11, 2, 2], solution: [1, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 0, 1, 0, 0, 1, 1, 0, 1, 0, 0], rowTargets: [12, 24, 13, 15, 12], colTargets: [4, 11, 20, 17, 24]),
  // #33 (5x5, 12 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [9, 11, 2, 12, 6, 6, 12, 7, 7, 3, 3, 7, 10, 4, 9, 7, 6, 9, 10, 7, 6, 7, 4, 9, 6], solution: [0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1], rowTargets: [12, 19, 19, 30, 28], colTargets: [13, 25, 10, 38, 22]),
  // #34 (5x5, 13 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [8, 1, 6, 12, 5, 1, 6, 4, 3, 10, 9, 4, 11, 6, 8, 9, 12, 5, 3, 3, 10, 4, 3, 2, 4], solution: [0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0], rowTargets: [19, 23, 8, 15, 12], colTargets: [10, 19, 10, 17, 21]),
  // #35 (5x5, 16 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [5, 4, 12, 4, 4, 9, 5, 1, 9, 7, 3, 1, 10, 4, 2, 10, 12, 13, 6, 6, 12, 11, 13, 1, 11], solution: [0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0], rowTargets: [4, 10, 13, 19, 1], colTargets: [9, 1, 24, 11, 2]),
  // #36 (5x5, 12 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [11, 12, 5, 8, 4, 4, 11, 2, 6, 2, 6, 7, 4, 3, 1, 7, 2, 11, 4, 3, 4, 9, 13, 7, 6], solution: [1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1], rowTargets: [16, 8, 14, 11, 22], colTargets: [21, 9, 22, 10, 9]),
  // #37 (5x5, 11 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [12, 7, 11, 4, 9, 3, 6, 7, 8, 6, 5, 13, 3, 1, 2, 1, 5, 9, 2, 7, 8, 13, 7, 8, 12], solution: [1, 1, 1, 1, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0], rowTargets: [34, 15, 16, 14, 23], colTargets: [20, 25, 34, 21, 2]),
  // #38 (5x5, 13 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [3, 12, 9, 1, 8, 12, 5, 6, 5, 4, 2, 6, 2, 6, 4, 5, 2, 12, 10, 7, 4, 8, 9, 12, 1], solution: [0, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 0, 1], rowTargets: [13, 11, 14, 9, 5], colTargets: [6, 19, 8, 7, 12]),
  // #39 (5x5, 9 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [11, 13, 6, 5, 1, 7, 4, 12, 11, 5, 13, 11, 12, 2, 12, 4, 12, 7, 11, 10, 4, 8, 1, 7, 9], solution: [0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1, 1, 0, 1, 1, 0, 1, 0], rowTargets: [12, 34, 25, 34, 19], colTargets: [28, 24, 37, 34, 1]),
  // #40 (5x5, 14 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [12, 12, 8, 4, 8, 6, 8, 13, 10, 13, 9, 3, 9, 12, 11, 6, 1, 8, 7, 11, 2, 3, 6, 13, 10], solution: [0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0, 0, 1], rowTargets: [16, 10, 29, 15, 15], colTargets: [11, 3, 25, 17, 29]),
  // #41 (5x5, 13 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [3, 3, 14, 8, 12, 10, 2, 3, 12, 9, 11, 12, 4, 8, 6, 7, 4, 4, 12, 1, 9, 14, 6, 3, 1], solution: [1, 1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 1, 1, 1, 0, 1, 0, 0], rowTargets: [26, 9, 26, 13, 15], colTargets: [12, 15, 6, 28, 28]),
  // #42 (5x5, 12 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [6, 9, 6, 5, 10, 10, 9, 7, 9, 9, 3, 7, 1, 1, 13, 9, 13, 13, 13, 3, 14, 2, 13, 5, 13], solution: [1, 0, 1, 0, 1, 1, 1, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 1], rowTargets: [22, 19, 11, 35, 15], colTargets: [28, 31, 19, 1, 23]),
  // #43 (5x5, 14 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [12, 5, 10, 2, 13, 14, 11, 6, 5, 14, 6, 11, 1, 1, 8, 1, 5, 1, 9, 12, 11, 3, 8, 1, 13], solution: [1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1], rowTargets: [12, 5, 26, 15, 24], colTargets: [29, 16, 2, 14, 21]),
  // #44 (5x5, 10 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [2, 12, 6, 13, 7, 7, 4, 11, 11, 11, 5, 12, 8, 9, 14, 10, 1, 6, 11, 1, 14, 5, 14, 7, 10], solution: [0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 1], rowTargets: [26, 26, 27, 22, 31], colTargets: [15, 5, 39, 42, 31]),
  // #45 (5x5, 13 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [5, 14, 1, 8, 2, 11, 13, 4, 9, 12, 3, 3, 11, 5, 14, 12, 8, 1, 14, 13, 6, 9, 3, 1, 11], solution: [0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0], rowTargets: [3, 32, 8, 23, 7], colTargets: [17, 11, 2, 29, 14]),
  // #46 (5x5, 13 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [14, 5, 4, 10, 3, 14, 7, 5, 11, 9, 9, 10, 10, 6, 11, 14, 5, 9, 4, 1, 9, 4, 5, 4, 6], solution: [0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 1, 0], rowTargets: [4, 30, 16, 20, 13], colTargets: [28, 16, 19, 10, 10]),
  // #47 (5x5, 16 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [3, 13, 9, 13, 12, 7, 9, 9, 2, 9, 4, 7, 7, 4, 12, 7, 13, 10, 8, 11, 2, 10, 3, 3, 2], solution: [0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 1], rowTargets: [9, 16, 14, 8, 15], colTargets: [7, 17, 16, 11, 11]),
  // #48 (5x5, 13 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [5, 2, 10, 14, 8, 5, 7, 2, 6, 8, 4, 1, 11, 10, 2, 14, 13, 12, 3, 6, 11, 3, 8, 7, 11], solution: [1, 1, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0], rowTargets: [25, 11, 15, 26, 3], colTargets: [28, 6, 22, 16, 8]),
  // #49 (5x5, 15 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [14, 1, 9, 3, 7, 2, 1, 12, 11, 6, 11, 4, 4, 12, 1, 9, 1, 12, 4, 4, 2, 14, 9, 11, 2], solution: [1, 0, 0, 0, 1, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0], rowTargets: [21, 20, 12, 10, 20], colTargets: [25, 1, 21, 23, 13]),
  // #50 (5x5, 15 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [9, 4, 10, 1, 6, 8, 2, 3, 13, 3, 1, 11, 1, 12, 13, 2, 4, 6, 9, 11, 5, 1, 6, 4, 9], solution: [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1], rowTargets: [1, 3, 26, 9, 18], colTargets: [6, 11, 4, 14, 22]),
  // #51 (5x5, 12 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [3, 6, 9, 10, 1, 14, 3, 1, 14, 11, 2, 2, 2, 5, 5, 12, 12, 5, 14, 1, 8, 6, 5, 14, 3], solution: [0, 0, 1, 1, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1], rowTargets: [19, 28, 7, 27, 23], colTargets: [16, 21, 9, 43, 15]),
  // #52 (5x5, 16 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [10, 1, 7, 5, 8, 8, 12, 11, 7, 8, 13, 3, 3, 2, 8, 12, 3, 5, 10, 8, 11, 2, 4, 11, 8], solution: [0, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1], rowTargets: [1, 26, 15, 5, 19], colTargets: [13, 1, 16, 20, 16]),
  // #53 (5x5, 13 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [8, 13, 7, 8, 12, 10, 12, 12, 11, 6, 5, 8, 6, 13, 9, 14, 7, 13, 6, 5, 1, 4, 9, 4, 7], solution: [1, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0], rowTargets: [28, 16, 19, 5, 17], colTargets: [23, 12, 15, 12, 23]),
  // #54 (5x5, 8 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [1, 13, 5, 9, 1, 7, 13, 4, 14, 4, 10, 14, 12, 5, 3, 7, 2, 10, 6, 7, 10, 9, 8, 5, 6], solution: [1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0], rowTargets: [20, 38, 25, 22, 14], colTargets: [25, 37, 21, 25, 11]),
  // #55 (5x5, 14 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [2, 11, 8, 1, 2, 2, 12, 14, 7, 14, 11, 8, 6, 5, 14, 13, 11, 13, 11, 3, 9, 8, 11, 12, 8], solution: [1, 1, 1, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 1, 0], rowTargets: [21, 26, 25, 13, 29], colTargets: [35, 31, 22, 12, 14]),
  // #56 (5x5, 9 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [6, 7, 7, 13, 8, 9, 10, 12, 9, 1, 2, 4, 12, 14, 8, 1, 9, 8, 3, 1, 4, 6, 3, 10, 9], solution: [0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 0, 1, 0, 1, 0, 1], rowTargets: [28, 22, 36, 18, 16], colTargets: [16, 16, 35, 27, 26]),
  // #57 (5x5, 13 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [12, 11, 4, 3, 1, 9, 4, 5, 6, 6, 3, 3, 14, 14, 1, 9, 2, 1, 8, 7, 11, 2, 13, 8, 3], solution: [1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0], rowTargets: [27, 26, 1, 17, 11], colTargets: [41, 11, 5, 17, 8]),
  // #58 (5x5, 13 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [13, 5, 2, 13, 14, 7, 10, 13, 10, 5, 9, 11, 1, 10, 4, 5, 13, 12, 12, 14, 5, 9, 11, 14, 9], solution: [1, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0, 0], rowTargets: [31, 15, 21, 31, 20], colTargets: [18, 35, 11, 35, 19]),
  // #59 (5x5, 12 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [6, 6, 12, 10, 7, 13, 14, 12, 3, 4, 7, 10, 12, 11, 9, 8, 11, 7, 13, 6, 10, 10, 11, 1, 9], solution: [0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 0, 1, 0], rowTargets: [29, 29, 26, 28, 1], colTargets: [15, 24, 31, 27, 16]),
  // #60 (5x5, 10 struck, unique)
  SumStrikeLevel(gridSize: 5, grid: [4, 1, 9, 3, 11, 14, 12, 11, 14, 7, 7, 2, 5, 3, 8, 8, 7, 12, 4, 6, 5, 11, 11, 5, 12], solution: [1, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 0, 1], rowTargets: [16, 21, 13, 31, 28], colTargets: [17, 20, 21, 24, 27]),
  // #61 (5x5, 12 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [13, 9, -11, 5, 10, 13, 10, -2, 7, 9, 5, 5, 13, 10, 11, 2, 2, 13, -11, 10, -6, 11, 1, 1, 6], solution: [0, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0], rowTargets: [8, 27, 26, 10, 12], colTargets: [18, 20, -12, 17, 40]),
  // #62 (5x5, 12 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [14, 7, 3, 1, 7, 8, 6, 4, 5, 1, 9, 1, 10, 14, 11, -12, 4, -7, 1, 10, 7, 11, 7, -8, 11], solution: [0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1], rowTargets: [10, 14, 35, 1, 36], colTargets: [15, 11, 20, 20, 30]),
  // #63 (5x5, 12 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [-4, 14, 8, 8, 6, 7, 8, 13, -5, 7, 2, 12, 1, 2, 7, 10, 1, 6, 10, 12, 9, 5, 12, 13, 10], solution: [0, 0, 1, 0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 1], rowTargets: [14, 22, 17, 1, 28], colTargets: [9, 26, 9, 15, 23]),
  // #64 (5x5, 10 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [2, 13, 12, 10, 10, 10, -6, 1, 9, 11, 11, 2, 9, 8, 9, 8, -9, 7, 7, 13, 2, 2, 9, -13, -3], solution: [1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1], rowTargets: [15, 15, 28, 22, 8], colTargets: [23, 7, 17, 24, 17]),
  // #65 (5x5, 9 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [2, -5, 8, 6, 6, 9, -9, 4, 13, 3, -4, 13, 2, 6, 5, 12, 9, 8, 7, -4, 14, -11, 4, 6, 3], solution: [0, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0], rowTargets: [9, 16, 9, 19, 9], colTargets: [31, -25, 10, 32, 14]),
  // #66 (5x5, 12 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [14, 1, 8, -4, 8, 10, 10, 7, 4, 4, 11, 3, -13, 3, 11, 13, -13, 1, -6, 14, 14, 5, 11, 5, 1], solution: [1, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1], rowTargets: [18, 25, -13, 0, 11], colTargets: [37, -8, -6, 5, 13]),
  // #67 (5x5, 11 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [9, 12, 3, -3, -6, 5, -6, 11, 13, 11, 8, 11, -6, 10, 2, 8, -2, 3, 7, 1, 11, 8, -1, 6, 4], solution: [0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 0, 1, 1, 0, 1], rowTargets: [-3, 7, 4, 9, 11], colTargets: [8, 0, -1, 20, 1]),
  // #68 (5x5, 13 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [-11, 14, 11, 4, 1, 10, -13, -7, 10, -8, 2, -11, 13, 11, 9, -14, 7, 7, 13, 9, 4, 11, 9, 14, -9], solution: [0, 1, 0, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 0, 0], rowTargets: [15, 0, -9, -7, 15], colTargets: [2, 1, 0, 10, 1]),
  // #69 (5x5, 12 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [10, 8, -9, -9, 9, 10, 12, 7, -4, 7, 8, 8, -9, 1, -1, 12, -14, 9, 12, 13, 10, 2, 3, 7, 3], solution: [1, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0], rowTargets: [1, -4, -10, 20, 12], colTargets: [20, -12, -9, -1, 21]),
  // #70 (5x5, 14 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [5, -6, 14, 5, 3, 13, 3, -5, 7, 1, -11, 3, 9, 14, 8, 10, 10, -6, 2, 13, 12, 8, 6, 9, 5], solution: [1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 0, 1], rowTargets: [22, 7, 17, 4, 23], colTargets: [17, 10, 23, 7, 16]),
  // #71 (5x5, 14 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [12, 11, 1, 2, 13, 14, 6, 6, -12, 4, 14, -3, 4, 12, -8, 2, 6, 3, -5, 7, -1, 3, 10, 10, 8], solution: [1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1], rowTargets: [36, 14, 6, 2, 28], colTargets: [40, 11, 10, 5, 20]),
  // #72 (5x5, 11 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [9, 13, 9, -7, 2, -4, 3, 11, -8, 6, 2, 3, 12, 1, 6, 9, 2, 12, 9, 7, 8, 13, -10, 1, 10], solution: [1, 1, 1, 0, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 1, 1, 1, 1], rowTargets: [33, 9, 6, 14, 14], colTargets: [9, 28, 22, -7, 24]),
  // #73 (5x5, 11 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [11, 5, 12, -14, 5, 6, 11, 10, 12, 11, 8, 11, 12, 5, 9, -8, 9, 8, 13, 9, -1, 7, 12, 11, 7], solution: [0, 1, 1, 1, 0, 1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 1], rowTargets: [3, 28, 5, 39, 13], colTargets: [5, 21, 30, 16, 16]),
  // #74 (5x5, 12 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [9, -11, 9, 13, 13, 10, -7, -8, 11, 9, -12, 1, -8, 14, -13, 8, 12, 10, 3, 12, 11, 5, 6, 6, 13], solution: [0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 0, 0, 1, 1, 1, 0, 1, 0, 0, 1], rowTargets: [-2, 14, 3, 25, 18], colTargets: [-2, -12, 19, 28, 25]),
  // #75 (5x5, 15 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [2, 3, -10, -4, -6, 11, 3, 5, 1, 2, 6, 1, 10, 4, -1, 3, 8, 14, -13, 7, 12, 8, 8, 8, 9], solution: [0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1], rowTargets: [-3, 2, 15, -5, 17], colTargets: [6, 11, 18, -13, 4]),
  // #76 (5x5, 15 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [8, 4, 2, 5, 10, 7, 13, 13, 7, 9, 4, 6, -6, 6, 7, 2, -2, -2, 6, 3, -6, 8, 14, 11, 11], solution: [0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1], rowTargets: [5, 22, 6, -2, 36], colTargets: [2, -2, 25, 22, 20]),
  // #77 (5x5, 11 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [11, 1, 5, -1, -9, 8, -14, 10, 13, 8, -2, 14, -6, 8, -6, -9, 7, 10, 12, -2, 14, 14, 9, 13, 12], solution: [1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 0, 0, 0, 1, 1, 0, 1, 1, 1], rowTargets: [2, -1, -6, -11, 48], colTargets: [14, -14, 3, 34, -5]),
  // #78 (5x5, 15 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [3, 11, -10, 11, 8, 4, -14, -13, 5, 12, 4, 7, 1, 9, 8, 7, 10, 5, 5, 6, -6, 12, -2, 5, -5], solution: [1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 0], rowTargets: [14, -1, 8, 16, 3], colTargets: [3, 17, -14, 16, 18]),
  // #79 (5x5, 11 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [12, 8, 7, 6, 4, 12, 8, 7, -13, 6, 6, 13, 1, 7, 9, 10, -14, 1, 9, 11, -1, 12, 7, 12, -6], solution: [1, 1, 1, 1, 0, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 1, 0, 1], rowTargets: [33, 2, 6, 21, 13], colTargets: [18, 28, 22, 2, 5]),
  // #80 (5x5, 10 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [12, 3, 5, 1, 10, 5, 10, 4, 13, 11, 1, 3, 11, -13, -3, 5, 13, 7, 11, 9, 2, 6, 13, 11, -13], solution: [1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1, 1], rowTargets: [26, 33, 12, 18, 0], colTargets: [20, 3, 22, 36, 8]),
  // #81 (5x5, 15 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [3, -5, -14, -8, 9, 14, 7, -11, 5, 9, 12, -13, 10, 6, 11, 13, 8, 1, -11, 2, 5, 3, 5, 12, 11], solution: [0, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 0], rowTargets: [-14, 12, 17, 11, 5], colTargets: [14, 8, -19, 6, 22]),
  // #82 (5x5, 13 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [5, 5, 8, 11, 3, -4, 8, 5, 15, 3, 5, 12, 6, 10, 3, 13, 15, 15, 5, -10, 4, -7, -10, 11, 2], solution: [0, 1, 0, 1, 0, 1, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 1, 0, 0, 0, 1, 0, 1], rowTargets: [16, 9, 9, 33, -8], colTargets: [9, 13, 16, 16, 5]),
  // #83 (5x5, 16 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [1, 14, 6, 6, 5, 14, 3, -5, 1, 1, 15, 11, -14, -15, 4, -4, 4, 15, 4, 14, 13, -9, 10, -13, 2], solution: [0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 0, 0, 1, 0], rowTargets: [19, 3, 11, 29, -13], colTargets: [-4, 28, 15, -9, 19]),
  // #84 (5x5, 14 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [6, 11, -13, -11, 2, 3, 9, 4, -7, 14, -7, 13, 6, 13, 5, 4, 5, 14, -8, 12, -14, 12, 8, 8, 7], solution: [1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 1, 0, 1, 0, 1, 1], rowTargets: [17, -7, 19, 18, 27], colTargets: [6, 36, 20, -7, 19]),
  // #85 (5x5, 11 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [10, 6, -14, -4, -3, -7, 6, 15, 8, -8, -11, 8, 2, 5, -15, 15, 6, 9, 13, 13, 5, -5, -2, 1, 8], solution: [1, 1, 1, 0, 0, 1, 0, 0, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1], rowTargets: [2, -7, -1, 43, 8], colTargets: [7, 20, -3, 8, 13]),
  // #86 (5x5, 14 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [8, 3, 7, 12, 4, 13, -4, -13, 1, 5, 2, 1, 13, 13, -9, 13, 7, 6, -7, 14, -13, 10, 14, 11, 15], solution: [0, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 1], rowTargets: [7, -7, 5, 13, 39], colTargets: [13, 11, 21, 1, 11]),
  // #87 (5x5, 12 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [-1, -8, 12, 15, 15, 9, 7, 13, -14, 13, -11, -14, 4, 13, 2, 1, 8, -5, 14, 6, 14, 13, -5, -5, -15], solution: [1, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1], rowTargets: [11, 15, 19, 9, -20], colTargets: [8, 7, 11, 8, 0]),
  // #88 (5x5, 11 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [-2, 10, 9, -11, 7, 6, 12, 13, 5, 3, 14, 13, -3, 10, 5, 4, -6, 8, 15, -11, 2, -15, 4, 6, 14], solution: [1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 1, 1, 1, 0, 0, 0, 0], rowTargets: [3, 30, 27, 2, 2], colTargets: [18, 19, 22, 9, -4]),
  // #89 (5x5, 14 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [6, 11, -2, 13, 8, 5, -2, 6, 1, -2, 6, -15, 5, 5, 12, 5, -2, -11, -15, 5, 10, 6, 7, 14, -15], solution: [0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 1, 0, 1, 0], rowTargets: [6, 4, 23, -15, 20], colTargets: [11, 6, -2, 5, 18]),
  // #90 (5x5, 13 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [15, 15, 5, -15, 1, 8, 12, 8, 6, 5, 4, -9, 14, 8, 11, 5, 13, -9, 12, -14, -12, 1, 13, 14, 2], solution: [0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1], rowTargets: [5, 8, 15, 16, 30], colTargets: [17, 14, 18, 26, -1]),
  // #91 (5x5, 11 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [-13, -15, 5, 3, 5, 15, 14, 10, -7, -7, 11, -9, 1, 15, 11, -11, 4, 15, 12, 13, 6, -10, 6, 6, 6], solution: [0, 1, 1, 0, 0, 0, 1, 1, 1, 0, 1, 1, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 0], rowTargets: [-10, 17, 13, 18, 12], colTargets: [6, -6, 21, 5, 24]),
  // #92 (5x5, 13 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [9, 8, 5, 4, 11, 13, -2, 12, -8, 5, 12, -9, -12, 12, -12, 8, 4, 9, 3, 2, -3, 12, 5, -4, 15], solution: [0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 0, 1], rowTargets: [13, 5, 0, 14, 15], colTargets: [33, 12, -7, 4, 5]),
  // #93 (5x5, 10 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [7, -4, 9, -4, -7, 12, 15, 12, -1, 10, 5, 14, 11, 6, 15, -8, -6, 4, 13, 13, 5, -8, 14, -3, 7], solution: [1, 1, 0, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 1, 1, 1, 1, 0, 1], rowTargets: [-4, 26, 17, 11, 18], colTargets: [24, -3, 29, 5, 13]),
  // #94 (5x5, 15 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [9, -10, 6, 15, 4, 9, 6, 1, 3, -3, 11, 14, 11, 12, 8, 13, 4, -2, 14, -8, 4, -14, -13, 5, -14], solution: [1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1], rowTargets: [9, 3, 48, 4, -14], colTargets: [20, 14, 9, 29, -22]),
  // #95 (5x5, 13 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [3, 4, 10, 4, -1, 13, 13, -11, 12, 2, -10, 11, -14, -12, 12, 11, 11, 3, 14, 15, 2, -1, 15, 12, -8], solution: [0, 0, 1, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1], rowTargets: [13, 4, -24, 36, -8], colTargets: [1, 24, -15, 18, -7]),
  // #96 (5x5, 15 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [10, 14, -2, -8, -13, -12, 12, 13, -7, -6, 7, 5, 2, 5, 8, -8, 3, -12, 15, -11, 5, 5, -11, -9, -8], solution: [0, 1, 1, 0, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1], rowTargets: [-1, -18, 5, -11, -12], colTargets: [-7, 19, -2, -9, -38]),
  // #97 (5x5, 15 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [-9, 14, 3, -8, 7, 11, 7, 8, 15, -6, -13, 12, 11, -6, 15, 4, 10, -13, 2, -15, 14, 5, -8, 14, 12], solution: [0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0], rowTargets: [6, 15, 25, -15, 6], colTargets: [-13, 26, 3, 21, 0]),
  // #98 (5x5, 15 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [10, 4, 11, 9, 8, 9, 11, -5, 8, 14, -11, 12, -11, 10, 12, -13, 6, -13, 8, 4, 15, 8, 6, 3, 2], solution: [1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 1], rowTargets: [19, 11, 1, 4, 31], colTargets: [14, 31, 6, 9, 6]),
  // #99 (5x5, 11 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [14, 1, 9, 5, 1, -7, 2, -2, 4, 12, 1, 11, 10, 2, -15, -12, 8, 8, 8, 10, 3, 5, 5, 3, 15], solution: [1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1], rowTargets: [28, 18, 21, 4, 23], colTargets: [2, 21, 32, 12, 27]),
  // #100 (5x5, 11 struck, negatives, unique)
  SumStrikeLevel(gridSize: 5, grid: [-8, 8, 12, 7, -4, 12, 11, 7, 8, -9, 7, 8, 11, 3, 3, 3, -15, 4, 7, 3, 14, 4, -7, 7, -14], solution: [1, 1, 0, 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0], rowTargets: [-4, 38, 11, 14, 21], colTargets: [18, 27, 11, 22, 2]),
  // #101 (6x6, 19 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [8, 16, 1, 6, 6, 8, -9, 5, 5, 6, 5, 3, 11, 7, 13, 11, 9, 9, 16, 4, 5, 11, -4, 15, 8, 9, 15, 16, -9, 2, 13, -5, 10, 3, 8, 14], solution: [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0], rowTargets: [30, 19, 31, 11, -9, 11], colTargets: [13, 20, 13, 26, 1, 20]),
  // #102 (6x6, 21 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [10, -6, 12, 3, -11, 13, 9, -15, 4, 4, 1, 6, 2, 5, 15, 9, 12, 13, -7, 10, -7, 14, -14, -6, 3, 8, 7, 7, 15, 7, 16, 8, 1, 2, 3, 16], solution: [1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0], rowTargets: [8, -9, 28, 8, 10, 19], colTargets: [29, -21, 34, 17, -8, 13]),
  // #103 (6x6, 17 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [5, 1, 4, 6, 2, 4, 16, -13, 12, 2, 9, 15, 1, 16, -2, 7, -7, 5, 1, 15, 2, 12, -3, 1, 13, -2, 5, 10, 7, 10, 11, 13, -15, 3, -9, 14], solution: [0, 1, 1, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 0, 0, 0], rowTargets: [5, 17, 6, 4, 38, -2], colTargets: [31, -1, 1, 19, 7, 11]),
  // #104 (6x6, 19 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [14, 12, 10, 14, 3, -16, 9, 6, 4, 10, 14, 9, 14, 13, 3, 8, -8, 12, 13, -14, 11, 10, 9, -9, 8, 12, 7, 2, -8, 11, 1, 3, 14, -6, -11, 10], solution: [0, 1, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0], rowTargets: [26, 43, 23, -12, 17, -6], colTargets: [8, 4, 25, 28, 14, 12]),
  // #105 (6x6, 16 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [1, 8, 7, 1, 6, 11, 1, 4, 8, -9, 9, 9, 16, 10, 12, 15, 2, 15, 7, 11, 8, 7, -3, 12, 9, 9, 2, 12, 1, -12, 14, 8, 4, 16, 2, -16], solution: [0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1], rowTargets: [18, 0, 30, 23, 33, 24], colTargets: [30, 17, 9, 41, 9, 22]),
  // #106 (6x6, 18 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [4, 12, 16, 5, -16, 8, 14, -6, -4, 9, 13, 14, 13, 6, -7, 10, -10, 12, 11, -14, 16, 11, -1, 1, -14, 13, 1, 14, -12, 8, 13, 4, 2, 8, 13, 7], solution: [0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 1, 0, 1], rowTargets: [8, 3, 2, 9, -3, 15], colTargets: [10, -14, -6, 42, -22, 24]),
  // #107 (6x6, 17 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [8, 2, 3, 6, 13, -10, 10, 13, -4, -10, -11, 12, 11, -16, 3, 11, 4, 15, 2, 3, 8, 11, 11, 7, 8, 6, 15, 11, 1, 2, 2, -10, 8, 10, 6, -11], solution: [1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 0, 1, 1, 1], rowTargets: [7, -2, 29, 15, 23, -5], colTargets: [8, 9, 25, 27, -5, 3]),
  // #108 (6x6, 18 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [-11, 1, 1, 7, 6, 16, 10, 13, 16, 12, -14, 3, -15, 9, -14, 7, 10, -5, 8, 3, 15, -10, 14, -16, 15, 14, 8, 11, -14, 4, 8, 3, 13, 12, 16, 8], solution: [1, 1, 1, 0, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0], rowTargets: [13, 17, 1, 23, 27, 8], colTargets: [5, 10, 40, 19, -8, 23]),
  // #109 (6x6, 19 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [4, -12, 15, 5, -7, 8, 15, 2, 8, 5, 3, 10, 13, 8, 12, 4, -15, 8, 6, -14, 5, 4, 8, 3, 9, -11, 12, 15, 2, 10, -16, -7, 13, 16, 11, 9], solution: [0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1, 0, 1, 0, 1, 1, 1, 0], rowTargets: [-4, 28, 25, 15, 11, 24], colTargets: [21, -4, 13, 24, 24, 21]),
  // #110 (6x6, 19 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [7, 13, 16, 9, 6, 6, 2, -10, 12, 3, 5, 4, 15, 7, 13, 1, 1, 7, 8, 14, 16, 12, 7, -5, 11, 1, -5, 3, 8, 11, 8, 14, 16, -4, 9, 11], solution: [0, 0, 1, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0, 0, 1, 0, 1], rowTargets: [22, 15, 9, 17, 25, 15], colTargets: [27, 14, 23, 0, 15, 24]),
  // #111 (6x6, 17 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [9, -8, 9, -5, 11, 9, 11, 2, -6, 7, 3, 10, -15, 4, -13, 7, 13, 9, 15, 3, 16, 4, 4, 12, 6, 10, 15, 9, 5, 6, 7, 13, 10, 3, 10, -9], solution: [1, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 0, 1], rowTargets: [-4, 28, 13, 34, 35, 11], colTargets: [48, -1, 41, 14, 5, 10]),
  // #112 (6x6, 14 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [6, 5, 2, 14, 2, 5, 14, 11, 7, 2, -14, -15, 16, 5, 1, 15, -13, 16, -3, -6, 4, 3, 16, -4, 13, 12, 8, 16, -16, 5, -14, 8, -14, 15, 5, 16], solution: [0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 0, 0], rowTargets: [2, 13, 53, 13, 21, -5], colTargets: [26, 24, -1, 48, -12, 12]),
  // #113 (6x6, 19 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [9, 6, 6, 8, 12, 5, -14, 13, 8, 12, 16, 8, 16, -5, 12, 9, 4, -13, 6, -5, 15, 9, 11, 8, 15, 10, 2, 5, 16, 14, 12, 15, 13, 12, 2, -7], solution: [0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0, 0, 0, 1], rowTargets: [31, 13, 32, 14, 36, 8], colTargets: [37, 23, 20, 22, 12, 20]),
  // #114 (6x6, 19 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [7, 3, 11, 11, -14, 13, 15, 12, -4, -4, 6, 11, 10, 8, 16, -5, 14, -13, -2, -8, 7, 5, 10, 16, 9, -8, 1, -6, 6, 7, -3, 14, 1, -5, 7, 8], solution: [1, 0, 1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 1, 0, 1], rowTargets: [17, -4, 11, 9, 6, 3], colTargets: [7, -8, 35, -9, 2, 15]),
  // #115 (6x6, 15 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [15, 3, 4, 15, 10, 7, 5, 14, 12, -6, -16, 7, 4, 3, 8, 8, 12, 14, 14, 16, 5, 11, 1, 1, 8, -13, 12, 12, 4, -15, 11, 15, 6, 12, -13, 13], solution: [0, 1, 0, 1, 1, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0], rowTargets: [28, 10, 20, 47, 28, 16], colTargets: [30, 33, 31, 50, -3, 8]),
  // #116 (6x6, 15 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [12, -7, 5, 16, 11, -16, 12, 4, 14, 12, 6, 11, -3, 4, 2, 2, 12, 11, 11, 15, 7, 13, 9, 7, 8, 11, 16, -15, 2, 10, 5, -12, 15, 14, 2, 1], solution: [1, 0, 1, 0, 0, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 1], rowTargets: [17, 53, 26, 40, 27, 4], colTargets: [32, 7, 52, 25, 21, 30]),
  // #117 (6x6, 20 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [-5, 1, 6, -3, 11, 11, -12, 15, 4, 9, 16, 2, 16, -3, 14, 4, -9, 1, 12, -12, 15, 3, -7, 4, 3, 7, 9, 11, 15, -4, 1, 2, -11, 2, 13, 6], solution: [0, 1, 1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0], rowTargets: [29, 16, 6, -9, 6, 15], colTargets: [3, -5, 20, 7, 31, 7]),
  // #118 (6x6, 16 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [8, 4, 13, -12, 10, 4, 2, 5, 2, -13, 8, -14, 14, -6, -9, 10, -14, 10, 13, 7, 15, -2, 15, 2, -9, 13, 1, 9, 3, 8, 14, 12, -14, -3, 11, 2], solution: [1, 1, 0, 0, 0, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 1, 1, 1, 0, 1], rowTargets: [16, 2, -15, 24, 10, -3], colTargets: [24, 22, -22, -7, 9, 8]),
  // #119 (6x6, 16 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [7, 9, -13, 12, 1, 10, -2, 9, 5, 10, -14, 11, 16, 5, 7, 6, 5, 7, 3, 9, 16, -16, -15, 6, -10, -10, 2, 16, -13, 14, -6, 13, 8, 9, 12, 10], solution: [0, 1, 1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 0], rowTargets: [18, 0, 30, -6, -7, 7], colTargets: [-18, 36, -1, 34, -37, 28]),
  // #120 (6x6, 21 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [-13, 15, 16, 3, 7, 14, 3, -14, 11, -5, 10, -13, 11, 14, 13, -11, -15, 14, 3, 9, 16, -1, 13, 10, 9, 10, 6, 10, -8, -5, 4, -9, 2, 8, -4, 12], solution: [0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1, 1], rowTargets: [17, 10, 14, 26, 5, 18], colTargets: [14, 14, 2, 10, 19, 31]),
```

## Appendix B - Masyu 8x8 (levels 151-180)

```dart
// SAFE BACKUP: 30 unique+distinct 8x8 Masyu levels (z3-verified)
  // 8x8 backup #1 (10 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [2, 1, 0, 1, 0, 0, 0, 0, 1, 2, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 8x8 backup #2 (12 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [2, 1, 1, 2, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 8x8 backup #3 (10 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 2, 1, 0, 0, 0, 1, 0, 0, 1, 2]),
  // 8x8 backup #4 (10 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 1, 0, 0, 1, 2, 0, 0, 0, 1, 0, 1, 2, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 8x8 backup #5 (12 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 2, 1, 1, 2, 0, 0, 0, 0]),
  // 8x8 backup #6 (12 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 2, 1, 1, 2]),
  // 8x8 backup #7 (11 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 2, 1, 0, 0, 1, 0, 0, 0]),
  // 8x8 backup #8 (11 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 1, 0, 1, 2, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 8x8 backup #9 (9 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 2, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 8x8 backup #10 (13 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 1, 0, 0, 1, 2, 0, 0, 0, 1, 2, 0, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 8x8 backup #11 (10 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 1, 2, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 8x8 backup #12 (11 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 2, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0]),
  // 8x8 backup #13 (14 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 0, 1, 0, 1, 2, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 2, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 8x8 backup #14 (14 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 1, 0, 0, 0, 0, 1, 2, 0, 1, 0, 1, 2, 0, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 8x8 backup #15 (14 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 0, 0, 2, 1, 0, 1, 0, 2, 1, 0, 0, 0, 0, 1, 0]),
  // 8x8 backup #16 (12 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0]),
  // 8x8 backup #17 (16 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 2, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 2]),
  // 8x8 backup #18 (17 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 0, 1, 0, 1, 2, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 2, 1, 0]),
  // 8x8 backup #19 (14 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 0, 1, 2, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 2]),
  // 8x8 backup #20 (17 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 0, 1, 2, 1, 0, 2, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0]),
  // 8x8 backup #21 (13 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 0, 0, 1, 2, 1, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0]),
  // 8x8 backup #22 (16 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 2, 1, 0, 0, 1, 2]),
  // 8x8 backup #23 (14 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 1, 0, 0, 1, 2, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 2, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 8x8 backup #24 (14 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 1, 0, 0, 1, 2, 0, 0, 0, 0, 2, 1, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 0, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 8x8 backup #25 (16 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 1, 2, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 2]),
  // 8x8 backup #26 (17 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 0, 1, 0, 1, 2, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 2, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 8x8 backup #27 (16 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 1, 0, 0, 1, 2, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 2, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 8x8 backup #28 (17 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 1, 2, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 2, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 2, 1, 1, 0, 0, 0, 0, 0]),
  // 8x8 backup #29 (17 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 2, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 2, 1, 0, 1, 0, 0, 0, 0]),
  // 8x8 backup #30 (15 pearls, unique)
  MasyuLevel(gridSize: 8, pearls: [0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 2, 1, 0, 2, 1, 0, 1, 1, 1, 0, 0, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
```

## Appendix C - Masyu 9x9 (levels 181-205)

_Generation in progress (single-process). This block will be appended when the 9x9 run completes._
