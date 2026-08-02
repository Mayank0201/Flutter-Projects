# CogniQ — Endgame Modifier-Pool Expansion (batch 2)

## Read this before touching any code

This is a follow-up to `final_modifier_fix_pool_audit.md` (which fixed *dead* pool
entries) and `final_modifier_fix_regressions.md` (already implemented and verified,
commit `aa34260`). That prior batch made every existing pool entry actually work. This
batch is different: it **adds new entries** to several endgame pools, using modifiers
that were already fully built for the Daily Challenge system in the same file but never
offered to free-play players. The goal is more per-level variety so grinding a single
game's endgame doesn't feel like the same 2–3 modifiers on repeat.

**How each candidate was found:** every game file has two independent modifier gates —
`_dailyModifierType == 'X'` (daily-only) and `RotationEngine.getActiveModifiers(...,
pool: [...])` (endgame free-play, levels ≥30). A modifier implemented for daily but
absent from the endgame `pool:` list is "free" variety that just needs wiring up.

**Rules for whoever (human or agent) implements this — same discipline as the prior two
files:**
- Before editing, **search for the exact "current code" text given below** and confirm
  it matches verbatim. Line numbers are locator hints only (they drift) — the quoted
  text is the source of truth. If it doesn't match, stop and re-read the surrounding
  function; do not guess.
- Do these **one game at a time**, run `flutter analyze` on that file before moving on.
- Several sites below are marked **"verify context before editing"** — these are places
  where the survey that produced this doc did not capture the full surrounding block, so
  a wrong collapse could accidentally remove a daily-mode-only guard. Read the whole
  surrounding function first in those cases; don't apply the replacement blind.
- A "Deliberately excluded" section at the end lists modifiers that look portable but
  aren't safe to add as a quick pool edit — read it before adding anything not listed in
  the master table.

---

## Master table

| Game | gameId | Current pool | Add | New pool size | Notes |
|---|---|---|---|---|---|
| Sudoku | `sudoku` | `['clueThinning','eclipse','timer']` | `zoom`, `glitch`, `time_warp` | 3→6 | multiple call sites per modifier, widen all |
| Killer Sudoku | `killersudoku` | `['cageSize','clueThinning','timer']` | `spy` | 3→4 | trivial, single site |
| Minesweeper | `mines` | `['limitedFlags','hiddenCount','timer']` | `blind` | 3→4 | trivial, single site. Do NOT add fog/spotlight (see exclusions) |
| Bridges | `bridges` | `['hiddenIslands','timer','zoom']` | `fog` | 3→4 | getter rewrite needed |
| Odd Color Out | `oddcolorout`* | `['hueChannel','noise','gradient','timer']` | `monochrome`,`whisper`,`prism`,`eclipse`,`fog`,`retro` | 4→10 | biggest win; adds a shared helper; 2 call sites to update identically |
| Zip | `zip` | `['waypointSparsity','nonRectShape','timer']` | `retro`, `minimal` | 3→5 | verify context before editing |
| Pattern Lock | `patternlock` | `['pathComplexity','distractorDots','gridSize','boardTransform','memorizeTimer']` | `eclipse` | 5→6 | trivial + a bonus dead-code bugfix in the same file |
| Colour Link | `colourlink` | `['gridSize_pairCount','walls','tortuosity','timer']` | `monochrome` | 4→5 | small getter rewrite |
| Circuit Guide | `circuitguide` | `['tortuosity','junctionDensity','decoyWires','scrambleDepth','timer']` | `retro` | 5→6 | trivial, single line, zero other change |
| Chimp (Patches) | `chimp` | `['numbersHide','spatialSpread','positionShuffle','timer','glitch']` | `gravity` | 5→6 | trivial, effect fn already exists |
| Sum Strike | `sumstrike` | `['negatives','denseStrike','timer','whisper']` | `fog` | 4→5 | radius fallback already safe, no new config needed |

*\*The master table in the prior audit doc called this game `oddcolor`; the actual
`gameId` string used in the live `RotationEngine.getActiveModifiers` calls is
`'oddcolorout'`. Use `'oddcolorout'` — that's what the file actually passes.*

Games not touched in this batch at all: **Star Battle, Masyu, Spectrum, Color Flood,
Word Hive** — see "Deliberately excluded" for Star Battle/Masyu; Spectrum and Color
Flood already have full daily/endgame parity (nothing to port); Word Hive's only
daily-only extras (`restriction`, `spotlight2`) have no implementing code at all in the
game file — they're dead config entries, not a pool-omission bug, and inventing an
implementation for them is out of scope here.

---

## Fix 1 — Sudoku: add `zoom`, `glitch`, `time_warp`

**File:** `lib/screens/games/sudoku/sudoku_screen.dart`

**Why:** all three already have complete, self-contained effect code gated only by
`_dailyModifierType`, with no dependency on daily-specific data.

### Step 1 — pool list

**Current code** (`_loadLevel()`):
```dart
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'sudoku',
        levelIndex: _levelIndex,
        pool: ['clueThinning', 'eclipse', 'timer'],
      );
```

**Replacement code:**
```dart
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'sudoku',
        levelIndex: _levelIndex,
        pool: ['clueThinning', 'eclipse', 'timer', 'zoom', 'glitch', 'time_warp'],
        minActive: 2,
        maxActive: 4,
      );
```
(Pool doubled, so `maxActive` is bumped from the implicit default of 3 to 4 — same
reasoning as Star Battle's Fix 1 in the prior audit — so the 3 new entries get a fair
chance to appear alongside the original 3, not crowded out.)

### Step 2 — widen `zoom` (2 sites, both must change together)

**Current code** (mode-toggle chips):
```dart
                  if (_playDailyMode && _dailyModifierType == 'zoom') ...[
```
**Replacement code:**
```dart
                  if ((_playDailyMode && _dailyModifierType == 'zoom') || (!_playDailyMode && _levelIndex >= 30 && _activeModifiers.contains('zoom'))) ...[
```

**Current code** (InteractiveViewer wrap):
```dart
                        if (_playDailyMode && _dailyModifierType == 'zoom') {
```
**Replacement code:**
```dart
                        if ((_playDailyMode && _dailyModifierType == 'zoom') || (!_playDailyMode && _levelIndex >= 30 && _activeModifiers.contains('zoom'))) {
```
Both sites gate the *same* feature (the toggle chips and the viewer wrap it controls) —
widen both identically or you'll get chips with no wrapper underneath them, or vice
versa.

### Step 3 — widen `glitch` (1 site)

**Current code:**
```dart
    if (_playDailyMode && _dailyModifierType == 'glitch') {
```
**Replacement code:**
```dart
    if ((_playDailyMode && _dailyModifierType == 'glitch') || (!_playDailyMode && _levelIndex >= 30 && _activeModifiers.contains('glitch'))) {
```

### Step 4 — widen `time_warp` (2 sites — **verify context before editing the first one**)

**Scoring site — safe, single-line, edit directly:**
Current code:
```dart
    if (_playDailyMode && _dailyModifierType == 'time_warp') {
```
Replacement code:
```dart
    if ((_playDailyMode && _dailyModifierType == 'time_warp') || (!_playDailyMode && _levelIndex >= 30 && _activeModifiers.contains('time_warp'))) {
```

**Init site — verify context first.** The current line here is just:
```dart
      if (_dailyModifierType == 'time_warp') {
        _warpTimeLeft = 90;
```
Note this one does **not** check `_playDailyMode` explicitly on this line — it may
already be nested inside a broader `if (_playDailyMode) { ... }` block set up elsewhere
in the same init function. Read the full surrounding function before touching this one.
If it's inside such a wrapper, you need to either widen the *outer* wrapper condition (if
nothing else daily-only-specific lives inside it) or add the free-play branch as a
sibling `else if` that also starts the same 90-second countdown when
`!_playDailyMode && _levelIndex >= 30 && _activeModifiers.contains('time_warp')`. Don't
just prepend a bare OR to this exact line without seeing what wraps it — you could end up
with dead code that's still gated by an untouched outer `_playDailyMode` check.

**How to verify:** Jump-to-Level to several free-play Sudoku levels ≥30 and confirm you
eventually see: the pan/zoom toggle chips (with working InteractiveViewer), an
occasional row-swap glitch after 3 correct placements, and occasionally the 90s
countdown-with-bonus-time mode — not just clueThinning/eclipse/timer every time.

---

## Fix 2 — Killer Sudoku: add `spy`

**File:** `lib/screens/games/beta/killer_sudoku_beta.dart`

**Why:** `spy` is already checked via `_activeModifiers.contains('spy')` (not
`_dailyModifierType`), fully procedural (random cage index, no daily-specific data). This
is the simplest possible fix in this whole batch — one line.

**Current code:**
```dart
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'killersudoku',
        levelIndex: _currentLevel,
        pool: ['cageSize', 'clueThinning', 'timer'],
        minActive: 1,
        maxActive: 2,
        smallGrid: _gridSize == 6,
      );
```

**Replacement code:**
```dart
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'killersudoku',
        levelIndex: _currentLevel,
        pool: ['cageSize', 'clueThinning', 'timer', 'spy'],
        minActive: 1,
        maxActive: 2,
        smallGrid: _gridSize == 6,
      );
```
No other change — the effect code (lines ~395–398 and ~479) already reads
`_activeModifiers.contains('spy')` unconditionally.

**How to verify:** replay free-play Killer Sudoku levels ≥30 several times and confirm
you sometimes see one cage's displayed sum is +3 too high and that cage's own digit-repeat
check (but not its sum) is what's enforced.

---

## Fix 3 — Minesweeper: add `blind`

**File:** `lib/screens/games/mine_finder/mine_finder_screen.dart`

**Why:** self-contained boolean guard, no daily-specific data dependency.

**Current code** (`_toggleFlag`):
```dart
      if (_playDailyMode && _dailyModifierType == 'blind') {
        if (_flagged[r][c] && !_mines[r][c]) {
          // Flagged a safe cell - instantly lost!
          _lost = true;
          _message = 'Oops! Flagged a safe cell.';
```

**Replacement code:**
```dart
      if ((_playDailyMode && _dailyModifierType == 'blind') || (!_playDailyMode && _levelIndex >= 30 && _activeModifiers.contains('blind'))) {
        if (_flagged[r][c] && !_mines[r][c]) {
          // Flagged a safe cell - instantly lost!
          _lost = true;
          _message = 'Oops! Flagged a safe cell.';
```

**Pool list — current code:**
```dart
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'mines',
        levelIndex: _levelIndex,
        pool: ['limitedFlags', 'hiddenCount', 'timer'],
        minActive: 2,
        maxActive: 3,
        smallGrid: _gridSize <= 10,
      );
```

**Replacement code:**
```dart
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'mines',
        levelIndex: _levelIndex,
        pool: ['limitedFlags', 'hiddenCount', 'timer', 'blind'],
        minActive: 2,
        maxActive: 3,
        smallGrid: _gridSize <= 10,
      );
```

Do **not** also add `fog`/`spotlight`/`spotlight2` — there's an explicit code comment in
this file stating fog is "removed for normal/endgame levels," and `hidden_rule`'s logic
is scattered across generation, tap handling, and rendering (3+ separate sites) rather
than centralized — both need a real scoped pass, not a quick pool edit. See exclusions.

**How to verify:** replay free-play Minesweeper levels ≥30 several times and confirm
flagging a non-mine cell sometimes instantly ends the level (previously only possible via
a matching Daily Challenge).

---

## Fix 4 — Bridges: add `fog`

**File:** `lib/screens/games/bridges/bridges_screen.dart`

**Why:** `fog` wraps the board in the same generic `FogOverlay` widget other games already
use in their endgame pools; no daily-specific data dependency.

**Current code** (`_isFogActive` getter, verify this matches before editing — this one
was not re-confirmed against the live file in this pass, only located by an earlier
survey):
```dart
  bool get _isFogActive => _playDailyMode && _dailyModifierType == 'fog';
```

**Replacement code** (mirror the existing dual-mode pattern already used by
`_isHiddenIslandsActive` in this same file):
```dart
  bool get _isFogActive {
    if (_playDailyMode) return _dailyModifierType == 'fog';
    return !_playDailyMode && _currentLevel >= 30 && _activeModifiers.contains('fog');
  }
```

**Pool list — current code:**
```dart
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'bridges',
        levelIndex: _currentLevel,
        pool: ['hiddenIslands', 'timer', 'zoom'],
        minActive: 1,
        maxActive: 2,
        smallGrid: _gridSize <= 6,
      );
```

**Replacement code:**
```dart
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'bridges',
        levelIndex: _currentLevel,
        pool: ['hiddenIslands', 'timer', 'zoom', 'fog'],
        minActive: 1,
        maxActive: 2,
        smallGrid: _gridSize <= 6,
      );
```

**How to verify:** replay free-play Bridges levels ≥30 and confirm the fog-of-war
visibility radius sometimes appears around your touch point.

---

## Fix 5 — Odd Color Out: add `monochrome`, `whisper`, `prism`, `eclipse`, `fog`, `retro`

**File:** `lib/screens/games/odd_color_out/odd_color_out_screen.dart`
**gameId used in code:** `'oddcolorout'` (not `'oddcolor'` — see master-table note)

**Why:** all six are fully built for Daily Challenge, gated only by
`_isDailyMode && _dailyModifierType == 'X'`, with no daily-specific data dependency, and
none conflict with each other. (`hidden_rule` is deliberately **excluded** from this list
— see exclusions section, it would collide with the existing `hueChannel` pool entry.)

### Step 1 — add a small shared helper (this file touches the same gating pattern 7
times across 6 modifiers; one helper avoids repeating — and risking a typo in — the same
3-clause boolean 7 times)

Add this method to the class (anywhere near the other getters is fine):
```dart
  bool _isModActive(String name) {
    if (_isDailyMode) return _dailyModifierType == name;
    return !_isDailyMode && _levelIndex >= 30 && _activeModifiers.contains(name);
  }
```

### Step 2 — pool list (**two identical call sites — update both**)

**Current code** (appears twice, lines ~138–143 and ~299–304):
```dart
        final activeMods = RotationEngine.getActiveModifiers(
          gameId: 'oddcolorout',
          levelIndex: _levelIndex,
          pool: ['hueChannel', 'noise', 'gradient', 'timer'],
          smallGrid: _gridSide <= 5,
        );
```

**Replacement code** (apply to **both** occurrences, identically):
```dart
        final activeMods = RotationEngine.getActiveModifiers(
          gameId: 'oddcolorout',
          levelIndex: _levelIndex,
          pool: ['hueChannel', 'noise', 'gradient', 'timer', 'monochrome', 'whisper', 'prism', 'eclipse', 'fog', 'retro'],
          minActive: 2,
          maxActive: 4,
          smallGrid: _gridSide <= 5,
        );
```
(Pool goes from 4 to 10 entries — `maxActive` bumped to 4, same reasoning as Sudoku's
Fix 1, so the 6 new entries aren't crowded out by the original 4.)

### Step 3 — widen each of the 6 simple, single-line sites

**`monochrome`** — current code:
```dart
    final double saturation = (_isDailyMode && _dailyModifierType == 'monochrome') ? 0.0 : (0.55 + rand.nextDouble() * 0.35);
```
Replacement:
```dart
    final double saturation = _isModActive('monochrome') ? 0.0 : (0.55 + rand.nextDouble() * 0.35);
```

**`whisper`** — current code:
```dart
      if (_isDailyMode && _dailyModifierType == 'whisper') {
        delta = 0.015;
      }
```
Replacement:
```dart
      if (_isModActive('whisper')) {
        delta = 0.015;
      }
```

**`prism`** — current code:
```dart
      } else if (_isDailyMode && _dailyModifierType == 'prism') {
```
Replacement:
```dart
      } else if (_isModActive('prism')) {
```

**`eclipse` (overlay render site only)** — current code:
```dart
                            if (_isDailyMode && _dailyModifierType == 'eclipse')
```
Replacement:
```dart
                            if (_isModActive('eclipse'))
```

**`fog`** — current code:
```dart
                        enabled: _isDailyMode && _dailyModifierType == 'fog',
```
Replacement:
```dart
                        enabled: _isModActive('fog'),
```

**`retro`** — current code:
```dart
                                        if (_isDailyMode && _dailyModifierType == 'retro')
```
Replacement:
```dart
                                        if (_isModActive('retro'))
```

### Step 4 — `eclipse` timer-start site — **verify context before editing**

There's a second `eclipse` site, the one that actually starts the periodic overlay
timer, currently:
```dart
    if (_isDailyMode) {
      if (_dailyModifierType == 'eclipse') {
```
This is a nested `if`, not a single-line condition — the outer `if (_isDailyMode)` may
wrap other daily-only setup besides eclipse. Read the full surrounding block first:
- If the outer block contains **only** the eclipse timer setup, collapse both lines to
  `if (_isModActive('eclipse')) {`.
- If the outer block contains other daily-only logic alongside the eclipse check, **do
  not** collapse the outer wrapper — instead leave `if (_isDailyMode) { if
  (_dailyModifierType == 'eclipse') { ... } ... other daily-only stuff ... }` as-is, and
  add a **sibling** `else if (!_isDailyMode && _levelIndex >= 30 &&
  _activeModifiers.contains('eclipse')) { /* same timer-start body as the daily branch */
  }` after the outer `if` block, duplicating just the timer-start body (not the other
  daily-only logic) into free-play mode.

**How to verify:** Jump-to-Level to several free-play Odd Color Out levels ≥30 several
times and confirm you see grayscale grids (monochrome), near-invisible odd tiles
(whisper), diagonal-split hue halves (prism), the periodic blackout overlay (eclipse),
fog-of-war (fog), and the CRT/scanline visual skin (retro) show up across different
level visits — not just hueChannel/noise/gradient/timer every time.

---

## Fix 6 — Zip: add `retro`, `minimal`

**File:** `lib/screens/games/grid_path/grid_path_screen.dart`

**Why:** both are visual/UI-only effects with existing implementing code.

**Pool list — current code:**
```dart
      activeMods = RotationEngine.getActiveModifiers(
        gameId: 'zip',
        levelIndex: levelIndex,
        pool: ['waypointSparsity', 'nonRectShape', 'timer'],
        minActive: 2,
        maxActive: 3,
```

**Replacement code:**
```dart
      activeMods = RotationEngine.getActiveModifiers(
        gameId: 'zip',
        levelIndex: levelIndex,
        pool: ['waypointSparsity', 'nonRectShape', 'timer', 'retro', 'minimal'],
        minActive: 2,
        maxActive: 3,
```

**`retro` — verify context before editing.** The painter-side check is:
```dart
    final isRetro = modifierType == 'retro';
```
This reads a `modifierType` parameter passed into `_ZipPainter`'s constructor — find
that constructor call site (search for `_ZipPainter(` in the build method) and check
what value is currently passed for `modifierType`. It's very likely
`_dailyModifierType` directly, which means widening the painter-side literal alone does
nothing in free play — the fix has to happen at the call site, passing something like
`_playDailyMode ? _dailyModifierType : (activeMods.contains('retro') ? 'retro' : '')`
(or whatever the actual field holding the endgame modifier set is named in this file —
confirm the exact field name first, it may not be `activeMods` outside the
level-generation function shown above).

**`minimal` — verify context before editing.** Current code:
```dart
    _blindStepsTimer?.cancel();
    _hideGridPathElements = false;
    if (_isDailyMode && _dailyModifierType == 'minimal') {
      _blindStepsTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _hideGridPathElements = true;
          });
        }
      });
    }
```
Confirm the class-level field name used for tracking endgame level index in this file
(the pool call above uses a local `levelIndex` parameter, not necessarily a field named
`_levelIndex` — check what field this widget actually stores its current level in) before
writing the free-play half of the condition. Once confirmed, widen to:
```dart
    _blindStepsTimer?.cancel();
    _hideGridPathElements = false;
    if ((_isDailyMode && _dailyModifierType == 'minimal') || (!_isDailyMode && <levelField> >= 30 && _activeModifiers.contains('minimal'))) {
      _blindStepsTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _hideGridPathElements = true;
          });
        }
      });
    }
```
replacing `<levelField>` with whatever that field actually is.

Do **not** attempt `mirror` in this pass — it flips the win-direction logic
(`_isReversePath`, start/end swap) across the hint solver, win-check, and both
drag/tap input handlers, not just rendering. Real scoped work, see exclusions.

**How to verify:** replay free-play Zip levels ≥30 several times and confirm the retro
visual skin and the delayed waypoint-hiding effect both show up on some levels.

---

## Fix 7 — Pattern Lock: add `eclipse`, and fix dead `memorizeTimer`

**File:** `lib/screens/games/beta/pattern_lock_beta.dart`

**Why (`eclipse`):** its activation check, `_activeModifiers.contains('eclipse')`, is
already completely ungated by daily/endgame mode — it just needs the string added to the
endgame pool for `RotationEngine` to ever select it in free play.

**Current code:**
```dart
        _activeModifiers = RotationEngine.getActiveModifiers(
          gameId: 'patternlock',
          levelIndex: _currentLevel,
          pool: ['pathComplexity', 'distractorDots', 'gridSize', 'boardTransform', 'memorizeTimer'],
          minActive: 2,
          maxActive: 3,
          smallGrid: (baseN <= 5),
        );
```

**Replacement code:**
```dart
        _activeModifiers = RotationEngine.getActiveModifiers(
          gameId: 'patternlock',
          levelIndex: _currentLevel,
          pool: ['pathComplexity', 'distractorDots', 'gridSize', 'boardTransform', 'memorizeTimer', 'eclipse'],
          minActive: 2,
          maxActive: 3,
          smallGrid: (baseN <= 5),
        );
```

**Bonus bug found during this survey, same file:** `memorizeTimer` is already in the
pool above (so `RotationEngine` does sometimes select it) but has been dead this whole
time — search for `hasMemorizeTimer` in this file; it's hardcoded to `false` around line
317, so the pool entry currently does nothing no matter how many times it's rolled. This
wasn't caught in the original pool audit (that audit only checked `gridSize`, this one
was missed). Grep for the literal `hasMemorizeTimer` assignment, read the surrounding
function to see what it *should* be gated on, and — if there's no other blocker visible
— change it to read `_activeModifiers.contains('memorizeTimer')` instead of the
hardcoded `false`, following the same pattern every other real modifier in this file
uses. Verify with `flutter analyze` and a Jump-to-Level replay before considering this
one done — don't assume the one-line swap is complete without reading what's around it
first, since this file wasn't fully re-read in this pass.

**How to verify (`eclipse`):** Jump-to-Level to free-play Pattern Lock levels ≥30 several
times and confirm the board sometimes fades to near-invisible on a timer, forcing you to
recall the pattern from memory.

---

## Fix 8 — Colour Link: add `monochrome`

**File:** `lib/screens/games/beta/numberlink_beta.dart`

**Why:** self-contained palette swap, no daily-specific data dependency.

**Current code** (`_colors` getter):
```dart
  List<Color> get _colors {
    if (_playDailyMode && _dailyModifierType == 'monochrome') {
      return const [
        Color(0xFFE0E0E0), // Very light grey
        Color(0xFF9E9E9E), // Medium grey
        Color(0xFF616161), // Dark grey
        Color(0xFFBDBDBD), // Silver grey
        Color(0xFF757575), // Charcoal grey
        Color(0xFFEEEEEE), // Off white
        Color(0xFF424242), // Very dark grey
        Color(0xFFCCCCCC), // Light silver
      ];
    }
    return [
```

**Replacement code:**
```dart
  List<Color> get _colors {
    final bool monochrome = (_playDailyMode && _dailyModifierType == 'monochrome') ||
        (!_playDailyMode && _currentLevel >= 30 && _activeModifiers.contains('monochrome'));
    if (monochrome) {
      return const [
        Color(0xFFE0E0E0), // Very light grey
        Color(0xFF9E9E9E), // Medium grey
        Color(0xFF616161), // Dark grey
        Color(0xFFBDBDBD), // Silver grey
        Color(0xFF757575), // Charcoal grey
        Color(0xFFEEEEEE), // Off white
        Color(0xFF424242), // Very dark grey
        Color(0xFFCCCCCC), // Light silver
      ];
    }
    return [
```

**Pool list — current code:**
```dart
        _activeModifiers = RotationEngine.getActiveModifiers(
          gameId: 'colourlink',
          levelIndex: _currentLevel,
          pool: ['gridSize_pairCount', 'walls', 'tortuosity', 'timer'],
          smallGrid: _gridSize <= 5,
        );
```

**Replacement code:**
```dart
        _activeModifiers = RotationEngine.getActiveModifiers(
          gameId: 'colourlink',
          levelIndex: _currentLevel,
          pool: ['gridSize_pairCount', 'walls', 'tortuosity', 'timer', 'monochrome'],
          smallGrid: _gridSize <= 5,
        );
```

**How to verify:** replay free-play Colour Link levels ≥30 several times and confirm the
grid sometimes renders in 8 shades of grey instead of its normal color palette.

---

## Fix 9 — Circuit Guide: add `retro`

**File:** the Circuit Guide game file (`lib/screens/games/beta/circuit_guide_beta.dart`
or wherever `gameId: 'circuitguide'` lives)

**Why:** the only daily-only extra in this file, and it's already checked via
`_activeModifiers.contains('retro')` with no daily-only gate at all — genuinely just a
pool-string add, nothing else.

**Current code:**
```dart
        _activeModifiers = RotationEngine.getActiveModifiers(
          gameId: 'circuitguide',
          levelIndex: _currentLevel,
          pool: ['tortuosity', 'junctionDensity', 'decoyWires', 'scrambleDepth', 'timer'],
          minActive: 2,
          maxActive: 3,
```

**Replacement code:**
```dart
        _activeModifiers = RotationEngine.getActiveModifiers(
          gameId: 'circuitguide',
          levelIndex: _currentLevel,
          pool: ['tortuosity', 'junctionDensity', 'decoyWires', 'scrambleDepth', 'timer', 'retro'],
          minActive: 2,
          maxActive: 3,
```

**How to verify:** replay free-play Circuit Guide levels ≥30 several times and confirm
the green pixel/CRT wire-rendering skin shows up sometimes.

---

## Fix 10 — Chimp (Patches): add `gravity`

**File:** `lib/screens/games/patches/patches_screen.dart`

**Why:** `_sinkUntappedNumbers()` already exists and is already wired to two separate
triggers (`_dailyModifierType == 'gravity'` for daily, and `_hasDecoyTiles`
— `_chimpCycle >= 4` — as an automatic non-selectable behavior at very high non-pool
levels). This just makes it independently selectable by the endgame pool too.

**Current code** (`_applyDailyPositionModifier`, the `else` branch that runs in
free-play):
```dart
    } else {
      if (_hasPositionShuffle && _correctTapCount >= 3 && !_chaosShuffleDone) {
        _shuffleUntappedNumbers();
        _chaosShuffleDone = true;
      }
      if (_hasDecoyTiles) {
        // Apply gravity to move things around as an extra challenge
        _sinkUntappedNumbers();
      }
    }
```

**Replacement code:**
```dart
    } else {
      if (_hasPositionShuffle && _correctTapCount >= 3 && !_chaosShuffleDone) {
        _shuffleUntappedNumbers();
        _chaosShuffleDone = true;
      }
      if (_hasDecoyTiles || _activeModifiers.contains('gravity')) {
        // Apply gravity to move things around as an extra challenge
        _sinkUntappedNumbers();
      }
    }
```

**Pool list — current code:**
```dart
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'chimp',
        levelIndex: _levelIndex,
        pool: ['numbersHide', 'spatialSpread', 'positionShuffle', 'timer', 'glitch'],
        minActive: 2,
        maxActive: 3,
```

**Replacement code:**
```dart
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'chimp',
        levelIndex: _levelIndex,
        pool: ['numbersHide', 'spatialSpread', 'positionShuffle', 'timer', 'glitch', 'gravity'],
        minActive: 2,
        maxActive: 3,
```

**How to verify:** replay free-play Chimp levels ≥30 (well below the `_chimpCycle >= 4`
auto-trigger point) several times and confirm untapped numbers sometimes sink downward
after being revealed, even at levels where that wouldn't normally auto-trigger.

---

## Fix 11 — Sum Strike: add `fog`

**File:** `lib/screens/games/sum_strike/sum_strike_screen.dart`

**Why:** unlike a typical "needs a default radius" case, this one is actually free —
`_dailyRadius` already defaults to `1.5` and is only overwritten when
`_playDailyMode` is true and `dailyModifierExtraParams` has a `radius` key. In free
play that overwrite branch never runs, so `_dailyRadius` naturally stays at its `1.5`
default with zero extra plumbing needed.

**Current code:**
```dart
                            child: FogOverlay(
                              enabled: _playDailyMode && _dailyModifierType == 'fog',
                              radius: cellW * _dailyRadius,
```

**Replacement code:**
```dart
                            child: FogOverlay(
                              enabled: (_playDailyMode && _dailyModifierType == 'fog') ||
                                  (!_playDailyMode && _currentLevel >= 30 && _activeModifiers.contains('fog')),
                              radius: cellW * _dailyRadius,
```

**Pool list — current code:**
```dart
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'sumstrike',
        levelIndex: _currentLevel,
        pool: ['negatives', 'denseStrike', 'timer', 'whisper'],
        minActive: 1,
        maxActive: 2,
```

**Replacement code:**
```dart
      _activeModifiers = RotationEngine.getActiveModifiers(
        gameId: 'sumstrike',
        levelIndex: _currentLevel,
        pool: ['negatives', 'denseStrike', 'timer', 'whisper', 'fog'],
        minActive: 1,
        maxActive: 2,
```

**How to verify:** replay free-play Sum Strike levels ≥30 several times and confirm
fog-of-war visibility (radius ~1.5 cells around touch) sometimes appears.

---

## Deliberately excluded from this batch

Same spirit as the prior audit's `variantRule`/Masyu call-outs — these looked like
candidates but need real scoped work, not a quick pool edit. Don't implement any of
these as part of applying the fixes above.

- **Star Battle — `hidden_rule`, `spy`.** Both are hardcoded to
  `_playDailyMode && _dailyModifierType == 'X'` across ~5 call sites combined (generation
  logic, win-check, region-counting), not a single getter. Porting means rewriting every
  site to check `_activeModifiers` instead, and re-verifying the win-condition logic
  (`spy` changes required star count) still holds correctly in free play. Scope as its
  own task.

- **Masyu — no endgame pool at all.** Still true after the regression fix (which only
  removed the dead `_generateEndgameLevel` method, per the prior doc's Option A). Now
  that the prism validator bug is fixed, `prism` is genuinely safe to eventually port
  (it's visual-only and can no longer make a board unsolvable) — but there is still no
  pool infrastructure in this file at all, and the prior audit's core warning stands:
  don't wire in procedural endgame generation without verifying every generated board
  via `_countMasyuSolutions` first. Real feature work, own task.

- **Minesweeper — `hidden_rule`.** Logic is scattered across generation, tap-handling,
  and rendering (3+ separate `_dailyModifierType` checks plus an `_isCorner` helper) —
  needs centralizing behind one `_activeModifiers` flag before it can be pool-selectable,
  not a one-line add.

- **Minesweeper — `fog`/`spotlight`/`spotlight2`.** An explicit code comment says fog
  is "removed for normal/endgame levels" — that's a design decision already made in the
  code, not an oversight. Don't silently override it without confirming with whoever made
  that call.

- **Odd Color Out — `hidden_rule`.** Currently mutually exclusive with the existing
  `hueChannel` pool entry only because `_isDailyMode` gates them apart (both are hue-band
  restriction mechanics). Widening `hidden_rule` to fire in free play the same way as the
  6 modifiers in Fix 5 would let `RotationEngine` select both `hidden_rule` and
  `hueChannel` in the same level, and nothing in the code currently defines which one
  should win. Needs an explicit precedence decision (or keeping them permanently mutually
  exclusive some other way) before it's safe to add — same category of risk as Sudoku's
  `variantRule` exclusion in the prior doc.

- **Zip — `mirror`.** Changes win-direction logic (start/end swap, `_isReversePath`)
  across the hint solver, win-check, and both drag/tap handlers — not a rendering-only
  effect like `retro`. Needs its own pass.

- **Pattern Lock — `mirror`.** The existing `boardTransform` endgame modifier already
  randomly picks between CW/180°/Mirror as one of its outcomes; a standalone `mirror`
  entry would need either a new branch or a decision to just let `boardTransform`'s
  existing Mirror outcome cover this instead of adding a redundant second entry.

- **Chimp — `time_warp`, `chaos`.** Functionally near-duplicates of the already-present
  `numbersHide`/`positionShuffle` pool entries (same underlying functions, different
  string). Adding them would be trivial mechanically but wouldn't add real new variety —
  skipped as redundant, not because they're hard.

- **Word Hive — `restriction`, `spotlight2`.** Referenced by the daily-challenge config
  (`daily_challenge_manager.dart`) but have **zero** implementing code anywhere in
  `word_hive_screen.dart` — these are dead config entries, not a pool-omission bug.
  Flagging for awareness; not in scope to invent an implementation here.
