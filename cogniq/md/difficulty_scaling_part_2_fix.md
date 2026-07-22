# Difficulty Scaling — Part 2 FIX & Implementation Plan

> **Companion to:** `difficulty_scaling_part_2.md` (the original lever/rotation design) and
> `masyu_sum_level_fix.md` (Masyu + Sum Strike).
> **Reviews commit:** `3963edd` "Add new modifiers (Testing)" on branch `v5_Puzzle`.
> **Audience:** this document is written so a reading agent (Gemini) can fully understand the
> problems and a planning agent (Opus) can turn it into a correct, ordered implementation plan.
> Every fix below names the file, the symptom, the root cause, and the required end-state.

---

## 0. How to read this document

- **Section 1** = the two root causes that explain ~80% of all reported problems. Fix these first at the *system* level.
- **Section 2** = the global design rules every per-game fix must obey.
- **Section 3** = shared systems to (re)build once: the Modifier Rotation Engine v2, and the Hard-Timer framework.
- **Section 4** = P0 crashers / unwinnable boards. These make games literally unplayable — do them before any tuning.
- **Section 5** = per-game specification. One block per game: *symptom → root cause (file/line) → required fix → modifier set → timer → grid policy.*
- **Section 6** = open design decisions (defaults are chosen; confirm or override).
- **Section 7** = implementation phases and order.
- **Section 8** = acceptance / QA checklist per game.

All paths are repo-relative to `cogniq/lib/`. Line numbers are as of commit `3963edd` and are guides, not guarantees.

---

## 1. The two root causes (read this first)

### RC-1 — "Only the timer modifier ever shows up."
Reported by the player for nearly every game. **Cause:** the timer is the *only always-on lever*.
Every other modifier is gated either to a narrow level band (e.g. distractors only appear at L45–59) or
behind a combo formula like `combo = (level - 90) % 6`, where most values resolve to **a single lever or none**.
So when the player jumps to L104/L110 they land in a "trough" and see nothing but the ever-present clock.
**The rotation is not actually surfacing a visible 2–3 levers per level.**

> **This is the #1 fix. It is shared across every game.** It is solved once in the Rotation Engine v2 (Section 3.1),
> then each game supplies its own modifier pool. Do NOT fix this per-game with ad-hoc `if` bands again.

### RC-2 — "Timer hits 0 and the level does not restart."
Every timer was implemented as a **soft bonus** (`+5` points, no fail state). A clock with no consequence is decoration.
**Required:** a **hard timer** — reaching 0 restarts the level (fresh attempt, same level index / same board where the board is deterministic).
See Section 3.2 for the framework and the per-game on/off policy.

### Corollary — "High levels feel too easy / grids too small."
(Reported for Grid Path, Sudoku, Pattern Lock, Colour Flood, Circuit Guide.)
The rotation cycles grid size **down** to its smallest value (`5 + x%5`, `3 + …`, etc.) without compensating,
so L110 can be a bare 3×3 or 6×6. **Rule (see 2.3):** rotation may shrink the grid **only if it simultaneously
stacks more modifiers** — difficulty rides a rising floor and never drops to "small and bare."

---

## 2. Global design principles (every fix must obey these)

1. **Every non-tutorial level shows a deliberate 2–3 visible modifiers**, chosen by the rotation engine — never "just the timer," never "nothing."
2. **The timer is one modifier in the pool, not a permanent overlay.** When it is active it is a *hard* timer (RC-2). Some levels have it, some don't — that is what lets the other levers become visible.
3. **Rising difficulty floor.** A later level is never *easier* than an earlier one. Piecewise formulas must be **continuous at the seam** (no reset-to-easiest at L30). If the grid shrinks, modifier count rises to compensate.
4. **No degenerate fallbacks.** When a generator's constraint gate fails, it must fall back to a *valid, on-difficulty* board — never a trivial Level-1 board, never `List.generate(len,(i)=>i)`, never "the easiest board found."
5. **Solvability is guaranteed before ship.** Any procedural generator must emit a board that is (a) solvable and, where the game's win-check assumes it, (b) uniquely solvable. A hard timer may only be enabled on a game once its boards are guaranteed solvable.
6. **No debug tools in production.** The "Jump to Level" dialog (tap the level indicator → jump to any level 1–150) is shipped in every screen. Gate it behind a debug flag or remove it — it lets players skip into broken endgame states and its "1–150" label contradicts infinite rotation.
7. **Determinism for rotation levels** stays as-is (`RotationEngine.getDeterminism(gameId, level)`, seeded at load, not in `build()`). This part works. Minor: the seed is `gameId.hashCode ^ levelIndex`; the low-bit XOR gives adjacent levels near-identical seeds. Prefer a stronger mix (e.g. `Object.hash(gameId, levelIndex)` or `gameId.hashCode * 1000003 ^ levelIndex`).

---

## 3. Shared systems to build once

### 3.1 Modifier Rotation Engine v2 (fixes RC-1)

**Goal:** given a `gameId` and `level`, deterministically select **which** modifiers are active and the grid config,
such that (a) 2–3 modifiers are visible on every endgame level, (b) difficulty floor rises, (c) small grids come with more modifiers.

**Design:**
- Each game declares an ordered **modifier pool**, e.g. `['density','distractor','variant','timer', ...]`.
- Replace the current `combo = (level - 90) % 6` single-index scheme with a **selection of k modifiers** where `k = 2 + (stage growth)`:
  - Compute a rotating **subset** of size `k` from the pool (e.g. round-robin windows over the pool, or a deterministic combination index) so consecutive levels show *different but overlapping* sets — not "one lever then all levers."
  - Guarantee the subset size is **≥2** and **≤3** in mid rotation, growing toward 3 in late rotation.
- Grid size is chosen from a **difficulty-weighted** set; when a smaller grid is selected, force `k = 3` (max modifiers) so it isn't trivial.
- The **timer** is a member of the pool, not a global overlay. It appears in roughly 1/3–1/2 of rotation levels (per game, see Section 5), and when present it is hard (3.2).

**Acceptance:** print/log the active modifier set for levels 90–150 of each game; every level must list ≥2 named modifiers, and no 6-level window may be "single lever, single lever, ALL levers, single…" (the current sawtooth).

### 3.2 Hard-Timer framework (fixes RC-2)

- Add a shared helper: when the countdown reaches 0 → **restart the current level** (regenerate deterministically / reset state), do not silently stop.
- Per-game **duration** is explicit, not a flat `100s` or `30 + gridSize*15`. See each game in Section 5. Key ones the player called out:
  - **Odd Colour Out:** ~**25 s** (snap-judgment game; 100 s is meaningless).
  - **Chimp Test:** **5 s × count** (18 numbers → 90 s).
  - **Spectrum/Hue:** **5 s × tiles** (96 tiles → 480 s; today it wrongly gives ~90 s).
- **On/off policy (recommended default — see Decision D1):** hard timer on the **fast / perception** games (Odd Colour Out, Chimp, Spectrum, Colour Flood); **soft-or-none** on the **deliberate logic** games (Sudoku, Killer Sudoku, Bridges, Masyu) where a countdown fights the puzzle's nature.
- **A hard timer is enabled on a game only after that game's boards are guaranteed solvable** (principle 5).

### 3.3 Safe-fallback contract (principle 4)
Every generator's failure path must call a validated "make a guaranteed-valid on-difficulty board" routine. Track and log fallback-hit rate; if a game hits fallback often, the constraint gate is too strict and must be loosened, not masked by a trivial board.

---

## 4. P0 — Crashers & unwinnable boards (fix FIRST)

| # | Game | File | Symptom | Root cause | Fix |
|---|------|------|---------|-----------|-----|
| P0-1 | **Colour Link** | `screens/games/beta/numberlink_beta.dart` | L110 and most levels (incl. daily) are **unwinnable**. | Generator (gen loop ~181–248) **dropped the full-partition acceptance check** `board.every((c)=>c!=0)`; acceptance is now just `if (success)` (~223) where paths grow a *fixed* length and stop early, leaving empty cells. But win check (~419) still requires a **complete fill** `totalPathCells == gridSize*gridSize - wallCells`. No full-fill solution exists. | Restore full-partition acceptance: only accept a generated board whose solution paths **fill every non-wall cell**. Grow paths until the board is partitioned, as the pre-rewrite greedy loop did. |
| P0-2 | **Masyu / Pearl Loop** | `screens/games/masyu/masyu_screen.dart` | Game **crashes/freezes** entering L50/51 and beyond. | `_generateEndgameLevel` (~198) runs a **synchronous exponential solver** (`_countMasyuSolutions`, full loop enumeration) inside up to **500 attempts** in `_setupLevel`, on grids rotating to 9×9 — on the UI isolate, on every level load ≥31 → ANR/freeze. Also the z3-verified curated levels **31–150 are bypassed** (normal play reads `_kLevels` only for `_currentLevel < 30`). | Do **not** run any solver on level load. Use the curated `_kLevels` for L1–150 (they are the z3-verified unique set — 205 entries, 50/50/50 for 5×5/6×6/7×7). Only run the (already-correct lazy) `_ensureSolution()` on **hint**. If a procedural endgame is kept beyond L150, move solving off the UI isolate and cache. |
| P0-3 | **Killer Sudoku** | `screens/games/beta/killer_sudoku_beta.dart` | **RangeError crash** the instant a player completes any 9×9 board. | `_checkSolution` (~295) hardcodes `int boxRows = 2;`, so the 9×9 box loop reads past the 81-element grid; box check is also 2×3 while the generator built 3×3. | `boxRows = _gridSize == 9 ? 3 : 2;` (mirror the generator's `_isValidSudokuPlace` which already uses `size==9?3:2`). |
| P0-4 | **Killer Sudoku** | same | Puzzles are **ambiguous** (many solutions), guessy. | `_generateProceduralLevel` carves cages but never verifies uniqueness, and most levels have **0 givens**. Violates the doc's one hard requirement. | Add a solver-based **uniqueness check** (accept board only if exactly one solution). Give an appropriate number of givens (many early → thinning), so early procedural levels aren't ambiguous. |
| P0-5 | **Global timer** | all screens | Timer reaches 0, **nothing happens**. | Timers are soft bonus-only. | Implement Hard-Timer framework (3.2): 0 → restart level. |
| P0-6 | **Bridges** | `screens/games/bridges/bridges_screen.dart` | Dragging island→island **creates no bridge** (only tap-tap works). | Bridge-build logic moved into an `onTapUp` branch (~422) that the gesture arena never reaches after a pan; `onPanEnd` (~413–416) clears `_dragStartIsland` without building. Dead code. | Restore the bridge toggle in `_onPanEnd` (build between `_dragStartIsland` and the released island). |

---

## 5. Per-game specifications

> Legend — **Fix** = required end state. **Modifiers** = the pool the Rotation Engine v2 should surface (2–3 visible/level).
> **Timer** = hard-timer duration + whether enabled. **Grid** = size policy at high levels.

### 5.1 Grid Path (Zip) — `screens/games/grid_path/grid_path_screen.dart`
- **Symptom:** L110 too easy — 4 numbers, and the **X/wall tiles make it easier**. Only the timer modifier is present.
- **Root cause:** difficulty currently leans on walls; walls *constrain* the path (fewer options) = easier. Waypoints correctly thin, but geometry lever (`level>=140` corner hack, ~360–372) barely fires; timer (~597–614) is the only visible modifier.
- **Fix:** **Remove the X/wall tiles entirely** — an open board with sparse waypoints forces more branching = more thinking. Difficulty axes become: sparser waypoints + bigger grid + non-rectangular shapes.
- **Modifiers pool:** `waypointSparsity`, `gridSize`, `nonRectShape`, `timer`. (Drop walls/barriers.)
- **Timer:** enabled, moderate (deliberate-ish game — keep generous or make optional per D1).
- **Grid:** keep the correct waypoint-thinning; at high levels prefer **larger** open grids; small grids only with sparser waypoints. Keep connectivity validation; keep **no unique-solution enforcement** (existing correct decision).

### 5.2 Odd Colour Out — `screens/games/odd_color_out/odd_color_out_screen.dart`
- **Symptom:** delta "keeps shifting," sometimes easy (dark colours easy to spot). Only timer modifier. Timer 100 s is way too long.
- **Root cause:** **delta discontinuity** — pre-30 branch bottoms at `0.04` (hard) at L29; L≥30 branch = `0.012 + 0.088*(30/(30+level))` = **0.10 (easiest)** at L30, not hard again until ~L150. Determinism only applied at L≥90 (~105–107). Hue/noise/gradient levers don't camouflage the outlier's actual channel.
- **Fix:** make delta **monotonic and continuous at L30** (no reset). Ensure noise/gradient perturb the **same channel** as the outlier (lightness gradient does nothing to hide a hue outlier). Surface real modifiers.
- **Modifiers pool:** `deltaTightness`, `hueChannel`, `noise`, `gradient`, `timer`. Rotate 2–3.
- **Timer:** hard, **~25 s**.
- **Grid:** fine as-is; keep max 9×9.

### 5.3 Chimp Test — `screens/games/patches/patches_screen.dart`
- **Symptom:** wants **numbers to stay visible** with a **running clock** (pressure ramps). Timer = **5 s × count** (18 → 90 s). Decoy/X tiles are pointless because a wrong tap already restarts the level. Only timer + wrong-tile modifiers seen.
- **Design change (Decision D2 — confirm):** base mode becomes **visible-numbers + running clock** (a speed/pressure task). The classic **"numbers hide"** becomes *one rotating modifier*, not the base.
- **Fix:** implement visible + 5 s×count hard timer; **remove decoy tiles**; keep the sawtooth count (climb ~5→15, reset + add a modifier per cycle — already correct in `_getChimpConfig`). Fix the count-formula discontinuity at L121+ (`index>=120: 4+(index-120)%12` desyncs from the period-11 modifier cycle). Make the in-play shuffle deterministic (currently bare `Random()`).
- **Modifiers pool:** `numbersHide` (classic memory), `spatialSpread`, `positionShuffle`, `timer(5s×count)`. Rotate 2–3.
- **Timer:** hard, **5 s × count**.

### 5.4 Star Battle / Queens — `screens/games/star_battle/star_battle_screen.dart`
- **Symptom:** L110 "feels wrong / unsolvable at first glance"; must not lag/crash loading high levels.
- **Root cause:** an **anti-knight constraint was invented** (`_check`, `placeTwoStars`, `isSafe2`, tutorial text) — not real Star Battle, makes valid boards look wrong. Hints are **dead on all 1★ endgame levels** (`_solveQueens` ~835/839 gated on `_isEndgame` instead of `_useTwoStars` → runs a 2★ solver on 1★ boards → returns null → hint no-ops). The 2★ **fallback can emit an unsolvable board** at L60–89 (diagonally-adjacent seeds violate the no-touch rule).
- **Fix:** **remove the anti-knight rule** (revert to classic: 1★/2★ per row/col/region, no two adjacent). Change the hint gate to `if (_useTwoStars)`. Replace the 2★ fallback with a guaranteed-solvable seeding. **Bound the contortion generator** (cap attempts, time-box) so load never lags/crashes.
- **Modifiers pool:** `gridSize`, `twoStarMode`, `regionContortion`, `timer`. Rotate 2–3; introduce 2★ gradually (not a hard 1★→2★ jump at L60).
- **Timer:** soft/optional (deliberate logic game — see D1).

### 5.5 Mine Finder — `screens/games/mine_finder/mine_finder_screen.dart`
- **Symptom:** high levels too easy; **remove the fog modifier** (unwanted). For hidden mine-count, add a stipulation such as **"must flag all mines for the level to auto-clear."**
- **Root cause:** endgame branch (~250–262) **resets grid to 8×8 at L31**, a cliff *down* from the base ramp (`5 + idx//3`, ~15×15 by L33). No no-guess generator → 50/50 coin-flips remain. Fog added at 75–90.
- **Fix:** **remove fog.** Fix the cliff — endgame must continue *up* from the base ramp, not reset to 8×8. Implement a **no-guess generator** (solver-verified: solvable by logic without guessing) — this is Mine Finder's headline fix and removes the luck. For the hidden-count modifier, use the **flag-all-to-clear** rule (deterministic, skill-based). *Avoid the "show ? instead of the neighbour number" idea* — it reintroduces guessing, which is the exact thing this game should move away from.
- **Modifiers pool:** `gridSize/mineDensity`, `limitedFlags`, `hiddenCount(+flag-all-to-clear)`, `timer`. Rotate 2–3; make modifiers **cumulative then rotate** (they currently replace each other).
- **Timer:** soft/optional (D1).

### 5.6 Spectrum / Hue — `screens/games/spectrum/spectrum_screen.dart`
- **Symptom:** timer far too tight — 96 tiles at ~90 s. Wants **5 s × tiles** (96 → 480 s).
- **Root cause:** timer formula too small; the **index-based win-check** (~650–661, compares `correctRow/correctCol` not colour value) — the "fix first" bug — is still present; the move-limit reset regenerates the **identical deterministic board** → possible infinite loop; distractor tiles use fully random hues.
- **Fix:** timer = **5 s × tiles**; fix win-check to compare by **colour value** (accept a tile that has the right colour even if index differs); on move-limit exhaustion, restart with a *fresh* attempt rather than the identical unsolvable board; don't stack move-limit *and* timer (pick one, per doc).
- **Modifiers pool:** `gridSize`, `fewerAnchors`, `gradientComplexity/3-colour`, `distractors`, `timer|moveLimit` (exactly one). Rotate 2–3.
- **Timer:** hard, **5 s × tiles**.

### 5.7 Sudoku — `screens/games/sudoku/sudoku_screen.dart`
- **Symptom:** L104 is a **simple 6×6**. Only timer modifier.
- **Root cause:** endgame branch (`index>=30`) forces **6×6** for L30–44 then 9×9 (player sees 9×9→6×6→9×9 regression); the doc's headline **required-technique tier** is not implemented; the **eclipse/blackout** memory gimmick (~1160+) was repurposed as the core scaling axis.
- **Fix:** **9×9 is the floor** past the intro — never rotate down to 6×6 at high levels. Difficulty comes from **clue-thinning + required-technique tier** (needs a technique-ladder solver), not grid shrink. Demote eclipse to *one rotating modifier*, not the main axis.
- **Modifiers pool:** `clueThinning/techniqueTier`, `variantRule`, `eclipse`, `timer`. Rotate 2–3.
- **Timer:** soft/optional (D1).

### 5.8 Word Hive — `screens/games/word_hive/word_hive_screen.dart`
- **Symptom:** further levels not possible — letter count is small but game demands 6-letter words. Only timer modifier.
- **Root cause:** `_minWordLength` ramps to **6** at L60–89; if the hand-authored letter set lacks 6-letter words, `validCount → 0` and `_targetCount → 0` → instantly-won or unwinnable soft-lock. Difficulty also *drops* after L90 (min length rotates back to 4). A `whisper` masking lever appears at L120 (unprescribed).
- **Fix:** **clamp `_minWordLength` to what the current letter set actually supports** — never demand a length that yields fewer than, say, N valid words. Scale `_targetCount` to available words with a sane floor. Keep the correct decision that the **"hide word count" lever was rightly NOT added.** Restore the removed shuffle/skip button if it was needed.
- **Modifiers pool:** `minWordLength(clamped)`, `targetCount`, `whisper(optional)`, `timer`. Rotate 2–3.
- **Timer:** hard-optional (word game — keep generous).

### 5.9 Pattern Lock — `screens/games/beta/pattern_lock_beta.dart`
- **Symptom:** L110 too easy (3×3 grid, 4 dots). **Reverse navigation doesn't make sense.** Only timer.
- **Root cause:** the agreed **player-controlled "Ready/Done" hide was NOT built** — the flawed auto-timer (`durationSeconds = max(1.5, targetLength*0.6)`) was kept, and a *second* reproduction timer added. Grid rotates **down to 3×3** at L90+. Degenerate fallback `List.generate(len,(i)=>i)` (not a valid path) fires on small grids. `_transformType` only ever 1|2 (mirror-H case 3 is dead). Reverse-draw mode is confusing.
- **Fix:** **remove reverse-draw.** Build the **player-controlled hide** (show pattern → player taps "Ready/Done" to hide → reproduce), with a ~60 s AFK backstop; delete the auto-hide timer. **Grow the grid at high levels** (3×3/4-dot is trivial at L110). Replace the degenerate fallback with a valid self-avoiding path. Optionally reintroduce a tightened memorize timer as *one* rotating modifier, not always-on.
- **Modifiers pool:** `pathComplexity(turns)`, `distractorDots`, `gridSize`, `boardTransform(rotate)`, `memorizeTimer`. Rotate 2–3.
- **Timer:** the memorize timer becomes a modifier; no always-on solve clock.

### 5.10 Colour Link — `screens/games/beta/numberlink_beta.dart`
- **Symptom:** L110 (and later) **not possible**. Only timer modifier.
- **Root cause:** **P0-1** (unwinnable boards — dropped full-fill acceptance). Also endgame rotation pairs tiny grids with too many colours (grid `%5` and colours `%4` desync), and the fallback (~236–248) collapses to a static trivial 4×4/2-colour board.
- **Fix:** **P0-1 first** (restore full-partition acceptance). Then fix rotation so grid/colour counts are sensibly paired (more colours only on larger grids); replace the trivial fallback with a valid on-difficulty board. Remove the dead base branches (~134–140).
- **Modifiers pool:** `gridSize/pairCount`, `walls`, `tortuosity`, `timer`. Rotate 2–3.
- **Timer:** hard-optional.

### 5.11 Colour Flood — `screens/games/beta/color_flood_beta.dart`
- **Symptom:** "great," but at L68/69 the player still has **2–3 moves leftover** (too loose). Only timer modifier otherwise.
- **Root cause:** the move-**buffer is permanently 0** in all endgame branches (doc wanted a `+3 → +1 → +0` ramp), but the board-picker fallback was **inverted** (`if (opt < bestMoves)` keeps the *minimum-optimal* / easiest board), and `minOptimal = 18` for L30–44 is rarely met by a random board in 20 attempts → most levels fall through to the easy fallback, so despite buffer 0 the board is trivial and the player finishes early with moves to spare.
- **Fix:** restore the **"closest to target optimal" tiebreak** (stop picking the easiest board); implement the **`+3 → +1 → +0` buffer ramp**; ensure the optimal-move band is actually reachable in the attempt budget. Surface real modifiers.
- **Modifiers pool:** `buffer`, `colourCount`, `centerSeed`, `obstacles`, `timer`. Rotate 2–3. (Decouple grid/colour rotation — currently lockstep.)
- **Timer:** hard (fast game, D1).

### 5.12 Circuit Guide — `screens/games/beta/circuit_guide_beta.dart`
- **Symptom:** levels ~60–70+ have a **red lock** causing weird connections; **bulbs/targets are mostly in the same row/col**; board is **small even though the screen is free**. Only timer modifier.
- **Root cause:** the **"locked wires" lever** (`lockCount = 1 + gridSize~/2`, sets tiles to their solution and locks them) pre-solves tiles → the weird forced connections, *and* it makes puzzles easier, *and* it runs alongside the always-on timer. `combo = (level-90)%6` stacks all levers at combo 4 (spike) and one at combos 0/1/3/5 (trough). Grid `5 + (level-90)%4` stays small; targets not spread. Dead ramp ladder in `_loadLevel`.
- **Fix:** **remove the locked-wires lever.** **Spread the target bulbs** (avoid collinear placement). **Grow the board** to use the available screen. Rebalance combos to a steady 2–3 via Rotation Engine v2. Remove dead code.
- **Modifiers pool:** `tortuosity`, `junctionDensity`, `scrambleDepth`, `decoyWires`, `timer`. Rotate 2–3.
- **Timer:** hard-optional.

### 5.13 Masyu / Pearl Loop — `screens/games/masyu/masyu_screen.dart`, `masyu_levels.dart`
- **Symptom:** **crashes** entering L50/51+.
- **Root cause / Fix:** **P0-2** (no solver on load; use curated `_kLevels` for L1–150). The level *data* is correct (`masyu_levels.dart`: 205 entries, 50/50/50 for 5/6/7; 8×8/9×9 L151–205 intentionally deferred). If procedural endgame is retained past L150, it must guarantee a **unique** solution (the reason we used z3 for 1–150) and must not solve on the UI isolate.
- **Modifiers pool (endgame beyond curated set):** `gridSize`, `pearlSparsity`, `blackRatio`, `tortuosity`. Rotate 2–3.
- **Timer:** none/soft (deliberate loop puzzle — the added L31 countdown is off-brief).

### 5.14 Bridges — `screens/games/bridges/bridges_screen.dart`, `bridges_levels.dart`
- **Symptom:** "perfect," but wants the **rotation modifier** added to make it even better.
- **Root cause / notes:** the 110 curated levels are preserved (good) and ~40 hand-authored 7×7/8×8/9×9 levels appended. But: **drag-to-connect is dead (P0-6)**; a **hidden-clue lever hides up to 80% of island numbers** at L90+ and a **fog lever** exist (~178–216) — these make Hashi non-deducible (pure guessing).
- **Fix:** **fix P0-6 (drag).** **Remove the 80%-hidden-clue and fog levers** (keep Bridges clean/deducible). **Add proper rotation** — ideally a procedural generator wrapped around the existing `_SolverIsland` with no-guess + uniqueness filtering; at minimum, rotate the curated + appended levels with *legitimate* modifiers (grid size, island density), not hidden-clue/fog.
- **Modifiers pool:** `gridSize`, `islandDensity`, `maxBridgeMultiplicity`. Rotate 2–3.
- **Timer:** none/soft (D1).

### 5.15 Sum Strike — `screens/games/sum_strike/sum_strike_screen.dart`
- **Symptom:** wants the **target row/column headers to be a distinct colour** (visual clarity).
- **Status:** the "already-solved" bug is **correctly fixed** (`_isNonTrivialMask` gates both main and fallback loops — good). Remaining refinements: with **negatives (L45+)**, an all-kept line can still equal its target (Σ struck can be 0) → the "pre-solved line" feeling can return; the post-50-attempt **fallback is non-unique**.
- **Fix:** **tint the target-sum row/col headers** a distinct colour (the requested change). Extend the non-trivial gate so a line with negatives can't be pre-satisfied. Add a uniqueness check to the fallback path.
- **Modifiers pool:** `numberRange`, `negatives`, `strikeDensity`, `gridSize`, `timer`. Rotate 2–3.
- **Timer:** hard-optional.

### 5.16 Killer Sudoku — `screens/games/beta/killer_sudoku_beta.dart`
- **Symptom:** player has no info yet (didn't test).
- **Root cause / Fix:** **P0-3** (9×9 box check crash) and **P0-4** (uniqueness + givens). Until both are fixed the game is not worth playing. Newly registered as a real route (`/killersudoku`) in `main.dart` + `game_info.dart`.
- **Modifiers pool:** `gridSize`, `cageSize`, `givens`, `timer`. Rotate 2–3.
- **Timer:** soft/optional (D1).

---

## 6. Open decisions (defaults chosen — confirm or override)

- **D1 — Hard-timer scope.** *Default:* hard timer (restart on 0) on the **fast/perception** games (Odd Colour Out, Chimp, Spectrum, Colour Flood); **soft or none** on the **deliberate logic** games (Sudoku, Killer, Bridges, Masyu, Star Battle). Timer durations per Section 5.
- **D2 — Chimp Test identity.** *Default:* base mode = **visible numbers + running clock** (speed/pressure), 5 s × count; classic "numbers hide" demoted to a rotating modifier. Alternative: keep hide-based as base and only add the running clock.
- **D3 — Mine Finder hidden-count.** *Default:* **"must flag all mines to auto-clear."** Rejected alternative: "? instead of the neighbour number" (reintroduces guessing).
- **D4 — Jump-to-Level dialog.** *Default:* gate behind a debug flag (keep for dev, hide in production). Alternative: remove entirely.

---

## 7. Implementation phases (recommended order)

1. **Phase A — Shared systems.** Build Rotation Engine v2 (3.1) and the Hard-Timer framework (3.2). Strengthen the RNG seed mix (principle 7). Add the safe-fallback contract helper (3.3).
2. **Phase B — P0 crashers/unwinnables.** P0-1 Colour Link fill, P0-2 Masyu no-solve-on-load + use curated levels, P0-3 Killer 9×9 box, P0-4 Killer uniqueness, P0-5 hard-timer restart, P0-6 Bridges drag. Ship-blockers.
3. **Phase C — Per-game tuning** (Section 5), in this suggested order (highest player-visible pain first): Colour Link → Masyu → Odd Colour Out → Grid Path → Spectrum → Sudoku → Circuit Guide → Pattern Lock → Colour Flood → Star Battle → Mine Finder → Chimp → Word Hive → Sum Strike → Killer → Bridges rotation.
4. **Phase D — Cleanup.** Remove dead code branches, dead transforms (Pattern Lock mirror-H), gate/remove Jump-to-Level, make in-play shuffles deterministic.

Each phase should be independently testable; do not start Phase C tuning on a game whose Phase B item isn't done.

---

## 8. Acceptance / QA checklist (per game, before marking done)

- [ ] Every endgame level (spot-check L90, L110, L130) shows **≥2 named modifiers**, never "just timer," never "none."
- [ ] No level is **easier than an earlier** level (no seam reset; no grid shrink without added modifiers).
- [ ] Hard timer (where enabled) **restarts the level at 0** with correct per-game duration.
- [ ] Generator **never emits an unsolvable board**; where the win-check requires it, the board is **uniquely** solvable.
- [ ] Fallback path yields a **valid on-difficulty** board (log fallback-hit rate; loosen gates if high).
- [ ] No crash/lag on loading high levels (L100–150) — especially Masyu, Star Battle, Killer 9×9.
- [ ] Removed levers are gone: Grid Path walls, Chimp decoys, Mine Finder fog, Pattern Lock reverse-draw, Circuit Guide locked-wires, Star Battle anti-knight, Bridges hidden-clue/fog.
- [ ] Requested visual: Sum Strike target row/col headers tinted distinctly.
- [ ] Jump-to-Level dialog gated/removed.

---

*End of plan. Cross-references: lever definitions & Rotation Model → `difficulty_scaling_part_2.md`; Masyu level data & Sum Strike non-trivial-mask fix → `masyu_sum_level_fix.md`.*
