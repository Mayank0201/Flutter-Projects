# Difficulty Scaling — Part 2: Endgame Scaling & the Rotation Model

**Date:** 2026-07-20
**Focus:** how to keep games getting harder *and staying fresh* long after the grid stops growing — specifically for players who reach 500+ levels.
**Status:** design proposal (suggestions, not yet implemented). Companion to `DIFFICULTY_SCALING_ANALYSIS.md`.

---

## The core problem

Every grid-based game hits two walls:

1. **Physical:** the grid can only grow so far on a phone (Odd Color Out caps at 9×9, Grid Path at 6×6).
2. **Content:** even the *designed* progression — the stages that introduce new mechanics — eventually runs out. A dedicated player will blow past level 500, and there's no way to hand-author 500 genuinely distinct levels per game.

So the endgame needs an **engine**, not a level list.

---

## The Rotation Model (the key idea)

Instead of freezing at the biggest grid and grinding one maxed-out config forever, the late game **rotates old levels back in and dresses them with rotating modifier combos.**

Every game accumulates two things as the player climbs:

- **An archetype pool** — the grid sizes, layouts, and base configs from *every* earlier stage (including the small early grids).
- **A lever set** — the difficulty modifiers introduced one per stage (shrinking color delta, walls, barriers, timers, etc.).

Once all levers have been introduced (end of the base progression, ~L140), each further level is generated as:

> **pick an archetype from the pool (grid size rotates — it is *not* fixed at max) × apply a rotating 2–3 of the levers**, chosen deterministically from the level index.

**Why rotate old grids back in instead of locking at max size:**
- **Infinite, varied content from a finite designed base** — the whole point.
- **A small grid with heavy modifiers is a *different* kind of hard** than a big grid — a 5×5 at near-invisible color delta + timer tests different skills than a 9×9. Variety, not just difficulty.
- **500+ players have already seen each base config once** — recombination is the freshness engine, so it never feels like the same three screens forever.
- **Difficulty is carried by the modifier stack, not the grid**, so you're free to vary grid size down without making it easier.

Difficulty still climbs in the endgame — via modifier *intensity* (color delta → just-noticeable floor, wall density, timer tightness) — while grid size and which levers are active rotate purely for variety. Deterministic per level index, so level 512 always plays the same for everyone; it's recombination, not random noise.

---

## Worked example 1 — Odd Color Out

Levers (introduced one per stage, decoys excluded):

| Lever | What it does |
|-------|--------------|
| A — grid growth | 2×2 → 9×9 |
| B — perceptual delta shrink | odd tile's shade difference shrinks toward the just-noticeable limit |
| C — channel switch | difference moves lightness → saturation → **pure hue at equal brightness** (hardest) |
| D — noise floor | every tile jittered slightly, camouflaging the odd one |
| E — background gradient | base color drifts across the grid, so "which is darkest" fails |
| F — soft timer | per-level countdown (reuses chaos/eclipse timer code) |

| Stage | Levels | Grid | New lever | Notes |
|-------|--------|------|-----------|-------|
| 0 — Learn | 1–16 | 2×2 → 5×5 | A + wide lightness delta | onboarding |
| 1 — Grid + delta | 17–40 | 6×6 → 9×9 | B (delta shrinks) | ~today's behaviour; grid caps at 41 |
| 2 — Delta takes over | 41–60 | 9×9 | B uncapped (drop `min(49,…)` clamp) | grid frozen; delta → near-JND floor |
| 3 — Channel switch | 61–85 | 9×9 | C (hue at equal luminance) | delta continues, harder axis |
| 4 — Noise | 86–115 | 9×9 | D | first stacked lever (hue + noise) |
| 5 — Gradient | 116–140 | 9×9 | E | alternate noise/gradient level to level |
| **6 — Rotation** | **141+** | **rotates 5×5–9×9** | F + **rotation** | endgame model below |

**Endgame (L141+):** grid size **rotates across 5×5–9×9** (not stuck at 9×9), hue-delta held near the JND floor, plus a rotating 2–3 of {noise, gradient, timer}. Example:
- L141: 9×9 + gradient + timer
- L142: 6×6 + noise + gradient
- L143: 8×8 + noise + timer
- L144: 5×5 + gradient + timer (small grid, brutal delta — a different kind of hard)

Delta formula for the uncapped stages: `delta = 0.012 + 0.088 * (30 / (30 + level))` — decays toward ~0.012, never flat.

---

## Worked example 2 — Grid Path

**Current problems (diagnosed):** grid caps at 6×6 by L30 (earliest of any game); the waypoint count *rises* with level, which makes it **easier** (more numbered cells = route more spelled out); walls only appear at L30, oscillate 2–5 (`levelIndex % 4`), and never really ramp. Net: meaningful difficulty stops ~L30 and drifts *easier* after.

Levers (unique-solution enforcement intentionally **not** used):

| Lever | What it does |
|-------|--------------|
| A — grid growth | 3×3 → 6×6 |
| B — waypoint count (flipped) | **more early (guidance), fewer later (freedom = harder)** — opposite of current |
| C — structured walls | monotonic count, placed as corridors / forced turns (not random) |
| D — barrier-walls | uncrossable edges between two open cells (real LinkedIn-Zip mechanic) |
| E — non-rectangular boards | holes / L-shapes via wall clusters |
| F — soft timer | per-level countdown |

| Stage | Levels | Grid | New lever | Notes |
|-------|--------|------|-----------|-------|
| 0 — Learn | 1–15 | 3×3 → 4×4 | generous waypoints | route mostly spelled out |
| 1 — Grid + thinning | 16–30 | 5×5 → 6×6 | B begins (waypoints thin) | last stage leaning on grid size |
| 2 — Walls | 31–55 | 6×6 | C (walls 2→8, structured) | grid frozen; walls take over |
| 3 — Sparse waypoints | 56–80 | 6×6 | B pushed to few | solve more of the path yourself |
| 4 — Barriers | 81–110 | 6×6 | D (barrier-walls) | learned alone, then layered on walls |
| 5 — Geometry | 111–140 | 6×6 | E (non-rect boards) | shape variety, no grid growth |
| **6 — Rotation** | **141+** | **rotates 4×4–6×6, rect + non-rect** | F + **rotation** | endgame model below |

**Endgame (L141+):** archetype rotates across the pooled boards (grid sizes 4×4–6×6, rectangular and L-shaped), with a rotating 2–3 of {dense structured walls, barrier-walls, sparse waypoints, soft timer}. Example:
- L141: 6×6 + dense walls + barriers → tight-corridor maze
- L142: 5×5 + sparse waypoints + timer → open board, race the route
- L143: L-shaped 6×6 + barriers → odd geometry
- L144: 4×4 + dense walls + sparse waypoints → small but knotted

Also fix the generation edge bug: at high waypoint counts the spacing formula `(i*(pathLen-1)/(waypointCount-1)).round()` collides two waypoints onto one cell — moot once waypoints are *reduced* late-game rather than raised.

---

## Worked example 3 — Circuit Guide

**Current state (diagnosed):** a pipe-rotation puzzle — rotate each tile so a circuit runs from the source to all targets. Two levers, grid size and target count, ramp in interleaved steps (the best base ramp of the set) up to **8×8 / 6 targets at L71, then hard plateau** — every level after is identical parameters. And it scales by *size*, while the real difficulty (how tangled the circuit is, junction density, how scrambled tiles start) is random per seed and never tuned.

Levers:

| Lever | What it does |
|-------|--------------|
| A — grid growth | 3×3 → 8×8 (caps L71) |
| B — target count | 1 → 6 (caps L71) |
| C — circuit tortuosity | longer, more winding path; more branch points |
| D — junction-piece density | more T-junctions / cross (+) pieces vs straights & elbows (hardest to orient) |
| E — scramble depth | min rotations each tile starts from solved (no tile spawns pre-solved) |
| F — decoy wires | filler tiles that look connected but must be left as dead-ends |
| G — soft timer | speed bonus; hard timer only in endgame |
| H — move/rotation budget | bonus for solving under optimal; hard cap in endgame; scales with E |

| Stage | Levels | Grid / targets | New lever | Notes |
|-------|--------|----------------|-----------|-------|
| 0 — Learn | 1–12 | 3×3, tutorials → 2 tgt | A + B baseline | hand-authored + gentle |
| 1 — Grid + targets | 13–70 | 4×4→8×8, 2→6 tgt | A + B ramp (C/D rising mildly in background) | keep — the strong base ramp; caps L71 |
| 2 — Tortuosity | 71–95 | 8×8, 6 tgt | C foregrounded | grids capped; tangle takes over |
| 3 — Junctions | 96–115 | 8×8, 6 tgt | D | biggest grid-independent lever |
| 4 — Scramble | 116–130 | 8×8, 6 tgt | E | no tile starts pre-solved |
| 5 — Decoys | 131–150 | 8×8, 6 tgt | F | false leads, no grid growth |
| **6 — Rotation** | **151+** | **rotates 4×4–8×8** | G / H + rotation | endgame model below |

**Endgame (L151+):** grid size rotates across 4×4–8×8 × a rotating 2–3 of {high tortuosity, junction-heavy, deep scramble, decoys} + **either** a timer **or** a move budget (never both — they're both efficiency pressure and stack into stress, not depth). Example:
- L151: 8×8 + junction-heavy + decoys → dense tangle
- L152: 5×5 + max tortuosity + move budget → small but knotted, plan your rotations
- L153: 7×7 + deep scramble + decoys + timer → race a scrambled board
- L154: 6×6 + junctions + tortuosity → pure spatial

Notes specific to Circuit Guide:
- **Move budget must be computed from the level's actual optimal** — sum of each tile's minimum rotation distance to a valid orientation (accounting for symmetric pieces, e.g. a straight has two equivalent orientations) + slack. Never a fixed number.
- **Move budget and scramble depth reinforce each other:** deeper scramble → higher optimal → the same "optimal + slack" par gets tighter automatically.

---

## Worked example 4 — Pattern Lock

**Current state (diagnosed):** a memory game — a connected path flashes on a grid, the player memorizes it during a **fixed auto-timer** (`max(1.5s, 0.6s × length)`), then reproduces it by dragging. Grid grows 3×3 → 7×7 (caps L35); length grows `3 + level//2`. **Scaling flaw:** exposure is a *constant* 0.6s per dot, so the memory pressure per element never tightens — longer patterns just get proportionally more time.

**Core mechanic change (per design decision): remove the auto-timer.** The pattern stays visible until the player taps **"Ready/Done"** to hide it, then reproduces from memory. A generous **~60s backstop** auto-hides it only to prevent an AFK hang — it is *not* a pressure clock. This fits the app's calm positioning and turns the game from "memorize fast under pressure" into "reconstruct a complex path."

**The catch this creates:** with no tight timer, memory difficulty is *self-selected* (a player can study until fully confident). So difficulty **must** come from complexity levers that stay hard *even after careful study* — length and turns to hold, and reproduction twists that can't be cheesed by staring.

Levers:

| Lever | What it does |
|-------|--------------|
| A — grid growth | 3×3 → 7×7 (caps L35) |
| B — pattern length | more dots to hold |
| C — path complexity | more turns / direction-changes, diagonals, self-crossing (hard to hold regardless of study time) |
| D — distractor dots | extra dots flash that aren't part of the pattern |
| E — reverse reproduction | study forward, draw **backward** |
| F — rotated-grid reproduction | grid rotates before you draw (mental rotation) |
| G — no re-peek | once hidden, can't show it again — one shot |
| H — memorize timer | **removed at baseline** (player-controlled hide + ~60s backstop); reintroduced *tightened* only as an endgame rotating lever |

| Stage | Levels | Grid / length | New lever | Notes |
|-------|--------|---------------|-----------|-------|
| 0 — Learn | 1–10 | 3×3 → 4×4, short | player-controlled hide | learn the reconstruct-from-memory loop |
| 1 — Grid + length | 11–35 | 5×5 → 7×7, lengthening | A + B (existing) | base ramp; grid caps L35 |
| 2 — Complexity | 36–60 | 7×7 | C (turns/diagonals) | grid capped; complexity takes over |
| 3 — Distractors | 61–80 | 7×7 | D | false dots among the flash |
| 4 — Reverse | 81–105 | 7×7 | E (draw backward) | un-cheesable by staring |
| 5 — Rotated grid | 106–135 | 7×7 | F (mental rotation) | study one orientation, draw another |
| **6 — Rotation** | **136+** | **rotates 3×3–7×7** | G + H + rotation | endgame model below |

**Endgame (L136+):** grid size rotates 3×3–7×7 × a rotating 2–3 of {high turn-complexity, distractors, reverse, rotated-grid, no re-peek} — plus, as the hardest optional lever, a **tightened memorize timer** (the ~60s backstop pulled down to real pressure) appearing only in a fraction of endgame levels. Example:
- L136: 7×7 + reverse + distractors → long backward recall
- L137: 5×5 + rotated grid + no re-peek → mental rotation, one shot
- L138: 6×6 + high-turn + tightened timer → the rare pressure level
- L139: 4×4 + reverse + rotated → small but doubly-twisted

This keeps the game relaxed and player-paced for the whole main progression, and only ever reintroduces time pressure to already-expert players, as an occasional flavour in the rotation.

---

## Worked example 5 — Star Battle / Queens

**Current state (diagnosed):** the LinkedIn-Queens variant — one star per row, per column, and per colored region, no two adjacent. `_loadLevel` (lines 731–745) scales a single value `n`, and because it's one star per line/region, **`n` is simultaneously the grid size, the star count, and the region count** — one lever doing everything.

| Levels | Grid `n` |
|--------|----------|
| 1–5 | 5×5 |
| 6–15 | 6×6 |
| 16–30 | 7×7 |
| 31–50 | 8×8 |
| 51–75 | 9×9 |
| **76+** | **10×10 (cap)** |

**Plateau at L76** — 10×10 forever. And the deeper issue: difficulty is **grid size**, but the puzzle is the **regions**. The generator grows regions by *random cellular growth* (lines 400–460), so region complexity — the thing that actually makes the puzzle hard — is never tuned (noisy difficulty), and there's **no uniqueness check**, so many puzzles are guessable rather than deducible. (`_kLevels = []` is also dead code.)

Levers:

| Lever | What it does |
|-------|--------------|
| A — grid `n` | 5→10; grid = stars = regions (caps L76) |
| B — region contortion | irregular, elongated, interlocking regions (snaking across rows/cols = far harder) — tuned instead of random |
| C — ★★ two-star mode | classic Star Battle: **2 stars** per row/col/region — a whole extra difficulty dimension on the *same* grid |
| D — soft timer | late/endgame only |
| *(opt)* unique solution | deduce-the-answer vs guess-a-valid-one (flagged, per no-forced-uniqueness stance) |

| Stage | Levels | Grid | New lever | Notes |
|-------|--------|------|-----------|-------|
| 0 — Learn | 1–5 | 5×5 | compact regions | onboarding |
| 1 — Grid growth | 6–75 | 6×6 → 10×10 | A (+ B rising mildly) | base ramp; grid caps at L76 |
| 2 — Region contortion | 76–105 | 10×10 | B foregrounded | grid capped; region shapes carry difficulty |
| 3 — Two-star mode | 106–135 | 8×8–10×10 | C (★★) | the harder variant the game is *named* after |
| **6 — Rotation** | **136+** | **rotates 6×6–10×10, 1★/2★** | D + rotation | endgame model below |

**Endgame (L136+):** grid size rotates 6×6–10×10 and star-count rotates 1★/2★ × a rotating 2–3 of {high region contortion, 2★, timer}. A 2★ 7×7 with snaking regions is a completely different — and harder — puzzle than a 1★ 10×10, so the endgame gets real variety with no board bigger than 10.

**Standout lever: the ★★ two-star mode.** The game is literally named *Star Battle* (the 2-star genre) but ships as 1-star Queens — adding 2★ is a large, grid-independent difficulty jump that's already implied by its own name.

---

## Worked example 6 — Sum Sudoku (Killer Sudoku)

**Current state (diagnosed):** a fusion game — Star Battle's *regions* (cages) + *sums* (cage totals) + *sudoku rules* (each digit once per row/col/box). But it currently has **no scaling at all**: a **4×4 mini** (digits 1–4, 2×2 boxes), **10 fixed hand-authored levels** (`_loadLevel`, lines 27–63), ~7 cages throughout, no givens system, no procedural generation — then it ends. This is a placeholder, so the task here is *building* a ramp, not fixing a plateau.

The upside: as a fusion of two games, its levers are the **union of both parents' levers** plus one Killer-specific lever:

| Lever | Inherited from | What it does |
|-------|----------------|--------------|
| A — grid / number range | Sudoku | 4×4 (1–4) → 6×6 (1–6) → **9×9 (1–9)** — the standard size ramp it's missing entirely |
| B — cage size & irregularity | Star Battle regions | small cages = strong constraints (easy); large, snaking, interlocking cages = loose & hard |
| C — given digits | Sudoku | many pre-filled → few → **zero** (pure cage deduction) |
| D — cage-sum ambiguity | *Killer-specific* | prefer sums with *many* digit combinations (hard) over unique-combo cages like "2 cells = 3" (easy) |
| E — operation variant | KenKen | swap plain sums for ×/−/÷ cages as a late twist |
| F — soft timer | universal | late/endgame only |

> **Uniqueness is required here** (unlike Grid Path / Star Battle) — a Sudoku-family puzzle *is* a single-solution deduction. Any procedural generator must verify one solution. (The Sudoku parent's solver can be reused; note the app's Sudoku uniqueness check is one of the sync-on-UI-thread solvers flagged in the audit — run it off-thread.)

| Stage | Levels | Grid | New lever | Notes |
|-------|--------|------|-----------|-------|
| 0 — Learn | 1–8 | 4×4 | many givens, small cages | onboarding |
| 1 — Size up | 9–30 | 4×4 → 6×6 → 9×9 | A (+ givens thinning) | the size ramp it lacks; grid caps 9×9 |
| 2 — Cage complexity | 31–55 | 9×9 | B (bigger, irregular cages) | grid capped; cages carry difficulty |
| 3 — Fewer givens | 56–80 | 9×9 | C (toward zero givens) | |
| 4 — Sum ambiguity | 81–105 | 9×9 | D (many-combo cages, near-zero givens) | pure Killer deduction |
| 5 — Operation variant | 106–130 | 9×9 | E (KenKen ×/−/÷) | optional harder twist |
| **6 — Rotation** | **131+** | **rotates 4×4 / 6×6 / 9×9** | F + rotation | endgame model below |

**Endgame (L131+):** grid size rotates 4×4 / 6×6 / 9×9 × a rotating 2–3 of {big irregular cages, zero givens, ambiguous sums, operation cages, timer}. A no-givens 6×6 with ×/÷ cages is a different beast than a 9×9 plain-sum with a few givens — so, again, endless variety without exceeding a 9×9 board.

---

## Worked example 7 — Color Flood

**Current state:** flood-fill from a corner — pick a color, the connected region floods to it, fill the whole board within a move limit. **Credit:** the move limit is computed from the actual optimal (`_solveColorFlood` + a buffer, lines 134–165), so it's fair. Two levers, both cap at **9×9 / 6 colors at L36**, then plateau.

| Levels | Grid | Colors |
|--------|------|--------|
| 1–5 | 5×5 | 4 |
| 6–10 | 6×6 | 4 |
| 11–20 | 7×7 | 5 |
| 21–35 | 8×8 | 5 |
| **36+** | **9×9** | **6 (cap)** |

Levers:

| Lever | What it does |
|-------|--------------|
| A — grid size | 5→9 (caps L36) |
| B — color count | 4→6 (caps L36) |
| C — move-buffer tightness | `optimal + 3` → `+1` → `+0` — forces near-optimal play (biggest lever, half-built already) |
| D — seed position | corner → **center** (harder to reason about) |
| E — obstacle cells | locked cells that don't flood — routing complexity, no bigger grid |
| F — soft timer | late/endgame |

| Stage | Levels | Grid / colors | New lever | Notes |
|-------|--------|---------------|-----------|-------|
| 0 — Learn | 1–10 | 5×5→6×6, 4 clr | generous buffer | onboarding |
| 1 — Grid + colors | 11–35 | 7×7→9×9, 5→6 clr | A + B | base ramp; caps L36 |
| 2 — Buffer tightening | 36–65 | 9×9, 6 clr | C (`+3`→`+1`) | grid capped; the primary post-cap lever |
| 3 — More colors | 66–90 | 9×9, 7–8 clr | B beyond 6 | more branching per move |
| 4 — Seed + obstacles | 91–120 | 9×9 | D + E | center seed, locked cells |
| **6 — Rotation** | **121+** | **rotates 5×5–9×9** | F + rotation | endgame |

**Endgame (L121+):** grid rotates 5×5–9×9 × color count × **buffer tightness** (+ obstacles / timer). A `+0`-buffer 6×6 with 8 colors is a different hard than a loose 9×9.

---

## Worked example 8 — Hue (Spectrum)

**Current state:** unscramble a 2D color gradient by swapping tiles; some **anchor** tiles (corners + mid-edges) stay locked as reference. Grid grows in tiers of 5 levels, 3×3 → … → **clamped at 12×13 around L70–75** — the **slowest, latest-capping base ramp of the whole set.** Bigger grid also auto-hardens it (finer gradient steps = more similar neighbours).

**Bug to fix first:** `_checkWinCondition` (line 473) requires each tile at its exact index, but color quantization can make two tiles *identical* — a visually-correct board with those two swapped is wrongly rejected. Compare by **color value**, not index.

| Lever | What it does |
|-------|--------------|
| A — grid size | 3×3 → 12×13 (caps ~L70) |
| B — anchors | many → **zero** locked reference tiles (training wheels off) |
| C — gradient complexity | 2-corner linear → multi-hue / non-linear gradients |
| D — hue-only at equal lightness | isoluminant gradients are the hardest to order |
| E — step subtlety | smaller adjacent-tile color distance, independent of grid |
| F — swap limit / timer | optimization + late pressure |

| Stage | Levels | Grid | New lever | Notes |
|-------|--------|------|-----------|-------|
| 0 — Learn | 1–15 | 3×3→5×5 | all anchors, simple 2-corner gradient | onboarding |
| 1 — Grid growth | 16–70 | 6×6 → 12×13 | A | base ramp (the long one); caps ~L70 |
| 2 — Fewer anchors | 71–95 | 12×13 | B (toward zero) | infer the gradient yourself |
| 3 — Gradient complexity | 96–120 | 12×13 | C (multi-hue / non-linear) | harder to reason about |
| 4 — Hue-only / subtle | 121–150 | 12×13 | D + E | isoluminant + finer steps |
| **6 — Rotation** | **151+** | **rotates grid sizes** | F + rotation | endgame |

**Endgame (L151+):** grid size rotates × a rotating 2–3 of {no anchors, multi-hue gradient, hue-only/subtle steps, swap limit, timer}. A no-anchor hue-only 8×8 is a different puzzle than a big linear-gradient 12×13.

---

## Worked example 9 — Chimp Test (memory)

**Current state:** numbers 1..N appear on a grid; tap **1**, the rest hide, then tap 2..N from memory. Study is **self-paced** (nothing hides until you tap 1) — already the no-timer / player-controlled model. Scaling ramps grid + count from `(3,4)` to **14×14 / ~147 numbers**.

**Problem — overshoot, not plateau:** human working memory for this tops out around ~15–20 items. Ramping count to 60/100/147 blows past that by ~L15–20, so it becomes *impossible-by-luck*, not harder. The count lever is scaled far past where it's still a skill.

**Fix — sawtooth the count, capped at 15.** The count never exceeds ~15. Instead of ramping count upward forever, it **sawtooths**: climb 4 → 15, then on completion **reset to ~5 and add a modifier**, climb 5 → 15 again under it, reset again with the next modifier, and so on. The low reset lets each new modifier be learned with only a few numbers; count stays human-playable forever while difficulty rises through accumulating modifiers.

Modifiers (added one per cycle):

| Modifier | What it does |
|----------|--------------|
| A — timed exposure | numbers auto-hide after a window even before you tap 1 |
| B — spatial spread | larger grid, count held — positions harder to locate/recall |
| C — position shuffle | tiles shift after hiding (the `_applyDailyPositionModifier` hook already exists) |
| D — decoy tiles | extra blank/false tiles among the numbers |

Cycle plan:

| Cycle | Count | Modifier(s) |
|-------|-------|-------------|
| 1 | 4 → 15 | none (base) |
| 2 | 5 → 15 | + A (timed exposure) |
| 3 | 5 → 15 | + B (spatial spread) |
| 4 | 5 → 15 | + C (shuffle) |
| 5 | 5 → 15 | + D (decoys) |
| 6+ (extreme) | 5 → 15 | rotating 2–3 modifiers combined |

Count-capped, endless, and always inside human memory range.

---

## Worked example 10 — Word Hive (word game)

**Current state:** Spelling-Bee clone — 1 center + **6 fixed outer letters**, form words using the center letter from a **hardcoded per-level word set**, reach `targetCount`. ~40 hand-authored levels; the only lever is `targetCount` (rises 4→10+), letter count never changes, and the list runs out. The clearest case of "word games don't scale."

Levers (word-specific — this game does **not** fit the grid-rotation model):

| Lever | What it does |
|-------|--------------|
| A — min word length | require 5-, then 6-letter words (long-words-only is a big jump) |
| B — letter-set stinginess | sets yielding fewer total words / rarer letters / fewer vowels |
| C — pangram requirement | must find the all-7-letters word to clear |
| D — soft timer | late/endgame |
| E — procedural letter-sets | **(structural)** generate valid 7-letter sets from the dictionary → endless content instead of a finite hand-authored list |

Staged: min-length ramp → stinginess → pangram-required → timer, with **E** as the structural change that makes it endless (reuse the Word Guess dictionary). *(No "hide word count / remove hints" lever — excluded per design.)*

**Word Hive's endless engine is procedural word-set generation, not board rotation** — the one game here that scales by a different mechanism than the rest.

---

## Worked example 11 — Sudoku

**Current state:** three hand-authored base puzzles per size (4×4 / 6×6 / 9×9), remixed by digit-shuffle + transpose, with givens removed as levels rise (uniqueness re-checked — good):

| Levels | Grid | Givens |
|--------|------|--------|
| 1–10 | 4×4 | 8 → 5 |
| 11–25 | 6×6 | 18 → 14 |
| 26–40 | 9×9 | 25 |
| 41–60 | 9×9 | 21 |
| **61+** | **9×9** | **17 (cap)** |

**The clue lever is already maxed** — 17 is the proven minimum for a unique 9×9, so difficulty *cannot* rise further by removing clues. **Plateau at L61.** And clue *count* ≠ solving *difficulty* — the actual technique required is uncontrolled.

**Primary fix: scale by required solving technique, not clue count.** Rate/generate puzzles by the hardest technique needed (naked singles → hidden pairs → pointing → X-wing → chains) — exactly how real Sudoku apps rate Easy→Evil. Uncapped scaling on a fixed 9×9. **Needs a technique-ladder solver** (solve via progressively harder techniques, report the hardest used = the rating).

| Lever | What it does |
|-------|--------------|
| A — grid size | 4×4 → 9×9 (caps L26) |
| B — clue count | down to 17 (caps L61, theoretical floor) |
| C — required technique | singles → pairs → pointing → X-wing → chains (the real post-cap lever) |
| D — variant rules | diagonal/X-sudoku, anti-knight, thermo — each a difficulty dimension (cheaper bolt-on) |
| E — soft timer | endgame/optional (speed-sudoku is well-established) |

| Stage | Levels | Grid | New lever | Notes |
|-------|--------|------|-----------|-------|
| 0 — Learn | 1–10 | 4×4 | many clues | onboarding |
| 1 — Grid + clues | 11–60 | 6×6 → 9×9 | A + B | base ramp; clues bottom at 17 (L61) |
| 2 — Technique tier | 61–95 | 9×9 | C | grid + clues capped; technique carries difficulty |
| 3 — Variant rules | 96–130 | 9×9 | D | diagonal / anti-knight etc. |
| **6 — Rotation** | **131+** | **rotates 4×4/6×6/9×9** | E + rotation | endgame |

**Endgame (L131+):** grid rotates × {technique tier, variant rule, timer}. A chain-required 6×6 or a diagonal-variant 9×9 is a different hard than a plain 17-clue.

---

## Worked example 12 — Mine Finder (Minesweeper)

**Current state (lines 193–197):** grid `5 + level//3` → **5×5–16×16 (caps L33)**; mines `3 + level×1.2` → capped at **~25% density (~61 mines, ~L48)**. Sensible ramp, expert-size cap.

**The bottleneck isn't size or density — it's guessing.** Classic minesweeper forces 50/50 coin-flips, so late-game difficulty is partly *luck*, and luck worsens on bigger boards.

**Primary fix: no-guess generator.** Produce only fully-deducible boards (reject any that require a coin-flip), then scale by **deduction complexity** (simple counting → 1-2-1 / subset patterns → constraint-solving chains) rather than just density. Turns luck into skill and gives a real axis past the density cap. **Needs a minesweeper logic-solver** used as generate-and-filter.

| Lever | What it does |
|-------|--------------|
| A — grid size | 5→16 (caps L33) |
| B — mine density | → ~25% (caps ~L48) |
| C — no-guess + deduction depth | fully-deducible boards, rated by hardest deduction required (the real lever) |
| D — limited flags / hidden mine count | remove assists |
| E — timer | **genre-canonical** — natural to Minesweeper, can appear earlier as a time-attack mode |

| Stage | Levels | Grid | New lever | Notes |
|-------|--------|------|-----------|-------|
| 0 — Learn | 1–10 | 5×5→7×7 | low density, no-guess simple | onboarding |
| 1 — Grid + density | 11–48 | 8×8 → 16×16 | A + B | base ramp; density caps ~25% (~L48) |
| 2 — Deduction depth | 49–80 | 16×16 | C (no-guess, harder deductions) | grid/density capped; logic carries difficulty |
| 3 — Info restriction | 81–110 | 16×16 | D (limited flags, hidden count) | |
| **6 — Rotation** | **111+** | **rotates grid sizes** | E + rotation | endgame |

**Endgame (L111+):** grid rotates × {high-density no-guess, hard-deduction-required, limited flags, hidden count, **timer**}. A tight-timer 10×10 no-guess is a different hard than a slow 16×16.

> Both Sudoku and Mine Finder are **solver-dependent** fixes — a technique-ladder rater and a no-guess checker respectively. Higher-effort than the other games, but they're *the* classic deduction puzzles, so difficulty-from-logic-depth is exactly right for them.

---

## Worked example 13 — Colour Link (Numberlink / Flow)

**Current state:** connect matching endpoints with non-crossing paths that **fill the whole grid**. **Already procedurally generated.** One lever — grid size: 4×4 → 5×5 → 6×6 → 7×7 → **8×8 (cap L35)**. But pair count and path winding just *emerge* from random generation — untuned. **Plateau at L35.**

**Easiest game to extend** — the generator exists; just steer it:

| Lever | What it does |
|-------|--------------|
| A — grid size | 4→8 (caps L35) |
| B — pair count / density | more endpoints on the same grid = tighter routing (currently random → tune it) |
| C — path tortuosity | bias toward solutions whose paths must wind & detour, not run straight |
| D — variant mechanics | walls (impassable cells), bridge/warp tiles (paths cross via a bridge) |
| E — soft timer | late/endgame |

| Stage | Levels | Grid | New lever | Notes |
|-------|--------|------|-----------|-------|
| 0 — Learn | 1–10 | 4×4→5×5 | few pairs, simple paths | onboarding |
| 1 — Grid growth | 11–35 | 6×6 → 8×8 | A | base ramp; caps L35 |
| 2 — Pair density | 36–60 | 8×8 | B (more pairs) | grid capped; density carries difficulty |
| 3 — Tortuosity | 61–85 | 8×8 | C (forced winding) | |
| 4 — Variant mechanics | 86–115 | 8×8 | D (walls, bridge tiles) | new mechanics, no bigger grid |
| **6 — Rotation** | **116+** | **rotates 4×4–8×8** | E + rotation | endgame |

**Endgame (L116+):** grid rotates × {high pair count, forced-tortuous paths, walls, bridge tiles, timer}.

---

## Worked example 14 — Bridges (Hashi)

**Current state:** islands with numbers; connect with 1–2 bridges (no crossing, all connected, counts satisfied). It's a **fixed database of 110 hand-authored levels** (gridSize 4×20, 5×30, 6×35, 7×25 — max 7×7) and it literally **ends at level 110.** No procedural generation. The ceiling is the authored set, not a plateau.

**Key asset:** Bridges already has a working logic solver in the screen (`_SolverIsland`, used for hints) — so the generator is half-built.

**Structural fix — procedural generator wrapped around the existing solver**, used as a **no-guess + uniqueness filter** (Hashi is a deduction puzzle — reject guess-required boards). Then scale by logic depth, same family as Sudoku / Mine Finder but **lower-effort since the solver exists.**

| Lever | What it does |
|-------|--------------|
| A — grid size | authored 4–7; generator extends beyond 7×7 |
| B — island count / density | more islands, denser layout |
| C — no-guess + deduction tier | fully-deducible boards rated by hardest logic chain required |
| D — soft timer | late/endgame |

| Stage | Levels | Grid | New lever | Notes |
|-------|--------|------|-----------|-------|
| 0 — Learn | 1–20 | 4×4 (authored) | sparse islands | use existing DB as the base ramp |
| 1 — Grid + density | 21–110 | 5×5 → 7×7 (authored) | A + B | the 110 authored levels as curated ramp |
| 2 — Procedural + bigger | 111–150 | 7×7 → 9×9 (generated) | generator kicks in | endless past the authored set |
| 3 — Deduction tier | 151–180 | generated | C (no-guess, deeper logic) | |
| **6 — Rotation** | **181+** | **rotates grid sizes** | D + rotation | endgame |

**Endgame (L181+):** grid rotates × {dense islands, hard-deduction-required, timer}. Reuse the authored 110 as the hand-crafted opening, then the generator carries it endlessly.

---

## Applying the model to every game

General recipe for any grid-capped game:

1. **Base progression** — stages that each introduce one lever (grid growth first, then perception/constraint levers), learned in isolation, up to ~L140.
2. **Archetype pool** — retain every earlier grid size / layout / base config.
3. **Endgame (L141+)** — rotate an archetype from the pool (grid size included in the rotation) × a rotating 2–3 of the levers, deterministic per level index. Difficulty rides the modifier intensities; grid and lever selection ride the rotation for variety.

| Game | "Grid" lever | Non-size levers (rotate these) |
|------|--------------|-------------------------------|
| Odd Color Out | grid 2×2–9×9 | delta→JND, hue channel, noise, gradient, timer |
| Grid Path | grid 3×3–6×6 + shape | structured walls, barrier-walls, sparse waypoints, timer |
| Circuit Guide | grid 3×3–8×8 + targets | tortuosity, junction density, scramble depth, decoys, timer, move budget |
| Pattern Lock | grid 3×3–7×7 + length | path/turn complexity, distractors, reverse, rotated-grid, no re-peek, (late) memorize timer |
| Star Battle / Queens | grid 5×5–10×10 (=stars=regions) | region contortion, ★★ two-star mode, timer |
| Sum Sudoku (Killer) | grid 4×4–9×9 + number range | cage size/irregularity, fewer givens, sum ambiguity, operation cages, timer |
| Color Flood | grid 5×5–9×9 + colors | move-buffer tightness, center seed, obstacle cells, timer |
| Hue (Spectrum) | grid 3×3–12×13 | fewer/no anchors, gradient complexity, hue-only/subtle steps, swap limit, timer |
| Chimp Test | grid size + count **(count capped ~15, sawtooth)** | timed exposure, spatial spread, position shuffle, decoys (modifiers accumulate/rotate) |
| Word Hive | letter set (fixed 7) + target | min word length, letter stinginess, pangram, timer, **procedural letter-sets** (not board rotation) |
| Sudoku | grid 4×4–9×9 + clues (17 floor) | **required-technique tier**, variant rules, timer |
| Mine Finder | grid 5×5–16×16 + density | **no-guess + deduction depth**, limited flags, hidden count, timer |
| Colour Link | grid 4×4–8×8 | pair count/density, path tortuosity, walls, bridge tiles, timer |
| Bridges | grid 4×4–9×9+ + islands | **procedural gen (reuse solver)**, no-guess deduction tier, density, timer |
| Masyu / Pearl Loop | grid 5×5–9×9 + pearls | pearl sparsity, black ratio, loop tortuosity, technique tier, timer *(detail in `masyu_sum_level_fix.md`)* |
| Sum Strike | grid 3×3–6×6 | number range, negatives, ~50% strike density, deduction tier, timer *(detail in `masyu_sum_level_fix.md`)* |

Part 3 can extend this to the remaining grid-capped games.

---

## Notes for implementation (later)

- Endgame level index → (archetype, lever-combo) must be a **deterministic** function (hash of level index), so the same level number always plays the same across players and reloads.
- Cap the *combined* intensity (never smallest-delta **and** highest-noise **and** shortest-timer at once) so the endgame stays hard-but-fair.
- Measure Odd Color Out's delta in a perceptually-uniform space (OKLab/CIELAB) so "delta" is consistent across hue/lightness/saturation and can be pinned to a real JND floor.
- The timer, gradient (`prism`), blackout (`eclipse`), and mirror machinery already exist as daily-challenge modifiers — the endgame levers can reuse that code.
- Unique-solution enforcement is intentionally **not** part of this plan (per design decision).
- **Timer is a universal lever**, but a **"moves" lever takes a game-specific form** — tile rotations in Circuit Guide, taps / wrong-taps in Odd Color Out, limited-undo in Grid Path (its path length is fixed, so a raw move cap doesn't fit). Keep timer and moves as *alternatives* in the endgame rotation, not a stacked pair.
- This is a scaling *design*; nothing here is implemented, and it does not touch game rules, other games, challenges, or the stats screen.
