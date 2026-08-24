# CogniQ — Device Testing Checklist

**Purpose:** the things that must be checked **on a real phone**, because nothing else can
check them. Every item here has already passed `flutter analyze` (0 errors) and the full
test suite, and most have been verified in a desktop browser. They are listed anyway
because those two tools are blind to whole categories of failure.

**How to use it:** work the newest release first. Anything unticked from an older release
is still outstanding — a fix shipped in 2.0 does not re-verify 1.9.

---

## 👉 Testing one of the six drip-feed bundles? Start somewhere else

This file is organised by **when a feature was written**. If you are about to upload one of
the `1.8.2+61` … `2.3.1+66` bundles, you want it organised by **which bundle you are holding**
instead — the roster differs in each one, so the answer to "what do I check?" differs too.

**Use `Documents\Cogniq Versions\TESTING_BY_VERSION.md`.** It has a fixed Part A (identical in
all six bundles) plus one short per-bundle section. Come back here for the long-form detail
behind any item.

### Measured 2026-08-23 — daily challenges do NOT vary by bundle

Worth recording, because the opposite is the intuitive guess and it would have shaped the
testing plan wrongly.

The plan holds **90 challenge slots across 30 themed weeks**, and **none of them schedules a
drip-feed game** — not Kakuro, Sand Sort, Light Beam, Hitori, Zen Slide, Slitherlink, Untangle
or Cipher Decoder. So the daily challenge sequence is **identical in all six bundles**, and
testing it thoroughly once (in 1.8.2) covers the set.

What the roster shrink *does* exercise is `_isLiveGame` at
`daily_challenge_manager.dart:1121` — the guard that stops a challenge offering a game with no
live route. That guard is what makes shrinking the roster safe at all, and it is the
descendant of the crash still live in `1.8.0+50`.

Separately, **16 of the 90 slots (18%)** point at seven games deleted in 2.3's cull
(`wordle`, `hangman`, `memory`, `sequence`, `flagle`, `numbermemory`, `wordbuilder`) and run
the deterministic stand-in instead. Handled, not broken — but it is a fifth of the plan
showing a substitute, and it is the same 16 in every build.

---

## Why this file exists

Three times now, a change passed a fully green test suite and was still broken in a way a
person would notice within seconds:

| Release | Passed tests, still broken |
|---|---|
| 1.9 Kakuro | Route commented out in `main.dart` — **crashed the moment you tapped the game** |
| 1.9 Sand Sort | The `fog` modifier blacked out the entire screen |
| 2.0 Hitori | Board overflowed the viewport by **908 pixels** on a wide screen |

The tests check logic, and layout at one phone-shaped viewport. They cannot check what a
person sees, feels, or hears.

**What automation in this project genuinely cannot reach:**
- Haptics — whether the phone actually buzzes, and whether it respects the setting
- Audio
- In-app purchases and rewarded ads — both are disabled entirely on web
- Notifications — `zonedSchedule` early-returns off-device, so it has **zero** coverage
- The home-screen widget
- Real frame rates, battery, and thermal behaviour
- Play Store install/update flows
- How anything looks in sunlight, at 1.15x font scale, or on a notched screen

---


## 2.2 (not yet built) — check on a device before release

**Untangle — brand new, never on hardware.** It is the project's first `CustomPainter` and
its first free-drag game, so the things most likely to be wrong are the things no test can
see.

- [ ] **Dragging feels right** — a node follows your finger, does not lag, and does not jump.
      Verify a **slow, deliberate drag** works: the Zen Slide sketch discarded those entirely
      because it keyed off gesture velocity, and that class of bug is invisible to tests.
- [ ] **You can grab the node you meant to grab**, especially at level 20+ where there are
      25 nodes. The handbook's scramble put two nodes on top of each other on 99% of late
      boards; that is fixed, but only a finger can confirm it.
- [ ] **The crossing counter is live and correct** while dragging, and hits "No crossings"
      exactly when the last crossing clears.
- [ ] **Level 1 is not already solved.** 54% of the handbook's level-1 boards were.
- [ ] **The hint moves a node that is actually in a crossing**, and never one already correct.
- [ ] Untangle **in landscape and on a tablet**, and at 320dp wide.
- [ ] Untangle with each modifier: `timer`, `fog`, `shy`, `mirror` — each must be **visibly
      named** on screen when it runs (remember.md §8).

**Modifier batch 2 — `momentum`, `decay`, `heartbeat`.** All only appear from level 15+.

- [ ] **`momentum` (Word Hive, Sum Strike)** — the flame chip climbs on a chained correct
      answer and resets on a mistake. **Check the payout**: an unchained clear must award the
      same points it always did (×1 pays a 0 bonus). A perfect chain tops out at +40 over the
      base 10. This is the third near-miss on double-paying points in this project.
- [ ] **`decay` (Kakuro, Slitherlink)** — clue *ink* fades and a tap brings it back briefly.
      The clue **value** must never change: a faded-then-restored clue must read the same
      number, and the board must still be solvable and still validate.
- [ ] **`heartbeat` (Sand Sort, Spectrum)** — contents blank periodically **in place**. Tube
      fill levels, hit targets and grid shape must not move. It should only ever appear
      alongside a timer; if you see it on an untimed level, that is a bug.
- [ ] **No board is ever fully unreadable.** `heartbeat` must never co-occur with `fog`,
      `whisper`, `minimal`, `wildcard` or `eclipse`, and `decay` must never co-occur with
      `clueThinning`, `wildcard` or `eclipse`.
- [ ] **Kakuro, Spectrum and Word Hive at 320dp with modifiers on (level 15+)** — all three
      had overflows that shipped, invisible because the layout test only booted level 0.

**Winter event — invisible until 18 December.** No browser sweep on any build day can see
this; tests are its only other coverage.
- [ ] Set the device clock into **18 Dec – 5 Jan** and confirm the banner appears, the night
      trail lights one lantern per day, and the milestone labels change.
- [ ] **Tap a featured game from the banner** — it must route correctly and appear in
      Recently Played, but must **NOT** advance the badge (opening is not clearing).
- [ ] **Clear a level during the window** — that must advance it.
- [ ] Set the clock to 6 Jan: the banner must disappear.
- [ ] Dismiss the banner, then re-open the app — it stays dismissed for that occurrence only.

## Known flaky-under-load test — do NOT "fix" it by raising the bound

`test/sandsort_logic_test.dart` → *"generating every level stays far away from hanging"*
asserts the slowest single level generates in **under 500ms**. That is the correct shape of
gate (per level, not an aggregate).

It fails when a `flutter build` or another test run is competing for CPU: measured **2064ms
under load, 281ms in isolation** on 2026-08-23. Same code, 7x difference.

**The fix is process, not the threshold.** Run `flutter test` and `flutter build` one at a
time. If this test fails, re-run it alone before believing it:

```
flutter test test/sandsort_logic_test.dart
```

Raising the 500ms bound would blind the project to a real regression in the one generator
that has previously blocked the UI thread for minutes. Leave it.

## 2.3 (not yet built) — check on a device before release

**Cipher Decoder — completely rebuilt, and the old version was unplayable.** From level 6,
**73.7%** of puzzles could not be solved at all; from level 13, **100%**. It also charged the
player a hint on those impossible boards. The whole input method changed: the letter keyboard
is gone, replaced by **one 0-25 dial per word**, like a suitcase lock.

- [ ] **Turn the dials.** Each word's letters must change live as its dial turns. Reaching the
      answer on the last dial should win immediately — there is no Check button any more.
- [ ] **Play levels 6, 13, 20 and 30.** Every one of these was impossible before.
- [ ] **No word is ever shown in plain English** at the start. Shift 0 is excluded, but this
      is the kind of thing only an eye catches.
- [ ] **Hint reveals one word's dial**, and costs exactly one hint.
- [ ] **Reset zeroes all dials.**
- [ ] Cipher Decoder in landscape and at 320dp; and with each modifier
      (`timer`, `fog`, `whisper`, `quota`, `retro`) — each must be **named on screen**.

**Daily challenges — 16 theme weeks are visible for the first time.**
- [ ] **Play past day 98.** Days 99+ are content that has never been reachable: Gravity,
      Illusion, Ice, Ghost, Swap, Magnet, Encryption, Mutation, Echo, Blind, Aurora, Matrix,
      Grand Finale. Confirm each day offers 3 playable challenges and none crashes.
- [ ] **Your existing progress day must not move.** If you were on day 57, you are still on
      day 57, with the same three challenges.
- [ ] **The banner must read "Week N of 30"**, never "of 14".
- [ ] **Finish a daily without using a hint** — you should get **+10** on top of the usual
      25/50. Then use a hint on another and confirm no bonus.

**The 10 deleted games.**
- [ ] Nothing in the app should reference Word Guess, Word Ladder, Mahjong, Hangman, Reaction
      Time, Number Memory, Word Builder, Sequence Memory, Word Climb or Flag Finder — no
      broken tile, no empty row, no crash from a stale shortcut or home-widget entry.
- [ ] **Existing players' saved progress must survive the deletion.** Install the previous
      build, play a few games, then upgrade to this one and check levels/points/streaks.

**The colour rename** (`wordleGreen` → `positiveGreen`) was value-identical, but:
- [ ] Success snackbars, the analytics consent dialog, and the Settings switches/slider should
      all look exactly as before.

## 2.4 (in progress) — check on a device

- [ ] **Zen mode is now visible in every game.** Turn Zen on from the home header (the leaf
      icon), open any game, and confirm the app bar reads **🍃 Zen · Level N**. Turn it off
      and confirm it goes back to **Level N**.
- [ ] **A daily challenge still says "Daily"** while Zen is on — not "Zen".
- [ ] **Check a 3-digit level in Zen on a small phone** — that is the widest the chip gets.
- [ ] **The Zen level number should differ from your Challenge level.** That is correct — they
      are separate ladders. Before 2.4 nothing said so, which looked like lost progress.
- [ ] **First-run tour** — clear app data, reopen, and step through it. Check: Next reaches
      the end, **Skip** works at any point, it does **not** appear again on the second open,
      and it does not collide with the "Today's Daily Challenge" prompt.
- [ ] **Re-open the tour from Settings** and confirm it still works after being dismissed.
- [ ] **Purchases still complete.** 2.4 added signature verification to every purchase — buy
      something as a licensed tester and confirm the item is granted. **If a real purchase is
      ever rejected, that is a bug in the verifier and it costs real money** — report it
      immediately rather than retrying.

## The home-screen widget — never once looked at

Add the CogniQ widget to your Android home screen and check it properly. It has shipped since
1.8 and **no one has ever seen it run.** It is the only surface where a bug sits permanently
on someone's home screen.

- [ ] **It renders at all**, in both widget sizes offered.
- [ ] **Light theme AND dark theme** — widget layouts do not inherit the app's theme.
- [ ] **Every number is right**: daily streak, total solved, star counts (bronze/silver/gold/
      diamond), today's puzzle name and description.
- [ ] **It refreshes.** Clear a daily, go back to the home screen — does the number move?
- [ ] **Long text does not overflow** — a long game name or description in the smallest size.
- [ ] **Tapping it opens the app** at something sensible.

## Long-standing items found during 2.1 — check on ANY build

These are not tied to one release. Both predate 1.8 and are still present. Full write-up in
`versions/2.0/NOTES.md`.

- [ ] **Color Flood levels 10-34** — the move budget has **zero slack** here (`buffer = 0`).
      Play 10, 20 and 30 normally and see whether they feel unfairly tight. Then play 35-40,
      where the board is bigger *and* 3 spare moves are granted, and compare. The question to
      answer is whether difficulty actually rises across level 35, because the slack does.
      The budget is a **greedy** solver's move count, not a true optimum, so matching it is
      possible — do not widen the buffer without playing it first.
- [ ] **Circuit Guide with the `timer` modifier (level 15+)** — let the clock hit zero.
      Expected on 2.0 and earlier: the level **does not end**, you just lose the speed bonus.
      Star Battle and Grid Path end the level on the same modifier. Decide which behaviour
      you want; 2.1 adds a `quota` loss overlay to this game, so test this on 2.0 first or
      the two become indistinguishable.
- [ ] **Star Battle on a narrow screen (≤360dp), level 15+ with the `timer` modifier** —
      on 2.0 and earlier the countdown chip is reported to render *only* at ≥360px wide, so
      the timer runs invisibly. Set Display Size to Largest to shrink effective dp width.
      **This one is unverified** — the source changed before it could be re-read, so confirm
      or refute it on a device. Fixed in 2.1 either way.
- [ ] **Star Battle with the `zoom` modifier at ≤360dp** — the Draw Stars / Scroll Grid
      toggle overflows its row. Pre-existing; fixed in 2.1.
- [ ] **Seasonal badge counts clears, not launches** (2.2 fix) — during an event window,
      open a game and back out five times: the badge must NOT unlock. Then clear five
      levels: it must. On **2.1.0+53 the first case wrongly unlocks it**.
- [ ] **Hitori with the `timer` modifier (level 15+)** — a countdown chip must appear and
      count down. On **2.0 and 2.1 nothing happens at all**: the modifier was pooled with no
      implementation, so those levels ran with no modifier effect. Fixed in 2.2.
- [ ] **Hitori on a small phone (320dp wide, or Display Size = Largest)** — on 2.0 the
      board column overflows the bottom by ~106px, so the lower controls are clipped. Fixed
      in 2.1. This is separate from the 908px landscape overflow 2.0 already fixed.
- [ ] **Any game in landscape / on a tablet / in split screen** — until 2.1 the layout test
      had no wide-short viewport at all, so *no* game was ever checked in that shape by the
      suite. 2.1 closed the gap and all 22 games now pass, but nothing before 2.1 was
      verified. Worth a sweep on a real tablet.


## Release 2.0 — Hitori, Light Beam, streaks, analytics

**Status: bundle built (`versions/2.0/`), device-untested.**

### ⚠️ Two open concerns carried into this build

These were known and accepted at build time. They are not defects — they are decisions
still outstanding, recorded here so they are not quietly forgotten.

**1. The analytics consent dialog is deliberately NOT shown.**
The analytics layer is complete and wired into startup, but **no backend has been
chosen**, so the default sink is a no-op and nothing leaves the device. Showing a consent
prompt in that state would ask people to approve collection that goes nowhere — and a
prompt that means nothing teaches people to dismiss the prompt that eventually matters.

- What this means for testing: **no consent dialog should appear on first run.** If one
  does, that is a bug.
- What it means for shipping: analytics collects nothing in 2.0. It is scaffolding.
- **The decision needed:** pick a backend. Wiring one in is a single class implementing
  one method, plus `Analytics.setSink(...)`, plus enabling the dialog. A privacy policy
  and a Play Console data-safety declaration are required **before** the prompt goes live;
  the exact collected/not-collected lists for that declaration are in
  `md/RELEASE_PLAN.md` §4.2C.

**2. This bundle has never run on real hardware.**
Same as 1.9. Everything below was verified by 431 automated tests and a desktop browser,
neither of which can touch haptics, notifications, IAP, ads, the home widget, real frame
rates, or how anything looks in daylight.

- The single highest-risk item in 2.0 is the **streak reminder notification**, which has
  **zero** automated coverage — `zonedSchedule` early-returns off-device, so not one line
  of the actual scheduling path has ever executed.
- The 908px Hitori overflow (found in a browser, fixed) is the reminder that a green suite
  is not evidence about layout on a real screen.

### Hitori (revived — was completely unplayable before)
- [ ] Open Hitori. It should appear in the games grid (it was stashed until now).
- [ ] **Reach level 6.** Before this release this froze the UI for ~22 minutes. It should
      open instantly.
- [ ] **Reach level 13+ (8x8).** Previously impossible — the search would have taken
      months. Should open instantly.
- [ ] **Rotate to landscape, and try a tablet if you have one.** The board overflowed by
      908px on wide-short screens; fixed, but verified only in a browser.
- [ ] Use a **hint**. Confirm it does not destroy a board you were solving. This was the
      worst bug in the game: ~96% of boards stored an illegal solution, so a single hint
      tap wrecked a winning position, charged you a hint, then said you were correct while
      the Check button disagreed.
- [ ] Solve a board and press **Check**. It should accept it.
- [ ] Clear a level, close the app fully, reopen. **Progress must persist.**
- [ ] At level 12+ confirm modifier chips appear (`timer`, `fog`, `zoom`) and that each
      one visibly does what it says.

### Light Beam (new game)
- [ ] Open it. Tap an empty cell: it should cycle `/` → `\` → empty.
- [ ] The beam should re-route live as you place mirrors.
- [ ] Light every crystal and confirm the win fires.
- [ ] Check the mirror budget in the footer counts down correctly.
- [ ] At level 15+ confirm the modifier chips (`timer`, `tightBudget`, `fog`) appear and
      work. `tightBudget` should show one fewer mirror than usual.
- [ ] Level 66 is the intended hardest level. Confirm it is hard but fair.

### Streaks (S1)
- [ ] Play any game today. The streak should register — it used to count **only** daily
      challenges.
- [ ] Play again the same day; the streak must **not** double-count.
- [ ] Play on consecutive days and confirm it increments by exactly 1.
- [ ] **Miss one day, then return.** The free monthly skip should save the streak.
- [ ] Miss a second day in the same month. The streak should break.
- [ ] Reach 7 days and confirm the milestone appears as **unlocked-but-unclaimed** —
      you must tap to claim it. It must not auto-grant.
- [ ] ⚠️ **The streak reminder notification has no automated coverage at all.** Confirm it
      fires, and at a sensible hour (~20:00 local, or ~45 min from now if 20:00 has
      passed).
- [ ] Play a level in **Zen mode** and confirm it sustains the streak — Zen is a parallel
      progression, not a lesser one.

### Analytics
- [ ] **Nothing should be visible yet.** No consent dialog appears on first run — that is
      deliberate, no backend has been chosen. If you see a consent prompt, that is a bug.
- [ ] Settings should show a **Privacy** section with an analytics opt-out and a
      "What We Collect" row.
- [ ] Toggle the opt-out and confirm the app does not crash or stall.
- [ ] ⚠️ Confirm the app still works **fully offline** — aeroplane mode, play a few
      levels. The zero-network property is supposed to be intact (verified in code: no
      network imports, `pubspec.yaml` unchanged), but confirm it in the real world.

---

## Release 1.9 — Kakuro, Sand Sort, and a live crash fix

**Status: bundle built (`versions/1.9/cogniq-1.9.0+51.aab`), device-untested.**

### 🔴 Highest priority — this bug was live in 1.8(50)
- [ ] **Open the daily challenge on several different days.** The 30-day plan scheduled 16
      of its 90 slots on stashed games whose routes do not exist, and there is no
      unknown-route fallback — so those days threw an unhandled exception and killed the
      app. Confirm no day crashes.
- [ ] Complete a daily challenge and confirm the reward is granted **once**. Six games
      used to double-count daily clears, inflating points, achievements and trail unlocks.

### Kakuro (revived)
- [ ] **Reach level 6, close the app, reopen.** Before 1.9, reaching level 5 silently
      **wiped your saved progress** every single time. This is the most important
      persistence check in the app.
- [ ] Reach level 13+ (8x8) and confirm it opens instantly.
- [ ] Confirm the same level always gives the same puzzle (it was unseeded before).

### Sand Sort (new)
- [ ] Pour sand between tubes; confirm blocks move as expected.
- [ ] **Haptics fire on every pour.** Then turn haptics off in Settings and confirm they
      stop — the haptic toggle is independent of the sound toggle.
- [ ] At level 15+ check the modifiers: `Monochrome` must stay playable (every layer
      carries a distinct glyph, so it never depends on colour alone); `Move Budget` should
      show `Pours: n / m` and restart the level if you run out.
- [ ] Level 55+ should feel consistently hard — it used to get *easier* at high levels.

### Games that awarded nothing
- [ ] Clear a level in **Pearl Loop**, **Sum Strike** and **Killer Sudoku**. Each should
      now award points and increment your cleared count. Before 1.9 all three gave
      literally nothing — no points, no achievements, no trail progress.

### Determinism
- [ ] **Odd Color Out** and **Spectrum**: replay the same level twice and confirm the
      board is identical. Levels 1–90 and 1–30 respectively were previously random on
      every visit.

### Accessibility
- [ ] Turn on TalkBack and confirm icon buttons announce sensible names (82 tooltips were
      added, and a tooltip doubles as the screen-reader label).
- [ ] Set font scale to **1.15x** in Settings and check a few games for clipped text.

---

## Release 1.8 and earlier — never formally device-tested

Carry these forward until they have been done once.

- [ ] **In-app purchase**: buy hints. Confirm the purchase completes and hints arrive.
      ⚠️ Purchase verification is **client-side only** — a known unfixed issue scheduled
      for 2.5. Worth confirming the happy path works.
- [ ] **Restore purchases** on a reinstall.
- [ ] **Rewarded ads**: watch one and confirm the reward is granted.
- [ ] **Home-screen widget**: add it, confirm it updates.
- [ ] **Zen mode**: clear levels in Zen and confirm it does **not** advance
      Challenge-side trails or achievements. They are parallel progressions.
- [ ] **Achievements**: confirm claiming is manual — nothing should auto-grant.
- [ ] Play on a **low-end device** if you have one: check for jank while dragging in Grid
      Path, Colour Link and Pearl Loop.

---

## Every release, always

- [ ] Install **over the previous version** (not a clean install) and confirm saved
      progress, points and hints all survive.
- [ ] Cold start: force-stop, reopen, confirm no crash and progress intact.
- [ ] Background the app mid-level, return, confirm state is preserved.
- [ ] Rotate the screen on two or three games.
- [ ] Dark mode and light mode.
- [ ] Aeroplane mode: the app is offline-first and must work fully.

---

## Reporting back

For anything that fails, the useful details are: **which game, which level, what you did,
what happened**. Level number matters most — nearly every bug in this project's history has
been level-dependent.

If a phone is connected by USB with debugging enabled, exceptions and stack traces can be
read live from the running app, which turns "it closed" into an exact line of code.

---

## Maintaining this file

Add a new section per release, newest at the top, following the pattern above:
**what changed → what to check → why it cannot be automated.** Keep the "why this file
exists" table current — each new entry is evidence for why the device pass is not optional.
