# CogniQ — Per-Game Modifier Start Levels, Challenge Mode & Description Copy

**Written:** 2026-08-24
**Verified against:** `github.com/mayank0201/flutter-projects` branch `v5_Puzzle`, commit `3bd34e1` — `pubspec.yaml` says **1.8.0+48**

**Related files:**
- `COGNIQ_FIXES_DAILY_TRAIL_GRIDPATH.md` — daily persistence (not a bug), trail toast, Grid Path
- `3_GAME_FIXES_FOR_1.8.3.md` — Colour Link, Chimp

Three changes are specified here:

| # | Change | Verdict |
|---|---|---|
| A | [Per-game modifier start levels](#a-per-game-modifier-start-levels) | **Fix — replace the global 30 with a per-game table** |
| B | [Challenge mode must honour every modifier](#b-challenge-mode-must-honour-every-modifier) | **Fix — live bug, not a tuning preference** |
| C | [Description copy must not be endgame-framed](#c-description-copy-must-not-be-endgame-framed) | **Fix — 3 competing surfaces, wrong one wins** |

Do them in order **C → A → B**; see [Order of work](#order-of-work) for why.

---

## The number that drives all three

Every modifier in the app is gated on **level ≥ 30**, hardcoded separately in each screen. Two things collide with that.

**One — challenge mode never reaches it.** Computed from the plan (`daily_challenge_manager.dart:1072-1090`):

```dart
int level = c.levelIndex + slot * c.step;   // slot is 0..2
if (m > 0) {
  level += (dayInWeek - 1) ~/ m;           // dayInWeek is 1..7, m is 1..3
}
```

Parsing every `_ChallengeData` in `_kDailyChallengesPlan`: `levelIndex` ∈ **{1,2,3,6,7}**, `step` ∈ **{1,3}**. Worst case `7 + 2×3 + 6` = **19**.

> **The maximum level any daily challenge can ever run at is 19. The modifier system starts at 30. They never overlap** — not on any day, in any week, for any slot.

**Two — 30 is far too late for normal play.** Board ramps top out long before it. Verified:

| Game | Board ramp | First step |
|---|---|---|
| Pattern Lock | `<5`→3, `<10`→4, `<20`→5 | **5** |
| Colour Link | `<5`→4, `<10`→5, `<20`→6, else 7 | **5** |
| Circuit Guide | `<5` branch, then bands from 35 | **5** |
| Color Flood | `<5`, `<10` steps | **5** |
| Grid Path | `<5`→3, `<15`→4, `<30`→5, else 6 | **5** |

Most games finish growing their board around level 20, then sit unchanged for ten levels before anything new happens. That dead stretch is the whole problem.

**Level 5 is the natural start** — it is where the board takes its first step in five of the games measured, including Circuit Guide.

---

## A. Per-game modifier start levels

### The mechanism

`RotationEngine` (1.8.0+48) has no start-level concept at all — `getActiveModifiers` takes a pool and a level and never checks a threshold; every screen hardcodes `>= 30` itself. Give the engine the table and delete 27 literals:

```dart
class RotationEngine {
  /// Level at which each game's modifier layer switches on.
  ///
  /// Tuned to each game's board ramp: modifiers begin once the board has taken
  /// its first size step, so fog/zoom/timer have something to act on, and long
  /// before the old global 30 -- which left every game static for the ten
  /// levels between "board stops growing" and "modifiers start".
  ///
  /// Challenge mode ignores this entirely: see modifierCountFor and
  /// _isModActive. Dailies run at level 1..19 and must still get their rule.
  /// EXHAUSTIVE over every game id that has ever shipped. Ids are stable
  /// forever (a game's display name may change -- 'Skyscrapers (Beta)' loses
  /// its suffix -- but the id never does), so an entry here never needs
  /// revisiting once written.
  static const Map<String, int> _modifierStartLevel = {
    // ================= grid puzzles: board steps at 5 =================
    'zip':           5,   // Grid Path      <5:3  <15:4  <30:5  else 6
    'oddcolor':      5,   // Odd Color Out
    'queens':        5,   // Star Battle
    'minesweeper':   5,   // Mine Finder
    'hue':           5,   // Spectrum
    'sudoku':        5,
    'spellingbee':   5,   // Word Hive
    'pattern_lock':  5,   //                <5:3  <10:4  <20:5
    'colour_link':   5,   //                <5:4  <10:5  <20:6  else 7
    'color_flood':   5,   //                <5,   <10 steps
    'circuit_guide': 5,   //                <5 branch, then bands from 35
    'bridges':       5,
    'sumstrike':     5,   // Sum Strike
    'killersudoku':  5,   // Killer Sudoku
    'kakuro':        5,   // pool is timer only today
    'hitori':        5,
    'slitherlink':   5,
    'nurikabe':      5,   // if present in your version
    'skyscrapers':   5,   // added 2.5 -- id keeps no '(Beta)' suffix

    // ============ memory / attention: modifier IS the mechanic ============
    'chimp':         3,   // Chimp Test
    'sequence':      3,   // Sequence Memory
    'numbermemory':  3,   // Number Memory
    'memory':        5,   // Mahjong Solitaire

    // ================= line / path games added in 2.4 =================
    'orbit':         5,
    'onestroke':     5,   // One Stroke

    // ==== word games: difficulty is vocabulary, not board size -> later ====
    'wordle':        8,   // Word Guess
    'weaver':        8,   // Word Ladder
    'crossclimb':    8,   // Word Climb
    'wordbuilder':   8,   // Word Builder
    'hangman':       8,
    'cipherdecoder': 8,   // Cipher Decoder
    'flagle':        8,   // Flag Finder

    // ========================= special cases =========================
    'masyu':         1,   // Pearl Loop -- fog/timer, exactly one, every level

    // 'reaction' is deliberately absent -- see "The one exclusion".
    // It is the ONLY id that may be missing. Everything else missing is a bug.
  };

  /// Ids that intentionally have no modifier layer. Kept explicit so the
  /// coverage test can tell "deliberately excluded" from "somebody forgot".
  static const Set<String> kNoModifierGames = {'reaction'};

  static int? modifierStartLevelRaw(String gameId) =>
      _modifierStartLevel[gameId];

  static int modifierStartLevel(String gameId) =>
      _modifierStartLevel[gameId] ?? 30;   // unknown id keeps the old behaviour

  /// How many modifiers to stack. Starting at the start level with 2-3 at once
  /// is brutal; ramp instead. Challenge mode always gets exactly its one
  /// authored modifier and never comes through here.
  static int modifierCountFor(String gameId, int level) {
    final start = modifierStartLevel(gameId);
    if (level < start) return 0;
    if (level < start + 10) return 1;   // one at a time while it's new
    if (level < 30) return 2;
    return 3;                            // unchanged endgame density
  }
}
```

The ramp matters as much as the start level. Turning on today's `minActive: 2, maxActive: 4` at level 5 would be worse than the status quo. **One modifier from the start level, two from +10, three from 30** keeps the endgame exactly as it is today and only fills the empty stretch below it.

### Wire it into `getActiveModifiers`

```dart
static Set<String> getActiveModifiers({
  required String gameId,
  required int levelIndex,
  required List<String> pool,
  int minActive = 2,      // kept for call-site compatibility; now a floor only
  int maxActive = 3,
  bool smallGrid = false,
}) {
  if (pool.isEmpty) return {};

  final want = modifierCountFor(gameId, levelIndex);
  if (want == 0) return {};                       // below this game's start level

  final rand = getDeterminism(gameId, levelIndex);
  var count = smallGrid ? want : want;            // small grids no longer force max
  count = count.clamp(1, pool.length);

  final poolCopy = List<String>.from(pool);
  poolCopy.shuffle(rand);
  return poolCopy.take(count).toSet();
}
```

> **Determinism warning.** `getDeterminism(gameId, level)` is unchanged, so a given level still shuffles identically — but `count` changes, so **the modifier set for existing levels 30+ changes for current players**. Boards stay identical (they are seeded separately); only which modifiers are layered on moves. That is acceptable for a difficulty change and must not be done accidentally. Do not also change `_stableHash` or the seed formula in the same release, or you will not be able to tell which change caused a report.

### Games that need a pool created

**14 of the 30 live game screens have no modifier system at all** — zero references to `_activeModifiers`. Verified by grep:

`cipher_decoder`, `flag_finder`, `hangman`, `hitori`, `mahjong`, `masyu`, `number_memory`, `reaction`, `sequence_memory`, `slitherlink`, `word_builder`, `word_climb`, `word_guess`, `word_ladder`

For these, don't invent bespoke mechanics. Give them the two modifiers that are already implemented in a dozen screens and need no new game logic:

```dart
// Minimal pool for games that had none. fog and timer are generic: fog needs
// only a cell-reveal radius, timer needs only a countdown -- both already exist
// in 12+ screens and can be lifted directly.
static const List<String> kMinimalPool = ['fog', 'timer'];
```

**Masyu (Pearl Loop) — exactly as specified:** no bespoke pool, just `['fog', 'timer']`, one of the two active on every level from level 1.

```dart
// masyu_screen.dart -- the game currently has no modifier system whatsoever.
_activeModifiers = RotationEngine.getActiveModifiers(
  gameId: 'masyu',
  levelIndex: _levelIndex,
  pool: RotationEngine.kMinimalPool,   // ['fog', 'timer']
);
// modifierStartLevel('masyu') == 1 and modifierCountFor returns 1 for
// levels 1..10, so exactly one of fog/timer is active on every level from
// the first. Above level 11 it becomes 2, which for a 2-item pool means
// fog AND timer together -- cap it if that is not wanted:
```

If fog+timer simultaneously is too much for Pearl Loop, pin it:

```dart
static int modifierCountFor(String gameId, int level) {
  final start = modifierStartLevel(gameId);
  if (level < start) return 0;
  if (kSingleModifierGames.contains(gameId)) return 1;   // never stack
  ...
}

static const Set<String> kSingleModifierGames = {'masyu'};
```

Fog on Masyu is a good fit — the loop is deduced from pearl positions, so hiding distant pearls makes it a memory-plus-logic problem rather than changing the rules. Timer is neutral. Neither touches the solver, which matters because `masyu_screen.dart` deliberately keeps `shouldRepaint => true` (grid, activeEdges, dragPath and hiddenPearls are mutated in place) — **do not "optimise" that while you are in the file.**

### The one exclusion

**Reaction Time gets no modifiers. Leave `reaction` out of the table.**

The game *is* a timing measurement. A `timer` modifier is incoherent — the timer is the score. `fog` on a reaction target either does nothing or destroys the measurement. Adding either would make the scores incomparable with every score already recorded. It is the one game where "no modifiers" is the right answer, not an oversight.

### Where your 26 came from

`game_info.dart` in this commit has **30 entries**, and `GameInfo` carries an `isStashed` flag. Counted:

- **16 active** — visible in the app
- **14 stashed** — built, tested, hidden, waiting for the drip-feed

Your 26 is those 16, plus the stashed games the drip-feed has since revealed, plus Orbit and One Stroke (2.4) and Skyscrapers (2.5). **The table below covers all 33 known ids**, so it is correct whichever 26 are currently active — nothing needs re-deriving when the next stashed game is revealed.

One finding worth stating on its own:

> **Pearl Loop (`masyu`) is the only ACTIVE game in this commit with zero modifiers.** All 13 other no-pool games are stashed. Your instinct about Masyu was pointing at a real asymmetry — it is genuinely the odd one out, and it is the one active game where a player sees nothing new for its entire level range.

Kakuro is the mirror image: stashed, but it does have a pool (`timer` only).

### Table 1 — ACTIVE in 1.8.0+48 (16 games)

Pools verified from source. Ramps shown where measured.

| Game (id) | Screen | Pool today | Start |
|---|---|---|---|
| Grid Path (`zip`) | `grid_path_screen` | 5: minimal, nonRectShape, retro, timer, waypointSparsity | 5 |
| Odd Color Out (`oddcolor`) | `odd_color_out_screen` | 9: eclipse, fog, gradient, hueChannel, monochrome, noise, prism, timer, whisper | 5 |
| Chimp Test (`chimp`) | `patches_screen` | 6: glitch, gravity, numbersHide, positionShuffle, spatialSpread, timer | **3** |
| Star Battle (`queens`) | `star_battle_screen` | 5-6: regionContortion, timer, glitch, zoom, mirror (+`twoStarMode` when n>7) | 5 |
| Mine Finder (`minesweeper`) | `mine_finder_screen` | 4: fog, hiddenCount, limitedFlags, timer | 5 |
| Spectrum (`hue`) | `spectrum_screen` | 5: distractors, monochrome, moveLimit, prism, timer | 5 |
| Sudoku (`sudoku`) | `sudoku_screen` | 6: clueThinning, eclipse, glitch, time_warp, timer, zoom | 5 |
| Word Hive (`spellingbee`) | `word_hive_screen` | 4: minimal, spy, timer, whisper | 5 |
| Pattern Lock (`pattern_lock`) | `pattern_lock_beta` | 6: boardTransform, distractorDots, eclipse, gridSize, memorizeTimer, pathComplexity | 5 |
| Colour Link (`colour_link`) | `numberlink_beta` | 5: gridSize_pairCount, monochrome, timer, tortuosity, walls | 5 |
| Color Flood (`color_flood`) | `color_flood_beta` | 3: centerSeed, chaos, timer | 5 |
| **Circuit Guide** (`circuit_guide`) | `circuit_guide_beta` | 7: decoyWires, fog, junctionDensity, retro, scrambleDepth, timer, tortuosity | **5** |
| Bridges (`bridges`) | `bridges_screen` | 4: fog, hiddenIslands, timer, zoom | 5 |
| Sum Strike (`sumstrike`) | `sum_strike_screen` | 5: denseStrike, fog, negatives, timer, whisper | 5 |
| Killer Sudoku (`killersudoku`) | `killer_sudoku_beta` | 7: cageSize, clueThinning, eclipse, fog, spy, timer, zoom | 5 |
| **Pearl Loop** (`masyu`) | `masyu_screen` | **none** → `['fog','timer']`, one at a time | **1** |

### Table 2 — STASHED in 1.8.0+48 (14 games)

Whichever of these the drip-feed has revealed are part of your 26. All need `kMinimalPool` created except Kakuro.

| Game (id) | Screen | Pool today | Start |
|---|---|---|---|
| Kakuro (`kakuro`) | `kakuro_screen` | 1: timer | 5 |
| Hitori (`hitori`) | `hitori_screen` | **none** → minimal | 5 |
| Slitherlink (`slitherlink`) | `slitherlink_screen` | **none** → minimal | 5 |
| Mahjong Solitaire (`memory`) | `mahjong_screen` | **none** → minimal | 5 |
| Sequence Memory (`sequence`) | `sequence_memory_screen` | **none** → minimal | **3** |
| Number Memory (`numbermemory`) | `number_memory_screen` | **none** → minimal | **3** |
| Word Guess (`wordle`) | `word_guess_screen` | **none** → minimal | 8 |
| Word Ladder (`weaver`) | `word_ladder_screen` | **none** → minimal | 8 |
| Word Climb (`crossclimb`) | `word_climb_screen` | **none** → minimal | 8 |
| Word Builder (`wordbuilder`) | `word_builder_screen` | **none** → minimal | 8 |
| Hangman (`hangman`) | `hangman_screen` | **none** → minimal | 8 |
| Cipher Decoder (`cipherdecoder`) | `cipher_decoder_screen` | **none** → minimal | 8 |
| Flag Finder (`flagle`) | `flag_finder_screen` | **none** → minimal | 8 |
| **Reaction Time** (`reaction`) | `reaction_screen` | **none — keep none** | **never** |

### Table 3 — added after this commit (3 games)

Not in 1.8.0+48; ids taken from the 2.4/2.5 `game_info.dart` entries. **Verify these three against your source** — they are the only rows I could not read.

| Game (id) | Pool today | Start |
|---|---|---|
| Orbit (`orbit`) | check — added 2.4 | 5 |
| One Stroke (`onestroke`) | check — added 2.4 | 5 |
| Skyscrapers (`skyscrapers`) | 4: timer, fog, zoom, decay | 5 |

Skyscrapers is the one to be careful with: it shipped as Beta specifically because its rare slow levels were still being watched on real devices, and its median generation was 61 ms with a tail to ~5 s. **Adding a modifier layer at level 5 to a generator with a 5-second tail will surface that tail to new players.** Either leave `skyscrapers` at 30 until the Beta suffix comes off, or fix the tail first.

Word games start at 8 rather than 5 because their difficulty is vocabulary, not board size — there is no early size step to hang a start level on, and fogging letters in the first few levels reads as a broken screen rather than a rule.

### Table 4 — the 26 active games as of 2.5(68)

**This is a reconstruction, not a reading.** I only have 1.8.0+48; the 2.5 tree was deleted from this machine. The arithmetic is solid but the membership of one group is not.

How 16 becomes 26:

| | Count | Source |
|---|---|---|
| Active in 1.8.0+48 | 16 | **read from source** |
| Revealed by the drip-feed across 1.8.2(61) → 2.3.1(66) | **7** | inferred — six bundles, `isStashed` flipped to false |
| Added in 2.4 — Orbit, One Stroke | 3 | known from `game_info.dart` edits |
| Added in 2.5 — Skyscrapers (Beta) | | |
| **Total** | **26** | matches your count |

So **7 of these 14 are now active, and 7 are still stashed:**

`kakuro`, `hitori`, `slitherlink`, `memory`, `sequence`, `numbermemory`, `wordle`, `weaver`, `crossclimb`, `wordbuilder`, `hangman`, `cipherdecoder`, `flagle`, `reaction`

I cannot tell you which 7 without the 2.5 source. Kakuro is near-certain (it shipped in 1.9). Beyond that I would be guessing, and a guess in this table is worse than a blank — it would read as verified.

**Generate the authoritative list in one command,** from your 2.5 tree or any zip:

```bash
# active games, numbered -- run in the cogniq/ root
grep -o "id:'[^']*'" lib/models/game_info.dart > /tmp/all.txt
grep -c "isStashed: true" lib/models/game_info.dart      # how many still hidden
grep "GameInfo(" lib/models/game_info.dart | grep -v "isStashed: true" | \
  sed -n "s/.*id:'\([^']*\)'.*name:'\([^']*\)'.*/\1\t\2/p" | nl
```

```powershell
# PowerShell equivalent
Select-String -Path lib\models\game_info.dart -Pattern "GameInfo\(" |
  Where-Object { $_.Line -notmatch "isStashed: true" } |
  ForEach-Object { if ($_.Line -match "id:'([^']*)'.*name:'([^']*)'") { "$($Matches[1])`t$($Matches[2])" } }
```

**The important part: it does not matter which 7.** Tables 1-3 cover all 33 ids, so every one of your 26 already has a start level whichever way the drip-feed went — and so does every game still stashed, for the day it is revealed. That is the whole reason the map is exhaustive rather than scoped to "the active 26".

Two rows in Table 4's arithmetic to confirm when you open the source:

1. **`skyscrapers` should stay at 30 for now,** not 5 — see the warning under Table 3. It is the only id in the map I would deliberately leave at the old value.
2. **`orbit` and `onestroke` pools are unread.** If either has an empty pool, it needs `kMinimalPool` like the Table 2 games, not just a start level.

---

## Never let a game fall through again

The `?? 30` fallback is deliberate — an unknown id must not crash — but it fails **silently**, which is the exact failure mode behind every bug in this document. Close it with a test that runs against `kAllGames`, so the source of truth is the catalogue, not this file:

```dart
test('every game has an explicit modifier start level', () {
  final missing = <String>[];
  for (final g in kAllGames) {
    if (RotationEngine.kNoModifierGames.contains(g.id)) continue;  // deliberate
    if (RotationEngine.modifierStartLevelRaw(g.id) == null) missing.add(g.id);
  }
  expect(missing, isEmpty,
      reason: 'These ids fall back to 30 -- add them to _modifierStartLevel: $missing');
});

test('no start level is above the level its board stops growing', () {
  // A start level past the board ramp recreates the dead stretch this change
  // exists to remove.
  for (final g in kAllGames) {
    final start = RotationEngine.modifierStartLevel(g.id);
    if (RotationEngine.kNoModifierGames.contains(g.id)) continue;
    expect(start, lessThanOrEqualTo(10),
        reason: '${g.id} starts at $start -- too late to fill the gap');
  }
});

test('stashed games are covered too', () {
  // Stashed games become active without a code change to game_info, so they
  // must already be in the table on the day the drip-feed reveals them.
  expect(kAllGames.where((g) => g.isStashed).every((g) =>
      RotationEngine.kNoModifierGames.contains(g.id) ||
      RotationEngine.modifierStartLevelRaw(g.id) != null), isTrue);
});
```

That third test is the one that matters for your release cadence: **a stashed game becomes active by flipping `isStashed`, with no other code change.** Without it, the next drip-feed reveal ships a game whose modifiers silently start at 30.

---

## B. Challenge mode must honour every modifier

Separate from the start-level table, because challenge mode must ignore start levels entirely — a daily at level 7 still gets its authored rule.

### Three species of hand-rolled gate

Because there was never a shared gate, every screen invented one.

**Species 1 — correct.** `odd_color_out_screen.dart:33-37` is the reference. Challenge mode is checked *before* the level gate, and it is generic over the modifier name, so every pooled modifier is reachable:

```dart
bool _isModActive(String name) {
  if (_forcedModifier == name) return true;
  if (_isDailyMode) return _dailyModifierType == name;          // no level gate
  return !_isDailyMode && _levelIndex >= 30 && _activeModifiers.contains(name);
}
```

**Species 2 — pass-through.** Nine screens dump the daily modifier into the active set:

```dart
_activeModifiers = {};
if (_playDailyMode && _dailyModifierType.isNotEmpty) {
  _activeModifiers.add(_dailyModifierType);
}
```

This works *only* where the downstream check also ORs in daily mode, as `circuit_guide_beta.dart` remembers to do:

```dart
if ((_playDailyMode || _currentLevel >= 30) && _activeModifiers.contains('timer')) {
```

There are dozens of those `_playDailyMode ||` clauses and every one is a chance to forget.

**Species 3 — hard-disabled.** Six getters switch the modifier **off** in challenge mode outright:

| File | Line | Getter | Modifier lost |
|---|---|---|---|
| `bridges_screen.dart` | 73 | `_isHiddenIslandsActive` | `hiddenIslands` |
| `mine_finder_screen.dart` | 56 | `_isLimitedFlagsActive` | `limitedFlags` |
| `mine_finder_screen.dart` | 63 | `_isHiddenMinesActive` | `hiddenCount` |
| `patches_screen.dart` | 70 | `_hasPositionShuffle` | `positionShuffle` |
| `patches_screen.dart` | 78 | `_hasDecoyTiles` | decoy tiles |
| `star_battle_screen.dart` | 407 | `_useTwoStars` | `twoStarMode` |

All six read `if (_playDailyMode) return false;`. So the plan selects the modifier, `daily_screen.dart` pops the **"Special Daily Rule!"** dialog announcing it, the player taps **Play!** — and the board applies nothing.

### The fix — one shared gate

```dart
/// Single source of truth for "is this modifier in effect right now?"
///
/// Challenge mode is checked BEFORE any level gate and deliberately has no
/// level gate of its own: dailies run at level 1..19, so any threshold here
/// swallows the rule the launch dialog just promised.
bool _isModActive(String name) {
  if (_forcedModifier == name) return true;                     // debug / forced
  if (_isDailyMode) return _dailyModifierType == name;          // <-- no level gate
  return _levelIndex >= RotationEngine.modifierStartLevel(_gameId) &&
         _activeModifiers.contains(name);
}
```

Then collapse every hand-rolled check into it:

```dart
// BEFORE -- six variants of this exist
bool get _isHiddenIslandsActive {
  if (_playDailyMode) return false;
  if (_currentLevel >= 30) {
    return _activeModifiers.contains('hiddenIslands');
  }
  return false;
}

// AFTER
bool get _isHiddenIslandsActive => _isModActive('hiddenIslands');
```

```dart
// BEFORE -- the pass-through species, where the OR is easy to forget
if ((_playDailyMode || _currentLevel >= 30) && _activeModifiers.contains('timer')) {

// AFTER
if (_isModActive('timer')) {
```

Mechanical, deletes more lines than it adds, and it also removes the last hardcoded `30` from every screen — which is what makes the section A table actually take effect.

### Two things to decide, not assume

1. **Do you want all six hard-disabled modifiers on in challenge mode?** Some may be off for an unwritten reason — `twoStarMode` changes Star Battle's win condition, and a challenge whose win condition differs from the announced rule is worse than a no-op. If a modifier genuinely should never appear in a daily, **remove it from that game's plan entry** so the dialog cannot announce it. Don't return false in the screen.
2. **A modifier tuned for level 30+ may be brutal at level 5.** `fog` on a 4×4 is not `fog` on a 9×9. This is the same trap as always here: the code will be correct and the experience may still be wrong. Play a week of dailies and levels 5-15 of four games before shipping.

### Lock the class with a test

```
For every week/day/slot in _kDailyChallengesPlan:
  - resolve the challenge -> (gameId, levelIndex, modifierType)
  - assert modifierType is non-empty
  - assert the screen for gameId can return true for that modifierType
    while _isDailyMode is true
  - assert levelIndex < 30                     (documents the gap)
```

The third assertion passes today and fails the day someone raises a plan `levelIndex` past 30 — exactly when the hand-rolled gates would start diverging again.

---

## C. Description copy must not be endgame-framed

### Three description surfaces, and the wrong one wins

**Surface 1 — the endgame HUD label.** Per-screen `_getModifierDescription(mod)`, e.g. `grid_path_screen.dart:526-536`:

```dart
case 'waypointSparsity':
  return 'Sparse: fewer waypoints shown';
case 'minimal':
  return 'Minimal: waypoints disappear after 10s';
```

Terse `Label: mechanic`, written for a player 30 levels in who knows the game cold. **This is the voice that reads wrong as a challenge rule** — and, after section A, wrong at level 5 too.

**Surface 2 — the authored challenge prose.** `_ChallengeData.modifierDescription`, written for someone meeting the rule for the first time:

```
'A visual interference/static effect briefly disrupts grid boundaries.'
'The Sudoku board is blacked out by fog. Selecting a cell illuminates a 3x3 region around it.'
'The remaining mine counter is hidden. You must flag all mines to auto-clear the board.'
```

`getChallengesForDay` even tailors it per game (`daily_challenge_manager.dart:1091-1122`). This is the right copy, and it is already persisted on every launch:

```dart
await prefs.setString(PrefsKeys.dailyModifierName, challenge.modifierName);
await prefs.setString(PrefsKeys.dailyModifierDesc, challenge.modifierDescription);
```

**Surface 3 — the name-only daily banner:** `'DAILY CHALLENGE: ${_dailyModifierName.toUpperCase()}'`.

### The measured problem

`daily_modifier_desc` is **written on every challenge launch and read by exactly 2 of 27 game screens** — `mine_finder_screen.dart:1082` and `star_battle_screen.dart:1557`.

| Surface | Screens implementing it |
|---|---|
| Name-only daily banner | 7 — mahjong, mine_finder, number_memory, odd_color_out, sequence_memory, star_battle, word_guess |
| …of those, also showing the authored **description** | **2** — mine_finder, star_battle |

And the endgame banner is hidden in challenge mode anyway: it is gated on `_activeModifiers.isNotEmpty`, but the daily path sets `_activeModifiers = {}` (e.g. `odd_color_out_screen.dart:188-193`).

| Screen | Endgame desc banner in challenge mode |
|---|---|
| `grid_path_screen.dart` | **hidden** |
| `mine_finder_screen.dart` | **hidden** |
| `odd_color_out_screen.dart` | **hidden** |
| `spectrum_screen.dart` | **hidden** |
| `sudoku_screen.dart` | **hidden** |
| `bridges_screen.dart` | no banner exists |
| `kakuro_screen.dart` | no banner exists |
| 9 others (pass-through) | shows — but shows the **terse endgame label** |

So today the player gets one of three wrong things:

1. **Odd Colour Out** — `DAILY CHALLENGE: PRISM` and no explanation of what Prism does.
2. **Grid Path, Spectrum, Sudoku** — nothing at all under the board.
3. **The nine pass-through screens** — `Sparse: fewer waypoints shown`, endgame shorthand, instead of the sentence authored for this exact challenge and sitting unread in prefs.

The good copy exists, is written every launch, and almost nothing reads it.

### The fix — one getter, prefer the authored copy

```dart
String _dailyModifierName = '';
String _dailyModifierDesc = '';

// in _loadPrefs, alongside the existing _dailyModifierType read:
_dailyModifierName = prefs.getString(PrefsKeys.dailyModifierName) ?? '';
_dailyModifierDesc = prefs.getString(PrefsKeys.dailyModifierDesc) ?? '';
```

```dart
/// Copy to show under the board.
///
/// Challenge mode uses the description authored in _kDailyChallengesPlan and
/// persisted by setupDailyModifier -- written for a player meeting the rule
/// cold, and already tailored per game. The per-game _getModifierDescription
/// strings are terse HUD labels written for the endgame, so they are the
/// fallback, never the challenge-mode answer.
String get _modifierBannerText {
  if (_isTutorialMode) return '';

  if (_isDailyMode) {
    if (_dailyModifierDesc.isNotEmpty) return _dailyModifierDesc;
    if (_dailyModifierName.isNotEmpty) return _dailyModifierName;
    return '';
  }

  return _activeModifiers
      .map(_getModifierDescription)
      .where((d) => d.isNotEmpty)
      .join(' · ');
}
```

```dart
// BEFORE -- invisible in challenge mode, because _activeModifiers is {} there
if (!_isTutorialMode && _activeModifiers.isNotEmpty) ...[
  Text(
    _activeModifiers.map((m) => _getModifierDescription(m))
        .where((desc) => desc.isNotEmpty).join(' · '),
    ...
  ),
]

// AFTER -- one condition, correct in both modes
if (_modifierBannerText.isNotEmpty) ...[
  Text(_modifierBannerText, ...),
]
```

Keep the `DAILY CHALLENGE: <NAME>` header where it exists — name as header, description underneath, exactly as `mine_finder_screen.dart:1070-1082` and `star_battle_screen.dart:1543-1557` already do. **Those two are the layout reference; copy them into the other five.**

### Section A makes this bigger

Once modifiers start at level 5, the endgame label is being shown to a player on their fifth ever game. `'Sparse: fewer waypoints shown'` assumes the player knows what a normal waypoint count looks like — at level 5 they don't. **Every `_getModifierDescription` string needs rewriting for a first-time reader**, not just the challenge path. That is ~70 strings across 16 screens and it is the largest single piece of work in this document.

### Copy rules

| | Endgame label (`_getModifierDescription`) | First-encounter prose (plan + early levels) |
|---|---|---|
| Audience | player 30+ levels in | player meeting the rule cold |
| Length | 2-6 words after the colon | 1-2 full sentences |
| Form | `Label: mechanic` | describes the board, then what to do |
| Assumes | the game's vocabulary | nothing |

Write about **this board**, never about progression:

```
BAD   'Endgame modifier: fog.'
BAD   'The level-30+ fog rule is active.'
BAD   'Unlocked at level 30.'
BAD   'Sparse: fewer waypoints shown'          <-- endgame label reused
GOOD  'A heavy fog covers the grid. Selecting a cell reveals the 3x3 region around it.'
GOOD  'Fewer waypoints are shown than usual. Deduce the order from the ones you can see.'
```

Never mention levels, unlocks, or "past 30" in this copy. After section A a player can meet a modifier on level 3, and after section B on daily level 7 — the words "endgame" and "unlocked at level 30" are simply false in both.

### Two cheap fixes to bundle in

**Four screens bypass `PrefsKeys` and hardcode the raw string** — `mahjong_screen.dart:403`, `number_memory_screen.dart:68`, `sequence_memory_screen.dart:91`, `word_guess_screen.dart:95`:

```dart
_dailyModifierName = prefs.getString('daily_modifier_name') ?? '';
```

Use `PrefsKeys.dailyModifierName`. A typo in a raw key yields an empty string, and empty means "no banner" — it fails invisibly, which is how this entire class of bug survived.

**`sequence_memory_screen.dart:400` shows the raw name un-uppercased** while the other six uppercase it. One line.

---

## What to change in every future update

This is the part to re-read each release. Three triggers, and what each one obliges you to do.

### Trigger 1 — you add a brand-new game

`GAME_WIRING_CHECKLIST.md` already lists the 10 shared files a new game must touch, and `rotation_engine.dart` is one of them. **This document defines what value to put there.** Add to that checklist's row for `rotation_engine.dart`:

- [ ] `_modifierStartLevel['<newId>']` — pick from the rule below
- [ ] the game has a non-empty `pool:`, or is given `kMinimalPool`
- [ ] `_isModActive` is used for every modifier check in the new screen — never a bare `_levelIndex >= n`
- [ ] `_modifierBannerText` is wired into the new screen's board area
- [ ] if the game should never have modifiers, add its id to `kNoModifierGames` **with a comment saying why**

**Picking the start level — the rule, not a lookup:**

| Game shape | Start | Why |
|---|---|---|
| Grid puzzle whose board grows by level 5 | **5** | board has taken its first step; fog/zoom have something to act on |
| Memory / attention test | **3** | the modifier *is* the mechanic; there is no board to wait for |
| Word game | **8** | difficulty is vocabulary; let the rules land first |
| Generator with a slow tail (>1 s at p99) | **30** until fixed | an early start surfaces the tail to new players |
| Measurement game (a timer *is* the score) | `kNoModifierGames` | a modifier makes scores incomparable |

The coverage test fails if you skip this, which is the point.

### Trigger 2 — you reveal a stashed game

**This is the dangerous one, because it is a one-character change.** Flipping `isStashed: true` → `false` makes a game live with no other edit — no new route, no new screen, nothing that would make you open the checklist.

Every reveal must confirm:

- [ ] the id is already in `_modifierStartLevel` (the third test in the previous section enforces this)
- [ ] the game has a pool, or `kMinimalPool`
- [ ] its `_getModifierDescription` strings were rewritten for a first-time reader (section C) — stashed games were written when modifiers started at 30
- [ ] you have actually played its levels 3-15 with modifiers on

That third box is easy to miss: a game stashed since 1.8 has endgame-voiced copy that nobody has looked at since, and after this change a brand-new player meets it on level 5.

### Trigger 3 — you add a modifier to an existing game's pool

- [ ] `_isModActive('<newMod>')` returns true in challenge mode — i.e. the plan can select it and the screen honours it
- [ ] it is **not** a no-op at any level (the Pattern C check in `COGNIQ_FIXES_DAILY_TRAIL_GRIDPATH.md` — this is how Grid Path's `waypointSparsity` was caught doing nothing on 45 consecutive levels)
- [ ] `_getModifierDescription` has a case for it, written for a first-time reader
- [ ] if it goes in a daily plan entry, it has authored prose in `modifierDescription`
- [ ] it does not change the win condition — or if it does, it is excluded from dailies at the *plan* level, not with `return false` in the screen

### Per-release regression check

Cheap, and it catches everything this document is about:

```
1. Coverage tests green (3 tests, previous section)
2. Plan-coverage test green (section B) -- every plan entry's modifier is honourable
3. No screen contains a bare `>= 30` modifier gate:
      grep -rnE "(_currentLevel|_levelIndex) *>= *30" lib/screens/games/
   Expected: difficulty-band hits only. Any _activeModifiers.contains on the
   same condition is a regression back to the hand-rolled gates.
4. Play levels 3-15 of two games and one full day of dailies.
```

Step 3 is worth automating as a test that greps the source — it is the only way to stop the 27 hand-rolled gates growing back one screen at a time.

### Record it where you will see it

Add a line to `NOTES.md` for the release that ships this, naming the start-level table as a thing that exists — otherwise the next person to add a game will hardcode `30` because that is what every other screen used to do. And add the three triggers above to `CHECKLIST.md` so "I'm adding a game" and "I'm revealing a stashed game" both point here.

---

## Which versions get these

Same policy as the companion file: **backport only what loses data or blocks play.**

| Change | Backport? | Why |
|---|---|---|
| A — per-game start levels | **No — head only** | Difficulty change touching 27 files plus `RotationEngine`. Nothing corrupts; existing saves keep working. |
| B — challenge mode gate | **No — head only** | Players currently get easier dailies than intended; after updating they get the intended ones. |
| C — description copy | **No — head only** | Copy and layout. |

None of these belong in the drip-feed ladder. A 27-file change replicated across six unshipped bundles is how regressions get introduced — 2.6 head only.

> **Still outstanding:** `cogniq(1.8.2(61))` has never been uploaded to Play internal testing. The daily-challenge crash fix has been built and unshipped for nine builds. That still matters more than anything in this file.

---

## Order of work

1. **C first.** Pure UI, touches no game logic, and it makes A and B *testable* — you cannot tell whether a modifier fired if the board never says which modifier it is.
2. **`RotationEngine` table + `modifierCountFor`,** with the `kAllGames` coverage test. No screen changes yet, so nothing moves.
3. **B on one screen** — `bridges_screen.dart`, the smallest hard-disabled case. Verify `hiddenIslands` engages on a daily. This is also where `_isModActive` replaces the last hardcoded `30`, which is what activates the table.
4. **B across the rest,** one screen per commit.
5. **A's new pools** — Masyu first, since it is the one you specified and has no existing modifier code to conflict with.
6. **Rewrite the ~70 description strings.**
7. **Play levels 3-15 of six games and a full week of dailies.** The code being right is not the same as the difficulty being right.

Step 7 is not optional. Every disaster in this project traced to a generator or curve that was believed instead of measured — Skyscrapers took three rounds, and Grid Path's dead floor sat in shipped code across five versions.
