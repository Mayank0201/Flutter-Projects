# CogniQ — Daily Persistence, Trail Toast & Grid Path

**Written:** 2026-08-24
**Verified against:** `github.com/mayank0201/flutter-projects` branch `v5_Puzzle`, commit `3bd34e1` — `pubspec.yaml` says **1.8.0+48**
**Companion file:** `3_GAME_FIXES_FOR_1.8.3.md` — see [Cross-reference](#cross-reference-3_game_fixes_for_183md)

Everything below was read out of real source and, where it is a number, computed — not recalled. Line numbers are from the commit above. If you are applying this to 2.x the logic will have moved; the *shape* of each bug is what to search for, not the line number.

---

## Contents

| # | Item | Verdict | Cost |
|---|---|---|---|
| 1 | [Daily challenge doesn't persist mid-game](#1-daily-challenge-mid-game-persistence) | **Do not fix — not a bug** | — |
| 2 | [Trail unlock toast missing on star unlock](#2-trail-unlock-toast-missing-on-the-star-path) | **Fix, head only** | 1 call |
| 3 | [Grid Path: dead difficulty code + no-op modifier](#3-grid-path-dead-difficulty-code--a-no-op-modifier) | **Fix** | ~6 lines |
| 4 | [Colour Link & Chimp](#cross-reference-3_game_fixes_for_183md) | See companion md | — |
| 5 | [Auditing the rest of the games](#5-auditing-the-other-games) | Method + suspects | — |
| 6 | [Which versions to change](#6-which-versions-actually-need-the-change) | Policy | — |

---

## 1. Daily challenge mid-game persistence

### Verdict: leave it. This is not a bug, and "fixing" it would make things worse.

The daily is not a separate mode — it is a **level swap** (`lib/screens/daily_screen.dart:155-256`):

```dart
final realLevel = prefs.getInt(levelKey) ?? 0;
await prefs.setInt('daily_backup_$gameId', realLevel);      // remember where you were
await prefs.setString('daily_backup_active_game', gameId);
await prefs.setInt(levelKey, levelIndex);                   // pretend you're on the challenge level
await DailyChallengeManager.setupDailyModifier(challenge);

final result = await Navigator.pushNamed(context, game.routeName);   // <-- you play here

if (result == true) { await DailyChallengeManager.completeChallenge(...); }

await updatedPrefs.setInt(levelKey, realLevel);             // put it back
await updatedPrefs.remove('daily_backup_$gameId');
await updatedPrefs.remove('daily_backup_active_game');
await DailyChallengeManager.clearDailyModifier();
```

### Why bailing out costs nothing

`completeChallenge` (`lib/utils/daily_challenge_manager.dart:1237`) writes exactly one gate key, and only on success:

```dart
final key = 'daily_v2_completed_${difficulty.toLowerCase()}_$dateStr';
if (prefs.getBool(key) == true) return;
await prefs.setBool(key, true);
```

I grepped the whole tree for an attempt/failure flag — `attempted`, `failed`, `started`, `consumed`. **There is none.** Nothing is written when you leave. So backing out mid-challenge:

- does **not** burn the day's attempt — it is still playable
- does **not** touch your streak
- costs you only the board you had already filled in

### The genuinely dangerous case is already handled

If the app is *killed* inside the game screen, the cleanup after `await Navigator.pushNamed` never runs — which would leave your real level clobbered by the challenge level and `play_daily_mode` stuck true, leaking the daily modifier into normal play. `lib/main.dart:97-110` catches exactly that on next cold start:

```dart
final activeGame = prefs.getString(PrefsKeys.dailyBackupActiveGame);
if (activeGame != null && activeGame.isNotEmpty) {
  final backupLevel = prefs.getInt(PrefsKeys.dailyBackupGame(activeGame));
  if (backupLevel != null) {
    await prefs.setInt(PrefsKeys.gameLevel(activeGame), backupLevel);
  }
  await prefs.remove(PrefsKeys.dailyBackupActiveGame);
  await prefs.remove(PrefsKeys.dailyBackupGame(activeGame));
  await prefs.setBool(PrefsKeys.playDailyMode, false);
}
```

### The decisive argument

I searched all 110 Dart files for any save/resume machinery — `saveBoardState`, `restoreBoard`, `board_state`, `resumeGame`, `inProgress`, `_saveGameState`. **Zero hits in the entire app.**

**No game in CogniQ persists mid-level state.** The daily behaves exactly like every normal level: leave, come back, board regenerates from `(gameId, level)`. It is *consistent*, not broken.

So the two options are:

- Fix it only for the daily → the daily becomes the one place in the app that resumes, which reads as a bug in the other 20+ games.
- Fix it everywhere → ~20 separate serialise/restore implementations, each with a different state shape, plus a schema-version story for when a board format changes under a saved game. That is a **feature for 2.7**, not a patch.

### Optional 2-line tidy (not required)

The crash-recovery block clears `play_daily_mode` but leaves the `daily_modifier_*` strings in prefs. Harmless — every screen reads them gated on `play_daily_mode`:

```dart
_dailyModifierType = _playDailyMode ? (prefs.getString(PrefsKeys.dailyModifierType) ?? '') : '';
```

— but it is litter. If you want it clean, call the manager instead of setting the bool by hand, in `main.dart`:

```dart
// BEFORE
await prefs.setBool(PrefsKeys.playDailyMode, false);

// AFTER
await DailyChallengeManager.clearDailyModifier();   // clears the bool AND the strings
```

---

## 2. Trail unlock toast missing on the star path

### Verdict: fix it. One call. Highest value-per-line in this document.

**Caveat on this one:** the commit I read is 1.8.0+48, where trails are hardcoded in `hint_manager.dart` against global clear count and `TrailCatalog` does not exist yet. **I could not read your star-unlock code.** The diagnosis below is inference — strong inference, but confirm the call site before you patch.

### Why it is almost certainly this

There is exactly **one** `TrailUnlockToast.show` call in the entire app. `grep -rn "TrailUnlockToast" lib/` returns two lines, and one is the import:

```
lib/utils/hint_manager.dart:7:   import '../widgets/trail_unlock_toast.dart';
lib/utils/hint_manager.dart:123: TrailUnlockToast.show(context, name, emoji, styleId);
```

It sits inside `onLevelCleared`, gated on the **level-clear** counter (`hint_manager.dart:100-123`):

```dart
if (globalCount == 30 || globalCount == 100 || globalCount == 250) {
  String name = ""; String emoji = ""; String styleId = "";
  if (globalCount == 30)       { name = "Game Accent";   emoji = "🎯"; styleId = "accent";  }
  else if (globalCount == 100) { name = "Sparkle Stars"; emoji = "✨"; styleId = "sparkle"; }
  else if (globalCount == 250) { name = "Pastel Glow";   emoji = "🌸"; styleId = "pastel";  }

  final context = navigatorKey.currentContext;
  if (context != null && context.mounted) {
    TrailUnlockToast.show(context, name, emoji, styleId);
  }
}
```

Star unlocks flow through a different function entirely — `DailyChallengeManager.completeChallenge`, which awards bronze/silver/gold, bumps the counters, syncs the widget… and **never mentions trails**.

So the star path is silent *by omission*. The toast was only ever wired into the level-clear path. Nothing is broken; a call is missing.

### The fix

Find whatever evaluates the star-based unlock in your current version and give it the same treatment. It will look like this — note it uses the global `navigatorKey`, because this code runs in a manager with no `BuildContext` of its own:

```dart
// in DailyChallengeManager.completeChallenge (or wherever TrailCatalog
// evaluates a star threshold), immediately after the star totals are written:

final newTrails = await TrailCatalog.checkStarUnlocks();   // returns trails crossed this call
if (newTrails.isNotEmpty) {
  final context = navigatorKey.currentContext;
  if (context != null && context.mounted) {
    for (final t in newTrails) {
      TrailUnlockToast.show(context, t.name, t.emoji, t.id);
    }
  }
}
```

### Three things to get right

1. **`checkStarUnlocks` must return only newly-crossed trails**, not everything currently unlocked — otherwise every daily completion re-toasts the whole set. Mirror `AchievementManager.checkAndUnlock`, which already has this contract and is called ten lines below the trail block in `hint_manager.dart`.
2. **Guard `context.mounted`.** `completeChallenge` is async and the user may have navigated away. The existing call site does this; copy it.
3. **Do not toast during a daily-completion dialog.** `daily_screen.dart:230-250` already shows a Perfect Week dialog, a Perfect Day dialog, or a SnackBar on return. A trail toast firing into a barrier-dismissible dialog will be invisible or will fight it. Either fire the trail toast *after* those resolve, or fold it into the existing SnackBar branch.

Point 3 is the one that will actually bite you. Test the case where the trail unlocks on your **third** daily of the day, which is also the Perfect Day dialog.

---

## 3. Grid Path: dead difficulty code + a no-op modifier

### Verdict: fix. This is the real bug of the three, and it is worse than it looks.

**File:** `lib/screens/games/grid_path/grid_path_screen.dart:382-412`
**Confirmed by computation, not by reading.**

### The code

```dart
int waypointCount;
int minWaypoints = gridSize + 2;          // gridSize is 6 for every level >= 30, so this is 8

if (!_isDailyMode && levelIndex >= 30) {
  if (levelIndex >= 75) {
    waypointCount = 6 + (levelIndex % 4);      // 6..9
  } else if (levelIndex >= 50) {
    waypointCount = 5 + (levelIndex % 3);      // 5..7
  } else {
    waypointCount = 4 + (levelIndex % 2);      // 4..5
  }
  if (activeMods.contains('waypointSparsity')) {
    waypointCount = minWaypoints;              // = 8
  }
} else if (levelIndex < 5) {
  ...
}

if (levelIndex >= 5) {
  if (waypointCount < minWaypoints) {
    waypointCount = minWaypoints;              // <-- the floor that eats everything above
  }
}
waypointCount = waypointCount.clamp(2, (gridSize * gridSize) - 2);   // clamp(2, 34), never binds
```

### What actually happens

The floor is **8**. The three tuning branches produce 4-5, 5-7, and 6-9. So:

| Levels | Formula range | After the floor | Formula survives? |
|---|---|---|---|
| 30-49 | 4-5 | **8, always** | never |
| 50-74 | 5-7 | **8, always** | never |
| 75+ | 6-9 | 8, or 9 when `level % 4 == 3` | 1 level in 4 |

Computed over levels 30-119: **the formula survives 23 of 90 levels (26%)**, and across 30-74 the set of distinct waypoint counts produced is exactly `{8}`.

**Grid Path has no difficulty progression at all from level 30 to 74.** Forty-five consecutive levels, identical waypoint count. All three tuning branches are dead code — they compute a value that is thrown away.

### The second bug, hiding behind the first

`waypointSparsity` sets `waypointCount = minWaypoints`, which is **8** — the exact value the floor produces anyway. So:

| Level | Base | With sparsity | Delta |
|---|---|---|---|
| 30 | 8 | 8 | **0** |
| 50 | 8 | 8 | **0** |
| 74 | 8 | 8 | **0** |
| 75 | 9 | 8 | −1 |
| 78 | 8 | 8 | **0** |

The modifier is advertised in the UI (`grid_path_screen.dart:527`):

```dart
case 'waypointSparsity':
  return 'Sparse: fewer waypoints shown';
```

It does **literally nothing on all 45 levels from 30 to 74**, and removes exactly one waypoint on the quarter of levels above 75 where the formula clears the floor. Players are being told a modifier is active when it changes nothing.

### The fix

The floor exists for a real reason — too few waypoints on a 6×6 makes the path ambiguous. The mistake is applying a floor sized for a 6×6 to branches that were tuned as if they would run. Make the post-30 branch start *above* the floor and rise:

```dart
int waypointCount;
final int minWaypoints = gridSize + 2;        // 8 at gridSize 6

if (!_isDailyMode && levelIndex >= 30) {
  // Start above minWaypoints (8) and climb, so these values actually survive the
  // floor below. The old 4/5/6-based branches were silently discarded: every
  // level from 30 to 74 resolved to a flat 8.
  final int band = levelIndex >= 75 ? 2 : (levelIndex >= 50 ? 1 : 0);
  waypointCount = minWaypoints + band + (levelIndex % 2);   // 8-9, 9-10, 10-11

  if (activeMods.contains('waypointSparsity')) {
    // Sparse must be strictly sparser than the level's own baseline, and must
    // still respect the floor -- otherwise it is a no-op (which it was).
    waypointCount = (waypointCount - 2).clamp(minWaypoints, waypointCount);
  }
} else if (levelIndex < 5) {
  waypointCount = 2 + (levelIndex ~/ 2);
} else if (levelIndex < 15) {
  waypointCount = 3 + ((levelIndex - 5) ~/ 3);
} else if (levelIndex < 30) {
  waypointCount = 5 + ((levelIndex - 15) ~/ 4);
} else {
  waypointCount = 6 + ((levelIndex - 30) ~/ 5);
}

if (levelIndex >= 5 && waypointCount < minWaypoints) {
  waypointCount = minWaypoints;
}
waypointCount = waypointCount.clamp(2, (gridSize * gridSize) - 2);
```

Note the sparsity fix still bottoms out at `minWaypoints`, so on levels 30-49 it remains a no-op by design — the alternative is generating ambiguous boards. If you want Sparse to mean something at every level, you must **raise the baseline further**, not lower the floor. That is the honest trade.

### Verify before shipping

The generator places waypoints along a generated path (`grid_path_screen.dart:506-521`):

```dart
final int pathIndex = (i * (pathLen - 1) / (waypointCount - 1)).round();
```

Raising `waypointCount` to 11 on a 6×6 (36 cells) means 11 waypoints on a path of at most 36 — fine on paper, but **this project's history is generators that were believed instead of measured.** Skyscrapers took three rounds: first correct but 10 s/board, then fast but throwing on 1.5% of boards, then finally right. Do not skip the soak:

```
Run every level 0..150, 20 seeds each. Assert for each board:
  - generation does not throw
  - generation completes under 200 ms
  - waypoints are numbered 1..waypointCount with no gaps and no duplicates
  - a valid path visiting them in order exists
  - the same (gameId, level) produces a byte-identical board twice
```

That last one is the seeded-RNG law — the board must stay a pure function of `(gameId, level)`. Never introduce a bare `Random()`; always `RotationEngine.getDeterminism('zip', levelIndex)`.

---

## Cross-reference: `3_GAME_FIXES_FOR_1.8.3.md`

**Colour Link and Chimp are already written up in `3_GAME_FIXES_FOR_1.8.3.md`, with before/after code. Use that file — do not re-derive them from here.** Grid Path is covered in both; **section 3 above supersedes** the Grid Path section in the 1.8.3 md, because the floor arithmetic and the `waypointSparsity` no-op were computed rather than reasoned about.

Two things I re-confirmed on this commit that are worth carrying back into that file:

**Colour Link — the regression is real and permanent.** `numberlink_beta.dart:160-176`:

| Levels | Grid | Colours |
|---|---|---|
| 45-59 | 8 | **8** ← peak |
| 60-79 | 8 | **6** ← drops |
| 80+ | 6/7/8 cycling | 4/5/6 cycling ← never recovers |

Level 80 is `(6, 4)` — the same board size and colour count as **level 10**. It never climbs back above the level-45 peak, forever.

**Chimp — a 60 → 7 cliff, and you need to decide which side is wrong.** `patches_screen.dart:29-38` ends at `(9, 60)`; `_getChimpConfig` for index ≥ 30 returns `(4, 7)` — byte-identical to level 3, and capped at 15 numbers forever.

`_n` is the count of numbers to memorise — the UI says `'Memorize 1 → $_n, then tap 1 to begin'` (`patches_screen.dart:702`). **60 numbers is superhuman;** the human Chimp Test ceiling is around 15. So the two readings are:

- The **table** is wrong — levels ~20-29 are unwinnable and players quit there.
- The **post-30 band** is wrong — it resets a hard game to trivial.

They cannot both be right. **Playtest levels 25-29 before patching either side.** If you cannot clear them, fix the table, not the post-30 code.

> Your later note said Chimp's board "caps at 24", which does **not** match this commit's table (it reaches 60). That strongly suggests you already changed the table somewhere in 2.x. Check the current version before applying anything — this specific finding may already be dead.

---

## 5. Auditing the other games

The three bugs are three distinct patterns. Each has a mechanical search.

### Pattern A — a floor or clamp eats the tuning code

**Symptom:** difficulty is computed in branches, then a floor overrides it. The branches become dead code and difficulty goes flat.
**Found in:** Grid Path.

**How to find it:** for each game, extract the difficulty expression and the floor/clamp, then *evaluate them* over levels 0-150. Do not read them — run them. If the set of distinct outputs over a 40-level span has size 1, it is flat.

```python
# paste each game's formula in and run this; it is how Grid Path was caught
def waypoints(i):
    grid = 6; minw = grid + 2
    f = 6+(i%4) if i>=75 else (5+(i%3) if i>=50 else 4+(i%2))
    return max(f, minw)

vals = {waypoints(i) for i in range(30, 75)}
print(vals, "FLAT - formula is dead" if len(vals) == 1 else "ok")
```

### Pattern B — the curve goes backwards

**Symptom:** a later level is objectively easier than an earlier one.
**Found in:** Colour Link (peaks at L45, drops at L60, never recovers), Chimp (60 → 7 at L30).

**How to find it:** score each level with one number — cells × colours, grid × count, whatever means "hard" for that game — and assert it never decreases:

```python
score = [difficulty_of(i) for i in range(0, 150)]
drops = [(i, score[i-1], score[i]) for i in range(1, 150) if score[i] < score[i-1]]
print(drops or "monotonic")
```

A deliberate reset is fine *if intended* — but it must be a decision, not the `% n` operator quietly wrapping around. `4 + ((level - 80) % 3)` is not a difficulty curve, it is an oscillator.

### Pattern C — a modifier that changes nothing

**Symptom:** a modifier sets a value to something the baseline already produces.
**Found in:** Grid Path `waypointSparsity`.

**How to find it:** for every modifier, compute the board parameter with it on and with it off, at every level it can appear. If the delta is 0, the modifier is a lie the UI is telling the player.

```python
for lvl in range(30, 120):
    if base(lvl) == with_modifier(lvl):
        print(f"L{lvl}: NO-OP")
```

This is worth doing across all of them. Modifiers are implemented **per game screen** — 18 screens implement `fog` individually — so there is no central place where this could have been caught, and no reason to assume Grid Path is the only one.

### Suspect list

Games in this commit that contain both a `level >= 30` branch and a floor/clamp — i.e. the shape that produced the Grid Path bug. **This is a list of things to check, not a list of confirmed bugs.** I verified Grid Path only.

| File | floors/clamps | post-30 blocks | |
|---|---|---|---|
| `grid_path_screen.dart` | 9 | 3 | ← **confirmed broken** |
| `mine_finder_screen.dart` | 9 | 5 | |
| `word_hive_screen.dart` | 4 | 5 | |
| `sum_strike_screen.dart` | 4 | 5 | |
| `odd_color_out_screen.dart` | 4 | 4 | |
| `numberlink_beta.dart` (Colour Link) | 3 | 5 | ← confirmed (Pattern B) |
| `circuit_guide_beta.dart` | 3 | 8 | |
| `pattern_lock_beta.dart` | 3 | 8 | |
| `sudoku_screen.dart` | 2 | 8 | |
| `spectrum_screen.dart` | 1 | 9 | |
| `star_battle_screen.dart` | 1 | 5 | |
| `color_flood_beta.dart` | 1 | 3 | |

Regenerate this list on your current version with:

```bash
for f in $(find lib/screens/games -name "*.dart"); do
  c=$(grep -cE "\.clamp\(|= *min\w*;|< *min\w+\)" "$f")
  l=$(grep -cE "(levelIndex|_currentLevel|_levelIndex) *>= *30" "$f")
  [ "$l" -gt 0 ] && [ "$c" -gt 0 ] && printf "%-34s clamps=%-3s post30=%s\n" "$(basename $f)" "$c" "$l"
done
```

### Make it permanent

None of this should rely on anyone remembering to look. Add to `difficulty_curve_test.dart` — a test per game that asserts the curve is non-decreasing and not flat for more than N levels. That converts all three patterns from "hope someone notices" into a red test.

---

## 6. Which versions actually need the change

**The rule: backport only what loses data or blocks play.**

The version zips are historical snapshots, not things you patch. The only builds that matter are the ones you still intend to **upload** — the unshipped ladder 1.8.2(61) → 2.5(68). A fix in a build that ships must exist in every build after it, or it reappears as a regression.

| Fix | Backport? | Why |
|---|---|---|
| Daily persistence | **N/A** | Not a bug. Nothing to ship. |
| Trail toast | **No — head only** | Cosmetic. Does not corrupt or accumulate. A player who silently unlocks a trail during 1.8.2-2.5 gets the toast working after they update; nothing is lost in between. |
| Grid Path | **No — head only** | Difficulty tuning. Existing players keep their progress either way; nobody is blocked. |
| Colour Link / Chimp | **No — head only** | Same reasoning. See `3_GAME_FIXES_FOR_1.8.3.md`. |

Contrast: the daily-challenge **crash** fix belonged at the bottom of the ladder, in 1.8.2(61), because a crash stops people cold. That distinction is the whole policy.

> **Still outstanding, unrelated to this file:** `cogniq(1.8.2(61))` has never been uploaded to Play internal testing. The daily-challenge crash fix has now been built and unshipped for nine builds. That is worth more than everything in this document.

---

## 7. One structural suggestion

The reason "do I have to change this in every version?" is a hard question is that `cogniq` is **not a git repository** — `versions/<x.y>/` plus `NOTES.md` has been doing the job of version control by hand.

You already have the remote: `github.com/mayank0201/flutter-projects`. It is sitting at **1.8.0+48**, four versions behind. Pushing the current tree to a `v6` branch would give you real history, real diffs, and turn "which versions have this fix?" into something git answers instead of you.

**Before you push, check `.gitignore` covers these — they are in every zip:**

```
android/app/upload-keystore.jks
android/key.properties
```

Those are your **signing secrets**. If they reach a public repo, anyone can sign builds as you, and Play does not let you rotate an upload key without support intervention. The licensing key in the manifest is a *public* key and is designed to be embedded — that one is fine.
