# CogniQ — Developer Onboarding Guide

> **Version**: 1.8.0+48 · **SDK**: Dart 3.10+ / Flutter · **Architecture**: Pure `setState` + `SharedPreferences`
> **Last updated**: August 2026

---

## 1. What is CogniQ?

CogniQ is a mobile puzzle & brain training app containing **25+ distinct games** across categories: Logic, Word, Memory, and Perception. It features:

- **Progressive difficulty** with deterministic level generation
- **A modifier system** that layers gameplay effects (fog, timer, eclipse, shuffle, etc.)
- **Daily Challenges** with streak tracking and star rewards
- **Achievements, Hints, Points, and Swipe Trail cosmetics**
- **Monetization** via AdMob ads and In-App Purchases

---

## 2. Tech Stack

| Layer | Technology | Notes |
|---|---|---|
| **Framework** | Flutter (Dart 3.10+) | Single codebase, primarily targeting Android/iOS |
| **State Management** | `setState` | No BLoC, Riverpod, or Provider. Every game screen is a self-contained `StatefulWidget` |
| **Persistence** | `SharedPreferences` | All game progress, settings, streaks, and purchases stored as key-value pairs |
| **Navigation** | Named Routes | `MaterialApp.routes` map. Arguments passed via `ModalRoute.of(context)!.settings.arguments` |
| **Fonts** | Google Fonts (`Outfit`, `Space Grotesk`) | `Outfit` for UI text, `Space Grotesk` for numbers |
| **Animations** | `flutter_animate` + manual `AnimationController` | `flutter_animate` for declarative UI transitions; manual controllers for game-specific effects |

### Dependencies (`pubspec.yaml`)

| Package | Purpose |
|---|---|
| `shared_preferences` | Local key-value storage for all game state |
| `google_fonts` | Typography (`Outfit`, `Space Grotesk`) |
| `audioplayers` | Sound effects and background music |
| `google_mobile_ads` | Banner, interstitial, and rewarded ads |
| `in_app_purchase` | Hint packs, ad removal, premium |
| `in_app_update` | Android in-app update prompts |
| `home_widget` | Android/iOS home screen widget for daily challenge stars |
| `flutter_displaymode` | Forces high refresh rate (90Hz/120Hz) on supported Android devices |
| `flutter_animate` | Declarative animation chains |
| `flutter_local_notifications` + `timezone` | Daily challenge reminder notifications |

---

## 3. Directory Structure

```
lib/
├── main.dart                          # App entry point, route registry, lifecycle
├── models/
│   └── game_info.dart                 # Game metadata model
├── theme/
│   ├── app_theme.dart                 # Color palette, Material themes, responsive helpers
│   ├── theme_manager.dart             # Dark/light mode ValueNotifier
│   └── settings_manager.dart          # Font scale, haptics, sound toggles
├── utils/
│   ├── rotation_engine.dart           # ⭐ Deterministic random + modifier picker (59 lines)
│   ├── hint_manager.dart              # ⭐ Hint economy + level-clear hooks (144 lines)
│   ├── prefs_keys.dart                # ⭐ All SharedPreferences key constants (135 lines)
│   ├── daily_challenge_manager.dart   # Daily challenge generation & tracking (1,386 lines)
│   ├── achievement_manager.dart       # Achievement conditions & unlock logic
│   ├── purchase_manager.dart          # IAP flow
│   ├── notification_manager.dart      # Push notification scheduling
│   ├── audio_manager.dart             # Sound effects + music lifecycle
│   ├── ad_manager.dart                # Ad abstraction (platform-specific)
│   ├── ad_manager_mobile.dart         # AdMob implementation
│   ├── point_manager.dart             # Point economy (add/spend)
│   ├── shuffle_manager.dart           # Randomizes game order on home screen
│   ├── activity_tracker.dart          # Active days tracking
│   ├── restore_manager.dart           # Backup restoration on boot
│   └── update_manager.dart            # In-app update checks
├── widgets/                           # ⭐ Shared reusable widgets (14 files)
│   ├── fog_overlay.dart               # Fog modifier visual overlay
│   ├── swipe_trail_overlay.dart       # Finger-trail cosmetic overlay
│   ├── loss_overlay.dart              # "Game Over" overlay
│   ├── challenge_cleared_overlay.dart # Daily challenge completion overlay
│   ├── confetti_overlay.dart          # Celebration particles
│   ├── buy_hints_dialog.dart          # Hint purchase dialog
│   ├── points_store_dialog.dart       # Point store dialog
│   ├── game_tutorial_dialog.dart      # First-time tutorial dialog
│   ├── interactive_tutorial_overlay.dart # Step-by-step tutorial
│   ├── auto_next_countdown.dart       # Auto-advance to next level timer
│   ├── animated_level_indicator.dart  # Level progress indicator
│   ├── achievement_toast.dart         # Achievement popup notification
│   └── trail_unlock_toast.dart        # Trail unlock notification
└── screens/
    ├── splash_screen.dart             # Loading/branding screen (2.5s → /home)
    ├── home_screen.dart               # Main game grid, categories, profile (2,573 lines)
    ├── daily_screen.dart              # Daily challenge hub (1,064 lines)
    ├── settings_screen.dart           # App settings
    ├── achievements_screen.dart       # Achievement gallery
    ├── trails_screen.dart             # Swipe trail cosmetic shop
    ├── beta/                          # Beta features (logic grid, beta game listing)
    └── games/                         # ⭐ All game screens (see Section 5)
        ├── game_completed_screen.dart # Shared completion screen
        ├── patches/                   # Chimp Test game
        ├── reaction/                  # Reaction Time game
        ├── odd_color_out/             # Color perception game
        ├── sudoku/                    # Sudoku (largest: 2,567 lines)
        ├── bridges/                   # Bridge-building graph puzzle + solver
        ├── word_builder/              # Anagram game + word list data
        └── ... (25+ game directories)
```

---

## 4. The Universal Game Screen Template

**Every game in CogniQ follows the same structural template.** Understanding this template is the single most important thing for working in this codebase.

```dart
class _GameScreenState extends State<GameScreen> {

  // ╔═══════════════════════════════════════════════════╗
  // ║  1. LEVEL CONFIGURATION (scale map)              ║
  // ╚═══════════════════════════════════════════════════╝
  // Maps level index to difficulty parameters.
  // Uses Dart 3 Records: (int, int) = (gridSize, count)
  static const List<(int, int)> _levels = [
    (3, 4), (3, 5), (4, 7), ...  // grows with difficulty
  ];

  // ╔═══════════════════════════════════════════════════╗
  // ║  2. STATE VARIABLES                              ║
  // ╚═══════════════════════════════════════════════════╝
  int _levelIndex = 0;
  bool _won = false;
  bool _failed = false;

  // ╔═══════════════════════════════════════════════════╗
  // ║  3. MODIFIER BOOLEANS                            ║
  // ╚═══════════════════════════════════════════════════╝
  Set<String> _activeModifiers = {};
  // Individual games check: _activeModifiers.contains('timer')

  // ╔═══════════════════════════════════════════════════╗
  // ║  4. DAILY CHALLENGE FLAGS                        ║
  // ╚═══════════════════════════════════════════════════╝
  bool _playDailyMode = false;
  String _dailyModifierType = '';

  // ╔═══════════════════════════════════════════════════╗
  // ║  5. initState — PARSE ARGS, PICK MODIFIERS       ║
  // ╚═══════════════════════════════════════════════════╝
  @override
  void initState() {
    super.initState();
    // Read level from SharedPreferences or daily challenge config
    _loadPersistedLevel();
  }

  void _loadLevel() {
    // Pick grid size from _levels[_levelIndex]
    // Get seeded random: RotationEngine.getDeterminism(gameId, level)
    // Pick modifiers:    RotationEngine.getActiveModifiers(...)
    // Generate puzzle:   _randomPositions() or _generateBoard()
    // Start timers if timer modifier is active
  }

  // ╔═══════════════════════════════════════════════════╗
  // ║  6. USER INTERACTION                             ║
  // ╚═══════════════════════════════════════════════════╝
  void _onCellTap(int r, int c) {
    // Check if tap is correct
    // If correct: advance state, check win condition
    // If wrong: set _failed = true, play error sound
  }

  // ╔═══════════════════════════════════════════════════╗
  // ║  7. WIN/LOSS HANDLING                            ║
  // ╚═══════════════════════════════════════════════════╝
  // Win → _savePersistedLevel(levelIndex + 1)
  //      → HintManager.onLevelCleared(gameId)
  //      → Show AutoNextCountdown or ChallengeClearedOverlay
  // Loss → Show LossOverlay with retry button

  // ╔═══════════════════════════════════════════════════╗
  // ║  8. build() — SCAFFOLD + GAME UI                 ║
  // ╚═══════════════════════════════════════════════════╝
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(/* title, hint button, rules button, level indicator */),
      body: Stack(
        children: [
          // Game grid (GridView, Column, or custom layout)
          // Conditional overlays:
          if (_won) AutoNextCountdown(...)
          else if (_failed) LossOverlay(...)
          // Fog overlay if modifier active:
          // FogOverlay(enabled: _activeModifiers.contains('fog'), child: grid)
        ],
      ),
    );
  }

  // ╔═══════════════════════════════════════════════════╗
  // ║  9. dispose() — CANCEL ALL TIMERS                ║
  // ╚═══════════════════════════════════════════════════╝
  @override
  void dispose() {
    _gameTimer?.cancel();
    _glitchTimer?.cancel();
    super.dispose();
  }
}
```

---

## 5. Game Inventory & Complexity

### By Complexity Tier

| Tier | Games | Lines | Notes |
|---|---|---|---|
| **Simple** | Reaction, Number Memory, Sequence Memory, Chimp Test, Cipher Decoder, Word Ladder, Hangman | 400–900 | Direct state machines, no complex algorithms |
| **Medium** | Odd Color Out, Spectrum, Sum Strike, Mine Finder, Grid Path, Word Guess, Word Builder, Word Climb, Word Hive | 900–1,700 | Color math, multiple modifiers, word list lookups |
| **Complex** | Sudoku, Bridges, Masyu, Slitherlink, Star Battle, Mahjong, Kakuro, Hitori, Flag Finder | 1,200–2,600 | Solver algorithms, constraint satisfaction, large data files |

### Companion Files

Some games have additional data/logic files:

| Game | Companion File | Purpose |
|---|---|---|
| Bridges | `bridges_levels.dart` | Pre-built level layouts |
| Masyu | `masyu_levels.dart` | Pre-built level layouts |
| Sum Strike | `sum_strike_levels.dart` | Pre-built level layouts |
| Word Builder | `word_builder_words.dart` | Word dictionary |
| Word Guess | `word_guess_dictionary.dart` | Valid word list |
| Word Hive | `word_hive_words.dart` | Spelling bee word list |
| Word Climb | `word_climb_words.dart` | Word chain dictionary |
| Word Ladder | `word_ladder_words.dart` | Word transformation dictionary |
| Flag Finder | `flag_finder_screen.dart` | Flag data embedded in screen file |

---

## 6. Core System: RotationEngine

**File**: `lib/utils/rotation_engine.dart` (59 lines)

This is the backbone of the difficulty system. It provides three things:

### 6.1 Deterministic Randomness
```dart
static Random getDeterminism(String gameId, int levelIndex)
```
- Produces a **seeded `Random`** using FNV-1a hash of `"gameId:levelIndex"`.
- **Same game + same level = same puzzle layout every time.** This is critical for reproducibility.

### 6.2 Difficulty Decay
```dart
static double getDecayValue({level, start, floor, rate})
```
- Returns a value that starts at `start` and decays toward `floor` as `level` increases.
- Used for shrinking time limits, color differences, etc.

### 6.3 Modifier Selection
```dart
static Set<String> getActiveModifiers({gameId, levelIndex, pool, minActive, maxActive, smallGrid})
```
- Takes a game's modifier pool (e.g., `['timer', 'fog', 'eclipse', 'mirror']`).
- Uses a deterministic shuffle to pick `minActive` to `maxActive` modifiers.
- If `smallGrid` is true, always picks `maxActive` modifiers.
- Returns an empty set if `pool` is empty.

---

## 7. Core System: Modifier Architecture

### How Modifiers Flow Through the Code

```
Game Screen defines pool     RotationEngine picks       Game applies effects
─────────────────────── ───→ ──────────────────── ───→ ─────────────────────

final pool = [               final active =             if (active.contains('fog'))
  'timer',                     RotationEngine              child = FogOverlay(child: grid);
  'fog',                         .getActiveModifiers(    if (active.contains('timer'))
  'eclipse',                       gameId, level, pool     _startCountdown();
  'mirror',                      );                      if (active.contains('eclipse'))
  'shuffle',                                               _startEclipseTimer();
];
```

### Common Modifiers Across Games

| Modifier | Behavior | Implementation Pattern |
|---|---|---|
| `timer` | Countdown pressure; game over when time runs out | `Timer.periodic(1 second)`, decrement `_timeLeft`, check `<= 0` |
| `fog` | Obscures the board; reveals area near finger touch | Wrap grid with `FogOverlay(enabled: true, radius: R, child: grid)` |
| `eclipse` | Periodically blacks out the entire grid for 1-2 seconds | Separate `Timer.periodic`, toggle `_isShadowed` boolean |
| `glitch` | Numbers/icons briefly turn to random symbols | `Timer.periodic(500ms)`, toggle `_glitchTick` boolean |
| `shuffle` / `positionShuffle` | Rearranges remaining tiles after N correct taps | Shuffles coordinate map, calls `setState` |
| `gravity` | Tiles sink downward after each correct tap | Recalculates positions, moves tiles to lowest available row |
| `noise` | Random visual perturbation on colors/positions | Random offsets in color or position calculations |
| `whisper` | Makes distinguishing feature extremely subtle | Reduces the delta/difference parameter |
| `mirror` | Flips or reflects the grid | Transform widget or reversed iteration |

### Daily Challenge Modifier Override

When a game is launched from the Daily Challenge screen, modifiers come from the daily config instead of `RotationEngine`:
```dart
// In game's _loadLevel():
if (_playDailyMode && _dailyModifierType.isNotEmpty) {
  _activeModifiers = {_dailyModifierType};  // Override with daily modifier
} else if (_levelIndex >= 30) {
  _activeModifiers = RotationEngine.getActiveModifiers(...);  // Normal rotation
}
```

---

## 8. Core System: Daily Challenges

**File**: `lib/utils/daily_challenge_manager.dart` (1,386 lines)

### How It Works

1. **Theme Rotation**: A 30-theme plan (`_kDailyChallengesPlan`) rotates themes like "Fog Day", "Mirror Day", "Nightmare Trial" on a 98-day cycle.
2. **Slot Assignment**: Each day generates 3 challenge slots (Easy, Medium, Hard) with specific games and modifier configs.
3. **Star Rewards**: Completing challenges earns Bronze/Silver/Gold/Diamond stars.
4. **Streak Tracking**: Consecutive days of completion maintain a streak counter.

### Game Screen Integration

Games detect daily mode via SharedPreferences flags set before navigation:
```dart
// Read by game screens on init:
_playDailyMode = prefs.getBool(PrefsKeys.playDailyMode) ?? false;
_dailyModifierType = prefs.getString(PrefsKeys.dailyModifierType) ?? '';
```

### Key Behavioral Differences (Normal vs. Daily)

| Behavior | Normal Mode | Daily Challenge Mode |
|---|---|---|
| Level source | `SharedPreferences` persisted level | Fixed by daily config |
| Modifiers | `RotationEngine` picks based on level | Forced by daily theme |
| On win | Save `levelIndex + 1`, show `AutoNextCountdown` | Pop back to daily screen, show `ChallengeClearedOverlay` |
| Level persistence | Saves progress | Does **not** save progress |
| Random seed | Deterministic (seeded by level) | `Random()` (unseeded, fresh each attempt) |

---

## 9. Theme & Design System

**File**: `lib/theme/app_theme.dart` (208 lines)

### Zen Palette

| Color | Hex (Light) | Hex (Dark) | Usage |
|---|---|---|---|
| Background | `#F5F4F0` (warm linen) | `#1C1A18` | Scaffold background |
| Card | `#FFFFFF` | `#252320` | Card surfaces |
| Text Primary | `#1C1A18` | `#F0EBE3` | Main text |
| Text Muted | `#827B75` | `#6E6760` | Secondary text |

### Accent Palette

| Name | Hex | Used For |
|---|---|---|
| Dusty Mauve | `#8B6E8C` | Primary brand accent, Word Climb, Sequence Memory |
| Warm Amber | `#D4953A` | Hangman, Odd Color Out, Spelling Bee |
| Slate Blue | `#5E7A8C` | Word Ladder, Flag Finder, Number Memory |
| Soft Sage | `#6B8C6E` | Word Guess, Word Builder |
| Terracotta | `#9E6B5A` | Chimp Test, Minesweeper |
| Rose Gold | `#C4786E` | Grid Path, Mahjong, Reaction |
| Deep Lavender | `#7068A0` | Sudoku, Star Battle, Spectrum |

### Responsive Scaling

`BuildContext` extension provides:
```dart
context.isDarkMode    // bool — checks current brightness
context.bgDark        // Color — adaptive background
context.bgCard        // Color — adaptive card color
context.textPrimary   // Color — adaptive text color
context.scale(16)     // double — scales font size to screen width (base: 375px)
context.isTablet      // bool — width >= 600
context.isDesktop     // bool — width >= 1024
```

---

## 10. SharedPreferences Key Organization

**File**: `lib/utils/prefs_keys.dart`

All storage keys are centralized in `PrefsKeys` to prevent typos and enable auditing.

### Key Categories

| Category | Example Key | Pattern |
|---|---|---|
| Settings | `settings_sound`, `settings_haptic`, `settings_music` | Static constants |
| Economy | `points`, `hints_<gameId>` | Static + dynamic helpers |
| Per-game progress | `level_<gameId>`, `cleared_count_<gameId>` | `PrefsKeys.gameLevel(gameId)` helper |
| Daily challenge | `daily_v2_streak`, `daily_v2_last_date` | Static constants |
| Achievements | `unlocked_achievements`, `clear_streak` | Static constants |
| Purchases | `settings_ads_removed`, `iap_starter_bundle_granted` | Static constants |
| Tutorials | `has_seen_tutorial_<gameId>` | `PrefsKeys.hasSeenTutorial(gameId)` helper |

### Dynamic Key Helpers

```dart
PrefsKeys.gameLevel('chimp')        → 'level_chimp'
PrefsKeys.gameHints('sudoku')       → 'hints_sudoku'
PrefsKeys.clearedCount('bridges')   → 'cleared_count_bridges'
PrefsKeys.hasSeenTutorial('queens') → 'has_seen_tutorial_queens'
PrefsKeys.dailyV2Completed('hard', '2026-08-10') → 'daily_v2_completed_hard_2026-08-10'
```

---

## 11. Navigation Model

### App Flow

```
main() → SplashScreen (2.5s delay) → HomeScreen
                                        ├── Game Screens (via pushNamed)
                                        │   └── Win → AutoNextCountdown → next level
                                        │   └── Loss → LossOverlay → retry
                                        ├── DailyScreen
                                        │   └── Game Screen (daily mode)
                                        │       └── Win → ChallengeClearedOverlay → pop back
                                        ├── SettingsScreen
                                        ├── AchievementsScreen
                                        └── TrailsScreen
```

### Route Names (from `main.dart`)

| Route | Screen | Game ID |
|---|---|---|
| `/` | `SplashScreen` | — |
| `/home` | `HomeScreen` | — |
| `/daily` | `DailyScreen` | — |
| `/chimp` | `ChimpTestScreen` | `chimp` |
| `/wordle` | `WordGuessScreen` | `wordle` |
| `/sudoku` | `SudokuScreen` | `sudoku` |
| `/bridges` | `BridgesScreen` | `bridges` |
| `/oddcolor` | `OddColorOutScreen` | `oddcolor` |
| `/queens` | `StarBattleScreen` | `queens` |
| `/minesweeper` | `MineFinderScreen` | `minesweeper` |
| `/spellingbee` | `WordHiveScreen` | `spellingbee` |
| ... | (25+ more) | ... |

---

## 12. Shared Widgets Reference

| Widget | File | Purpose | Used By |
|---|---|---|---|
| `FogOverlay` | `fog_overlay.dart` | Dark overlay with touch-reveal spotlight | Games with `fog` modifier |
| `SwipeTrailOverlay` | `swipe_trail_overlay.dart` | Cosmetic finger-trail particles | Wraps entire app globally |
| `LossOverlay` | `loss_overlay.dart` | "Game Over" card with Try Again button | Every game on failure |
| `ChallengeClearedOverlay` | `challenge_cleared_overlay.dart` | Daily challenge win screen + confetti | Daily challenge games |
| `ConfettiOverlay` | `confetti_overlay.dart` | Celebration particle effects | Level wins, daily clears |
| `AutoNextCountdown` | `auto_next_countdown.dart` | 3-second auto-advance to next level | Normal mode wins |
| `BuyHintsDialog` | `buy_hints_dialog.dart` | Hint purchase flow | Triggered from game app bars |
| `GameTutorialDialog` | `game_tutorial_dialog.dart` | First-time tutorial for each game | Shown once per game via `PrefsKeys.hasSeenTutorial` |

---

## 13. Performance Rules

From the project's internal `remember.md`:

| Rule | Why |
|---|---|
| **No `setState` inside `onPanUpdate` or 60Hz gesture callbacks** | Causes full widget tree rebuilds at 60-120fps. Use `ValueNotifier` + `ValueListenableBuilder` instead |
| **Wrap dynamic painted areas in `RepaintBoundary`** | Prevents static UI (app bar, buttons) from repainting when only the game grid changes |
| **Implement `shouldRepaint` properly in `CustomPainter`** | Avoids redundant repaints when input hasn't changed |
| **Use `Set` / `HashSet` for hot-path lookups** | `List.contains()` is O(n); `Set.contains()` is O(1). Matters inside paint loops |
| **Defer `SharedPreferences` writes to `onPanEnd`** | Disk I/O during gesture callbacks causes jank |

---

## 14. Recommended Reading Order

### Phase 1: Foundation (Understand the skeleton)

| Priority | File | Lines | What You'll Learn |
|---|---|---|---|
| 1 | `main.dart` | 234 | Boot sequence, route registry, global wrappers |
| 2 | `rotation_engine.dart` | 59 | Deterministic randomness, modifier selection |
| 3 | `hint_manager.dart` | 144 | Level lifecycle hooks, economy |
| 4 | `prefs_keys.dart` | 135 | Storage key organization |
| 5 | `app_theme.dart` | 208 | Color system, responsive helpers |

### Phase 2: Simple Games (Learn the template)

| Priority | File | Lines | What You'll Learn |
|---|---|---|---|
| 6 | `reaction_screen.dart` | 487 | Simplest game: phase state machine, timers |
| 7 | `patches_screen.dart` (Chimp Test) | 898 | Grid coordinates, sequence tapping, modifiers |
| 8 | `number_memory_screen.dart` | 762 | Memorize-then-test pattern |

### Phase 3: Complex Games (Modifier mastery)

| Priority | File | Lines | What You'll Learn |
|---|---|---|---|
| 9 | `odd_color_out_screen.dart` | 1,024 | 10 modifiers, HSL color math, eclipse/fog |
| 10 | `word_builder_screen.dart` | 1,679 | Word game pattern, companion data files |
| 11 | `bridges_screen.dart` | 1,412 | Solver-based game pattern |

### Phase 4: Infrastructure (System-level understanding)

| Priority | File | Lines | What You'll Learn |
|---|---|---|---|
| 12 | `daily_challenge_manager.dart` | 1,386 | Daily system, theme rotation, star rewards |
| 13 | `home_screen.dart` | 2,573 | Main UI hub (read by searching, not scrolling) |
| 14 | `daily_screen.dart` | 1,064 | Daily challenge UI and navigation |
| 15 | `achievement_manager.dart` | 527 | Achievement conditions and unlock logic |

---

## 15. Quick Reference: Adding a New Game

To add a new game, you need to touch these files:

1. **Create** `lib/screens/games/<game_name>/<game_name>_screen.dart` — follow the universal template
2. **Add route** in `lib/main.dart` → `routes` map
3. **Add game metadata** in `lib/models/game_info.dart`
4. **Add accent color** in `lib/theme/app_theme.dart` → `accentFor()` and `kGameColors`
5. **Add daily challenge config** in `lib/utils/daily_challenge_manager.dart` → `_getConfigForGame()`
6. **Add to home screen** in `lib/screens/home_screen.dart` → game list

---

## 16. Quick Reference: Adding a New Modifier to an Existing Game

1. Add the modifier string to the game's `pool` list
2. Add a state boolean or check: `_activeModifiers.contains('myModifier')`
3. Implement the effect in `_loadLevel()` (logic changes) and/or `build()` (visual changes)
4. If it uses a `Timer`, create it in `_loadLevel()` and cancel it in `dispose()`
5. Add a description in `_getModifierDescription()` if the game has one
6. Update daily challenge config if the modifier should appear in daily challenges

---

> **Key insight**: The patterns in this codebase repeat aggressively. Once you've read 3 game screens (Reaction, Chimp Test, Odd Color Out), you've seen the template for all 25+. The differences are in puzzle generation algorithms and modifier implementations — the lifecycle, navigation, persistence, and UI structure are identical.
