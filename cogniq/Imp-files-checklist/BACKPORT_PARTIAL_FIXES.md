# CogniQ — Fix Status and Backport Register

**Put this file in `cogniq/Imp-files-checklist/` next to `backport.md`.**

**Audience:** an AI coding agent working on CogniQ, or a developer picking this up cold.
Read this before touching any modifier or level-generation code.

---

## 0. Why this file exists

`backport.md` in this folder is the entry point for the original six-change backport (labelled **A–F**). That backport was applied to version 1.8 and pushed to GitHub.

**This file records what actually landed.** Four of the six changes are only partly applied. On top of that, a full audit of the codebase found further problems in the same areas — some of them the *reason* the original changes were written in the first place.

Everything here is grouped into **8 groups**, listed in §3.

### The single most important rule

Whatever ends up in 1.8 gets copied into **seven more bundles**. A half-finished fix here becomes a half-finished fix in eight places, and by then it is eight times harder to find.

**Close all 8 groups in 1.8 before branching 1.9.**

### How this file works with the others in this folder

**This file does not replace `backport.md`. Read both.**

| File | What it is | When to open it |
|---|---|---|
| `backport.md` | **The entry point.** The procedure and the progress checkboxes for changes A–F | First. It tells you *how* to propagate and tracks *which bundles are done* |
| **this file** | **The current truth.** What actually landed in the code, plus everything the audit found since | Second. It tells you *what still needs doing* |
| `CHALLENGE_MODE_MODIFIERS_AND_DESC.md` | The code for changes A, B, C | When working on start levels, `_isModActive`, or description copy |
| `COGNIQ_FIXES_DAILY_TRAIL_GRIDPATH.md` | The code for changes D and E, plus the daily-persistence non-bug | When working on the trail toast or Grid Path |
| `3_GAME_FIXES_FOR_1.8.3.md` | The code for change F | When verifying Colour Link and Chimp |
| `verify_cogniq_fixes.sh` | **v2 — checks changes A–F *and* all 8 groups in this file.** 13 sections, ends with `N of 8 groups clear` | Before you start, and after every change |
| `VERIFY_SCRIPT.md` | What that script does, what it proves, and what it does **not** prove | Once, before trusting a green run |
| `Monthly_Version_Issue_checklist.md` | The monthly release routine and the three rot risks (targetSdk, toolchain drift, dependency rot) | Every month, at release time |

**Precedence when two files disagree:**

- **`backport.md` wins on procedure** — branching, ordering, which bundles are in scope.
- **This file wins on status** — what is applied and what is not. It was written from a direct audit of the 1.8 code at commit `5da298c`; the older docs describe what was *intended*.

### Run the script before you read any further

```bash
./verify_cogniq_fixes.sh <version-root>
```

**Every group in this document is checked by that script.** It searches for the
broken pattern and fails when it finds it, so it doubles as a progress meter.

Against an unfixed 1.8 it reports **23 failures, 0 of 8 groups clear** — that is the
correct starting reading, not a sign something is wrong. Work the groups in the order
in §5 and watch the count rise.

**The script is also the portable form of this document.** Every `file:line` below is
a 1.8 line number and will be wrong in another bundle; every check in the script is a
pattern, so it gives a true answer on any bundle without adjustment. See §7.

Read `VERIFY_SCRIPT.md` once before relying on a green run. The script proves a broken
pattern is **gone**. It does not prove the replacement is **good** — that a start level
is a sensible number, that the new Grid Path waypoint spread feels right, that a
repaired modifier now does something a player would notice, or that the app builds.
Those need `flutter analyze` and real play.

---

## 1. Backport context — what you are propagating into

### The ladder

Per `backport.md`, the scope is the **unshipped ladder of 8 bundles, version codes 61–68**:

`1.8.2(61)` · `(62)` · `(63)` · `(64)` · `(65)` · `2.3.1(66)` · `2.4(67)` · `2.5(68)`

The five originals (codes 50–54) are **out of scope** — superseded by the drip-feed rebuilds above, kept as history, never uploaded again.

The version audited for this document is `1.8.2+61` — the first rung. Everything below describes that codebase.

- Repo: `github.com/mayank0201/flutter-projects`, branch `v5_Puzzle`, path `cogniq/`
- Commit audited: `5da298c` ("1.8 version added")
- `flutter analyze`: **0 errors**, 63 warnings, 245 infos
- No secrets tracked anywhere in the tree or history

### Release cadence

**One version per month**, rebuilt each month on the pinned toolchain. Do not pre-build the ladder — a toolchain change would invalidate the lot. See `Monthly_Version_Issue_checklist.md`.

### The original six changes, and where they stand

| | Change | Source doc | Marker comment | Status in 1.8 |
|---|---|---|---|---|
| **A** | Per-game modifier start levels | `CHALLENGE_MODE…md` §A | `mod-start-map` | **Partial** — map + accessor landed; `modifierCountFor` and `kMinimalPool` are **absent from the code entirely** |
| **B** | `_isModActive` in every screen | `CHALLENGE_MODE…md` §B | `mod-active-helper`, `mod-getters` | **Partial** — helper in all 26 screens but Word Hive uses a wrong id; 18 getters created and never called |
| **C** | Description copy | `CHALLENGE_MODE…md` §C | `mod-desc-copy` | **Complete** — 19 sites, `_modifierBannerText` present in 19 files |
| **D** | Trail unlock toast | `COGNIQ_FIXES…md` §2 | `trail-toast` | **Partial** — star path correct, clear-count path fragile |
| **E** | Grid Path floor + `waypointSparsity` | `COGNIQ_FIXES…md` §3 | `gridpath-floor` | **Partial** — the level-30+ base ramp fixed; the pre-30 branches and the `waypointSparsity` no-op are **still present** |
| **F** | Colour Link curve + Chimp cliff | `3_GAME_FIXES_FOR_1.8.3.md` | *(none)* | **Complete** — verified in the code, but has **no marker comment**, so the verify script cannot see it |

> **Note on E.** `COGNIQ_FIXES_DAILY_TRAIL_GRIDPATH.md` §3 already contains a `waypointSparsity` no-op table. An independent audit of the 1.8 code found that no-op still live. Whoever applied E fixed the base ramp and did not apply the sparsity half. Do not assume a documented fix is an applied fix — check the code.

> **Note on F.** Because F left no marker, `verify_cogniq_fixes.sh` will pass a version where F was never applied. When you propagate, verify F by reading the Colour Link `>= 30` block directly: it must have exactly two branches (`< 45` and `else`), not the old four.

### The marker system

Each applied fix leaves `// COGNIQ-FIX:<name>`. Current counts in 1.8:

| Marker | Count |
|---|---|
| `mod-active-helper` | 20 |
| `mod-desc-copy` | 19 |
| `mod-getters` | 17 |
| `trail-toast` | 2 |
| `gridpath-floor` | 1 |
| `mod-start-map` | 1 |

A line ending `// not-a-modifier-gate` means *"this `>= 30` is difficulty maths, not a modifier gate."* Respect it — do not remove those comments, do not "fix" the lines they mark.

**When you close a group, add its marker.** The script already knows these names and lists them as `pending` in section 13 until they appear:

| Marker | Group |
|---|---|
| `COGNIQ-FIX:mod-deadeffect` | 2 — modifiers announced but doing nothing |
| `COGNIQ-FIX:mod-unreachable` | 3 — modifiers that can never be selected |
| `COGNIQ-FIX:mod-inverted` | 4 — modifiers that do the opposite of their description |
| `COGNIQ-FIX:curve-regression` | 5 — difficulty running backwards |
| `COGNIQ-FIX:curve-plateau` | 6 — frozen boards |
| `COGNIQ-FIX:mod-start-early` | 7 — lowered start levels + unwrapped `>= 30` blocks |

Group 1 reuses the six original markers — do not invent new ones for it. Group 8 needs no marker; the script detects it directly.

Adding a marker is **not** what makes a group pass. The script's group checks look at the code itself, so a marker on an unfixed file changes nothing. The marker is for the next seven bundles and for the next person grepping.

### How to propagate

Per `backport.md`: one branch per version, oldest first. For each of the 8 bundles:

1. `diff -q` the file against the fixed 1.8 copy. **Identical → copy the fixed file wholesale.** This is provably safe and covers most files.
2. Only genuinely-different files need thought.
3. Run `verify_cogniq_fixes.sh` against the version root.
4. Read the Colour Link block by hand (change F has no marker).
5. `flutter analyze` — must stay at **0 errors**.

The per-game start-level map is designed to be **byte-identical in all eight versions**. It has 44 keys against a 24-game roster; the extras are aliases and games that do not exist yet. An entry for a game that is not in the roster is inert and costs nothing. **Never trim the map to "only what this version uses"** — that reintroduces per-version drift, which is the entire problem this design exists to avoid.

---

## 2. Read this before changing any start level

Two traps that are not obvious from the map.

### Trap 1 — four games ignore the map

In four games the call to `RotationEngine.getActiveModifiers` sits **inside a hardcoded `level >= 30` block**. Lowering the map value changes nothing, because the code that selects modifiers never runs:

| Game | Blocking line |
|---|---|
| Grid Path | `grid_path_screen.dart:415` — `if (!_isDailyMode && levelIndex >= 30)` |
| Mine Finder | `mine_finder_screen.dart:365-366` — `bool isHighLevel = … >= 30; if (isHighLevel)` |
| Star Battle | `star_battle_screen.dart:1219` — `else if (!_playDailyMode && _levelIndex >= 30)` |
| Color Flood | `color_flood_screen.dart:211` — `if (!_playDailyMode && _currentLevel >= 30)` |

**Pattern Lock is the correct model** (`pattern_lock_screen.dart:252`):

```dart
} else if (!_playDailyMode && _currentLevel >= RotationEngine.modifierStartLevel('patternlock')) {
```

It reads the map. Make the other four do the same. The remaining 19 games are already fine — their `_modsOn` getter calls `RotationEngine.hasModifiers(gameId, level)`, which reads the map.

**Grid Path has a second layer:** `waypointSparsity`'s *effect* (`grid_path_screen.dart:466-470`) is also inside that `>= 30` block. Unwrapping the selection alone leaves that one modifier dead below 30.

### Trap 2 — the small-board guard is not connected

`RotationEngine.getActiveModifiers` takes a `smallGrid` parameter (`rotation_engine.dart:145`). **Nothing in the function body reads it.** The only mention is a comment at `:182-187` describing what it used to do. All 17 call sites pass it for nothing.

Harmless today, because modifiers do not start until boards are already large. **It stops being harmless the moment start levels drop** — modifiers begin landing on small boards with no guard. Connect it, or choose numbers that keep every game's board large enough at its start level.

`minActive` (`:143`) is inert for the same class of reason: its only consumer at `:189` is unreachable after the clamp at `:188`.

**Good news:** the tier maths cannot strand a modifier. `singlesSpan = max(p, 10) >= p`, so every pool entry gets a solo appearance on levels `start … start + p - 1`. Verified empirically for `zip` and `killersudoku`. The only unreachable pool in the app is Circuit Guide's, and that comes from the screen, not the engine.

---

## 3. The 8 groups

| # | Group | Player impact | Size |
|---|---|---|---|
| 1 | Backport fixes that stopped short | mixed | 6 items |
| 2 | Modifiers announced but doing nothing | high — breaks trust | 5 items |
| 3 | Modifiers that can never be selected | high — lost content | 7 items |
| 4 | Modifiers that do the opposite of what they say | medium | 1 item |
| 5 | Difficulty running backwards | high — quit trigger | 2 items |
| 6 | Frozen boards / plateaus | high — early churn | 8 items |
| 7 | Earlier modifier start (design decision) | high — fixes group 6 cheaply | 24 numbers + 4 unwraps |
| 8 | Engine and housekeeping dead code | none today | 5 items |

---

### Group 1 — Backport fixes that stopped short

Suggested marker: reuse the existing markers; do not invent new ones for these.

**1.1 — `trail-toast`, clear-count path.** `hint_manager.dart:176`

```dart
if (globalCount == 30 || globalCount == 100 || globalCount == 250) {
```

Exact equality, no "already notified" flag. Miss the moment — app killed between the count being saved and the toast rendering — and it never fires again. **The trail itself is safe**: `TrailCatalog.isEarnedByClears` (`trail_catalog.dart:234`) is `clears >= required`. The player keeps the reward and is never told.

The star path (`daily_challenge_manager.dart:1405` → `trail_catalog.dart:302`) does it correctly: threshold check plus a `trail_unlocked_toast_<styleId>` flag. **Copy that pattern.** Best fix is to move the clear-count trails into `TrailCatalog` so there is one mechanism, not two.

**1.2 — `mod-active-helper`, Word Hive wrong id.** `word_hive_screen.dart:484` asks for `'wordhive'`, which is **not a key in the map**, so it falls through to `?? 15` (`rotation_engine.dart:97`). But `:597` and `:832` both pass `'spellingbee'` → **12**.

Levels 12, 13, 14 are half-modified: the engine fills `_activeModifiers`, the banner at `:589-592` announces the modifier, the direct reads at `:806` and `:842` fire — and every gameplay getter at `:490-493` returns false.

**Fix: line 484, `'wordhive'` → `'spellingbee'`.** Do **not** add a `'wordhive'` key instead — that hides the inconsistency behind a fourth alias pair.

**1.3 — three more id mismatches that work by luck.**

| Game | in `modifierStartLevel` | in `getActiveModifiers` | both resolve to |
|---|---|---|---|
| Mine Finder | `'minesweeper'` | `'mines'` | 30 |
| Odd Color Out | `'oddcolor'` | `'oddcolorout'` | 20 |
| Spectrum | `'hue'` | `'spectrum'` | 15 |

Not bugs today. Traps — retune one value, forget its twin, recreate 1.2. Settle on the `game_info.dart` id for each and use it in both places. Keep the alias keys in the map as a safety net.

Note for Spectrum: the gameId also seeds the modifier shuffle order (`rotation_engine.dart:160-161`), so the two ids are not interchangeable even when the numbers agree.

**1.4 — `mod-getters`, 18 unused.** The fix created getters like `bool get _isZoomActive => _isModActive('zoom');` but many call sites still read `_activeModifiers.contains('zoom')` directly. `flutter analyze` flags 18 as `unused_element`.

Not wrong today (the engine returns an empty set below the start level, so the short check happens to agree) — **except in Word Hive, where the ids disagree.** That is exactly where "right by accident" stops being right.

Replace each direct `contains('x')` with the matching getter, or `_isModActive('x')` if no getter exists. **Leave direct `_activeModifiers` reads alone where the code iterates the whole set** — e.g. building the banner with `.map(_getModifierDescription)`. That is legitimate.

Verify: `flutter analyze 2>&1 | grep unused_element` — the `_is<Something>Active` entries should be gone.

**1.5 — `gridpath-floor` applied to one branch of four.** See group 6.1 — the full arithmetic is there.

**1.6 — change A's `modifierCountFor` and `kMinimalPool` are absent.** `backport.md` lists both as part of change A. Neither string appears anywhere in `lib/`. Either they were dropped deliberately or the change was applied incompletely. **Read `CHALLENGE_MODE_MODIFIERS_AND_DESC.md` §A and decide before propagating** — if they are needed, they are needed in all eight bundles.

---

### Group 2 — Modifiers announced but doing nothing

Suggested marker: `// COGNIQ-FIX:mod-deadeffect`

The game shows a banner, the board does not change. Worse than a missing feature: a player told the board will change looks for the change, does not find it, and concludes the game is fake. They stop trusting banners, then miss the real ones.

**2.1 — Pearl Loop `zoom`.** `masyu_screen.dart:79` declares `_isZoomActive`. Nothing consumes it. No `InteractiveViewer`, no `TransformationController` anywhere in the file. The description at `:100` still tells the player "Grid is magnified with pan-and-scan navigation" via the banner at `:1134`. **Implement it or remove `'zoom'` from the pool at `:174` and `:275`.**

**2.2 — Pattern Lock `boardTransform`.** `:278-280` computes `_transformType`. Every consumer (`:471`, `:710`, `:870`) gates on `_isEndgame || _playDailyMode`, and `_isEndgame` is `_isModActive('timer')` — **`timer` is not in Pattern Lock's pool** (`:257`). So in free play the transform is computed and never applied; `:471` falls through to the untransformed pattern and the banner at `:870` never renders.

**2.3 — Word Hive `minimal`.** The description at `:571` promises "Target word count is hidden". Both hiding sites (`:1299`, `:1316`) test `_playDailyMode && _dailyModifierType == 'minimal'`, but pool selection only happens when `_modsOn` is true, which requires `!_playDailyMode` (`:597`). **In free play the count still shows.** Only the hint wording at `:806-810` changes.

Related dead branch: `_hasWhisperAndTimer` (`:492`) can never be true, because `:842-844` removes `timer` whenever both are drawn — so `:520-522` and `:535-537` are unreachable.

**2.4 — Killer Sudoku `clueThinning`.** `:269-271` sets `numGivens = 0`. Levels 26–29 already reach 0 via `max(0, 2 - ((L-16) ~/ 5))` at `:233`, and levels 30–49 hardcode 0 at `:237`. **No-op across levels 26–49** — simulated to actually fire as a no-op at L30, 35, 40, 41, 42, 43.

Copy bug in the same modifier: the description at `:222` says "Fewer cage sums are provided upfront", but the code changes `numGivens`, which controls pre-filled **cell digits** (`:322-324`), not cage sums. `wildcard` is the modifier that masks sums.

**2.5 — Grid Path `waypointSparsity`.** The one you noticed. Full arithmetic:

```
456:    int minWaypoints = gridSize + 2;
463:      final int band = levelIndex >= 75 ? 2 : (levelIndex >= 50 ? 1 : 0);
464:      waypointCount = minWaypoints + band + (levelIndex % 2);
466:      if (activeMods.contains('waypointSparsity')) {
469:        waypointCount = (waypointCount - 2).clamp(minWaypoints, waypointCount);
470:      }
```

| levels | grid | minWaypoints | base | after −2 and clamp | net |
|---|---|---|---|---|---|
| **30–49, even** | 6 | 8 | 8 + 0 + 0 = **8** | `6.clamp(8, 8)` = **8** | **0 — NO-OP** |
| 30–49, odd | 6 | 8 | 9 | `7.clamp(8, 9)` = 8 | −1 |
| 50–74, even | 7 | 9 | 10 | `8.clamp(9, 10)` = 9 | −1 |
| 50–74, odd | 7 | 9 | 11 | `9.clamp(9, 11)` = 9 | −2 |
| 75+ | 8/9 | 10/11 | 13 | 11 | −2 |

Simulating the engine's shuffle for `zip` gives the order `[ratchet, timer, waypointSparsity, minimal, retro, nonRectShape]`, so `waypointSparsity` is index 2 and its **solo** levels are `30 + 2 = 32` and `30 + 2 + 6 = 38`. **Both even. The player's first and second encounter with this modifier change nothing at all** while the banner announces it. Over levels 30–120 it is a no-op on 2 of 36 appearances — but those 2 are the ones that form the first impression.

The comment at `:461-462` says the base values were raised so they "actually survive the floor below". That fix worked for the base ramp and was never re-checked against the subtraction stacked on top of it.

**Fix:** either lower the clamp floor for the sparse case (`minWaypoints - 1`), or make `band` parity-independent so `base` is never exactly `minWaypoints`. **Also move this block out of the `>= 30` wrapper** — see §2 Trap 1 — or it stays dead below 30 after group 7.

---

### Group 3 — Modifiers that can never be selected

Suggested marker: `// COGNIQ-FIX:mod-unreachable`

**3.1 — Circuit Guide, four modifiers. Highest value-per-line in this document.**

```
260:      _activeModifiers.clear();
...
281:      if (_isEndgame) {          // _isEndgame reads the set cleared at :260
307:        ... getActiveModifiers(pool: kCircuitGuideEndgamePool) ...
```

`_isEndgame` is `_isModActive('timer')` (`:102-107`, `:111`), which reads `_activeModifiers` — emptied one moment earlier. In free play `_forcedModifier` is null and `_playDailyMode` is false, so **`_isEndgame` is always false at `:281`**. The branch never runs, and the only call to the endgame pool lives inside it. Free play always falls to the `else` at `:357` and uses `kCircuitGuidePresentationPool` (`:424-434`).

**Dead: `tortuosity` (consumer `:626`), `junctionDensity` (`:633`), `decoyWires` (`:739`), `scrambleDepth` (`:763`, `:808`).** All four are implemented and working — they just cannot be chosen. Circuit Guide rotates 4 modifiers instead of 8, so it goes repetitive twice as fast as designed.

The same bug also disables the endgame board ramp at `:280-303` (grid up to 8, 6 targets).

Second effect: in a Daily whose type is `timer`, `_isEndgame` **is** true, so the unguarded `:307` overwrites the daily's chosen modifier with a random endgame combo while the banner (`:242-253`) still shows the original text.

**Fix:** move the pool selection above `_activeModifiers.clear()`, or compute endgame status from the level rather than from the set being populated.

**3.2 — Practice sandbox, three modifiers.** `practice_screen.dart:51` declares `fog`, `time_limit`, `no_hints`. `_isModActive` is defined at `:43` and never called. `_activeModifiers` is used once, at `:102`, as `Text(_activeModifiers.toString())`. Route `/practice` is wired in `main.dart:250`.

Dev sandbox, so no player impact — but it is reachable. Decide: finish it, or unwire the route.

---

### Group 4 — Modifiers that do the opposite of what they say

Suggested marker: `// COGNIQ-FIX:mod-inverted`

**4.1 — Killer Sudoku `cageSize`.** `:266-268` sets `maxCageSize = _gridSize == 9 ? 5 : 4`. The description at `:219` says "Cages are larger and combine more cells."

- Levels 16–29 already have `maxCageSize = 4` → **no-op**
- Levels 30–49 already have **5** → the modifier **shrinks cages to 4**, making the level *easier*

Simulated: no-op at L23 and L29, inverted at L35–39. A modifier meant to punish the player rewards them.

---

### Group 5 — Difficulty running backwards

Suggested marker: `// COGNIQ-FIX:curve-regression`

A player grinds to level 30 expecting the game to get serious, and it goes soft. That is the moment they conclude there is nothing left and stop playing.

**5.1 — Pattern Lock, level 30. The worst single moment in the app.**

At level 29: `targetLength = 3 + (29 ~/ 2) = 17` (`:272`).
At level 30: `targetLength = (5 + (_currentLevel % 3)).clamp(5, 8)` (`:277`) = **5**.

A 17-dot pattern drops to 5 — easier than level 10. Then it **cycles 5, 6, 7, 5, 6, 7…** forever. Levels 30–79 draw from exactly **three** board specifications, each repeating about 17 times, with zero escalation. `_gridN` is hardcoded 7 across that whole range (`:83`). The `.clamp(5, 8)` upper bound is unreachable — `5 + (L % 3)` maxes at 7. From level 80 the grid *shrinks*, alternating 6 and 7.

Modifiers are on throughout (start level 30), which is the only thing carrying it.

**5.2 — Sudoku 9×9, level 30.** `sudoku_screen.dart:529`:

```dart
targetFilled = max(17, 25 - ((index - 45) ~/ 3));
```

For levels 30–44 the dividend is **negative**, and Dart's `~/` truncates toward zero. At level 30: `(30 - 45) ~/ 3 = -5`, so `targetFilled = max(17, 25 + 5) = 30`.

The player had 25 clues at level 29 and gets **30 clues** at level 30 — more help, easier puzzle. It does not recover to 25 until level 43.

Same line at the other end: from level 69 the raw value is 17 and falling, and the `max(17, …)` floor pins it there forever, making the `index >= 90 → 17` branch at `:527` redundant.

---

### Group 6 — Frozen boards and plateaus

Suggested marker: `// COGNIQ-FIX:curve-plateau`

Boards stop growing for long runs. The layout reshuffles each level, but size and piece counts freeze, so it reads as "same level again". **The early ones hurt most** — they land before modifiers start, during the window where a new player decides whether to keep the app.

**Worst uncovered stretches** (no modifiers active during them):

| Game | Levels | Length | Frozen |
|---|---|---|---|
| Star Battle | 15–29 | **15** | 7×7 board |
| Sand Sort | 0–11 | **12** | 3 colours, 5 tubes |
| Zen Slide | 0–10 | **11** | 5×5, 2 stones |
| Star Battle | 5–14 | 10 | 6×6 |
| Color Flood | 10–19, 20–29 | 10 each | 7×7 then 8×8 |
| Grid Path | 5–14 | 10 | 4×4, 6 waypoints |
| Light Beam | 0–8 | 9 | 5×5, 2 mirrors |

**6.1 — Grid Path, the reference case, three unfixed branches.** `grid_path_screen.dart:471-479`:

```dart
} else if (levelIndex < 5) {
  waypointCount = 2 + (levelIndex ~/ 2);
} else if (levelIndex < 15) {
  waypointCount = 3 + ((levelIndex - 5) ~/ 3);
} else if (levelIndex < 30) {
  waypointCount = 5 + ((levelIndex - 15) ~/ 4);
} else {
  waypointCount = 6 + ((levelIndex - 30) ~/ 5);
}
```

then the floor at `:481-486` (`minWaypoints = gridSize + 2`).

- **Levels 5–14, 4×4, floor 6.** Formula yields `3,3,3,4,4,4,5,5,5,6` — all raised to 6. **Ten identical levels.**
- **Levels 15–26, 5×5, floor 7.** Formula yields `5,5,5,5,6,6,6,6,7,7,7,7` — all raised to 7. **Twelve identical levels.**
- Levels 27–29 reach 8 naturally and are fine.

**22 of the first 30 levels are two configurations.**

The trailing `else` is **not dead code** — it is the daily-challenge path for level ≥ 30 (the chain opens with `!_isDailyMode && levelIndex >= 30`). There `gridSize` is 6, floor is 8, and the formula returns 6 until level 40. **Daily levels 30–39 are flattened too.** Same bug, third location.

Fix the same way `:463-464` was fixed: express each count **relative to `minWaypoints`** so it starts above the floor and climbs. Do not remove the floor — it exists so small grids are not trivial. Target: 5–14 → 6→9, 15–29 → 7→11, daily 30+ → 8 upward. Ceiling is `.clamp(2, gridSize² - 2)` = 14 on a 4×4, so there is headroom.

Also in that function: at level 75+, `gridSize = 8 + ((levelIndex - 75) % 2)` makes the board alternate 8×8, 9×9, 8×8, 9×9 every level while waypoints stay 13 for both. Confirm intent.

**6.2 — Slitherlink and Kakuro stop progressing at level 12.**

Slitherlink's `targetRegionFor(int size, int level, Random rng)` (`slitherlink_logic.dart:58-66`) **never reads `level`.** It switches on `size` alone. Its doc comment at `:56-57` claims "Rises with level so later boards have longer, more interesting loops" — it does not. `hideCount` (`slitherlink_screen.dart:252`) is a function of size only. `sizeFor` caps at 5 from level 12. **So level 12 onward is one board forever.**

Kakuro is the same shape: `sizeFor` and `layoutsFor` (`kakuro_logic.dart:83-89`) are the only level-driven inputs and both terminate at level 12.

**6.3 — Odd Color Out, 55 identical levels then a backwards loop.** `odd_color_out_screen.dart:240`:

```dart
delta = 0.04 * (30.0 / (30.0 + (_levelIndex - 30)));   // = 1.2 / level
if (delta < 0.035) delta = 0.035;                       // :241
```

Level 34 → 0.035294, survives. Level 35 → 0.034286, raised back to 0.035. **Every level from 35 onward ships the identical colour delta**, and `_gridSide` returns a hardcoded 9 for all of 30–89 (`:158`). Level 90+ is worse: `5 + ((_levelIndex - 90) % 5)` (`:150`) **drops the board back to 5×5** and cycles 5→9 forever with delta still pinned — a period-5 loop with zero net progression.

**6.4 — Color Flood, duplicate branch and a dead feature.** `color_flood_screen.dart:220-226`: the `>= 60 && < 75` branch and the `>= 75 && < 90` branch are **character-for-character identical** (`_gridSize = 9; _numColors = 7;`). 30 flat levels. `_gridSize` is 9 in every branch of the `>= 30` chain, so the board never grows after level 30.

`hasObstacles` is set `false` at `:210` and again at `:246` and assigned nowhere else, so the obstacle generator at `:293-306` — including the level-75 obstacle-density ramp at `:301-303` — **can never run.** Whatever the 75 band was meant to add is dead. Finish the feature or delete it.

**6.5 — Spectrum, 30 flat levels and a shrink.** `spectrum_screen.dart:222-229`: the `>= 45 && < 60` branch and the trailing `else` both hardcode 8×8. Levels 30–59 are one board — and it is a **shrink** from the 9×7 at levels 25–29. Also dead: the `default:` arm of the tier switch (`:270-274`, the 15×8/16×8 boards) is unreachable in non-daily play.

**6.6 — Killer Sudoku level 50 is a partial regression.** `maxCageSize` drops 5→4 and `numGivens` rises 0→3; only the 6→9 grid jump makes it a net increase.

**6.7 — Long modifier-covered plateaus.** Lower priority (modifiers carry them) but the board itself stops moving: Sum Strike 200–499 (**300** levels, grid 7 / maxNum 18, both clamped); Colour Link 44+ (**57+**, deliberate — see change F); Word Hive 35–90 (**56**, `maxCap = 12` eats the climb); Killer Sudoku 50+ (**51+**); Sand Sort 54+ and Mine Finder 54+ (**47+** each); Hitori 60+ (**41+**); Light Beam 66+ and Zen Slide 66+ (**35+** each, Zen Slide documented as intentional via `hardestFairLevel = 66`); Sudoku 69+ (**33+**); Circuit Guide 70+ (**32+**); Star Battle 30–59 and 60–89, Color Flood 60–89, Spectrum 30–59 (**30** each); Untangle 75+ (**27+**).

**6.8 — The clamp-eats-formula family.** Same class as Grid Path, all confirmed: Light Beam `min()` against `gridSizeFor - 1` (`lightbeam_logic.dart:243-244`, flattens 30–43 and 45–59); Sudoku `max(17, …)`; Odd Color Out `if (delta < 0.035)`; Word Hive `maxCap = 12`; Sand Sort `(c * 2.7).round()` cap. **When fixing any curve, check what clamp sits below it.**

---

### Group 7 — Earlier modifier start

**Decision made by the app owner: modifiers start much earlier in normal (non-Zen) mode, and the proposed table below is APPROVED. Implement these numbers as written.**

Rationale: group 6 shows the worst dead stretches are all in the first 15 levels, before modifiers begin. Starting them earlier covers almost all of them without touching a single level generator.

**Read §2 first.** Four games ignore the map, and the small-board guard is not connected.

**Do groups 2, 3 and 4 before this.** Lowering the start level while modifiers are dead or inverted just makes the broken ones arrive sooner.

#### Proposed numbers — map change only, works immediately

| Game | id | Now | Proposed |
|---|---|---|---|
| Zen Slide | `zenslide` | 15 | **5** |
| Bridges | `bridges` | 10 | **6** |
| Pearl Loop | `masyu` | 10 | **6** |
| Killer Sudoku | `killersudoku` | 12 | **6** |
| Kakuro | `kakuro` | 12 | **6** |
| Hitori | `hitori` | 12 | **6** |
| Slitherlink | `slitherlink` | 12 | **6** |
| Sand Sort | `sandsort` | 15 | **6** |
| Light Beam | `lightbeam` | 15 | **6** |
| Spectrum | `hue` + `spectrum` | 15 | **6** |
| Colour Link | `colourlink` + `colour_link` | 15 | **6** |
| Sum Strike | `sumstrike` | 12 | **8** |
| Word Hive | `spellingbee` | 12 | **8** |
| Untangle | `untangle` | 15 | **8** |
| Odd Color Out | `oddcolor` + `oddcolorout` | 20 | **8** |
| Cipher Decoder | `cipherdecoder` | 20 | **8** |
| Circuit Guide | `circuitguide` + `circuit_guide` | 14 | **8** |
| Sudoku | `sudoku` | 20 | **10** |
| Pattern Lock | `patternlock` + `pattern_lock` | 30 | **10** |

#### Needs the `>= 30` wrapper unwrapped first

| Game | id | Now | Proposed |
|---|---|---|---|
| Star Battle | `queens` | 30 | **5** |
| Grid Path | `zip` | 30 | **8** |
| Mine Finder | `mines` + `minesweeper` | 30 | **8** |
| Color Flood | `colorflood` + `color_flood` | 30 | **8** |

Star Battle gets the most aggressive drop because it has the worst uncovered stretch in the app.

#### Leave alone

**Chimp Test at 24.** It is the only game where the number was chosen correctly: its level table maxes out at index 24 and holds flat through 29, so modifiers begin exactly where the board stops getting harder, and there is a comment in the map explaining it. **This is the model for how to choose a start level.** Lowering it would break the one curve that works.

Update **every alias key** for a game, not just one. That is what makes the mismatches in group 1.3 dangerous.

Board size at each proposed start level was checked — nothing lands on a 3×3. That check is currently arithmetic in this document, not a guard in the code. Connecting `smallGrid` (group 8.1) is what makes it safe to retune later.

---

### Group 8 — Engine and housekeeping dead code

No player impact today. It matters because this code is about to be copied into seven more bundles.

**8.1 — `smallGrid` is never read.** `rotation_engine.dart:145`, comment at `:182-187`. 17 call sites pass it for nothing. Implement or delete — but see §2 Trap 2 before deleting, since group 7 is exactly when it becomes load-bearing.

**8.2 — `minActive` is inert.** `rotation_engine.dart:143`. Its only consumer at `:189` is unreachable: after `:188` clamps `k`, `k < minActive` is never true for any call site in the catalogue. Lines 189–191 are dead.

**8.3 — 18 unused getters.** See group 1.4.

**8.4 — Slitherlink tells the player nothing.** Four working modifiers (`timer`, `fog`, `zoom`, `decay`) with no `_getModifierDescription`, no chips, no banner. The board fogs, zooms, decays and times out with no explanation. Light Beam, Sand Sort, Untangle and Zen Slide also lack `_getModifierDescription` but each announces via icon chips — acceptable.

**8.5 — Descriptions for modifiers that are not in that game's pool.** Implemented and explained, never selectable in free play: Color Flood `fog` (`:83`, `:97`, `:935`); Mine Finder `blind` (description only, no implementation); Odd Color Out `retro` (`:1000`); Pattern Lock `mirror` (`:283`) and `timer` (`:193`, `:412`). Either add them to the pool or drop the copy.

---

## 4. Confirmed healthy — do not "fix" these

- **No surviving `>= 30` modifier gates.** Every remaining one is difficulty maths, correctly tagged `// not-a-modifier-gate`.
- **The start-level map covers the full roster.** All 24 ids in `game_info.dart` have an entry. The 20 extra keys are aliases plus future games — inert and intentional.
- **Daily challenge persistence.** The `daily_backup_*` keys (9 references in `daily_screen.dart`) are how the daily swaps a game's level and restores it. **Intended behaviour, not a leak.** `COGNIQ_FIXES_DAILY_TRAIL_GRIDPATH.md` §1 says the same — it is documented there so nobody re-investigates it.
- **No crash risk anywhere.** Every hand-authored table is `%`-wrapped or length-checked: Bridges 150, Pearl Loop 205, Sudoku 19/21/16, Word Hive 64, Cipher Decoder 10, Sum Strike 200 (guarded), Chimp 30 (guarded), all 7 beta screens.
- **The modifier rotation is sound.** Every pool entry gets a solo appearance. No modifier is stranded by the tier maths.
- **Cipher Decoder has the cleanest curve in the codebase** — bands explicitly measured and tuned, then a 10-entry `%`-wrapped rotation from level 20.
- **Change F landed** (Colour Link two-branch curve, Chimp cliff).
- **No secrets tracked.**

---

## 5. Suggested order of work

1. **Group 1.2** — Word Hive one word. Live bug, smallest possible fix.
2. **Group 3.1** — Circuit Guide. Recovers 4 finished modifiers for a few lines.
3. **Group 5** — the two backwards curves. Worst player-facing moments.
4. **Groups 2 and 4** — make every announced modifier real.
5. **Group 6.1** — Grid Path branches, all three.
6. **Group 8.1** — connect `smallGrid`.
7. **Group 7** — the start levels, plus the four unwraps.
8. **Group 6.2–6.8** — the remaining curves.
9. **Groups 1.1, 1.4, 8.2–8.5** — housekeeping, one pass each so the diff stays reviewable.
10. Re-run `flutter analyze` — must be **0 errors**.
11. Re-run `verify_cogniq_fixes.sh` — must read **8 of 8 groups clear**.
12. Add the group markers, record the final numbers and code shapes you actually shipped, **then** branch 1.9.

Run the script after **every** step, not just at the end. It takes seconds, and it is the only thing in this process that can tell you a fix did not take.

Step 12 matters more than it looks. The numbers you settle on — the start levels, the new Grid Path waypoint counts — become the specification for the other seven bundles. If they only exist in the 1.8 source and not in writing, the next bundle's agent will re-derive them and you will end up with eight slightly different curves.

---

## 6. Ground rules

- Work only inside `cogniq`. Do not touch `cinetracker`, `flow_grid`, `pulse`, `weather`.
- Never commit `android/app/upload-keystore.jks` or `android/key.properties`. If either lands in a commit, the history must be **rewritten** — deleting them in a later commit is not enough.
- Do not upgrade Flutter, Gradle, AGP or the JDK. `build.gradle.kts` reads `flutter.targetSdkVersion`, so the Play Store compliance level is decided by the pinned Flutter version at build time.
- Preserve every `// COGNIQ-FIX:` and `// not-a-modifier-gate` comment. They are how the next seven bundles get verified.
- A documented fix is not an applied fix. Change E proves it. **Check the code.**

---

## 7. Appendix — re-checking these findings in bundles 62–68

**Every `file:line` in this document is a version-1.8 line number** (commit `5da298c`). Line numbers drift between bundles. **Do not navigate by line number in any other version** — use the patterns below, which are position-independent.

Two things also change across the ladder:

- **The roster grows.** 1.8 has 24 games; 2.5 has 33. The extra games were **never audited**. They may carry their own dead modifiers and plateaus, and they need the same checks run against them.
- **A finding may already be fixed, or may never have existed,** in a later bundle. Check before changing. A "fix" applied to code that was already correct is a regression.

### Detection commands

**First, just run the script** — `verify_cogniq_fixes.sh` performs every check below
automatically, on any bundle, and prints which of the 8 groups are still open. The
table here is for when you want to check one thing by hand, or to understand what the
script is actually looking at.

Run from the version's `cogniq/` directory. Each returns output **only when the bug is present**, unless noted.

| # | Finding | Command | Bug present when |
|---|---|---|---|
| 1.1 | Trail toast fragile | `grep -rn "globalCount == 30" lib/utils/hint_manager.dart` | any output |
| 1.2 | Word Hive wrong id | `grep -rn "modifierStartLevel('wordhive')" lib/` | any output |
| 1.3 | Id mismatches | `grep -rn "modifierStartLevel(" lib/screens` then `grep -rn "gameId: '" lib/screens` | the two ids differ for a game |
| 1.4 | Unused getters | `flutter analyze 2>&1 \| grep unused_element \| grep "_is"` | any output |
| 1.6 | Change A incomplete | `grep -rn "modifierCountFor\|kMinimalPool" lib/` | **no** output |
| 2.1 | Pearl Loop fake zoom | `grep -c "InteractiveViewer\|TransformationController" lib/screens/games/masyu/masyu_screen.dart` | returns `0` while `'zoom'` is in the pool |
| 2.2 | Pattern Lock transform | `grep -n "pool: \[" -A2 lib/screens/games/pattern_lock/pattern_lock_screen.dart` | `boardTransform` present but `timer` absent |
| 2.4 | Killer Sudoku clueThinning | `grep -n "numGivens = 0" lib/screens/games/killer_sudoku/killer_sudoku_screen.dart` | two or more hits (modifier + band both set 0) |
| 2.5 | Grid Path sparsity no-op | `grep -n "clamp(minWaypoints" lib/screens/games/grid_path/grid_path_screen.dart` | any output |
| 3.1 | Circuit Guide unreachable pool | `grep -n "_activeModifiers.clear()\|if (_isEndgame)" lib/screens/games/circuit_guide/circuit_guide_screen.dart` | `clear()` appears **before** `if (_isEndgame)` |
| 3.2 | Practice sandbox wired | `grep -n "practice" lib/main.dart` | route registered while `_isModActive` is uncalled |
| 4.1 | Killer Sudoku cageSize inverted | `grep -n "maxCageSize = _gridSize == 9" lib/screens/games/killer_sudoku/killer_sudoku_screen.dart` | any output |
| 5.1 | Pattern Lock level-30 collapse | `grep -n "5 + (_currentLevel % 3)" lib/screens/games/pattern_lock/pattern_lock_screen.dart` | any output |
| 5.2 | Sudoku negative division | `grep -n "((index - 45) ~/ 3)" lib/screens/games/sudoku/sudoku_screen.dart` | any output |
| 6.1 | Grid Path pre-30 branches | `grep -n "3 + ((levelIndex - 5) ~/ 3)" lib/screens/games/grid_path/grid_path_screen.dart` | any output |
| 6.2 | Slitherlink ignores level | `sed -n '/targetRegionFor/,/^  }/p' lib/screens/games/slitherlink/slitherlink_logic.dart \| grep -c level` | body never uses `level` |
| 6.3 | Odd Color Out delta floor | `grep -n "delta < 0.035" lib/screens/games/odd_color_out/odd_color_out_screen.dart` | any output |
| 6.4 | Color Flood duplicate band | `grep -n "_numColors = 7;" lib/screens/games/color_flood/color_flood_screen.dart` | two hits in adjacent branches |
| 6.4 | Color Flood dead obstacles | `grep -n "hasObstacles" lib/screens/games/color_flood/color_flood_screen.dart` | never assigned `true` |
| 6.5 | Spectrum duplicate band | `grep -n "_rows = 8;" lib/screens/games/spectrum/spectrum_screen.dart` | two hits in adjacent branches |
| 7 | Hardcoded `>= 30` wrappers | `grep -n ">= 30" lib/screens/games/{grid_path,mine_finder,star_battle,color_flood}/*_screen.dart` | a `getActiveModifiers` call sits inside one |
| 8.1 | `smallGrid` unread | `sed -n '/getActiveModifiers/,/^  }/p' lib/utils/rotation_engine.dart \| grep -c smallGrid` | returns `1` (the parameter only, no use in the body) |
| 8.2 | `minActive` inert | `grep -n "k < minActive" lib/utils/rotation_engine.dart` | preceded by a `k.clamp(` that makes it unreachable |

### Checks that must be run per version regardless

```
grep -rc "COGNIQ-FIX" lib/ --include='*.dart'          # marker count, expect 60 in a fixed 1.8
./verify_cogniq_fixes.sh <version-root>                # the six original markers
flutter analyze                                        # must be 0 errors
```

Then by hand, because no marker exists for them:

- **Change F** — Colour Link's `>= 30` block must have exactly two branches (`< 45` and `else`), not four.
- **The roster** — `grep -c "GameInfo(" lib/models/game_info.dart`. Every id it returns must be a key in `_modifierStartLevel`. Later bundles have more games; a missing key silently falls back to 15.

### For the games that only exist in later bundles

The extra games in 1.9 through 2.5 have not been audited. Run the same three questions against each:

1. **Does every modifier in its pool actually do something?** Trace each name from the pool to a line that changes generation, rendering, timing, input or scoring. A name that only appears in the pool and in `_getModifierDescription` is dead.
2. **Does its difficulty ever stop moving?** Compute every level-driven parameter for levels 0–100. Any run of 5+ consecutive levels with all parameters identical is a plateau. Check what clamp or floor sits below the formula — that is what causes most of them.
3. **Does it use one gameId everywhere?** The id in `modifierStartLevel(...)`, in `hasModifiers(...)` and in `getActiveModifiers(gameId: ...)` must be the same string, and must be a key in the map.

Those three questions are the whole audit. Everything in groups 2 through 6 of this document came out of them.
