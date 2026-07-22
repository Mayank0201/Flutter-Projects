# modifier_fix.md — Verified Audit of commit `a1c6a97` ("Fix new modifiers (Testing)")

**Purpose:** This file is the ground-truth result of auditing the *actual committed code* on branch `v5_Puzzle`
(HEAD `a1c6a97`, 2026-07-22) against the "Comprehensive Audit & Walkthrough of Optimizations" that the
antigravity agent produced. Every line below was verified by reading the real source with `file:line` evidence.
Use it to (a) know what is genuinely fixed and can ship, and (b) implement the fixes that are still open
**before building the production appbundle**.

> TL;DR — The big structural fixes are real and good. But the **#1 user complaint (timer reaching 0 does
> nothing) is still present in 7 of 11 timed games**, the audit's **"Modifier Testing Guide" table is mostly
> wrong** (names that don't exist in code), and two Word Hive claims are overstated. Fix P0 + P1 below, then ship.

---

## 1. Verified DONE (trust these — they shipped correctly)

| Area | Claim | Verdict | Evidence |
|---|---|---|---|
| **Masyu crash L50+** | No solver on load; precomputed levels | ✅ CONFIRMED | `masyu_screen.dart:153-174` `_setupLevel` only copies `_kLevels[...]`; solver `_solveMasyu()` reachable only via `_showHint()` (`:898`). Exponential solve no longer on load. |
| **Masyu level bank** | 8×8 & 9×9 boards exist | ✅ CONFIRMED | `masyu_levels.dart` = 205 levels (5×5:50, 6:50, 7:50, **8×8:30 [L151-180], 9×9:25 [L181-205]**). |
| **Sum Strike data** | Precomputed levels wired | ✅ CONFIRMED | `sum_strike_levels.dart` `kSumStrikeLevels`; `sum_strike_screen.dart:175-183` loads curated when `!daily && level < len`. (Now extended to **200** — see `final_masyu_sum_levels.md`.) |
| **Sum Strike targets** | Target headers a distinct colour | ✅ CONFIRMED | Row/col target chips render **amber** (`sum_strike_screen.dart:837-895`); grid cells dark `0xFF23272F` — clearly distinct. |
| **Killer Sudoku 9×9 RangeError** | `boxRows=2` hardcode fixed | ✅ CONFIRMED | `killer_sudoku_beta.dart:276-277` `boxRows = size==9?3:2; boxCols = size==4?2:3` — now derived. |
| **Killer Sudoku UX** | SafeArea + real hints + badge | ✅ CONFIRMED | SafeArea `:639`; `_solution` stored `:122/:332`; `_showHint` writes correct digit `:544-555`; badge `:599-620`. |
| **Grid Path generator** | Warnsdorff self-avoiding walk, X-tiles removed | ✅ CONFIRMED | `grid_path_screen.dart:369-385` min-onward-degree pick; coverage gate `:387-408`; snake fallback `:410-424`; walls only from `nonRectShape` corners, never in normal levels. |
| **Star Battle hints** | Comparative erase-wrong / place-next | ✅ CONFIRMED | `star_battle_screen.dart:932-1013` (`_useHint`). Note: solution computed live via `_solveQueens` `:949`, not stored — functionally identical. |
| **Star Battle twoStarMode** | Restricted to 8×8+ | ✅ CONFIRMED | `star_battle_screen.dart:1031-1034` `if (n > 7) pool.add('twoStarMode')`. |
| **Word Hive solvability** | min word length + guaranteed valid set | ✅ CONFIRMED | `word_hive_screen.dart:461-478` back-off loop guarantees ≥4 valid words; `_targetCount` clamped to real count. |
| **Odd Color Out timer** | 20-30s not 100s | ✅ CONFIRMED | `odd_color_out_screen.dart:283` `_timeLeft = 25`. |
| **Mine Finder fog** | Removed from normal/endgame levels | ✅ CONFIRMED | `_isFogActive` false unless daily (`mine_finder_screen.dart:69-74`, comment "Fog is removed for normal/endgame levels!"); not in level pool `:252`. |
| **Home → Daily** | "Take Me There" pushes `/daily` | ✅ CONFIRMED | `home_screen.dart:497-503` `Navigator.pushNamed(context,'/daily')`. |

---

## 2. P0 — MUST FIX before appbundle

### P0-1 — Timer reaches 0 does NOTHING in 7 of 11 timed games
This is the user's **very first reported issue** and the audit never addressed it.

**Root cause:** `lib/utils/hard_timer.dart` (the framework whose `onTimeout()` + `AudioManager.playFail()`
is the intended "act on expiry" contract) is **dead code — zero games import it** (`grep import.*hard_timer` → none).
Every game hand-rolls its own `Timer.periodic`, so expiry behaviour is inconsistent.

**Games that already restart on 0 (reference implementation — copy this pattern):**
- `odd_color_out_screen.dart:291-297` — cancel, `AudioManager.playFail()`, snackbar `'Time is up! Restarting level...'`, `_generateLevelColors()`
- `patches_screen.dart:226-232` — same shape → `_loadLevel()`
- `spectrum_screen.dart:407-413` — same shape → `_generateSpectrum()`
- `kakuro_screen.dart:207-215` — same shape → `_generatePuzzle()`

**Games where the timer is INERT at 0 (bug — the clock zeroes, speed-bonus is forfeited, play continues):**

| Game | File:line of the dead `else` branch | Fix |
|---|---|---|
| Grid Path | `grid_path_screen.dart:510-514` | on 0 → `LossOverlay` or restart level |
| Star Battle | `star_battle_screen.dart:1074-1078` | " |
| Sum Strike | `sum_strike_screen.dart:319-323` | " |
| Mine Finder | `mine_finder_screen.dart:281-285` | " |
| Bridges | `bridges_screen.dart:227-231` | " |
| Word Hive | `word_hive_screen.dart:708-712` | " |
| Sudoku (endgame path) | `sudoku_screen.dart:1655-1658` | " — NB the *daily* time_warp path `:1628-1631` already sets `_gameOver` → `LossOverlay` `:2401`; only the normal endgame timer is inert |

**Decision needed (pick one, apply everywhere for consistency):**
- **(A) Restart the level** (matches the 4 games above and the user's words "level does not restart").
- **(B) Show `LossOverlay`** (a `loss_overlay.dart` widget already exists) then let the player retry — arguably better UX for a hard fail.
- **Recommended: (A) restart**, because it's what the user literally asked for and what 4 games already do — uniform behaviour across all 11.

**Optional cleanup:** route every timed game through `hard_timer.dart` so there's one expiry contract instead of 11
hand-rolled copies. Not required to ship, but kills the dead code and prevents this class of bug recurring.

---

## 3. P1 — Should fix before appbundle

### P1-1 — "Only the timer is ever noticeable" — dead & imperceptible modifiers
The rotation engine is **fine**: `rotation_engine.dart:25-44` returns **2–3 modifiers, uniformly shuffled, with
no bias toward `timer`**. The complaint persists in practice because some pools contain entries that do nothing
visible:

- **Dead pool entries (listed but never consumed):**
  - `star_battle_screen.dart:1031` — `'gridSize'` is in the pool but has **no `contains('gridSize')` reader**. Either wire it up (actually vary grid size) or remove it from the pool.
  - `odd_color_out_screen.dart:138,279` — `'deltaTightness'` is in the pool but **never read** (`delta` is always computed at `:152-157` regardless). Wire it (tighten the delta when active) or remove.
- **Imperceptible modifiers (technically applied, but the player can't tell):**
  - `odd_color_out` `noise` (≈0.03 lightness / 15° hue) and `gradient` (≈0.05) — bump magnitudes and/or add a small header indicator so they read as an actual modifier.
  - `star_battle` `regionContortion` only nudges a generation score (2.2 vs 1.5) — barely perceptible.

**Fix:** for every game, audit its pool vs. its `_activeModifiers.contains(...)` consumers; delete dead strings,
and give each surviving modifier a *perceptible* effect + ideally a tiny header badge so 2–3 active modifiers
actually feel like 2–3.

### P1-2 — Word Hive whisper leak
`word_hive_screen.dart:668` — the hint clue `'Hint: Try a word starting with "$clue"'` where
`clue = targetWord.substring(0,1)` (`:667`) is **not whisper-guarded**. If the target word starts with the
center letter, whisper mode is defeated. **Fix:** mask `clue` through the same `_isWhisper ? '?' : clue` guard
used everywhere else (getter at `:455`).

### P1-3 — Color Flood: remove the black/obstacle tiles (they make the game *easier*)
The `obstacles` modifier drops immovable black tiles onto the board. Because Color Flood is scored on filling
the *whole* board in minimum moves, obstacle tiles **shrink the effective playable area and cut the move count
required** — they make levels easier, not harder. They should not appear.

- Pool entry: `color_flood_beta.dart:166` — `pool: ['buffer', 'colourCount', 'centerSeed', 'obstacles', 'timer']`.
- Activation: `:177` `hasObstacles = _activeModifiers.contains('obstacles')`.
- Placement: `:228-241` — when active, cells are set to `testGrid[i] = _numColors` (the black obstacle value),
  constrained to stay flood-connected.
- The obstacle value renders as a dark/black tile.

**Fix:** remove `'obstacles'` from the pool at `:166` so it can never be selected. Then dead-strip the now-unused
`hasObstacles` branch (`:177`, `:228-241`) and the `obstacleVal` plumbing in `_isFloodConnected` (`:90-110`) if you
want it clean — or leave the branch in place (harmless once it can never activate). Optionally add another real
modifier to the pool to keep 2–3 active per level.

### P1-4 — Daily Challenge 12-hour reminder dialog must redirect to the Daily screen
The "less than 12 hours left" reminder dialog only dismisses itself — it never takes the player to the challenge.

- `challenge_reminder_helper.dart:60-68` — the only action is a `TextButton` labelled **"Start Solving"** whose
  `onPressed: () => Navigator.pop(ctx)` merely closes the dialog. No navigation.
- The dialog itself is correctly gated: shown once per cycle when `diff.inHours < 12` and fewer than 3 done (`:16-31`).

**Fix:** make "Start Solving" behave like Home's working "Take Me There" (`home_screen.dart:497-503`) — pop the
dialog, then push the daily route:
```dart
onPressed: () {
  Navigator.pop(ctx);
  Navigator.pushNamed(context, '/daily');
},
```
`checkAndShowReminder(BuildContext context)` already has the outer `context` in scope — pop with the dialog's `ctx`,
navigate with the outer `context`. `/daily` is already registered in `main.dart` (Home uses it).

---

## 4. P2 — Nice to fix / documentation accuracy

### P2-1 — Word Hive "enlarged touch target" claim is FALSE
The audit says the AppBar level selector was wrapped in an `InkWell` with padding and a scaled-up edit icon.
Reality: `word_hive_screen.dart:938-953` is still a plain `GestureDetector`, no padding, `Icon(Icons.edit, size:14)`.
If touch detection is genuinely a problem, do the wrap; otherwise just delete this claim from the walkthrough.

### P2-2 — The "Modifier Testing Guide" table is NOT reliable for QA
Many modifier names in the audit's table **do not exist in the code**. Testing against them wastes time.
Corrected mapping:

| Audit table name | Reality in code | Status |
|---|---|---|
| Odd Color Out `colorNoise` / `colorGradient` / `colorChannels` | `noise` / `gradient` / `hueChannel` (`odd_color_out_screen.dart:138,279`) | renamed — test the real tokens |
| Spectrum `colorBlend` | ❌ no such token; pool is `monochrome, prism, timer, moveLimit, gradientComplexity, distractors` (`:244`) | does not exist |
| Spectrum `moveLimit` | ✅ real (`:244,:395`) | ok |
| Mine Finder `fogMode` | ❌ not a level modifier (daily-only fog); pool `limitedFlags, hiddenCount, timer` (`:252`) | does not exist as a level modifier |
| Mine Finder `hiddenCount` | ✅ real (`:252,:65`) | ok |
| Bridges `islandCapacity` (3-4 bridges) | ❌ no token; bridges-per-pair capped at 2 (`bridges_screen.dart:44`) | does not exist |
| Pattern Lock `reverseDraw` / `autoHide` | ❌ no tokens; pool `pathComplexity, distractorDots, gridSize, boardTransform, memorizeTimer` (`pattern_lock_beta.dart:172`) | do not exist |
| Pattern Lock "capped at 5×5" | ❌ contradicted — `_gridN` reaches 6 (`:63`) and 7 in endgame (`:58`) | wrong |
| Sudoku `blackoutCells` | the blackout/"SCAN PHASE" mechanic is triggered by the `eclipse` modifier (`sudoku_screen.dart:1637`) | renamed → test `eclipse` |
| Sudoku `candidatesLimit` | ❌ no such token anywhere | does not exist |

**Action:** regenerate the testing guide from the *actual* pool literals in each game file (search each
`_screen.dart` for the modifier list passed to the rotation engine), not from the audit's table.

### P2-3 — Masyu jump-to-level dialog text
`masyu_screen.dart:114` still says "1 - 150" though 205 levels now exist. Update the max to 205.

---

## 5. Second Review Batch (verified 2026-07-22) — additional issues

A second round of playtesting surfaced more issues. All verified against the real `a1c6a97` code below.

### 5.A — SHARED ROOT CAUSE: grid size *oscillates / shrinks* at high levels (4 games)
User reports across several games: "levels 60/70/80 have big grids, then 91/100/141 get smaller and jump around."
**Same bug in all of them:** the endgame branch sets grid size with a **cyclic modulo** `base + ((level - X) % k)`,
which *rotates* sizes instead of growing them. Compounded by a **0-based index vs 1-based display** mismatch
(`_currentLevel` is 0-based; UI shows `+1`), so a "round" displayed level lands on the small end of the cycle.

| Game | file:line | Formula | Example (displayed) | Fix |
|---|---|---|---|---|
| Circuit Guide | `circuit_guide_beta.dart:95` | `_gridSize = 5 + ((level-90) % 4)` | L91→**5** (was 8 at L80); L140→6 | monotone, clamp |
| Color Flood | `color_flood_beta.dart:159` | `_gridSize = 5 + ((level-90) % 5)` | L100→9, **L101→5** | monotone, clamp |
| Spectrum | `spectrum_screen.dart:132` | `size = 6 + ((level-80) % 5)` | L100→10, **L101→6** | monotone, clamp |
| Star Battle | `star_battle_screen.dart:1029` | `n = 6 + ((level-90) % 5)` | **L141→6**, L142→7 | monotone, clamp |

**Fix (apply the same shape to all four):** replace the cyclic `% k` with a **non-decreasing** size that never
drops below the pre-rotation maximum and clamps at a ceiling. Example (tune per game):
```dart
// grows slowly, never shrinks, never exceeds the max
_gridSize = min(MAX, PRE_ROTATION_MAX + (_currentLevel - THRESHOLD) ~/ STEP);
```
For high-level *variety*, rotate the **modifiers**, not the board size. (Bonus: in Star Battle, keeping `n` large
also keeps `twoStarMode` eligible — it's gated on `n > 7` at `:1032`.) Also note the display-vs-index off-by-one:
use `_currentLevel` consistently and remember the player sees `+1`.

### 5.B — P0: Circuit Guide level ~82 is genuinely unsolvable
`circuit_guide_beta.dart` — the endgame board is a bounded random walk (`:266-402`) with **no solver and no
solvability check**. If the walk can't wire a target within budget it abandons it (`:328-367`); after up to 1000
failed attempts (`:272`) the code **ships the last broken board anyway** — no fallback, `RotationEngine.logFallback`
never called. A stranded target's only neighbor is turned into an `EMPTY` cell (`:447-451`), producing exactly the
reported "bulbs in the top row with no wires near them." The win check only tests reachability (`:610-617`), so the
dead board is never caught. Worse at L82 because 6 targets are packed onto 3 edges (`:144`).
**Fix:** (1) after the attempt loop, if `!success` → `logFallback` + regenerate with perturbed seed / fewer targets,
or fall back to a guaranteed-solvable template; (2) better, build via a spanning-tree/BFS from the source that
provably reaches every target instead of a walk that can give up; (3) add a post-gen validation asserting every
`TGT` is reachable before accepting the board.

### 5.C — P0: Bridges is the ONLY game missing from the main clear pool
(Answers "check if the other games' level-cleared counts are not in the main pool.") The aggregate counter is
`global_level_cleared_count` (`prefs_keys.dart:47`), incremented — along with per-game `cleared_count_<id>`, +10
points, every-5-clears hint, achievements, and trail unlocks — in one place: `HintManager.onLevelCleared(gameId)`
(`hint_manager.dart:36-94`). **21 of 22 games call it. Bridges does not.** Its handler `_onLevelCleared`
(`bridges_screen.dart:547-569`) only writes a private `beta_level_bridges` key + speed bonus. So **Bridges clears
don't count toward the global pool, points, hints, milestone achievements, or trail unlocks.**
**Fix:** add `await HintManager.onLevelCleared('bridges');` in `bridges_screen.dart:547`, like every other game.
Also reconcile its non-standard `beta_level_bridges` key with the shared `PrefsKeys.clearedCount`/`gameLevel`
convention to avoid a second divergence.

### 5.D — P1: per-game mechanic fixes
- **Circuit Guide — Reset gives free time.** The "Reset Board" button is `onPressed: _loadLevel` (`:1034`), and
  `_loadLevel` rebuilds *everything* including a full fresh timer + re-armed speed bonus (`:78-80`, `:516-532`).
  **Fix:** add a board-only `_resetBoard()` that re-scrambles tile rotations and leaves
  `_gameTimer`/`_timeLeft`/`_timeBonusEarned` untouched; point the button at it.
- **Color Flood — move budget too generous (L148 "4 moves left").** Cap is BFS-optimal `+ buffer` where
  `buffer` = +2 when the `buffer` modifier rolls (`:172-175`, `:254`); endgame is *more* generous than mid-game
  (which forces `buffer=0` at `:209`). **Fix:** at endgame set `_movesLeft = opt` (buffer 0/−1), compute from the
  actual solved `opt` not the `minOptimal` heuristic, and drop/repurpose `buffer` in the endgame pool.
- **Color Flood — `colourCount` is a dead modifier** (in pool `:166`, never consumed). It eats a modifier slot and
  shows nothing. **Fix:** remove it, or wire it (`_numColors += 1`). (Combines with the P1-3 `obstacles` removal.)
- **Spectrum — `prism` renders nothing in normal play.** `_startPrismTimer` runs for endgame (`:511-512`) and
  animates `_prismHueOffset`, but the tile color only applies it under `_isDailyMode && _dailyModifierType=='prism'`
  (`:1064-1073`) — so in non-daily endgame the modifier is invisible. `gradientComplexity` (`:277-279`) is a
  one-corner `Color.lerp` tweak, near-imperceptible. Together this is why "only monochrome shows."
  **Fix:** apply `_prismHueOffset` whenever prism is active in any mode; make `gradientComplexity` visibly distinct.
- **Sudoku scan/eclipse phase — three fixes:**
  1. **Timer keeps draining during scan** — the main `_gameTimer` callback (`:1647-1661`) has no `_isScanPhase`
     guard, so the countdown burns while you're memorizing. **Fix:** early-return (don't cancel) when
     `_isEclipseActive && _isScanPhase`, so it pauses and resumes at recall.
  2. **No memorize count shown** — scan banner (`:2172-2173`) shows only seconds. **Fix:** include
     `_recallTargetCount`, e.g. `'SCAN PHASE: Memorize $_recallTargetCount cells! $_blackoutCountdown s'`.
  3. **No "Ready" button** to end scan early. **Fix:** extract the scan→recall transition (`:1217-1234`) into
     `_endScanPhase()` and add a button in the scan UI (`:2161-2184`) that calls it (Pattern Lock already has one at
     `pattern_lock_beta.dart:821`).
  4. *(Already correct)* the loss/game-over overlay already shows **only** "Try Again"/restart
     (`:2401-2406` → `loss_overlay.dart:123-145`). No change needed.
- **Odd Color Out — wrong tap has no consequence.** A wrong tile in standard mode just reshuffles the same level
  (`:507-515`) — you can guess forever. (Chaos daily mode already sets `_gameOver`.) **Fix:** on a wrong tap set
  `_gameOver = true` (fires the existing `LossOverlay` at `:679-684`) or call `_resetGame()` for a clean restart.
- **Pattern Lock — distractor dots don't distract.** They're a distinct **red** at size 16 vs the amber size-20
  real dots, and only drawn while memorizing (vanish once you trace) (`:266-277`, `:781-792`). **Fix:** render them
  the same amber/size as real dots and keep them present during the trace phase for real target ambiguity.
- **Pattern Lock — board-transform warning comes too late.** The rotate/mirror modifier (`:178-180`;
  1=90°CW, 2=180°, 3=mirror — no true counterclockwise) is announced only *after* READY (`:713` guard
  `!_isMemorizing`), so you memorize blind then learn the board is rotated. **Fix:** show the "BOARD ROTATED…"
  notice during the memorize phase too (render it while `_isMemorizing`, or add a memorize-phase banner near
  `:705-711`).

### 5.E — P2: quality / polish
- **Word Hive — solvable but difficulty is inconsistent at high levels.** Letter set is **fixed at 7** (1 center +
  6 outer, `:19-32`); `_minWordLength` wants 6 at L60+ (`:461-478`) but **auto-degrades to 4** when fewer than 4
  valid words of that length exist (`:472-476`), and `_targetCount` clamps to availability (`:481-493`). So levels
  are **never unwinnable** — but a thin word bank silently collapses a "level 90" to easy 4-letter play. **Fix
  (recommended):** add a build-time/test assertion over `_kLevels` that each level yields ≥4 valid words at its
  intended min length (so authored data sustains the challenge). Bigger alternative: give high levels 8 letters
  (requires regenerating every level's `validWords`).
- **Bridges — bland board.** Participates in the rotation engine only for *mechanical* modifiers
  (`pool: ['hiddenIslands','timer']`, `:173-184`); the painter is fully static — one bridge accent
  (`AppTheme.dustyMauve`, `:1158`), fixed island colors (`:1242-1254`), flat `bgCard` board (`:1041-1045`), and
  `bridges_levels.dart` carries no color/theme fields. Identical look from L1→150. **Fix:** per-tier accent color
  (band by gridSize), a cosmetic rotation-modifier pool (nightMode / water-gradient board / texture) parallel to the
  mechanical one, distinct rings for higher-capacity islands, and a gradient/water board background instead of flat.

---

## 7. Suggested order of work

**P0 — must fix before appbundle (unsolvable levels / broken progression):**
1. **P0-1** timer-on-zero across the 7 inert games (copy the odd_color_out pattern; decision: restart). *~1-2 hrs.*
2. **5.B** Circuit Guide unsolvable board — add solvability guarantee + fallback. *~1-2 hrs.*
3. **5.C** Bridges missing from main clear pool — add `HintManager.onLevelCleared('bridges')`. *~10 min.*

**P1 — should fix before appbundle:**
4. **5.A** grid-oscillation shared fix across Circuit Guide / Color Flood / Spectrum / Star Battle (monotone size). *~1-2 hrs.*
5. **P1-2** Word Hive whisper leak (one-line guard). *~5 min.*
6. **P1-4** Daily 12-hour reminder → push `/daily`. *~5 min.*
7. **P1-3** Color Flood: drop `'obstacles'`; **5.D** Color Flood move-budget = exact optimal; drop dead `colourCount`. *~30 min.*
8. **5.D** Circuit Guide board-only reset (don't reset timer). *~15 min.*
9. **5.D** Spectrum `prism` render fix + visible `gradientComplexity`. *~30 min.*
10. **5.D** Sudoku scan phase: pause timer + show memorize count + "Ready" button. *~1 hr.*
11. **5.D** Odd Color Out: wrong tap → restart/game-over. *~15 min.*
12. **5.D** Pattern Lock: stronger distractors + announce board-transform during memorize. *~30 min.*
13. **P1-1** dead/imperceptible modifiers sweep (per game). *~2-3 hrs.*

**P2 — polish / docs:**
14. **5.E** Bridges visual polish (per-tier accents, cosmetic modifiers). *~1-2 hrs.*
15. **5.E** Word Hive high-level word-bank assertion. *~30 min.*
16. **P2** doc cleanups (regen testing guide, Masyu dialog max→205, drop false touch-target claim). *~30 min.*
17. Rebuild appbundle.

## 8. QA checklist (post-fix)
- [ ] In each of the 11 timed games, let the timer hit 0 → level restarts (or LossOverlay), never silently continues.
- [ ] `grep import.*hard_timer` — either used everywhere or the file is deleted (no dead framework).
- [ ] Every string in each game's modifier pool has a matching `contains(...)` consumer (no dead entries).
- [ ] Word Hive: with whisper active, the hint clue shows `?` (not the center letter) when the word starts with it.
- [ ] Color Flood: no black/obstacle tiles appear at any level; `'obstacles'` gone from the pool.
- [ ] Daily 12-hour reminder: "Start Solving" navigates to the Daily screen, not just closes the dialog.
- [ ] **Grid size never shrinks with level** — Circuit Guide / Color Flood / Spectrum / Star Battle grids are monotone non-decreasing past their thresholds (spot-check L91, L101, L141).
- [ ] **Circuit Guide: every generated board is solvable** — no bulb without a reachable wire path (check L82).
- [ ] **Bridges clears count** — clearing a Bridges level increments `global_level_cleared_count`, grants points, and advances achievements/trails.
- [ ] Circuit Guide: pressing Reset does NOT add time / re-arm the speed bonus.
- [ ] Color Flood: perfect play leaves 0 spare moves at endgame levels (e.g. L148).
- [ ] Spectrum: `prism` visibly shifts hue in non-daily endgame; `gradientComplexity` is noticeable.
- [ ] Sudoku eclipse: main timer pauses during scan; scan shows the memorize count; a "Ready" button ends scan early.
- [ ] Odd Color Out: a wrong tap restarts / ends the level (no consequence-free guessing).
- [ ] Pattern Lock: distractor dots are indistinguishable from real dots; board-transform is announced before/while memorizing.
- [ ] Testing guide regenerated from real pool literals; every listed modifier is observable in play.
- [ ] Masyu jump-to-level accepts up to 205.
