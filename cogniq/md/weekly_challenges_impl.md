# Weekly Challenges - Implementation Spec

Verified against branch `v5_Puzzle`, HEAD `9324013` ("New Version added", 2026-07-27), by reading the live code. Every file:line below is real.

Goal (in your words): keep each themed day running for a whole week. Within a week the theme/modifier stays fixed, and the level advances one step per day (Day 1 = base level, Day 2 = base+1, ... Day 7 = base+6). Your 14 themed days become 14 themed **weeks**. Plus: a recipe for wiring newly added games into the challenge pool.

Delivery: this is a handoff spec for your implementation agent. Signatures, keys, and insertion points are exact. Nothing here has been applied to the repo.

---

## 0. TL;DR - what changes

| Area | Today | After |
|---|---|---|
| Rotation unit | 1 theme per **day**, wraps `%30`, UI capped at 14 | 1 theme per **week** (7 days), 14 weeks = 98 days, then wraps |
| Difficulty within a week | fixed per game | the trio **rotates** through Easy/Medium/Hard daily (Hard wraps to Easy) |
| Level within a week | fixed `levelIndex` | `base + slot x step` (slot = the game's difficulty that day) |
| `getActiveDay()` | returns 1..30 | returns 1..98 (raw progress day) + helpers `weekOf` / `dayInWeekOf` |
| `getChallengesForDay(day)` | `plan[day-1]`, level = base | `plan[weekOf(day)-1]`, trio rotated through E/M/H slots |
| Daily screen header | "Day X of 30" / wall at >14 | "Week W of 14 - Day D of 7 - <Theme>" / wall removed |
| New games | not in the plan | add via the Part B recipe |

The completion / streak / star model (`completeChallenge`, per-date keys, Perfect Day) is **unchanged** by the core work. Perfect Week + Diamond Star is an optional add-on in Part E.

---

## 1. How the daily system works today (ground truth)

`lib/utils/daily_challenge_manager.dart`
- `_kDailyChallengesPlan` (line 84): a `List<_DayData>` of 30 entries. Each `_DayData` has `theme` + three `_ChallengeData` (easy/medium/hard), each carrying `gameId`, `levelIndex`, `modifierName`, `modifierDescription`, `modifierType`, `extraParams`.
- Entries 1-14 are your real themes: Fog, Mirror, Monochrome, Retro, Glitch, Whisper, Hidden Rule, Zoom, Eclipse, Spy, Chaos, Nightmare, Prism, Time Warp. Entries 15-30 are extra content that the UI never reaches today (see the >14 cap).
- `getActiveDay()` (line 935): reads `dailyChallengeStartTime`; every full 24h elapsed since it, bumps `dailyUserProgressDay` and re-anchors the start time. Wraps `((currentDay - 1 + elapsedDays) % 30) + 1` (line 958). This is **progress time**, not the wall calendar - the day only advances when the user opens the app 24h+ after the last anchor.
- `getChallengesForDay(dayNum)` (line 971): clamps `1..30`, returns `plan[dayNum-1]` mapped into three `DailyChallenge` objects with `levelIndex` taken verbatim.
- `completeChallenge(difficulty, dateStr, gameId)` (line 1070): keyed by **calendar date** `dateStr` (today UTC). Awards stars, updates streak, marks Perfect Day at 3/3.
- `setupDailyModifier` / `clearDailyModifier` (lines 1157, 1171): write/remove `play_daily_mode` + the five `daily_modifier_*` prefs.

`lib/screens/daily_screen.dart`
- `_loadDailyState()` (line 102): `_activeDay = getActiveDay()`, `_challenges = getChallengesForDay(_activeDay)`, plus per-date completion flags.
- `_playChallenge(challenge)` (line 140): the launch flow.
  1. Backs up the game's real progress: `daily_backup_<id> = level_<id>` (line 152-153).
  2. **Injects the challenge level**: `prefs.setInt('level_<id>', challenge.levelIndex)` (line 156).
  3. `setupDailyModifier(challenge)` (line 157).
  4. Shows the "Special Daily Rule" dialog, then `Navigator.pushNamed(game.routeName)` (line 209).
  5. On return: if `result == true`, `completeChallenge(...)`; always restores `level_<id> = realLevel` and clears the modifier (line 238-241).
- Header text "Day $_activeDay of 30" (line 665). The >14 completion wall (line 597).
- "WEEKLY STARS" card (line 674): a 7-node strip of the last 7 **calendar** days, each showing that date's star (via `getCompletedCountForDate`).

**The level-injection contract:** a game shows the daily variant because (a) `play_daily_mode == true` and (b) its `level_<id>` pref was set to the challenge's level index just before launch. That is the single lever the weekly progression pulls - we only need to change what number gets written there.

---

## 2. PART A - Weekly rotation (the core "how to make it work")

### A.1 Constants

Add near the top of `DailyChallengeManager`:

```dart
static const int kThemeCount  = 14;               // 14 themed weeks
static const int kDaysPerWeek = 7;
static const int kTotalDays   = kThemeCount * kDaysPerWeek; // 98
```

### A.2 The math

Let `globalDay` = the raw 1-based progress day from `getActiveDay()` (now 1..98).

```
dayInWeek   = ((globalDay - 1) % 7) + 1              // 1..7
weekNumber  = (((globalDay - 1) ~/ 7) % 14) + 1      // 1..14 (theme/week to use)
```

Within a week the theme, modifier, and the trio of 3 games are **locked**. What changes each day is the **difficulty rotation**: each game shifts up one slot (Easy -> Medium -> Hard) and the game that was Hard wraps back to Easy.

```
game in slot k on day d = trio[(k - (dayInWeek - 1)) mod 3]   // k: 0=Easy, 1=Medium, 2=Hard
level for that game      = base + k * step                    // harder slot => higher level
```

Exception: a game with `pinDifficulty` set does not rotate (Chimp is pinned to Easy); the remaining games rotate through the remaining slots. After 98 progress-days you wrap back to Week 1.

### A.3 `getActiveDay()` - change the wrap only

One-line change at line 958: `% 30` -> `% kTotalDays`.

```dart
currentDay = ((currentDay - 1 + elapsedDays) % kTotalDays) + 1;
```

Everything else in that method (start-time anchoring, the v2 migration block) stays as-is. The returned value is now the raw progress day 1..98.

### A.4 Derived helpers

```dart
/// 1..14 - which themed week this progress day belongs to.
static int weekOf(int globalDay) {
  final d = ((globalDay - 1) % kTotalDays);
  return ((d ~/ kDaysPerWeek) % kThemeCount) + 1;
}

/// 1..7 - day within the current themed week.
static int dayInWeekOf(int globalDay) {
  final d = ((globalDay - 1) % kTotalDays);
  return (d % kDaysPerWeek) + 1;
}

/// Convenience for the UI banner.
static String themeOf(int globalDay) => _kDailyChallengesPlan[weekOf(globalDay) - 1].theme;
```

### A.5 Data model - extend `_ChallengeData` with `step` + `pinDifficulty`

Each plan entry is now a **week**. Its three `_ChallengeData` (easy/medium/hard) define the **Day-1 arrangement** = the fixed trio, in slot order [Easy=0, Medium=1, Hard=2]. The theme/modifier is shared across the week (each game keeps its own themed variant name/description). Add two fields:

```dart
class _ChallengeData {
  final String gameId;
  final String difficulty;          // Day-1 slot label (informational only)
  final int levelIndex;             // now the game's EASY base level
  final int step;                   // level added per difficulty rank (default 3)
  final int? pinDifficulty;         // null = rotates; 0 = pinned to Easy (Chimp)
  final String modifierName;
  final String modifierDescription;
  final String? modifierType;
  final Map<String, dynamic>? extraParams;
  const _ChallengeData({
    required this.gameId,
    required this.difficulty,
    required this.levelIndex,
    this.step = 3,
    this.pinDifficulty,
    required this.modifierName,
    required this.modifierDescription,
    this.modifierType,
    this.extraParams,
  });
}
```

Authoring change: set each entry's `levelIndex` to the game's **easy** level (the same game is shown at all three difficulties across the week), and `step` so `levelIndex + 2*step` is its intended **hard** level and is valid. Give every Chimp entry `pinDifficulty: 0`.

### A.6 `getChallengesForDay(day)` - difficulty rotation

Replace the body of `getChallengesForDay` (line 971):

```dart
static const List<String> _kDiffLabels = ['Easy', 'Medium', 'Hard'];

static List<DailyChallenge> getChallengesForDay(int globalDay) {
  final week = weekOf(globalDay);            // 1..14
  final dayInWeek = dayInWeekOf(globalDay);  // 1..7
  final wk = _kDailyChallengesPlan[week - 1];
  final trio = [wk.easy, wk.medium, wk.hard]; // Day-1 [slot0, slot1, slot2]

  final slotToGame = _slotAssignment(trio, dayInWeek); // slot -> index into trio

  final out = <DailyChallenge>[];
  for (int slot = 0; slot < 3; slot++) {
    final c = trio[slotToGame[slot]];
    final level = c.levelIndex + slot * c.step;   // level scales with the slot
    out.add(DailyChallenge(
      difficulty: _kDiffLabels[slot],
      game: kAllGames.firstWhere((g) => g.id == c.gameId),
      levelIndex: level,
      modifierName: c.modifierName,
      modifierDescription: c.modifierDescription,
      modifierType: c.modifierType,
      extraParams: c.extraParams,
    ));
  }
  return out; // [0]=Easy, [1]=Medium, [2]=Hard, matching daily_screen
}

/// slotToGame[slot] = index (0..2) into `trio`, honoring any pinned game.
static List<int> _slotAssignment(List<_ChallengeData> trio, int dayInWeek) {
  final slotToGame = List<int>.filled(3, -1);
  final usedSlots = <int>{};
  final freeGames = <int>[];
  for (int i = 0; i < 3; i++) {                 // 1) place pinned games
    final p = trio[i].pinDifficulty;
    if (p != null) { slotToGame[p] = i; usedSlots.add(p); }
    else { freeGames.add(i); }
  }
  final freeSlots = [for (int s = 0; s < 3; s++) if (!usedSlots.contains(s)) s];
  final m = freeSlots.length;                   // 3 (no pin) or 2 (Chimp week)
  final r = m == 0 ? 0 : (dayInWeek - 1) % m;   // 2) rotate free games through free slots
  for (int j = 0; j < m; j++) {
    slotToGame[freeSlots[j]] = freeGames[((j - r) % m + m) % m];
  }
  return slotToGame;
}
```

With no pins this is exactly `game in slot k = trio[(k - (dayInWeek-1)) mod 3]` - the Hard game wraps to Easy each day, the others move up. With a Chimp pin (`pinDifficulty: 0`), Chimp holds Easy every day and only the other two swap Medium/Hard (m = 2).

### A.7 Level rule, Chimp pin, and bounds

- **Level from slot:** `level = base + slot*step` (Easy = base, Medium = base+step, Hard = base+2*step). A game plays harder only when it rotates into a harder slot.
- **Chimp pinned Easy** (`pinDifficulty: 0`, Weeks 5/11/14): always `base`, never scaled up. Rationale: Chimp Test at higher levels (too many tiles to memorize) is not viable as a Medium/Hard challenge.
- **Bounds:** difficulty is capped at `base + 2*step` - three known levels per game, not an open-ended `base+6`. Pick `base` + `step` so `base + 2*step` is valid; no separate cap needed.
- **Cycle length:** normal weeks repeat every 3 days (Day 7 = Day 1 arrangement); Chimp weeks every 2. Each game still hits Easy/Medium/Hard across the week. Optional polish for freshness: add `((dayInWeek - 1) ~/ m)` to `level` so each full cycle nudges one level up (keep `base + 2*step + that` valid).

### A.8 Legacy `getChallengesForDate` (line 1010)

Still `%30`-based and only used by legacy/widget callers. Either (a) leave it (harmless, isolated) or (b) route it through the new mapping: `return getChallengesForDay(((...days...) % kTotalDays) + 1);`. Not required for the feature.

---

## 3. PART B - Wiring new games into the challenge pool

A game is "daily-ready" when three things are true. Two are already handled by the framework; the third is per-game work.

### B.1 The three requirements

1. **Registered in `kAllGames`** (`lib/models/game_info.dart`) with a stable `id` and a real `routeName`. All your current games already are - Pearl Loop/`masyu` (line 48), `bridges` (49), `sumstrike` (50), `killersudoku` (51), `color_flood` (42), `circuit_guide` (43), etc.
2. **Level injection** - handled for free by `_playChallenge`: it writes `level_<id> = levelIndex` before launch and restores it after. The game just has to load `level_<id>` on entry (they all do).
3. **Modifier awareness** (the real work) - the game screen must, in daily mode, read `daily_modifier_type` (+ `daily_modifier_extra_params`) and actually apply that modifier's visuals/rules. ~27 game screens already read these prefs; a newly added game must copy that pattern or its daily card will inject the level but show no modifier.

### B.2 Recipe to add a game as a daily/weekly challenge

1. **Confirm/add `GameInfo`** in `kAllGames` (id + routeName). If the game route is not registered in the app router, add it.
2. **Add an icon** in `daily_screen.dart` `_gameIcons` map (line 12). Optional - it falls back to `Icons.gamepad_outlined` (line 453), but a real icon looks finished.
3. **Make the screen daily-modifier-aware.** In the level-load path, when `play_daily_mode == true`, read:
   ```dart
   final prefs = await SharedPreferences.getInstance();
   final isDaily   = prefs.getBool('play_daily_mode') ?? false;
   final modType   = prefs.getString('daily_modifier_type') ?? '';
   final extraJson = prefs.getString('daily_modifier_extra_params');
   final extra = extraJson == null ? const {} : jsonDecode(extraJson) as Map<String, dynamic>;
   ```
   then branch on `modType` (`'fog'`, `'mirror'`, `'monochrome'`, `'glitch'`, `'timer'`, ...) and apply. Mirror the closest existing implementation - e.g. Sudoku (`sudoku_screen.dart`), Word Hive (`word_hive_screen.dart`), or Spectrum (`spectrum_screen.dart`) all read `daily_modifier_type`. Match whichever modifier family you are adding.
4. **Reference the game in the plan.** Put its `id` into one of the trio slots of the target week in `_kDailyChallengesPlan`. Set `levelIndex` to the game's **easy** level and `step` so `levelIndex + 2*step` is a valid hard level. Add `pinDifficulty: 0` if it should never rotate above Easy (like Chimp).
5. **Verify the modifier is honored** at the Easy level (`base`) and the Hard level (`base + 2*step`) (see QA).

### B.3 The challenge pool - exactly 16 games

The daily/weekly challenge pool is **exactly 16 games** - the distinct `gameId`s used across the first 14 themed days (= the 14 weeks). This is the canonical roster; `kAllGames` in `game_info.dart` holds more entries but many are `isStashed: true` and are not part of the pool. When adding or swapping a challenge, stay within (or deliberately extend) this set.

The internal `id` differs from the display name for several games - always use the `id` in `_kDailyChallengesPlan`, and the display name in UI:

| # | id (use in plan) | Display name | # | id (use in plan) | Display name |
|---|---|---|---|---|---|
| 1 | `oddcolor` | Odd Color Out | 9 | `circuit_guide` | Circuit Guide |
| 2 | `sudoku` | Sudoku | 10 | `chimp` | Chimp Test |
| 3 | `minesweeper` | Mine Finder | 11 | `spellingbee` | **Word Hive** |
| 4 | `zip` | Grid Path | 12 | `sumstrike` | Sum Strike |
| 5 | `pattern_lock` | Pattern Lock | 13 | `bridges` | Bridges |
| 6 | `queens` | Star Battle | 14 | `killersudoku` | Killer Sudoku |
| 7 | `hue` | Spectrum | 15 | `color_flood` | Color Flood |
| 8 | `colour_link` | Colour Link | 16 | `masyu` | Pearl Loop |

Watch-outs:
- `spellingbee` renders as **Word Hive** (not "Spelling Bee"); `hue` = Spectrum; `queens` = Star Battle; `zip` = Grid Path; `minesweeper` = Mine Finder; `masyu` = Pearl Loop. Don't let a display name leak into a `gameId`.
- `chimp` (Chimp Test) is the one pool game flagged `isStashed: true`. It still resolves and plays fine as a challenge (used in Weeks 5, 11, 14), but it is hidden from the normal menu - keep it if intentional, otherwise swap that slot for another pool game.

### B.3.1 Keep this file and `weekly_themes_challenges.md` in sync

The two docs are meant to be read together:
- `md/weekly_themes_challenges.md` is the source of truth for **themes and modifiers** (which modifier family each week uses, gradients, reward flow).
- This file is the source of truth for the **rotation mechanics and the game pool**.
- They meet in `_kDailyChallengesPlan`: each week's entry pairs a theme (from the themes doc) with 3 of the 16 pool games.

Current 14-week theme -> game mapping (from `_kDailyChallengesPlan` days 1-14; Easy / Medium / Hard):

| Week | Theme | Easy | Medium | Hard |
|---|---|---|---|---|
| 1 | Fog | Odd Color Out | Sudoku | Mine Finder |
| 2 | Mirror | Grid Path | Pattern Lock | Star Battle |
| 3 | Monochrome | Odd Color Out | Spectrum | Colour Link |
| 4 | Retro | Odd Color Out | Circuit Guide | Grid Path |
| 5 | Glitch | Chimp Test | Sudoku | Star Battle |
| 6 | Whisper | Odd Color Out | Word Hive | Sum Strike |
| 7 | Hidden Rule | Odd Color Out | Mine Finder | Star Battle |
| 8 | Zoom | Star Battle | Sudoku | Bridges |
| 9 | Eclipse | Odd Color Out | Pattern Lock | Sudoku |
| 10 | Spy | Word Hive | Star Battle | Killer Sudoku |
| 11 | Chaos | Odd Color Out | Chimp Test | Color Flood |
| 12 | Nightmare | Word Hive | Sudoku | Grid Path |
| 13 | Prism | Odd Color Out | Spectrum | Pearl Loop |
| 14 | Time Warp | Odd Color Out | Chimp Test | Sudoku |

Note: the columns are the **authored Day-1 trio** (which 3 games the week uses). Across the week they rotate through Easy/Medium/Hard per A.6, so a game appears at every difficulty. **Chimp Test (Weeks 5, 11, 14) carries `pinDifficulty: 0`** - it stays in the Easy card every day and only the other two rotate (Medium <-> Hard). Set each game's `levelIndex` to its easy level regardless of which column it sits in here.

Rule of thumb: if you edit a week's theme/modifier in `weekly_themes_challenges.md`, update the matching week entry in `_kDailyChallengesPlan` (and this table), and vice-versa. Any game you place in a week must be one of the 16 above (or a new pool member added via the B.2 recipe) and must honor that week's `modifierType`.

### B.4 Failure mode to avoid

`kAllGames.firstWhere((g) => g.id == c.gameId)` (line 975) throws `StateError` if a `gameId` in the plan has no matching `GameInfo`. A typo'd id crashes the Daily tab on load. Keep plan ids and `GameInfo` ids in exact sync. (Optional hardening: `firstWhere(..., orElse: () => <fallback>)` so a bad id degrades instead of crashing.)

---

## 4. PART C - `daily_screen.dart` UI changes

### C.1 Header label (line 664-668)

Replace the "Day X of 30" line with week/day context:

```dart
final _week = DailyChallengeManager.weekOf(_activeDay);
final _dayInWeek = DailyChallengeManager.dayInWeekOf(_activeDay);
final _theme = DailyChallengeManager.themeOf(_activeDay);
// ...
Text(
  'Week $_week of 14  -  Day $_dayInWeek of 7  -  $_theme',
  textAlign: TextAlign.center,
  style: GoogleFonts.outfit(fontSize: 13, color: context.textSecondary, fontWeight: FontWeight.bold),
),
```

(Compute `_week/_dayInWeek/_theme` in `_loadDailyState` and store as fields, next to `_activeDay`.)

### C.2 Remove the >14 wall (line 596-643)

With weekly wrapping there is always content, so the "Challenges Completed!" branch (`if (_activeDay > 14)`) should be removed or repurposed. Recommended: delete the early-return so `_buildBody` always renders the cards. If you want a "you have looped all themes" nicety, gate it on `weekOf(_activeDay) == 1 && everCompletedAllWeeks` instead of the raw day.

### C.3 Weekly theme banner (recommended)

Above the summary card, add a themed banner using `_theme`. Minimal version:

```dart
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    gradient: LinearGradient(colors: _themeGradient(_theme)), // small switch on theme name
    borderRadius: BorderRadius.circular(20),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('${_theme.toUpperCase()} WEEK',
        style: GoogleFonts.outfit(fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w800, color: Colors.white)),
      const SizedBox(height: 4),
      Text('Day $_dayInWeek of 7 - same theme all week, one level harder each day.',
        style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70)),
    ],
  ),
),
```

The full gradient palette per theme is specified in `md/weekly_themes_challenges.md` section 5A.

### C.4 In-week progression strip (optional)

The existing "WEEKLY STARS" strip (line 674-706) shows the last 7 **calendar** days. Because the weekly theme runs on **progress** days, a truer strip shows Day 1..7 of the current theme week. Two options:
- Keep the calendar strip as-is (it still communicates recent activity), or
- Replace it with 7 nodes indexed by `dayInWeek`, filled up to `_dayInWeek`, current pulsing. To show which in-week days were completed you need the per-week completion tracking in Part E.

---

## 5. PART D - Prefs keys

Core weekly rotation needs **no new keys** - it reuses `dailyUserProgressDay` + `dailyChallengeStartTime`. Add keys only for the optional Perfect Week add-on (Part E). Register them in `lib/utils/prefs_keys.dart` next to the Daily V2 block:

```dart
// Weekly / Perfect Week (optional add-on)
static const String weeklyPerfectStreak   = 'daily_v2_perfect_streak';   // int 0..7
static const String weeklyLastPerfectDate = 'daily_v2_last_perfect_date';// ISO yyyy-MM-dd
static const String diamondStars          = 'daily_diamond_stars';       // int
static const String perfectWeekHistory    = 'daily_perfect_week_history';// List<String> dates
static const String weeklyResetV3Done     = 'daily_v3_weekly_reset_completed'; // migration flag
```

---

## 6. PART E - (Optional) Perfect Week + Diamond Star

This is the reward layer from `md/weekly_themes_challenges.md`. It is independent of the core rotation; ship it after Part A/B/C if you want a weekly goal.

- **Perfect Day** already exists (3/3 on a date -> `dailyV2Perfect(dateStr)`, `dailyV2PerfectDays++`, see `completeChallenge` line 1126).
- **Perfect Week**: 7 perfect days in a row -> award 1 Diamond Star, reset the streak. Hook into `completeChallenge` right after the Perfect Day block:

```dart
if (completedCount == 3) {
  final today = DateTime.parse(dateStr); // dateStr is UTC yyyy-MM-dd
  final last = prefs.getString(PrefsKeys.weeklyLastPerfectDate) ?? '';
  int streak = prefs.getInt(PrefsKeys.weeklyPerfectStreak) ?? 0;
  if (last != dateStr) {
    if (last.isEmpty) {
      streak = 1;
    } else {
      final diff = today.difference(DateTime.parse(last)).inDays;
      streak = (diff == 1) ? streak + 1 : 1; // gap -> reset to 1
    }
    await prefs.setString(PrefsKeys.weeklyLastPerfectDate, dateStr);
    if (streak >= 7) {
      await prefs.setInt(PrefsKeys.diamondStars, (prefs.getInt(PrefsKeys.diamondStars) ?? 0) + 1);
      streak = 0; // reset after the reward
      // trigger the Diamond Star reward dialog on the UI side
    }
    await prefs.setInt(PrefsKeys.weeklyPerfectStreak, streak);
  }
}
```

- **Diamond Sparkle trail** + reward dialog: fully specified in `md/weekly_themes_challenges.md` sections 5B and 6. Not required for the rotation to work.
- **Migration/reset**: the existing spec (section 7) wants a one-time reset of star counters when this ships, guarded by `weeklyResetV3Done`. Keep it one-shot; remove the reset block in the release after.

Use UTC dates everywhere (matches `completeChallenge`, blocks clock-tampering).

---

## 7. PART F - Edge cases and gotchas

1. **Level bounds:** difficulty is capped at `base + 2*step` (three levels per game), so there is no open-ended growth - but that hard level must still be valid. Audit each game's `levelIndex` (easy) + `step` so `base + 2*step` is a real level. A level past content = an unplayable daily card. Chimp stays at `base` (pinned Easy).
2. **Progress-day vs calendar-day mismatch:** the week advances on *progress* days (only when the app is opened 24h+ after the anchor), while completion/stars are keyed by *calendar* date. A player who skips real days still sees Day N+1 next open. This is the existing behavior - the weekly banner should say "Day D of 7" from `dayInWeekOf`, not from the wall calendar, so the two never contradict.
3. **Stashed games in the plan:** several referenced ids are `isStashed: true`. They still resolve, but decide deliberately whether a hidden game should surface as a challenge; otherwise swap for an active game (B.3).
4. **Bad gameId crashes the tab:** `firstWhere` with no `orElse` (line 975) throws on a typo. Keep ids in sync or add a fallback (B.4).
5. **Only entries 1-14 are used** as themes now (weekOf caps at 14). Entries 15-30 in `_kDailyChallengesPlan` become dead data - remove them or keep as a reserve, but they will not render.
6. **Unrelated but live - the `getDeterminism` bug:** `rotation_engine.dart:6` still seeds `Random` with `Object.hash(gameId, levelIndex)`. Dart randomizes `String.hashCode` per app launch, so a given level's procedurally generated board changes every cold start, and generators that can fail (Circuit Guide) ship occasional impossible boards ("impossible level ~every 10, fixed by reopening"). This touches daily challenges too: any daily card whose game is procedurally generated (Circuit Guide, Grid Path, Star Battle, Spectrum) can hand the player an unsolvable variant. Fix the seed (stable hash of gameId) and add a solvability check before this ships widely. Tracked separately from weekly work but worth fixing in the same pass.

---

## 8. PART G - QA checklist

Rotation
- [ ] Fresh install: Daily tab shows Week 1, Day 1, theme = Fog (or your entry 1).
- [ ] Advance the clock 24h x1: Day 2 of Week 1 - same theme + same trio, difficulties rotated one slot (the Day-1 Hard game is now Easy at its base level).
- [ ] Advance to Day 8: Week 2, Day 1, theme = entry 2 (Mirror), trio back to its Day-1 arrangement.
- [ ] Advance to Day 98 then +1: wraps to Week 1 Day 1.
- [ ] Header reads "Week W of 14 - Day D of 7 - <Theme>" and matches the cards.

Level injection & rotation
- [ ] Launching a card sets `level_<id>` to `base + slot*step` for that game's slot today; on exit it is restored to the player's real level (backup/restore intact).
- [ ] The Hard-slot level (`base + 2*step`) loads a real, solvable level for each game (spot-check small-level games).
- [ ] Chimp weeks (5, 11, 14): Chimp stays in the Easy card every day at its base level; the other two swap Medium/Hard.

New games
- [ ] A newly added game shows its modifier in daily mode (not just the injected level).
- [ ] Its `id` matches `GameInfo.id` exactly; no `firstWhere` crash.
- [ ] Icon renders (real or fallback).

Completion / rewards
- [ ] 3/3 on a day still marks Perfect Day, awards star, updates streak.
- [ ] (If Part E) 7 consecutive Perfect Days awards exactly one Diamond Star and resets the streak; a skipped day resets to 1.

Regression
- [ ] "Special Daily Rule" dialog still shows the correct modifier name/description for the week.
- [ ] Countdown timer card still counts to the next progress day.
- [ ] Removing the >14 wall did not break the embedded (home tab) daily view.

---

## 9. Ordered work list

1. A.1-A.7: constants (incl. default `step`), `getActiveDay` wrap, `weekOf`/`dayInWeekOf`/`themeOf`, add `step` + `pinDifficulty` to `_ChallengeData`, rotation `getChallengesForDay` + `_slotAssignment`.
2. A.5/A.7 authoring: set each game's `levelIndex` (easy) + `step` so `base + 2*step` is valid across all 14 weeks; add `pinDifficulty: 0` to every Chimp entry.
3. C.1-C.2: header label, remove the >14 wall.
4. B: wire any new games (GameInfo, icon, modifier-awareness, plan slot).
5. C.3: weekly theme banner.
6. (Optional) E + D: Perfect Week, Diamond Star, prefs keys, migration.
7. C.4: in-week progression strip (needs E's per-week tracking).
8. Part F.6: fix the `getDeterminism` seed + add solvability check (separate but recommended same-pass).
