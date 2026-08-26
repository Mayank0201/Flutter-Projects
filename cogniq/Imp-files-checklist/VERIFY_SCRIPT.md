# verify_cogniq_fixes.sh

Checks that the backported fixes actually landed in a CogniQ version.
Built to be run on **all 8 versions at once**, after you've propagated 1.8 forward.

Companion to `backport.md` (which says *what* to change) and
`BACKPORT_PARTIAL_FIXES.md` (which says *what is still broken*). This says
*whether it worked*.

> **v2.** The script now covers the original six backport changes **A–F** *and* the
> **8 groups** from `BACKPORT_PARTIAL_FIXES.md` — 13 sections in total. Same
> filename as v1 on purpose, so every doc that references it keeps working. All six
> original checks are unchanged; nothing that passed before starts failing.

---

## Run it

```bash
# one version
./verify_cogniq_fixes.sh "Cogniq Versions/cogniq(1.8.2(61))"

# every version under a parent folder - auto-finds each pubspec.yaml
./verify_cogniq_fixes.sh "Cogniq Versions"
```

Exit `0` = all versions clean. Exit `1` = at least one FAIL. Ends with a per-version
summary line and an `N of 9 groups clear` count.

Git Bash on Windows. No dependencies beyond grep/sed/awk/find.

**Expect it to fail the first time.** Against an unfixed 1.8 it reports **23 failures,
0 of 8 groups clear**. That is the correct starting reading — sections 8–12 look for
*broken patterns* and fail when they find them, so the script doubles as a progress
meter. Work the groups in the order in `BACKPORT_PARTIAL_FIXES.md` §5 and watch the
count drop.

---

## Prerequisite: leave a marker on every fix

The script can't judge whether your new code is *correct* — it checks that the edit
**happened** and that the **old code is gone**. That needs a breadcrumb.

As you make each fix, drop a comment on it:

```dart
// COGNIQ-FIX:mod-start-map
static const Map<String, int> _modifierStartLevel = { ... };
```

### The six original markers (changes A–F)

| Marker | Expected in | Fix | Count in 1.8 |
|---|---|---|---|
| `COGNIQ-FIX:trail-toast` | `lib/utils/hint_manager.dart` | toast fires on the star-completion path | 2 |
| `COGNIQ-FIX:gridpath-floor` | `lib/screens/games/grid_path/` | waypoint floor stops eating the formula | 1 |
| `COGNIQ-FIX:mod-start-map` | `lib/utils/rotation_engine.dart` | per-game `_modifierStartLevel` map + accessor | 1 |
| `COGNIQ-FIX:mod-active-helper` | `lib/screens/games/` | generic `_isModActive` in each screen | 20 |
| `COGNIQ-FIX:mod-getters` | `lib/screens/games/` | hard-disabled per-modifier getters removed | 17 |
| `COGNIQ-FIX:mod-desc-copy` | anywhere in `lib/` | modifier description copy rewritten | 19 |

**Change F has no marker.** Section 7 checks it by pattern instead — see below.

### The six group markers (add as you close each group)

These do not exist yet. Section 13 lists them as `pending` until you add one.

| Marker | Group |
|---|---|
| `COGNIQ-FIX:mod-deadeffect` | 2 — modifiers announced but doing nothing |
| `COGNIQ-FIX:mod-unreachable` | 3 — modifiers that can never be selected |
| `COGNIQ-FIX:mod-inverted` | 4 — modifiers that do the opposite of their description |
| `COGNIQ-FIX:curve-regression` | 5 — difficulty running backwards |
| `COGNIQ-FIX:curve-plateau` | 6 — frozen boards |
| `COGNIQ-FIX:mod-start-early` | 7 — lowered start levels + unwrapped `>= 30` blocks |

Group 1 reuses the existing markers — don't invent new ones for it. Group 8 is
housekeeping and needs no marker; sections 12's checks detect it directly.

Rename anything freely — edit the `MARKERS` and `NEWMARKERS` arrays at the top of
the script. It only greps for the string you actually type.

---

## The 13 sections

### Sections 1–6 — the original backport (unchanged from v1)

**1. Markers present** — all six found, with a file count each.

**2. Old level-30 gate gone** — FAILs on any surviving `levelIndex >= 30`, with
file:line. WARNs on any other `>= 30` in game screens so you can eyeball it.

**3. Description copy** — FAILs on `past 30 levels`, `after level 30`, `30+ levels`
and similar still shipping in strings.

**4. Map covers the roster** — reads the game ids out of `game_info.dart` for
**that version**, reads the keys out of the `_modifierStartLevel` map, FAILs on any
roster game with no start level. Self-adapting: 24 ids in 1.8, more in later
bundles, no per-version config. Map keys *not* in the roster print as `info`, not a
failure — that's the point of shipping the identical map everywhere. Extra keys are
inert. In 1.8: 24 roster ids against 44 map keys.

**5. Generic helper adopted** — finds every screen containing modifier logic (25 in
1.8) and FAILs any that lacks `bool _isModActive`. Also FAILs a screen that reads
the start level through **neither** `RotationEngine.modifierStartLevel` **nor**
`RotationEngine.hasModifiers` — both are valid routes to the same map, so a screen
using either one passes. WARNs on literal `activeModifiers.contains('fog')` checks
that bypass the helper (30 of them in 1.8 — that's group 1.4).

**6. Deliberate non-changes** — FAILs if the `daily_backup_` keys disappeared.
Daily persistence is **not** a bug (see `COGNIQ_FIXES_DAILY_TRAIL_GRIDPATH.md` §1);
this check exists so nobody "helpfully" rips out the level-swap during a backport.

### Section 7 — change F, which has no marker

Change F (Colour Link curve + Chimp cliff) left no `COGNIQ-FIX:` comment, so v1 of
this script would pass a version where F was never applied. Section 7 detects the
**pre-F code** instead: it FAILs if `_currentLevel >= 60 && _currentLevel < 80`
still exists in `colour_link_screen.dart`. That branch is the old four-step curve
that dropped to 6 colours at level 60 and cycled from 80 — difficulty running
backwards. A fixed Colour Link has exactly two branches, `< 45` and `else`.

### Sections 8–12 — the 8 groups

These invert the logic: they search for the **broken pattern** and FAIL when found.
A group whose file doesn't exist in a given version is **skipped with a WARN**, not
failed — later bundles have more games, earlier ones fewer.

**8. Group 1 — backport fixes that stopped short.**
`1.1` trail toast using `globalCount == 30` (exact equality, no notified-flag) ·
`1.2` Word Hive asking for `'wordhive'`, which isn't a map key ·
`1.3` any screen using two different gameIds — it extracts the id from
`modifierStartLevel(...)` and from `gameId:` and compares them, catching all four
mismatches including the three that currently work by luck ·
`1.4` per-modifier getters declared and never called, found by counting references
per file rather than by running the analyzer ·
`1.6` WARNs if `modifierCountFor` / `kMinimalPool` from change A are absent (a
decision to make, not a bug).

**9. Groups 2–4 — dead, unreachable and inverted modifiers.**
`2.1` Pearl Loop with `'zoom'` in the pool and no `InteractiveViewer` anywhere ·
`2.2` Pattern Lock's `boardTransform` gated on a `timer` modifier that isn't in its
pool · `2.4` Killer Sudoku setting `numGivens = 0` where the band already did ·
`2.5` Grid Path's `clamp(minWaypoints, …)` cancelling `waypointSparsity` ·
`3.1` Circuit Guide clearing `_activeModifiers` **before** testing `_isEndgame` — it
compares the two line numbers, so it stays correct as the file moves ·
`3.2` Practice sandbox declaring `_isModActive` and never calling it (WARN) ·
`4.1` Killer Sudoku's `cageSize` shrinking the cages it promises to grow.

**10. Groups 5–6 — the difficulty curve.**
`5.1` Pattern Lock's `5 + (_currentLevel % 3)` collapse at level 30 ·
`5.2` Sudoku's `((index - 45) ~/ 3)` negative-division clue regression ·
`6.1` Grid Path's pre-30 waypoint formulas that the floor discards ·
`6.2` Slitherlink's `targetRegionFor` — it extracts the function body and checks
whether `level` is used at all · `6.3` Odd Color Out's `delta < 0.035` floor ·
`6.4a` Color Flood's duplicated colour band, by counting occurrences ·
`6.4b` Color Flood's `hasObstacles` never assigned `true` ·
`6.5` Spectrum's duplicated board band.

**11. Group 7 — modifier start levels.**
`7.1` the four screens whose `getActiveModifiers` call sits inside a hardcoded
`>= 30` block, where **lowering the map value does nothing**. It finds the pool call,
then the nearest `>= 30` gate *before* it — not merely the first one in the file, or
Star Battle slips through. ·
`7.2` prints the whole start-level map as `info` so a human can read the numbers at
a glance. Never fails — the numbers are a design decision, not a correctness one.

**12. Group 8 — engine and housekeeping dead code.**
`8.1` FAILs if `smallGrid` appears 2 times or fewer in `rotation_engine.dart` — that
means it's a parameter and a comment, never read. This one matters most *after* you
lower start levels, because it's the guard that keeps modifiers off tiny boards. ·
`8.2` WARNs if `minActive` looks inert · `8.4` WARNs if Slitherlink still has no
`_getModifierDescription`.

### Section 13 — group markers

Lists the group markers as `pending` or `PASS`. Turns green as you close groups.

### Section 14 — Group 9: In-App Review Prompt (Change G)

Checks that `in_app_review` is in `pubspec.yaml`, the `COGNIQ-FIX:review-prompt` marker is present, `requestReview()` is not called from launch or `initState`, the 90-day cooldown is present, and `reviewPromptLastShown` is stamped before requesting review.

### Verdict

Per-group `clear` / `open (N issues)`, then `N of 9 groups clear`, then the usual
version PASS/FAIL. The summary at the end carries the group count per version, so
running it across all 8 bundles tells you at a glance how far each one has come.

---

## Escape hatch

If a line legitimately trips a check — a `>= 30` that's a grid size, not a modifier
gate — append this to the line and it's skipped:

```dart
if (score >= 30) { ... }  // not-a-modifier-gate
```

It applies to sections 2, 3 and to every group check that greps a pattern.

Use it sparingly. Every one you add is a check you've turned off.

---

## Using it on the other 7 bundles

Every `file:line` in `BACKPORT_PARTIAL_FIXES.md` is a **1.8** line number and will be
wrong elsewhere. **This script is the portable version of that document** — every
check is a pattern, not a position, so it gives a true answer on any bundle without
adjustment.

Two things it can't do for later bundles:

- **It doesn't know about games that don't exist in 1.8.** 2.5 has more games than
  1.8, and none of them were audited. The script runs clean against them because
  there's nothing to match — not because they're healthy. `BACKPORT_PARTIAL_FIXES.md`
  §7 has the three questions to audit them by hand.
- **It can't tell "already fixed" from "never broken".** If a later bundle passes a
  group check, that's good either way — but don't apply a fix to code that was
  already correct. Check before changing.

---

## What it does NOT prove

- That a start level is a *good* number. Only that one exists, and that the screen
  can actually see it.
- That the Grid Path formula now produces a sensible waypoint spread. It proves the
  discarded formula is gone, not that the replacement feels right. That's the
  arithmetic in `COGNIQ_FIXES_DAILY_TRAIL_GRIDPATH.md` §3 and
  `BACKPORT_PARTIAL_FIXES.md` §6.1, and it needs a real run.
- That a modifier you "fixed" now does something a player would notice. Section 9
  proves the no-op pattern is gone; only playing proves the effect landed.
- That the app builds. Run `flutter analyze` separately — it must stay at **0 errors**.
- Anything about gameplay. Green here means "the edits are in place in all 8
  versions", not "the game is right". Deep testing happens once, on 1.8.
