# CogniQ — Marketing Plan (low-effort track)

> **Where this file belongs:** `Imp-files-checklist/MARKETING_PLAN.md`
>
> **Relationship to the other docs in this folder:** none, technically. Every other
> file here (`backport.md`, `WHAT_SHIPPED_IN_1.8.md`, `BACKPORT_PARTIAL_FIXES.md`,
> `RESET_PROGRESS_FIXES.md`, `PATTERN_LOCK_FIXES.md`, `VERIFY_SCRIPT.md`) is about
> **code correctness**. This one is about **distribution**. The only hard dependency
> between them is ordering:
>
> **Do not run any of the outreach in this file until the fixed 1.8 bundle is live
> on Play.** Sending press and Reddit traffic to a build with the Colour Link
> RangeError crash, the Grid Path dead modifier, and the progress-reset bug burns
> the one first impression you get. Ship first, market second.
>
> **Play Store listing copy is deliberately NOT in this file.** It is being handled
> separately. Everything below assumes the listing is already rewritten.

**Constraint this plan is written under:** low effort only. No video, no ongoing
content schedule, no daily posting. Every item here is **one-time work** that keeps
paying afterwards. Nothing in this file requires you to become a content creator.

---

## Table of contents

1. [Priority order and time budget](#1-priority-order-and-time-budget)
2. [Reddit](#2-reddit)
3. [Press and YouTuber outreach](#3-press-and-youtuber-outreach)
4. [Play Console — editorial nomination](#4-play-console--editorial-nomination)
5. [Play Console — listing localization](#5-play-console--listing-localization)
6. [Play Console — store listing experiments (A/B)](#6-play-console--store-listing-experiments-ab)
7. [In-app review prompt (code change)](#7-in-app-review-prompt-code-change)
8. [Share-result image (optional code change)](#8-share-result-image-optional-code-change)
9. [What NOT to do](#9-what-not-to-do)
10. [How to tell if any of it worked](#10-how-to-tell-if-any-of-it-worked)
11. [Checklist](#11-checklist)

---

## 1. Priority order and time budget

Do them in this order. Stop whenever you run out of patience — the list is sorted so
that quitting early still leaves you with the highest-value items done.

| # | Item | Your time | One-time? | Payoff |
|---|------|-----------|-----------|--------|
| 0 | Ship fixed 1.8 bundle | (already planned) | — | Prerequisite for everything below |
| 1 | Listing rewrite | *(handled separately)* | Yes | Highest |
| 2 | Localization (§5) | ~15 min | Yes | High — untapped search volume |
| 3 | In-app review prompt (§7) | ~30 min coding | Yes | Compounds forever |
| 4 | Editorial nomination (§4) | ~15 min | Yes | Low odds, very high ceiling |
| 5 | Reddit warm-up + posts (§2) | ~2 h over 2 weeks | Yes | Modest, real |
| 6 | Press emails (§3) | ~1 h | Yes | ~1-in-20 reply, one hit is big |
| 7 | Store listing experiments (§6) | ~20 min | Yes | Real, but needs traffic |
| 8 | Share-result image (§8) | ~2 h coding | Yes | Optional, highest ceiling of the code items |

**Total: about one weekend, spread out.** After that there is no maintenance work.

---

## 2. Reddit

### 2.1 Account status — you are fine

Current state: **~7.4k karma, ~2 years old, all posts and comments deleted.**

- **Automod gates check account age and karma.** Both survived the deletion. You
  clear the minimums on effectively every relevant subreddit (typical thresholds are
  30 days old / 50–100 karma; you are far above).
- **The empty history is a minor negative with human moderators.** A 2-year-old
  account with 7.4k karma and zero visible content reads as "cleaned house," which
  is not disqualifying but is not neutral either.
- **Fix, and it costs nothing:** leave roughly 10 genuine comments over a week or two
  in subs you actually browse, before you post anything about CogniQ. That is the
  entire warm-up. Do not manufacture comments in the target subs specifically — that
  pattern is more obvious than an empty profile.

**Note unrelated to marketing:** deleting Reddit comments removes them from your
profile but does not remove them from third-party archive mirrors. If the reason for
the wipe was privacy rather than tidiness, the wipe is not complete.

### 2.2 Rules — read these before posting, they change

Subreddit self-promotion rules change often and are enforced inconsistently. **Read
the sidebar and the rules page of each sub on the day you post.** Nothing below is a
substitute for that. Getting this wrong costs you the sub permanently.

Two universal rules:

- **The 9:1 guideline.** Reddit's site-wide self-promotion norm: for every
  self-promotional post, you should have roughly nine non-promotional contributions.
  Your warm-up comments count toward this.
- **Never cross-post identical text.** Reddit's spam detection flags repeated
  identical submissions across subs. The drafts below are deliberately different from
  each other. Do not merge them into one.

### 2.3 Verify your post actually went live

This is the single most useful trick in this document.

After you submit, **open the subreddit in a logged-out or incognito window and look
for your post.** If it is not there, it was auto-removed by a filter. Your own
logged-in view will still show it as live — this is how Reddit shadow-removal works,
and most people never realise it happened.

If it was removed: message the mods politely once, asking if the post can be
approved. Do not repost. Reposting after a filter removal is what gets accounts
banned.

### 2.4 Target subs

Ordered by likelihood of a good reception. Spread these over 2–3 weeks — do not post
to all of them in one day.

| Sub | Approx. size | How to post | Notes |
|-----|--------------|-------------|-------|
| r/playmygame | small | Direct post, follow their format | Purpose-built for this. Start here. |
| r/AndroidGaming | very large | **Weekly self-promo thread only** | Direct promo posts are removed. Find the pinned thread. |
| r/AndroidApps | medium | Direct post, usually `[DEV]` flair | Check current flair requirements |
| r/puzzlegames | small | Direct post | Tolerant of relevant indie work. Lead with the puzzle types. |
| r/DestroyMyGame | small | Direct post | Feedback, not promo. Brutal. Genuinely useful. |
| r/SideProject | medium | Direct post | Frame as "solo dev shipped a thing", not as an ad |
| r/IndieDev, r/gamedev | large | Feedback Friday / Screenshot Saturday threads | Devs, not players — low install yield, good feedback |

**Realistic expectation:** a good Reddit post gets you tens to low hundreds of
installs, not thousands. It is worth doing because it is cheap and one-time, not
because it is transformative. Set expectations accordingly so you are not
disappointed.

### 2.5 Paste-ready drafts

Edit the bracketed parts. **Do not paste these verbatim across multiple subs** — each
is written for its own audience.

---

#### Draft A — r/playmygame

> **Title:** CogniQ — [N] logic puzzle types in one app, no subscription, made solo over [N] months
>
> **Body:**
>
> Hi all — I'm a solo dev and I've been building CogniQ for about [N] months. It's a
> collection of logic and brain-training puzzles in one app: Sudoku, Killer Sudoku,
> Kakuro, Hitori, Slitherlink, Masyu, Bridges, plus some original ones like Colour
> Link, Spectrum, Grid Path and Pattern Lock.
>
> The thing I actually want feedback on is the **difficulty curve**. Each game has its
> own level progression, and there's a modifier system that layers extra rules on top
> as you get deeper — timers, walls, monochrome mode, that kind of thing. I've just
> spent a chunk of time rebalancing when those kick in, because they were starting way
> too late and the mid-game was flat.
>
> So: does it feel like it's ramping, or does it plateau? Which game gets boring
> first?
>
> There's also a Zen mode with the modifiers off, and a daily challenge.
>
> Free, Android only for now: [PLAY STORE LINK]
>
> Happy to answer anything about how it's built (Flutter) or how the puzzle
> generation works.

---

#### Draft B — r/AndroidGaming (weekly self-promo thread)

Keep this one short. Self-promo threads are skimmed, not read.

> **CogniQ** — [N] logic puzzle types in one app. Sudoku, Kakuro, Hitori,
> Slitherlink, Bridges, Masyu, plus several original ones.
>
> No subscription, no forced ads between levels. There's a Zen mode if you just want
> to solve without timers, and a daily challenge if you want a streak.
>
> Just pushed an update that rebalances the difficulty curve across every game — the
> mid-game used to flatten out badly and it now ramps properly.
>
> [PLAY STORE LINK]

---

#### Draft C — r/puzzlegames

This audience knows puzzle genres by name. Lead with that, do not explain what Hitori
is, and do not use marketing language — they will bounce off it.

> **Title:** Built an app with [N] different logic puzzle types — looking for
> feedback on the generators
>
> **Body:**
>
> I've been working on a puzzle app that bundles a bunch of the classic pencil
> genres — Sudoku, Killer Sudoku, Kakuro, Hitori, Slitherlink, Masyu, Bridges — along
> with a few I made up.
>
> The part I'd genuinely like this sub's opinion on: **the puzzles are generated, not
> handmade.** I know that's a compromise, and generated puzzles can end up with the
> same feel level after level even when the difficulty number goes up. I've been
> working on variety specifically.
>
> If anyone here plays a few levels of the genres you know well, I'd like to know
> whether they hold up as *proper* puzzles — unique solution, solvable by logic
> without guessing — or whether the generator is producing something that only looks
> like the real thing.
>
> Free on Android: [PLAY STORE LINK]

---

#### Draft D — r/DestroyMyGame

The point of this sub is that you get told what is wrong. Post here only if you
actually want that. Do not get defensive in the comments — it is the fastest way to
lose the thread.

> **Title:** Puzzle collection app, [N] years of solo work — tell me why people bounce
>
> **Body:**
>
> CogniQ: a collection of logic puzzles for Android. I've been at it a while and it's
> live, but retention is not where I want it.
>
> Destroy it. Specifically I want to know:
>
> - Does the first 60 seconds make it obvious what the app is?
> - Is the game-select screen overwhelming? There are a lot of games and I've never
>   been sure that's a strength.
> - Does the difficulty ramp feel earned or arbitrary?
>
> [PLAY STORE LINK]
>
> I'll take all of it, no arguing in the comments.

---

#### Draft E — r/SideProject

Here the story is the product. Nobody in this sub cares about Kakuro; they care about
the shipping.

> **Title:** Shipped a puzzle app solo — [N] puzzle types, [N] levels, [N]k downloads
>
> **Body:**
>
> Flutter, Android, one person. CogniQ is a collection of logic puzzle games —
> Sudoku, Kakuro, Slitherlink, Hitori, Bridges and a handful of original ones — with a
> shared progression system layered across all of them.
>
> The thing that took the longest wasn't the puzzles, it was the **modifier system**:
> extra rules that get layered onto later levels of every game to keep them from going
> stale. Getting that to compose correctly across [N] different games without breaking
> any individual one was most of the work, and I only recently found that in several
> games the modifiers weren't firing at all.
>
> Free, no subscription: [PLAY STORE LINK]
>
> Happy to talk about the architecture if anyone's building something similar in
> Flutter.

---

## 3. Press and YouTuber outreach

### 3.1 Expectations

**Roughly 1 in 20 will reply.** That is a normal, healthy rate — it is not a sign that
your app is bad. One pickup by a mid-size Android gaming channel or site is worth
more than everything else in this document combined, which is why it is worth an hour
despite the rejection rate.

Send them all in one sitting, then forget about it. Do not follow up more than once,
and not sooner than two weeks.

### 3.2 Where to send

**Do not guess at email addresses.** Every outlet below has a public tips, contact,
or submission page — use it. A guessed address either bounces or lands in a dead
inbox, and some outlets treat guessed-address mail as spam.

Sites worth contacting:

- **Droid Gamers** — Android games specifically. Probably your single best fit.
- **Pocket Gamer** — has a formal submission route for indie devs.
- **Android Police** — has a public tips route. Large audience.
- **Android Authority** — same. Covers apps as well as hardware.
- **TouchArcade** — mostly iOS, but covers puzzle games seriously. Low priority for
  you until you have an iOS build.
- **IndieDB** — free to list, near-zero effort, small return.

YouTube channels: search YouTube for **"best new android games this week"** and sort
by upload date. Take the channels that have posted within the last month and have
somewhere between 10k and 500k subscribers. Under 10k will not move installs; over
500k will not answer you. Use the business email on their channel's About tab —
that one is public and intended for exactly this.

**Aim for 15 contacts total.** That is enough to expect one reply and few enough to
do in one sitting.

### 3.3 Email template

Subject lines matter more than the body here. Keep it factual — anything that reads
like a press release gets deleted.

> **Subject:** CogniQ — [N] logic puzzle types in one Android app, solo dev
>
> Hi [NAME / team],
>
> I'm a solo developer and I've just released a significant update to CogniQ, a logic
> puzzle collection for Android.
>
> It bundles [N] puzzle types — Sudoku, Killer Sudoku, Kakuro, Hitori, Slitherlink,
> Masyu, Bridges — plus several original ones, with a shared progression system and a
> modifier layer that adds new rules as you go deeper. There's a Zen mode with all
> that turned off, and a daily challenge.
>
> The angle that might interest you: **no subscription.** The category is dominated by
> $60/year apps, and this one is free with optional one-off purchases.
>
> Play Store: [LINK]
>
> Happy to send a promo code, a press kit, or an APK if that's useful. I can also
> answer anything about the puzzle generation — it's all procedural, which was the
> hard part.
>
> Thanks for your time,
> Mayank
> [CONTACT EMAIL]

**Rules for this email:**

- Send it **individually** to each recipient. Never BCC a list — it is visible and it
  reads as a mass mail.
- **No attachments.** Attachments from unknown senders get filtered. Link instead.
- Keep it under 200 words. Yours is at about 160.
- Put the Play Store link in the body as a plain URL, not hidden behind link text.

### 3.4 Press kit (optional, 20 minutes)

If you want to raise the reply rate slightly, put a folder on Google Drive with:

- 6–8 screenshots at full resolution
- The app icon as a PNG with transparency
- A 100-word and a 300-word description
- Your name and contact email
- The Play Store link

Then add one line to the email: *"Press kit with screenshots here: [LINK]."*
Set the Drive folder to "anyone with the link can view."

---

## 4. Play Console — editorial nomination

**Time: 15 minutes. Do it once. Low odds, but the ceiling is enormous — an editorial
feature on Play is worth more than every other item in this file put together.**

### Where

Play Console → **Grow** (or **Grow users**) → **Store presence** → look for
**Editorial / Featuring / Nominate app**. The exact menu label moves around between
Console redesigns; if you cannot find it, search "nominate" in the Console's own
search bar.

### What they are looking for

Google's editorial team selects for: recent meaningful updates, good ratings, strong
listing assets, technical quality (low ANR and crash rates), and a clear hook.
**Your Android vitals matter here** — check Play Console → **Quality** → **Android
vitals** before nominating. If your crash rate is above the bad-behaviour threshold,
fix that first, because a nomination with bad vitals is a wasted shot.

### What to write

Keep it factual and lead with what is distinctive:

> CogniQ is a collection of [N] logic puzzle types in a single app — classic pencil
> puzzles like Sudoku, Kakuro, Slitherlink, Hitori and Bridges alongside original
> designs. A shared progression system layers additional rules onto later levels of
> every game, so the difficulty comes from new constraints rather than bigger grids.
>
> It is built by one developer, is free with no subscription in a category dominated
> by subscription apps, and includes a Zen mode with all timers and modifiers
> disabled for players who want to solve without pressure.
>
> The most recent update rebalanced the difficulty progression across the entire
> roster and added [BRIEFLY: what's new in the fixed 1.8].

### Timing

Nominate **after** the fixed bundle is live and has had a week to accumulate clean
vitals. Not before.

---

## 5. Play Console — listing localization

**Time: about 15 minutes. This is the best effort-to-return item in this file.**

### Why

Play Store search is per-language. An English-only listing is invisible to a user
searching in Portuguese. In most non-English markets the puzzle category is far less
saturated, so you rank higher for the same content. Installs from these markets cost
you nothing and require no support work, because puzzle games are largely
language-independent in play.

### How

Play Console → **Grow** → **Store presence** → **Store listings** → **Manage
translations** → **Add your own translations** or **Use Google Translate**.

Google's auto-translate is free and applied instantly. It is imperfect but it is
enormously better than not being listed at all.

### Which languages

Start with these, chosen for install volume relative to category competition:

1. **Hindi** — large market, you likely have some organic base already
2. **Portuguese (Brazil)** — very high mobile game volume
3. **Spanish (Latin America / Spain)**
4. **Indonesian** — huge Android base, low category saturation
5. **Russian**
6. **German**
7. **French**
8. **Turkish**

### One caveat that matters

**Auto-translation will mangle puzzle genre names.** "Bridges", "Hitori" and
"Slitherlink" are proper nouns of the genre and are usually left in English even in
localized puzzle apps. After auto-translating, spot-check that the genre names
survived. If a genre name got translated into a literal word, edit that language's
listing by hand to put the English name back — otherwise you lose the exact search
term people actually use.

### What NOT to localize

Do not translate the app **name**. `CogniQ` is a brand; keep it identical everywhere
so that people who hear about it can find it.

---

## 6. Play Console — store listing experiments (A/B)

**Time: 20 minutes setup, then it runs by itself.**

### Where

Play Console → **Grow** → **Store presence** → **Store listing experiments**.

### What to test

Test **one thing at a time**. Testing two changes at once tells you nothing about
which one worked.

Run them in this order, each for its full duration before starting the next:

1. **Icon** — usually the largest single effect on conversion. Test your current icon
   against one alternative.
2. **First two screenshots** — the second-largest effect. Almost nobody scrolls past
   screenshot two.
3. **Short description** — smaller effect on conversion, but it also feeds search
   ranking.

### The caveat you need to know before you start

**Experiments need install volume to reach statistical significance.** If your daily
install count is low, an experiment can run for weeks and return "no clear winner,"
which is not a failure of your variant — it is simply insufficient data.

If that happens, do not conclude your current asset is fine. Just make the change you
believe in and move on. At low volume, judgement beats an underpowered test.

### Do not

Do not run an experiment at the same time as a press pickup or a Reddit post. The
traffic spike is not representative of your normal audience and it will skew the
result.

---

## 7. In-app review prompt (code change)

**Time: ~30 minutes. This is the highest-value code change in this document.**

### Why it matters

Rating count and average rating feed **both** Play search ranking **and** the
conversion rate of everyone who reaches your listing. It is a compounding loop: more
ratings → better rank → more listing views → more installs → more ratings. Most solo
apps never wire this up and leave a large amount of growth unclaimed.

### The package

`in_app_review` on pub.dev — the standard Flutter wrapper around the Google Play
In-App Review API. Add it to `pubspec.yaml`.

**Check the current version on pub.dev before adding.** Do not copy a version number
from this document.

### Critical constraints of the Play API

Read these before writing the code, because they determine the design:

- **Google decides whether the dialog actually appears.** `requestReview()` may
  silently do nothing. There is no callback telling you whether it showed, and no way
  to detect it. Your code must not assume it worked.
- **There is a quota.** Google limits how often a given user can be shown the prompt
  (a small number of times per year). Calling it more often does not help and wastes
  your quota.
- **You must not incentivise it.** Offering hints, points, or anything else in
  exchange for a rating violates Play policy. Do not do this.
- **You must not pre-prompt.** Asking "do you like the app?" and only showing the
  review sheet to people who say yes is against Google's guidance for this API.
- **It does not work in debug or sideloaded builds.** You cannot meaningfully test it
  outside an internal testing track from Play. Do not conclude it is broken because
  nothing happened on your test APK.

### Where to fire it

**Not on app launch.** Launch is the worst possible moment — the user has not yet
experienced anything worth rating.

Fire it at a **moment of earned satisfaction**, and only once the user has enough
history to have an opinion:

- Just after a level-completion celebration, **not during it** — let the win
  animation finish first
- Only if total levels completed across all games is above a threshold (suggest 20)
- Only if the user has opened the app on at least 3 separate days
- Never within 90 days of the last time you asked
- Never during a daily challenge, and never after a failure or a timeout

### Implementation sketch

Add two keys to `prefs_keys` in the existing style:

```dart
// Marketing / review prompt
static const String reviewPromptLastShown = 'review_prompt_last_shown';
static const String distinctDaysOpened    = 'distinct_days_opened';
```

Then a small gate — put it wherever the other cross-game progress helpers live, not
inside an individual game screen:

```dart
/// Asks Play to show the in-app review sheet, if now is a good moment.
///
/// Google decides whether the sheet actually appears and there is no way to
/// know whether it did, so this is fire-and-forget. Never call it on launch,
/// on a loss, or during a daily challenge.
// COGNIQ-FIX:review-prompt
static Future<void> maybeRequestReview() async {
  final prefs = await SharedPreferences.getInstance();

  // Enough experience to have an opinion?
  final levelsDone = /* existing total-levels-completed lookup */;
  if (levelsDone < 20) return;

  final daysOpened = prefs.getInt(PrefsKeys.distinctDaysOpened) ?? 0;
  if (daysOpened < 3) return;

  // Respect Google's quota - don't burn it more than a few times a year.
  final last = prefs.getInt(PrefsKeys.reviewPromptLastShown) ?? 0;
  final ninetyDays = const Duration(days: 90).inMilliseconds;
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  if (last != 0 && nowMs - last < ninetyDays) return;

  final review = InAppReview.instance;
  if (!await review.isAvailable()) return;

  await prefs.setInt(PrefsKeys.reviewPromptLastShown, nowMs);
  await review.requestReview();
}
```

And increment `distinctDaysOpened` once per calendar day at startup, storing the last
recorded date alongside it.

### Marker comment

Follow the project convention so the verify script and future backports can find it:

```dart
// COGNIQ-FIX:review-prompt
```

### Backporting

This is a **new feature**, not a bug fix, so it is not part of the A–F backport set
in `backport.md`. If you want it in bundles 62–68, add it as a new lettered entry in
that file so the procedure stays consistent. Do not smuggle it in as an unlabelled
change.

---

## 8. Share-result image (optional code change)

**Time: ~2 hours. Optional. Highest ceiling of any code item here, but it is the only
thing in this document that is not low-effort.** Skip it if you want to stay strictly
within the low-effort budget; come back to it if the rest of the plan works.

### Why

This is the Wordle mechanic. A shareable result image turns each player into a
distribution channel with no cost to you and no ongoing work after it is built. Your
**daily challenge** is already the right shape for it: one shared puzzle per day, one
result, an obvious thing to compare with other people.

### What to build

On daily challenge completion, offer a **Share** button that generates an image
containing:

- The date and the puzzle type
- The player's time or move count
- Their current streak
- A small, abstract render of the solved board — **stylised, not the actual
  solution**
- `CogniQ` and a short link

Use Flutter's `RepaintBoundary` + `toImage()` to rasterise a widget, then hand it to
the platform share sheet.

### The one rule that makes or breaks it

**Never leak the solution.** If the shared image lets someone else solve today's
puzzle without playing, the mechanic collapses — nobody plays, they just read their
friend's screenshot. Wordle's coloured squares work precisely because they encode
performance without encoding the answer. Do the same: render a shape or colour
pattern derived from the result, not from the board state.

### Also

- Make sharing entirely optional and never automatic.
- Do not attach anything identifying to the image.
- Make sure the image is legible after a messaging app compresses it — high contrast,
  large text, no thin strokes.

---

## 9. What NOT to do

Things that look like marketing, cost real time or money, and do not work at your
stage:

- **Paid ads right now.** Google App Campaigns and Meta ads both need meaningful
  budget and conversion tracking to escape their learning phase. More importantly:
  if retention is weak, paid installs are money poured into a leaky bucket. Fix
  retention first, then consider ads. Reddit Ads is the cheapest place to start
  *when* you get there.
- **Buying installs or reviews.** Detected, and it gets apps removed from Play.
  Not a grey area.
- **Product Hunt.** Wrong audience — it is a web/SaaS/dev crowd, and mobile puzzle
  games do poorly there. Costs an afternoon for very little.
- **Posting the same text to ten subreddits.** Reddit's spam detection catches this
  and you lose the account and the subs.
- **Asking friends and family for 5-star reviews.** Play detects rating clusters from
  related devices and IPs. The downside risk is not worth twenty ratings.
- **Building a website.** Your Play listing is your website. Do not spend a weekend
  on a landing page nobody will visit.
- **Social media accounts for the app.** An abandoned Twitter/Instagram with 40
  followers looks worse than no account. You have already ruled out video, and a
  text-only games account has no route to growth. Skip it.
- **A Discord server.** Same reasoning — an empty server is a negative signal, and
  staffing an active one is not low-effort.

---

## 10. How to tell if any of it worked

Do this **before** you start, so you have a baseline to compare against.

### Set a baseline

Play Console → **Statistics**. Record today's numbers for:

- Daily installs (7-day average)
- Store listing visitors and **conversion rate** (visitors → installs)
- Rating count and average
- Day-1 and Day-7 retention

Write them into §11 below with today's date. Without a baseline you will not be able
to tell a real change from normal week-to-week noise.

### What each item should move

| Item | Metric it should move | How soon |
|------|----------------------|----------|
| Listing rewrite | Conversion rate, then installs | 1–2 weeks |
| Localization | Installs from new countries | 2–4 weeks |
| Review prompt | Rating count | Immediately, then compounds |
| Reddit / press | A visible spike in daily installs | Same day, decays in ~3 days |
| Editorial feature | An unmissable step change | If it happens, you will know |

### Acquisition reports

Play Console → **Grow** → **Acquisition reports** → **Store performance** breaks
installs down by traffic source — Play Store search vs. third-party referrers. This
is how you separate "the listing rewrite worked" from "a Reddit post drove a spike."

### Attribute your links

Use Play's URL builder to tag outbound links so referrals show up separately: append a
campaign parameter to the store URL you put in each Reddit post and press email.
Otherwise everything lands in one undifferentiated bucket and you cannot tell which
channel produced anything.

### Give it time

Two to four weeks before drawing conclusions. Daily install counts are noisy at low
volume and a single good or bad day means nothing.

---

## 11. Checklist

**Baseline recorded on: ____________ (date)**

- Daily installs (7-day avg): ______
- Listing conversion rate: ______
- Rating count / average: ______ / ______
- Day-1 / Day-7 retention: ______ / ______

**Prerequisite**

- [ ] Fixed 1.8 bundle live on Play, vitals clean for at least a week

**Play Console (about an hour total)**

- [ ] Listing rewritten *(tracked separately, not in this file)*
- [ ] Auto-translated into 8 languages (§5)
- [ ] Genre names spot-checked in each translation (§5)
- [ ] App name left untranslated (§5)
- [ ] Android vitals checked (§4)
- [ ] Editorial nomination submitted (§4)
- [ ] Icon A/B experiment started (§6)

**Code (about 30 minutes, plus optional 2 hours)**

- [ ] `in_app_review` added, current version checked on pub.dev (§7)
- [ ] Review prompt gated on 20 levels / 3 days / 90-day cooldown (§7)
- [ ] `// COGNIQ-FIX:review-prompt` marker added (§7)
- [ ] New lettered entry added to `backport.md` for bundles 62–68 (§7)
- [ ] *(Optional)* Daily challenge share image (§8)

**Reddit (2 hours over 2 weeks)**

- [ ] ~10 genuine comments posted as warm-up (§2.1)
- [ ] Rules read on the day of posting, per sub (§2.2)
- [ ] r/playmygame — Draft A
- [ ] r/AndroidGaming — Draft B, in the weekly self-promo thread
- [ ] r/puzzlegames — Draft C
- [ ] r/DestroyMyGame — Draft D
- [ ] r/SideProject — Draft E
- [ ] Each post verified live in an incognito window (§2.3)

**Press (1 hour)**

- [ ] *(Optional)* Press kit folder on Drive, link-viewable (§3.4)
- [ ] 15 contacts identified via their public tips/contact pages (§3.2)
- [ ] Emails sent individually, no BCC, no attachments (§3.3)
- [ ] Diary note: one follow-up, no sooner than two weeks

**Review**

- [ ] Metrics re-checked 2–4 weeks after baseline
- [ ] Acquisition report reviewed to attribute the change (§10)
