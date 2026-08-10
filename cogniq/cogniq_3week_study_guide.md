# 🧠 CogniQ — 3 Week Self-Study Guide

> Open this at work. Follow one day at a time. 2-3 hours per day.
> By Day 21, you'll be confidently making changes on your own.

---

# WEEK 1 — Flutter Refresh + Core Architecture

> **Goal**: Refresh Dart/Flutter fundamentals using your own CogniQ code. Understand how the app boots, how screens connect, and read 3 simple games.

---

## Day 1 — StatefulWidget Lifecycle Refresh

### 💡 Concept: How StatefulWidgets Work

Every game screen in CogniQ is a `StatefulWidget`. Here's the lifecycle you need to remember:

```
Constructor → createState() → initState() → build() → [setState() → build()]* → dispose()
```

| Method | When It Runs | CogniQ Usage |
|---|---|---|
| `initState()` | Once, when widget is inserted into tree | Parse level arguments, pick modifiers, generate puzzle |
| `setState(() {...})` | You call it manually to trigger a rebuild | Update score, reveal/hide tiles, advance game state |
| `dispose()` | Once, when widget is removed from tree | Cancel timers, dispose animation controllers |
| `build()` | After every `setState` call | Render the game grid, overlays, buttons |

### 📖 See It In CogniQ

Open **`lib/screens/games/reaction/reaction_screen.dart`**

**initState** (sets up the game):
```dart
@override
void initState() {
  super.initState();
  _initLevel();  // parses arguments, sets up game state
}
```

**setState** (updates the screen when something changes):
```dart
setState(() {
  _phase = _Phase.go;       // changes background color
  _goTime = DateTime.now();  // records the timestamp
});
```

**dispose** (cleans up timers so they don't leak):
```dart
@override
void dispose() {
  _delayTimer?.cancel();  // MUST cancel or timer keeps firing after screen closes
  super.dispose();
}
```

> ⚠️ **Rule**: If you create a `Timer` or `AnimationController`, you MUST cancel/dispose it in `dispose()`. Forgetting this is the #1 source of bugs.

### ✅ Self-Check
- What happens if you call `setState` after `dispose` has run? *(Answer: crash — "setState called after dispose")*
- Why do we check `if (mounted)` before calling `setState` inside timer callbacks? *(Answer: the user might have navigated away before the timer fired)*

---

## Day 2 — Timers, SharedPreferences, and Navigator

### 💡 Concept: Timer & Timer.periodic

CogniQ uses timers for countdown modifiers, delayed reveals, and eclipse effects.

```dart
// One-shot timer: fires once after 2 seconds
Timer(Duration(seconds: 2), () {
  if (mounted) setState(() => _showResult = true);
});

// Repeating timer: fires every 1 second (like a countdown)
_gameTimer = Timer.periodic(Duration(seconds: 1), (timer) {
  if (mounted) {
    setState(() => _timeLeft--);
    if (_timeLeft <= 0) {
      timer.cancel();  // stop the timer
      _onTimeUp();
    }
  }
});

// Always cancel in dispose:
@override
void dispose() {
  _gameTimer?.cancel();
  super.dispose();
}
```

### 💡 Concept: SharedPreferences

CogniQ stores ALL data locally using key-value pairs. No backend server, no database.

```dart
// Save a value:
final prefs = await SharedPreferences.getInstance();
await prefs.setInt('level_chimp', 5);
await prefs.setBool('settings_sound', true);
await prefs.setString('daily_v2_last_date', '2026-08-10');

// Read a value (with fallback):
int level = prefs.getInt('level_chimp') ?? 1;  // returns 1 if key doesn't exist
bool sound = prefs.getBool('settings_sound') ?? true;
```

### 📖 See It In CogniQ

Open **`lib/utils/prefs_keys.dart`** — all keys are defined here as constants to prevent typos:
```dart
static String gameLevel(String gameId) => 'level_$gameId';
static String gameHints(String gameId) => 'hints_$gameId';
static String clearedCount(String gameId) => 'cleared_count_$gameId';
```
So `PrefsKeys.gameLevel('chimp')` returns the string `'level_chimp'`.

### 💡 Concept: Named Route Navigation

CogniQ uses the simplest navigation pattern — named routes with arguments:

```dart
// Navigate TO a game (passing the level number):
Navigator.pushNamed(context, '/chimp', arguments: {'level': 3});

// Inside the game screen, READ the arguments:
final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
final level = args['level'] as int;

// Navigate BACK:
Navigator.pop(context);

// Replace current screen (used by splash → home, so user can't go back to splash):
Navigator.pushReplacementNamed(context, '/home');
```

### 📖 See It In CogniQ

Open **`lib/main.dart`** lines 192-228 — this is the complete route registry:
```dart
routes: {
  '/': (ctx) => const SplashScreen(),
  '/home': (ctx) => const HomeScreen(),
  '/chimp': (ctx) => const ChimpTestScreen(),
  '/sudoku': (ctx) => const SudokuScreen(),
  '/oddcolor': (ctx) => const OddColorOutScreen(),
  // ... 25+ more
},
```

### ✅ Self-Check
- What's the difference between `Navigator.pushNamed` and `Navigator.pushReplacementNamed`? *(Answer: replacement removes the current screen from the stack, so back button won't return to it)*
- If `prefs.getInt('level_chimp')` returns `null`, what does `?? 1` do? *(Answer: uses 1 as the default value)*

---

## Day 3 — App Boot Sequence & Dart 3 Records

### 📖 Read: `lib/main.dart` (all 234 lines)

Follow the boot sequence step by step:

**Step 1 — `main()` function (line 59):**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();  // Required before any async work
```

**Step 2 — Device setup (lines 61-95):**
- `FlutterDisplayMode.setHighRefreshRate()` → forces 90Hz/120Hz on Android
- `AdManager.initialize()` → loads ad SDK
- `PurchaseManager.initialize()` → connects to Play Store / App Store
- `NotificationManager.initialize()` → sets up push notifications
- `AudioManager.init()` → preloads sound effects
- `SystemChrome.setPreferredOrientations([portraitUp, portraitDown])` → locks portrait

**Step 3 — Crash recovery (lines 97-110):**
```dart
final activeGame = prefs.getString(PrefsKeys.dailyBackupActiveGame);
if (activeGame != null && activeGame.isNotEmpty) {
  // Restore level if app crashed during a daily challenge
  final backupLevel = prefs.getInt(PrefsKeys.dailyBackupGame(activeGame));
  if (backupLevel != null) {
    await prefs.setInt(PrefsKeys.gameLevel(activeGame), backupLevel);
  }
  // Clean up backup flags
}
```

**Step 4 — `runApp(const CogniQApp())` (line 118):**
- Creates the `MaterialApp`
- Sets theme (light + dark), font (`Outfit`), and routes
- Wraps everything in `SwipeTrailOverlay` (the finger trail cosmetic)

### 💡 Concept: Dart 3 Records

You'll see this syntax everywhere in CogniQ grid games:
```dart
// This is a "Record" — basically a lightweight tuple
(int, int) position = (3, 5);  // row 3, column 5

// Access fields with .$1 and .$2
int row = position.$1;  // 3
int col = position.$2;  // 5

// Used in maps:
Map<int, (int, int)> _positions = {
  1: (0, 2),  // number 1 is at row 0, column 2
  2: (1, 3),  // number 2 is at row 1, column 3
};

// Set of positions:
Set<(int, int)> _glowingCells = {(0, 2), (1, 3)};

// Scale map — maps level to (gridSize, numCount):
static const List<(int, int)> _levels = [
  (3, 4),   // level 1: 3x3 grid, 4 numbers
  (3, 5),   // level 2: 3x3 grid, 5 numbers
  (4, 7),   // level 3: 4x4 grid, 7 numbers
];
```

### ✅ Self-Check
- In `main.dart`, what method checks for app updates after the first frame renders? *(Answer: `UpdateManager.checkForUpdate()` inside `addPostFrameCallback`)*
- If `_levels[0]` is `(3, 4)`, what does `_levels[0].$2` return? *(Answer: 4)*

---

## Day 4 — Your First Game: Reaction Screen

### 📖 Read: `lib/screens/games/reaction/reaction_screen.dart` (487 lines)

This is the **simplest game in CogniQ**. No grid, no puzzle generation — just a timed tap.

**How the game works:**
1. Screen is amber — "Tap to start"
2. After a random delay (1.5 to 4 seconds), screen turns green — "TAP!"
3. Player taps. Reaction time is measured using `DateTime.now().difference(_goTime!).inMilliseconds`
4. After 5 rounds, average is calculated. If below target → win.

**Key state machine** — the game cycles through phases:
```dart
enum _Phase { waiting, ready, tooEarly, go, result }
```

**What to look for in the code:**

| Line Range | What It Does |
|---|---|
| Lines 30-46 | State variables: `_phase`, `_reactionMs`, `_results`, `_round` |
| Lines 48-51 | `initState()` → calls `_initLevel()` |
| Lines 53-57 | `dispose()` → cancels `_delayTimer` |
| Lines 136-180 | `_startRound()` → random delay → phase change to `go` |
| Lines 183-250 | `_onTap()` → measures time or records penalty |
| Line 110 | Win check: `if (_round >= 5)` → average all 5 results |

**Daily mode distractor** (lines 147-172):
In daily challenge mode, there's a 50% chance of a fake "GO!" screen in red or blue. If the player taps it, they get a **+1500ms penalty** added to their results.

### 🔬 Practice
- Find `_bgColor()`. Map each `_Phase` to its screen color.
- Find where `AudioManager.playSuccess()` is called. What conditions must be true?

---

## Day 5 — Grid Game Pattern: Chimp Test (Patches Screen)

### 📖 Read: `lib/screens/games/patches/patches_screen.dart` (898 lines)

This is your **first grid game**. It introduces coordinate systems, sequential tapping, and the modifier system.

**How the game works:**
1. Numbers 1 through N appear on a grid
2. Player taps number 1 → all numbers hide
3. Player must tap the remaining positions in order (2, 3, 4...) from memory
4. Grid size and number count increase with level

**Key code blocks to read:**

| What | Where | Pattern |
|---|---|---|
| Level config | Lines 29-37 | `_levels` list: `(gridSize, numCount)` records |
| State variables | Lines 39-96 | `_gridSize`, `_n`, `_positions`, `_nextToTap`, `_won`, `_failed` |
| Modifier selection | Lines 206-213 | `RotationEngine.getActiveModifiers(gameId: 'chimp', pool: [...])` |
| Position generation | `_randomPositions()` | Picks unique `(row, col)` coordinates for each number |
| Tap handler | Lines 400-480 | `_onCellTap(r, c)` → checks sequence order |
| Win condition | Line 448 | `if (_nextToTap > _n)` → all numbers found → win |

**The tap sequence logic (simplified):**
```dart
void _onCellTap(int r, int c) {
  final num = _numberAt(r, c);  // what number is at this cell?
  
  if (num == null) {
    _failed = true;  // tapped empty cell after game started
    return;
  }
  
  if (!_started && num == 1) {
    _started = true;     // first tap on 1 → hide all numbers
    _nextToTap = 2;
    return;
  }
  
  if (num == _nextToTap) {
    _nextToTap++;        // correct! advance to next number
    if (_nextToTap > _n) {
      _won = true;       // all numbers found → level complete
    }
  } else {
    _failed = true;      // wrong number → game over
  }
}
```

### 🔬 Practice
- Find the `_levels` list. What grid size and number count does level 1 have? *(Answer: (3,4) — 3×3 grid, 4 numbers)* What about level 30? *(Answer: (9,60) — 9×9 grid, 60 numbers)*
- Find `_applyDailyPositionModifier()`. What does the `chaos` modifier do after 3 correct taps? *(Answer: shuffles all remaining untapped numbers to random positions)*

---

## Day 6 — RotationEngine: The Modifier Picker

### 📖 Read: `lib/utils/rotation_engine.dart` (59 lines — read the whole thing)

This tiny file is the engine behind all game variation. It does 3 things:

### 6.1 Deterministic Random Seeds
```dart
static Random getDeterminism(String gameId, int levelIndex) {
  final seed = _stableHash(gameId) ^ (levelIndex * 2654435761 & 0x7fffffff);
  return Random(seed);
}
```
**Why it matters**: Same game + same level = same puzzle EVERY time. If you play Chimp Test level 5, you always get the same number positions.

### 6.2 Difficulty Decay
```dart
static double getDecayValue({level, start, floor, rate}) {
  return floor + (start - floor) * (rate / (rate + level));
}
```
Returns a value that starts high and gradually approaches `floor`. Used for shrinking time limits and color differences.

### 6.3 Modifier Selection
```dart
static Set<String> getActiveModifiers({gameId, levelIndex, pool, minActive, maxActive, smallGrid}) {
  if (pool.isEmpty) return {};
  final rand = getDeterminism(gameId, levelIndex);
  final count = smallGrid ? maxActive : (minActive + rand.nextInt(maxActive - minActive + 1));
  final poolCopy = List<String>.from(pool)..shuffle(rand);
  return poolCopy.take(count).toSet();
}
```
Shuffles the pool with a seeded random, picks `count` modifiers. Same level = same modifiers every time.

### ✅ Self-Check
- If `pool` is empty, what does `getActiveModifiers` return? *(Answer: empty set `{}`)*
- If `smallGrid` is true, does it pick `minActive` or `maxActive`? *(Answer: `maxActive`)*
- Why seeded `Random` instead of `Random()`? *(Answer: replaying a level gives the same puzzle)*

---

## Day 7 — HintManager, Theme System & Week 1 Review

### 📖 Read: `lib/utils/hint_manager.dart` (144 lines — read the whole thing)

**`startLevel(gameId)`** — called when a level loads:
- Resets `_hintUsedThisLevel` flag
- If previous level was failed, resets achievement clear streak

**`onLevelCleared(gameId)`** — called when player wins:
- Awards **10 points**
- Increments game + global clear counts
- Shows **interstitial ad every 20 clears**
- Triggers **trail unlock toasts** at 30 / 100 / 250 global clears
- Checks and unlocks **achievements**

### 📖 Read: `lib/theme/app_theme.dart` (208 lines)

| Feature | How to Use |
|---|---|
| Dark mode check | `context.isDarkMode` |
| Adaptive background | `context.bgDark`, `context.bgCard` |
| Adaptive text | `context.textPrimary`, `context.textMuted` |
| Font scaling | `context.scale(16)` — scales relative to 375px base |
| Game accent color | `AppTheme.accentFor('chimp')` → returns `terracotta` |
| Number font | `AppTheme.numberStyle(fontSize: 20)` → Space Grotesk |

### 🏆 Week 1 Review

| ✅ Concept | Day |
|---|---|
| StatefulWidget lifecycle | 1 |
| Timer, SharedPreferences, Navigator | 2 |
| App boot sequence, Dart 3 Records | 3 |
| Simple game template (Reaction) | 4 |
| Grid game + tap sequence (Chimp Test) | 5 |
| RotationEngine (seeds, decay, modifiers) | 6 |
| HintManager hooks, Theme system | 7 |

---
---

# WEEK 2 — Modifier System + Daily Challenges + Complex Games

> **Goal**: Master the modifier system, understand daily challenges, and read medium-to-complex games.

---

## Day 8 — The Modifier System Deep Dive

### 💡 How Modifiers Flow Through the Code

```
1. Game defines pool          2. RotationEngine picks        3. Game applies effects
─────────────────────    →    ──────────────────────    →    ─────────────────────

pool = ['timer', 'fog',      active = {'timer', 'fog'}      if active.contains('timer'):
  'eclipse', 'mirror',                                         start countdown
  'shuffle']                                                 if active.contains('fog'):
                                                                wrap grid in FogOverlay
```

### Common Modifiers

| Modifier | What It Does | Implementation |
|---|---|---|
| `timer` | Countdown, game over at 0 | `Timer.periodic(1s)` + `_timeLeft--` |
| `fog` | Dark overlay, reveals near touch | `FogOverlay(enabled: true, child: grid)` |
| `eclipse` | Grid blacks out periodically | `Timer.periodic`, toggles `_isShadowed` |
| `glitch` | Numbers turn to symbols briefly | `Timer.periodic(500ms)`, toggles `_glitchTick` |
| `shuffle` | Tiles rearrange after N taps | Re-shuffle position map |
| `gravity` | Tiles sink down after each tap | Recalculate coordinates |
| `noise` | Random color perturbation | Random offsets in calculations |
| `whisper` | Differences extremely subtle | Reduce delta parameter |

### 📖 Read: `lib/widgets/fog_overlay.dart` (full file)

How it works:
- Wraps child widget in `Stack`
- `Listener` tracks finger position
- `CustomPainter` draws dark overlay with spotlight cutout at finger position
- `shouldRepaint` checks if position/radius changed

**Usage in games:**
```dart
FogOverlay(
  enabled: _activeModifiers.contains('fog'),
  radius: 80.0,
  child: _buildGameGrid(),
)
```

### 🔬 Practice
- Open `patches_screen.dart`. Find the modifier pool (line 209). List all 6 strings.
- Find where `_glitchTimer` is started and where it's cancelled in `dispose()`.

---

## Day 9 — Modifier Showcase: Odd Color Out

### 📖 Read: `lib/screens/games/odd_color_out/odd_color_out_screen.dart` (1,024 lines)

> ⚠️ **Do NOT read top to bottom.** Search for each modifier name instead.

This game has **10 modifiers**. Search and understand each:

| Search For | Effect |
|---|---|
| `'hueChannel'` | Shifts odd tile on hue axis instead of lightness |
| `'noise'` | Random lightness jitter per tile |
| `'gradient'` | Diagonal lightness gradient across grid |
| `'monochrome'` | Grayscale only |
| `'whisper'` | Color difference nearly invisible (0.015) |
| `'eclipse'` | Periodic grid blackout |
| `'fog'` | FogOverlay wrapped around grid |
| `'retro'` | Pixelated styling |
| `'prism'` | Dual complementary color regions |
| `'timer'` | Countdown with game-over |

**Grid scaling:**
```
Level 1-2:   2×2        Level 16-22: 6×6
Level 3-4:   3×3        Level 23-29: 7×7
Level 5-9:   4×4        Level 30-89: 9×9
Level 10-15: 5×5        Level 90+:   rotates 5-9
```

---

## Day 10 — Daily Challenge System

### 📖 Read: `lib/utils/daily_challenge_manager.dart` (1,386 lines)

> ⚠️ **Do NOT read top to bottom.** Search in this order:

1. Search `_kDailyChallengesPlan` → 30-entry theme rotation (Fog Day, Mirror Day, etc.)
2. Search `getActiveDay` → which day of the 98-day cycle
3. Search `getChallengesForDay` → 3 slots: Easy, Medium, Hard
4. Search `markSlotCompleted` → star awards and streak updates

### Normal vs Daily Mode

| | Normal | Daily |
|---|---|---|
| Level source | SharedPreferences | Fixed by daily config |
| Modifiers | RotationEngine | Forced by theme |
| On win | Save level + 1 | Pop back to daily screen |
| Random seed | Seeded (deterministic) | `Random()` (fresh) |
| Level save | Yes | No |

### 📖 Also read: `lib/screens/daily_screen.dart` (1,064 lines)
Look for how challenge cards are rendered and how tapping launches a game with daily flags.

---

## Day 11 — Game Completion Flow

### 📖 Read these 3 widget files:

**`lib/widgets/loss_overlay.dart`** — Game Over:
- Red flash animation on init
- "Try Again" button → game resets
- Calls `AchievementManager.resetClearStreak()` immediately

**`lib/widgets/challenge_cleared_overlay.dart`** — Daily Win:
- Confetti + countdown
- Pops back to daily screen after 5 seconds

**`lib/widgets/auto_next_countdown.dart`** — Normal Win:
- 3-second countdown, auto-advances to next level
- Tap to skip

### The Complete Flow
```
Normal win:  → save level+1 → HintManager.onLevelCleared → AutoNextCountdown → next level
Daily win:   → markSlotCompleted → ChallengeClearedOverlay → pop to DailyScreen
Any loss:    → LossOverlay → resetClearStreak → "Try Again" → reload same level
```

---

## Day 12 — Word Game Pattern

### 📖 Read: `lib/screens/games/word_builder/word_builder_screen.dart` (first 100 lines)

Word games = standard template + companion word list file:
```dart
import 'word_builder_words.dart';  // massive data file
```

All word games follow this pattern:

| Game | Word List File |
|---|---|
| Word Builder | `word_builder_words.dart` |
| Word Guess | `word_guess_dictionary.dart` |
| Word Hive | `word_hive_words.dart` |
| Word Climb | `word_climb_words.dart` |
| Word Ladder | `word_ladder_words.dart` |

The word list is pure data. The screen uses it for letter selection and answer validation.

---

## Day 13 — Home Screen & Settings

### 📖 Skim: `lib/screens/home_screen.dart` (2,573 lines)

> **Do NOT read it all.** Use search:

| Search For | What You'll Find |
|---|---|
| `pushNamed` | How games launch |
| `kGameColors` | Game card colors |
| `category` | Category filtering |
| `RecentlyPlayed` | Recently played bar |
| `ShuffleManager` | Game order randomization |

### 📖 Read: `lib/screens/settings_screen.dart` (366 lines)
Look for dark mode toggle, sound toggles, font scale slider.

---

## Day 14 — Achievements, Purchases & Week 2 Review

### 📖 Read: `lib/utils/achievement_manager.dart` (527 lines)
Search for `checkAndUnlock` — checks clear streaks, no-hint clears, milestones.

### 📖 Read: `lib/utils/purchase_manager.dart` (264 lines)
Standard IAP flow: hint packs, ad removal, premium, restore.

### 🏆 Week 2 Review

| ✅ Concept | Day |
|---|---|
| Modifier system architecture | 8 |
| All modifier types (Odd Color Out) | 9 |
| Daily challenge system | 10 |
| Win/Loss completion flow | 11 |
| Word game pattern | 12 |
| Home screen, Settings | 13 |
| Achievements, Purchases | 14 |

---
---

# WEEK 3 — Solver Games + Widgets + Hands-On Coding

> **Goal**: Skim remaining game types, learn all shared widgets, and make real code changes.

---

## Day 15 — Solver-Based Games (Skim Only)

### 📖 Skim first 80 lines of each:

- `lib/screens/games/bridges/bridges_screen.dart` + `bridges_levels.dart`
- `lib/screens/games/masyu/masyu_screen.dart` + `masyu_levels.dart`
- `lib/screens/games/slitherlink/slitherlink_screen.dart`
- `lib/screens/games/sudoku/sudoku_screen.dart` (2,567 lines — just first 80)

**Key insight**: Solvers are only used during puzzle generation to verify unique solutions. You call `solver.solve(puzzle)` and get a result. You never need to understand the algorithm to modify UI or add modifiers.

All solver games follow the exact same template as every other game.

---

## Day 16 — All Shared Widgets Catalog

### Read each to know what's available:

| Widget File | Purpose |
|---|---|
| `fog_overlay.dart` | Touch-reveal spotlight *(read Day 8)* |
| `swipe_trail_overlay.dart` | Cosmetic finger trail |
| `loss_overlay.dart` | Game Over *(read Day 11)* |
| `challenge_cleared_overlay.dart` | Daily win *(read Day 11)* |
| `confetti_overlay.dart` | Celebration particles |
| `buy_hints_dialog.dart` | Hint purchase flow |
| `points_store_dialog.dart` | Point store |
| `game_tutorial_dialog.dart` | First-time tutorial |
| `interactive_tutorial_overlay.dart` | Step-by-step tutorial |
| `auto_next_countdown.dart` | Auto-advance *(read Day 11)* |
| `animated_level_indicator.dart` | Level progress |
| `achievement_toast.dart` | Achievement popup |
| `trail_unlock_toast.dart` | Trail unlock notification |

### 🔬 Practice
- Search `LossOverlay(` across codebase. Find 3 games using it.
- Search `GameTutorialDialog`. How does a game decide to show it? *(Answer: checks `PrefsKeys.hasSeenTutorial(gameId)`)*

---

## Day 17 — Remaining Utilities & Performance Rules

### Quick-read these files:

| File | Lines | Purpose |
|---|---|---|
| `point_manager.dart` | ~26 | Add/spend points |
| `audio_manager.dart` | ~37 | Sound effects + music |
| `activity_tracker.dart` | ~51 | Active days tracking |
| `shuffle_manager.dart` | ~149 | Game order randomization |
| `notification_manager.dart` | ~371 | Daily reminders |
| `ad_manager_mobile.dart` | ~178 | Banner + interstitial + rewarded ads |

### 📖 Read: `remember.md` (project root) — Performance Rules

| Rule | Why |
|---|---|
| No `setState` in `onPanUpdate` | Causes 60-120fps full rebuilds |
| Use `ValueNotifier` for high-freq updates | Only rebuilds specific widget |
| Wrap dynamic areas in `RepaintBoundary` | Prevents static UI repaints |
| Implement `shouldRepaint` properly | Avoids redundant paints |
| Use `Set` for lookups in paint loops | O(1) vs O(n) |
| Defer SharedPreferences to `onPanEnd` | Disk I/O causes jank |

---

## Day 18 — Hands-On: Trivial Changes ⭐

**Exercise 1 (15 min):** Open `app_theme.dart`. Change `terracotta` color to `Color(0xFF2196F3)`. Hot reload. See Chimp Test card change. Revert.

**Exercise 2 (15 min):** Open `reaction_screen.dart`. Find the "too early" text. Change it. Hot reload. Trigger it. Revert.

**Exercise 3 (30 min):** Trace `reaction_screen.dart` call chain on paper:
```
initState → _initLevel → _loadPersistedLevel → _loadLevel → _startRound
```
Now trace what happens on a tap: `_onTap → ??? → ???`

---

## Day 19 — Hands-On: Read an Unfamiliar Game ⭐⭐⭐

Pick a game you haven't read. Suggestions: `spectrum_screen.dart`, `mine_finder_screen.dart`, `kakuro_screen.dart`

**Within 30 minutes, find these 5 things:**
- [ ] The modifier pool
- [ ] The scale/level config
- [ ] The puzzle generation method
- [ ] The win condition
- [ ] Daily challenge integration (`_playDailyMode`)

---

## Day 20 — Hands-On: Add a Modifier ⭐⭐⭐⭐

1. Open `patches_screen.dart`
2. Find the pool: `['numbersHide', 'spatialSpread', 'positionShuffle', 'timer', 'glitch', 'gravity']`
3. Add `'flash'` to the pool
4. Add: `bool get _hasFlash => _activeModifiers.contains('flash');`
5. In `build()`, add a visual effect when `_hasFlash` is true
6. Test by forcing: `_activeModifiers = {'flash'};`
7. Revert when done

---

## Day 21 — Graduation Test 🎓

Open **any game you haven't read.** Find all of these within 15 minutes:

- [ ] Modifier pool
- [ ] Level configuration
- [ ] Puzzle generation
- [ ] Win condition
- [ ] Daily challenge integration
- [ ] Timer cancellation in `dispose()`
- [ ] `HintManager.onLevelCleared` call

**If yes → you own this codebase.** 🎯

---

## 📋 Quick Reference Card

### The Universal Game Lifecycle
```
initState → _loadPersistedLevel → _loadLevel → RotationEngine → _generate → build
                                                                      ↓
                                               _onCellTap → win → save level
                                                          → loss → show overlay
                                                                      ↓
                                                                   dispose (cancel timers)
```

### Key Files
```
main.dart                    → Boot + routes (234 lines)
rotation_engine.dart         → Random + modifiers (59 lines)
hint_manager.dart            → Level hooks (144 lines)
prefs_keys.dart              → Storage keys (135 lines)
app_theme.dart               → Colors + responsive (208 lines)
daily_challenge_manager.dart → Daily system (1,386 lines)
```

### SharedPreferences Keys
```dart
PrefsKeys.gameLevel('chimp')         → 'level_chimp'
PrefsKeys.gameHints('sudoku')        → 'hints_sudoku'
PrefsKeys.clearedCount('bridges')    → 'cleared_count_bridges'
PrefsKeys.hasSeenTutorial('queens')  → 'has_seen_tutorial_queens'
```

---

> **You built this app. The patterns are yours. It'll click faster than you expect.** 💪
