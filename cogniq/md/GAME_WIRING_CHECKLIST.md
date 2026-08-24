# CogniQ — new game wiring checklist

**Status: VERIFIED HANDBOOK.**
Use this checklist when creating a new game screen or refactoring an old one.

Two blanks per step:
- **Why** — one line. What breaks conceptually without it.
- **Symptom if missed** — one line, phrased as something you'd *observe*.

---

## Before starting

Game ID: `exam_game`
Screen file: `lib/screens/games/practice/practice_screen.dart`

> ⚠️ **`practice_screen.dart` is KEPT deliberately.** It is the owner's practice scaffold
> and this checklist's runnable reference — "Sim win", "Sim lose" and "Use Hint" buttons
> demonstrating the prefs / hint / rotation-engine / loss-overlay wiring. It looks like dead
> code (routed in `main.dart`, absent from `kAllGames`, nothing navigates to it) and was
> proposed for deletion in the 2.3 cull. **Owner decision 2026-08-23: keep it.** If you ever
> do remove it, update this file first — three sections here point at it by name.
Route name: `/practice`

---

## 🏗️ Architectural Blueprints (Method Layouts)

Follow these structural skeletons to know exactly where each checklist item goes:

### 1. The Initialization Skeleton
```dart
@override
void initState() {
  super.initState();
  _initState(); // calls async loader, NOT awaited (Step 4)
}

Future<void> _initState() async {
  // Prerequisite: Define local pool list
  final pool = ['timer', 'fog', ...];

  // Step 3 Prerequisite: Await SharedPreferences first (prevents context crash)
  _prefs = await SharedPreferences.getInstance();

  // Step 3: Read arguments (checks for daily mode or custom levels)
  final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

  // Step 5: Load level (check args first, fallback to disk)
  if (args != null && args.containsKey('level')) {
    level = args['level'] as int;
  } else {
    level = _prefs!.getInt(PrefsKeys.gameLevel(gameId)) ?? 1;
  }

  // Step 7: Get active modifiers
  _activeModifiers = RotationEngine.getActiveModifiers(
    gameId: gameId,
    levelIndex: level,
    pool: pool,
  );

  // Step 6: Load and reset hints
  int h = await HintManager.startLevel(gameId);

  // Step 8: Generate your puzzle board here
  _generateBoard();

  // Step 9: Notify UI on mount
  if (mounted) {
    setState(() {
      hints = h;
    });
  }
}
```

### 2. The Hint Usage Skeleton
```dart
Future<void> _useHint() async {
  // Step 14: Check bounds before modifying
  if (hints > 0 && !hintUsed) {
    setState(() {
      hints--;
      hintUsed = true;
    });
    // Persist subtraction to storage
    await HintManager.useHint(gameId);
    
    // Highlight next expected number on the screen
    _showVisualHint(); 
  }
}
```

### 3. The Win/Clear Click Skeleton
```dart
Future<void> _onLevelCleared() async {
  // ⚠️ Mutate state first, then save, then notify Manager
  setState(() {
    isSuccess = true;
    hintUsed = false;
  });
  
  // Step 10: Save level (optional if AutoNext handles the save, but do it here or in onNext)
  await _onClick(); 
  
  // Step 11: Notify cleared manager (runs points, streaks, achievements)
  await HintManager.onLevelCleared(gameId);
}
```

### 4. The AutoNext Completed Skeleton
```dart
// AutoNextCountdown onNext/onComplete callback:
onNext: () async {
  // ⚠️ Must mutate state FIRST, then write to disk, then read/reload
  setState(() {
    isSuccess = false;
    level++;
    hintUsed = false;
  });

  await _onClick();   // Write: Saves the new level to disk
  await _initState(); // Read: Reloads screen config, modifiers & hints
}
```

---

## Setup

**1. Create the screen file**
- Action: Create `lib/screens/games/<game_name>/<game_name>_screen.dart` using `StatefulWidget`.
- Why: Houses the game class and state.
- Symptom if missed: App won't compile (missing reference).

**2. Register the route in `lib/main.dart`**
- Action: Add the route mapping under `routes: { ... }` in `MaterialApp`.
- Why: Links the string path (e.g. `'/practice'`) to the screen constructor.
- Symptom if missed: Navigation crash when opening the game ("Route not found").
- ⚠️ Order-dependent: nothing can navigate here until this exists.

**3. Read navigation arguments**
- Action:
  ```dart
  final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
  ```
- Why: Retrieves level information or daily modifiers passed during navigation.
- Symptom if missed: Daily challenge settings/specific levels aren't loaded.
- ⚠️ **CRITICAL GOTCHA**: `ModalRoute.of(context)` cannot run synchronously inside the `initState()` lifecycle execution. To prevent a `dependOnInheritedWidgetOfExactType` context crash, you **must** place your first `await` statement (e.g. `_prefs = await SharedPreferences.getInstance();`) on the **very first line** of your `_initState()` method to yield execution before reading arguments.

**3b. Register the game in BOTH test harnesses — same change, not "later"**
- Action: add the game to
  - `test/all_games_all_levels_test.dart` (import + entry in the games map), and
  - `test/layout_overflow_test.dart` (import + entry in the `screens` map).
- Why: the first boots every level of the curve; the second checks four viewports for
  `RenderFlex` overflow. Neither can protect a game that is not listed in it.
- Symptom if missed: **nothing.** Both suites stay green. That is precisely the problem.

> 🔴 **This step was skipped in 1.9, 2.0 and 2.1 — six games in a row.** Kakuro, Sand Sort,
> Light Beam, Hitori, Zen Slide and Slitherlink were all absent from
> `layout_overflow_test.dart` until 2026-08-22.
>
> The cost was real. **Hitori** — the game whose 908px overflow is the entire reason that
> file matters — was fixed in 2.0 and never given a regression test, so it kept a **second**
> overflow (106px at 320×568) that shipped in 2.0 *and* 2.1. Adding the six games surfaced
> it within seconds.
>
> A missing test never goes red. Add the game the same day you add the route.

**3c. Add the accent colour**
- Action: `case '<gameId>': return <AppTheme colour>;` in `AppTheme.accentFor`.
- Why: `GameLevelChip` and every chip on the screen take their colour from here.
- Symptom if missed: the game falls back to a default accent and looks like a different app.

---

---

## Load side (`initState` → `_initLevel`)

**4. `initState` calls `_initState()`, not awaited**
- Why: `initState` is a synchronous framework lifecycle method and cannot return a `Future`.
- Symptom if missed: Compilation error if marked `async`, or app fails to boot.

**5. Load saved level**
- Action:
  ```dart
  level = _prefs!.getInt(PrefsKeys.gameLevel(gameId)) ?? 1;
  ```
- Why: Resumes the player's saved progression.
- Symptom if missed: Every game starts at level 1.
- ⚠️ **CRITICAL GOTCHA**: SharedPreferences returns a nullable type (`int?`). You **must** supply a default fallback value using the `??` operator (e.g., `?? 1`) to prevent a null-assign compilation error.

**6. Load hint count**
- Action:
  ```dart
  hints = await HintManager.startLevel(gameId);
  ```
- Why: Resets the "no hint used" tracker for the session, evaluates win streaks, and returns current hints.
- Symptom if missed: Clear streaks fail to reset on loss, and no-hint achievements break.
- ⚠️ The returned integer must be **captured and saved**, not just awaited.

**7. Get active modifiers**
- Action:
  ```dart
  _activeModifiers = RotationEngine.getActiveModifiers(
    gameId: gameId,
    levelIndex: level,
    pool: pool,
  );
  ```
- Why: Selects the difficulty modifiers for this level deterministically.
- Symptom if missed: Modifiers are random or missing.
- ⚠️ Do **not** use `getDecayValue` — it is dead code in the repository.
- ⚠️ Ensure you pass variables as **named arguments** to match the signature.

**8. Generate the puzzle**
- Action: Call your board/puzzle generation method using the loaded level.
- Why: Creates the interactive layout for the game.
- Symptom if missed: Blank screen or previous board layout is retained.

**9. `if (mounted) setState(...)`**
- Why: Forces the screen to rebuild with the loaded data, but guards against calling it on a closed state.
- Symptom if missed: Screen remains blank/unloaded, or crashes if exited mid-load.
- ⚠️ Batch your assignments first, then call a single `setState` at the end of the load cycle.

---

## Win path

**10. Save `level + 1`**
- Action:
  ```dart
  await _prefs!.setInt(PrefsKeys.gameLevel(gameId), level);
  ```
- Why: Commits the player's progression to disk.
- Symptom if missed: Progression is lost on app restart.

**11. `HintManager.onLevelCleared(gameId)`**
- Why: Triggers ~10 points, clears counts, ad loops, and achievement unlocks behind one call.
- Symptom if missed: Users earn no points, streaks don't update, and achievements never unlock.
- ⚠️ Call this exactly once per win. Do not evaluate its return type (it is a dummy `Future<bool>`).

**12. AutoNextCountdown**
- Action: Instantiated inside the Stack when the win state is triggered.
- Why: Provides a visual 3-second auto-advance countdown.
- Symptom if missed: Level does not advance automatically.
- ⚠️ **CRITICAL GOTCHA (Layout)**: `AutoNextCountdown` is a small horizontal banner. You **must** wrap it in a `Center()` or a `Positioned()` widget inside a `Stack` to prevent it from overlapping widgets in the top-left corner.
- ⚠️ **CRITICAL GOTCHA (Execution Order)**: In your `onNext` callback, you **must** execute operations in this exact order:
  1. Update local variables inside `setState` (`level++`, `isSuccess = false`).
  2. Await your write callback (`await _onClick()`) to save to disk.
  3. Await your read/init callback (`await _initState()`) to reload modifiers.
  *Reversing this order will cause the read to overwrite your local increment before it is saved.*

---

## Loss path

**13. LossOverlay**
- Action: Instantiated inside the Stack when the loss state is triggered.
- Why: Displays game-over card with a retry button.
- Symptom if missed: Failures are unhandled, and streaks don't reset.
- ⚠️ Pass `onTryAgain` to reset state variables and clear the overlay.

---

## Hints

**14. Hint button → `HintManager.useHint(...)`**
- Why: Consumes a hint and sets the internal "hint was used" flag.
- Symptom if missed: Hints are free/infinite, and streak checks bypass the hint penalty.
- ⚠️ Ensure you only decrement and set the flag if the user actually has hints left (`hints > 0`).

---

## Teardown

**15. `dispose`: cancel every timer**
- Action: Cancel all `Timer` or `Timer.periodic` instances and call `super.dispose()`.
- Why: Releases memory resources.
- Symptom if missed: Memory leaks, phantom background executions, and crashes.

---

## Verification — hot-restart and observe

- [ ] Clear a level, hot-restart → resumes at the new level?
- [ ] Use a hint, clear the level → registers as hint-assisted?
- [ ] Clear a level → points increase?
- [ ] Play a small grid → modifiers appear?
- [ ] Navigate in from home → arguments arrive intact?
- [ ] Leave the screen mid-load → no `setState` after dispose error?

---

## Gotchas found while wiring

- **Browser Routing on Web:** Changing `initialRoute` in `main.dart` may be overridden by the web browser URL path. You must manually enter the path (e.g. `/#/practice`) in the browser URL bar to test the page directly.
- **Async Execution sequence:** Do not mix up the order of disk read/write calls inside state change triggers. Database writes must always precede database reads.
- **Navigator context inside root:** `navigatorKey.currentContext` can throw if `Navigator.of()` is called on it before the navigation overlay has fully mounted.
