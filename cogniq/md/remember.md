# CogniQ — Remember & Rulebook

**Last reviewed:** 2026-07-18 (claims re-verified against source; see Section B)
**How to use this file:** Read Sections A–E before coding. They are either hard constraints, facts verified in the source, or decisions the user actually made. Section F is *proposals only* — ideas generated during analysis that have NOT been decided or validated; treat them as a backlog to discuss, not a plan to execute.

> Integrity note: earlier drafts of this file mixed verified facts with subagent-generated strategy and invented metrics. This version separates them. Any number describing user behaviour (retention, session length, MAU) is an **assumption**, not measured data — the app currently ships **no analytics/network layer** (`ActivityTracker` writes only to local `SharedPreferences`), so none of those baselines can be known until analytics is added.

---

# SECTION A: HARD CONSTRAINTS (do not touch without explicit approval)

- **The 12 active games** — do not modify their logic/screens unless asked. IDs: `zip` (Grid Path), `oddcolor` (Odd Color Out), `chimp` (Chimp Test), `queens` (Star Battle), `minesweeper` (Mine Finder), `hue` (Spectrum), `sudoku`, `spellingbee` (Word Hive), `pattern_lock`, `colour_link`, `color_flood`, `circuit_guide`.
- **The daily challenges system** — off-limits unless asked.
- **The stats screen** (`_StatsTab` in `home_screen.dart`) — off-limits unless asked.

Everything else (achievements UX, settings, new games, scaling logic) is fair game per the decisions below.

---

# SECTION B: VERIFIED CODE FINDINGS (checked in source 2026-07-18)

### B1. Haptic toggle is dead — bug 🔴
`lib/theme/settings_manager.dart`, lines 84–94. All three helpers gate on `_soundEnabled`:
```dart
void hapticTap()     { if (_soundEnabled) HapticFeedback.lightImpact(); }
void hapticSuccess() { if (_soundEnabled) HapticFeedback.mediumImpact(); }
void hapticError()   { if (_soundEnabled) HapticFeedback.heavyImpact(); }
```
`_hapticEnabled`, its getter, and `setHaptic()` exist but gate **nothing** → the haptic setting does nothing; haptics follow the sound toggle.
**Fix:** change all three checks to `_hapticEnabled`.

### B2. Achievements are auto-claimed — confirmed 🔴 (this is the user's #1 requested change)
`lib/utils/achievement_manager.dart`, `checkAndUnlock()` (lines 214–352). The moment a condition is met it BOTH marks the id unlocked AND dispatches every reward inline (lines 318–344): points via `PointManager.addPoints`, titles → `unlocked_titles`, trail styles → `unlocked_trail_styles`, and `swipe_trail_unlocked` for `centurion`.
**To make claiming manual:** split this — `checkAndUnlock` should only mark "unlocked-but-unclaimed"; move the reward dispatch (322–343) into a new `claim(id)` called when the user taps Claim. Trails are dispatched via `rewardTrailStyle`, so routing them through `claim()` automatically satisfies "same manual claim for trails."

### B3. `completionist` achievement is unreachable — bug 🔴
`achievement_manager.dart` line 281 requires `playedGamesCount >= 15`, and its description says "Play all 15 active games," but only **12** active (non-stashed) games exist. It can never unlock. Change the threshold to 12 (or the current active-game count) when touching achievements.

### B4. Not personally re-verified this session (came from the scaling subagent — spot-check the file/line before acting)
The difficulty plateaus below are reported in `DIFFICULTY_SCALING_ANALYSIS.md` but were NOT re-read from source in this pass. Verify the exact clamp/const before editing:
- Circuit Guide — capped ~5×5 + 4 targets
- Mine Finder — `gridSize` clamped to 13
- Pattern Lock — capped at 5×5
- Sudoku — fixed level list, cycles instead of generating
- Spectrum — plateaus ~10×11

---

# SECTION C: USER-CONFIRMED CHANGES TO MAKE

### C1. Achievements → manual claim (see B2 for the mechanism)
- Remove auto-claim; add a **Claim** button per unlocked achievement in the achievements screen.
- Achievements must be **clickable/tappable** to claim.
- **Trails**: same manual-claim behaviour (clickable to claim).
- **Reduce the achievement toast timer** (currently too long → ~4–5s or less). Check `lib/widgets/achievement_toast.dart` for the duration.

### C2. UI alignment (user said the rest of the UI is fine)
- **NavBar (home tab):** when Home is selected the highlight capsule shows, but the icon + label are **not centred** within it. Fix in `home_screen.dart` → `_buildCustomBottomNavBar()` / `_buildNavItem()`.
- **Games grid alignment** on the home screen needs adjustment — `_buildHomeTab()` `GridView.builder` (spacing / `childAspectRatio` / padding).

### C3. Features the user judged "good enough" — leave alone
Notifications, streaks, daily challenges, and the achievements **core logic** are fine. The only achievements work is the manual-claim UX above.

---

# SECTION D: PRODUCT DIRECTION (endorsed by the user)

### D1. Positioning
CogniQ is a **logic-puzzle** app. Lean into that; don't try to be a well-rounded brain trainer.

### D2. Why not other genres (user's own reasoning)
- **Word games** — hard to generate procedurally; difficulty doesn't scale predictably. Do **not** unstash the old word games to "balance" the library.
- **Memory / reaction games** — hit a boredom ceiling; scaling just means "faster/more," which stops being interesting.
- **Logic games** — each puzzle differs even at the same difficulty, so they stay fresh. This is the moat.

### D3. Scaling philosophy — "don't just make it harder, make it different"
Add *secondary mechanics* as levels climb rather than only enlarging the grid: time pressure, a memory component, grid/shape evolution, hidden information, movement/rotation, and combinations of these. Full per-game progressions live in `DIFFICULTY_SCALING_ANALYSIS.md`. Worked example (Odd Color Out): single off-tile → two mutually-different tiles → rank 3 shades → position memory → moving grid → combined conditions.

### D4. New games to add (logic only, all scale naturally)
- **Kakuro** — arithmetic + logic; fills the number-reasoning gap.
- **Cipher Decoder** — treat as a *logic* puzzle. User's scaling idea: early levels every letter is off by 1; later levels one word differs by 1, another by 2, etc. This sidesteps the word-game generation problem.
- **Hitori** — cell-elimination; distinct mechanic.
- **Slitherlink** — loop/path logic; complements Colour Link.
- **Killer Sudoku** — variant leveraging existing Sudoku familiarity.
- Later candidates: Shakashaka, Yin-Yang, Norinori, Thermostat.
- **Rejected:** Nonogram (allows multiple solutions → ambiguous, bad for a logic app). Chain Breaker / Frequency / Vault Builder are novel but high-cost and niche — parked, not planned.

Design specs for these live in `GAME_SUGGESTIONS_WITH_DESIGN.md`.

---

# SECTION E: PERFORMANCE RULEBOOK (mandatory when writing/modifying game code)

These are the original project rules — they prevent jank during drag/pan/tap.

**1. No unconditional `setState` in gesture loops.** Never `setState()` every frame in `onPanUpdate` / `onPointerMove`. Use a `ValueNotifier` or a `CustomPainter`'s `repaint` listenable. For grid selection, diff against current state and only `setState` when a tile boundary is actually crossed.

**2. Isolate dynamic painters/grids in `RepaintBoundary`.** Wrap drag/draw areas so their repaints don't dirty the whole screen (AppBar, backgrounds, buttons).

**3. Optimize `CustomPainter`.** Implement a real `shouldRepaint` (never `=> true`). Pass an `AnimationController`/`ValueNotifier` to `super(repaint: …)` so the canvas repaints without rebuilding parents.

**4. No animation-listener `setState`.** Don't `controller.addListener(() => setState(...))` for drag effects — it rebuilds the whole tree per frame. Use the `repaint:` param or a tightly-scoped `AnimatedBuilder`.

**5. Defer heavy side-effects.** No disk writes (`SharedPreferences`) or O(N²) win-checks inside `onPanUpdate`. Keep changes in memory; persist/verify in `onPanEnd`/`onPanCancel`. Debounce quadratic checks.

**6. Keep hot paths O(1).** No `list.contains()`/`list.any()` inside `paint()` or `itemBuilder`. Maintain a `Set` of selected coordinates for O(1) lookups.

**Pre-commit checklist:**
- [ ] No per-frame `setState` during drag (only on a real tile change)
- [ ] Drag coords via `ValueNotifier`, not page state
- [ ] Grid/canvas wrapped in `RepaintBoundary`
- [ ] `CustomPainter` has a proper `shouldRepaint`
- [ ] Animation ticks don't trigger page-wide rebuilds
- [ ] Disk writes deferred to `onPanEnd`
- [ ] No linear scans in `paint()` / `itemBuilder`; use `Set`

---

# SECTION F: PROPOSALS — NOT decided, NOT validated ⚠️

Everything below was generated during analysis as *options to consider*. The user has **not** approved any of it. Do not treat it as a roadmap or cite its numbers as facts. Kept here so the ideas aren't lost.

- **12-month roadmap** (`FEATURE_ROADMAP.md`) — sequencing proposal only.
- **Social/community** (`SOCIAL_COMMUNITY_FEATURES.md`) — leaderboards, friends, clans, events. Note: these need a backend + accounts, which the app currently doesn't have (offline-first, no network). Big architectural commitment — discuss before scoping.
- **Onboarding overhaul** (`ONBOARDING_STRATEGY.md`) — tutorial/difficulty-select flow proposal.
- **Accessibility program** (`ACCESSIBILITY_RECOMMENDATIONS.md`) — the concrete, low-risk wins here (semantic labels on grids, verify WCAG contrast, text labels on icon-only buttons) are worth doing regardless; the broader program is a proposal.
- **All retention / MAU / session-length figures in those files are illustrative assumptions.** There is no analytics in the app yet. If any of these targets matter, step one is adding an analytics/measurement layer — otherwise success can't be observed.

---

# MD FILE INDEX

| File | Focus | Status |
|------|-------|--------|
| `remember.md` (this) | Constraints, verified facts, decisions, perf rules | Authoritative |
| `DIFFICULTY_SCALING_ANALYSIS.md` | Per-game scaling progressions | Reference (verify code before editing) |
| `COMPREHENSIVE_APP_ANALYSIS.md` | Full app audit | Reference (subagent findings — spot-check) |
| `GAME_SUGGESTIONS_WITH_DESIGN.md` | New-game concepts + design specs | Reference |
| `FEATURE_ROADMAP.md` | 12-month plan | **Proposal only** |
| `SOCIAL_COMMUNITY_FEATURES.md` | Leaderboards/friends/clans | **Proposal only (needs backend)** |
| `ACCESSIBILITY_RECOMMENDATIONS.md` | WCAG / a11y | Proposal (some quick wins worth doing) |
| `ONBOARDING_STRATEGY.md` | Tutorial/onboarding flow | **Proposal only** |
