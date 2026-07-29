# CogniQ — Daily/Weekly Challenge & Modifier Fixes

Implementation spec for the bugs reported after the weekly-challenge + IAP work
(commits `e1a638b`…`2b57ba5` on `v5_Puzzle`). Line numbers are against that branch head.

**Legend:** each fix has → *Symptom* · *Root cause (file:line)* · *Fix*.
Work the **Priority P0** items first (they make a challenge unwinnable or corrupt score state).

---

## Priority summary

| # | Bug | Priority | Primary file |
|---|-----|----------|--------------|
| 1 | Perfect-week streak lags 1 / needs 8 golds for diamond | **P0** | daily_screen.dart, daily_challenge_manager.dart |
| 2 | Star Battle mirror modifier does nothing | P1 | star_battle_screen.dart |
| 3 | Pattern Lock shows "Level N" in daily mode | P2 | pattern_lock_beta.dart |
| 4 | Colour Link shows "Level N" in daily mode | P2 | numberlink_beta.dart |
| 4b | Same header bug: color_flood, circuit_guide, killer_sudoku | P2 | *_beta.dart |
| 5 | Chimp (Wk 5/11/14) rotates into Hard, level frozen | P1 | daily_challenge_manager.dart |
| 6 | Sum Strike life logic inverted | **P0** | sum_strike_screen.dart |
| 7 | Week banner describes one game, not the week | P2 | daily_screen.dart, daily_challenge_manager.dart |
| 8 | Killer Sudoku Wk 10 (level 3) unwinnable | **P0** | killer_sudoku_beta.dart |
| 9 | Masyu/Pearl Loop Wk 13 Day-1 impossible + Verify button | **P0** | masyu_screen.dart, daily_challenge_manager.dart |
| A | Bronze+Silver+Gold all inflate on a perfect day | **P0** | daily_challenge_manager.dart |
| B | `minefinder` gameId typo → fog copy never applies | P2 | daily_challenge_manager.dart |
| C | Generic fog override clobbers authored descriptions | P3 | daily_challenge_manager.dart |
| D | Wrong daily-backup key in Replay Game | P2 | game_completed_screen.dart |
| E | Sum Strike daily win never registers (completion race) | **P0** | sum_strike_screen.dart |

---

## 1. Perfect-week streak off-by-one → diamond needs 8 golds (P0)

**Symptom:** Complete Day 1 → streak effectively 0; Day 2 → shows 1; Day 3 → shows 2 …
so the diamond (7 perfect days) is only awarded on the **8th** perfect day.

**Root cause (two sites):**
- `lib/screens/daily_screen.dart:1085-1107` — the **"Reset All"** debug handler resets
  `debug_date_offset = 0` (snapping `dateStr` back to real today) and clears
  `weeklyPerfectStreak`, `perfectWeekHistory`, `dailyV2LastDate`, `dailyV2Streak` — **but
  never clears `weeklyLastPerfectDate`** (`daily_v2_last_perfect_date`). A stale last-perfect
  date from the previous test run survives and is ≥ the new Day-1 date.
- `lib/utils/daily_challenge_manager.dart:1268-1274` — the perfect-week diff branch only
  handles `diff == 1` and `diff > 1`; a `diff <= 0` (stale/equal/future last-date) falls
  through **silently**, so Day 1's increment is swallowed. From Day 2 on the streak is
  permanently 1 behind.

The increment/threshold/reset arithmetic is otherwise correct (a *clean* reset awards the
diamond at exactly 7). Note the day-streak (`dailyV2Streak`) does **not** lag because its
`dailyV2LastDate` *is* cleared — only the perfect-week streak is affected.

**Fix — primary (load-bearing).** In `daily_screen.dart`, in the Reset All handler, right
after `await prefs.remove(PrefsKeys.perfectWeekHistory);` (line 1102) add:
```dart
await prefs.remove(PrefsKeys.weeklyLastPerfectDate);
await prefs.setInt(PrefsKeys.dailyV2PerfectDays, 0);   // optional: fully clean slate
await prefs.remove(PrefsKeys.dailyChallengeStartTime); // optional
```

**Fix — defense-in-depth.** In `daily_challenge_manager.dart:1268-1274`, turn the
`else if (diff > 1)` into a catch-all `else` so any non-consecutive/stale/clock-skew date
restarts the streak instead of silently eating a day:
```dart
if (diff == 1) {
  streak += 1;
} else {                       // diff <= 0 OR diff > 1 → restart at 1
  streak = 1;
  history = [dateStr];
  await prefs.setStringList(PrefsKeys.perfectWeekHistory, history);
}
```
The primary fix removes the bug; the second prevents any future reset/clock edge case from
recurring.

---

## A. Bronze + Silver + Gold counters all inflate on one perfect day (P0)

**Symptom:** After a single perfect day, the HUD shows "1 Bronze, 1 Silver, 1 Gold"
instead of "1 Gold"; the totals contradict the weekly calendar (which shows one star/day).

**Root cause:** `lib/utils/daily_challenge_manager.dart:1204-1209` — on **each** of the 3
sub-completions, `completeChallenge` recomputes `completedCount` and increments a *different*
tier counter (1st → `dailyBronzeStars`, 2nd → `dailySilverStars`, 3rd → `dailyGoldStars`).
So one perfect day adds +1 to all three. The per-date star `dailyStarForDate` and the
calendar (`daily_screen.dart:571-586`) correctly treat tiers as mutually exclusive (one
star per day = the highest tier reached).

**Fix:** Make the tier counters mutually exclusive per day — when a day's tier upgrades,
move the count rather than adding a new one. Replace the counter-increment (around 1206-1209)
with a read-old-then-move:
```dart
// Determine the previous tier awarded for THIS date (if any) and move the count.
final prevStar = prefs.getString(starKey); // read BEFORE overwriting starKey
String newStar = completedCount == 1 ? 'bronze' : completedCount == 2 ? 'silver' : 'gold';
await prefs.setString(starKey, newStar);

String keyFor(String s) => s == 'bronze'
    ? PrefsKeys.dailyBronzeStars
    : s == 'silver' ? PrefsKeys.dailySilverStars : PrefsKeys.dailyGoldStars;

if (prevStar != null && prevStar != newStar) {
  final oldK = keyFor(prevStar);
  await prefs.setInt(oldK, (prefs.getInt(oldK) ?? 1) - 1); // remove the superseded tier
}
final newK = keyFor(newStar);
await prefs.setInt(newK, (prefs.getInt(newK) ?? 0) + 1);
```
(Alternative, more robust: derive Bronze/Silver/Gold totals by scanning all
`daily_star_for_date_*` values instead of incrementally maintaining them — kills any drift.)

---

## 6. Sum Strike — life logic inverted (P0)

**Symptom:** Removing the **correct** block costs a life; removing an **incorrect** block does
nothing.

**Root cause:** `lib/screens/games/sum_strike/sum_strike_screen.dart:469-495` (`_toggleCell`).
Data model: `_solutionMask[idx] == true` → cell must be **kept**; `== false` → must be
**struck**. The entire strike+penalty body is gated on `if (_solutionMask[idx] == false)`
(line **472**) — i.e. it only runs on a *correct* strike, and inside it decrements a life.
A wrong strike (`== true`) fails the `if`, so nothing happens.

**Fix:** Always strike the tapped cell; deduct a life only when the struck cell was meant to
be kept. Restructure lines 472-494:
```dart
settingsNotifier.hapticTap();
setState(() { _keep[idx] = false; });           // strike the tapped cell

if (_solutionMask[idx] == false) {
  // Correct strike — no penalty.
  _tryAutoCheck();
} else {
  // Wrong strike — cell should have been kept. Cost a life and restore it.
  setState(() {
    _wrongTaps.add(idx);
    _lives--;
    if (_lives <= 0) { _gameTimer?.cancel(); _gameOver = true; }
  });
  Future.delayed(const Duration(milliseconds: 500), () {
    if (mounted) setState(() { _wrongTaps.remove(idx); _keep[idx] = true; });
  });
}
```
(The original also never restored a wrongly-struck cell; the `else` above restores it after
the 500 ms flash.)

---

## 8. Killer Sudoku Week 10 — Level 3 board unwinnable (P0)

**Symptom:** On Week 10 (Spy Day) days **3 and 6**, a perfectly-filled grid is rejected:
"Incorrect solution…". The `2b57ba5` auto-check (fill last cell → validate) makes it feel
worse — no button to blame.

**Root cause:** In daily mode the game forces `_currentLevel = savedLvl % 10` and always uses
the hardcoded 4×4 boards. Killer Sudoku rotates through all three slots in Week 10, giving
levels 1, 3, 5. **Level 3's board data is malformed**
(`lib/screens/games/beta/killer_sudoku_beta.dart:370-391`):
- solution[3] = `[1,2,4,3, 4,3,2,1, 3,4,1,2, 2,1,3,4]`
- cages[3]   = `[0,1,1,2, 0,0,1,2, 3,4,5,2, 3,4,5,6]`
- **Cage 1** = cells idx 1, 2, 6 = values `{2, 4, 2}` → duplicate `2` in one cage. The
  no-duplicate-in-cage check (`:478`, and `:474` on the spy path) rejects the intended
  solution → unwinnable.

The 'spy' decoy-cage modifier itself is fine (levels 1 & 5 verified clean); spy only bypasses
the *sum* check, not dedup, so it can't rescue level 3.

**Fix:** Repartition Level 3's cages so no cage holds a repeated solution digit — e.g. move
idx 6 out of cage 1 (make cage 1 = cells idx 1,2 only) and recompute the affected cage sums
to match the solution. Any layout where every cage's cells hold distinct solution values works.

**Guard (recommended):** After building `_cageSums`, assert in debug that every hardcoded
cage has distinct solution digits **and** its sum equals the solution total; fail loudly.
This would have caught level 3 and guards boards 0,2,4,6-9 (only 1/3/5 were verified).

---

## 9. Masyu / "Pearl Loop" Week 13 — Day-1 impossible + remove Verify button (P0)

### 9a. Day-1 board is genuinely unsolvable
**Root cause:** Week 13 Hard = masyu, `levelIndex 1, step 2`, `modifierType 'prism'`
("Inverted Pearls") — `daily_challenge_manager.dart:486-494`. Day-1 (dayInWeek 1) maps masyu
to the Hard slot → daily level `1 + 2*2 = 5` → `kMasyuLevels[5]` (a 5×5 hand-authored puzzle).

'prism' is implemented **inconsistently**: the pearl white↔black swap is applied only in the
validator (`masyu_screen.dart:794-800`) and painter (`:1443-1445`), but **not** in board load
(`_setupLevel`), the solver (`_solveMasyu` ~`:520-530`), or hints (`_showHint` ~`:918`). A
Masyu puzzle is not invariant under a black/white pearl swap, so the inverted board generally
has no valid loop. Brute-force (same rules as the app's own solver) confirms: original grid =
1 unique loop; **prism-inverted grid = 0 solutions**. No player input can pass validation.

**Fix — DECIDED: Option 2b (visual-only inversion). Keep "Inverted Pearls" as a modifier.**

Invert only the **rendered pearl colours** (black pearls drawn white, white drawn black) while
keeping the **actual solve rules on the true pearl types**. The board stays the original,
guaranteed-solvable puzzle; the player sees swapped colours and must mentally flip them. The
validator, solver, and hints all operate on the true types, so they always agree and the
puzzle is always solvable — while still delivering a genuine "Prism Day" cognitive twist.

Concretely:
1. **Keep** the paint swap in the painter (`masyu_screen.dart:1443-1445`) — this is what makes
   the colours look inverted on screen.
2. **Remove** the pearl swap in the validator (`masyu_screen.dart:794-800`) so win-checking
   uses the true pearl types (the original solvable solution). This is the line that currently
   demands the impossible inverted-rule solution.
3. **Leave** `_setupLevel` (board load), `_solveMasyu`/`_countMasyuSolutions`, and `_showHint`
   unchanged — they already use the true `_grid`, so after step 2 all four paths (load, paint,
   validate, hint) are consistent.
4. Keep the modifier description "Inverted Pearls" but make the copy explicit that the twist is
   **visual**, e.g.: *"Pearl colours are swapped — black pearls appear white and white pearls
   appear black. The rules are unchanged; read the colours in reverse."* (edit the
   `modifierDescription` for Week 13 Hard masyu in `daily_challenge_manager.dart:486-494`, or
   the masyu branch of the description-override block if one is added).

Net effect: no board is ever unsolvable, `_tryAutoCheck` (`:870-880`) fires correctly on a true
completed loop, and the "Inverted Pearls" modifier is retained.

> Rejected alternative (kept for reference — do NOT implement unless the design changes):
> genuinely inverting the rules would require swapping pearls at board load, running
> `_countMasyuSolutions`, and falling back to another puzzle when the inverted board has 0
> solutions. More work and needs puzzles verified to survive inversion; not worth it for the
> same visible payoff.

### 9b. Remove the Verify button (auto-check already works)
**Root cause:** `masyu_screen.dart:1283-1294` renders an `ElevatedButton.icon("Verify")`
(only when `_playDailyMode && _dailyModifierType == 'prism'`). It's redundant: `_onPanEnd`
(`:687`) already calls `_tryAutoCheck()` (`:870-880`) after every drag, which validates and
triggers `_onLevelCleared`/`ChallengeClearedOverlay` (`:1301-1314`).

**Fix:** Delete the button block (`:1283-1294`). The `Row` then holds only Reset — switch its
`MainAxisAlignment` to `center` (or wrap it) so Reset stays centered. No other change needed
for auto-check.

---

## 5. Chimp rotates into Hard + level frozen (Weeks 5, 11, 14) (P1)

**Symptom:** Week 5 Chimp Test reaches the Hard slot; its level never changes (Easy = Medium =
Hard, all 5 numbers).

**Root cause:** `daily_challenge_manager.dart:219-227` — Week 5 (Glitch Day) chimp is Easy,
`step: 0`, **no `pinDifficulty`**. In `_slotAssignment` (`:1112-1132`) only pinned games
reserve a slot; unpinned chimp is a *free* game and rotates through **all three** free slots
across the week, so it lands in Hard on some days. `level = levelIndex + slot*step` (`:1059`)
with `step:0` → level always 1. The stale doc comment at `:54` ("0 = pinned to Easy") is never
applied. **Weeks 11 (`:416`) and 14 (`:509`) have the same bug** (only Week 5 was noticed).

Chimp level→difficulty (`patches_screen.dart:28-36,166-181`): `_levels` = (gridSize,
numberCount); level 1→5 nums, 2→6, 3→7. A positive `step` yields genuinely different puzzles.

**Fix (no `_slotAssignment` changes needed):** Pin the Hard-slot game to slot 2 so only chimp
+ the medium game remain free and rotate strictly through {Easy, Medium} — never Hard. Then
give chimp a positive `step` so Easy ≠ Medium.

Week 5 (Glitch Day, `:217-246`):
```dart
easy: _ChallengeData(gameId: 'chimp', difficulty: 'Easy', levelIndex: 1, step: 1, ...),
//                                                          ^^^ was 0 → Easy=lvl1(5), Medium=lvl2(6)
hard: _ChallengeData(gameId: 'queens', difficulty: 'Hard', levelIndex: 2, step: 3,
                     pinDifficulty: 2, ...),   // ADD: pin queens to Hard
```
Apply the same pattern to Week 11 (pin Hard `color_flood` at `:424` with `pinDifficulty: 2`,
set chimp `step > 0` at `:419`) and Week 14 (pin Hard `sudoku` at `:517`, chimp step at
`:512`). Optionally fix the stale comment at `:54`. Verified by hand: with the Hard game
pinned, `freeGames=[chimp, mediumGame]`, `freeSlots=[0,1]`, and chimp alternates Easy/Medium
day-to-day, never Hard.

---

## 2. Star Battle — mirror modifier is a no-op (P1)

**Symptom:** Week 2 (Mirror Day) Star Battle plays identically to normal.

**Root cause:** The modifier is wired correctly (`star_battle_screen.dart:730,732,1030,
1036-1037` → `_activeModifiers = {'mirror'}`), but it's applied to **both** the render and the
input, so they cancel:
- Render maps visual col → data col: `:1631` `final col = _activeModifiers.contains('mirror')
  ? (_level.n - 1 - c) : c;` (+ mirrored borders `:1646-1670`).
- Input handlers do the inverse remap back: onTapUp `:1590-1592`, onPanStart `:1603-1605`,
  onPanUpdate `:1616-1617`.

Net: the tapped cell equals the rendered cell, identical to non-mirror. Because each daily
board is freshly procedurally generated there's no reference orientation, so a consistently
flipped board is indistinguishable from an unflipped one.

**Fix:** Break the symmetry — keep the render mirror (`:1631` + borders `:1646-1670`, matching
the "grid is visually flipped left-to-right" copy) and **remove the input-side compensation**
so taps use the raw on-screen column. Delete the
`if (_activeModifiers.contains('mirror')) { col = _level.n - 1 - col; }` blocks in onTapUp
(`:1590-1592`), onPanStart (`:1603-1605`), onPanUpdate (`:1616-1618`). Keep exactly one side
mirrored, never both.

---

## 3, 4 & 4b. "Level N" shown in daily mode — 5 beta games (P2)

**Symptom:** Top-right header shows "Level N" + an editable pencil in daily-challenge mode
instead of a daily indicator. Confirmed in **five** `beta/` game screens (you reported the
first two; the codebase sweep found the same bug in three more). The fully-built game screens
(sudoku, spectrum, word_hive, masyu, mine_finder, bridges, grid_path, patches, star_battle,
odd_color_out) all handle this correctly — only these five `beta/` screens miss it.

**Reference (correct pattern):** `sudoku_screen.dart:2113-2140` uses a 3-way label
`_isTutorialMode ? 'Tutorial' : _playDailyMode ? 'Daily' : 'Level ${_levelIndex + 1}'` and
gates the edit pencil with `if (!_isTutorialMode && !_playDailyMode)` (`:2132`).

Apply the same two changes to each file:

| Game | File | Label line | Edit-icon (pencil) line |
|------|------|-----------|----------------------|
| Pattern Lock  | `beta/pattern_lock_beta.dart`  | `:709-710` | `:717` |
| Colour Link   | `beta/numberlink_beta.dart`    | `:772-773` | `:780` |
| Color Flood   | `beta/color_flood_beta.dart`   | `:793`     | `:800-803` |
| Circuit Guide | `beta/circuit_guide_beta.dart` | `:1022`    | `:1029-1032` |
| Killer Sudoku | `beta/killer_sudoku_beta.dart` | `:670`     | `:671-672` |

- **Label** → `_isTutorialMode ? 'Tutorial' : (_playDailyMode ? 'Daily' : 'Level ${_currentLevel + 1}')`
- **Edit-icon guard** → wrap the pencil `Icon` (and its leading `SizedBox`) in
  `if (!_isTutorialMode && !_playDailyMode) ...`

Notes:
- **Killer Sudoku** has no `_isTutorialMode` in this header, so drop that term:
  label `:670` → `_playDailyMode ? 'Daily' : 'Level ${_currentLevel + 1}'`, and wrap
  `:671-672` (the `SizedBox(width: 4)` + `Icon(Icons.edit)`) in `if (!_playDailyMode) ...`.
- Pattern Lock / Colour Link already load `_playDailyMode`/`_dailyModifierDifficulty` in state;
  color_flood / circuit_guide / killer_sudoku read `_playDailyMode` already. Optionally show
  `_dailyModifierDifficulty` instead of the literal `'Daily'` when non-empty.

---

## 7. Week banner describes one game instead of the week (P2)

**Symptom:** The theme banner at the top of the Daily screen shows a single game's modifier
text (e.g. "The pattern lock grid and visual preview lines are horizontally mirrored") rather
than a general description of the week's theme.

**Root cause:** `daily_screen.dart:886` — `activeDesc = _challenges.first.modifierDescription`
(the Easy challenge's per-game text), rendered at `:935`.

**Fix:** Add a per-theme general blurb and show that instead.

In `daily_challenge_manager.dart`, add a lookup keyed by theme (or a `themeDescription` field
on `_DayData`) and expose it:
```dart
static const Map<String, String> _kThemeBlurbs = {
  'Fog Day':        'A heavy fog covers every board this week — visibility is limited to a small area around your cursor across all three puzzles.',
  'Mirror Day':     'Boards are flipped and mirrored left-to-right this week. Expect reversed layouts and controls in each daily puzzle.',
  'Monochrome Day': 'Colour is drained to shades of grey this week. Judge every puzzle by brightness alone.',
  'Retro Day':      'Everything is rendered in blocky, pixelated retro style this week.',
  'Glitch Day':     'Boards briefly glitch, shift and corrupt this week — memorise fast and adapt.',
  'Whisper Day':    'Key clues are hidden or blanked out this week; deduce the missing information.',
  'Hidden Rule Day':'A secret extra rule applies to each puzzle this week — figure out what it is.',
  'Zoom Day':       'Boards are zoomed in this week; pan and drag to see the whole puzzle.',
  'Eclipse Day':    'The board darkens in and out this week — plan your moves during the lit windows.',
  'Spy Day':        'One clue is a decoy/lie this week; find it and work around it.',
  'Chaos Day':      'Colours and tiles shuffle mid-solve this week — stay adaptable.',
  'Nightmare Trial':'Minimal clues, maximum difficulty this week. Only the essentials are given.',
  'Prism Day':      'Colour and pearl rules are twisted this week — assumptions are inverted.',
  'Time Warp Day':  'The clock is against you this week; boards change or vanish on a timer.',
};

static String themeDescriptionOf(int globalDay) =>
    _kThemeBlurbs[themeOf(globalDay)] ?? 'Special rules apply to all game boards this week.';
```
In `daily_screen.dart`, replace the `activeDesc` computation (`:886`) with:
```dart
final activeDesc = DailyChallengeManager.themeDescriptionOf(_activeDay);
```

---

## B. `minefinder` gameId typo → fog/zoom/whisper copy never applies (P2)

**Root cause:** `daily_challenge_manager.dart:1066, 1076, 1092` branch on
`gameId == 'minefinder'`, but the real id in `kAllGames` and the plan is `minesweeper`
("Mine Finder" is only the display name). These branches never match, so Day-1 Hard
(minesweeper + fog) falls through to the generic `else` (`:1069`) instead of the mine-specific
copy.

**Fix:** Change every `'minefinder'` → `'minesweeper'` at `:1066, :1076, :1092`.

---

## C. Generic fog override clobbers authored descriptions (P3)

**Root cause:** `daily_challenge_manager.dart:1061-1097` — for a fog challenge whose gameId
isn't sudoku/killersudoku/minesweeper, the `else` at `:1069` overwrites the hand-written
`modifierDescription` with generic text (e.g. Day-1 Easy oddcolor's authored fog copy is
replaced).

**Fix:** Only override when game-specific copy actually exists; otherwise keep
`c.modifierDescription`. E.g. drop the catch-all `else` branches so the authored text stands.

---

## D. Wrong daily-backup key in "Replay Game" (P2)

**Root cause:** `game_completed_screen.dart:144` — `prefs.remove('daily_backup_$prefKey')`
where `prefKey` is already the full level key (e.g. `level_hangman`), producing
`daily_backup_level_hangman`. The real key is `daily_backup_<gameId>` (`daily_backup_hangman`).
The remove is a no-op, so the stale daily backup + `daily_backup_active_game` survive and
`main.dart:100-108` re-applies the stale level on next launch, undoing the reset at `:143`.

**Fix:** Derive the gameId (strip the `level_` prefix) and remove `daily_backup_<gameId>` plus
`daily_backup_active_game`:
```dart
final gameId = prefKey.startsWith('level_') ? prefKey.substring(6) : prefKey;
await prefs.remove('daily_backup_$gameId');
await prefs.remove('daily_backup_active_game');
```

---

## E. Sum Strike — daily win never registers (completion race) (P0)

**Symptom:** Completing a Sum Strike daily challenge (Week 6 Whisper Day, Hard) may not mark
the daily complete, and the game's own level counter is wrongly bumped. (Separate from the
inverted-life bug in #6 — this is the *win* path.)

**Root cause:** `lib/screens/games/sum_strike/sum_strike_screen.dart:1018-1023` — on success the
body renders `AutoNextCountdown(onNext: _nextLevel)` **without** gating on `!_playDailyMode`
(contrast `patches_screen.dart:767`, which gates its equivalent). In daily mode this countdown
races the `ChallengeClearedOverlay` pop-`true` path (`:1045-1053`). When the countdown fires,
`_nextLevel` (`:582-590`) increments `_currentLevel` and calls `_generatePuzzle`, which resets
`_isSuccess = false` (`:335`). That reset flips the overlay's `if (_isSuccess && _playDailyMode)`
condition false and dismisses it **before** its `onComplete → Navigator.pop(context, true)`
runs. Result: `daily_screen._playChallenge` gets no `true`, so `completeChallenge` never fires.

**Fix:** Gate the in-body countdown like Chimp does — at line 1019, only show
`AutoNextCountdown` in non-daily mode, so daily wins go solely through the `ChallengeClearedOverlay`
pop-`true` path:
```dart
child: (_isSuccess && !_playDailyMode)
    ? AutoNextCountdown(onNext: _nextLevel, accentColor: ...)
    : ElevatedButton(...),   // existing non-countdown branch
```
(Whatever the existing else-branch is, keep it; the change is adding `&& !_playDailyMode` so
`_nextLevel` never runs in daily mode.)

---

## Codebase sweep — coverage & what's clean

All 16 daily-plan games were audited for three bug classes (header, modifier-applied,
completion). Results:

- **Completion (`pop(true)` on daily win):** clean for **15/16** games. The only defect is
  **Sum Strike (#E above)**. This was the highest-risk class (a miss means the daily can never
  complete) — good news that it's isolated.
- **Header (daily indicator vs "Level N"):** the **5 `beta/` games** in #3/#4/#4b are the only
  offenders; all fully-built screens are correct.
- **Modifiers (weeks 1-14):** of **42** (modifier, game) pairs in the active weeks, exactly
  **2** are broken — `masyu + prism` (#9, unsolvable) and `star_battle + mirror` (#2, no-op).
  The other **40 apply real effects**. No additional dead modifiers.
- **Dormant modifiers:** games reference modifier types like `spotlight/swap/mutation/blind/`
  `aurora/spotlight2/grand_finale/ghost/echo/ice/illusion` that are **unimplemented**, but these
  belong to **weeks 15-30, which never run** (`kThemeCount = 14`). They are **not bugs today** —
  but they become dead modifiers the moment you raise `kThemeCount`. If you ever extend past 14
  weeks, implement those effects (or remap those weeks) first.
- **Minor, non-blocking (not fixed here):** `bridges_screen.dart:1123` rebuilds a
  `TransformationController` every `build()` (perf smell); `grid_path_screen.dart:905` and
  `odd_color_out_screen.dart:821` render `Icon(null)` for the normal-mode level-edit pencil (a
  cosmetic no-op); `spectrum_screen.dart:425` lets the daily "Daily Challenge" label still open
  a jump-to-level dialog (not `kDebugMode`-gated). Note only.

---

## Suggested implementation order

1. **P0 unwinnable/score-corrupting:** #1 (streak), #A (star counters), #6 (Sum Strike life),
   #E (Sum Strike completion race), #8 (Killer Sudoku L3),
   #9 (Masyu — apply 9a Option 2b visual-only inversion + remove Verify button).
2. **P1 modifiers:** #5 (Chimp slot/level, all 3 weeks), #2 (Star Battle mirror).
3. **P2/P3 polish:** #3/#4/#4b (headers, 5 beta games), #7 (week banner), #B (minefinder),
   #D (backup key), #C (fog copy).

Re-test each daily challenge with the in-app **Developer Debug Controls** (Day ±1 / Week +1),
and after any `weeklyLastPerfectDate` change, run **Reset All** once and verify a clean
7-perfect-day → diamond.

---

# Appendix A — Full per-game daily-mode audit (all 16 games)

Every game that appears in the active weekly plan (weeks 1-14) was audited for three daily-mode
bug classes. `OK` = correct; `DEFECT (#n)` = see the fix with that number above.

- **HEADER** — daily mode shows a daily indicator (not "Level N" + edit pencil).
- **MODIFIER** — the game reads `_dailyModifierType` and applies a real effect for every
  modifier it uses in weeks 1-14.
- **COMPLETION** — a daily win calls `Navigator.pop(context, true)` so `daily_screen` marks the
  challenge complete.

| gameId | screen file | HEADER | MODIFIER | COMPLETION |
|--------|-------------|--------|----------|------------|
| oddcolor | `odd_color_out/odd_color_out_screen.dart` | OK | OK | OK |
| sudoku | `sudoku/sudoku_screen.dart` | OK | OK | OK |
| minesweeper | `mine_finder/mine_finder_screen.dart` | OK | OK | OK |
| zip | `grid_path/grid_path_screen.dart` | OK | OK | OK |
| queens (Star Battle) | `star_battle/star_battle_screen.dart` | OK | **DEFECT (#2)** mirror no-op | OK |
| hue | `spectrum/spectrum_screen.dart` | OK | OK | OK |
| spellingbee (Word Hive) | `word_hive/word_hive_screen.dart` | OK | OK | OK |
| chimp (Patches) | `patches/patches_screen.dart` | OK | OK¹ | OK |
| sumstrike | `sum_strike/sum_strike_screen.dart` | OK | OK | **DEFECT (#E)** + life bug (#6) |
| bridges | `bridges/bridges_screen.dart` | OK | OK | OK |
| masyu (Pearl Loop) | `masyu/masyu_screen.dart` | OK | **DEFECT (#9)** prism unsolvable | OK |
| pattern_lock | `beta/pattern_lock_beta.dart` | **DEFECT (#3)** | OK | OK |
| colour_link (Colour Link) | `beta/numberlink_beta.dart` | **DEFECT (#4)** | OK | OK |
| color_flood | `beta/color_flood_beta.dart` | **DEFECT (#4b)** | OK | OK |
| circuit_guide | `beta/circuit_guide_beta.dart` | **DEFECT (#4b)** | OK | OK |
| killersudoku | `beta/killer_sudoku_beta.dart` | **DEFECT (#4b)** | OK | OK (board data bug #8) |

¹ Chimp's modifiers apply correctly; its separate slot/level rotation issue is #5.

**Class tallies:** HEADER 5 defects (all `beta/`) · MODIFIER 2 defects (star_battle, masyu) ·
COMPLETION 1 defect (sumstrike). Everything else verified clean.

---

# Appendix B — Modifier coverage matrix, weeks 1-14

Of the **42** (modifier, game) pairs used in the active weeks, **40 are IMPLEMENTED** (read the
modifier and apply a real visual/behavioural effect) and **2 are broken** (#2, #9). No other
silent-dead modifiers exist in weeks 1-14.

| modifier | game → status (file:line) |
|----------|---------------------------|
| fog | oddcolor✔ (odd_color_out:864) · sudoku✔ (:2261) · minesweeper✔ (mine_finder:71) |
| mirror | zip✔ (grid_path:55,1096) · pattern_lock✔ (:206,382) · **queens = no-op (star_battle:1590-1660 render+input cancel → #2)** |
| monochrome | oddcolor✔ (:122) · hue✔ (spectrum:256) · colour_link✔ (numberlink:44) |
| retro | oddcolor✔ (:901) · circuit_guide✔ (:1082) · zip✔ (grid_path:1184) |
| glitch | chimp✔ (patches:210,746) · sudoku✔ (:1838,2506) · queens✔ (star_battle:1075,1580) |
| whisper | oddcolor✔ (:161) · spellingbee✔ (word_hive:457,493) · sumstrike✔ (sum_strike:235,902) |
| hidden_rule | oddcolor✔ (:209) · minesweeper✔ (mine_finder:352,656) · queens✔ (star_battle:640,918) |
| zoom | queens✔ (star_battle:1552,1790) · sudoku✔ (:2223) · bridges✔ (:1050,1114) |
| eclipse | oddcolor✔ (:333,924) · pattern_lock✔ (:211,796) · sudoku✔ (:1165) |
| spy | spellingbee✔ (word_hive:460,731) · queens✔ (star_battle:1220,1267) · killersudoku✔ (:394,472) |
| chaos | oddcolor✔ (:348) · chimp✔ (patches:422) · color_flood✔ (:517) |
| minimal | spellingbee✔ (word_hive:1147) · sudoku✔ (:1549) · zip✔ (grid_path:562) |
| prism | oddcolor✔ (:221) · hue✔ (spectrum:125,510) · **masyu ✘ BROKEN (validator swap → unsolvable → #9)** |
| time_warp | oddcolor✔ (:113,481) · chimp✔ (patches:62,228) · sudoku✔ (:1632,2164) |

✔ = implemented · ✘ = broken/unsolvable · "no-op" = present but self-cancelling.

**Dormant (not counted, not bugs today):** games also reference `spotlight, swap, mutation,
blind, aurora, spotlight2, grand_finale, ghost, echo, ice, illusion, restriction, magnet,
encryption, matrix, gravity` — these belong to **weeks 15-30, which never run**
(`kThemeCount = 14`). They are unimplemented no-ops but unreachable. **If you ever raise
`kThemeCount` above 14, implement these (or remap those weeks) before shipping** — otherwise
they become live dead modifiers.

---

# Appendix C — Issue index

17 issues total: 9 reported + 4 from the IAP/daily audit + 2 Sum Strike (life + completion) +
2 from the game sweep (header extends to 5 games; Sum Strike completion). Full list with
priorities is in the **Priority summary** table at the top.

---
---

# PART 2 — Non-daily (free-play) core gameplay audit

Separate sweep of every game's **normal free-play** mechanics — win/loss detection, level data
& solvability, level persistence, scoring, the hint system, and crash/leak robustness. Daily
mode was covered in Part 1 and is not repeated here.

**Scope:** the 16 games in the active daily pool (`oddcolor, sudoku, minesweeper, zip,
pattern_lock, queens/star_battle, hue/spectrum, colour_link, circuit_guide, chimp/patches,
spellingbee/word_hive, sumstrike, bridges, killersudoku, color_flood, masyu`) plus shared
systems (`point_manager`, `hint_manager`, `buy_hints_dialog`, `shuffle_manager`,
`achievement_manager`, `main.dart` recovery). **Not covered:** games that exist in the app but
never appear in weeks 1-14 (e.g. wordle, hangman, memory, sequence, flagle, numbermemory,
wordbuilder, weaver, crossclimb, connections, kakuro, hitori, slitherlink, cipherdecoder).

## Part 2 priority summary

| # | Bug | Priority | File |
|---|-----|----------|------|
| CG-1 | Killer Sudoku **level 4 unwinnable** (impossible cage sum 10) | **P0** | killer_sudoku_beta.dart |
| CG-2 | Sudoku **normal Level 24 corrupt board** — unwinnable | **P0** | sudoku_screen.dart |
| CG-3 | Killer Sudoku **normal progress never persists** (wrong prefs key) | **P0** | killer_sudoku_beta.dart |
| CG-4 | Masyu & Bridges: **daily clear corrupts normal saved level** (missing daily guard) | **P0** | masyu_screen.dart, bridges_screen.dart |
| CG-5 | Spectrum **move-limit makes 6×6+ levels unwinnable** | **P1** | spectrum_screen.dart |
| CG-6 | Killer Sudoku level 2 intended solution has cage duplicate (hint broken) | P1 | killer_sudoku_beta.dart |
| CG-7 | **Hint system broken/misleading across ~9 games** (see grouped list) | **P1** | hint_manager.dart + 8 game files |
| CG-8 | Word Hive: **center-letter reuse blocked** → many target words unenterable | P1 | word_hive_screen.dart |
| CG-9 | Odd Color Out: odd delta swamped by noise / imperceptible at high levels | P2 | odd_color_out_screen.dart |
| CG-10 | `setState`-after-dispose (no `mounted` guard) in clear/hint paths | P2 | 6 game files |
| CG-11 | Sum Strike: Reset button doesn't restore lives; win not persisted at overlay | P2 | sum_strike_screen.dart |
| CG-12 | Chimp: uncancelled exposure timer; time-up reload not in setState | P3 | patches_screen.dart |
| CG-13 | Assorted robustness/tuning (gen fallbacks, minesweeper first-tap hint, etc.) | P3 | various |

---

## CG-1. Killer Sudoku — level 4 (index 4) is mathematically unwinnable (P0)

`killer_sudoku_beta.dart:373-374`. Cage 4 = cells {9,10,14} (3 cells) with `_cageSums[4] = 10`.
In a 4×4 killer sudoku a cage needs distinct digits 1-4; max sum of 3 distinct is 4+3+2 = **9**.
No legal fill reaches 10, so `_checkSolution` (sum == cageSum + no-dup) can never pass — hard
progression stop in free play (only escapable via Jump-to-Level). The stored `_solution[4]` also
has duplicates in cages 3 & 4, so hints build an invalid board too.
**Fix:** re-derive the cage layout/sums for this level from a legal no-duplicate solution.

## CG-2. Sudoku — normal Level 24 (`_levelIndex == 23`) loads a corrupt board (P0)

`sudoku_screen.dart:970-988` (the 6×6 entry → `levels6[13]`, reached at `_levelIndex 23` via
`_getSudokuLevel`, `:1503`). Two defects:
- Solution row 5 = `[5,4,6,3,3,2]` (`:986`): digit `3` duplicated, `1` missing — not a valid
  6×6 solution.
- `startBoard[4][1] == 1` (`:939`) but `solution[4][1] == 3` — a locked given contradicts the
  solution, and column 1 has two `1`s (visibly impossible).

`_checkBoard` requires every cell == `_level.solution`, so the win can never fire → permanent
free-play progression blocker. **Fix:** replace with a valid, self-consistent 6×6 board.
(A second malformed 6×6 at `:1027-1045` maps to `levels6[16]`, which is unreachable — indices
0-14 only — noted for completeness.)

## CG-3. Killer Sudoku — normal-mode level never persists (P0)

`killer_sudoku_beta.dart`. `_initLevelState` reads `prefs.getInt('level_killersudoku')` (`:52`),
but nothing ever **writes** that key. On clear, `_onLevelCleared` writes `beta_level_killersudoku`
(`:407`), which is only read back as `highest` (`:405`) and never assigned to `_currentLevel`.
`_nextLevel` (`:424`) and Jump-to-Level only mutate memory. → **all killer-sudoku free-play
progress is lost on app restart** (resets to Level 1).
**Fix:** write `PrefsKeys.gameLevel('killersudoku')` (== `level_killersudoku`) in
`_onLevelCleared`, like every other game.

## CG-4. Masyu & Bridges — a daily clear corrupts normal saved level (P0, daily→normal leak)

`masyu_screen.dart:908-916` and `bridges_screen.dart:584-592`. Their `_nextLevel` has **no**
`_playDailyMode` guard (Star Battle has one at `star_battle_screen.dart:1320`), so it always
`_currentLevel++` and persists `gameLevel('masyu'/'bridges')`. On a daily clear both screens
mount `AutoNextCountdown` (masyu `:1258`, bridges `:1137`) which auto-fires `onNext` after ~1s
**even hidden under the `ChallengeClearedOverlay`**. Since `_currentLevel` is read from the
normal `gameLevel(...)` key even in daily mode, a **daily win silently advances and saves the
player's normal progress by one**, skipping a level they never played.
**Fix:** add to both `_nextLevel` methods, at the top:
```dart
if (_playDailyMode) { Navigator.pop(context, true); return; }
```
(Same class as Sum Strike #E. Recommend grepping every `AutoNextCountdown` user and confirming
it is gated by `!_playDailyMode` in the build **and** the `_nextLevel` has this guard.)

## CG-5. Spectrum (hue) — move-limit makes 6×6+ levels unwinnable (P1)

`spectrum_screen.dart:394-395` — `_movesLeft = 15 + (_rows * _cols ~/ 3)`. Winning needs to
fully sort the scramble (~N − H_N minimum swaps, more for a casual player). 6×6 (levels 30-44):
32 tiles, budget 27 → often impossible. 7×7: 45 tiles, budget 31 → impossible for ~every board.
10×10: 96 tiles, budget 48 → impossible. `moveLimit` is drawn frequently from a 6-item pool, and
exhaustion just regenerates another impossible board (stuck loop).
**Fix:** scale the budget off the actual scramble distance (`_minSwapsToSolve(scramble) + buffer`)
or drop `moveLimit` for grids larger than ~4×4.

## CG-6. Killer Sudoku — level 2 (index 2) intended solution has a cage duplicate (P1)

`killer_sudoku_beta.dart:367-368`. Cage 1 = {1,2,6}; `_solution[2]` puts `{3,1,3}` there
(duplicate 3). A valid no-dup fill exists ({1,2,4}=7), so it's solvable by hand, but
`_checkSolution` rejects the stored solution and `_showHint` fills the contradictory values →
hint feature broken. Distinct from CG-1 and the already-known level-3 dup (#8 in Part 1).
**Fix:** supply a solution/cage set with no in-cage duplicates. (Recommend a debug-time
assertion that validates all hardcoded killer boards — would catch levels 2, 3, and 4 at once.)

## CG-7. Hint system — broken or misleading across ~9 games (P1)

The biggest cross-cutting theme. Two shared-layer bugs plus per-game hint defects.

**Shared (`hint_manager.dart`) — both HIGH:**
- **No-hint tracking is dead → "Flawless" false-unlocks.** `useHint` (`:34-42`) sets
  `_hintUsedThisLevel[gameId]=true`, then calls `getHints`, which **resets that flag to false**
  (`:17`). On clear the flag is always false, so `AchievementManager.registerClear(gameId,false)`
  bumps `no_hint_clears` on **every** clear — "Flawless" (25 no-hint clears) unlocks for a player
  who hinted every level.
- **Clear-streak wiped after nearly every clear → "On a Roll" (15) unreachable.** `getHints`
  also gates `resetClearStreak()` on `_lastClearWasSuccessful==false` then flips it false; games
  refresh the hint count right after a clear (e.g. `odd_color_out_screen.dart:469`), so the
  streak oscillates 1→0→1→0.
- **Root cause (MED):** `getHints()` is a *mutating* method (resets per-level flag, resets
  streak, lazy-inits) used everywhere as a pure getter. **Fix:** add a side-effect-free
  `peekHints()` for display, and move the resets into explicit `startLevel()` / fail hooks.

**Per-game hint defects:**
| Game | Bug | file:line |
|------|-----|-----------|
| Masyu | Hint charged even when solver returns empty; DFS capped at 10000 steps fails on 8×8/9×9 → can burn entire hint balance for nothing | masyu_screen.dart:1122-1126, solver :539-541 |
| Circuit Guide | Hardcoded `_solutionRotations` for levels 1-5 don't connect the source → hint flashes misleading tiles, wastes token (board still solvable) | circuit_guide_beta.dart:206-221, :540, :862-869 |
| color_flood | Hint BFS seeds from cell 0, but levels ≥30 always use `centerSeed` (grid center) → suggests a colour not touching the blob; with zero-margin budget can force a loss | color_flood_beta.dart:628-631 |
| Pattern Lock | Hint compares/needs untransformed `_targetPattern`, but endgame (≥30) requires the transformed sequence → flashes wrong dot, wastes token | pattern_lock_beta.dart:574-593 vs :382-384 |
| Bridges | Charge-before-check ordering; hint solves from scratch ignoring current placement → can remove player's legit bridges or create a crossing state | bridges_screen.dart:958-961, :780, :813 |
| Word Hive | `_useHint` can point at an un-formable word (center-letter/doubled-letter, see CG-8) | word_hive_screen.dart:670-675 |
| Sum Strike | A hint that completes the board doesn't call `_tryAutoCheck` → soft-lock (all cells correct, none tappable) | sum_strike_screen.dart:592-611 |
| Killer Sudoku | Hint fills the invalid stored solution on levels 2/3/4 (see CG-1, CG-6, Part 1 #8) | killer_sudoku_beta.dart:594 |

**Common fixes:** (1) only decrement/consume a hint when the hint was actually applied (return a
bool from `_showHint`/`_useHint` and gate the charge on it) — this alone fixes Masyu, Bridges,
Circuit Guide, Pattern Lock partial cases; (2) make hints respect the active transform/seed and
current placement; (3) call the auto-check after applying a hint.

## CG-8. Word Hive — center-letter reuse blocked, many target words unenterable (P1)

`word_hive_screen.dart:1280` — the center-letter `onTap` bails `if (_selectedIndices.contains(0))
return;`. Every valid word must contain the center letter, and many targets contain it 2+ times
(center 'T' → TART, TAROT, TATTOO) — those can't be entered by tapping (silently ignored). Drag
input (`:829`) only blocks the *consecutive* same tile, so tap and drag disagree, and words with
adjacent doubled letters (OTTO, ACCEPT) are unenterable by either method. Shrinks the usable word
pool invisibly.
**Fix:** allow re-tapping the center tile (match the outer-letter `onTap`, which has no guard),
pick one consistent reuse rule across tap and drag, and skip un-formable words when choosing a
hint. Also add a guard so `_targetCount` can't degenerate to 0 (`:488-502`).

## CG-9. Odd Color Out — odd tile becomes ambiguous / imperceptible at high levels (P2)

`odd_color_out_screen.dart:157` — `delta` shrinks with level; combined with per-cell noise
(`:256-264`, ±0.015 lightness / ±7.5° hue) the odd tile's distinguishing shift falls **below**
the noise amplitude at L≳80, so ordinary tiles differ from neighbours more than the odd tile does
→ no unique answer. At L≈120-149 the delta (~0.008 lightness) is imperceptible even without noise.
**Fix:** floor `delta` above the active noise amplitude and above a perceptible minimum
(~0.03 lightness / ~8° hue), or disable noise once delta is small.

## CG-10. `setState` after dispose — no `mounted` guard in clear/hint paths (P2, crash risk)

Each does `setState` after `await`s (prefs/HintManager) with no `if (mounted)` check; leaving the
screen during the await window throws "setState after dispose":
`sudoku_screen.dart:1423-1429` & `:1966`, `mine_finder_screen.dart:599-606`,
`killer_sudoku_beta.dart:594`, `numberlink_beta.dart:524`, `pattern_lock_beta.dart:471`,
`circuit_guide_beta.dart:811`.
**Fix:** add `if (!mounted) return;` before each post-await `setState`.

## CG-11. Sum Strike — lives/persistence gaps (P2)

`sum_strike_screen.dart` (separate from the two known bugs in Part 1 #6/#E):
- **Reset button doesn't restore `_lives`** (`:1031-1037`) — a fresh board but a depleted life
  count; not a true retry. Fix: set `_lives = 3` in the Reset `onPressed`.
- **Level not persisted at win** — `gameLevel('sumstrike')` is written only in `_nextLevel`
  (`:587-589`), after the countdown; killing the app on the success overlay loses the clear.
  Fix: persist in `_onLevelCleared`.

## CG-12. Chimp / Patches — timer hygiene (P3)

`patches_screen.dart:229` — the timed-exposure `Timer` isn't stored or cancelled, so a stale
timer from the previous level can fire and prematurely hide numbers on the next (guarded against
crash, but wrong behaviour). `:247-254` — the time-up `_loadLevel()` isn't wrapped in `setState`
(board renders stale until next tick). Also `_decoyCells` is never populated (dead feature) and
`numbersHide` is inert on levels 30-44.
**Fix:** store the timer in a field and cancel in `_loadLevel`/`dispose`; wrap the reset in
`setState`.

## CG-13. Assorted robustness / tuning (P3)

- **Minesweeper first-tap hint** (`mine_finder_screen.dart:784-786`): if `_useHint` is the first
  action, mines are placed around the *center*, not the player's first real tap, which then has
  no safe-zone guarantee and can detonate immediately. Fix: don't generate mines around the
  center for a hint before the first real tap.
- **Killer endgame 9×9** (`killer_sudoku_beta.dart:206-269`): `_hasUniqueKillerSolution` caps at
  `maxStates = 4000` and returns false on overflow, so a 9×9 keeps adding givens until the board
  can load fully-filled and uncompletable (win only fires from a tap on a non-given cell). Bound
  the givens count or add a manual Check.
- **circuit_guide** (`:359-465`): if generation never succeeds (50×200 attempts, target placement
  not re-randomized) it ships the last disconnected board — no known-good fallback. Very unlikely
  but unbounded.
- **numberlink** (`:284-297`): a failed high-level generation hard-resets to a trivial 4×4/2-colour
  board — "Level 50" becomes trivially easy (still solvable). Difficulty degradation only.
- **color_flood** (`:681-682`): hint colour-name table has 6 names but up to 8 colours →
  "Try flooding with **Unknown** next!". Cosmetic.

---

## What was verified CLEAN in non-daily play

- **Points economy** (`point_manager.dart`): read-modify-write is atomic (no `await` between
  read and write on the single-threaded loop); no race, no negative balance, no double-award.
- **Hint purchase math** (`buy_hints_dialog.dart`): cost `qty*100`, consume-before-add, `+80`
  ad grant once. Correct.
- **Shuffle** (`shuffle_manager.dart`): no infinite navigation loop; consistent cache.
- **Achievement claim**: no double-claim/double-reward.
- **`main.dart` crash recovery**: no-op on normal launch → does not corrupt normal levels.
- **Win/loss detection**: Star Battle, Masyu, Bridges, Sudoku (reachable boards), Spectrum,
  color_flood, grid_path/zip, chimp, minesweeper all validate correctly (no false win/loss) —
  the failures above are level-**data** or **hint**/**persistence** bugs, not validator bugs.
- **Timers**: aside from the Chimp exposure timer (CG-12), periodic timers are cancelled in
  `dispose` and guard `mounted`.

## Cross-cutting patterns worth a single systemic fix

1. **Hint charging** — almost every hint bug shares one root: the game **charges the hint before
   confirming it applied**, and/or the hint uses a stale/invalid solution or ignores the active
   transform/seed. A shared "compute → if applicable, apply & charge; else no charge + message"
   contract across all `_showHint`/`_useHint` methods would fix most of CG-7 at once.
2. **AutoNextCountdown vs daily** — any screen that shows `AutoNextCountdown` on clear must gate
   both it and `_nextLevel` on `!_playDailyMode` (CG-4, Part 1 #E). Audit every user.
3. **Hardcoded puzzle data** — Killer Sudoku (levels 2,3,4) and Sudoku (level 24) ship invalid
   boards. A debug-time validator over all hardcoded level tables (unique/consistent solution,
   no dup-in-unit/cage, clue matches solution) would have caught every CG-1/CG-2/CG-6 and Part 1
   #8 at build time.
4. **`mounted` guards** — standardize `if (!mounted) return;` after every awaited call that
   precedes `setState` (CG-10).
