# verify_cogniq_fixes.sh

Checks that the six backport fixes actually landed in a CogniQ version.
Built to be run on **all 8 versions at once**, after you've propagated 1.8 forward.

Companion to `backport.md` (which says *what* to change). This says *whether it worked*.

---

## Run it

```bash
# one version
./verify_cogniq_fixes.sh "Cogniq Versions/cogniq(1.8.2(61))"

# every version under a parent folder - auto-finds each pubspec.yaml
./verify_cogniq_fixes.sh "Cogniq Versions"
```

Exit `0` = all versions clean. Exit `1` = at least one FAIL. Ends with a PASS/FAIL summary table.

Git Bash on Windows. No dependencies beyond grep/sed/awk/find.

---

## Prerequisite: leave a marker on every fix

The script can't judge whether your new code is *correct* — it checks that the edit
**happened** and that the **old code is gone**. That needs a breadcrumb.

As you make each fix, drop a comment on it:

```dart
// COGNIQ-FIX:mod-start-map
static const Map<String, int> _modifierStartLevel = { ... };
```

Six markers, one per change:

| Marker | Expected in | Fix |
|---|---|---|
| `COGNIQ-FIX:trail-toast` | `lib/utils/hint_manager.dart` | toast fires on the star-completion path |
| `COGNIQ-FIX:gridpath-floor` | `lib/screens/games/grid_path/` | waypoint floor stops eating the formula |
| `COGNIQ-FIX:mod-start-map` | `lib/utils/rotation_engine.dart` | per-game `_modifierStartLevel` map + accessor |
| `COGNIQ-FIX:mod-active-helper` | `lib/screens/games/` | generic `_isModActive` in each screen |
| `COGNIQ-FIX:mod-getters` | `lib/screens/games/` | hard-disabled per-modifier getters removed |
| `COGNIQ-FIX:mod-desc-copy` | anywhere in `lib/` | modifier description copy rewritten |

Rename them if `backport.md` labels the changes A–F differently — edit the `MARKERS`
array at the top of the script. It only greps for the string you actually type.

Markers also make the fixes greppable forever, which is what you'll want the next
time one of them regresses.

---

## The six checks

**1. Markers present** — all six found, and it prints how many files each is in.
`mod-active-helper` should show ~30 files in 1.8 and ~33 in 2.5.

**2. Old level-30 gate gone** — FAILs on any surviving `levelIndex >= 30`, with
file:line. Also WARNs on any other `>= 30` in game screens so you can eyeball it.

**3. Description copy** — FAILs on `past 30 levels`, `after level 30`, `30+ levels`
and similar still shipping in strings.

**4. Map covers the roster** — reads the game ids out of `game_info.dart` for
**that version**, reads the keys out of the `_modifierStartLevel` map, and FAILs on
any roster game with no start level.
Self-adapting: 30 ids in 1.8, 33 in 2.5, no per-version config.
Map keys *not* in the roster print as `info`, not a failure — that's the whole point
of shipping the identical map everywhere. Extra keys are inert.

**5. Generic helper adopted** — finds every screen containing modifier logic, and
FAILs any that lacks `bool _isModActive` or doesn't call
`RotationEngine.modifierStartLevel`. WARNs on literal
`activeModifiers.contains('fog')` checks that bypass the helper.

**6. Deliberate non-changes** — FAILs if the `daily_backup_` keys disappeared.
Daily persistence is **not** a bug (see `COGNIQ_FIXES_DAILY_TRAIL_GRIDPATH.md` §1);
this check exists so nobody "helpfully" rips out the level-swap during a backport.

---

## Escape hatch

If a line legitimately trips a check — a `>= 30` that's a grid size, not a modifier
gate — append this to the line and it's skipped:

```dart
if (score >= 30) { ... }  // not-a-modifier-gate
```

Use it sparingly. Every one you add is a check you've turned off.

---

## What it does NOT prove

- That a start level is a *good* number. Only that one exists.
- That the Grid Path formula now produces a sensible waypoint spread — that's the
  arithmetic in `COGNIQ_FIXES_DAILY_TRAIL_GRIDPATH.md` §3, and it needs a real run.
- That the app builds. Run `flutter analyze` separately.
- Anything about gameplay. Green here means "the edit is in place in all 8 versions",
  not "the game is right". Deep testing happens once, on 1.8.
