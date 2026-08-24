# CogniQ — Release Plan of Record (1.9 → 2.6)

**Written:** 2026-08-22, immediately after shipping `versions/1.8(50).aab`.
**Status:** agreed with the owner. This is the plan of record. It supersedes the deleted
`FEATURE_ROADMAP.md`. It does **not** supersede `md/remember.md`, which remains the
authority on hard constraints, verified findings, and the performance rulebook.

> **WHO THIS DOCUMENT IS FOR.** A developer or AI agent with **zero prior context** —
> possibly not the agent that wrote it. It is deliberately self-contained: project
> facts, architecture map, per-release work orders with file paths and search strings,
> verification steps, and the traps that have already burned this project once.
> Read Part 0 and Part 1 fully before writing any code. Line numbers are locators from
> 2026-08-22 and WILL drift — the quoted search strings are the source of truth.

---

# PART 0 — PROJECT SNAPSHOT (verified 2026-08-22)

- **What:** CogniQ, a Flutter brain-training puzzle app, live on Google Play as
  `com.mayank.cogniq`. **17 active games** as of 2026-08-22 (Kakuro was revived from
  the stash during 1.9), each with 70+ levels.
- **Version state:** `pubspec.yaml` says `1.8.0+51`. That is correct: build `+50`
  shipped (the `.aab` is in `versions/1.8(50).aab`) and the convention is to bump the
  build number immediately *after* copying the bundle out, so the tree always carries
  the **next** build number. The 1.9 release will ship as `1.9.0+51` (or later if
  interim builds are made).
- **Architecture:** fully **offline-first**. All state in `SharedPreferences`. There is
  **no network layer, no analytics, no backend, no accounts** (until 2.0 adds
  analytics). `google_mobile_ads` and `in_app_purchase` are the only outward-facing
  dependencies.
- **Toolchain:** Flutter ~3.41 / Dart ~3.11 on **Windows**. PowerShell is the primary
  shell.
- **NOT a git repository.** Version tracking is the `versions/` folder system
  (Part 6). Recommending `git init` + tag-per-release to the owner is welcome but it
  has not been done.
- **Test state (2026-08-22, mid-1.9):** `flutter analyze` = **0 errors** (~373
  info-level lints, mostly `withOpacity` deprecations — harmless for now).
  `flutter test` = **235 tests, all passing**. Keep it that way: any release with
  failing tests or analyzer errors does not ship.
- **Known build quirk:** `flutter build appbundle` prints a *"failed to strip debug
  symbols"* error because the Android SDK path contains a space
  (`C:\Users\Lancia-AI Bot\...`). **The `.aab` is still produced and valid** —
  signature, ABIs and contents were verified on 1.8(50). Do not "fix" this by moving
  the SDK without the owner's say-so; just know the error is cosmetic.
- **Signing:** Play App Signing; upload keystore `android/app/upload-keystore.jks`,
  key alias `upload`. `android/app/build.gradle.kts` has a null-guarded signing config
  with a debug fallback — do not restructure the path resolution (a previous
  `rootProject.file(...)` "improvement" broke the build; paths are resolved relative
  to `android/app/`).

## Working agreements with the owner (violating these loses trust)

1. **Do not spawn subagents without explicit approval** — the owner's usage limit is
   tight.
2. **Ask before building an app bundle.** Never build one unprompted.
3. **Ask before starting each revival/major feature** — present a short plan or
   options first, ideally as multiple-choice questions. The owner decides; then build.
4. **Never rename a game ID** (`remember.md` §12) — IDs are baked into save keys and
   seeded generation. Renaming silently wipes player progress.
5. Testing in Chrome (`flutter run -d chrome`) is expected for UI/feature checks, but
   understand its limits (Part 6).
6. Report honestly: failing tests are reported as failing; skipped work is stated.

---

# PART 1 — ARCHITECTURE MAP (what an incoming agent must know)

## 1.1 Game registry and routing

- **`lib/models/game_info.dart`** — `kAllGames` list; each entry has `id`, `name`,
  `description`, `emoji`, `routeName`, `isStashed`. **`isStashed: true` = hidden from
  the entire app** (home grid, shuffle, achievements denominator). Flipping it to
  `false` is the *last* step of shipping a game, never the first.
- **`lib/main.dart`** — routes map (~line 200–240, search `'/zip'`). Every game,
  stashed or not, has a route here. New game = new route + import.
- The 17 active game IDs: `kakuro` (revived 2026-08-22), `zip` (Grid Path), `oddcolor` (Odd Color Out), `chimp`
  (Chimp Test), `queens` (Star Battle), `minesweeper` (Mine Finder), `hue` (Spectrum),
  `sudoku`, `spellingbee` (Word Hive), `pattern_lock`, `colour_link`, `color_flood`,
  `circuit_guide`, `masyu` (Pearl Loop), `bridges`, `sumstrike`, `killersudoku`.
  ⚠️ Registry IDs and the gameId strings passed to `RotationEngine` sometimes differ
  (e.g. registry `oddcolor` vs engine `'oddcolorout'`, registry `minesweeper` vs
  engine `'mines'`). **Always grep the game's screen file for the string it actually
  passes** — never assume.

## 1.2 The manager layer (static classes, `lib/utils/`)

- **`rotation_engine.dart`** — the difficulty spine.
  - `getDeterminism(gameId, level)` → seeded `Random`. **THE SEEDED-RNG LAW: never
    write bare `Random()` in game code.** Same (gameId, level) must generate the same
    puzzle on every device, forever.
  - `getActiveModifiers(gameId:, levelIndex:, pool:, minActive:, maxActive:,
    smallGrid:)` → `Set<String>`. Selection is combination-exhaustive: all singles,
    then all pairs, then triples ("breadth-then-intensity"). Returns `{}` when Zen
    mode is on.
  - `modifierStartLevel(gameId)` — per-game onset (bridges/masyu 10; sumstrike/
    killersudoku/spellingbee 12; circuitguide 14; oddcolorout/sudoku 20; mines/
    patternlock/queens/zip/colorflood/chimp 30; default 15).
  - `getDecayValue(level:, start:, floor:, rate:)` — smooth curve helper.
- **`prefs_keys.dart`** — ALL save keys. `gameLevel(id)`, `clearedCount(id)` are
  **mode-aware**: they resolve to Zen keys (`zen_level_<id>`, …) when Zen is on.
  `normalGameLevel(id)` / `normalClearedCount(id)` read Challenge-mode values
  explicitly (used by achievements so Zen progress can't leak into Challenge rewards).
  **New games must use `PrefsKeys.gameLevel('<id>')`**, NOT a hand-rolled
  `'<id>_level'` string (the builders handbook §3.6 predates this and shows the old
  way — do not copy it).
- **`zen_mode.dart`** — `ZenMode.isEnabled` (sync), toggled from the home screen.
  Zen = no modifiers, half points, parallel level progression, own achievements/trail.
  A game gets Zen support **for free** iff it (a) saves via mode-aware `PrefsKeys`,
  (b) routes wins through `HintManager.onLevelCleared` (which does the Zen-aware
  clear counting — see its `ZenMode.isEnabled` branch), and (c) gets modifiers via
  `RotationEngine`. Bypassing any of the three (e.g. hand-writing
  `globalLevelClearedCount`) breaks Zen/trail accounting.
- **`progress_guard.dart`** — `ProgressGuard.saveLevel(gameId, level, isDaily:)`:
  forward-only saves, never during a daily challenge. Use it instead of raw
  `prefs.setInt` for level saves.
- **`hint_manager.dart`** — hint economy. `startLevel(id)`, `useHint(id)`,
  `onLevelCleared(id)`. **Every win must call `onLevelCleared`.**
- **`point_manager.dart`** — `addPoints(n)` on win (typical n = 5–10; Zen halves).
- **`achievement_manager.dart`** — manual-claim model (`checkAndUnlock` marks,
  `claim(id)` dispatches rewards). `completionist` compares against
  `activeGames.length` (search `playedGamesCount >= activeGames.length`) — it is
  **relative by owner decision**: un-stashing a game raises the bar automatically.
  Expected behaviour, not a bug.
- **`trail_catalog.dart`** — trail unlocks; `pointsOnly = 999999` sentinel must never
  satisfy `isEarnedByClears`.
- **`daily_challenge_manager.dart`** — daily system. **OFF-LIMITS per `remember.md`
  Section A** except where this plan explicitly schedules S2 (owner-approved
  exception, 2026-08-22).
- **`lib/theme/settings_manager.dart`** — settings + haptics. `hapticTap()`,
  `hapticSuccess()`, `hapticError()` gate on `_hapticEnabled`. ⚠️ The builders
  handbook (§1.15/§3.8) claims the app has zero haptics and tells you to build a
  `Haptics` class + toggle. **That is stale — it all exists. Skip handbook §3.8
  entirely; call `SettingsManager`'s helpers.**
- **`lib/theme/app_theme.dart`** — `AppTheme.accentFor(id)` + palette. Never hardcode
  colors in game screens.

## 1.3 Standard UI contract (every game screen)

- **Header:** `GameTitle` (game name) as the AppBar title + `GameLevelChip` (level
  pill + jump-to-level pencil) as the LAST AppBar action. Both in
  `lib/widgets/game_level_chip.dart`. **Nothing else shows the level.** This was
  standardized in 1.8 across all 16 games; do not invent a fourth header variant.
- Shared widgets: `ConfettiOverlay`, `AutoNextCountdown`, `LossOverlay`,
  `GameTutorialDialog`, `BuyHintsDialog`, `FogOverlay` (all `lib/widgets/`). Check
  constructor params at a live call site (e.g. `grid_path_screen.dart`) before use.
- Performance rules are `remember.md` Section E — mandatory. Summary: no per-frame
  `setState` in pan handlers; `ValueNotifier` + painter `repaint:` for hot paths;
  `RepaintBoundary` around boards; honest `shouldRepaint`; defer disk writes to
  `onPanEnd`; O(1) lookups in `paint()`.

## 1.4 Test harnesses (add every new/revived game to these)

- `test/all_games_all_levels_test.dart` — boots every game at ~10 level checkpoints,
  catches layout overflows + boot crashes (uses `FlutterError.onError`).
- `test/difficulty_curve_test.dart` — asserts difficulty never decreases.
- `test/layout_overflow_test.dart`, `test/modifier_ramp_test.dart`,
  `test/trail_catalog_test.dart`, `test/progress_guard_test.dart`,
  `test/sudoku_levels_test.dart` — patterns to copy.
- Widget-test boilerplate: `TestWidgetsFlutterBinding.ensureInitialized()` +
  `SharedPreferences.setMockInitialValues({})`.

## 1.5 Document trust map (`md/` folder)

| File | Trust level |
|---|---|
| `remember.md` | **Authoritative.** Read Sections A–E before coding. D5 = beta-prototype audit. |
| `RELEASE_PLAN.md` (this) | **Plan of record.** |
| `cogniq_builders_handbook.md` | **The build spec for every new game and modifier in this plan.** This plan decides *what and when*; the handbook says *how*. See §1.6 below for the full mapping and the list of handbook sections that are stale or superseded. |
| `GAME_WIRING_CHECKLIST.md` | **Verified handbook** — per-step "why / symptom if missed" checklist for wiring a new or refactored game screen. Use alongside checklist 3.2. Relocated from repo root 2026-08-22. |
| `SEASONAL_ROTATION_SPEC.md` | **Feeds S3 (2.1).** An existing worked plan for seasonal daily-challenge rotation (15-day blocks, recap screen, per-user progression from day 1, keeping the 30-day static plan as starting content). Read it before designing the event framework. Note: its "add ~20 new games as definitions" idea is superseded by this plan's calendar. Relocated 2026-08-22. |
| `GAME_BACKLOG_SPEC.md` | 55 unimplemented puzzle types with data models, rules, generation strategies and solution-checking — **logic specs only**, no UI. Far more reliable than the deleted `GAME_SUGGESTIONS_WITH_DESIGN.md`. Source for post-2.6 game picks. Verify any spec against a solver before building (rule 3.2). Relocated 2026-08-22. |
| `POINTS_ECONOMY_SPEC.md` | Historical design record for the points economy (10/clear, 60/hint, 80/rewarded ad) — **already implemented** as `PointManager`. Reference only. Relocated 2026-08-22. |
| `modifier_pool_expansion.md` | Correct and **mostly already implemented**; its file paths are stale (pre-restructure: `beta/killer_sudoku_beta.dart` → `killer_sudoku/killer_sudoku_screen.dart`, `patches/` → `chimp_test/`). Its "Deliberately excluded" section still applies. |
| *(deleted 2026-08-22)* | `ACCESSIBILITY_RECOMMENDATIONS.md`, `GAME_SUGGESTIONS_WITH_DESIGN.md`, `SOCIAL_COMMUNITY_FEATURES.md`, `ONBOARDING_STRATEGY.md` — all proposal docs, removed after everything actionable was lifted into this plan (accessibility quick wins → work order 4.1C; social requirements → Part 8 backlog). The game-suggestions doc contained factual errors (invalid Latin square, wrong Kuromasu rules); the onboarding doc advertised features that do not exist. If a file with one of these names reappears, treat it as untrusted. |

## 1.6 How this plan and `cogniq_builders_handbook.md` work together

The two documents are companions with a strict division of labour:

- **This plan** owns *sequencing, scope, decisions, and diagnoses.* Its work orders
  (Part 4) carry only the **deltas** to the handbook — corrections, integration
  requirements, and release-specific constraints.
- **The handbook** owns *build instructions* — architecture pattern (Part 2), widget
  primer (Part 1), copy-paste integration templates (Part 3), per-modifier
  implementations (Part 4, §A1–A12), and per-game builds (Part 5, §B1–B9) including
  complete logic-file code. **When building anything named below, open the handbook
  section and follow it**, applying this plan's deltas on top.
- **Where they conflict, this plan wins.** In particular, the handbook's own roadmap
  (§6.4 "The complete roadmap", Phases 0–6) predates this plan and is **superseded by
  the Part 2 calendar** — do not sequence work from §6.4. Use the handbook for *how*,
  never for *when*.

### Handbook item → release mapping

| Handbook § | Item | Release | Deltas (authoritative in this plan) |
|---|---|---|---|
| B7 | Sand Sort | **1.9** | ⚠️ Its `generate()` is unsafe — mandatory correction in work order 4.1B |
| B6 | Light Beam | **2.0** | Verify generator per checklist 3.2 (work order 4.2B) |
| B5 | Zen Slide | **2.1** | Its BFS-gated generator is sound; ship Tier 1 static greys first (per handbook) |
| B1 | Untangle | **2.2** | Build clean — its painter patterns are One Stroke's prerequisite |
| A6, A3, A8, A7 | `silence`, `quota`, `ratchet`, `wildcard` | **2.1** (batch 1) | `ratchet`+`silence` never in the same pool; `wildcard` uses a salted seed |
| A9, A2, A4 | `momentum`, `decay`, `heartbeat` | **2.2** (batch 2) | `momentum` replaces flat win points with `(10 × avgMultiplier)` |
| B3 | Orbit | **2.4** | Do the Tier 2 painter upgrade **within the release** — its Tier 1 is the handbook's self-admitted worst janker |
| B2 | One Stroke | **2.4** | Parity-fixer + connectivity check are mandatory; include "Rewind 1" |
| A10, A1, A5, A11 | `seismic`, `drift`, `vertigo`, `inverse` | **2.6** (batch 3) | `vertigo` Tier 1 only on tap-games; skip Color Flood's `inverse` variant |
| A12 | `twin` | backlog | Needs mature Tier-2 painters first |
| B4 | Mirror Trace | backlog | — |
| B8, B9 | Split, Shadow Match | backlog | Perception ceiling (Part 7) — last, if ever |
| *(none)* | **Skyscrapers, Nurikabe** (2.6) | **2.6** | ⚠️ **Not in the handbook.** Build spec = the beta prototype + `remember.md` D5 audit + checklist 3.2. Handbook Parts 1–3 (patterns/templates) still apply. |

### Handbook sections known stale or superseded — do NOT follow as written

| Section | Problem | Do instead |
|---|---|---|
| §6.4 roadmap | Predates this plan | Part 2 calendar of this plan |
| B7 `generate()` / `_reversePourOk` | Emits unsolvable boards from level 25 (measured 25–61%) | Work order 4.1B fix |
| §3.8 haptics setup | Claims zero haptics exist; tells you to build `Haptics` + toggle | All of it already exists — `SettingsManager.hapticTap/Success/Error` |
| §1.15 "your app currently uses ZERO haptics" | Stale claim | Ignore; 22 game files already call the helpers |
| §3.6 persistence (`'sandsort_level'` raw key) | Predates mode-aware keys | `PrefsKeys.gameLevel('<id>')` so Zen works |
| §3.1 "set `isStashed: true` to soft-launch hidden" | Stashed games are unreachable (no beta hub anymore) — there is no soft-launch path | Keep stashed during development; flipping the flag IS the launch (checklist 3.1 step 6) |

Everything else in the handbook — the two-tier pattern, the logic/screen split, the
integration templates, the per-game code — was spot-checked in the 2026-08-22 audit
(reflection tables, canonical forms, crossing tests) and holds up. Trust it.

---

# PART 2 — THE CALENDAR

Assumes roughly monthly releases. If cadence slips, everything slides **except the two
date-locked items**: S3 seasonal framework (2.1) and the winter event (2.2) — a winter
event after winter is worthless.

| Version | Approx. | Games after | Content | Systems |
|---|---|---|---|---|
| 1.8(50) | shipped Aug 2026 | 16 | — | — |
| **1.9** | Sep 2026 | 18 | Kakuro (revival) + Sand Sort (new) | Accessibility quick wins |
| **2.0** | Oct 2026 | 20 | Hitori (revival) + Light Beam (new) | **Analytics** + S1 streak depth |
| **2.1** | Nov 2026 | 22 | Slitherlink (revival) + Zen Slide (new) | **S3 seasonal framework** + modifier batch 1 |
| **2.2** | Dec 2026 | 23 | Untangle (new) ✅ | **Winter event** ✅ + modifier batch 2 ✅ |
| **2.3** | Jan 2027 | 24 | Cipher Decoder (revival) ✅ | S2 daily depth ✅ + dead-code cull ✅ + ~~discovery/curation~~ ⏸️ blocked on analytics |
| **2.4** | Feb 2027 | 26 | **Orbit + One Stroke** (two new) | Data-review checkpoint |
| **2.5** | Mar 2027 | 26 | *(none — deliberate pause)* | **Speed & Endless modes** + performance pass + IAP hardening |
| **2.6** | Apr 2027 | 28 | **Skyscrapers + Nurikabe** (two prototype→full) | Modifier batch 3 |

**Why the two pauses exist (owner-agreed, do not cut them):** QA surface is the binding
constraint. This codebase shipped 16 unwinnable Sudoku levels that were live for
months. A solo pipeline that ships games every single release repeats that.

**Load warnings:**
- **2.6 is the heaviest release** — two ~70%-of-a-new-game builds + a modifier batch,
  and Nurikabe has the hardest generator on the roadmap. **Slip rule: Nurikabe slips
  first** (Skyscrapers' level data is already verified; Nurikabe has no dependency).
  Escape hatch: substitute **Light Up** (see 2.6 work order).
- **2.4 doubles game QA.** Mitigated by sequencing: One Stroke reuses Untangle's (2.2)
  painter/trace patterns; Orbit is small.

---

# PART 3 — STANDING CHECKLISTS (apply to every release)

## 3.1 Revival checklist (full parity — owner decision 2026-08-22)

A "revival" = un-stashing one of the four broken-but-built games. Steps **in order**:

1. **Fix the defect**, with a test that would have caught it.
2. **Standardize the header**: replace the raw `AppBar` title with `GameTitle` +
   `GameLevelChip` as the last action (copy any live game, e.g.
   `lib/screens/games/masyu/masyu_screen.dart`).
3. **Centralize the win path**: on win call `HintManager.onLevelCleared('<id>')` and
   `PointManager.addPoints(n)`; save level via `ProgressGuard`/mode-aware
   `PrefsKeys.gameLevel`. **Delete any hand-written `globalLevelClearedCount`
   increment** — the four stashed games are the only files still doing this, and it
   double-counts/mis-counts trail progress and breaks Zen separation.
4. **Widen the modifier pool** beyond `['timer']` to be comparable with live games;
   verify each pool entry actually changes the level and is visible to the player.
5. **Uncomment the route in `lib/main.dart`.** ⚠️ **Found the hard way 2026-08-22:**
   three of the four revival games ship with their route commented out — Kakuro
   (~line 232), Cipher Decoder (~233), Hitori (~234); only Slitherlink is live. The
   import at the top of `main.dart` is already present and active, so the file
   compiles either way and nothing warns you. Un-stashing without this produces an
   `_onUnknownRoute` throw the moment a player taps the game's card — a white
   "Unhandled Promise Rejection" screen on web, a crash on device. Verify by grep:
   the line must not start with `//`.
6. **Add to both test harnesses** (`all_games_all_levels_test.dart`,
   `difficulty_curve_test.dart`) + a generator solvability/uniqueness test.
7. **Flip `isStashed: false` in `lib/models/game_info.dart` LAST**, after 1–6 pass.

Side effect to expect: un-stashing raises the `completionist` denominator. Relative by
design — do not "fix" it.

## 3.2 New-game checklist

Follow handbook Part 2/3 (logic file + screen file split, registration steps), with
these **corrections to the handbook**:
- Persistence: `PrefsKeys.gameLevel('<id>')` (mode-aware), not a raw string key.
- Haptics: `SettingsManager` helpers exist — skip handbook §3.8.
- **Generator rule (absolute): every generator is gated by a REAL solver test — never
  `expect(isWon, false)`.** Both historical disasters (16 unwinnable Sudoku levels;
  the handbook's own Sand Sort generator) pass the weak "not already solved" check
  and fail an actual solver. Write the solver first, generate against it.
- Seeded RNG only: `RotationEngine.getDeterminism('<id>', level)`.
- Register: `kAllGames` (stashed until done), route + import in `main.dart`,
  `AppTheme.accentFor` case, rules text in `lib/utils/rules_helper.dart`, tutorial
  dialog on first open, `RecentlyPlayedManager` on open.
- Add to both test harnesses; hand-authored level lists get solvability + uniqueness
  tests.

## 3.3 Ship checklist (every version)

- [ ] `flutter analyze` — zero errors
- [ ] `flutter test` — all green
- [ ] Chrome smoke pass: boot every touched game at several levels incl. ≥30 (modifier
      territory); check header standard, modifiers visible, no overflows
- [ ] Difficulty never decreases with level (harness enforces)
- [ ] **Ask the owner before building the bundle**
- [ ] `flutter build appbundle` (ignore the strip-symbols warning — Part 0)
- [ ] Copy to `versions/<version>/cogniq-<x.y.z+NN>.aab` + write `NOTES.md` (Part 6)
- [ ] Bump `pubspec.yaml` build number AFTER copying

---

# PART 4 — RELEASE WORK ORDERS

## 4.1 — Version 1.9 (Sep 2026): Kakuro + Sand Sort + accessibility

### A. Revive Kakuro — full diagnosis (verified in source AND by simulation)

**File:** `lib/screens/games/kakuro/kakuro_screen.dart` (~1,003 lines).
**Headline: levels 5+ have NEVER worked and mathematically cannot.**

Layouts are three hardcoded `_types` arrays (0 = wall, 1 = white/fillable, 2 = clue
cell): `_kLayout4x4` (~line 101), `_kLayout6x6` (~108), `_kLayout8x8` (~117). Level →
layout mapping in `_generatePuzzle()` (~128): `<5` → 4×4, `<12` → 6×6, else 8×8.

**The bug chain:**
1. `_computeClues()` (search `void _computeClues`) writes a clue **only outward from a
   type-2 cell** (right for H, down for V).
2. But several runs begin directly after a type-0 **wall**, so they get clue `0`:
   - 6×6: H run at cells **[16,17]**; V run at cell **[26]** → 2 unclued runs
   - 8×8: H run at **[34,35,36,37]**; V runs at **[41,49]** and **[47,55]** → 3
   - 4×4: none (which is why levels 0–4 work)
3. `_isSegmentSumsValid()` walks left/up to find the clue, lands on the wall, reads
   `0`, and applies `if (rowSum >= hClue) return false;` — with digits 1–9,
   `rowSum >= 0` is **always true**, so the first digit placed in an unclued run is
   always rejected.
4. `_countSolutions` therefore returns 0; `numSolutions == 1` never holds; all 50
   retries exhaust (simulated: 0/50 on 6×6); the fallback fires.
5. The fallback (search `Fallback fallback if generation is stuck`) contains
   **`_currentLevel = 0;`** (~line 186) — it **silently destroys the player's saved
   progress** and serves the same hardcoded 4×4 forever. One bug, two symptoms.

**Additional defects found in the same file:**
- `final rand = Random();` (~line 164) — unseeded; violates the seeded-RNG law.
- Only one layout per size band → every level 12+ is the identical shape.
- Pool is `pool: ['timer']` (~137) — far below live-game parity.
- Manual `globalLevelClearedCount` write (~476–477) instead of
  `HintManager.onLevelCleared` — breaks Zen/trail accounting (see 3.1 step 3).
- Raw `AppBar(` (~554) instead of `GameTitle`/`GameLevelChip`.

**Fix order:** (1) clue geometry — derive each run's clue cell positionally, or
promote the wall preceding every run to a clue cell in the layout data; (2) delete
`_currentLevel = 0` — generator failure must NEVER touch saved progress (fall back to
a valid board at the same level instead); (3) seeded RNG via
`RotationEngine.getDeterminism('kakuro', level)` — note the gameId the file actually
uses is `'kakuro'`; (4) add ≥3 layouts per size band, all machine-verified fully-clued;
(5) parity steps 2–4 of checklist 3.1; (6) tests: every layout has all runs clued;
generation succeeds and `_countSolutions == 1` for levels 0–80.
Show the owner a working 6×6 after steps 1–3, before layouts/parity.

### B. New game: Sand Sort (`sandsort`, handbook Part 5 §B7)

Follow the handbook's B7 build (logic/screen split, tube UI, pool
`['quota','ratchet','monochrome','momentum']`) **except its generator**:

> ⚠️ **The handbook's `generate()` is labelled "ALWAYS-solvable" and is not.** Its
> `_reversePourOk` returns `true` without checking the matching forward pour would be
> legal, so the reverse walk reaches unsolvable states. Simulated 300 boards/level:
> 0% unsolvable through level 24, then **25% at level 25, 34% at 40, 55% at 60, 61%
> at 80**. The cliff is exactly `empties = level < 25 ? 2 : 1`.
> **Fix:** keep **two empty tubes at every level** (measured: drops failures to 0–1
> per 300) AND gate every generated board behind a real DFS solver (state-dedup on
> sorted tube tuples; skip pointless pure-tube→empty moves). Reject-and-reroll with a
> salted seed on the rare failure. Solver lives in the logic file and is unit-tested.

Registration per checklist 3.2. Suggested accent: `terracotta` (handbook).

### C. Accessibility quick wins — DONE 2026-08-22

> ⚠️ **Correction.** Earlier drafts of this plan (and the deleted
> `ACCESSIBILITY_RECOMMENDATIONS.md` it came from) claimed the codebase had **zero**
> `Semantics` widgets. That was false. Five exist and already cover grid cells in
> Sudoku, Mine Finder, Star Battle, Hitori and Cipher Decoder, with labels like
> `'Cell Row 3, Column 5, value empty'`. Verify claims like this before scheduling
> work from them.

- **Tooltips: done.** 82 `IconButton`s had no `tooltip:`; all 82 now do, across 39
  files. A tooltip doubles as the screen-reader label, so this was the cheapest real
  accessibility win available.
- **Contrast: audited, three tokens fixed.** `textMutedLight` `#827B75`→`#706963`
  (was 3.53-4.17:1, now 4.58-5.40:1), `textSecondaryDark` `#8A847C`→`#908A82`,
  `textMutedDark` `#6E6760`→`#746D66` (clears the 3:1 UI floor; full 4.5:1 would
  collapse it past `textSecondaryDark` and destroy the three-tier hierarchy). All
  three are pure-lightness nudges — the warm-gray hue offsets are unchanged.
- **Semantics: already present, nothing added** (see correction above).

**Known-unfixed, deliberately — the accent palette fails contrast as text.** All seven
accents are used as real text (22 sites, some at 13px/w600). On light backgrounds
`warmAmber` is 2.34:1 — failing even the 3:1 UI floor — and roseGold, softSage,
dustyMauve, terracotta and slateBlue all fail 4.5:1. Fixing the fill colours would be
a visible repaint of the brand palette, so it was not done. **Recommended for a later
release: add a separate darker "accent-on-light-text" variant per accent rather than
moving the fill colours**, so buttons and boards keep the zen look while text passes.

---

## 4.2 — Version 2.0 (Oct 2026): Hitori + Light Beam + Analytics + S1

### A. Revive Hitori

**File:** `lib/screens/games/hitori/hitori_screen.dart` (~674 lines).
**Defects (from the 1.8 audit — re-verify in source before fixing):**
1. The uniqueness check ignores the solution it was passed → hints can shade wrong
   cells.
2. The solution enumerator is unpruned → **UI freeze at 8×8** (exponential search on
   the UI thread).

**Fix:** honour the passed solution in the uniqueness check; add constraint
propagation / bounding to the enumerator; run generation off the UI thread
(`compute()` or pre-generate). Then parity checklist 3.1 (this file also hand-writes
`globalLevelClearedCount` — remove it).

### B. New game: Light Beam (`lightbeam`, handbook §B6)

Tap-to-place mirrors; beam re-routes live; light all crystals. The handbook's
generator is forward-construction (walk the beam, place solution mirrors, drop
crystals on the path, clear mirrors) — sound approach, but still verify per rule 3.2:
replaying `solutionMirrors` must light all crystals, and the board must NOT be
solvable with zero mirrors. Tier 1 needs no painter (glow the path cells).

### C. Analytics layer (the release's real work)

First network-touching feature. Minimum event set: game opened; level
started/completed/abandoned per game; hint used; purchase events; session length; Zen
vs Challenge mode. Requirements: a privacy policy (Play Console data-safety form
update), user consent/opt-out in Settings, and graceful offline queuing. Choice of
backend (Firebase Analytics is the low-friction default) is the **owner's call — ask
with options before implementing.**

### D. S1 — streak depth (owner-approved exception to `remember.md` C3)

- Multi-game streaks: "played anything today" sustains a streak, not just dailies.
- Milestone badges at 7/30/100 days through the existing **manual-claim** flow.
- **Streak recovery: one free skip per month** — highest-value item; removes the
  "streak broken, why bother" quit cliff.
- Reminder notification within the remaining day window (notification plumbing
  already exists — `flutter_local_notifications`).

---

## 4.3 — Version 2.1 (Nov 2026): Slitherlink + Zen Slide + S3 + modifiers 1

### A. Revive Slitherlink

**File:** `lib/screens/games/slitherlink/slitherlink_screen.dart` (~797 lines).
**Defect:** the stuck-growth fallback force-adds a hole, producing a **two-loop board
that cannot be solved** (a Slitherlink solution must be ONE closed loop).

> **⚠️ CORRECTED 2026-08-22 — the diagnosis above was wrong.** The force-add line exists
> (`if (!added) cells.add(candidates.first);`, no re-check) but **never fired across 9,000
> simulated boards**: target region sizes are small relative to the grid, so a legal
> candidate is always available.
>
> The real defect is a **diagonal pinch**. The old `_isSimplyConnected` checked that the
> region *and* its complement are each edge-connected — necessary but not sufficient. Two
> cells touching only at a **corner** pass that check while making the boundary cross
> itself at that corner, producing a **degree-4 vertex**. The screen's win check rejects
> any vertex of degree other than 0 or 2, so the board stored a solution that failed the
> game's own validator. Measured over 3,000 boards per size: **0% at 3x3, 0.7% at 4x4,
> 2.4% at 5x5** — about one level in forty from level 13 up.
>
> **Fixed** in `lib/screens/games/slitherlink/slitherlink_logic.dart` by gating generation
> on `isSingleLoop` (the win check itself), not on the shape heuristics alone. 22 tests.
**Fix:** replace hole-punching with reject-and-retry on a salted seed; add a
single-loop validator (walk the solution edges; assert exactly one cycle covering all
of them) and gate generation on it. Then parity checklist 3.1.

### B. New game: Zen Slide (`zenslide`, handbook §B5)

Ice-slide puzzle; BFS solver included in the handbook logic and doubles as the
generation gate (`solve()` distance ≥ target) — this one's generator pattern is sound.
Swipe detection via `onPanEnd` velocity; `AnimatedPositioned` stone.

### C. S3 — seasonal event framework (DATE-LOCKED: must ship this version)

Framework, not content: event definition (id, date window, featured games/modifiers,
badge reward), a scheduler reading the device clock, an event banner on the home
screen, event-specific badges through the manual-claim flow. Fully offline —
definitions ship in the app binary. **No leaderboards** (needs a backend — cut).

### D. Modifier batch 1: `silence`, `quota`, `ratchet`, `wildcard`

Handbook Part 4 §A6/A3/A8/A7 — the four no-timer no-painter modifiers. Wire into the
games each section lists. Pool-safety rules: `ratchet` and `silence` never in the same
pool (contradictory); `wildcard` uses a salted seed (`'<id>_wild'`); respect
`modifier_pool_expansion.md`'s "Deliberately excluded" list (e.g. do NOT add fog to
Mine Finder pools beyond what's already there without owner sign-off).

---

### 2.x — Monthly drip-feed rebuilds (owner decision, 2026-08-23)

**The situation that forced this.** Play Console has only ever received `1.8.0+50`. Every
bundle since — `+51` through `+54` — was built but never uploaded, so users are still on 1.8
with the daily-challenge crash live. The owner wants to release **monthly**, adding a couple
of games each time, rather than shipping 2.2's full 23-game roster in one jump.

**What was rejected, and why.** The obvious reading — "rebuild the old versions from the old
source zips" — was refused. Each zip is up to six releases of drift from current; a diff
showed nearly every file differs, and current game screens depend on current shared code. It
would mean backporting ~30 fixes by hand into four separate trees, four chances to introduce
new bugs, against old code the current test suite no longer matches. Old snapshots may not
even build: `pubspec.lock` already lists 42 packages with newer incompatible versions.

**What ships instead.** Each monthly build is **the current, fully-fixed tree with future
games switched off** via `isStashed: true` — the app's own existing mechanism, the same one
that hides the beta prototypes. The roster is the only thing that varies; every build carries
every fix.

| Build | Version | Live | Adds |
|---|---|---|---|
| 1 | `1.8.1+55` | 16 | the original roster |
| 2 | `1.9.1+56` | 18 | Kakuro, Sand Sort |
| 3 | `2.0.1+57` | 20 | Light Beam, Hitori |
| 4 | `2.1.1+58` | 22 | Zen Slide, Slitherlink |
| 5 | `2.2.1+59` | 23 | Untangle, winter event ready |

Version *names* had to change (`1.8.1`, not `1.8.0`) because Play requires each upload to
carry a higher `versionCode` than the last; gaps are legal, reuse is not.

**Two things must track the roster** or the suite fails — both are data, not test changes:

1. **Seasonal `featuredGameIds`** — every featured id must be live in that build. A stashed id
   routes the player at an unregistered route and crashes, the bug that was live in 1.8.
2. **The pinned winter test**, which asserts winter's exact list, updated to match the trim.
   This is the only test edited per folder, and it is a data pin, not a weakened assertion.

Working folders: `Documents\Cogniq Versions\_work\<version>\cogniq`. **Original zips are
kept**; new ones are added alongside. Full procedure in `TRANSFER.md`.

---

## 2.1 — outcome (2026-08-22)

All four workstreams landed. What is worth carrying forward is where the *plan* was wrong,
not where it was right.

| Item | Outcome |
|---|---|
| **A. Slitherlink** | ✅ Recorded defect **refuted**; real cause was a diagonal pinch. `slitherlink_logic.dart` + 22 tests. Header standard applied, ~148 lines of dead helpers deleted. |
| **B. Zen Slide** | ✅ Shipped. **Six defects found in the handbook §B5 sketch** before a line was written. 64 tests. |
| **C. S3 seasonal** | ✅ Shipped, 48 tests. `SEASONAL_ROTATION_SPEC.md` was read and **rejected** — see below. |
| **D. Modifier batch 1** | ✅ **6 of 8** mappings shipped. Two were declined with reasons — see below. |

**Three planned items were correctly refused.** Each refusal is more valuable than the work
would have been:

1. **`quota` → Color Flood.** Color Flood already *is* a quota game: `_movesLeft` is a greedy
   solver's move count plus a `buffer` that is **0 at every level ≥60 and across 10-34**.
   The handbook's own `quota` formula gives `optimum × 1.64` at L30 — *looser* than what
   ships. Adding it would have been a difficulty **reduction** wearing a hard modifier's name.
2. **`wildcard` → Sum Strike.** Already ships as `whisper`: same render-only `?` masking,
   same salted-seed pattern, at a *higher* rate (60% vs 30%). Two names for one mechanic in
   one pool, and the pairs tier could have drawn both and double-masked the same targets.
3. **`SEASONAL_ROTATION_SPEC.md` as the S3 spec.** It is a rewrite of the daily system
   (off-limits per `remember.md` §A), it plans games deleted by owner decision on
   2026-08-22, and it computes days with `difference().inDays` — the exact 23/25-hour DST
   bug S1 already fixed. Nothing from it shipped. **The file is stale; treat as background
   reading only.**

**Seasonal calendar — decided 2026-08-22 (owner).** Windows are **annually recurring**
(`MonthDay` → `MonthDay`), not absolute dates: with no backend, an absolute-date event
fires once and never again on a device that stops updating. One-off events remain
expressible via `firstYear`/`lastYear`.

The owner chose a **quarterly rhythm** — four events a year, anchored to the 18th, each
running just over two weeks with ~10 weeks of quiet between them:

| Event | Window | Badge | Featured |
|---|---|---|---|
| ❄️ Winter Lights | 18 Dec – 5 Jan | `event_winter_lights` | lightbeam, sandsort, hitori, masyu, zip |
| 🌱 Spring Thaw | 18 Mar – 1 Apr | `event_spring_thaw` | zenslide, colour_link, bridges, hue, slitherlink |
| ☀️ Long Light | 18 Jun – 2 Jul | `event_summer_light` | lightbeam, circuit_guide, color_flood, oddcolor, zip |
| 🍂 Gathering In | 18 Sep – 2 Oct | `event_autumn_harvest` | kakuro, sumstrike, killersudoku, sandsort, sudoku |

Winter deliberately spans the year boundary so the rollover path is exercised by real
shipped content, not only by tests. Every featured id is live and route-checked by a test —
a stashed id would route the player at an unregistered route and crash the app, which is the
bug `DailyChallengeManager._isLiveGame` exists to prevent.

**Still content-thin by design.** `featuredModifierTypes` are *named, not applied*; per
`remember.md` §8 the banner therefore advertises featured games only, never the modifiers.
Wiring modifiers into event play is 2.2 work.

**Two long-standing defects surfaced and were recorded against earlier releases** rather
than fixed here — see `versions/2.0/NOTES.md` and `md/TESTING_CHECKLIST.md`: Color Flood's
zero-slack band at levels 10-34, and Circuit Guide's `timer` modifier having no loss
condition. Both predate 1.8.

**Regression caught by the harness, not by a person:** four new-modifier chips overflowed
their rows at exactly the levels where modifiers fire (Grid Path 260px, Star Battle 16-25px,
Mine Finder 50px, Slitherlink an uncancelled `Timer`). Every one passed its own unit tests.

---

## 4.4 — Version 2.2 (Dec 2026): Untangle + winter event + mods 2

> **Cipher Decoder moved to 2.3** (owner decision 2026-08-22). 2.2 already carries
> Untangle — the project's first `CustomPainter` on-ramp — plus the first real use of
> the seasonal framework and a three-modifier batch. Cipher Decoder is also the only
> revival needing a design decision before code can start, and that decision has now
> been made, so it fits 2.3 cleanly. See work order 4.5D.

### A. New game: Untangle (`untangle`, handbook §B1)

Drag nodes until no edges cross. Planar-by-construction generation (grid + neighbor
edges, then scramble) is guaranteed solvable. Needs a ~20-line `CustomPainter` even at
Tier 1 (the project's painter on-ramp). Its patterns are prerequisites for One Stroke
in 2.4 — build it clean.

### B. Winter event — first real use of the S3 framework, shipped in season.

### C. Modifier batch 2: `momentum`, `decay`, `heartbeat`

Handbook §A9/A2/A4 (timer/animation tier). `momentum` introduces the shared
`MomentumMeter` widget; on win use `addPoints((10 * avgMultiplier).round())`.

---

### 2.2 — progress (2026-08-22)

| Item | State |
|---|---|
| **A. Untangle** | ✅ Shipped. Handbook §B1 measured over 4,000 boards first — **four defects found**, see below. 35 logic tests. Browser-verified. |
| **B. Winter event** | ✅ Shipped. Night trail + event sheet, 185 tests. **Refused to wire `featuredModifierTypes`** — reasons below. |
| **C. Modifier batch 2** | ✅ Shipped. **9 of 16** handbook placements; **7 refused**. 41 tests. Found 3 more shipped overflows. |

**Untangle — what the handbook got wrong.** Its planar-by-construction idea is sound and was
kept verbatim: 0 of 4,000 solved layouts had a crossing, so every board is genuinely
winnable. Everything else was replaced:

| Property | Handbook, measured | After |
|---|---|---|
| dealt board already solved | **54% at level 1**, 48% at level 5 | 0 |
| two nodes overlap on the scramble circle | 87% at level 16, **99% at level 24+** | 0 |
| a node has no edges at all | 6–10% at every level | 0 |
| difficulty keeps climbing | flat from level 24 | edge density ramps to level 75 |

The overlap defect was the serious one. Nodes were scrambled with an independent random
angle each, and random angles clump — by the birthday problem, 25 nodes on one circle almost
always places two on top of each other, and two overlapping nodes cannot be told apart or
dragged separately. Slots are now evenly spaced and *which node gets which slot* is
shuffled; the tangle stays random, the separation is guaranteed.

**A correction worth keeping.** The first version of this file claimed the minimum-crossings
gate carried difficulty past the size plateau. Measurement says otherwise — level 16 asks
for 7 crossings and a circle scramble delivers ~322, so the gate is a **floor that almost
never binds**. `diagonalChanceFor` is the real lever. Do not cite the crossing floor as a
difficulty knob.

**Winter event — a refusal and a shipped defect found.**

`featuredModifierTypes` were **not** wired into play, deliberately. Two reasons, both
structural: `ice` does not exist as a rotation modifier at all — it lives only in
`daily_challenge_manager.dart`, which `remember.md` §A puts off limits — and making modifier
selection depend on the calendar would mean level 34 of a game renders differently in
December than in June, which breaks the determinism `difficulty_curve_test` asserts. A
seasonal modifier override is a **difficulty** change wearing a **content** change's
clothes. Same reasoning that refused `quota`→Color Flood in 2.1.

**And a §8 violation that shipped in 2.1.0+53 was found here:**
`SeasonalEventManager.recordProgress()` was hooked to `ActivityTracker.trackGamePlay`, which
fires on game **launch**. The badge reads *"Clear 5 levels during the event"* — so opening a
game five times and quitting earned it. Moved to `HintManager.onLevelCleared` after the Zen
guard. Recorded in `versions/2.1/NOTES.md` §6.

---

### 2.2 — modifier batch 2 detail

**Shipped:** `momentum` → Word Hive, Sum Strike · `decay` → Kakuro, Slitherlink ·
`heartbeat` → Sand Sort, Spectrum. Three shared widgets:
`momentum_meter.dart`, `decaying_clue.dart`, `pulse_vision.dart`.

**`momentum` composition — read this before touching points again.** The handbook said
"replace `addPoints(10)`", and **there is no `addPoints(10)` in any game screen**.
`HintManager.onLevelCleared` holds the base 10 for all 23 games and a screen cannot remove
it. Following the handbook would pay `10 + 10 × avg`. What shipped pays only the **excess
over base** — `(10 × avg).round() - 10`, clamped 0..40 — so an unchained clear (×1) pays
**0** and is worth exactly what it was before. The `+5` speed bonus stays separate and is
**not** multiplied. This is the third time points were nearly double-paid in this project;
the rule is in `remember.md` §11.

**Seven of sixteen placements were refused**, all for the same family of reasons:

| Refused | Why |
|---|---|
| momentum → Odd Colour Out | one scored action per level, so the average is a constant — flat inflation, no skill signal |
| momentum → Spectrum, Colour Flood | no per-move correct/incorrect exists at all |
| momentum → Sand Sort | a legal pour can be a setup move or a blunder; only the BFS solver knows. Scoring "legal pour" pays for pouring back and forth |
| heartbeat → Chimp Test | duplicates `numbersHide`, already pooled — playing blind from memory *is* Chimp Test |
| heartbeat → Odd Colour Out | duplicates `eclipse`, already pooled |
| heartbeat → Mine Finder, Pearl Loop | untimed and deliberate, so waiting out the blank phase is free — tedium, not difficulty |
| decay → Sudoku, Killer Sudoku, Mine Finder, Sum Strike, Bridges | each already carries a contradicting partner (`clueThinning`, `wildcard`, `hiddenCount`, `whisper`, `hiddenIslands`) |

**Pairs that must never co-occur** (enforced by pool composition and by tests):
`heartbeat`×`eclipse` (same mechanic), `heartbeat`× any spatial occlusion
(`fog`/`hiddenCount`/`whisper`/`minimal`/`wildcard` — the board would never be fully readable
at any instant), `decay`×`clueThinning`, `decay`×`wildcard` (tapping a decayed `?` reveals a
`?`), `decay`×`eclipse`.

**Side benefit:** three pools that were only 3 entries — Kakuro, Slitherlink, Sand Sort — are
now 4, which is what the pairs tier needs to avoid serving one pair for 35 straight levels.
`colorflood` is still thin at 3 and remains a known gap.

---

## 4.5 — Version 2.3 (Jan 2027): Cipher Decoder + curate, deepen, delete

**No new *build*. Deliberate.** At 24 games the problem inverts from "not enough
content" to "the good games are buried." Cipher Decoder is a revival, not a new build,
and it was moved here from 2.2 (owner decision 2026-08-22).

### A. Discovery & curation — ⏸️ **NOT DONE in 2.3, deferred.** Driven by ~3 months of analytics
Surfacing/ordering/grouping of the home grid decided from real open-rates. Present
findings + options to the owner before changing the home screen (Section A of
`remember.md` protects parts of `home_screen.dart` — get explicit approval).

### B. S2 — daily challenge depth (owner-approved exception to `remember.md` §A)
- 60-day rotation variants (current cycle: 30 days).
- Bonus stars for a hint-free daily (data already tracked).
- NO per-day leaderboards (backend — cut).

### C. Dead-code cull (~25,000 lines shipping in every bundle today)
The ten never-scheduled stashed games — six word games (`word_guess` 15,701 lines
incl. inlined dictionary, `word_ladder`, `word_climb`, `word_builder`, `hangman`,
`flag_finder`) and four memory/reaction games (`mahjong`, `number_memory`,
`sequence_memory`, `reaction`) — rejected twice by the owner (`remember.md` D2).
Work: delete folders under `lib/screens/games/`, their routes/imports in `main.dart`,
their `kAllGames` entries; **`/practice` is KEPT — owner decision 2026-08-23.** It is not dead code: it is the
owner's own practice scaffold and the worked example `md/GAME_WIRING_CHECKLIST.md` is
written around (its lines 15-16 and 293 name the file and route directly). 158 lines,
absent from `kAllGames` so it never appears in the game list. Do not re-flag it.
**Confirm the final delete list with the owner first.** Verify: analyze, full tests,
bundle-size drop recorded in NOTES.md.

### D. Revive Cipher Decoder — REDESIGN, decided 2026-08-22

**File:** `lib/screens/games/cipher_decoder/cipher_decoder_screen.dart` (~647 lines).
Moved here from 2.2. Sized at **~2 focused days**.

**The defect is worse and earlier than previously recorded.** Exhaustively enumerated
every shift the RNG can produce (25 outcomes for the uniform and progressive bands,
600 for vowel/consonant):

| Band | Levels shown | Unsolvable |
|---|---|---|
| Uniform shift | 1–5 | **0%** |
| Vowel/consonant | **6–12** | **73.7%** |
| Progressive per-word | **13+** | **100%** |

The plan previously blamed only the progressive band and put the cliff at level 12.
**The real cliff is Level 6.** Any fix that only addresses progressive shifts leaves
the game broken from Level 6. Root cause in all cases: the cipher→plaintext relation
is not a function — one cipher letter needs two different answers — while the UI keeps
a single global `Map<String,String>`.

Also: **hints are consumed on impossible puzzles.** `_showHint` spends a hint (and
`BuyHintsDialog` sells them) and writes a mapping that breaks another position. A
player on Level 13+ can spend a purchased balance on a puzzle that cannot be cleared.

#### The redesign: a per-word shift dial ("suitcase lock")

**Owner decision, 2026-08-22.** Replace the letter keyboard and the global
`Map<String,String>` with **one dial per word** — like the wheels on a combination
suitcase lock. Each word gets a 0–25 dial; turning it re-renders that word's letters
live; the player turns each until the phrase reads as English.

Why this over per-word *letter mapping* (the earlier idea in `remember.md` D4): both
are 100% solvable (verified, 0/2200 failures), but per-word letter mapping forces the
player to re-solve every word by vocabulary, multiplies UI state by word count, and
leaves ≤2-letter words guessy — 22% of the corpus is ≤2 letters and a one-letter word
is a pure coin flip. The dial keeps the **arithmetic** structure: because shifts are
progressive (`base + wordIndex`), cracking one word gives you every other word. One
unknown, deduced — a logic puzzle, which is what `remember.md` D1/D4 asks for and what
keeps this out of the word-game territory D2 rejects.

It also **removes** code: the virtual keyboard, `_mappings`, and the `CLR` path all go.

**Difficulty ladder = number of independent unknowns:**
1. one global shift (all words share it)
2. a *stated* progressive rule (`+1`, `+2`, `+k` per word) — still one unknown
3. an *unstated* progressive rule the player must infer
4. free per-word shifts — N unknowns

**Mandatory details:**
- **Exclude shift 0.** `(base + w) % 26 == 0` renders that word in plaintext; measured
  4–7 of 25 base shifts leak at least one word.
- **Corpus: 14 phrases → 100+.** Levels currently cycle with period 14 from level 10,
  and 12 of 21 short-phrase entries are unreachable dead data.
- **Cap the ladder around 40–50 levels of real progression.** Once the structure is
  understood the rest is "scan until it reads as English" — the perception-ceiling risk
  `remember.md` D2 warns about. Decide the hardest fair level up front.
- Hint becomes "reveal one word's dial"; reset becomes "zero all dials".

#### Then full parity (checklist 3.1)
Seeded RNG (bare `Random()` at ~L116, no `RotationEngine` import at all); `ProgressGuard`
+ `HintManager.onLevelCleared` + `PointManager` replacing the hand-written
`beta_level_cipherdecoder` and manual `globalLevelClearedCount`; `GameTitle` +
`GameLevelChip`; a `cipherdecoder` case in `AppTheme.accentFor` (none exists — it
silently returns grey); a modifier pool from zero (there is none, and its only
`fog` hook is dead because the daily plan never schedules this game); uncomment the
route at `main.dart:233`; both test harnesses.

### E. First formal data review → written priorities for 2.4+.

---

### 2.3 — outcome (2026-08-23)

| Item | Result |
|---|---|
| **C. Dead-code cull** | ✅ **25,248 lines** removed. 10 games deleted; analyzer warnings 58 → 46. |
| **D. Cipher Decoder** | ✅ Revived with the suitcase-lock dial redesign. Corpus 14 → **107** phrases. |
| **B. Daily depth (S2)** | ✅ Rotation **98 → 210 days**. Found 16 authored theme weeks shipping dead. |
| **A. Discovery/curation** | ⏸️ Parked — needs an analytics backend, still undecided since 2.0. |
| *Follow-up cleanup* | ✅ `wordleGreen` → `positiveGreen`, 5 dead aliases, 1 dead screen. |

**The recorded Cipher Decoder diagnosis was correct — the first time in four releases.**
Measured exactly: 0% unsolvable at levels 1-5, **73.7%** at 6-12, **100%** at 13+. Two
amendments: the shift-0 plaintext leak is **4-10** of 25 base shifts (recorded 4-7), and 12
of 21 short-phrase entries were confirmed unreachable.

**The daily-challenge find is the largest of the release.** `kThemeCount` was hardcoded to
**14** while `_kDailyChallengesPlan` held **30** authored theme weeks — so weeks 15-30
(Gravity, Illusion, Ice, Ghost, Swap, Magnet, Encryption, Mutation, Echo, Blind, Aurora,
Matrix, Grand Finale …) were mathematically unreachable and shipped dead in every bundle.
`kThemeCount` is now **derived from the table**, so the two can never drift again. Existing
players are provably undisturbed: the resolver's output for all 98 previously-reachable days
is byte-identical under the old and new constants.

**A false claim in this plan was caught.** §4.5 B said the hint-free-daily data was "already
tracked". It was not — `_hintUsedThisLevel` is private, in-memory, never persisted, and every
daily game skips `onLevelCleared` (it would double-pay), so nothing ever read it. The
obvious workaround — diffing the hint balance — was correctly **refused**, because
`BuyHintsDialog` and rewarded ads add hints mid-level, so a player who buys 3 and spends 1
shows a net increase and would be paid the hint-free bonus precisely when they *did* use a
hint. Implemented properly instead via a pure-read accessor on `HintManager`: **+10 on top of
25/50**, points not stars (a day holds exactly one star by invariant, and the 3x
star-inflation fix depends on that).

**`/practice` is KEPT** — owner decision. It is not dead code; see `remember.md` §9j.

**Cipher Decoder's ladder is being compressed** so it plateaus by level 30 rather than 45 —
see `remember.md` §9k for why tuning `modifierStartLevel` was the wrong fix.

---

### Carried forward out of 2.3 — read before planning 2.4

**Discovery & curation (2.3 work order A) was not done, and cannot be until analytics runs.**
It needs ~3 months of real open-rate data. No backend has been chosen — that decision has
been open since 2.0 and analytics still collects nothing, so the clock has not started.

**2.4's own data-review checkpoint (work order C below) has the same dependency.** Two
consecutive releases now carry an item that is blocked on one unmade decision. This is the
only thing on the roadmap that cannot be recovered by working harder later: the data can
only accumulate in wall-clock time.

**Recommendation:** choose a backend before 2.4 starts, or explicitly re-scope both items and
stop carrying them. Carrying a blocked item across three releases makes the plan dishonest.

---

## 4.6 — Version 2.4 (Feb 2027): Orbit + One Stroke (two new games)

### A. Orbit (`orbit`, handbook §B3)
Concentric rings of beads; drag to rotate with snap + haptic detents; win when spokes
are single-color. Generation is retrograde (scramble offsets from solved) — inherently
solvable, but keep the salted re-roll for accidental-solved states. ⚠️ The handbook
itself calls its Tier 1 "the jankiest in the doc" — **plan the Tier 2 painter upgrade
(§2.4 recipe) within this same release**, don't ship the janky tier.

### B. One Stroke (`onestroke`, handbook §B2)
Euler-path tracing. The parity-fixing step in generation (pair up odd-degree vertices
until 0 or 2 remain, verify connectivity) **guarantees** traceability — implement it
exactly, and test: random graphs always end with 0 or 2 odd vertices; the classic
"envelope" figure traces only from its odd corners. Reuses Untangle's line painter and
Grid Path's drag feel. Include the dead-end "Rewind 1" forgiveness.

### C. Data-review checkpoint vs the 2.3 baseline (which games earn their slot?).

---

## 4.7 — Version 2.5 (Mar 2027): systems only — modes, performance, money

**No new game. Deliberate.**

### A. Speed mode & Endless mode
**Reuse the Zen pattern exactly** — mode-aware `PrefsKeys`, own level records, own
achievements, adjusted scoring — do NOT invent a third persistence pattern. Speed =
timed variant (per-level clocks, time-based scoring). Endless = continuous scaling
run. Decisions to put to the owner first: which games participate; how the home-screen
mode switch scales past two modes; scoring multipliers.

### B. Performance pass
Handbook §6.2 profile-mode drag test on every game; fix the worst offenders;
re-verify `remember.md` Section E checklist app-wide. Also burn down the ~191
`withOpacity` deprecation lints (mechanical: `.withValues(alpha: …)`).

### C. IAP hardening — ✅ MOSTLY DONE 2026-08-23, ahead of this release
Purchase verification was a **client-side no-op** (flagged in the 1.8 audit). At the
owner's request it was implemented during the drip-feed rebuild and **ships in all six
bundles 61–66**: receipts are RSA signature-checked against the Play licensing public
key before anything is granted (`lib/utils/purchase_signature.dart`, gated in
`purchase_manager.dart`). It fails **open** where no signature can exist (non-Android,
no key, no signature) and **closed** only on a signature that is actually invalid.

Still open, if wanted: verifying purchase state via the store APIs on restore. True
server-side verification needs a backend — the owner has **explicitly accepted that
residual risk** rather than run one, so do not re-propose it as a checklist item.

**Effect on this release:** money is no longer part of 2.5. What remains here is Speed
mode, Endless mode and the performance pass.

---

## 4.8 — Version 2.6 (Apr 2027): Skyscrapers + Nurikabe + modifiers 3

**Heaviest release in the plan.** Both games are prototype→full builds — the audited
prototypes (`remember.md` D5) are ~15–20% complete demos: fixed 3×3/4×4 boards, 5–10
hand-typed levels, no generation/seeded RNG/hints/points/modifiers, own
`beta_level_*` save keys. Budget each at ~70% of a new game.

### A. Skyscrapers (from `lib/screens/games/beta/skyscrapers_beta.dart`)
Mechanic verified sound; all 10 hand-made levels brute-force verified solvable AND
unique. ⚠️ Levels 6 and 8 are byte-identical (and 2/7 near-identical) — replace
duplicates. Needs: sizes beyond 3×3 (4×4–6×6), a clue-generation + uniqueness-gate
solver, seeded RNG, full checklist 3.2 integration, and migration off the
`beta_level_skyscrapers` key (or accept fresh progress — owner's call; nobody could
reach it in production, so fresh is fine). Give it a **new proper game id** rather
than reusing beta plumbing.

### B. Nurikabe (from `lib/screens/games/beta/nurikabe_beta.dart`)
⚠️ **Unique-solution Nurikabe generation is genuinely hard** — the hardest generator
on this roadmap (island partition + connected wall + no-2×2-pool + uniqueness).
**Prototype the generator FIRST, before any UI work.** Acceptance bar: ≥99% of seeds
produce a verified-unique board within time budget at every size, proven by test.
**If it can't be made reliable: swap in Light Up** (`beta/light_up_beta.dart`, same
audit tier, far easier generation) and move Nurikabe to the post-2.6 backlog. That
substitution is pre-authorized by this plan; just tell the owner.

### C. Modifier batch 3: `seismic`, `drift`, `vertigo`, `inverse`
Handbook §A10/A1/A5/A11. `vertigo` Tier 1 only on tap-games (drag games need the
`_unrotate` transform); `inverse` always shows its "🔄 INVERTED" chip; skip the
Color Flood inverse variant (needs logic changes) unless time allows.

---

# PART 5 — RETENTION SYSTEMS (context)

Salvaged from the deleted `FEATURE_ROADMAP.md`; specs live in the release work orders
(S1 → 2.0, S3 → 2.1, event → 2.2, S2 → 2.3). All fully offline.

> **Approval note (2026-08-22):** `remember.md` Section A puts the daily-challenge
> system off-limits and C3 says streaks are "good enough, leave alone." The owner
> explicitly requested S1 and S2 on 2026-08-22 — that is the "unless asked" exception.
> It is NOT a general licence to touch those systems.

**Deliberately not salvaged** (personalisation, cheap only after analytics exists):
theme editor, player-selectable daily modifiers, difficulty profiles, insights page —
post-2.6 backlog. **Cut everywhere:** anything needing a backend (all leaderboards).

---

# PART 6 — QA + BUILD + SHIP PROCESS

## 6.1 What Chrome testing can and cannot do

`flutter run -d chrome` covers: UI/layout, game logic, level flows, modifier
behaviour, header standard. It **cannot** cover: haptics, IAP, ads, notifications,
home-screen widget, real device performance/frame rates, Play-specific behaviour.
Those gaps are exactly what the version folders are for.

## 6.2 Version folders (owner decision, 2026-08-22)

```
versions/
  1.8(50).aab                ← existing (flat, historical)
  1.9/
    cogniq-1.9.0+NN.aab
    NOTES.md
  2.0/
    ...
```

**`md/TESTING_CHECKLIST.md`** is the standing list of what must be checked on a real
device, per release, and why each item cannot be automated. Add a section to it every
release. `NOTES.md` in the version folder is the per-build record; the checklist is the
cumulative one, so an untested item from an older release stays visible.

`NOTES.md` per release records: **(1) what changed** — games added/revived, systems,
bugs fixed; **(2) device regression checklist** — the untestable-in-Chrome surface
touched this release (haptics? IAP? notifications?); **(3) known issues at ship
time**. Purpose: when a field bug arrives "since the last update," the folder tells
you exactly what that version touched. There is no git history — this IS the history.

## 6.3 Build procedure

1. Ship checklist 3.3 fully green.
2. **Owner approval to build.**
3. `flutter build appbundle` (strip-symbols error is cosmetic — Part 0).
4. Output: `build/app/outputs/bundle/release/app-release.aab` → copy/rename into the
   version folder.
5. Write `NOTES.md`.
6. Bump `pubspec.yaml` build number.
7. **Post-release cleanup (standing owner instruction, 2026-08-22) — run every time:**
   ```
   flutter clean            # removes build/ (~2.7 GB) and .dart_tool/ (~216 MB)
   rm -rf android/.gradle   # ~57 MB
   ```
   Measured 2026-08-22: this took the project from **3.1 GB → 114.6 MB**, of which
   105.6 MB is `versions/`. These caches are regenerated by `flutter pub get` + the
   next build. **They must never be copied between machines** — they contain absolute
   paths from the build machine (whose username contains a space) and produce
   confusing failures elsewhere. Also re-audit the repo root for stray docs and stale
   `analyze` dumps at this point; docs belong in `md/`, not the root.
8. Owner uploads to Play Console (Play App Signing re-signs with the app key).

---

# PART 7 — THE DIFFICULTY CEILING (design constraint on all new games)

Perception/memory games stale out: the only scaling axis is *faster, smaller, more*.
Proven twice in this app (August 2026 audit): **Odd Color Out** (with `noise`, decoy
tiles drifted further than the target — a coin flip) and **Chimp Test** (60 numbers;
past ~15 exceeds human recall — unwinnable). The standing rule for any perception-type
game: **decide the hardest fair level up front and stop there** (Chimp Test's
`_levels` list is the worked example; a code comment there warns not to "fix" the ≤15
cap into a rising curve — it is deliberate).

- **Genuine headroom** (combinatorial underneath): Sand Sort, Zen Slide, Untangle,
  Orbit, Light Beam, One Stroke, Skyscrapers, Nurikabe + every live logic game.
- **Real ceiling:** Split (B8), Shadow Match (B9) — pure perception; backlog, last.

---

# PART 8 — POST-2.6 BACKLOG AND EXCLUSIONS

## Game idea research (2026-08-23) — 10 proposed, all measured

Two agents proposed five ideas each; three more agents then **measured every one** with
throwaway probes (Python for sweeps, AOT Dart for cost figures). Nothing here is a
description — every verdict below is backed by hundreds or thousands of generated boards.

| Game | Verdict | The number that decided it |
|---|---|---|
| **Tumble** (tip a die across a grid onto seals) | ✅ **build first** | solver 1.80 ms measured, worst case 4,022 states, no tail |
| **Dominosa** (find a hidden domino set) | ✅ build | propagation-only rate 76% → 24% across the ladder; blanks are the real lever |
| **Driftwood** (Rush Hour) | ⚠️ build with a hard 10,000-node cap | optimised tail is **9.56 s** uncapped; capped, generation is 43–78 ms |
| **Twin Step** (two stones, one swipe) | ⚠️ build, but **drop both proposed variants** | mirror and ice each add **zero** measured depth |
| **Still Water** (Aquarium) | pending measurement | — |
| **Slant** | pending measurement | — |
| **Fit** (polyomino packing) | ❌ 6x6 only, cannot scale | difficulty runs **backwards**: 7x7 averages 37 solutions vs 1 at 5x5 |
| **Nebula** (Galaxies) | ❌ do not build | the "stranded single cell" fallback is **41.7% of the board** |
| **Fold** | ❌ do not build | under 32 reachable states; a player finishes it by tapping |
| **Norinori** | withdrawn by owner | — |

**Both proposing agents independently recommended not building a 25th game yet.** Of 24 live
games, 12 are spatial and **8 of those are the same idea** (draw or complete a path). The
shading slot is similarly crowded once Nurikabe lands in 2.6.

### Four findings worth keeping regardless of which game gets built

1. **A "trivially removable" cost is not removable until someone removes it.** Driftwood's
   3-second tail was attributed to a rebuild-per-expansion inefficiency. Rebuilt properly in
   AOT Dart it is **9.56 s** — the cost is component size (1.06M states), not the inner loop.
   The first agent was right to refuse to claim a number it had not measured.
2. **A bigger search budget can be strictly worse.** Driftwood at 50,000 nodes is 1.8x slower
   at the median and 3.3x worse at the tail than at 10,000, for **no gain in success rate**.
   Rejecting an expensive board fast beats exploring it.
3. **Every "0 solutions" must be proved, not believed.** All 19 zeros logged for Fit were
   **false** — the solver hitting its budget, not an absence. Boards were solvable by
   construction; one reported "0" actually had **at least 50** solutions. See `remember.md` 9g.
4. **A proposed mechanic must be measured before it is designed around.** Twin Step's mirrored
   and ice stones were both intended as the "something changes early" rung required by 9.
   Measured A/B on identical layouts, mirror gives an *identical* median solve distance to the
   decimal and a *lower* best depth. A plausible mechanism that does not bind is worse than
   none, because it stops anyone looking for the real one.

---

## Trail expansion — star-locked trails (proposed 2026-08-23, unscheduled)

Daily-challenge stars are earned, displayed and spent on **nothing**. `md/trail_ideas.md`
proposes 10 new swipe trails locked behind bronze/silver/gold/diamond tiers, giving stars a
purpose and separating the reward for *consistency* from the reward for *volume* (points and
clear counts).

Design constraints recorded there: star trails must never also be purchasable; `TrailCatalog`
stays the single source of truth (the screen and overlay drifted apart once already); the
trails screen needs a third card state showing progress toward a star threshold.

**Blocked on a measurement, not a decision:** the proposed thresholds are guesses, and the
daily system yields at most one star per day. Confirm real accrual rates before setting any
number.

---

## Backlog (nothing scheduled; decide after 2.6 with a year of data)
- **Light Up** — first in line for a slot (or the 2.6 Nurikabe substitute).
- **Kakurasu** (`beta/kakurasu_beta.dart`) — code verified sound (all 5 levels
  brute-force unique) but parked: would be the third addition puzzle after Sum Strike
  + Kakuro. Revisit once Kakuro has real usage data.
- **`twin` modifier** (handbook §A12) — needs mature Tier-2 painters.
- **Mirror Trace** (§B4); **Split** (§B8) and **Shadow Match** (§B9) — perception
  ceiling; last, if ever.
- **Personalisation:** theme editor, selectable daily modifiers, difficulty profiles,
  insights page.
- **Social/leaderboards/clans:** needs backend + accounts + anti-cheat + moderation +
  privacy story. Only if analytics shows the library alone is not retaining.

## Not planned at all
- **Word-game stash + memory/reaction stash** — rejected in `remember.md` D2, several
  carry unwinnable content; scheduled for **deletion** in 2.3, not revival.
- **Nonogram** — rejected (`remember.md` D4): multiple solutions.
- **Broken prototypes** (Tent and Trees — win check ignores tent-tree adjacency and
  tent-tent spacing, 4/5 stored solutions illegal; Thermometers — column clues alone
  reconstruct the answer, zero deduction; Shakashaka — 2 of 4 triangle orientations,
  compares against a stored answer instead of verifying the rectangle rule) — kept as
  reference only; details in `remember.md` D5. **Rewrites, never "finishes."**

---

# PART 9 — KNOWN-UNFIXED REGISTRY (so nothing silently vanishes)

| Issue | Status | Scheduled |
|---|---|---|
| IAP verification is a client-side no-op | flagged in 1.8 audit | **2.5** |
| Kakuro broken above level 5 + progress reset | fully diagnosed (§4.1) | **1.9** |
| Hitori freeze at 8×8 + bad hints | diagnosed | **2.0** |
| Slitherlink two-loop boards | ~~diagnosed~~ **refuted; real cause was a diagonal pinch, fixed** | 2.1 ✅ |
| Cipher Decoder unsolvable from level **6** (73.7%) and **13+** (100%); hints consumed on impossible boards | diagnosed; shift-dial redesign decided 2026-08-22 | **2.3** |
| ~25k lines of dead stashed games shipping in every bundle | measured | **2.3** |
| `/practice` route orphaned | ~~verified~~ **not a defect — KEPT by owner decision 2026-08-23; it is the wiring checklist's reference implementation** | closed |
| 191 `withOpacity` deprecation lints | cosmetic | **2.5** |
| Android SDK path space → strip-symbols warning | cosmetic; bundle valid | owner's machine; leave |
| Killer Sudoku 9×9 uniqueness partially improved, not proven | open | opportunistic |
| Grid Path (`zip`) level continuity — flagged in a root `notes.txt` scratch note (since removed); never investigated | unverified, low confidence | opportunistic |
| Not a git repository | suggestion made to owner | owner's call |

*End of plan. If you are a new agent: read `md/remember.md` Sections A–E next, then
start at the earliest unshipped version's work order. Ask the owner before starting.*
