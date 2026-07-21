# Masyu & Sum Strike — Level / Generation Fixes

**Date:** 2026-07-20
**Applies to:** `v5_Puzzle` branch · `cogniq/lib/screens/games/masyu/` and `.../sum_strike/`
**Covers two owner-reported issues:**
1. Masyu early levels "basically had the same solution."
2. Sum Strike sometimes spawns with "most of the columns already in the correct configuration."

> Everything below is drop-in Dart plus the exact edit locations. The Masyu level set was **generated and double-verified** (two independent solvers agree: all 50 levels have exactly one solution, all 50 solutions are distinct). Nothing here touches game *rules*, other games, challenges, or the stats screen.

---

## 1. Masyu / Pearl Loop

### 1.1 The problem (measured)

Solving every existing early level with a faithful port of the game's own `_solveMasyu`/`validateLoop`:

- **4×4 opening (L1–L15) collapsed to only 6 distinct solution loops.**
  - L2, L3, L4, L5 → identical loop.
  - L8, L10, L12, L13, L15 → identical loop.
- **5×5 repeated it:** L18/25/28/38/40/47 identical; L35/39/49 identical; L16&26; L29&48.
- **Ambiguous levels** (more than one legal loop): L23/L36/L46 had **29 valid loops each**, L24=27, L44=16, plus L7/L34/L45/L50/L11.

Root cause: sparse 2–3-pearl configs don't constrain the loop; on small grids many configs land on the same loop or leave several open. The rules engine is correct — the **level data** was the problem.

### 1.2 The fix — regenerated Levels 1–150 (5×5 + 6×6 + 7×7)

**Design decision (owner request):** the 4×4 opening was dropped and the game rebuilt on **5×5 and up**. A 4×4 has only 213 possible loops, so even distinct solutions look visually similar; 5×5 has ~9,349, which eliminates the "same-shape" feel. (Distinct 4×4 levels *were* achievable — the old repetition was a curation bug, not a hard limit — but bigger gives more visible variety.)

**How they were built:**
- **5×5 (Levels 1–50):** a target loop is chosen with rising length; the minimum pearls that make that loop the *only* legal loop are placed (verified by **exhaustively checking all 9,349 loops** of the 5×5 grid), padded to a target density; every solution loop required distinct.
- **6×6 (Levels 51–100) and 7×7 (Levels 101–150):** full enumeration is intractable at these sizes, so a **randomized loop generator** places all of a loop's pearl candidates and a **z3 SAT solver** confirms exactly one solution (solve → block → check for a second); every solution loop required distinct within its grid.

**Verification:**
- **5×5:** two independent engines agreed — curator (exhaustive enumeration) and a port of the app's DFS solver: `50 levels, 50 distinct solutions, each unique`.
- **6×6 / 7×7:** each level z3-verified unique at generation; all 50+50 distinct. Pearl counts 6–12 (6×6) and 6–15 (7×7).
- The z3 encoding was validated against the 5×5 ground truth (it agreed on every unique level and correctly flagged the old ambiguous ones), so its 6×6/7×7 verdicts are trustworthy.

Pearl density rises within each grid block, and grid size steps up 5×5 → 6×6 → 7×7 across Levels 1–150, so difficulty ramps smoothly with no repeated solution.

**Apply:** in `masyu_levels.dart`, replace the **first 150** `MasyuLevel(...)` entries (Levels 1–150) with the list below. **Levels 151–205 (8×8, 9×9) are being regenerated separately — keep the existing entries for those for now** (they'll be swapped in once generated).

```dart
const List<MasyuLevel> kMasyuLevels = [
  // Level 1 (5x5, 4 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 1, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 2, 0, 0, 0, 0, 0, 0]),
  // Level 2 (5x5, 3 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0]),
  // Level 3 (5x5, 4 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [2, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 2, 0, 0, 0, 0, 0, 0]),
  // Level 4 (5x5, 3 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 1, 0, 0]),
  // Level 5 (5x5, 4 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 0, 0]),
  // Level 6 (5x5, 4 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0, 0, 0]),
  // Level 7 (5x5, 4 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 0, 0]),
  // Level 8 (5x5, 4 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 0, 0, 2, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 0]),
  // Level 9 (5x5, 4 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0]),
  // Level 10 (5x5, 4 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 2, 0, 0, 0, 2, 0, 1, 0, 0]),
  // Level 11 (5x5, 4 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 2, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0]),
  // Level 12 (5x5, 4 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 13 (5x5, 4 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [2, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 2, 0, 0, 0, 0, 0, 0]),
  // Level 14 (5x5, 5 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 1, 0, 0, 1, 0, 2]),
  // Level 15 (5x5, 5 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 2, 0, 0, 0, 0, 0, 0, 2]),
  // Level 16 (5x5, 5 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 2, 2, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 2, 0]),
  // Level 17 (5x5, 5 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 2, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0]),
  // Level 18 (5x5, 5 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [2, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 2]),
  // Level 19 (5x5, 5 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 0, 2, 0, 0, 2, 0, 0, 0, 0, 0, 0, 1, 0, 1, 2, 0, 0, 0, 0, 0]),
  // Level 20 (5x5, 5 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 1, 0, 0, 0, 0, 0, 0, 1, 2, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0]),
  // Level 21 (5x5, 5 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2]),
  // Level 22 (5x5, 6 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 1, 0, 0, 0, 0, 1, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0]),
  // Level 23 (5x5, 6 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 2, 1, 0, 0, 0, 0, 1, 1, 0, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 24 (5x5, 6 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [2, 0, 0, 0, 2, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0]),
  // Level 25 (5x5, 6 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 2, 0, 2, 0]),
  // Level 26 (5x5, 6 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 1, 1, 2, 0, 0, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]),
  // Level 27 (5x5, 6 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 2, 0, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 2, 0, 0, 0, 0, 0]),
  // Level 28 (5x5, 6 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 2, 1, 0, 1, 0, 0, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 29 (5x5, 6 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 2, 0, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0]),
  // Level 30 (5x5, 7 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 2, 0, 0, 1, 1, 1, 0, 0, 0, 0, 2, 1, 0, 0, 2, 0, 0, 0, 0, 0]),
  // Level 31 (5x5, 7 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 2, 1, 0, 0, 0, 0, 0, 0, 2, 1, 0, 1, 0]),
  // Level 32 (5x5, 7 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 2, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0, 2]),
  // Level 33 (5x5, 7 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 0, 2, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 2, 1, 0, 0]),
  // Level 34 (5x5, 7 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 2, 0, 0, 1, 2, 1, 1, 0, 1, 0, 0, 0, 0, 0]),
  // Level 35 (5x5, 7 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [2, 0, 0, 1, 0, 0, 2, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 36 (5x5, 7 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 2, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 2, 1, 1, 0, 0, 0, 0, 0, 0]),
  // Level 37 (5x5, 7 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 2, 0, 0, 0, 0, 1, 2, 0, 0, 1, 2]),
  // Level 38 (5x5, 8 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 2, 1, 2, 0, 0, 0, 0, 0, 1, 0, 2, 1, 0, 0]),
  // Level 39 (5x5, 8 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [2, 0, 0, 0, 0, 1, 0, 0, 0, 2, 2, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0]),
  // Level 40 (5x5, 8 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 2, 0]),
  // Level 41 (5x5, 8 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 2, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 2, 0, 0, 0, 2]),
  // Level 42 (5x5, 8 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [2, 1, 0, 0, 2, 1, 0, 0, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0]),
  // Level 43 (5x5, 8 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 2, 0, 2, 1, 0, 0, 0, 1, 2, 0, 0, 1, 2]),
  // Level 44 (5x5, 8 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 2, 0, 0, 1, 0, 1, 2, 0, 0, 0, 0, 0]),
  // Level 45 (5x5, 8 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [2, 1, 0, 0, 2, 0, 2, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0]),
  // Level 46 (5x5, 9 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [2, 1, 0, 2, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 1, 2, 0, 0, 0, 0, 0, 1, 0]),
  // Level 47 (5x5, 9 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 2, 0, 1, 0, 2, 1, 0, 1, 0]),
  // Level 48 (5x5, 9 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0, 1, 0, 2, 1, 1, 0]),
  // Level 49 (5x5, 9 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 2, 0, 2, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 2, 1, 0, 1, 0]),
  // Level 50 (5x5, 9 pearls, unique)
  MasyuLevel(gridSize: 5, pearls: [0, 0, 1, 2, 0, 0, 1, 0, 0, 0, 2, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0]),

  // Level 51 (6x6, 8 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 2, 1, 0, 0, 0, 2, 1, 1, 0, 0, 0]),
  // Level 52 (6x6, 8 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [2, 1, 1, 0, 0, 0, 1, 2, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 53 (6x6, 8 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 1, 1, 2, 0, 0, 0, 1, 2, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 54 (6x6, 9 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 1, 1, 2, 0, 0, 0, 1, 2, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 55 (6x6, 9 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 2, 1, 0, 0, 1, 0, 1, 2]),
  // Level 56 (6x6, 9 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [2, 1, 0, 1, 0, 0, 1, 2, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 57 (6x6, 9 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 2, 1, 1, 0, 0, 2, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 58 (6x6, 9 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 1, 0, 1, 2, 0, 0, 1, 1, 2, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 59 (6x6, 7 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0]),
  // Level 60 (6x6, 9 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 2, 1, 0, 1, 0, 2, 1, 0, 0, 1, 0]),
  // Level 61 (6x6, 9 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 2, 1, 0, 0, 0, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0]),
  // Level 62 (6x6, 9 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [2, 1, 1, 0, 0, 0, 1, 2, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 63 (6x6, 9 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 2, 1, 1, 0, 0, 2, 1, 0, 1, 0, 0]),
  // Level 64 (6x6, 11 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 2, 1, 1, 2, 1, 0, 1, 0, 1, 1, 2, 0, 0, 0, 0, 0, 0]),
  // Level 65 (6x6, 6 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 66 (6x6, 10 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 2, 1, 0, 0, 1, 0, 1, 2]),
  // Level 67 (6x6, 10 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 1, 0, 1, 2, 0, 0, 1, 1, 2, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 68 (6x6, 10 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [2, 1, 0, 1, 0, 0, 1, 2, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 69 (6x6, 9 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 1, 0, 0, 1, 2, 0, 1, 0, 1, 2, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 70 (6x6, 6 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 71 (6x6, 7 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 1, 2, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 72 (6x6, 7 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 2, 1, 0]),
  // Level 73 (6x6, 10 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 2, 1, 1, 0, 0, 2, 1, 0, 1, 0, 0]),
  // Level 74 (6x6, 7 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 75 (6x6, 8 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0]),
  // Level 76 (6x6, 6 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 77 (6x6, 8 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 2, 1, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 78 (6x6, 7 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0]),
  // Level 79 (6x6, 8 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0]),
  // Level 80 (6x6, 9 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 2, 0, 0, 0, 0, 1, 0, 1, 0, 0]),
  // Level 81 (6x6, 9 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 1, 0, 1, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 82 (6x6, 6 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0]),
  // Level 83 (6x6, 8 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0]),
  // Level 84 (6x6, 8 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 1, 0, 1, 0, 0, 0, 0, 2, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 85 (6x6, 12 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 2, 0, 0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 2]),
  // Level 86 (6x6, 11 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 2, 1, 0, 1, 0, 0, 1, 2, 1, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 87 (6x6, 8 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0]),
  // Level 88 (6x6, 11 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 2, 2, 1, 0, 0, 1, 2, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 89 (6x6, 9 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 2, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0]),
  // Level 90 (6x6, 12 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 1, 0, 1, 2, 0, 0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 91 (6x6, 8 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 2, 1, 0, 0, 0, 1, 0, 1, 0, 0]),
  // Level 92 (6x6, 12 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 1, 2, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 2, 1, 1, 0, 0, 0, 2, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 93 (6x6, 10 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 2, 0, 0, 0, 0, 1, 0, 1, 0, 0]),
  // Level 94 (6x6, 9 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 2, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0]),
  // Level 95 (6x6, 12 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 2, 1, 1, 2, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0]),
  // Level 96 (6x6, 9 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 2, 1, 1, 0, 0, 0]),
  // Level 97 (6x6, 9 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 1, 2, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 98 (6x6, 10 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 2, 1, 1, 0, 0, 0]),
  // Level 99 (6x6, 11 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 2, 1, 0, 1, 0, 0]),
  // Level 100 (6x6, 11 pearls, unique)
  MasyuLevel(gridSize: 6, pearls: [0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 2, 1, 1, 2, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0]),
  // Level 101 (7x7, 9 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [2, 1, 1, 0, 0, 0, 0, 1, 2, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 102 (7x7, 9 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 1, 0, 1, 2, 0, 0, 0, 1, 1, 2, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 103 (7x7, 7 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 0]),
  // Level 104 (7x7, 9 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 2, 1, 0, 1, 0, 0, 2, 1, 0, 0, 1, 0, 0]),
  // Level 105 (7x7, 10 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 1, 0, 1, 2, 0, 0, 0, 1, 1, 2, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 106 (7x7, 10 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 1, 1, 2, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 107 (7x7, 9 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 2, 1, 0, 0, 0, 0, 1, 1, 2]),
  // Level 108 (7x7, 9 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 1, 0, 0, 1, 2, 0, 0, 1, 0, 1, 2, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 109 (7x7, 6 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 110 (7x7, 8 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0]),
  // Level 111 (7x7, 7 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0]),
  // Level 112 (7x7, 10 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 2, 1, 0, 1, 0, 0, 2, 1, 0, 0, 1, 0, 0]),
  // Level 113 (7x7, 10 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 1, 0, 1, 2, 0, 0, 0, 1, 1, 2, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 114 (7x7, 6 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0]),
  // Level 115 (7x7, 11 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 2, 1, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 116 (7x7, 9 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 2, 1, 2, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 117 (7x7, 8 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 2, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0]),
  // Level 118 (7x7, 14 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 1, 2, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 2, 1, 1, 1, 0, 0, 1, 1, 2, 0, 0]),
  // Level 119 (7x7, 8 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 2, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 0]),
  // Level 120 (7x7, 8 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 1, 0, 1, 0]),
  // Level 121 (7x7, 13 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 2, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 1, 2, 1, 0, 0, 2, 1, 0, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 122 (7x7, 11 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [2, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 123 (7x7, 7 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 124 (7x7, 10 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 2, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 125 (7x7, 11 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 2, 1, 0, 1, 2, 0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0]),
  // Level 126 (7x7, 8 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0]),
  // Level 127 (7x7, 11 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [2, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 128 (7x7, 12 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 2, 1, 2, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 129 (7x7, 11 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [2, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 130 (7x7, 10 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 2, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 131 (7x7, 12 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 2, 1, 0, 0, 0, 1, 0, 1, 2, 1, 1, 0, 0, 0, 0]),
  // Level 132 (7x7, 11 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 2]),
  // Level 133 (7x7, 9 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 1, 2, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 134 (7x7, 12 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 2, 1, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0]),
  // Level 135 (7x7, 14 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [2, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 2, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 136 (7x7, 14 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 2, 1, 2, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 2, 1, 1, 1, 0, 0, 1, 1, 2, 0, 0]),
  // Level 137 (7x7, 10 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 2, 1, 0]),
  // Level 138 (7x7, 14 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [2, 1, 0, 0, 0, 1, 0, 1, 0, 0, 2, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 139 (7x7, 12 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 2, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 140 (7x7, 14 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 1, 0, 0, 2, 1, 1, 0, 0, 0, 0, 1, 0, 1, 2, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 2, 1, 0, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 141 (7x7, 12 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 2, 0, 0, 1, 1, 0, 0, 0]),
  // Level 142 (7x7, 9 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0]),
  // Level 143 (7x7, 11 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1, 2, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 144 (7x7, 13 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 1, 0, 0, 1, 2, 0, 0, 1, 2, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 145 (7x7, 14 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [2, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 1, 0, 1, 1, 1, 0, 1, 1, 0, 0, 0, 2, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 146 (7x7, 15 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 1, 1, 2, 0, 0, 0, 0, 1, 2, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 2, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 1, 2]),
  // Level 147 (7x7, 14 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 1, 1, 0, 1, 0, 0, 1, 0, 1, 2, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 2, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0]),
  // Level 148 (7x7, 12 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 2, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  // Level 149 (7x7, 14 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 2, 1, 2, 1, 0, 0, 0, 1, 0, 1, 2, 0, 0, 0, 0, 0, 0, 0]),
  // Level 150 (7x7, 15 pearls, unique)
  MasyuLevel(gridSize: 7, pearls: [2, 1, 1, 0, 0, 0, 0, 1, 2, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 2, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 2, 1, 1, 0, 0, 0, 0]),

  // ---- Levels 151–205 (8x8, 9x9): regenerating tomorrow — keep existing entries for now ----
];
```

> Optional but recommended: run the same curator on the 6×6+ block later to guarantee uniqueness there too. Full-loop enumeration is too large past 5×5, so that pass uses a randomized loop generator + DFS uniqueness check instead. Not required to fix the reported issue (which was the opening levels).

### 1.3 Companion fix — stop solving on the UI thread

Separate from the data: `_solveMasyu()` (a brute-force DFS) runs **synchronously in `_setupLevel` on every level load** (`masyu_screen.dart:103`). On the 8×8/9×9 levels this can stall a frame and, when it can't finish, silently disables hints. Make it lazy — solve only when the player first taps Hint.

**In `_MasyuScreenState`, add a flag:**
```dart
bool _solveAttempted = false;
```

**In `_setupLevel()`**, replace:
```dart
_solutionEdges = _solveMasyu() ?? {};
```
with:
```dart
_solutionEdges = {};
_solveAttempted = false; // solution computed lazily on first hint
```

**Add a helper:**
```dart
void _ensureSolution() {
  if (_solveAttempted) return;
  _solveAttempted = true;
  _solutionEdges = _solveMasyu() ?? {};
}
```

**At the top of `_showHint()`**, before the `if (_solutionEdges.isEmpty)` check:
```dart
_ensureSolution();
```

This removes the per-load hang entirely (nothing solves unless a hint is requested). *Further hardening (optional):* move `_solveMasyu` to a top-level function and call it via `compute()` so even the hint press never blocks the UI; or, best long-term, store each level's precomputed solution in the level data and skip runtime solving.

---

## 2. Sum Strike

### 2.1 The problem (measured)

Sumplete-style: strike cells so each row/column sum equals its target. The board starts all-kept, so a line is **already satisfied** if the solution keeps every cell in it. The generator (`sum_strike_screen.dart:79–174`) picks the solution mask as `rand > 0.4` and only guards a *lower* bound on kept cells — nothing forces a line to need a strike.

Simulated over 200,000 generated boards:

| Grid | Boards with ≥1 line already correct | Boards with *most* columns pre-satisfied |
|------|-------------------------------------|------------------------------------------|
| **3×3** (Levels 1–5) | **69.7 %** | 12.3 % |
| **4×4** (Levels 6–10) | 60.7 % | 0.8 % |
| **5×5** (Levels 11+) | 51.1 % | 0.4 % |

That's the pre-solved feel you noticed, strongest on the 3×3 openers.

### 2.2 The fix — require every line to need action

Constrain the solution mask so **every row and every column has at least one kept cell AND at least one struck cell.** No line can start already-satisfied (all-kept) or trivially satisfied (all-struck).

**Add this helper to `_SumStrikeScreenState`:**
```dart
// Non-trivial iff EVERY row and EVERY column has at least one kept AND at least
// one struck cell — so no line starts already-satisfied or all-struck.
bool _isNonTrivialMask(List<bool> sol) {
  for (int r = 0; r < _gridSize; r++) {
    bool anyKept = false, anyStruck = false;
    for (int c = 0; c < _gridSize; c++) {
      if (sol[r * _gridSize + c]) {
        anyKept = true;
      } else {
        anyStruck = true;
      }
    }
    if (!anyKept || !anyStruck) return false;
  }
  for (int c = 0; c < _gridSize; c++) {
    bool anyKept = false, anyStruck = false;
    for (int r = 0; r < _gridSize; r++) {
      if (sol[r * _gridSize + c]) {
        anyKept = true;
      } else {
        anyStruck = true;
      }
    }
    if (!anyKept || !anyStruck) return false;
  }
  return true;
}
```

**Then update both solution-mask generators.** In the main attempt loop (~line 104–109) **and** the fallback block (~line 145–150), replace:
```dart
List<bool> solution = [];
int retries = 0;
do {
  solution = List.generate(total, (_) => rand.nextDouble() > 0.4);
  retries++;
} while (solution.where((k) => k).length < total * 0.3 && retries < 20);
```
with:
```dart
List<bool> solution = [];
int retries = 0;
do {
  solution = List.generate(total, (_) => rand.nextDouble() > 0.45);
  retries++;
} while (!_isNonTrivialMask(solution) && retries < 40);
```

Notes:
- The gate (`_isNonTrivialMask`) is the real fix; nudging the keep-probability from 0.6 to 0.55 (`> 0.45`) just leaves a few more struck cells so the constraint is satisfied faster.
- `_countSumStrikeSolutions` still guarantees a *unique* solution afterward, so puzzles stay well-formed.
- 40 retries is ample: for 3×3–5×5 a non-trivial mask is found almost immediately.

### 2.3 Optional — off-thread the uniqueness solver

`_countSumStrikeSolutions` (`sum_strike_screen.dart:226`) runs synchronously inside `setState` with up to 50 attempts. Pruning keeps it fast today, but for consistency it can be moved to a `compute()` isolate later. Low priority; the generation fix above is the one that resolves the reported issue.

---

## 3. Difficulty scaling (endgame) — same Rotation Model as the other games

The fixes above make Masyu and Sum Strike *correct*; this section makes them *scale* — using the same "introduce a lever per stage → rotate old grids back in at the extreme end" model documented in `difficulty_scaling_part_2.md`. Both are deduction puzzles, so difficulty should come from **logic depth**, not just grid size.

### 3.1 Masyu / Pearl Loop

**Current scaling:** grid 5×5 → 9×9 + pearl count/config; difficulty is essentially grid size, and it tops out at 9×9. Solution complexity (how winding the loop is, black-vs-white mix) is not tuned.

| Lever | What it does |
|-------|--------------|
| A — grid size | 5×5 → 9×9 (caps) |
| B — pearl sparsity | fewer clues relative to grid = harder deduction (must stay unique) |
| C — black-pearl ratio | black rules (turn + straight both sides) are trickier than white; more blacks = harder |
| D — solution tortuosity | a winding loop with many turns/detours is far harder to deduce than a near-rectangle — tune in generation |
| E — required-technique tier | rate by hardest solving technique needed (forced pearl moves → edge/segment propagation → no-subloop/connectivity chains) — solver-dependent |
| F — soft timer | late/endgame |

| Stage | Levels | Grid | New lever | Notes |
|-------|--------|------|-----------|-------|
| 0 — Learn | early | 5×5 | few pearls, simple loops | onboarding |
| 1 — Grid growth | mid | 6×6 → 9×9 | A | base ramp (the regenerated set); caps 9×9 |
| 2 — Pearl sparsity | — | 9×9 | B | grid capped; sparser clues carry difficulty |
| 3 — Black-heavy + tortuosity | — | 9×9 | C + D | trickier pearls, windier solutions |
| 4 — Technique tier | — | 9×9 | E | deeper deduction chains |
| 6 — Rotation | extreme | rotates 5×5–9×9 | F + rotation | endgame |

**Endgame:** grid rotates 5×5–9×9 × a rotating 2–3 of {sparse pearls, black-heavy, high tortuosity, timer}. A sparse, black-heavy 6×6 with a winding solution is a different hard than a big 9×9. **Uniqueness stays mandatory** (it's a deduction puzzle — the regenerated levels already enforce it).

### 3.2 Sum Strike (Sumplete)

**Current scaling:** grid 3×3 → 5×5 only; difficulty is grid size (plus the §2 fix that stops pre-solved lines). Small cap, and the numbers/strike-ratio never change.

| Lever | What it does |
|-------|--------------|
| A — grid size | 3×3 → 5×5 (extend cap to 6×6/7×7) |
| B — number range | wider values (1–9 → 1–15/1–20) = harder mental sums |
| C — negative numbers | a Sumplete variant with negatives — sums reachable many ways, big difficulty jump |
| D — strike density | push toward ~50% struck (the hardest ratio; the §2 gate already guarantees every line needs action) |
| E — required-deduction tier | simple row/col elimination → cross-constraint reasoning — solver-dependent (uniqueness solver already exists) |
| F — soft timer | late/endgame |

| Stage | Levels | Grid | New lever | Notes |
|-------|--------|------|-----------|-------|
| 0 — Learn | early | 3×3 | small numbers, sparse strikes | onboarding |
| 1 — Grid growth | mid | 4×4 → 6×6 | A (extend past 5×5) | base ramp |
| 2 — Number range | — | 6×6 | B (widen values) | bigger sums |
| 3 — Negatives | — | 6×6 | C | sums reachable many ways |
| 4 — Deduction tier | — | 6×6 | D + E | ~50% density, cross-constraint logic |
| 6 — Rotation | extreme | rotates 3×3–6×6 | F + rotation | endgame |

**Endgame:** grid rotates × a rotating 2–3 of {wide number range, negatives, ~50% strike density, timer}. A negatives 4×4 with a tight timer is a different hard than a wide-range 6×6.

> Both are **solver-dependent** for the technique tiers (each already has a uniqueness solver to build on). Full lever tables for all 16 games live in `difficulty_scaling_part_2.md`; these two are captured here since they share this doc's fix work.

---

## 4. Verification summary

| Fix | How verified |
|-----|--------------|
| Masyu L1–50 (5×5) | Curator (exhaustive: all 9,349 loops of the 5×5 grid) → 50 unique, 50 distinct. Independent DFS cross-check → `failures=0`. |
| Masyu lazy solve | Logic change only; behaviour identical except solving is deferred to first hint. |
| Sum Strike gate | Constraint provably eliminates all-kept/all-struck lines; simulation showed the untreated generator failed 50–70 % of the time. |

**Scope respected:** no changes to Masyu/Sum Strike *rules*, no other games, no challenges, no stats screen. Only level data + generation constraints + a lazy-solve refactor.
