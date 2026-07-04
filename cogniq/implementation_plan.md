# Seasonal Daily Challenge Rotation — Revised Plan

## Summary of Changes from v1

Based on your feedback:
- ❌ No season names/labels in UI
- ✅ Season recap screen (stats at end of each 15-day block)
- ✅ Keep the existing 30-day static plan as starting content
- ✅ Per-user progression — every user starts from day 1 regardless of install date
- ✅ Add all ~20 new games to the codebase (definitions + challenge data) but don't implement screens yet
- ✅ 10 levels each for new games initially
- ✅ Roll out game screens gradually over time

---

## Architecture Overview

```
Days 1–30:   Static plan (current _kDailyChallengesPlan, uses only existing 18 games)
Days 31–45:  Season 1 — introduces 3 new games alongside core games  
Days 46–60:  Season 2 — introduces 3 more new games, some old featured retire
Days 61–75:  Season 3 — introduces 3 more new games, older featured retire
Days 76+:    Continues rotating, cycling through all game families
```

Each user's "Day 1" = their first app open date (stored in SharedPreferences).

---

## New Games to Add (from logic_grid_puzzles_spec.md)

All added to `game_info.dart` as **disabled entries** (in a separate `kFutureGames` list). Each gets 10 levels. They become playable only when their game screen is implemented and they're moved to `kAllGames`.

### Family A — Fill the Grid (7 games)
| # | ID | Name | Description |
|---|---|---|---|
| 1 | `killersudoku` | Killer Sudoku | Fill the grid — digits in each cage must sum to the cage's target |
| 2 | `binairo` | Binairo | Fill the grid with 0s and 1s — no three in a row, balanced counts |
| 3 | `kakuro` | Kakuro | Fill crossword-style grid — digits in each run sum to the clue |
| 4 | `futoshiki` | Futoshiki | Fill 5×5 grid with 1–5 respecting inequality signs |
| 5 | `skyscrapers` | Skyscrapers | Fill grid so edge clues match visible building counts |
| 6 | `kenken` | KenKen | Fill grid — cage cells combine via +−×÷ to hit the target |
| 7 | `sumplete` | Sumplete | Delete numbers so each row/column sums to its target |

### Family B — Path/Connection (4 games)
| # | ID | Name | Description |
|---|---|---|---|
| 8 | `numberlink` | Numberlink | Connect matching endpoints with non-crossing paths |
| 9 | `hashi` | Hashi | Connect islands with 1–2 bridges to match each island's number |
| 10 | `masyu` | Masyu | Draw a single loop through pearls following black/white rules |
| 11 | `slitherlink` | Slitherlink | Draw a single loop on grid edges matching number clues |

### Family C — Shade/Region (3 games)
| # | ID | Name | Description |
|---|---|---|---|
| 12 | `lightup` | Light Up | Place bulbs to illuminate every cell without mutual visibility |
| 13 | `nurikabe` | Nurikabe | Shade cells to form a connected sea around numbered islands |
| 14 | `minesweeperpro` | Minesweeper Pro | Pure-logic minesweeper — every cell solvable without guessing |

### Family D — Slide/Move (2 games)
| # | ID | Name | Description |
|---|---|---|---|
| 15 | `rushhour` | Rush Hour | Slide blocks to free the target piece through the exit |
| 16 | `slidingtile` | Sliding Tile | Rearrange numbered tiles into order by sliding into the gap |

### Other (from spec notes)
| # | ID | Name | Description |
|---|---|---|---|
| 17 | `buzzer` | Buzzer | Estimate elapsed time — tap when you think the target seconds have passed |

**Total: 17 new games + 18 existing = 35 games in the codebase**

---

## Per-User Progression System

### How It Works
1. On **first app open**, store `install_date` in SharedPreferences (UTC date string).
2. Each day, compute `userDay = today.difference(installDate).inDays + 1` (1-indexed).
3. For `userDay 1–30`: use the existing static `_kDailyChallengesPlan`.
4. For `userDay 31+`: use the seasonal rotation algorithm.

### Migration for Existing Users
- If `install_date` doesn't exist but `daily_v2_streak` > 0, set `install_date` to `epoch - streakDays` as a reasonable estimate.
- If nothing exists, set `install_date = today`.

---

## Seasonal Rotation Algorithm (Day 31+)

### Game Families for Rotation

**Current games** (playable now):
- Logic: sudoku ⭐, nonogram ⭐, zip, queens, minesweeper, memory
- Word: wordle ⭐, hangman ⭐, wordbuilder, connections, spellingbee, wordsearch  
- Speed: oddcolor ⭐, sequence ⭐, hue, numbermemory, chimp, flagle

**Future games** (added to codebase, enabled when screens are built):
- Logic: killersudoku, binairo, kakuro, futoshiki, skyscrapers, kenken, sumplete, numberlink, hashi, masyu, slitherlink, lightup, nurikabe, minesweeperpro, rushhour, slidingtile
- Speed: buzzer

⭐ = Core games (always in rotation)

### Selection Algorithm

```dart
List<DailyChallenge> getSeasonalChallenges(int userDay) {
  // 1. Determine season number (0-indexed, each season = 15 days)
  final seasonDay = userDay - 31;          // 0-indexed from start of seasonal content
  final seasonNumber = seasonDay ~/ 15;     // which season we're in
  final dayInSeason = seasonDay % 15;       // 0–14

  // 2. Build active game pool
  //    Core games + featured games for this season
  //    Only include games that are "enabled" (have a screen implemented)
  final activePool = _buildActivePool(seasonNumber);

  // 3. Seed RNG deterministically with userDay
  final rng = Random(userDay * 31337);

  // 4. Rotate difficulty assignment across families
  final difficultyRotation = dayInSeason % 3;
  // [Logic, Word, Speed] gets [Easy, Medium, Hard] rotated

  // 5. Pick one game per family from active pool
  //    - Must differ from yesterday's picks
  //    - Seeded shuffle ensures determinism

  // 6. Pick one modifier per game
  //    - Must be compatible with the game's family
  //    - Must differ from all other modifiers today
  //    - Must differ from yesterday's modifiers
  //    - Seeded selection

  // 7. Compute level index based on difficulty
  //    Easy: 0–4, Medium: 3–7, Hard: 5–9

  // 8. Return 3 DailyChallenge objects
}
```

### Featured Game Rotation Table

Each season activates **2 featured games per family** alongside the 2 core games per family:

```
Season 0 (days 31–45):  Logic=[zip, queens]         Word=[wordbuilder, connections]   Speed=[hue, numbermemory]
Season 1 (days 46–60):  Logic=[minesweeper, memory]  Word=[spellingbee, wordsearch]    Speed=[chimp, flagle]
Season 2 (days 61–75):  Logic=[zip, memory]          Word=[wordbuilder, wordsearch]    Speed=[hue, flagle]
Season 3 (days 76–90):  Logic=[queens, minesweeper]  Word=[connections, spellingbee]   Speed=[numbermemory, chimp]
... (cycles with offset to avoid immediate repeats)
```

When future games get enabled, they're added to the featured rotation pool automatically.

---

## Modifier Registry (14 Modifiers)

Stored as a static list in `daily_challenge_manager.dart`:

| # | ID | Name | Families |
|---|---|---|---|
| 1 | `fog` | Fog Reveal | Logic, Speed |
| 2 | `mirror` | Mirror Board | Logic, Word |
| 3 | `mono` | Monochrome Mode | Speed, Logic |
| 4 | `crop` | Cropped View | All |
| 5 | `hidden` | Hidden Clue | Word, Logic |
| 6 | `false` | False Clue | Word, Logic |
| 7 | `secret` | Secret Rule | Logic, Speed |
| 8 | `spotlight` | Spotlight Mode | All |
| 9 | `vanish` | Vanishing Trail | Logic, Speed |
| 10 | `glitch` | Glitch Effect | Speed, Word |
| 11 | `reverse` | Reverse Logic | Logic |
| 12 | `moving` | Moving Target | Speed |
| 13 | `limited` | Limited Visibility | All |
| 14 | `onelife` | One-Life Challenge | All |

Each modifier also has a per-game **description map** so "Fog Reveal on Sudoku" reads differently from "Fog Reveal on Nonogram".

---

## Season Recap Screen

At the end of each 15-day block (when `dayInSeason == 14` and all 3 challenges are done, or on day 0 of the next season), show a popup/bottom sheet with:

- 🏆 Challenges completed this season (out of 45)
- ⭐ Perfect days (out of 15)
- 🎮 Most played game
- 🔥 Current streak
- A "New Season Starts Tomorrow!" message

---

## Proposed Changes

### Game Definitions
#### [MODIFY] [game_info.dart](file:///d:/Mayank/Flutter-Projects/cogniq/lib/models/game_info.dart)
- **Add**: `kFutureGames` list with 17 new game definitions (disabled, no routes yet)
- **Add**: `kAllGamesIncludingFuture` getter that combines both lists
- **Add**: `isGameEnabled(String gameId)` helper

---

### Daily Challenge Manager  
#### [MODIFY] [daily_challenge_manager.dart](file:///d:/Mayank/Flutter-Projects/cogniq/lib/utils/daily_challenge_manager.dart)
- **Keep**: Existing `_kDailyChallengesPlan` (30-day static plan) and all state management methods
- **Add**: `_ModifierInfo` class and `_kModifiers` static list
- **Add**: `_kFeaturedRotation` table
- **Add**: `_getSeasonalChallenges(int userDay)` method
- **Modify**: `getChallengesForDate()` to:
  1. Load `install_date` from prefs
  2. Compute `userDay`
  3. If `userDay <= 30` → use static plan
  4. If `userDay > 30` → use seasonal algorithm
- **Add**: `getInstallDate()` and `setInstallDate()` helpers
- **Add**: `getSeasonProgress()` → returns `{seasonNumber, dayInSeason, totalDays}`

---

### Daily Screen
#### [MODIFY] [daily_screen.dart](file:///d:/Mayank/Flutter-Projects/cogniq/lib/screens/daily_screen.dart)
- **Add**: Season recap popup trigger (when transitioning between 15-day blocks)
- **No season labels** in the UI — challenges just appear fresh

---

### Home Screen
#### [MODIFY] [home_screen.dart](file:///d:/Mayank/Flutter-Projects/cogniq/lib/screens/home_screen.dart)
- **Minor**: Update `_playChallenge` to work with the new per-user day system (already dynamic via `getChallengesForDate`)

---

## Verification Plan

### Automated
- `flutter analyze` — clean pass on all modified files

### Manual
1. Fresh install → verify `install_date` is saved, day 1 challenges appear from static plan
2. Simulate day 31 → verify seasonal challenges appear with correct game/modifier selection
3. Simulate day 45→46 transition → verify season recap popup appears
4. Verify all 3 daily challenges use different games and different modifiers
5. Verify no game/modifier repeats on consecutive days
6. Add a future game to `kAllGames` → verify it appears in rotation automatically
