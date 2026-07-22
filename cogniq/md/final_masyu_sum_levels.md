# final_masyu_sum_levels.md — Final Generated Level Data (Sum Strike + Masyu)

**Generated:** 2026-07-22. All level data below is **offline pre-computed and solver-verified** — nothing is
generated at runtime, so there is no on-load solve/freeze and every level is guaranteed valid.

| Set | Count | Guarantee | Source file |
|---|---|---|---|
| **Sum Strike** | **200** | z3-verified: unique solution + non-trivial mask (every row/col has at least 1 kept and 1 struck) + no pre-satisfied line | `masyu_gen/sumstrike_levels_backup.dart` |
| **Masyu 8x8** | **30** (levels 151-180) | z3-verified: unique closed-loop solution, distinct from every other board | `masyu_gen/masyu_8x8_backup.dart` |
| **Masyu 9x9** | **25** (levels 181-205) | z3-verified unique + distinct (pearl-rich for solid uniqueness) | `masyu_gen/masyu_9x9_backup.dart` |

> **Verification note.** The Masyu solver (`masyu_z3.py`) is hardened so a resource-starved `unknown` from z3 is
> **never** mistaken for `unsat` or for a passing uniqueness check. Every emitted board was re-verified in isolation
> before being kept, and every board's solution is distinct from all others. Sum Strike uniqueness is a
> linear-arithmetic z3 check (fast, exact).

---

## 1. Sum Strike — wiring

`sum_strike_levels.dart` already defines `class SumStrikeLevel` and `const List<SumStrikeLevel> kSumStrikeLevels`,
and `sum_strike_screen.dart:175-183` already consumes it for curated levels (`!daily && level < kSumStrikeLevels.length`).
**Action:** replace the body of `kSumStrikeLevels` with the **200** entries in Appendix A (they supersede the old 120;
levels 1-120 are byte-identical, 121-200 are new denser 6x6 + a new 7x7 tier). No screen changes needed — the
curated-vs-runtime switch already keys off `kSumStrikeLevels.length`, so the game will simply serve 200 curated levels.

Class shape (already present — do not redefine):

    class SumStrikeLevel {
      final int gridSize;
      final List<int> grid;        // row-major cell values (can be negative)
      final List<int> solution;    // row-major keep/strike mask: 1 = kept, 0 = struck
      final List<int> rowTargets;  // sum of kept cells per row
      final List<int> colTargets;  // sum of kept cells per col
      const SumStrikeLevel({
        required this.gridSize, required this.grid, required this.solution,
        required this.rowTargets, required this.colTargets,
      });
    }

## 2. Masyu — wiring

`masyu_levels.dart` defines `class MasyuLevel { final int gridSize; final List<int> pearls; ... }` and
`const List<MasyuLevel> kMasyuLevels`. `pearls` is a row-major array: `0` = empty, `1` = white pearl, `2` = black pearl.
`masyu_screen.dart:153-174` (`_setupLevel`) loads a level with a pure data copy — **no solve on load** — so adding
these boards cannot reintroduce the old L50+ freeze.

**Action:**
- **Levels 151-180 (8x8):** ensure the 30 entries in Appendix B occupy this range.
- **Levels 181-205 (9x9):** replace this range with the 25 entries in Appendix C.
- **Also:** update the jump-to-level dialog max — `masyu_screen.dart:114` still reads "1 - 150"; set it to **205**.

---

## Appendix A — Sum Strike (200 levels, z3-verified)

```dart
// SAFE BACKUP: 200 unique + non-trivial + no-presat Sum Strike levels (z3-verified)
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
  // #121 (6x6, 13 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [-7, 7, 11, 9, 3, -8, 7, 16, 5, 9, 14, -6, 6, 6, 2, -15, 16, 17, 14, 9, -6, 9, 14, 3, 12, 5, 5, 16, 4, -7, 5, 16, 5, 16, 13, 2], solution: [0, 0, 1, 0, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 0, 1, 0, 1], rowTargets: [3, 32, 26, 29, 30, 39], colTargets: [18, 46, 12, 35, 34, 14]),
  // #122 (6x6, 21 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [3, 12, 17, 15, -2, 11, 17, -8, 7, 1, 7, 3, 12, -5, 8, 8, 3, 13, 2, -17, -14, 4, 1, 17, 2, 11, 12, 11, 10, 15, 7, 6, 4, 16, 15, -11], solution: [0, 0, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1], rowTargets: [24, -7, 8, 5, 13, 26], colTargets: [4, 9, -6, 32, 13, 17]),
  // #123 (6x6, 18 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [9, -1, 6, 11, 6, 1, 14, 1, 4, 13, 2, 15, 7, 16, 4, 5, 2, 12, 15, 13, -13, 6, 14, 7, -1, -13, -14, 7, 2, 3, 11, 8, 1, 3, 17, 3], solution: [1, 1, 1, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 1, 0], rowTargets: [21, 17, 30, 6, -25, 26], colTargets: [16, 10, -3, 24, 27, 1]),
  // #124 (6x6, 17 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [2, 8, 4, 12, 17, 11, 4, 12, 10, 10, 6, 4, 14, 15, 9, 5, 12, -15, 10, -7, -7, 11, 3, 15, 7, 13, -11, 11, 9, 9, 10, 10, 1, 1, 6, 6], solution: [0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1, 1, 0, 0, 1, 1, 1, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 1], rowTargets: [12, 22, 35, 7, 7, 26], colTargets: [35, 45, -5, 22, 21, -9]),
  // #125 (6x6, 21 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [3, 12, 3, 14, 2, 12, -3, 7, -7, 2, 14, 10, 5, -1, 14, 13, -17, 9, 8, 9, -16, 10, 9, 12, -6, 7, 2, -16, 12, -13, -10, 6, 17, -14, 13, 8], solution: [1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 1, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 0, 0, 0, 0], rowTargets: [20, 7, 6, -7, 2, -10], colTargets: [-13, 23, 3, 14, -5, -4]),
  // #126 (6x6, 20 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [16, 14, 13, 5, 16, 9, 15, 11, 1, 3, 17, 4, 16, 12, 17, -12, -14, 2, 8, 4, 3, -16, 1, 1, -13, 15, 8, 12, 8, 11, -2, 15, 15, -10, 13, 17], solution: [0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0], rowTargets: [35, 18, 7, -4, -13, 11], colTargets: [9, 29, 17, -20, 15, 4]),
  // #127 (6x6, 21 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [8, 12, 11, 5, 16, 15, 6, 6, 12, -2, 2, 17, 2, -2, 6, 8, 7, 13, 15, 5, 4, 16, 15, 10, 3, 5, 15, 5, 17, 5, 1, 7, -7, -3, 7, -13], solution: [1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 0], rowTargets: [52, 23, 0, 19, 25, 7], colTargets: [25, 21, 30, 10, 23, 17]),
  // #128 (6x6, 21 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [12, 15, -2, -10, -17, 9, 13, 9, 9, 16, -17, 16, 9, 9, 1, 7, -2, -4, 3, 3, 12, -15, 12, 12, 7, 8, 13, 16, 2, 13, 5, 7, 11, -12, 12, 16], solution: [0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 1, 1, 0, 1], rowTargets: [-27, 1, 1, 15, 34, 20], colTargets: [8, 17, 34, -22, -22, 29]),
  // #129 (6x6, 16 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [10, 4, 6, 12, 5, -5, 8, 8, 3, 8, 14, 4, 17, -7, -8, 13, 3, -3, -1, 10, -5, 14, 10, -1, -1, 6, 4, 15, 8, 2, 15, 10, 7, 6, -11, -5], solution: [0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 1], rowTargets: [22, 31, 12, 24, 1, 12], colTargets: [24, 15, 8, 47, 10, -2]),
  // #130 (6x6, 21 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [-6, -6, 6, 8, 17, 11, 9, -5, 15, 12, 12, 7, 17, 10, 4, 4, 4, 11, 9, 6, -1, 12, 4, -9, 9, -9, 10, 11, -7, 14, -14, -16, 13, 15, 8, -8], solution: [0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1], rowTargets: [28, 15, 27, -3, 14, -15], colTargets: [12, -9, 15, 15, 25, 8]),
  // #131 (6x6, 21 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [14, -13, 6, -11, -17, 14, 16, 10, 15, 14, 11, 10, -16, -4, 3, 6, 9, 13, 16, 11, 9, 2, 6, 2, 14, 16, 13, -7, 16, 7, 15, -13, 3, -7, 15, 14], solution: [0, 1, 1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1, 0, 0], rowTargets: [-10, 14, 2, 11, 43, -17], colTargets: [14, -30, 31, 13, -1, 16]),
  // #132 (6x6, 17 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [14, 11, 6, 1, 5, 9, 1, -17, 14, -16, -11, -5, 5, 17, 13, 9, 15, -12, 10, -17, -6, 7, 5, 8, 5, 9, 15, 6, 16, 2, 14, -16, -14, 5, 11, 6], solution: [1, 1, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 1, 0, 1, 0], rowTargets: [40, 15, 15, 12, 16, -3], colTargets: [35, 20, 7, 10, 16, 7]),
  // #133 (6x6, 21 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [11, -14, 5, 8, 16, 6, 8, 11, 10, 14, 6, 16, -8, 2, 5, -17, 15, 11, -14, 10, -13, 5, -12, 6, 16, -14, 3, -6, 3, -16, -1, 9, 9, 10, -17, 3], solution: [0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0], rowTargets: [7, 47, -8, -9, 5, 8], colTargets: [-7, -8, 5, 19, 25, 16]),
  // #134 (6x6, 16 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [-2, 8, 13, 12, 5, 8, 7, 6, 16, 15, 10, 10, 7, 12, 5, 8, 13, 7, 5, -16, -4, -12, -13, 8, -13, -1, 1, -4, 13, 17, 4, 13, 6, -15, 1, -7], solution: [1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0], rowTargets: [-2, 15, 40, -24, 26, 24], colTargets: [14, 12, 8, 7, 14, 24]),
  // #135 (6x6, 16 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [11, 5, 17, 1, 4, -5, -12, 7, -5, -14, 16, 6, 5, 8, 12, 10, 7, 10, 1, -2, 17, 15, 4, 12, 5, -9, 9, -12, 17, 11, 3, 7, 7, 4, -9, 14], solution: [0, 0, 1, 0, 1, 1, 1, 0, 0, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 1, 1, 1, 1, 0, 1], rowTargets: [16, 10, 37, 25, 0, 35], colTargets: [-9, 4, 45, 19, 27, 37]),
  // #136 (6x6, 15 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [5, 5, 2, 5, 7, 13, -3, 15, -17, 10, -15, 8, 8, 2, 14, 15, 2, 10, 11, 14, 13, -9, 9, 3, 15, -5, 11, -4, -11, 8, 7, 2, 7, 9, 3, 16], solution: [1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 1, 1, 0], rowTargets: [32, -10, 8, 25, 4, 26], colTargets: [28, 34, -8, 6, 4, 21]),
  // #137 (6x6, 18 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [-1, 6, -8, 12, 16, 1, 5, 8, -11, 16, 3, 11, 3, 9, 9, 6, -2, 10, 10, 16, 16, -3, 4, 12, 11, 1, 2, 17, -6, 11, 8, 2, 13, 14, 10, 4], solution: [1, 0, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 0], rowTargets: [28, 24, 12, 30, 18, 25], colTargets: [23, 10, 40, 28, 24, 12]),
  // #138 (6x6, 16 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [5, -5, 8, 10, -17, 11, 3, 13, -7, 2, 1, 7, 6, 14, 5, 7, 17, 16, 12, 14, 4, 2, 2, 15, 10, 6, -17, 16, -9, 5, 16, 15, 2, 12, -8, 16], solution: [0, 0, 1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1], rowTargets: [2, 2, 29, 33, 0, 51], colTargets: [26, 29, -4, 39, -15, 42]),
  // #139 (6x6, 16 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [-7, -9, -1, -2, -5, -13, 3, -9, -11, 15, 9, 5, -2, 15, -3, 3, 5, -3, -5, 12, 1, 16, 7, 12, -5, 17, 2, 10, -15, 2, 15, 15, 17, 3, -9, 8], solution: [1, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 1], rowTargets: [-7, 9, 10, 42, 31, 23], colTargets: [4, 35, -1, 44, 7, 19]),
  // #140 (6x6, 18 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [8, 7, 2, 15, 13, 10, 13, -14, 2, -7, 2, 15, 16, 7, 13, 11, 7, 12, 15, -9, 4, 10, 12, 4, 6, 3, -1, 3, 3, -3, 13, -2, 13, 13, -9, 9], solution: [1, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 1, 1, 1], rowTargets: [36, 19, 20, 22, -1, 24], colTargets: [8, 1, 27, 38, 25, 21]),
  // #141 (6x6, 16 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [2, 3, 4, 17, 16, 1, 12, 7, 1, 3, 15, -18, 3, -2, 9, 14, 13, -14, 7, 5, 2, -3, 6, 5, -11, -8, 14, 3, 3, 14, -5, 5, 13, 16, 11, 10], solution: [0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0, 0], rowTargets: [37, 5, -14, 15, 20, 8], colTargets: [7, 15, 30, 20, 25, -26]),
  // #142 (6x6, 19 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [1, 2, 7, 17, 5, 4, 17, 3, 7, 18, -12, 3, 17, -4, 12, 11, -5, 12, 8, 6, 15, 8, -13, 15, 15, 17, 8, 11, -9, 15, -8, 14, -11, 3, 7, -14], solution: [0, 1, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0], rowTargets: [28, 20, 25, 1, 31, 3], colTargets: [49, 24, 20, 28, -17, 4]),
  // #143 (6x6, 23 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [-7, 12, 3, -12, 16, 11, 2, 10, 16, 1, 2, 15, 11, 10, -16, 6, 1, 4, 13, 6, 2, -14, 18, 4, 17, 17, 15, 11, -5, 8, 2, -7, -16, 1, -15, -16], solution: [1, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0], rowTargets: [4, 3, 15, 8, 49, -15], colTargets: [12, 33, 17, 1, -14, 15]),
  // #144 (6x6, 19 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [18, 9, 5, 12, -6, 7, 10, 10, 1, -16, -6, 3, 5, 16, 3, -17, -2, 9, 12, 9, 18, 6, -12, 2, -5, 4, 17, 2, -9, 14, -12, -9, 11, 7, 9, 8], solution: [0, 0, 1, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0], rowTargets: [6, 21, -7, 8, 24, 11], colTargets: [10, 10, 37, -9, -17, 32]),
  // #145 (6x6, 18 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [9, 11, 4, 4, 2, 14, 17, 2, 14, 11, -3, 16, -11, -5, 8, 1, 10, 10, 1, 1, 9, 9, -16, 7, 3, 5, 1, 17, 5, 16, 2, 10, 7, -11, -9, 8], solution: [0, 1, 0, 1, 0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0], rowTargets: [15, 35, 19, 1, 30, -7], colTargets: [22, 19, 17, 22, -20, 33]),
  // #146 (6x6, 19 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [-11, -9, -15, 9, 13, 9, 12, 1, -4, 5, -6, -11, 3, 3, -13, 13, 5, -15, 1, -10, 9, 1, 6, 12, 7, 2, 2, -16, -3, 16, -5, -8, -12, 5, 10, 8], solution: [0, 0, 1, 1, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 0], rowTargets: [7, 1, -12, 13, 24, -20], colTargets: [5, -5, -25, 15, 10, 13]),
  // #147 (6x6, 20 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [9, 14, -7, 15, -13, -4, -11, -1, 12, 5, 8, 17, 18, 18, 18, -15, -13, -9, 6, 7, -5, 4, 15, 9, 16, 3, 12, 13, 15, 4, 15, -3, 3, -6, 15, 7], solution: [0, 1, 0, 0, 1, 0, 1, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1], rowTargets: [1, 5, 21, 16, 15, 19], colTargets: [13, 10, 25, -10, 32, 7]),
  // #148 (6x6, 15 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [16, -2, -6, -15, -8, 11, 15, -5, 8, 5, 3, 3, 11, 17, 3, -1, 6, 13, -2, -1, 5, -18, 2, 6, 10, 3, 18, 14, 11, 6, -7, -17, 10, -3, 15, 3], solution: [1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1], rowTargets: [1, -2, 37, -10, 38, 4], colTargets: [18, -6, 36, -19, 24, 15]),
  // #149 (6x6, 18 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [8, 1, 15, 9, 10, 11, 3, -2, 8, 17, 17, 18, 9, 18, 18, -16, -10, 4, 3, 5, -13, 12, 11, -12, -13, 15, 11, 7, 7, 15, 11, 16, 10, 1, -6, 12], solution: [0, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 1], rowTargets: [12, 29, 5, 2, 18, 39], colTargets: [26, 35, 19, -16, 8, 33]),
  // #150 (6x6, 20 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [10, 17, 11, 17, 2, -12, 4, 3, -12, 2, 14, 17, 13, 1, 14, 9, 15, -15, -13, 11, 6, 3, -16, 8, 17, -2, 5, 12, 2, 15, 12, 10, 1, 1, 18, 12], solution: [0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 1, 1], rowTargets: [17, 16, 14, -23, 12, 53], colTargets: [12, 11, 7, 31, 31, -3]),
  // #151 (6x6, 16 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [3, -2, -5, 3, 11, -11, 2, 17, 17, 12, -4, -3, 13, -17, 2, -15, 10, 14, 6, -18, 18, 8, 8, -6, 1, 3, 5, -2, 8, 7, 8, 8, 2, 3, 12, 6], solution: [0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1], rowTargets: [-8, 27, 12, -10, 17, 29], colTargets: [22, -15, 24, 14, 16, 6]),
  // #152 (6x6, 18 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [2, -15, -6, 18, 6, 3, -1, -12, 11, 3, -1, 6, 7, 2, -15, 9, 2, 15, 9, 9, 15, 15, -11, -4, 1, 2, -6, 16, 12, 3, 9, 13, 6, 4, -8, 12], solution: [1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 1, 1, 1, 0, 1], rowTargets: [2, 4, 16, 5, 16, 35], colTargets: [18, 1, 11, 13, 18, 17]),
  // #153 (6x6, 23 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [8, 1, 15, 9, 6, 7, 16, 18, 6, -6, 6, 14, 15, 12, 12, 12, 17, 1, 4, 11, -1, 14, 7, 12, 5, -10, -13, -14, -11, 1, 3, 10, -7, 11, 9, 10], solution: [1, 0, 1, 0, 0, 1, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0], rowTargets: [30, 22, 12, 10, -24, 5], colTargets: [27, 13, 7, -14, 15, 7]),
  // #154 (6x6, 16 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [5, 9, -16, 2, 4, 5, -14, -10, 2, 2, 17, -5, -4, 8, -15, 16, 18, 15, 16, 1, 10, 4, 13, 1, -12, 13, 17, 6, 8, 8, 15, 2, -17, 1, 10, -2], solution: [1, 1, 0, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 0, 0, 1, 0], rowTargets: [23, -17, 8, 18, 27, 25], colTargets: [-6, 17, 4, 10, 35, 24]),
  // #155 (6x6, 18 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [-2, 13, 11, 18, -16, -11, -12, 12, 7, 9, 16, 4, 17, 14, 4, -13, 8, 12, 16, 5, -3, 5, 7, 9, 7, -17, 14, 1, 3, 4, 1, 2, 8, 16, 16, 10], solution: [1, 0, 1, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1], rowTargets: [9, 20, 17, 11, -14, 34], colTargets: [-14, 9, 20, -8, 35, 35]),
  // #156 (6x6, 13 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [-3, 6, 1, -9, -6, -13, -13, 4, 17, -13, 1, -6, -14, -4, 7, -14, 12, 3, -8, 14, -14, 9, -6, 16, 1, 14, 12, 1, 5, 13, 8, 7, 7, 9, -16, -12], solution: [0, 1, 0, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 0, 1, 0, 1, 1, 0], rowTargets: [-22, 9, -13, 39, 45, 0], colTargets: [-27, 45, 29, -4, -4, 19]),
  // #157 (6x6, 17 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [11, 8, 9, 14, 8, 1, 14, -17, 18, 7, 6, 17, 4, 11, 17, 1, 17, 7, -8, 12, -2, 6, 9, -2, 1, -1, 18, -15, -4, 8, 18, 10, 9, 3, 18, 15], solution: [1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 0, 1, 1], rowTargets: [41, 56, 28, 18, 12, 43], colTargets: [26, 41, 36, 12, 43, 40]),
  // #158 (6x6, 19 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [18, 12, 17, 4, -4, 6, 1, 18, 10, 17, 12, 3, -15, 13, 18, 11, 9, 6, 2, 15, -1, 15, 10, 13, -2, 7, 10, 17, -7, 8, -3, 11, 8, 1, 7, 16], solution: [1, 1, 0, 0, 0, 1, 0, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0], rowTargets: [36, 42, 23, 13, 32, -3], colTargets: [-2, 19, 38, 45, 21, 22]),
  // #159 (6x6, 20 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [12, 11, 16, 10, 14, 2, 6, 9, 2, 13, 13, 2, 18, 3, 1, 16, -11, 5, 9, 17, 4, -6, 16, -12, -12, -14, -10, 14, -10, 6, 11, 2, -13, 16, 10, 5], solution: [1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 1, 1, 0, 1], rowTargets: [38, 2, 6, 37, -20, 19], colTargets: [11, 3, 10, 26, 16, 16]),
  // #160 (6x6, 19 struck, negatives, unique)
  SumStrikeLevel(gridSize: 6, grid: [15, 7, 11, 10, 1, -12, -11, 9, 10, 16, 13, 1, 8, -10, 5, 11, 16, 15, 6, 17, 3, 8, 11, -7, 17, -5, -8, 5, 15, -4, 12, -4, 1, -5, 1, -14], solution: [1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1, 0, 0], rowTargets: [10, 2, 18, 19, 24, -8], colTargets: [29, -7, -2, 3, 39, 3]),
  // #161 (7x7, 28 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [10, 16, 3, 15, 1, 5, 7, 13, 15, 9, 4, -5, 11, -1, 3, 4, 8, 16, 11, 4, 5, 8, 1, 2, 14, 7, 10, 6, -10, 7, 12, -10, 7, -6, 13, 3, 4, 11, 6, -2, -15, -9, 5, 6, 15, 11, 16, 10, 14], solution: [0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 1, 1, 0, 0, 1, 0, 0], rowTargets: [12, 13, 29, 13, -14, 0, 27], colTargets: [-5, 11, 34, 10, 14, 13, 3]),
  // #162 (7x7, 22 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [2, 5, -6, 8, 3, 14, -8, -15, 6, 11, 10, 11, 13, 14, 14, 8, 6, 8, 11, 1, -10, 15, 15, 6, 7, -16, -8, 10, -7, 8, 5, 4, -3, 12, 15, 8, 11, 5, 10, -2, 10, -9, 10, 7, 11, 1, -14, 4, 12], solution: [0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 1, 1, 0, 1, 1, 1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 0], rowTargets: [-5, 16, 34, 23, 36, -3, 15], colTargets: [18, 29, 11, 20, 7, 9, 22]),
  // #163 (7x7, 21 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [6, 9, 10, -5, 6, -11, 9, 7, 6, 16, 14, 4, 3, 12, 3, 7, 6, 11, 7, -11, 2, 12, 13, 3, -16, 11, 16, 10, -10, -7, 11, 12, 13, 4, 4, 3, 16, 4, 2, 12, 8, -2, 11, 8, 9, -14, 8, -5, 13], solution: [1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 1], rowTargets: [-5, 34, 36, 37, 18, 26, 16], colTargets: [6, 42, 24, 25, 43, -1, 23]),
  // #164 (7x7, 26 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [-3, 13, 12, 12, 6, 14, -3, 3, 1, 1, 8, 15, 2, 2, -16, 8, 5, 14, 8, 1, 6, 7, 3, 1, 14, 12, 12, 15, 2, 4, 12, -15, 10, 9, 15, 1, 4, 5, 8, 9, 15, -1, -15, 16, 16, -12, 5, 1, 13], solution: [0, 0, 1, 0, 1, 1, 0, 1, 1, 0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 1], rowTargets: [32, 23, -4, 12, 12, 13, 17], colTargets: [-11, 17, 22, -27, 52, 17, 35]),
  // #165 (7x7, 19 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [-1, 5, 14, 5, -8, -14, 9, 1, 6, 13, 11, 3, 16, 6, 5, -12, -11, -2, -10, 10, -5, -3, 1, 2, 9, 2, 4, -12, 2, 3, 10, 10, 3, 7, 14, 12, -2, 9, 9, 1, 9, 16, -14, -8, 5, 4, -3, -9, 7], solution: [1, 0, 1, 0, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0, 1], rowTargets: [8, 43, -33, -5, 31, 7, -9], colTargets: [-12, -15, 18, 33, -10, 9, 19]),
  // #166 (7x7, 20 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [14, -3, 4, -11, 4, 3, -11, 5, 12, 16, -5, -2, 5, 15, 7, -2, 11, 2, 8, 8, 10, 13, 14, 12, 10, 5, 16, -11, 2, 1, 8, 12, 6, -15, 10, -3, 7, -3, 11, 6, 9, 15, 4, 4, 15, 2, 10, 3, 7], solution: [1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 0, 1, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1], rowTargets: [8, 38, 26, 31, 12, 12, 16], colTargets: [20, 21, 36, 18, 23, 4, 21]),
  // #167 (7x7, 22 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [11, -1, 7, 6, -12, 5, 9, -15, 7, 2, 8, 6, 15, 15, 1, 9, 7, 5, 13, 7, 10, -3, 7, 4, 16, -2, 1, 3, 5, 4, 1, 7, 8, 5, 11, 7, 2, 1, 15, 10, 4, 2, 4, -2, 7, 12, 5, -2, 5], solution: [1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0], rowTargets: [11, 2, 32, 1, 29, 27, 2], colTargets: [13, 17, 17, 41, -6, 9, 13]),
  // #168 (7x7, 30 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [2, 15, 9, 10, 1, 3, -11, 2, -11, 5, 1, -5, 5, 16, -1, -9, 1, 11, -3, 16, 8, 13, 11, 16, 10, 6, 4, 8, 10, -3, 12, 3, 16, 10, 13, 2, 12, 15, 14, -16, 6, 14, -2, 4, 10, 5, 12, 8, 9], solution: [0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1], rowTargets: [-2, -4, -2, 27, 52, 17, 14], colTargets: [13, -9, 40, 8, 16, 15, 19]),
  // #169 (7x7, 26 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [-9, 9, -7, 9, 6, 6, 16, 8, 12, 9, -1, 3, 16, 6, -5, -14, 5, 10, 9, 3, 2, -9, 10, 8, 3, -3, -6, 7, -9, 3, 2, 2, -3, 9, 1, 9, 9, 4, 8, 3, -14, -13, 9, 3, 4, 3, 4, -6, 3], solution: [0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1], rowTargets: [17, 34, 9, 7, 10, -1, 0], colTargets: [-9, 19, 14, 20, 9, 19, 4]),
  // #170 (7x7, 25 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [5, -13, 12, 2, 15, -5, 7, 5, 15, 5, 16, 1, 11, 9, 12, 8, 8, 12, 6, 2, 3, 9, 6, 5, 11, 15, 14, 6, 15, 13, 15, 11, -3, 14, 8, 8, 16, 10, 6, -16, 5, 2, 15, 12, 4, 5, 4, 1, -4], solution: [0, 0, 0, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 0, 0], rowTargets: [12, 57, 25, 23, 40, 15, 31], colTargets: [44, 48, 25, 30, 17, 27, 12]),
  // #171 (7x7, 23 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [14, 2, -9, 11, -12, 13, 12, 7, 6, 7, 13, 8, 5, 14, -13, 15, 15, 5, 10, 8, -5, -4, 5, -1, 3, 9, 2, 10, 16, 12, 7, 5, -6, -4, 8, 1, 14, 6, 13, 5, -2, -6, 13, 4, 12, 7, 4, 1, -13], solution: [1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 1, 1, 1, 1, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1], rowTargets: [38, 26, 40, 16, 36, 15, 23], colTargets: [44, 46, 41, 23, 11, 16, 13]),
  // #172 (7x7, 25 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [7, 7, 9, 4, -10, 12, 6, 1, -9, 7, 9, 12, 12, 7, 6, 3, -8, 10, 9, 1, 7, 3, 5, 4, 15, -7, -1, 15, 6, 8, -5, 15, -1, -13, -8, 13, 12, -9, -12, 16, 14, 5, -14, 12, 15, 9, 2, 9, -4], solution: [1, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 1], rowTargets: [26, 20, 8, 22, 8, 17, 8], colTargets: [9, 24, 9, 40, 2, 32, -7]),
  // #173 (7x7, 21 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [9, -14, 7, -9, 1, 7, 15, -14, 16, -12, 6, 1, 2, 11, 6, 14, 9, 7, 6, 11, 5, 11, 4, 13, 5, 7, 16, 10, 7, 14, 10, 15, 1, 11, 3, 3, 11, 14, 4, 16, 9, 13, 15, 10, 9, 1, 6, 9, 13], solution: [1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 0, 0], rowTargets: [7, 35, 47, 34, 53, 46, 25], colTargets: [33, 44, 62, 25, 22, 29, 32]),
  // #174 (7x7, 25 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [16, 11, 4, -6, 15, 12, 8, -12, 2, 2, -3, -8, 10, -4, 16, 7, 6, 6, -16, 11, 8, 5, 4, 9, -3, -8, 2, 9, 14, 15, 2, 13, -12, -11, -6, 7, -9, 15, 9, -3, 5, -12, 10, -1, 10, 5, 15, 5, 10], solution: [0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 1, 0, 0, 1, 0, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0], rowTargets: [23, -5, 31, 24, 6, 20, 10], colTargets: [4, 21, 46, 12, -16, 17, 25]),
  // #175 (7x7, 26 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [15, 10, 11, -4, -10, 6, 2, 1, 12, -14, 16, 13, 2, 10, 1, 13, -13, 3, 10, 12, 12, 6, 16, -11, 16, 8, -5, 16, 8, 15, 3, 12, -9, 9, 8, 13, 16, -3, 16, 14, -3, 15, 3, 14, 12, 2, -11, 16, 14], solution: [1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 1, 0, 1, 1, 0, 1, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0], rowTargets: [13, 25, 0, 41, 18, -3, 47], colTargets: [25, 29, -12, 30, 21, 8, 40]),
  // #176 (7x7, 26 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [-10, 4, 10, 7, 13, -1, 15, 6, 16, 9, 14, 3, 7, 10, 7, -15, 15, 13, 9, 8, 1, 1, 14, 4, 2, 2, 2, -12, 13, 5, -13, 10, 16, 13, 16, 7, 16, 11, -3, 5, 11, 7, 16, 13, 10, 1, 6, 2, 14], solution: [0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 0, 0, 0, 1, 1, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0], rowTargets: [10, 53, -8, 22, 39, 26, 15], colTargets: [26, 28, 12, 23, 16, 35, 17]),
  // #177 (7x7, 22 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [13, 5, 10, 14, 3, 15, 13, 5, 12, 15, 15, -4, 11, 5, 5, -6, 11, 7, 4, 7, 4, -13, 12, 16, 8, 8, -13, 16, 15, 11, -2, 12, 13, 10, -3, 14, 15, 15, -3, 14, 12, 3, 3, 6, 12, -6, 5, 12, 6], solution: [0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 0, 1, 1, 0, 0, 1], rowTargets: [35, 52, 9, 20, 38, 73, 12], colTargets: [34, 38, 51, 35, 42, 12, 27]),
  // #178 (7x7, 28 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [13, 2, 13, 14, 5, -14, 3, -14, 1, 10, -16, -9, -2, 2, 15, 7, 12, 10, 3, 8, 7, 16, 6, -9, 9, -14, 12, 12, -13, 2, 6, 16, 4, 9, -15, 13, 13, 3, 9, 8, 12, 5, 12, 2, -7, 14, 7, -14, 14], solution: [1, 0, 0, 1, 0, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 0, 1, 1, 1], rowTargets: [13, -19, 18, 28, 10, 37, 9], colTargets: [15, 16, 19, 17, 11, -8, 26]),
  // #179 (7x7, 26 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [15, 2, 6, 4, 15, 11, 15, 15, 1, 5, 3, -5, -6, 10, 4, 8, 15, 11, 13, 6, 14, 6, 1, 8, -7, 12, 13, 6, -13, 11, 5, -2, 4, -6, 8, 11, 7, 6, -1, 14, -5, -6, 12, 3, 9, 6, 1, -9, 3], solution: [0, 0, 1, 1, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1, 0, 0], rowTargets: [10, 24, 44, 19, 0, 13, 28], colTargets: [27, 1, 26, 21, 28, 13, 22]),
  // #180 (7x7, 26 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [6, -5, -9, 13, -2, 6, 2, -2, 7, 10, 3, 12, 10, 4, 16, -11, 16, -5, 9, 5, -10, 1, 12, 15, 14, 12, 14, 16, 9, 7, 10, 3, 5, -7, 7, 4, 4, 9, 14, 4, 12, 8, -13, 10, -8, 15, 11, -10, 7], solution: [0, 0, 1, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1], rowTargets: [8, 9, 11, 46, 3, 35, 14], colTargets: [3, 7, 33, 42, -2, 18, 25]),
  // #181 (7x7, 22 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [-14, 5, 11, 11, 4, 4, 5, 9, 16, 11, 4, 8, 2, 8, -2, 16, 7, 18, 7, 12, 3, -1, 15, 1, 16, 12, -7, 7, 7, 17, 15, -11, 17, 14, 16, 13, 4, 10, 7, 12, 16, 5, 5, 4, 17, -12, -15, -8, -13], solution: [0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1], rowTargets: [29, 46, 17, 36, 27, 32, -8], colTargets: [32, 40, 21, 16, 48, 25, -3]),
  // #182 (7x7, 22 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [3, 14, -11, -14, -17, 1, 4, -14, 9, 10, 7, 2, 12, 15, 12, 11, 18, 3, 9, 10, -10, -18, 5, 12, -17, 1, 17, 3, -1, 8, -6, -8, 10, 12, 6, 9, 15, 16, 18, 14, 15, 9, -5, 4, 9, 17, 11, -3, 11], solution: [1, 0, 0, 0, 1, 1, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 1, 1, 0, 0, 1, 1], rowTargets: [-13, 20, 35, 2, 16, 56, 21], colTargets: [-17, 24, 13, 21, 16, 52, 28]),
  // #183 (7x7, 23 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [10, 18, 1, 1, -18, 14, -1, -15, 17, 14, 11, -1, 8, -16, -10, 15, 11, 18, -10, -9, 12, -14, 14, 12, -13, -4, 16, 11, 15, 18, -18, 3, -7, 17, 6, 12, 5, 8, 6, 17, 7, 10, 2, 13, -7, 10, 4, 9, 17], solution: [1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0], rowTargets: [43, 20, 0, 11, 19, 37, 25], colTargets: [-1, 48, 19, 43, -18, 37, 27]),
  // #184 (7x7, 27 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [-11, -9, -6, -7, 14, 11, 15, 7, 14, 15, 4, 13, -17, -1, 17, 9, 10, 3, 15, 3, 10, 2, 7, 2, 3, -1, 3, -5, 3, 6, 14, -10, 8, -11, -15, 3, 15, 6, 17, 9, 2, 7, 7, 16, 18, -8, -2, 15, 9], solution: [1, 1, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1, 0, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1, 1, 0], rowTargets: [-5, 5, 25, 8, 3, 22, 31], colTargets: [-4, 13, 51, 3, 14, -10, 22]),
  // #185 (7x7, 20 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [13, 10, -9, 15, 8, 8, 8, 4, -18, 13, 18, 5, 3, 9, 4, -11, -8, 13, -13, -16, 10, 14, 16, 16, 5, 10, -15, 16, 13, 18, 1, 1, 7, 15, 7, 8, 2, 15, 3, 7, 11, 2, 6, -8, 5, 16, -11, 15, -18], solution: [1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 0], rowTargets: [12, -9, -26, 41, 43, 36, 17], colTargets: [44, -37, 27, 20, 0, 18, 42]),
  // #186 (7x7, 23 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [5, 10, 13, 15, 10, 2, 15, 10, 17, 17, 6, 1, 17, 2, -4, 18, 14, 18, 2, 16, 1, -3, 16, 12, 2, 3, 8, -16, 7, 11, 15, -6, 10, -12, 1, -7, 16, -9, 9, -11, 7, 3, 9, -13, 15, -15, 13, 8, 18], solution: [0, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1], rowTargets: [48, 61, 16, 0, 2, -4, 12], colTargets: [12, 48, 21, -21, 17, 24, 34]),
  // #187 (7x7, 24 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [-13, 12, 6, 11, -2, 5, -12, 12, -11, 3, 14, -18, -2, 9, 3, 14, 8, 7, 11, -5, -18, 11, -12, 7, -2, 15, 16, 5, 6, 11, 7, 7, 17, 12, 3, 9, 15, -2, -8, 3, -7, -12, 10, 14, 2, 17, -8, -12, -1], solution: [1, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1], rowTargets: [-5, -20, -9, 22, 60, 3, 9], colTargets: [3, 40, 20, 10, 15, 3, -31]),
  // #188 (7x7, 27 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [9, 1, 17, 18, 4, 7, 12, 11, -5, 4, 1, -1, 3, -10, -3, 7, -18, -12, 16, 14, -12, 11, 14, -2, -15, -13, 16, -12, 10, -17, -15, 1, -17, 12, -10, -6, -4, -12, 2, 15, 1, 17, 14, -1, 15, 6, 14, 16, 18], solution: [1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 0], rowTargets: [61, 1, -14, 12, -15, 14, 30], colTargets: [34, -20, -1, 6, 35, 45, -10]),
  // #189 (7x7, 25 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [15, 15, 12, 8, 5, -18, 6, 5, -2, -5, -16, 15, -10, 5, 9, 3, -15, 5, 2, -11, 5, 12, 2, -9, 8, 17, 8, -15, 6, 9, 8, 16, 5, -18, 1, 10, 2, 2, -4, 1, 11, -11, -17, 3, 10, 6, -2, -7, 16], solution: [0, 0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0], rowTargets: [2, -7, -7, 3, 12, 1, 10], colTargets: [15, 3, -7, 19, 21, -28, -9]),
  // #190 (7x7, 29 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [5, -2, 3, 14, 6, 12, -11, 14, -12, 1, 2, 4, 4, 8, 11, -15, -16, 5, 18, 17, -6, 11, 5, 11, 4, 8, -12, 1, 9, 12, 1, 7, 9, 11, -13, 13, 13, 16, -5, -1, 13, 18, 10, 14, 12, -16, 14, 1, 13], solution: [1, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0], rowTargets: [15, 15, -8, 11, 10, 15, 24], colTargets: [29, -5, 12, 9, 39, 11, -13]),
  // #191 (7x7, 21 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [12, 18, 9, 4, 3, -2, 6, -17, 7, -16, 16, -2, 5, 4, 18, 5, 12, 15, -11, -8, -5, 3, 17, 10, 15, 17, -8, 10, -17, 9, 17, -17, 17, 3, 1, 12, 9, 11, 13, 15, -15, 17, 5, 7, 17, 14, 12, 8, 14], solution: [1, 0, 0, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1, 0, 0, 0], rowTargets: [13, -7, 9, 29, -25, 68, 31], colTargets: [8, 16, 22, 41, 22, -13, 22]),
  // #192 (7x7, 21 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [-5, -4, -11, -17, 12, 10, 13, 18, -10, 4, 11, -7, 10, 14, 10, 2, -10, 10, -10, 9, 14, 2, 15, 12, 18, -4, -13, 13, 5, 16, 6, 12, 4, 2, 11, 16, -18, 3, 12, 2, -2, 11, 7, 6, 16, 14, 14, 18, 18], solution: [1, 1, 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1, 1, 1, 1, 0], rowTargets: [9, 53, 4, -2, 30, -5, 68], colTargets: [18, -1, 9, 32, 22, 25, 52]),
  // #193 (7x7, 27 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [3, -15, -7, 5, 3, 11, 11, 17, 8, -14, 15, 8, -6, 11, 5, 9, 5, 17, 18, 5, 16, -8, 6, 1, -12, 8, 7, 10, 11, 17, 8, -9, 17, -11, 15, -15, 14, 17, -2, -18, 13, -6, 17, 12, 4, -3, -11, 7, -15], solution: [0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 1, 1, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0], rowTargets: [1, 19, 32, 23, 29, -4, 12], colTargets: [-15, 20, 17, 3, 24, 27, 36]),
  // #194 (7x7, 27 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [12, -6, 2, 11, 2, -4, 17, 11, 12, -15, 18, 1, 7, 2, -12, -3, 12, 6, 15, 15, 3, 12, 8, 3, -12, 10, -10, -11, 14, 5, 6, 14, 15, 1, 12, 4, 2, 5, 11, 5, 11, 13, 18, 12, 10, -12, -7, 16, 12], solution: [0, 1, 0, 0, 1, 0, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0], rowTargets: [-4, 11, 30, 15, 32, 11, 7], colTargets: [23, 11, -2, 13, 21, 22, 14]),
  // #195 (7x7, 24 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [-8, 17, -11, 15, 7, 18, 6, 18, -1, 9, 16, -17, -9, -16, 5, -11, -13, 14, 6, -7, 11, 9, 3, -14, 5, 1, -8, -3, 2, 16, 18, 5, -1, 2, -15, -6, 10, 13, 7, -8, 3, -16, 15, 4, 12, 16, 6, 12, 4], solution: [1, 0, 0, 1, 1, 0, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 0, 1, 1], rowTargets: [14, 9, 6, -5, 24, -19, 47], colTargets: [33, -1, 0, 66, -11, 17, -28]),
  // #196 (7x7, 24 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [7, -15, 18, 18, 18, 4, -4, 4, 5, 3, 11, 8, 1, 10, 18, 8, 2, 3, 8, -7, 3, 11, 5, 3, 10, 1, 6, -7, 8, 8, 1, 1, 12, -9, 14, 9, 16, -14, -16, 11, 18, 18, 12, 9, -18, 9, -16, 18, 3], solution: [1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 0], rowTargets: [6, 23, 1, 15, 12, -3, 5], colTargets: [51, 7, 11, -16, -3, 3, 6]),
  // #197 (7x7, 19 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [8, 14, 8, -3, 1, 14, -15, -16, 18, 11, -7, 7, 14, 5, -15, -4, 11, 16, 13, 6, 7, -16, -1, -8, 18, 7, 11, 17, 13, 11, 15, 3, -8, 10, 4, 9, -12, 7, -1, 3, 14, -18, 5, 15, 13, 7, -12, 13, -9], solution: [0, 1, 0, 1, 0, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0, 1], rowTargets: [-4, 39, 23, 26, 16, -23, 7], colTargets: [-47, 42, 31, 34, 7, 30, -13]),
  // #198 (7x7, 25 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [-14, 13, 15, -8, 5, 1, 12, 3, 8, 3, 4, 6, 3, -12, 3, 10, 13, -10, 3, 1, 16, 5, 3, 17, 17, -4, 3, 9, 6, 18, 4, 1, 14, 12, 11, 14, 15, 13, 9, 12, -17, 4, 17, 6, 10, 15, -11, 11, -11], solution: [1, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0], rowTargets: [0, 2, 6, 23, 42, 41, 44], colTargets: [6, 63, 43, 10, 3, 30, 3]),
  // #199 (7x7, 24 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [-4, 15, 6, -9, -9, 2, 13, 6, 2, 8, -4, 10, 2, 7, -10, 6, 9, 1, 11, -12, 5, 14, -5, 10, 10, 12, 17, 1, 14, -6, 12, -11, -9, 10, 10, -18, 1, 2, 8, 1, 17, -18, 17, -5, -17, -14, -5, 3, 15], solution: [0, 1, 0, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1], rowTargets: [19, 20, 27, 15, 26, 9, 13], colTargets: [20, 18, 31, -1, 8, 15, 38]),
  // #200 (7x7, 24 struck, negatives, unique)
  SumStrikeLevel(gridSize: 7, grid: [6, 18, 9, 12, -17, 15, 5, 1, 12, -10, 11, 14, -15, 8, -15, 13, -11, -12, -9, 1, -11, -3, 4, 14, 13, -18, 11, -7, -16, -16, 18, 7, 5, 5, -14, 8, 5, -15, 3, 1, -10, 4, 10, 2, -6, 15, 7, 13, 9], solution: [1, 1, 1, 0, 1, 0, 0, 1, 1, 1, 1, 0, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 0, 0, 1, 0], rowTargets: [16, 7, -31, 42, 7, -6, 9], colTargets: [7, 36, -4, 22, -25, 0, 8]),
```

---

## Appendix B - Masyu 8x8 (30 levels, z3-verified) - levels 151-180

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

---

## Appendix C - Masyu 9x9 (25 levels, z3-verified) - levels 181-205

**All 25 verified-unique-and-distinct 9x9 boards.** Splice into levels 181-205. Each is a z3-proved unique closed-loop whose solution is distinct from every other board.

```dart
// SAFE BACKUP: 25 unique+distinct 9x9 Masyu levels (z3-verified)
  // 9x9 backup #1 (11 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 2, 1, 0, 1, 0, 0, 0, 0, 0]),
  // 9x9 backup #2 (11 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 2]),
  // 9x9 backup #3 (13 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [2, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 2, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 9x9 backup #4 (15 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [0, 0, 0, 2, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 2, 1, 0, 0, 0, 0, 0, 0, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 9x9 backup #5 (12 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 2, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 9x9 backup #6 (14 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 2, 1, 0, 0, 0, 0, 0, 0, 1, 1, 2, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 9x9 backup #7 (12 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0]),
  // 9x9 backup #8 (17 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [2, 1, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 2, 1, 1, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 9x9 backup #9 (13 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 9x9 backup #10 (15 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 2, 1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 9x9 backup #11 (13 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 9x9 backup #12 (14 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 2, 1, 0, 0, 1, 0, 0, 0, 0]),
  // 9x9 backup #13 (16 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 2, 1, 0, 0, 2, 1, 0, 0, 0, 0, 1, 0, 0]),
  // 9x9 backup #14 (19 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 2, 1, 0, 1, 0, 0, 0, 0, 0]),
  // 9x9 backup #15 (14 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [2, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 2, 1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 9x9 backup #16 (15 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [0, 0, 0, 0, 1, 0, 0, 1, 2, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 9x9 backup #17 (22 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [0, 0, 0, 0, 1, 0, 0, 1, 2, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 1, 2, 2, 1, 2, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 2, 1, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 9x9 backup #18 (20 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 1, 0, 1, 1, 2, 1, 0, 0, 0, 2, 1, 0, 0, 1, 2, 0, 0, 0]),
  // 9x9 backup #19 (16 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]),
  // 9x9 backup #20 (20 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [2, 1, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 2, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 9x9 backup #21 (17 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 2, 1, 0, 0, 1, 0, 0, 0, 0]),
  // 9x9 backup #22 (17 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 2, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 0]),
  // 9x9 backup #23 (17 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [0, 0, 0, 1, 0, 0, 0, 1, 2, 0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 9x9 backup #24 (18 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 2, 1, 2, 1, 0, 0, 0, 0, 2, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // 9x9 backup #25 (19 pearls, unique)
  MasyuLevel(gridSize: 9, pearls: [2, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1, 1, 2, 1, 1, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
```
