# What to test in each bundle

*Written 2026-08-23, after the six-bundle rebuild. Use this next to the zips — it tells you
what changes from one upload to the next, so you are not re-reading a 400-line checklist every
month.*

**How to use it:** do **Part A** every single time (it is the same in all six bundles), then
do the one **Part B** section for the bundle you are actually uploading. Part B is short on
purpose — it is only what is *different* about that build.

---

## The one thing that surprised me — read this first

I expected the daily challenges to change between bundles, since each one has a different
number of games. **They do not.** I measured it: the daily plan schedules 90 challenge slots
across 30 themed weeks, and **not one of them uses a drip-feed game** (Kakuro, Sand Sort,
Light Beam, Hitori, Zen Slide, Slitherlink, Untangle, Cipher Decoder).

So the daily challenges are **byte-identical in all six bundles**. Test them properly once,
in 1.8.2, and you do not need to re-test them for the roster in later uploads.

Two consequences worth knowing:

- **74 of the 90 slots** run their real scheduled game. The other **16 (18%)** point at seven
  games that were deleted in 2.3's cull (`wordle`, `hangman`, `memory`, `sequence`, `flagle`,
  `numbermemory`, `wordbuilder`) and fall back to a deterministic stand-in. That is handled,
  not broken — but it means nearly a fifth of your daily plan is showing a substitute. See
  `DECISIONS.md` §6.
- The old crash was a challenge pointing at a game with **no live route**. The code now checks
  this before offering a challenge (`_isLiveGame`), which is why the roster can shrink safely.
  That guard is the single most important thing to confirm on a device.

---

# PART A — do this for every bundle

Same in all six. Should take about 20 minutes once you know the route.

### A1. The crash that is live for your users right now 🔴

This is the whole reason to ship. Do it first, on every bundle.

- [ ] Open **Daily Challenge**. Play the Easy, Medium and Hard one for today.
- [ ] Move the phone clock forward a day and repeat. Do this for **at least 7 days in a row**
      so you cross a theme-week boundary.
- [ ] Confirm **no challenge ever opens a blank screen or crashes**. Every one must either
      open a real game or show a sensible substitute.
- [ ] Confirm the streak and the star (bronze/silver/gold) update after finishing.

### A2. First-run tutorial (new — never seen on a device)

- [ ] Fresh install, or clear app data. The tutorial dialog should appear **once**.
- [ ] Tap *Next* through every step. Check nothing is cut off on your screen.
- [ ] Confirm it covers shuffle, achievements, trails and Zen mode.
- [ ] Close and reopen the app — **it must not appear again**.
- [ ] Check it does not collide with the Android notification-permission prompt.

### A3. Zen mode is visible now (new)

- [ ] Turn Zen mode on. The level chip in the game header should read **"Zen  Level N"**.
- [ ] Turn it off. The chip goes back to **"Level N"**.
- [ ] Check this in **three or four different games**, not just one — it comes from one shared
      widget, so if it works in one it should work in all, but confirm the header does not
      overflow on a small screen.

### A4. Privacy toggle is reachable now (new)

- [ ] Go to the **Profile tab**. There should be a **Privacy** section.
- [ ] It has an analytics toggle and a "What We Collect" summary.
- [ ] Toggle it off and on. Close and reopen the app — **the setting must stick**.
- [ ] There should be **no separate Settings screen** anywhere.

### A5. Purchases 🔴 (new check — can block a real purchase)

- [ ] Sign in as your **licence tester** account.
- [ ] Buy something. It must complete and the item must be granted.
- [ ] Force-close and reopen — the purchase must still be there.
- [ ] Try **Restore Purchases**.

> If a purchase that *should* work gets rejected, that is the new signature check being too
> strict. Tell me and stop uploading until it is fixed — that is the one new change that can
> cost you money.

### A6. Home screen numbers

- [ ] The report card shows a **play streak** (opening the app), not the daily-challenge streak.
- [ ] The **cleared count** matches the one on the Trails screen. They must agree.
- [ ] Toggling Zen mode on/off must **not** make the cleared count jump around.

### A7. Always

- [ ] Both **light and dark** theme on every screen you touch.
- [ ] **Small phone** — check nothing overflows in game headers.
- [ ] Rotate to landscape in a few games.
- [ ] Kill the app mid-game and reopen — progress should be where you left it.

---

# PART B — the bit that changes per bundle

Only do the section for the bundle you are uploading.

---

## B1 · `cogniq(1.8.2(61)).zip` — 16 games, 2 trails

**This is the first upload. It is also the most important one**, because it is the one that
reaches the users currently hitting the crash.

**Games live (16):** Grid Path · Odd Color Out · Chimp Test · Star Battle · Mine Finder ·
Spectrum · Sudoku · Word Hive · Pattern Lock · Colour Link · Color Flood · Circuit Guide ·
Pearl Loop · Bridges · Sum Strike · Killer Sudoku

- [ ] **Confirm the other 8 games are not visible anywhere** — not on home, not in search, not
      in the shuffle pool, not in a seasonal event. Kakuro, Sand Sort, Light Beam, Hitori,
      Zen Slide, Slitherlink, Untangle and Cipher Decoder must be absent.
- [ ] **Shuffle** — press it 20 times. It must never open a game not in the list above.
- [ ] Play a few levels of each of the 16, far enough to clear one.

**Trails (2):** Morning Mist 🌫️ and Tide Line 🌊

- [ ] Only these two star trails appear on the Trails screen. Aurora Veil, Starfall, Petal
      Fall, Constellation and Eclipse must be **completely absent** — not greyed out.
- [ ] **Trail Collector III does not exist in this build** (there are no gold/diamond trails
      to need it). Confirm the achievements list shows only I and II.

---

## B2 · `cogniq(1.9.2(62)).zip` — 18 games, 3 trails

**New since last upload:** Kakuro, Sand Sort · trail **Aurora Veil** 🌌

- [ ] **Kakuro** — play past **level 5**. It used to become unsolvable there. Clear at least
      levels 4, 5, 6 and 7.
- [ ] **Sand Sort** — play 10 levels. It used to deal boards that could not be solved at all;
      confirm every one is finishable.
- [ ] Aurora Veil appears on the Trails screen; Starfall and later are still absent.
- [ ] Shuffle now includes the two new games and still nothing beyond the 18.

---

## B3 · `cogniq(2.0.2(63)).zip` — 20 games, 4 trails

**New since last upload:** Light Beam, Hitori · trail **Starfall** ☄️

- [ ] **Hitori** — this was completely unplayable before. Play 10 levels and confirm each one
      can actually be finished.
- [ ] **Hitori on a small phone** — it used to overflow by about 106px. Check the board fits.
- [ ] **Hitori's timer modifier** — it used to be offered with no implementation behind it.
      Play a level where a timer appears and confirm it actually counts and matters.
- [ ] **Light Beam** — play 10 levels.
- [ ] Starfall appears; Petal Fall and later still absent.

---

## B4 · `cogniq(2.1.2(64)).zip` — 22 games, 5 trails

**New since last upload:** Zen Slide, Slitherlink · trail **Petal Fall** 🌺

- [ ] **Slitherlink** — play 15 levels. Watch for a board where the loop pinches at a diagonal
      and cannot close. Every level must be completable.
- [ ] **Zen Slide** — play 10 levels. Confirm it behaves sensibly with Zen mode both on and off.
- [ ] Petal Fall appears; Constellation and Eclipse still absent.
- [ ] Check the **seasonal event** on this build does not feature a game that is not live.

---

## B5 · `cogniq(2.2.2(65)).zip` — 23 games, 6 trails

**New since last upload:** Untangle · trail **Constellation** ⭐ · the **winter event**

**Aim to upload this one in December** so the winter event lands in season.

- [ ] **Untangle** — play 15 levels. Two specific things were wrong and were fixed:
  - [ ] **Level 1 must not arrive already solved.** Over half of them used to. Restart level 1
        about ten times and confirm you always have real work to do.
  - [ ] **Around level 24 and up**, confirm the dots are not sitting on top of each other.
- [ ] **Winter event** — set the phone clock to December. Confirm the event appears and every
      featured game it names actually opens.
- [ ] Constellation appears; Eclipse still absent.

---

## B6 · `cogniq(2.3.1(66)).zip` — 24 games, 7 trails

**New since last upload:** Cipher Decoder · trail **Eclipse** 🌑 (the final trophy)

- [ ] **Cipher Decoder** — play from level 1 to at least level 20. It used to be unsolvable
      from level 6 onward, and the difficulty ladder was rebuilt. Confirm **every level is
      solvable** and the jump in difficulty feels gradual, not sudden.
- [ ] Eclipse appears. **All 7 star trails** are now on the Trails screen.
- [ ] **Trail Collector I, II and III** all exist in this build.
- [ ] Daily challenges: this build has the full 24-game roster, so re-run **A1** once more here
      as a final confirmation.

---

## When you find something

Tell me: **which bundle**, **which game**, **what level**, and what you saw versus what you
expected. Level number matters more than anything else — nearly every generator bug this
project has had only shows up past a certain level.

*Companion files: `DECISIONS.md` (what is waiting on you), `NOTES.md` (what each zip is), and
`md/TESTING_CHECKLIST.md` inside each zip (the long-form original, kept for detail).*
