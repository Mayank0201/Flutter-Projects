# CogniQ 1.8 — what was actually changed

**This is the record of work completed. It is the specification for bundles 62–68.**

Read alongside `backport.md` (procedure), `BACKPORT_PARTIAL_FIXES.md` (the 8 groups),
`RESET_PROGRESS_FIXES.md` (feature removal) and `PATTERN_LOCK_FIXES.md` (P1/P2).
Those describe what *needed* doing. **This file describes what was done, with the
numbers that shipped** — so the other seven bundles get the same values rather than
seven independently re-derived ones.

## State at completion

| Check | Result |
|---|---|
| `flutter test` | **1028 passing, 0 failing** |
| `flutter analyze` | **0 errors** (294 pre-existing info/warning lint, down from 306) |
| `verify_cogniq_fixes.sh` | **8 of 8 groups clear** |

---

## 1. The start-level map — copy these values exactly

`lib/utils/rotation_engine.dart`, `_modifierStartLevel`. **Every alias pair must move together.**

```
zenslide 5 · queens 5
bridges 6 · masyu 6 · killersudoku 6 · kakuro 6 · hitori 6 · slitherlink 6
sandsort 6 · lightbeam 6 · hue 6 · spectrum 6 · colourlink 6 · colour_link 6
sumstrike 8 · spellingbee 8 · untangle 8 · oddcolor 8 · oddcolorout 8
circuitguide 8 · circuit_guide 8 · zip 8 · mines 8 · minesweeper 8
colorflood 8 · color_flood 8
sudoku 10 · patternlock 10 · pattern_lock 10
chimp 24 · cipherdecoder 20
nurikabe 15 · skyscrapers 15 (unchanged, future games)
sequence 3 · numbermemory 3 · memory 5 · orbit 5 · onestroke 5
wordle 8 · weaver 8 · crossclimb 8 · wordbuilder 8 · hangman 8 · flagle 8
```

### Two values that must NOT be lowered

- **`chimp: 24`** — its level table stops getting harder at index 24, so modifiers begin exactly where the board stops climbing.
- **`cipherdecoder: 20`** — tied to `kHardestFairLevelIndex`. **This was originally lowered to 8 by mistake and the test suite caught it.** `test/cipher_decoder_logic_test.dart` asserts the tie and explains why: below that level the structural ladder is still adding unknowns, so modifiers would stack on a curve that is still climbing.

If a future game defines its own "hardest fair level" constant, check whether its start level is tied to it before touching either.

---

## 2. Engine changes

**`smallGrid` now works.** It was a parameter nothing read. It now forces `k = 1` (one modifier at a time) on small boards. This became load-bearing the moment start levels dropped — without it, modifiers land on 3×3 and 4×4 boards with no guard.

**`minActive` now applies.** Its only consumer sat after a clamp that made it permanently false. It now raises `k` from the pairs tier onward. Precedence: `smallGrid` (cap 1) beats `minActive`; `maxActive` and pool size cap everything.

> **This is what exposed most of the follow-on bugs below.** More modifiers active on more levels surfaced latent layout overflows and one crash that had never been reachable before.

---

## 3. Feature removal

`resetAllProgress()`, `_showResetDialog()`, the `_ProfileTile`, its card **and its `_SectionHeader('Data Management')`** are gone, plus the now-orphaned `home_widget` and `zen_mode` imports in `settings_manager.dart`. `prefs_keys` was kept — still used.

**`test/reset_progress_test.dart` was deleted** — it tested the removed method and no longer compiled.

**Still outstanding, do at release:** the privacy policy at
`https://springboot-projects-4m5x.onrender.com/privacy-cogniq.html` still promises
"Reset All Progress" in section 3. Replacement HTML is in `RESET_PROGRESS_FIXES.md` §9.4.

---

## 4. Difficulty curves — the formulas that shipped

**Pattern Lock**, level 30+:
```dart
targetLength = (17 + ((_currentLevel - 30) ~/ 5)).clamp(17, 24);
targetLength = targetLength.clamp(3, n * n);
```
Level 29's pre-30 ramp ends at exactly 17, so there is no drop at the boundary. Climbs to 24 by level 65. Replaces `(5 + (_currentLevel % 3)).clamp(5, 8)`, which collapsed 17→5 and then cycled 5/6/7 for fifty levels.

**Sudoku**, 9×9:
```dart
targetFilled = max(17, 25 - ((index - 30) ~/ 5));
```
Anchored at 30, not 45, so the dividend can never go negative — that was what *added* clues at level 30. Reaches the 17 floor at level 70. The redundant `index >= 90 → 17` branch was deleted.

**Grid Path** — all waypoint counts now computed relative to `minWaypoints` so the floor cannot discard them:
```dart
levelIndex < 15  ->  minWaypoints + ((levelIndex - 5) ~/ 3)
levelIndex < 30  ->  minWaypoints + ((levelIndex - 15) ~/ 3)
daily 30+        ->  minWaypoints + ((levelIndex - 30) ~/ 5)
```
Levels 5–14 now run 6→9, 15–29 run 7→11, daily 30+ starts at 8. `waypointSparsity` moved out of the `>= 30` block and given a floor of `max(4, minWaypoints - 1)`, so it always removes at least one waypoint.

**Odd Color Out**: `delta = 0.040 - (_levelIndex - 30) * 0.00025`, floor **0.018**, reached at level 118 instead of level 35. Board ladder 9×9 → 10×10 → 11×11, replacing the level-90 cycle that dropped back to 5×5. `whisper` changed from `delta = 0.015` to `delta = min(delta, 0.015)` — as a flat assignment it would eventually have made the "faint" modifier *easier* than the level itself.

**Spectrum**: post-30 ladder 10×7 → 11×7 → 12×7 → 12×8 → 13×8 → 14×8 → 15×8 → 16×8. Separately, cases 3 and 4 (levels 15–19 and 20–24) were **both** 8×8 — ten flat levels — and case 5 then shrank to 63 tiles. Now 8×7 (56) → 10×6 (60) → 9×7 (63), handing over to 70 at level 30.

**Slitherlink**: `targetRegionFor` now actually reads `level` (it took the parameter and ignored it, while its doc comment claimed otherwise). Enclosed fraction runs 0.34 → 0.56 by level 60. `sizeFor` ceiling raised to 7 — capped there because an 8×8 edge target is 31px on a 375pt phone.

**Killer Sudoku**: `cageSize` is now `min(cageCap, maxCageSize + 1)` — it was absolute and *shrank* cages on levels 30–49 while claiming to enlarge them. `clueThinning` is now `max(0, numGivens - 1)` against a baseline floored at 1 given; previously the baseline was already 0 across levels 26–49, so it did nothing.

---

## 5. Modifiers that were dead

- **Circuit Guide** — `_activeModifiers.clear()` ran immediately before `if (_isEndgame)`, which reads that set. Always false in free play, so **four modifiers could never be selected**. `_isEndgame` renamed to `_isTimerActive`; a separate `_isEndgameBoard` is derived from the level. Also fixed: a `timer` daily no longer has its chosen modifier overwritten while the banner still names the original.
- **Pearl Loop `zoom`** — announced to the player, no implementation existed. Implemented with `InteractiveViewer` and Draw/Scroll chips, mirroring Star Battle.
- **Pattern Lock `boardTransform`** — computed then never applied, because its consumers gated on `timer`, which is not in Pattern Lock's pool. Now gated on `_transformApplies`.
- **Word Hive `minimal`** — hid the target count in daily mode only; the pool that selects it only runs in free play. Now uses `_isModActive`.
- **Word Hive gameId** — `'wordhive'` was not a map key and fell back to 15 while the engine used `'spellingbee'` (12). Levels 12–14 were half-modified. Now `'spellingbee'` in both.
- **Colour Link `gridSize_pairCount`** — see §6, it was crashing.
- **Mine Finder `timer`** — was selected but never started, because the countdown gate was `isHighLevel && ...` rather than `_modsOn && ...`.

---

## 6. Bugs found only because modifiers now start earlier

**These had existed for a long time and were unreachable.** Expect the same class in later bundles, especially in games that only exist there.

- **Colour Link crashed.** `RangeError: not in range 0..7: 8`. The palette holds 8 colours, the base curve uses all 8 from level 45, and `gridSize_pairCount` added a ninth. First fix stopped the crash but made generation fail, dropping the player to the **4×4 tutorial board at level 45**. Final fix: the modifier is not offered at all when it has no headroom (`_gridSize < 8 || _numColors < _kPaletteSize`).
- **Color Flood's obstacle generator had no exit guard** — `do { … } while (!_isFloodConnected(…))` would spin forever. It had been unreachable because `hasObstacles` was never set true. Now wired up for levels 75+ with a 30-try bound and a fallback.
- **Layout overflows**: Bridges (44px — chips in a `Row`, now `Wrap`), Word Hive (21px toolbar + 29px body), Sum Strike (7px toolbar), Sudoku (264px eclipse caption). All caused by modifier UI appearing where it never had. The house patterns are `Wrap` for chip rows and `Flexible` + `FittedBox` for the timer in an AppBar — Star Battle already had both.

---

## 7. Pattern Lock P1 and P2

**P1 — auto-fill.** Dots on the straight line between the last selected dot and the new one are inserted, using integer lattice maths (`g = gcd(|dr|, |dc|)`, insert at `k·dr/g, k·dc/g` for `k = 1…g-1`). Haptic fires once per insertion, not per dot. Hit radius widened `0.35` → `0.42` of spacing.

**Safe because the generator only ever steps to an adjacent dot**, so no target pattern contains a jump. **Re-verify that in each bundle** before trusting auto-fill there.

**P2 — "Show again" peek.** Costs one hint, re-shows the pattern for 1.5s, keeps the in-progress trace. Disabled at zero hints, on success, and during the initial memorise phase — without that last guard, tapping it while the pattern is already showing would cancel the real timer and shorten the preview. It deliberately does **not** restart the solve clock.

---

## 8. New markers

Added alongside the six originals. Extend `NEWMARKERS` in `verify_cogniq_fixes.sh` if you add more.

```
mod-deadeffect 20 · curve-plateau 14 · mod-unreachable 5 · mod-start-early 5
patternlock-autofill 4 · layout-overflow 4 · curve-regression 3
patternlock-peek 2 · mod-smallgrid 1 · mod-minactive 1 · mod-inverted 1
```

---

## 9. The verify script was fixed too

**Use the updated `verify_cogniq_fixes.sh`.** The version that shipped with the docs produced false failures on correctly-fixed code, because fixes are documented by quoting the old line above them:

```dart
// Was `max(17, 25 - ((index - 45) ~/ 3))`. For levels 30-44 the dividend
targetFilled = max(17, 25 - ((index - 30) ~/ 5));   // <- the actual, fixed code
```

The greps matched the comment. **Every documented fix reported itself as still broken.** The script now strips `//` lines before matching.

Two checks also tested the old *cause* rather than the fix and were rewritten:

- **7.1** flagged any `>= 30` line near the pool call. Those difficulty branches are meant to stay; only the modifier selection moved out. It now checks whether the call is gated on `_modsOn` / `hasModifiers` / `modifierStartLevel`.
- **2.2** checked whether `timer` is in Pattern Lock's pool. The fix was a `_transformApplies` gate, so it now looks for that.

---

## 10. Known-good, deliberately left alone

- `chimp: 24` and `cipherdecoder: 20` — see §1.
- `getDeterminism(...)` seed strings — those are RNG seeds, not identifiers. Renaming one regenerates every board every player has ever seen.
- `hideCount` in Slitherlink — the win check accepts any single loop matching the **visible** clues, so hiding more clues loosens the win condition rather than tightening it.
- `daily_backup_*` keys — intended behaviour, see `COGNIQ_FIXES_DAILY_TRAIL_GRIDPATH.md` §1.
- The `_ProfileTile` `titleColor` parameter — now never passed, since the deleted tile was its only caller. Left in place; trimming a shared widget's API to silence one warning is not worth the churn.

---

## 11. Not verified by any of the above

**Nothing here has been played.** Every change is code analysis plus the test suite. Worth a real device pass:

- **Grid Path levels 13–17 and 28–32.** The waypoint count drops at both band boundaries (9→7 and 11→8) as the board grows. Probably correct — fewer anchors on a larger grid — but it is the same *shape* as the Pattern Lock regression that was just fixed, so feel it before trusting it.
- **Pattern Lock around level 30**, where the 17-dot curve now continues instead of collapsing.
- **Word Hive with whisper + timer together.** That combination used to be prevented; the pair is now allowed, on the grounds that the balance compensations for it already existed and were clearly intentional. It is a genuine gameplay change.
- **Any game at its new start level**, to confirm the first modifier a player meets actually does something visible on a small board.
