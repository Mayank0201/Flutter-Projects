# CogniQ — Remember & Rulebook

**Last reviewed:** 2026-07-18 (claims re-verified against source; see Section B)
**How to use this file:** Read Sections A–E before coding. They are either hard constraints, facts verified in the source, or decisions the user actually made. Section F is *proposals only* — ideas generated during analysis that have NOT been decided or validated; treat them as a backlog to discuss, not a plan to execute.

> Integrity note: earlier drafts of this file mixed verified facts with subagent-generated strategy and invented metrics. This version separates them. Any number describing user behaviour (retention, session length, MAU) is an **assumption**, not measured data — the app currently ships **no analytics/network layer** (`ActivityTracker` writes only to local `SharedPreferences`), so none of those baselines can be known until analytics is added.

---

# SECTION A: HARD CONSTRAINTS (do not touch without explicit approval)

- **The 16 active games** — do not modify their logic/screens unless asked. IDs: `zip` (Grid Path), `oddcolor` (Odd Color Out), `chimp` (Chimp Test), `queens` (Star Battle), `minesweeper` (Mine Finder), `hue` (Spectrum), `sudoku`, `spellingbee` (Word Hive), `pattern_lock`, `colour_link`, `color_flood`, `circuit_guide`, `masyu` (Pearl Loop), `bridges`, `sumstrike` (Sum Strike), `killersudoku` (Killer Sudoku).
  *(Updated 2026-08-22: was 12. Pearl Loop, Bridges, Sum Strike and Killer Sudoku went live after this file was first written.)*
- **The daily challenges system** — off-limits unless asked.
- **The stats screen** (`_StatsTab` in `home_screen.dart`) — off-limits unless asked.

Everything else (achievements UX, settings, new games, scaling logic) is fair game per the decisions below.

---

# SECTION B: VERIFIED CODE FINDINGS (checked in source 2026-07-18)

> **All three bugs below were re-checked on 2026-08-22 and are now FIXED.** Kept for
> history. B1: the haptic helpers gate on `_hapticEnabled`. B2: `AchievementManager`
> has a `claim(id)` method and rewards are no longer dispatched inline. B3:
> `completionist` now compares against `activeGames.length` rather than a hardcoded 15.
> B4's plateaus were also re-verified during the August audit — Circuit Guide's ramp
> turned out to be fine (it climbs every 4–7 levels); the flat games were Bridges,
> Masyu, Sum Strike, Word Hive and Killer Sudoku, all since addressed.

### B1. Haptic toggle is dead — bug 🔴
`lib/theme/settings_manager.dart`, lines 84–94. All three helpers gate on `_soundEnabled`:
```dart
void hapticTap()     { if (_soundEnabled) HapticFeedback.lightImpact(); }
void hapticSuccess() { if (_soundEnabled) HapticFeedback.mediumImpact(); }
void hapticError()   { if (_soundEnabled) HapticFeedback.heavyImpact(); }
```
`_hapticEnabled`, its getter, and `setHaptic()` exist but gate **nothing** → the haptic setting does nothing; haptics follow the sound toggle.
**Fix:** change all three checks to `_hapticEnabled`.

### B2. Achievements are auto-claimed — confirmed 🔴 (this is the user's #1 requested change)
`lib/utils/achievement_manager.dart`, `checkAndUnlock()` (lines 214–352). The moment a condition is met it BOTH marks the id unlocked AND dispatches every reward inline (lines 318–344): points via `PointManager.addPoints`, titles → `unlocked_titles`, trail styles → `unlocked_trail_styles`, and `swipe_trail_unlocked` for `centurion`.
**To make claiming manual:** split this — `checkAndUnlock` should only mark "unlocked-but-unclaimed"; move the reward dispatch (322–343) into a new `claim(id)` called when the user taps Claim. Trails are dispatched via `rewardTrailStyle`, so routing them through `claim()` automatically satisfies "same manual claim for trails."

### B3. `completionist` achievement is unreachable — bug 🔴
`achievement_manager.dart` line 281 requires `playedGamesCount >= 15`, and its description says "Play all 15 active games," but only **12** active (non-stashed) games exist. It can never unlock. Change the threshold to 12 (or the current active-game count) when touching achievements.

### B4. Not personally re-verified this session (came from the scaling subagent — spot-check the file/line before acting)
The difficulty plateaus below were reported in `DIFFICULTY_SCALING_ANALYSIS.md` (a file that no longer exists) and were NOT re-read from source in this pass. Verify the exact clamp/const before editing:
- Circuit Guide — capped ~5×5 + 4 targets
- Mine Finder — `gridSize` clamped to 13
- Pattern Lock — capped at 5×5
- Sudoku — fixed level list, cycles instead of generating
- Spectrum — plateaus ~10×11

---

# SECTION C: USER-CONFIRMED CHANGES TO MAKE

### C1. Achievements → manual claim (see B2 for the mechanism)
- Remove auto-claim; add a **Claim** button per unlocked achievement in the achievements screen.
- Achievements must be **clickable/tappable** to claim.
- **Trails**: same manual-claim behaviour (clickable to claim).
- **Reduce the achievement toast timer** (currently too long → ~4–5s or less). Check `lib/widgets/achievement_toast.dart` for the duration.

### C2. UI alignment (user said the rest of the UI is fine)
- **NavBar (home tab):** when Home is selected the highlight capsule shows, but the icon + label are **not centred** within it. Fix in `home_screen.dart` → `_buildCustomBottomNavBar()` / `_buildNavItem()`.
- **Games grid alignment** on the home screen needs adjustment — `_buildHomeTab()` `GridView.builder` (spacing / `childAspectRatio` / padding).

### C3. Features the user judged "good enough" — leave alone
Notifications, streaks, daily challenges, and the achievements **core logic** are fine. The only achievements work is the manual-claim UX above.

---

# SECTION D: PRODUCT DIRECTION (endorsed by the user)

### D1. Positioning
CogniQ is a **logic-puzzle** app. Lean into that; don't try to be a well-rounded brain trainer.

### D2. Why not other genres (user's own reasoning)
- **Word games** — hard to generate procedurally; difficulty doesn't scale predictably. Do **not** unstash the old word games to "balance" the library. *(Still stands.)*
- **Memory / reaction games** — hit a boredom ceiling; scaling just means "faster/more," which stops being interesting.
- **Logic games** — each puzzle differs even at the same difficulty, so they stay fresh. This is the moat.

> **Amended 2026-08-22.** The user has decided to broaden beyond pure logic and add
> tactile/perception games too (Sand Sort, Zen Slide, Untangle, Orbit). The ceiling
> warning above was borne out in practice — Odd Color Out and Chimp Test both hit it
> and needed fixing in the August audit — so the rule is now: **build them, but decide
> the hardest fair level up front instead of scaling until impossible.** Note that
> Sand Sort, Zen Slide, Untangle and Orbit are combinatorial underneath and have real
> headroom; only **Split** and **Shadow Match** are pure perception and carry the
> ceiling risk. The word-game rejection is unchanged. See `RELEASE_PLAN.md`.

### D3. Scaling philosophy — "don't just make it harder, make it different"
Add *secondary mechanics* as levels climb rather than only enlarging the grid: time pressure, a memory component, grid/shape evolution, hidden information, movement/rotation, and combinations of these. (Per-game progressions once lived in `DIFFICULTY_SCALING_ANALYSIS.md`, since deleted — the ideas shipped as the August 2026 modifier-rotation work; see `RELEASE_PLAN.md` for what remains planned.) Worked example (Odd Color Out): single off-tile → two mutually-different tiles → rank 3 shades → position memory → moving grid → combined conditions.

### D4. New games to add (logic only, all scale naturally)
- **Kakuro** — arithmetic + logic; fills the number-reasoning gap.
- **Cipher Decoder** — treat as a *logic* puzzle.
  > **Superseded 2026-08-22.** The original idea here was "early levels every letter
  > is off by 1; later levels one word differs by 1, another by 2". The scaling
  > instinct was right but the input model was the problem: the UI maps each cipher
  > letter to one global guess, so the moment a letter appears in two words with
  > different shifts the puzzle is unsolvable. Measured: **73.7% of levels 6-12 and
  > 100% of levels 13+ cannot be solved.**
  >
  > **Decided instead — the "suitcase lock":** one 0-25 **shift dial per word**,
  > replacing the letter keyboard entirely. Turn each dial until the phrase reads as
  > English. Solvable by construction, and because shifts are progressive
  > (`base + wordIndex`) cracking one word gives you all the others — so it stays a
  > single-unknown *logic* puzzle rather than a vocabulary exercise. Full work order
  > in `RELEASE_PLAN.md` §4.5D (moved to release 2.3).
- **Hitori** — cell-elimination; distinct mechanic.
- **Slitherlink** — loop/path logic; complements Colour Link.
- **Killer Sudoku** — variant leveraging existing Sudoku familiarity.
- Later candidates: Shakashaka, Yin-Yang, Norinori, Thermostat.
- **Rejected:** Nonogram (allows multiple solutions → ambiguous, bad for a logic app). Chain Breaker / Frequency / Vault Builder are novel but high-cost and niche — parked, not planned.

> **Correction 2026-08-22:** the old `GAME_SUGGESTIONS_WITH_DESIGN.md` did **not** contain
> specs for any of the games above (it covered ten different games, with factual errors in
> its worked examples) and has been **deleted**. Build specs for D4 games come from
> `cogniq_builders_handbook.md` or are written fresh per `RELEASE_PLAN.md`.

### D5. Beta prototype status (audited 2026-08-22)

All prototypes in `lib/screens/games/beta/` are **demos, not games**: 187–409 lines,
5–10 hand-typed levels, fixed 3×3/4×4 boards, and **zero** generation, seeded RNG,
hints, points, or modifiers. They save to their own `beta_level_*` keys, so they are
outside `PrefsKeys` and get no Zen, trails or achievements. None are registered in
`kAllGames` and none have routes — they are unreachable in the app. Reviving one is
~70% of building a new game, not 20%.

**Worth finishing** — mechanic is sound, just unbuilt:
- **Skyscrapers** — all 10 levels brute-force verified solvable and unique. Levels 6 and 8
  are byte-identical; 2 and 7 nearly so.
- **Nurikabe**
- **Light Up**

**Broken against their own rules — REWRITE, do not "finish"** (kept for reference only,
deliberately unscheduled):
- **Tent and Trees** — `_checkSolution` validates only row/column counts. Tent-tree
  adjacency and no-two-tents-touching are never enforced, so the trees are decoration.
  4 of 5 stored solutions place tents touching no tree (illegal under the game's own
  instructions), 3 of 5 levels accept two answers, and the hint guides players to the
  illegal solution.
- **Thermometers** — no deduction exists. All three thermometers are vertical, one per
  column, bulbs at the bottom, so the three column clues reconstruct the answer directly;
  the row clues are decorative.
- **Shakashaka** — cells cycle `0→1→2`, giving two triangle orientations where the real
  puzzle needs four. The win check compares against a stored answer instead of verifying
  the rectangle rule, so valid alternative solutions are rejected.

**Parked** — sound code, thematic overlap:
- **Kakurasu** — win check implements the real weighted-sum rule correctly and all 5
  levels are brute-force verified unique. Held back only because it would be the third
  addition puzzle alongside Sum Strike and Kakuro. Revisit after Kakuro ships in 1.9.

**Deleted 2026-08-22:** KenKen (overlaps Killer Sudoku), Binairo (repetitive),
Futoshiki (overlaps Sudoku/Skyscrapers), Map Memory (memory ceiling).

---

# SECTION E: PERFORMANCE RULEBOOK (mandatory when writing/modifying game code)

These are the original project rules — they prevent jank during drag/pan/tap.

**1. No unconditional `setState` in gesture loops.** Never `setState()` every frame in `onPanUpdate` / `onPointerMove`. Use a `ValueNotifier` or a `CustomPainter`'s `repaint` listenable. For grid selection, diff against current state and only `setState` when a tile boundary is actually crossed.

**2. Isolate dynamic painters/grids in `RepaintBoundary`.** Wrap drag/draw areas so their repaints don't dirty the whole screen (AppBar, backgrounds, buttons).

**3. Optimize `CustomPainter`.** Implement a real `shouldRepaint` (never `=> true`). Pass an `AnimationController`/`ValueNotifier` to `super(repaint: …)` so the canvas repaints without rebuilding parents.

**4. No animation-listener `setState`.** Don't `controller.addListener(() => setState(...))` for drag effects — it rebuilds the whole tree per frame. Use the `repaint:` param or a tightly-scoped `AnimatedBuilder`.

**5. Defer heavy side-effects.** No disk writes (`SharedPreferences`) or O(N²) win-checks inside `onPanUpdate`. Keep changes in memory; persist/verify in `onPanEnd`/`onPanCancel`. Debounce quadratic checks.

**6. Keep hot paths O(1).** No `list.contains()`/`list.any()` inside `paint()` or `itemBuilder`. Maintain a `Set` of selected coordinates for O(1) lookups.

**Pre-commit checklist:**
- [ ] No per-frame `setState` during drag (only on a real tile change)
- [ ] Drag coords via `ValueNotifier`, not page state
- [ ] Grid/canvas wrapped in `RepaintBoundary`
- [ ] `CustomPainter` has a proper `shouldRepaint`
- [ ] Animation ticks don't trigger page-wide rebuilds
- [ ] Disk writes deferred to `onPanEnd`
- [ ] No linear scans in `paint()` / `itemBuilder`; use `Set`

---

# SECTION E2: CONSISTENCY & CORRECTNESS STANDARDS

*Merged 2026-08-22 from the repo-root `remember.md`, which is now a pointer stub.
These are the rules from the August 2026 audit of the 16 live games. They record
decisions that are easy to undo by accident — read them before touching a game
screen, a level list, or the modifier system.*

These sections were added after a full audit of the 16 live games. They record
decisions that are easy to undo by accident, so read them before touching a
game screen, a level list, or the modifier system.

---

## 🎯 7. One Header Design for Every Game

Every game screen must use the same app-bar shape. Before this was enforced,
each game hand-rolled its own and they drifted: different font sizes, some set
a background colour and some did not, one used an animated level widget, and
Spectrum put the level in the body instead of the app bar. Several also
overflowed on a narrow phone because a three-digit level is wider than a
one-digit one.

- **Title**: `const GameTitle('Game Name')` — nothing else. No level number, no
  mode suffix, no bespoke `Text` with its own `GoogleFonts` call.
- **Level**: `GameLevelChip(...)` as the **last** entry in `actions`. It renders
  "Level N" plus a pencil, or the mode label for tutorial/daily runs.
- Both live in `lib/widgets/game_level_chip.dart` and both scale down instead
  of overflowing.
- Do **not** add a second level indicator anywhere else on the screen.

```dart
appBar: AppBar(
  backgroundColor: context.bgDark,
  foregroundColor: context.textPrimary,
  title: const GameTitle('Bridges'),
  actions: [
    // ... hint button, rules, etc.
    GameLevelChip(
      level: _currentLevel + 1,
      modeLabel: _playDailyMode ? 'Daily' : null,
      accent: AppTheme.accentFor('bridges'),
      onTap: kDebugMode ? _showJumpToLevelDialog : null,
    ),
  ],
),
```

**Keep the actions list short.** An app bar fits roughly three icon buttons plus
the level chip on a 360px phone. If a game needs more, collapse Rules/Reset into
a single `PopupMenuButton`, as Word Hive does.

---

## 🧩 8. Modifiers: Never Announce What You Do Not Apply

A modifier named in the caption must actually change the level.

- Sum Strike advertised `negatives`, `denseStrike` and `whisper` on about 170
  hand-authored levels where only the generated branch honoured them. If a
  modifier shapes the board *during generation*, it cannot apply to a curated
  level — leave it out of the pool for those levels.
- Circuit Guide offers only presentation modifiers (`timer`, `retro`, `fog`)
  below its endgame, for the same reason.
- Every game must show its active modifiers to the player. Bridges and Masyu
  previously showed none at all, so boards arrived fogged or zoomed with no
  explanation.

`test/difficulty_curve_test.dart` guards the schedule. A modifier audit lives in
that file's `pools` map — add new games there.

---

## 📈 9. Difficulty Must Climb, and Something Must Change Early

- **Modifiers start per game** via `RotationEngine.modifierStartLevel`, not at a
  flat level 30. Games whose board holds one size for a long opening (Bridges,
  Masyu, Sum Strike, Killer Sudoku, Word Hive) start around level 10–12.
- The schedule goes **breadth first, then intensity**: every modifier appears
  alone, then every distinct pair, then every distinct triple. Combinations are
  enumerated, not sampled, so a player never sees the same pairing twice until
  the set is exhausted.
- **Never let difficulty run backwards.** Killer Sudoku's first ten levels used
  to alternate 4x4 and 6x6; the Chimp Test's procedural tier reset from 60
  numbers back to 7. Both were bugs, not tuning.
- `smallGrid` must **not** be used to add more modifiers. It did, which meant a
  small early board got the maximum number of them.

---

## 📐 9b. Every New Game Goes Into the Layout Harness, Same Day

Three releases in a row — 1.9, 2.0, 2.1 — shipped two games each and **added none of them**
to `test/layout_overflow_test.dart`. Six games with no layout regression coverage. Worst of
all, **Hitori** was in that list: the game whose 908px overflow is the entire reason anyone
cares about that file was fixed in 2.0 and then never given a test, so it silently kept a
second, smaller overflow (106px at 320x568) that was still live in the shipped build.

Two rules, both cheap:

1. **Reviving or adding a game means adding it to `test/layout_overflow_test.dart` and
   `test/all_games_all_levels_test.dart` in the same change.** The revival checklist already
   says this; it was skipped three times because nothing failed when it was skipped. A test
   that is missing never goes red.
2. **A fixed bug gets a regression test before it is called fixed.** "Fixed in the browser,
   confirmed by eye" is how the same bug comes back one release later.

**And the harness must include a wide-short viewport.** Until 2026-08-22 the sizes were
320x568, 412x915 and 480x1000 — all taller than wide. A board sized `width * 0.85` fits
vertically in every one of them, so the whole width-only-sizing bug class could not be
detected *by construction*. Landscape phones, tablets, desktop windows and Android
split-screen are all wide-short. `1568x696` is now in the list; do not remove it to make
something pass.

**Size a board from BOTH axes, or better, from the constraints it is actually handed.**
`MediaQuery` includes chrome the board does not own, and a fixed `height - N` reserve is
wrong at some font scale or locale because the surrounding text wraps to more rows on a
narrow screen. `hitori_screen.dart` and `slitherlink_screen.dart` show the shape: measure
with a `LayoutBuilder`, and keep a scroll fallback so the failure mode is "scrolls a little"
rather than "clips the controls".

---

## 🕳️ 10b. A Fallback Board Is a Lie Unless It Is Verified

Every generator we have opened in 1.9–2.1 shipped an unwinnable board through its
*fallback*, not through its main path. The main path is the part that gets tested; the
fallback is the part that runs when the main path gives up, which is exactly when nobody
is watching.

Three instances, all real, all found by simulation rather than by a test:

| Game | The fallback | What the player got |
|---|---|---|
| Hitori (2.0) | a hardcoded board | **zero** valid solutions across all 65,536 masks; reached ~3% of the time at 4x4 and *always* above it |
| Slitherlink (2.1) | force-add a cell without re-checking | never actually fired — the recorded defect was **wrong**, see below |
| Zen Slide (2.1 sketch) | keep the last *rejected* board, `solve(...).clamp(1, 99)` | `solve` returns **-1** for unreachable, and `(-1).clamp(1,99)` is **1** — an unsolvable board relabelled "one move to solve" |

The Zen Slide one is the pattern at its purest: the clamp did not fix the failure, it
**erased the evidence of the failure** and dealt the board anyway.

**The rule.** A fallback must be *provably* valid by construction, not merely plausible.
Slitherlink's is a single cell, which is a legal loop by definition. Zen Slide has none —
it re-seeds instead. If you cannot state in one sentence why the fallback cannot be wrong,
delete it and widen the retry budget.

**And the corollary:** gate generation on the *same predicate the win check uses*, not on
the heuristics you think imply it. Slitherlink's shape checks (edge-connected + no holes +
no diagonal pinch) took the failure rate from 2.4% to 0.43%. Feeding the derived edges to
`isSingleLoop` — the win check itself — took it to 0%. Heuristics approximate correctness;
only the validator defines it.

---

## ✅ 10. Level Data Must Be Verified, Not Trusted

Sixteen of the fifty-six shipped Sudoku boards were unwinnable — wrong answer
keys, givens contradicting their own solution, or several valid solutions where
the win check accepts only one. They had been in the app for months.

- Any hand-authored level list needs a test asserting the puzzle is legal,
  agrees with its givens, and has exactly one solution. See
  `test/sudoku_levels_test.dart`.
- Puzzles with an **exact-match win check** must have a unique solution, or a
  player who solves it a different valid way is told they are wrong.
- Transposing a board is only safe when its box shape is square. A 6x6 sudoku
  uses 2x3 boxes, so transposing produces a grid the validator rejects.

---

## 💡 11. Hints Add, and Only Take Away When Provably Wrong

A hint must never delete work that could still lead to a solution.

- **Ask first**: solve the board *with the player's moves locked in*. If a
  solution exists that keeps them, they are on a valid line — extend it.
- Only when no solution can contain their moves is one genuinely wrong, and only
  then may a hint remove something. Say why: *"That bridge cannot be part of any
  solution."*
- **Never charge for a hint that did not help.** Bridges and Star Battle both
  deducted one even when the solver gave up.
- Compare what a piece *does*, not its raw value. Circuit Guide compared
  rotation numbers, but an "S" wire at rotation 0 and 2 is the same piece, so
  hints were spent on tiles that were already correct.

---

## 🗝️ 12. Never Rename a Game ID

The internal IDs are inconsistent — Grid Path is `zip`, Star Battle is `queens`,
Spectrum is `hue`, Word Hive is `spellingbee`, Mine Finder is `minesweeper`,
Chimp Test is `chimp`. They are ugly, and they must stay.

Every one is baked into SharedPreferences keys (`level_zip`, `hints_queens`,
`cleared_count_hue`) and seeds `RotationEngine.getDeterminism`, which decides
what each level looks like. Renaming one **wipes that game's progress, hints and
stats for every existing player** and changes every generated board.

If they ever need cleaning up, it requires a migration that copies the old keys
across on first launch. File names and class names are safe to rename; IDs are
not.

---

## 🧱 9h. This Machine Has 7GB of RAM — Build One at a Time, and Kill the Daemons

`flutter build appbundle` failed on 2026-08-23 with:

```
allocation.cc: 30: error: Out of memory.
Dart snapshot generator failed with exit code -1073740791
Target android_aot_release_android-arm failed
```

**Nothing was wrong with the code** — it passed 868 tests and analyzed clean. The machine has
**7 GB total RAM**, and **3.1 GB was held by Gradle daemons and Dart processes left resident
by the four previous builds**. The AOT snapshotter needs a large allocation and could not get
one.

**Before any release build, and between consecutive builds:**

```bash
taskkill //F //IM java.exe; taskkill //F //IM dart.exe; taskkill //F //IM dartaotruntime.exe
```

Then confirm it worked — a build that OOMs looks like a slow build, not a broken one.

Also delete the `build/` directory of any *completed* build before starting the next
(preserve its `.aab` first). Intermediates run to gigabytes each.

**And never run `flutter test` while a build is running.** It causes the
`sandsort_logic_test` timing flake documented in `md/TESTING_CHECKLIST.md` — 2064ms under
contention versus 281ms alone, against a 500ms bound.

---

## 👁️ 9i. A Watcher That Only Waits for Success Never Reports Failure

The OOM above went **unnoticed for over 20 minutes**, and was verbally reported as "healthy,
in the R8 phase", because the watcher was:

```bash
until [ -f "$OUT/app-release.aab" ]; do sleep 30; done      # WRONG
```

A build that dies never creates that file, so the loop waits forever and **silence is
indistinguishable from progress**. This is §9d ("audit what a check does not look at") applied
to tooling rather than tests.

Always watch for the failure signatures too, and exit on either:

```bash
while true; do
  [ -f "$OUT/app-release.aab" ] && { echo SUCCESS; break; }
  grep -qiE "BUILD FAILED|Out of memory|failed with exit code" "$LOG" && { echo FAILED; break; }
  sleep 30
done
```

And **never redirect a build to `/dev/null`** — without a log there is nothing to grep, and
the only symptom of failure is a wait that never ends.

---

## 🔬 9m. Validate the Measuring Instrument, Not Just the Thing Measured

§9c says measure the generator instead of believing it. The same rule applies to **the tool
doing the measuring** — and it has already caught two real faults:

* A probe's Slant solver **silently undercounted solutions on 5 of 180 boards** (a failed
  assignment mutated state the undo path never restored). It was found only because the solver
  was cross-checked against exhaustive enumeration *before* its numbers were used. Every
  downstream conclusion would have been wrong, and would have looked entirely plausible.
* Nineteen "0 solutions" results for the Fit polyomino probe were **all false** — the solver
  hitting its node budget, not an absence. One board reported "0" actually had **at least 50**
  solutions (§9g).

**So: before trusting a solver, a counter or an audit script, prove it can find the answer on
cases where the answer is already known.** Exhaustive enumeration on small instances is the
usual way, and it is cheap — 3x3 and 4x4 Slant grids, all 2^(n²) of them, settled it in
seconds.

The general shape, and the reason this keeps recurring: **a measurement tool fails silently by
construction.** A broken generator eventually produces a board somebody cannot solve. A broken
*measurement* produces a confident number that nobody can tell is wrong. That asymmetry is why
the instrument deserves more scepticism than the thing it measures, not less.

Also worth pinning: the same audit that found Hitori's dead `timer` **first reported a false
positive** on Cipher Decoder, because the detector matched `_gameId` while that screen uses a
top-level `_kGameId`. A false positive left unexamined trains you to ignore the audit.

---

## 🔢 9g. A Grep That Returns Zero Is Not Evidence

Twice in one session a counting command returned a clean-looking zero that was simply wrong,
and both times the false zero was reported as a result:

| Claim | Command used | Why it was always zero |
|---|---|---|
| "0 errors" | `grep -c 'error •'` | `flutter analyze` writes `error - `, not `error •` |
| "0 warnings" | `grep -c '^ +warning - '` | warning lines start at **column 0**; only *info* lines are indented |

The real figures were 2 errors (at that moment) and **58 warnings** — every release note in
this project claimed zero warnings for months.

**The rule: a filter that reports "none found" must be proven able to find something.** Before
trusting a zero, run the same command with the filter inverted, or against a case you know
matches, and check the total adds up:

```bash
# Prove the categories sum to the reported total
flutter analyze 2>&1 | grep -oE "^ *(error|warning|info) " | sort | uniq -c
flutter analyze 2>&1 | tail -1     # "N issues found."
```

Zero is the most dangerous result a check can return, because it looks like success and like
a broken check in exactly the same way. Treat an unexpected zero as a bug in the check until
proven otherwise.

The correct incantations for this project:
`grep -cE '^ *error - '` · `grep -cE '^ *warning - '` · `grep -cE '^ *info - '`.

---

## 📉 9k. A Long Difficulty Ladder Fights the Modifier Rule — Compress the Ladder

`test/difficulty_curve_test.dart` encodes a real product rule:

> **"no game leaves the player without variety for 30 levels"** —
> `expect(RotationEngine.modifierStartLevel(id), lessThan(31))`

Cipher Decoder (2.3) was built with a ladder that adds one independent unknown at a time and
**climbs for 45 levels**, where every other game plateaus around **12**. That creates a trap
with no good answer if you only tune the number:

- leave `modifierStartLevel` at the default **15** → modifiers stack on a puzzle that is
  still adding unknowns for another 29 levels;
- move it to **45** (where the ladder actually flattens) → **four tests fail**, because the
  30-level rule is violated.

**The fix is the ladder, not the constant.** Compress the tiers so the structural climb
plateaus at or before level 30, then let modifiers take over there. Both constraints are then
satisfied at once, and the game matches the shape every other game already has.

**The general lesson:** when two encoded constraints cannot both be met by tuning a number,
the number is not the problem — one of the designs is the wrong shape. Changing the constant
until the suite goes green would have silently traded a tested product rule for an untested
one.

---

## 🧪 9j. `practice_screen.dart` Is NOT Dead Code

`lib/screens/games/practice/` (158 lines, route `/practice`) has every marker of dead code:
routed in `main.dart`, absent from `kAllGames`, and nothing in the app navigates to it. It
was proposed for deletion in the 2.3 cull on exactly those grounds.

**Owner decision 2026-08-23: keep it.** It is the owner's own practice scaffold *and* the
runnable reference `md/GAME_WIRING_CHECKLIST.md` is built around — that file names the
screen and route in three places. Deleting it would strip a working example of the correct
prefs / hint / `RotationEngine` / loss-overlay wiring and leave the checklist dangling.

The general point: **"nothing references it" is evidence, not a verdict.** Before deleting
anything that looks orphaned, check whether the *documentation* depends on it, and ask
whoever owns the project why it exists.

---

## 🔎 9f. The Four Audits — run these, they are cheap and total

Tests prove what they look at. These four checks prove a *class* of defect absent across the
whole project, and each has found a real bug that every suite was green through.

**1. Every pooled modifier is actually acted on.** Parse each pool in
`difficulty_curve_test.dart`, strip comments from each game screen, and assert the modifier
name is read in code — `_isModActive('x')`, `_activeModifiers.contains('x')`,
`_dailyModifierType == 'x'`, or `case 'x'`. Stripping comments matters: a modifier named only
in prose looks implemented to a naive grep.
> Found **Hitori's `timer` pooled with no implementation at all** — no `Timer`, no countdown,
> nothing. Live in 2.0 and 2.1; a third of that game's modifier slots did nothing.

**2. Every live game is in BOTH harnesses.** `test/layout_overflow_test.dart` and
`test/all_games_all_levels_test.dart`.
> Found **six games missing** — every game shipped in 1.9, 2.0 and 2.1 — including Hitori,
> which then kept a second overflow that shipped twice.

**3. Every pool maps 1:1 to a rotation id, both directions.** A pool no screen asks for is
dead config; a screen calling `getActiveModifiers` with an id that has no pool gets nothing.
> Note the ids differ from `game_info.dart` ids (`minesweeper`→`mines`, `hue`→`spectrum`,
> `circuit_guide`→`circuitguide`). Match on what the screen passes, not the display id.

**4. Every `Timer.periodic` is cancelled in `dispose`.**
> Found Slitherlink's, and Hitori's when its timer was written.

None of these needs a framework — each is a short script over the source. Run them whenever a
pool, a game, or a screen's lifecycle changes, and **before any build**.

---

## 🕶️ 9d. Audit What a Test Does NOT Exercise

`test/layout_overflow_test.dart` has now been found to have **three separate blind spots, one
release apart**. Every time, it was green, and every time the reason was that it never looked:

| Found | Blind spot | Cost |
|---|---|---|
| 2.1 | every viewport was **portrait**, so `width * 0.85` always fitted vertically | Hitori's 908px and Slitherlink's overflow, both caught by eye in a browser |
| 2.1 | **no game from 1.9, 2.0 or 2.1 was listed** | Hitori kept a second 106px overflow that shipped in 2.0 *and* 2.1 |
| 2.2 | it only ever booted **level 0**, where the modifier rotation is OFF | no modifier chip, caption or countdown was ever rendered — three shipped overflows (Kakuro, Spectrum, Word Hive) |

**The rule:** when a test file is the only thing standing between you and a class of defect,
audit its *coverage surface*, not its pass rate. Ask what inputs it never supplies —
which screen shapes, which levels, which feature flags, which games — and assume anything
outside that surface is untested, because it is.

For this project specifically, a layout test must exercise **at least one level where
modifiers are active** (15+), because a large share of the UI only exists then.

---

## 🪞 9e. A Mirrored Constant Will Drift — Point at the Real One

Two failures this release from the same cause:

- `test/sandsort_screen_test.dart` kept its **own hardcoded copy** of Sand Sort's modifier
  pool and broke the moment the screen's pool changed.
- `test/seasonal_event_manager_test.dart` hardcoded `slitherlink` as its example of "a
  stashed game", and broke the moment 2.1 shipped Slitherlink.

Neither was a real defect; both cost time and both looked like a regression at first glance.

**Export the constant and have the test read it** — the screens now expose
`kSandSortModifierPool`, `kStarBattleModifierPool` and so on, and the tests import those. A
test that copies the value it is checking is only testing that someone updated two places.

Where a mirror genuinely cannot be avoided (`difficulty_curve_test.dart` holds a pool table
by design, so a pool change is a deliberate decision rather than an accident), say so in a
comment and keep it in one place.

**And never use a game on the revival calendar as a stand-in for "stashed".** Pick from the
beta prototypes; they are not scheduled.

---

## 📏 9c. Measure the Spec Before You Build On It

`md/cogniq_builders_handbook.md` is a **design sketch, not a specification**, and every game
built from it so far has needed defects fixed first:

| Game | Release | Found in the sketch before building |
|---|---|---|
| Zen Slide | 2.1 | **6 defects**, incl. a fallback that relabelled unsolvable boards as "one move to solve" |
| Untangle | 2.2 | **4 defects**, incl. 54% of level-1 boards dealt already solved and 99% of late boards with overlapping nodes |

The handbook is still worth using — both of its core ideas (BFS-gated generation; planar by
construction) were correct and were kept verbatim. The rule is not "distrust the handbook",
it is **transcribe its generator, run it a few thousand times, and measure the properties it
claims** before writing a line of screen code. Both sets of defects were found in under ten
minutes that way, and every one of them would have shipped.

**What to measure, at minimum:**

1. **Is the stored solution actually valid?** Feed it to the same predicate the win check
   uses. Hitori shipped a solution that was illegal on 96% of boards.
2. **Is the dealt board actually unsolved?** Untangle's level 1 was already won 54% of the
   time. Nobody checks this because it sounds absurd until it is measured.
3. **Can the player physically interact with every element?** Untangle drew two nodes on top
   of each other on 99% of late boards. Geometrically fine, completely unplayable.
4. **Does difficulty actually climb, measured on shipped boards** — not on the knob? Assert
   against generated output, never against the parameter you set. A knob that rises while
   the measured board does not is the most common way a curve test passes and lies.
5. **Does the fallback fire, and is it valid when it does?** See §10b.

**Report the numbers, and correct yourself when they contradict you.** Untangle's minimum-
crossings gate was written up as the difficulty lever; measurement showed it almost never
binds (level 16 asks for 7 crossings, gets 322). Edge density is the real lever. A plausible
mechanism that does not bind is worse than no mechanism, because it stops anyone looking for
the real one.

---

## 🗓️ 12b. Seasonal Events Are Annual, and Their Content Must Be Live

Decided by the owner on 2026-08-22. Four events a year on a **quarterly rhythm**, anchored
to the 18th of Dec / Mar / Jun / Sep, each running just over two weeks.

**Windows recur every year** (`MonthDay` → `MonthDay`), they are not absolute dates. The
reason is structural, not stylistic: CogniQ has **no backend**. An event pinned to
"18 Dec 2026" fires once and is dead forever on any device that stops taking updates — and
most devices eventually do. A recurring window keeps working on a binary nobody updates
again. One-off events are still expressible via `firstYear` / `lastYear`.

**Three rules that must hold for every event added:**

1. **Every `featuredGameIds` entry must be a live, non-stashed game with a real route.**
   A stashed id sends the player at an unregistered route and `MaterialApp` declares no
   `onUnknownRoute` — that is a crash, and it is exactly the bug that was **live in 1.8**
   until `DailyChallengeManager._isLiveGame` was added. `SeasonalEventManager.validate()`
   and a test both check this. Never hand-wave it.
2. **Every event's badge id must exist in `AchievementManager.allAchievements`** with
   `category: 'seasonal'`. Without that entry the badge unlocks correctly but the
   achievements screen renders nothing for it, because that screen builds from
   `allAchievements`. The id must also match no `case` in `checkAndUnlock` — the event
   manager owns the unlock condition and must not be second-guessed there.
3. **`featuredModifierTypes` are named, not applied.** They are metadata for future content
   work. Per rule 8 above, the banner therefore advertises **featured games only**. The day
   someone wires those modifiers into play is the day the banner may name them — not before.

**Two traps already hit here, both avoidable:**

- A test hardcoded `slitherlink` as its example of "a stashed game". Slitherlink shipped in
  2.1 and the test broke. **Never use a game on the revival calendar as a stand-in for
  "stashed"** — pick from the beta prototypes, which are not scheduled.
- The home banner's claim handler hardcoded `event_winter_lights`, so it silently did
  nothing for the other three events. **Resolve the badge from the running event**
  (`activeEvent()!.definition.badge.id`), never by name.

---

## 🚪 8c. A Feature Nobody Can Reach Is a Feature That Does Not Exist

Three separate cases found on 2026-08-23, all the same shape — **the machinery was built, the
way in was never wired**:

| What existed | Why nobody could use it |
|---|---|
| `settings_screen.dart`, a complete settings page | registered at `/settings`, but **nothing ever navigated there**. The analytics opt-out lived only inside it, so consent could not be withdrawn. |
| `big_board` and `speed_demon` achievements | `onLevelCleared` sets their flags only when a caller passes `isBigBoard`/`isSpeedDemon` — and **no call site anywhere passed either**. Both sat locked at 0% forever, inflating the "N / 41 unlocked" denominator. |
| `SettingsNotifier.setHaptic` | **zero UI call sites.** Haptics fired throughout the app with no way to turn them off. |

None of these produce an error, a failing test, or a warning. The code is correct; it is
simply unreachable. **Only reading the UI as a player finds them.**

**So, periodically — and always before a release:** for each feature that exists in code, ask
*what taps get a player here?* If you cannot name the path, it is not shipped, however
finished it looks.

The scripted version of this catches the coarse cases and is worth re-running (routes
registered vs navigated; files never imported; prefs keys never read; screens never
constructed) — but the settings bug was found by **reading**, not by a script, because the
route *was* registered. A script can prove absence of a reference; only a person can notice
that nothing sensible leads to it.

---

## 🧹 8d. When a Reset Says "All", Make It Mean All

`resetAllProgress` claimed to clear "all your level data and streaks" and wiped five key
prefixes — missing **Zen levels, Zen tallies, mid-game saved boards, and saved routes.** A
player who reset could therefore have a game restore a half-finished board against a level-0
counter.

Two rules from the fix:

1. **Enumerate what you wipe, never wildcard.** The corrected version lists each prefix
   explicitly and reads the key names from their owning managers (`ZenMode.zenGameLevel('')`
   rather than a copied `'zen_level_'` literal) so the strings cannot drift apart — §9e again.
2. **What you deliberately KEEP is part of the contract too.** Points, achievements, trails,
   titles and purchases survive a progress reset by design. Write that down next to the code,
   or the next person "fixes" it.

Whenever a saved-state key is added to any game, it must be added here in the same change —
this is the same class as §9b's "new game goes into both harnesses the same day".

---

## 👁️ 8b. If the App Changes Behaviour, the Player Must Be Able to See It

Rule 8 says *never announce what you do not apply*. Its converse matters just as much and has
been broken three times:

| What happened | Found |
|---|---|
| Star Battle's `timer` countdown rendered only at ≥360px, so on a small phone the timer ran with nothing on screen saying so | 2.2 |
| Hitori pooled `timer` with **no implementation at all** — a third of its modifier slots silently did nothing | 2.3 |
| **Zen mode had no indicator on any game screen** | 2.4 |

The Zen one was the worst, because the consequence is invisible *and* alarming: Zen is a
**separate progression with its own saved levels**, so a player who toggles it by accident
sees their level numbers change with nothing on screen explaining why. It looks like lost
progress.

**Fixed in 2.4 in `GameLevelChip`, not in 24 game screens.** The chip reads `ZenMode.isEnabled`
itself, so every game gets the indicator from one place and **no future game can forget it**.
That is the right shape for anything that must appear everywhere: put it in the shared widget
and let it read the global state, rather than passing a flag through two dozen call sites and
relying on each one to remember.

Two things the fix deliberately preserves, both tested:

* **The level number stays visible in Zen.** `modeLabel` *replaces* the level (that is correct
  for a daily, where no campaign level exists), but in Zen the level is real progress on a
  different ladder. Hiding it would recreate the confusion being fixed.
* **A daily still says "Daily"** even while Zen is on. A daily is never played in Zen.

**Before adding anything to the app bar, re-check the width.** Three separate app-bar
overflows have shipped from exactly this kind of growth. The Zen label plus a leaf plus a
three-digit level plus the debug pencil is the widest the chip can get — that combination is
now asserted at all four viewports.

---

## 🧘 13. Zen Mode Is a Parallel Progression

Zen strips every modifier and keeps its own level record per game, half points,
its own achievements and its own trail.

- `PrefsKeys.gameLevel()` is **mode-aware** — it resolves to `zen_level_<id>`
  in Zen. Anything that must always address Challenge progress (the daily
  challenge backup and restore path) has to use `PrefsKeys.normalGameLevel()`.
- Daily challenges always force Challenge rules, so stars and streaks keep their
  meaning.
- Zen clears must never feed Challenge-side counters, or easy modifier-free
  levels become a way to farm trails and achievements.

---

## 🧱 14. How the Home-Screen Widget Actually Works — read before touching it

*Written 2026-08-23, from reading the code, because this has caused trouble before and
nobody has ever seen the widget render.*

### The whole data path, end to end

There is no clever machinery here, and knowing that is most of the battle. It is four steps:

1. **Dart writes key/value pairs** with `HomeWidget.saveWidgetData(key, value)`.
   Three places do this:
   - `home_screen.dart:1336-1346` — the real update, on every home-screen load
   - `daily_challenge_manager.dart:1512-1515` — `syncStarsToWidget`, the four star counts
   - `settings_manager.dart:153-161` — resets every key to zero when the player wipes data
2. **Dart then pokes the widget** with `HomeWidget.updateWidget(...)`, naming
   `com.mayank.cogniq.StreakWidgetProvider` in all three of `name`, `androidName` and
   `qualifiedAndroidName`.
3. **Android wakes `StreakWidgetProvider.onUpdate`** (`StreakWidgetProvider.kt`), which reads
   those same keys back out of `SharedPreferences` and calls `setTextViewText` for each one.
4. **The layout** is `res/layout/widget_layout.xml`; the widget's own config (size, refresh) is
   `res/xml/widget_info.xml`.

**The contract is the string keys, and nothing enforces it.** Dart writes `"daily_streak"`,
Kotlin reads `"daily_streak"`. There is no shared constant, no codegen, no test spanning both
sides. **Rename a key on one side and the widget silently shows a default forever** — no
crash, no warning, no failing test. If you change a key, change it in all four files above in
the same commit.

### 🔴 The three things to know before you debug it

**1. `updatePeriodMillis` is `0` — the widget NEVER refreshes itself.**
This is the single most important fact and almost certainly the source of past confusion.
Android will *never* wake this widget on a timer. It updates *only* when the app calls
`updateWidget`, which in practice means **only when the home screen loads**. So:

- Player finishes a daily challenge, doesn't return to home → widget is stale.
- Player never opens the app for a week → widget shows week-old numbers.
- You change data and the widget doesn't move → **it is behaving as designed**, not broken.

To test a change, go back to the home screen — that is the trigger. If you want it to refresh
on its own, that is a real feature (`WorkManager`, or a non-zero `updatePeriodMillis` which
Android clamps to ~30 minutes), not a bug fix.

**2. `favorite_game` is written but never displayed.**
`home_screen.dart:1338` computes a favourite game and saves it; `settings_manager.dart:155`
resets it. **`widget_layout.xml` has no view for it and `StreakWidgetProvider.kt` never reads
it.** It is dead data. Either add a `TextView` and read the key, or delete the two writes —
but do not keep believing the widget shows it. (Earlier notes claimed it did; it does not.)

**3. Every failure is swallowed, on both sides.**
The Dart call sits in `try { ... } catch (_) {}` and `onUpdate` wraps everything in
`try/catch` that only logs. This is deliberate — a broken widget must never crash the app —
but it means **a failure is invisible unless you look**. To see what actually happened:

```
adb logcat -s StreakWidgetProvider
```

The provider logs the widget count, every value it read, and any fatal error. That log is the
only diagnostic you have; there is no test coverage of this path at all.

### What it shows, exactly

| Key written by Dart | Where it appears | Notes |
|---|---|---|
| `daily_streak` | `streak_number_text` + `streak_text` | The **daily-challenge** streak. Label is only " Day"/" Days" — the word "streak" appears nowhere |
| `total_solved` | `total_solved_text` | Fed from `completed` (`home_screen.dart:1313`), which is `globalLevelClearedCount` — so this **already matches** Home and Trails |
| `daily_bronze/silver/gold/diamond_stars` | the four star pills | `syncStarsToWidget` |
| `todays_puzzle_name` / `_desc` | the puzzle card | Falls back to "Word Hive" / "Form words with honey letters" if unset — a **stale default that is not today's puzzle** |
| `favorite_game` | **nowhere** | dead, see above |

### Known risks nobody has confirmed on a device

- **It is a 3×1 widget** (`targetCellWidth="3" targetCellHeight="1"`, `minHeight="40dp"`)
  carrying a streak, a solved count, four star pills, a puzzle name, a description and a play
  button. That is a lot in one cell of height. **Overflow is the most likely first bug.**
- `resizeMode="horizontal|vertical"` — so the player can shrink it further. Check the small
  size, not just the default.
- Widget layouts do not follow the app's theme system. Check light **and** dark, because a
  colour that vanishes in one is a classic `RemoteViews` failure.
- The two streaks in the product are now the *play* streak (home screen) and the
  *daily-challenge* streak (widget). The widget labels neither. Decide which one belongs on a
  home screen — arguably the play streak, since it rewards opening the app at all.

### If you change the widget, do these in order

1. `adb logcat -s StreakWidgetProvider` open in a second window before you start.
2. Change the key in **all four** files if you rename one.
3. Place the widget fresh on a home screen — resizing an existing one does not re-run
   `onUpdate`.
4. Load the home screen in the app to trigger the update.
5. Check both themes and both sizes.

---

## 📊 15. Turning Analytics On — the exact steps, when you decide

*Written 2026-08-23. The decision is in `Documents\Cogniq Versions\DECISIONS.md` §2. This is
what to actually do once it is made, so the plan is not reconstructed from scratch a year
later.*

**The work is already done except for one class.** `lib/utils/analytics/` holds a finished
taxonomy, consent handling and a local buffer. Every call site in every game is already
wired. The default sink is `NoopSink`, so **the app makes zero network calls today**, and
`test/analytics_test.dart` holds that property in place.

### The three steps

1. **Add the vendor package** to `pubspec.yaml` (Firebase Analytics is the usual choice for a
   Flutter app, and free at this scale).
2. **Write one class** — `class FooSink implements AnalyticsSink` — mapping `AnalyticsEvent`
   to the vendor's call. It has one real method:
   `Future<bool> deliver(List<AnalyticsEvent> batch)`.
   - Return `true` **only** once the vendor has taken ownership of the batch — that is the
     buffer's cue to drop those events.
   - Return `false` for anything retryable (offline, throttled, not ready). The events stay
     buffered. **This return value is the entirety of offline queuing** — you do not write
     retry logic.
   - **Never throw.** A throwing sink retries forever.
3. **Install it at startup** — `Analytics.setSink(FooSink())`, immediately after
   `Analytics.initialize()` in `main.dart:78`.

Nothing else changes. No game screen, no manager, no widget needs to know a backend appeared.

### 🔴 The trap, spelled out

**Do not let the vendor SDK initialise until `deliver` is actually reached.** `Analytics`
never calls `deliver` without consent — but a vendor SDK constructed eagerly at startup will
happily beacon on its own, and you will have broken the opt-out without touching the opt-out
code. Construct the SDK lazily, inside the first `deliver`.

### Before you ship it — non-negotiable, these are Play requirements

- [ ] **A privacy policy** exists and its URL is in the Play listing.
- [ ] **The Play data-safety form** is filled in and matches what you actually collect.
- [ ] **The opt-out works.** It lives in the Profile tab (Privacy section) — this was fixed on
      2026-08-23, having previously been stranded on an unreachable screen where no player
      could have reached it. Confirm on a device that toggling it off actually stops delivery.
- [ ] `AnalyticsConsentDialog` shows on first run and the choice sticks.
- [ ] Turn it off, play for a while, and confirm with a network inspector that **nothing**
      leaves the phone.

### What it is for — and the deadline that is not negotiable

Two roadmap items depend on this and cannot start without it: **"put popular games first"**
and the 2.4 review of **which games earn their slot**. Both need roughly **three months of
data**, which is wall-clock time — deciding in January gives you data in April, not January.

**"No, never" is a completely valid answer.** "This app collects nothing" is a genuine selling
point and the app has shipped its whole life that way. But if that is the answer, **delete
those two roadmap items** rather than carrying them forever.

---

## Checklist for Future Game Changes
- [ ] App bar uses `GameTitle` + `GameLevelChip`, and nothing else shows the level.
- [ ] Every modifier in the pool actually changes the level, and is shown to the player.
- [ ] The game appears in `test/difficulty_curve_test.dart` and `test/all_games_all_levels_test.dart`.
- [ ] Difficulty never decreases as the level rises.
- [ ] Any new hand-authored levels are covered by a solvability/uniqueness test.
- [ ] Hints only remove a move after proving no solution can keep it.
- [ ] No game ID was renamed.
- [ ] `flutter test` passes, including the layout-overflow suite at 320x568.

---

# SECTION F: PROPOSALS — NOT decided, NOT validated ⚠️

Everything below was generated during analysis as *options to consider*. The user has **not** approved any of it. Do not treat it as a roadmap or cite its numbers as facts. Kept here so the ideas aren't lost.

- ~~12-month roadmap (`FEATURE_ROADMAP.md`)~~ — **deleted 2026-08-22.** Superseded by
  `RELEASE_PLAN.md`; its retention ideas were salvaged there first.
- ~~Social/community (`SOCIAL_COMMUNITY_FEATURES.md`)~~ — **file deleted 2026-08-22.** The decision (backlog; needs backend + accounts + anti-cheat + moderation) and requirements are recorded in `RELEASE_PLAN.md` Part 8.
- ~~Onboarding overhaul (`ONBOARDING_STRATEGY.md`)~~ — **file deleted 2026-08-22.** It advertised features that don't exist and conflicted with the save system. One real fact preserved: tutorial infrastructure already exists (`lib/widgets/game_tutorial_dialog.dart`, `interactive_tutorial_overlay.dart`) — build on it if onboarding is ever revisited.
- ~~Accessibility program (`ACCESSIBILITY_RECOMMENDATIONS.md`)~~ — **file deleted 2026-08-22.** Its low-risk quick wins (semantic labels on grids, WCAG contrast verification, text labels on icon-only buttons) are now commitments in `RELEASE_PLAN.md` work order 4.1C; the broader screen-reader/keyboard program was proposal only.
- **All retention / MAU / session-length figures in those files are illustrative assumptions.** There is no analytics in the app yet. If any of these targets matter, step one is adding an analytics/measurement layer — otherwise success can't be observed.

---

# MD FILE INDEX

| File | Focus | Status |
|------|-------|--------|
| `remember.md` (this) | Constraints, verified facts, decisions, perf rules | Authoritative |
| `RELEASE_PLAN.md` | Version-by-version plan (1.9→2.6), work orders, retention systems, QA process | **The plan of record** (agreed 2026-08-22) |
| `cogniq_builders_handbook.md` | Build spec: 12 modifiers + 9 new games | Companion to RELEASE_PLAN — see its §1.6 for the mapping and stale sections |
| `TESTING_CHECKLIST.md` | Device-only tests, per release | **Living doc** — add a section every release |
| `modifier_pool_expansion.md` | Endgame pool additions | Mostly implemented 2026-08-22; file paths stale; its "Deliberately excluded" list still binding |

*Deleted 2026-08-22 (contents salvaged into RELEASE_PLAN.md first): `FEATURE_ROADMAP.md`, `ACCESSIBILITY_RECOMMENDATIONS.md`, `GAME_SUGGESTIONS_WITH_DESIGN.md`, `SOCIAL_COMMUNITY_FEATURES.md`, `ONBOARDING_STRATEGY.md`. Long gone: `DIFFICULTY_SCALING_ANALYSIS.md`, `COMPREHENSIVE_APP_ANALYSIS.md`.*
