# Three game fixes for 1.8.3 — Colour Link, Chimp, Grid Path

*Written 2026-08-23 during the 2.5 performance pass. **Nothing here is applied yet** — this is
the write-up plus the exact code, so you can do it when you want to.*

**These three games ship in every version from 1.8 onward**, so the fixes apply to the whole
drip-feed, not one bundle. Target release: **1.8.3**.

None of them crashes, none blocks a player from finishing anything, and none is urgent. They
are all "the difficulty curve does not do what someone intended it to do".

Every figure below was worked out by reading the arithmetic and computing it level by level —
not estimated.

---

## 1. 🔴 Colour Link gets EASIER as you play — the real one

**File:** `lib/screens/games/colour_link/colour_link_screen.dart` (~line 170)

The only genuine defect of the three. A player at level 100 gets easier boards than the same
player got at level 50.

| Levels | Grid | Colours | |
|---|---|---|---|
| 30–44 | 8×8 | 6 → 8 | climbing |
| **45–59** | 8×8 | **8** | ⬅️ the hardest it ever gets |
| **60–79** | 8×8 | **6** | ⬅️ **drops by two colours** |
| **80+** | 6–8 cycling | **4–6 cycling** | ⬅️ never reaches 8 again, forever |

### The code as it stands

```dart
      if (!_playDailyMode && _currentLevel >= 30) {
        if (_currentLevel >= 30 && _currentLevel < 45) {
          _gridSize = 8;
          _numColors = 6 + min(2, (_currentLevel - 30) ~/ 7); // 7-8 colors
        } else if (_currentLevel >= 45 && _currentLevel < 60) {
          _gridSize = 8;
          _numColors = 8;
        } else if (_currentLevel >= 60 && _currentLevel < 80) {
          _gridSize = 8;
          _numColors = 6;
        } else {
          _gridSize = 6 + ((_currentLevel - 80) % 3);
          _numColors = (4 + ((_currentLevel - 80) % 3)).clamp(2, (_gridSize * _gridSize) ~/ 4);
        }
      }
```

### Replace it with

```dart
      if (!_playDailyMode && _currentLevel >= 30) {
        if (_currentLevel < 45) {
          _gridSize = 8;
          _numColors = 6 + min(2, (_currentLevel - 30) ~/ 7); // 7-8 colors
        } else {
          // From 45 the board is at its hardest and STAYS there.
          //
          // It used to drop to 6 colours at level 60 and then cycle 4-6 from
          // level 80, so a level-100 player faced easier boards than at level
          // 50 -- the difficulty ran backwards. Holding 8x8 with 8 colours is
          // the peak the ladder was already building toward.
          //
          // Variety past this point is the modifiers' job, which is the same
          // arrangement every other plateaued game uses. Colour Link has no
          // special case in RotationEngine.modifierStartLevel, so it takes the
          // default of 15 -- modifiers have been running for thirty levels by
          // the time the board stops changing.
          _gridSize = 8;
          _numColors = 8;
        }
      }
```

**The trade-off, stated honestly:** the board is then identical from level 45 upward. That is
deliberate and matches how the rest of the app works (see `rotation_engine.dart` — Kakuro
plateaus at 12, Slitherlink at 12, and modifiers carry the curve). If you would rather keep
some board variation, vary something that is *not* difficulty — which pairs get placed, or
where they start — and leave grid and colour count at 8.

**Why no test caught this:** `difficulty_curve_test.dart` checks that modifiers start early
enough and change between levels. **It never asserts difficulty does not go backwards.** No
test in the project does. See the last section.

---

## 2. 🟡 Chimp has six levels where nothing changes

**File:** `lib/utils/rotation_engine.dart` (~line 75–82)

Chimp's board reaches its hardest hand-authored entry — 9 wide, 15 numbers — at **level 24**
and holds it. But Chimp's `modifierStartLevel` is **30**. So **levels 24–29 give the player
nothing new at all**.

This is the only game out of 26 with such a gap. Three others are exactly synchronised
(Kakuro 12/12, Cipher Decoder 20/20, Slitherlink 12/12) and the comments show that is
deliberate.

### The code as it stands

```dart
      case 'mines':
      case 'patternlock':
      case 'queens':
      case 'zip':
      case 'colorflood':
      case 'chimp':
        return 30;
```

### Change it to

```dart
      case 'mines':
      case 'patternlock':
      case 'queens':
      case 'zip':
      case 'colorflood':
        return 30;

      // Chimp's 30-entry table reaches its hardest board (9 wide, 15 numbers)
      // at index 24 and holds it through 29, so modifiers have to begin there
      // or levels 24-29 offer nothing new at all. Measured 2026-08-23; it was
      // the only game of 26 whose board plateaued before its modifiers started.
      case 'chimp':
        return 24;
```

`difficulty_curve_test.dart` asserts every game starts modifiers **by** level 30, so moving
Chimp earlier stays safely inside that rule. Run it afterwards anyway.

---

## 3. 🟡 Grid Path — difficulty logic above level 30 never actually runs

**File:** `lib/screens/games/grid_path/grid_path_screen.dart` (~line 452)

Nothing is broken for the player, but a chunk of code is dead and misleading.

From level 30 the game computes a waypoint count that varies with the level, then a few lines
later applies a floor of `gridSize + 2`. **The floor always wins:**

| Levels | Grid | Floor | Formula gives | Actually used |
|---|---|---|---|---|
| 30–49 | 6 | 8 | 4–5 | **8** (floor) |
| 50–74 | 7 | 9 | 5–7 | **9** (floor) |
| 75+ | 8 or 9 | 10 or 11 | 6–9 | **10 or 11** (floor) |

Those three formulas have **never executed once** in the shipped app.

### The code as it stands

```dart
    if (!_isDailyMode && levelIndex >= 30) {
      if (levelIndex >= 75) {
        waypointCount = 6 + (levelIndex % 4);
      } else if (levelIndex >= 50) {
        waypointCount = 5 + (levelIndex % 3);
      } else {
        waypointCount = 4 + (levelIndex % 2);
      }
      if (activeMods.contains('waypointSparsity')) {
        waypointCount = minWaypoints;
      }
    } else if (levelIndex < 5) {
```

### Replace it with

```dart
    if (!_isDailyMode && levelIndex >= 30) {
      // The `gridSize + 2` floor applied below always exceeded the per-level
      // formulas that used to live here (30-49 gave 4-5 against a floor of 8;
      // 50-74 gave 5-7 against 9; 75+ gave 6-9 against 10-11), so none of them
      // ran once in the shipped app. The floor alone produces a clean climb of
      // 8 -> 9 -> 10/11 as the grid grows. The `waypointSparsity` branch set
      // exactly this value too, so behaviour is unchanged.
      // Dead code removed 1.8.3.
      waypointCount = minWaypoints;
    } else if (levelIndex < 5) {
```

**This is behaviour-preserving** — the value used at run time is identical, because the floor
was already producing it. It only removes code that misleads the next reader.

**Also worth knowing (not fixed here):** from level 75 the grid alternates 8×8 / 9×9 forever
(`gridSize = 8 + ((levelIndex - 75) % 2)`). It never drops below 8, so this is not a
regression like Colour Link — but the game does stop getting harder at level 75.

---

## Suggested order

1. **Colour Link** — the only one a player can actually feel. Maybe an hour.
2. **Chimp** — one line.
3. **Grid Path** — delete dead code, no behaviour change.

## The test that would have caught all this

`difficulty_curve_test.dart` has no monotonicity check. Adding one would have caught Colour
Link, and will catch the next one automatically:

```dart
test('difficulty never runs backwards', () {
  for (final id in pools.keys) {
    // Build each game's difficulty signature per level (grid size, piece count,
    // whatever that game scales) and assert it never decreases.
    var previous = 0;
    for (var level = 0; level < 150; level++) {
      final signature = difficultySignatureFor(id, level);
      expect(signature, greaterThanOrEqualTo(previous),
          reason: '$id gets EASIER going into level $level');
      previous = signature;
    }
  }
});
```

The work is in writing `difficultySignatureFor` — each game scales different things, so it
needs a small per-game accessor. Worth it: this is the third difficulty-curve defect found by
reading code rather than by a test.

---

*Related: `md/remember.md` (rules), `md/RELEASE_PLAN.md` §4.7, and the plateau figures for all
26 games measured 2026-08-23.*
