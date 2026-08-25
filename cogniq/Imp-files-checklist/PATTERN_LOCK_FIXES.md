# CogniQ — Pattern Lock: two input fixes

**Put this file in `cogniq/Imp-files-checklist/` alongside `backport.md`.**

**Audience:** an AI coding agent working on CogniQ, or a developer picking this up cold.

Two problems reported by the app owner from real play, both in `lib/screens/games/pattern_lock/pattern_lock_screen.dart`. Numbered **P1** and **P2** so they never collide with the 8 groups or the R-numbers in the other documents.

---

## 0. How this file fits with the others

This folder holds one continuous piece of work. Read the others before acting on this one.

| File | What it covers |
|---|---|
| `backport.md` | **Entry point.** Procedure and progress for the original six changes **A–F**, across bundles **61–68** |
| `BACKPORT_PARTIAL_FIXES.md` | What actually landed vs what the docs claim, plus **8 groups** of modifier and difficulty-curve issues |
| `RESET_PROGRESS_FIXES.md` | Removal of the "Clear All Saved Progress" feature, plus its Play Console checklist |
| **this file** | **Pattern Lock input.** Two gameplay bugs, P1 and P2 |
| `CHALLENGE_MODE_MODIFIERS_AND_DESC.md` | Code for changes A, B, C |
| `COGNIQ_FIXES_DAILY_TRAIL_GRIDPATH.md` | Code for changes D and E, plus the daily-persistence non-bug |
| `3_GAME_FIXES_FOR_1.8.3.md` | Code for change F |
| `verify_cogniq_fixes.sh` | Checks A–F and all 8 groups. Does **not** check P1 or P2 — see §5 |
| `VERIFY_SCRIPT.md` | What that script proves and what it does not |
| `Monthly_Version_Issue_checklist.md` | Monthly release routine and the three rot risks |

**Precedence:** `backport.md` wins on procedure. `BACKPORT_PARTIAL_FIXES.md`, `RESET_PROGRESS_FIXES.md` and this file win on status — all written from a direct audit of the 1.8 code at commit `5da298c`.

### This is a backport change like any other

Both fixes must reach **all 8 bundles, version codes 61–68**:

`1.8.2(61)` · `(62)` · `(63)` · `(64)` · `(65)` · `2.3.1(66)` · `2.4(67)` · `2.5(68)`

Fix in 1.8 first, verify, then propagate with the `diff -q` procedure in `backport.md` — one branch per version, oldest first.

### Do Pattern Lock's other findings in the same pass

`BACKPORT_PARTIAL_FIXES.md` already has **two more Pattern Lock issues in the same file**:

- **Group 5.1** — at level 29 the pattern is 17 dots; at level 30 it collapses to 5 and then cycles 5/6/7 for fifty levels
- **Group 2.2** — the `boardTransform` modifier computes a transform that free play never applies, because it is gated on a `timer` modifier that is not in Pattern Lock's pool

Four fixes, one file. Doing them together means one review, one round of testing, one diff to propagate eight times. **Read those two before you start** — group 5.1 changes `targetLength`, which decides how many dots a pattern has, and that interacts with P1's testing.

### Same rule as everywhere else

**A documented fix is not an applied fix.** Change E proves it — fully written up, half applied, unnoticed for months. Check the code.

---

## 1. The two issues

| | Symptom | Cause |
|---|---|---|
| **P1** | Dragging from one dot straight to a distant dot skips the dots in between instead of collecting them | The input handler only registers a dot when a touch sample lands inside its hit circle. Nothing fills in dots crossed between samples. |
| **P2** | Once tracing begins there is no way to see the pattern again | `_isMemorizing` is a one-shot flag. A timer sets it false and nothing ever sets it back. |

Both are decided. P1 is a straight bug. P2's design question has been answered by the app owner — the peek costs one hint (§3). Build both as written.

---

## 2. P1 — Dragging over a dot does not select it

### What happens now

`_onPanUpdate` (`:445`) asks `_getHitDot` (`:422`) which dot the finger is currently inside:

```dart
int _getHitDot(Offset localPos) {
  final total = _gridN * _gridN;
  final hitRadius = _spacing * 0.35;
  for (int idx = 0; idx < total; idx++) {
    double dist = (localPos - _dotCenter(idx)).distance;
    if (dist < hitRadius) {
      return idx;
    }
  }
  return -1;
}
```

A dot is added **only** when a touch sample happens to land within `0.35 × spacing` of its centre. Two ways that fails:

1. **The finger travels between two dots without a sample landing on the one in between.** `onPanUpdate` fires roughly once per frame. Drag quickly and the pointer jumps far enough between frames to step clean over a dot's hit circle.
2. **The finger passes just outside the circle.** The hit radius is 35% of the spacing, so a slightly wide arc misses a dot the player visually dragged straight through.

Either way the dot is silently skipped, the pattern is wrong, and to the player it looks like the game ignored their input.

### The fix

When a new dot is selected, insert every dot that lies **on the straight line between the previously selected dot and the new one**, in order, skipping any already in the pattern. This is exactly what the Android system pattern lock does, and it is what players expect.

Use integer lattice arithmetic, not floating point. For a step from `(r1, c1)` to `(r2, c2)`:

```
dr = r2 - r1
dc = c2 - c1
g  = gcd(|dr|, |dc|)          // gcd(0, x) = x; g == 0 only if the dots are identical
```

If `g > 1`, the dots in between sit at `(r1 + k·dr/g, c1 + k·dc/g)` for `k = 1 … g-1`. If `g <= 1` there are no dots in between and nothing is inserted.

Worked examples on a 4×4 grid (index = `row * n + col`):

| From → To | dr, dc | g | Dots inserted |
|---|---|---|---|
| (0,0) → (0,3) | 0, 3 | 3 | (0,1), (0,2) |
| (0,0) → (2,2) | 2, 2 | 2 | (1,1) |
| (0,0) → (2,1) | 2, 1 | 1 | none — no dot lies on that line |
| (0,0) → (0,1) | 0, 1 | 1 | none — already adjacent |

Add this in `_onPanUpdate` at `:451`, in the branch that currently does a bare `_userPattern.add(idx)`. Insert the in-between dots **before** the new one, preserving order.

### Why this is safe — the generator never produces a jump

**This matters: verify it still holds in each bundle before assuming the fix is harmless.**

The target pattern is built by a random walk (`:310-337`) that only ever steps to an adjacent dot:

```dart
if (r > 0) neighbors.add((r - 1) * n + c);
if (r < n - 1) neighbors.add((r + 1) * n + c);
if (c > 0) neighbors.add(r * n + c - 1);
if (c < n - 1) neighbors.add(r * n + c + 1);

if (!_playDailyMode && _currentLevel >= 30) { // not-a-modifier-gate
  // the four diagonals, also ±1 in each axis
}
```

Every step is ±1 in row, column, or both. **No generated pattern ever jumps over a dot**, so for any target, `g` is always 1 between consecutive dots and auto-fill inserts nothing that was not meant to be there. `_generateValidWalkPath` (`:504`) has the same adjacency rule.

The fix therefore only ever *corrects* input the player intended, and can never make a target pattern impossible to enter.

### Points to get right

- **Only insert dots not already in `_userPattern`.** A dot already used must be skipped, not re-added — the same rule the existing `!_userPattern.contains(idx)` check applies.
- **Preserve order.** Insert the in-between dots first, then the newly hit dot.
- **The backtrack branch at `:456`** — where dragging back onto the second-to-last dot removes the last one — should keep working. Test that reversing over an auto-filled dot behaves sanely; decide whether backtracking removes one dot or the whole auto-filled run, and be consistent.
- **Haptics.** `settingsNotifier.hapticTap()` currently fires once per added dot. Firing it four times in one frame for an auto-filled run feels like a buzz. Fire once for the whole insertion, or once for the final dot only.
- **`_onPanStart` (`:434`) needs no change** — the first dot has no predecessor.

### Consider also widening the hit radius

`hitRadius = _spacing * 0.35` is fairly tight. Once auto-fill is in, the radius matters less for dots along the path, but it still decides how precisely the player must land on the *first* dot and on turns. If the game still feels fussy after P1, try `0.40`–`0.45` and test on a real device — not the simulator, where a mouse is far more precise than a thumb.

---

## 3. P2 — No way to see the pattern again

### What happens now

`_isMemorizing` starts `true` on level load (`:245`). A timer (`:408`) sets it `false` after the memorise duration:

```dart
_memorizeTimer = Timer(Duration(milliseconds: (durationSeconds * 1000).toInt()), () {
  ...
  _isMemorizing = false;
```

**Nothing in the file ever sets it back to `true`.** The painter shows `_targetPattern` while memorising and `_userPattern` afterwards (`:939`), so once the timer fires the pattern is gone for the rest of the level.

The only recovery today is the hint button (`:691-743`), which reveals **one dot** — the next correct one — costs a hint, and clears itself after a delay.

### The decision — MADE. Peek costs one hint.

**The app owner has chosen: a "Show again" button that re-enters the memorise phase briefly and consumes one hint.** Build this. Do not re-open the question.

- Costs **one hint** per use, taken through `HintManager.useHint('pattern_lock')`, exactly like the existing single-dot hint
- Re-shows the **whole pattern** for a short window — start at **1.5 seconds** and tune on a device
- No free allowance, no per-level limit beyond what the player's hint balance allows

**Why this and not a free peek:** hints are bought with points, and points are bought with real money. A free full-pattern reveal would make the single-dot hint button close to worthless in this game, since one look replaces every individual hint. Charging a hint keeps the existing economy intact and gives players who bought hints more to do with them.

For the record, the two options not taken were: one free peek per level then charged, and a free unlimited peek that clears your current trace as its cost. Neither is being built.

### Implementation notes

- Set `_isMemorizing = true`, restart `_memorizeTimer` with the peek duration, and let the existing timer callback flip it back. Reuse the machinery — do not add a parallel "peek mode" flag with its own painter branch.
- **Cancel any in-flight `_memorizeTimer` first** (`_memorizeTimer?.cancel()`) or two overlapping timers will fight over `_isMemorizing`.
- `_onPanStart`, `_onPanUpdate` and `_onPanEnd` all early-return while `_isMemorizing` is true (`:435`, `:446`, `:466`), so input is already blocked during a peek. No extra guarding needed.
- **Keep the trace in progress.** The player paid a hint to check their memory, not to start over — clearing `_userPattern` on a paid peek would feel like a penalty on top of the cost.
- Place the button where the hint button already lives (`:795`) so the two forms of help sit together.
- Disable it while `_isSuccess` is true, exactly as the hint button does.
- Dispose / cancel timers in `dispose()` alongside the existing ones (`:144`).
- **Mirror the hint button's flow exactly:** check the balance first, disable the button when the player has none, call `HintManager.useHint('pattern_lock')`, then refresh the displayed count. Do not deduct until the peek actually happens.

---

## 4. What NOT to do

**4.1 — Do not change the pattern generator to allow jumps.** P1's fix depends on generated patterns never skipping a dot. If a later change lets the walk jump, auto-fill would start inserting dots the target does not contain and some levels would become impossible. If the generator ever needs to change, revisit P1 in the same breath.

**4.2 — Do not remove the `// not-a-modifier-gate` comments** at `:322` and `:372`. Those `>= 30` checks are difficulty maths, not modifier gates, and `verify_cogniq_fixes.sh` relies on the marker to skip them.

**4.3 — Do not fix group 5.1 or 2.2 from memory.** They are in the same file and should be done in the same pass, but their details live in `BACKPORT_PARTIAL_FIXES.md`. Read them there.

**4.4 — Do not change the hint system's per-dot behaviour** while implementing P2. The single-dot hint stays as it is; a peek is a second, separate form of help.

---

## 5. Verifying it

`verify_cogniq_fixes.sh` does not cover these — both are behavioural. **Test on a device, not the simulator:** a mouse is far more precise than a thumb, and P1 is specifically about imprecise input.

### P1

1. **Slow drag** along a row through three dots — all three register. *(This works today; confirm no regression.)*
2. **Fast flick** from the first dot to the last in a row — every dot in between is now collected.
3. **Wide arc** from one dot to another two apart, bowing outside the hit circles — the middle dot is still collected.
4. **Diagonal** across a 3×3 corner-to-corner — the centre dot is collected.
5. **Knight-shaped move**, two rows and one column — **nothing** is auto-inserted, because no dot lies on that line.
6. **Drag over an already-used dot** — it is not added twice and the pattern is not corrupted.
7. **Backtrack** over an auto-filled run and confirm it behaves the way you decided.
8. Play ten levels and clear them normally. **Auto-fill must never make a level unwinnable.**
9. Test at **level 30+** too, where diagonal steps are enabled.

### P2

1. Peek mid-trace. The pattern shows, input is blocked, and it hides again when the timer expires.
2. Peek **twice in quick succession** — no timer fight, no stuck-visible pattern.
3. Peek with **zero hints** — the button is disabled and nothing is deducted.
3b. Peek with **exactly one hint** — it works, the balance drops to zero, and the button then disables itself.
4. Peek, then leave the screen before the timer fires — no crash, no setState-after-dispose.
5. Peek on the **last level of a session**, clear it, and confirm the hint count shown afterwards is right.

### Both

```bash
flutter analyze          # must stay at 0 errors
./verify_cogniq_fixes.sh <version-root>    # unchanged from before these fixes
```

---

## 6. Propagating to bundles 62–68

Per `backport.md`: one branch per version, oldest first.

1. `diff -q` `pattern_lock_screen.dart` against the fixed 1.8 copy. **Identical → copy the fixed file wholesale.**
2. If it differs, apply by pattern, not by line number — **every line number in this document is 1.8 and will be wrong elsewhere.**
3. **Re-check the generator's adjacency rule** in that bundle (§2, "Why this is safe") before trusting auto-fill there.
4. `flutter analyze` — **0 errors**.
5. Re-run the P1 device tests on at least one later bundle, since `targetLength` and `_gridN` differ across the ladder.

---

## 7. Ground rules

- Work only inside `cogniq`. Do not touch `cinetracker`, `flow_grid`, `pulse`, `weather`.
- Never commit `android/app/upload-keystore.jks` or `android/key.properties`. If either lands in a commit the history must be **rewritten**, not patched over.
- Do not upgrade Flutter, Gradle, AGP or the JDK.
- Preserve every `// COGNIQ-FIX:` and `// not-a-modifier-gate` comment.
- Add a marker when you close each of these: `// COGNIQ-FIX:patternlock-autofill` for P1, `// COGNIQ-FIX:patternlock-peek` for P2. Then add them to the `NEWMARKERS` array in `verify_cogniq_fixes.sh` so the other seven bundles can be checked mechanically.
