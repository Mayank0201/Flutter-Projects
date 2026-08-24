# Decisions waiting on you

*Rewritten 2026-08-23 after the six-bundle rebuild. Plain words. Work down the list — it is
in the order I would do them, and the reason for that order is at the bottom.*

Everything below is **waiting on a decision from you**, not on work. Nothing here is blocked
on code.

> **What changed in this rewrite:** three items on the old version described work that has
> since been done — the analytics opt-out is now reachable, the IAP signature check shipped,
> and the file it told you to install (`cogniq(1.8.1(55)).zip`) no longer exists. Those are
> corrected below rather than left to mislead you.

---

## 1. 🔴 Test on a phone before uploading anything

**The situation:** Six bundles are built. **None has ever run on a phone.** Not one.

**Why it's first:** The version your users have right now (1.8) has a bug where tapping
certain daily challenges **crashes the app**. That fix has now sat unshipped through seven
builds. Every day it stays unshipped is a day people hit a crash you already fixed.

**What to do:**
1. Unzip `cogniq(1.8.2(61)).zip` and install `out/cogniq-1.8.2+61.aab` on your phone
2. Work through **`TESTING_BY_VERSION.md`** in this folder — it lists exactly what to check
   for *that* bundle, since each one has a different game roster
3. Upload to Play's **internal testing** track — no user sees it until you promote it

**Test a real purchase before you promote.** The IAP signature check is new and it is the only
change that can *block* a purchase that should have worked. It is deliberately built to fail
open when there is no signature to check and to reject only an actually-invalid one — but that
code has never run on a device. Buy something as your licence tester first.

**Why not just upload it:** Seven releases of changes have never been touched by a human.
Tests caught a lot, but they cannot tell you if something *feels* wrong.

---

## 2. 🔴 Pick where your usage data goes (analytics)

**The situation:** The app has all the code to measure which games people actually play. It is
switched off, because **nowhere has been chosen to send the data**. Open since October.

**Why it matters:** Two jobs on the roadmap cannot happen without it —

- **"put popular games first"** — cannot know what's popular
- **2.4's data review** ("which games earn their slot") — same problem

**Why it can't wait:** Both need about **3 months of data**. That is wall-clock time. Deciding
in January does not give you data in January — it gives you data in April. This is the only
thing on your roadmap that working harder later cannot fix.

> ### ✅ The precondition that used to be here is FIXED
> The analytics opt-out used to live only on `settings_screen.dart`, which nothing in the app
> could open — so switching analytics on would have left users with no way to switch it off.
>
> **Done 2026-08-23:** the Privacy section (opt-out toggle plus a "What We Collect" summary)
> now lives in the Profile tab, where players actually go, and the orphaned settings screen
> was deleted. This is no longer blocking the decision — but it does mean the toggle has
> never been seen on a device, so look at it when you test.

> ### ✅ DECIDED 2026-08-23 — the owner will set this up personally
> Not delegated, not dropped. The full instructions live in **`md/remember.md` §15** so they
> can be followed cold, months from now, without reconstructing the plan.
>
> **What §15 contains:** the three steps (add the vendor package → write one class
> implementing `AnalyticsSink` → call `Analytics.setSink(...)` after `Analytics.initialize()`
> at `main.dart:78`), the `deliver` return-value contract that *is* the offline queuing, the
> pre-ship Play requirements, and the one trap worth repeating here —
>
> **⚠️ Build the vendor SDK lazily, inside the first `deliver` call.** `Analytics` never calls
> `deliver` without consent, but a vendor SDK constructed eagerly at startup beacons on its
> own — and you would have broken the opt-out without ever touching the opt-out code.
>
> Nothing is blocked while this waits. The app makes **zero network calls** today
> (`NoopSink`), and `test/analytics_test.dart` keeps it that way.

**The one thing time still decides:** the 2.4 data review needs ~3 months of data. Setting
analytics up in month *N* means the review can happen in month *N+3*, not month *N*. If 2.4
arrives first, ship its games and drop the checkpoint rather than delaying the release.

---

## 3. 🟡 Should 2.5 come before 2.4?

**The plan says:** 2.4 = two new games (Orbit, One Stroke) → 2.5 = no new games, just systems
(Speed mode, Endless mode, performance, payments).

**Why I'm asking:** Both game-idea agents, working separately, said the same thing —
**you have enough games.** 24 now, 28 by 2.6. Eight of them are basically "draw a line".

One put it directly: *the value of game #25 is lower than the value of the systems pause.*

> ### ✅ UPDATED 2026-08-23 — the payments half of 2.5 is already done
> The old version of this file said IAP hardening was dropped. You then asked for it, and
> **it shipped in all six bundles**: purchase receipts are now signature-checked against your
> Play licensing public key, so a faked "you already paid" response is rejected.
>
> This is the mitigation that needs no backend. It catches casually repackaged APKs. It is
> **not** server-side verification and does not claim to be — someone determined can still
> patch the check out of the app itself. Your recorded decision to accept that residual risk
> rather than run a backend still stands.
>
> **Effect on this question:** payments are no longer an argument for either order. What is
> left of 2.5 is Speed mode, Endless mode and a performance pass.

> ### ✅ DECIDED 2026-08-23 — keep the order, 2.4 first
> **Orbit and One Stroke ship next**, as originally planned. 2.5 (Speed mode, Endless mode,
> performance) follows.
>
> Recorded for the future reader: both game-idea agents independently recommended the
> opposite — pausing on new games at 24 — and I leaned that way too. The owner chose more
> games. That is a legitimate product call, not an oversight, so **do not re-litigate it**
> next time this file is read.
>
> One consequence to keep in view: 2.4 also carries the **data-review checkpoint** ("which
> games earn their slot"), and that needs analytics running roughly 3 months beforehand. If
> analytics is not on by then, ship 2.4's games and drop the checkpoint rather than delaying
> the release.

---

## 4. 🟡 Which new game, if any?

Ten ideas were researched. **Five were measured; one of those was tested and thrown out for
being too easy.** The other five were reasoned about only.

### Thinking puzzles

| Game | What you do |
|---|---|
| **Still Water** ⭐ | Tanks fill with water to one flat level. Side numbers say how many squares are wet. Work out the levels. |
| **Slant** | Draw `/` or `\` in every square. Corner numbers count the lines touching them. Never make a loop. |
| **Dominosa** | A full domino set is hidden in a grid of numbers. Find where each domino sits. |
| **Nebula** | Split the board so each piece holds one dot and looks identical upside-down. |

### Moving puzzles

| Game | What you do |
|---|---|
| **Tumble** ⭐ | Tip a dice across a grid. Land on each marker showing the face it asks for. |
| **Driftwood** | Slide logs aside to free the marked one (like Rush Hour). |
| **Twin Step** | Two stones both move when you swipe. Land each on its own pad. |
| **Fit** | Drag shapes into a space and fill it exactly. |
| ~~**Fold**~~ | ❌ Rejected — measured, and a player could finish it by just tapping |

### The two picks, and why

**Still Water** — the computer can check *every possible answer* fast, so it can never hand
you an impossible puzzle. Your biggest recurring bug has been exactly that.

> ⚠️ **Needs your decision:** it has numbers down two edges, so **it looks like a Nonogram** —
> which you rejected by name. It does not play like one, and the reason you rejected Nonogram
> (many possible answers) does not apply here. But if it *looks* wrong to you on the home
> screen, say so now — that is much cheaper than after it is built.

**Tumble** — the fastest to build of all ten, and the puzzle-checker runs in 2 milliseconds.
It is the only idea using something the app has never had: tracking a hidden 3-D thing (which
face of the dice is where) while moving in 2-D.

**Or: none.** Both agents recommended not building one yet. That is a real option.

---

## 5. 🟡 The Android home-screen widget — still never seen running

**Nobody has ever seen this widget run.** It has been on the never-device-tested list since
1.8, and it is the one surface where a bug sits *permanently* on someone's home screen rather
than inside an app they can close.

**What it shows:** daily streak · total solved · favourite game · today's puzzle name and
description · bronze / silver / gold / diamond star counts.

**Checked and fine:** diamond stars really are awarded, so that row is not permanently zero.
The update is wrapped in `try/catch`, so a failure cannot crash the app.

**Three things worth knowing** (I read the code properly on 2026-08-23 — full write-up in
`md/remember.md` §14):

1. **It never refreshes itself.** `updatePeriodMillis` is `0`, so Android will *never* wake
   it on a timer. It updates **only when the home screen loads**. If you ever found it showing
   stale numbers, that is why — it is behaving as designed, not broken.
2. **`favorite_game` is dead data.** Dart computes and saves it, but the layout has no view
   for it and the Kotlin provider never reads it. Despite what earlier notes here said, the
   widget does **not** show a favourite game. Either display it or delete the writes.
3. **It shows the *daily-challenge* streak, labelled just "Days"** — while the home screen now
   shows the *play* streak. Two different streaks in the product, and the widget names neither.

**Corrected:** an earlier version of this file said the widget was showing the old
cleared-count. It is not — it is fed from the same `globalLevelClearedCount` as Home and
Trails, so those three already agree.

**Suggested order:** look at it on a real home screen in both themes and both widget sizes
first, then fix what you actually see rather than what the code suggests. Keep
`adb logcat -s StreakWidgetProvider` open while you do — every failure on both sides is
swallowed by a `try/catch`, so that log is your only diagnostic.

---

## 5b. 📌 Deliberately left undone 2026-08-23 — not forgotten

Both were offered and both were declined as "really later on". Recording that here so a future
reader knows these are **decisions, not oversights**, and does not treat them as new findings.

| Job | Where it is written up | Why it can wait |
|---|---|---|
| **Week 30 Grand Finale** — 2 of its 3 puzzles are stand-ins | `NOTES.md`, and §6 below | Nothing crashes; the substitutes are real, playable and correctly tiered. Fixing it shifts that week for anyone mid-cycle. |
| **The widget's dead `favorite_game`** | `md/remember.md` §14, point 2 | It is invisible, not wrong. Dart computes and saves the value; the layout has no view for it and the Kotlin provider never reads it. |

**On `favorite_game` specifically, when you do get to it:** the fix is one of two things —
either add a `TextView` to `widget_layout.xml` and a matching `setTextViewText` in
`StreakWidgetProvider.kt`, **or** delete the two Dart writes (`home_screen.dart:1338` and
`settings_manager.dart:155`). Do not leave it half-done; a key written on one side and unread
on the other is exactly how the rest of that file drifts.

---

## 6. 🟢 Smaller things, whenever

- **Colour Flood, levels 10–34** gives you *zero* spare moves, then hands 3 back at level 35.
  Nobody has checked whether that feels unfair. Play it before changing it.
- **The accent colours fail accessibility contrast** when used as text (22 places).
  Fixing it properly means a second, darker set of colours for text.
- **16 of the daily plan's 90 slots** point at seven games that no longer exist (`wordle`,
  `hangman`, `memory`, `sequence`, `flagle`, `numbermemory`, `wordbuilder` — removed in 2.3's
  cull). They fall back to a deterministic stand-in, so nothing breaks, but 18% of the plan is
  running a substitute. Either re-point those slots at real games or accept it deliberately.

  **Audited all 30 weekly themes on 2026-08-23. Structurally sound, but the spread is wider
  than it first looked** — full plain-words write-up in `NOTES.md`.

  Good: 30 distinct theme names, no duplicates, every one has its own blurb, **no week is
  entirely substituted**, substitution is deterministic per date, prefers the same difficulty
  tier, and never shows the same game twice in one day.

  **The finding that matters — every affected week is 15 to 30, and none is 1 to 14:**

  | | Weeks | Days of the 210-day cycle |
  |---|---|---|
  | 1 of 3 substituted | 15, 16, 18, 19, 20, 22, 25, 26, 27, 28 | 70 |
  | **2 of 3 substituted** | **17 Restriction · 23 Encryption · 30 Grand Finale** | 21 |
  | **Total affected** | **13 of 30** | **91 of 210 (43%)** |

  Each plan entry is a **week**, not a day — the same trio serves all 7 days — so one affected
  week is seven consecutive affected days. I initially reported this as "three days"; it is
  three *weeks* at 2-of-3, plus ten more at 1-of-3.

  **Why the damage is all in the back half:** `kThemeCount` was pinned at 14, so weeks 15–30
  were authored but **unreachable** — never played, never checked. 2.3 unpinned it and doubled
  the rotation to 210 days, which is a real win, but the newly-opened half is precisely the
  untested half, and it refers to seven games deleted in the same release.

  **Nothing is broken.** Every substitute is real, playable and correctly tiered; it just
  carries its own modifier rather than the theme's named one, so the week reads off-theme.

  **The trade before fixing:** those slots were left alone deliberately. The substitute is
  picked from the live pool, so re-pointing them would shift every existing player's daily
  challenge on every future date — someone mid-cycle would see it move under them.

  **My recommendation: fix week 30 only.** It is the finale, it is the most visible, and it is
  small enough to reason about. Leave the other twelve.

---

## How I would order it

1. **Test `1.8.2(61)` on your phone and upload it.** Your users are hitting a crash you fixed
   seven builds ago. Nothing else on this list beats that.
2. **Decide the analytics question** — even if the answer is "never, delete those items". The
   cost is only the delay.
3. **Decide 2.4 vs 2.5.** Weaker now that payments are done, but still worth settling.
4. **Then pick a game** — or don't. Still Water or Tumble, and only after 1–3.

The pattern in this list: **the cheapest decisions are the ones being postponed, and they are
the ones with time attached.** Testing takes an evening. Choosing an analytics answer takes a
minute. Both have been open for months, and both get more expensive the longer they wait.
