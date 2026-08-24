# New swipe trails — ideas and star-based unlocking

*Written 2026-08-23. Design proposal, nothing built. Read `md/DECISIONS.md` first — this is a
"when you want it" item, not a queued one.*

---

## ✅ DECIDED 2026-08-23 — the shipping plan

**Unlock model: THRESHOLD, not spend.** Reaching the count unlocks the trail permanently; the
stars stay. Nothing a player earned ever goes down — which also means the daily screen and the
home widget keep showing rising numbers, with no "why did my total drop?" moment.

**Conversion ratio: 7 : 1 at every step.** 7 bronze = 1 silver = 1/7 gold = 1/49 diamond.
Every star trail is unlockable **either** way, so a steady player and a perfect player both
have a route.

**Availability: cumulative.** A trail introduced in one release stays earnable in every later
one. Nobody loses access by updating.

| Release | Trail | Unlock — **any ONE** of these routes |
|---|---|---|
| **1.8** | 🌫️ **Morning Mist** | 7 bronze · 1 silver · **400 clears** |
| **1.8** | 🌊 **Tide Line** | 7 silver · 1 gold · **700 clears** |
| **1.9** | 🌌 **Aurora Veil** | 1 diamond · 7 gold · **1,000 clears** |
| **2.0** | ☄️ **Starfall** | 3 diamond · 21 gold · **1,500 clears** |
| **2.1** | 🌺 **Petal Fall** | 5 diamond · 35 gold · **2,200 clears** |
| **2.2** | ⭐ **Constellation** | 7 diamond · 49 gold · **3,000 clears** |
| **2.3** | 🌑 **Eclipse** | 10 diamond · 70 gold · **4,000 clears** — the final trophy |

**One trail per release from 2.1 onward** (owner decision). Seven star trails in total.

### The clears route exists so daily-only is not the only path
Added 2026-08-23 after the owner spotted the gap: a player who works through Kakuro and never
opens a daily challenge would otherwise earn **no star trail ever**. The third route uses
`PrefsKeys.globalLevelClearedCount` — the true lifetime tally covering Challenge *and* Zen —
so any kind of player has a road in.

The numbers sit deliberately far above the existing clear-based trails (accent 30, sparkle
100, pastel 250): the clears route is a long grind, not a shortcut. It does not break the
"never purchasable" rule either — grinding is not paying.

> ### ⚠️ What a diamond actually costs — check this before adding more diamond tiers
> A diamond is **7 consecutive days of perfect play** (all three challenges, every day), and
> `daily_challenge_manager.dart:1479-1481` resets the run to 1 on **any** gap. So 3 diamond is
> not "21 perfect days" — it is **three unbroken perfect weeks**, and one missed day restarts
> the week in progress. Realistically that is months, not three weeks.
>
> This is why 2.0 was set at 3 rather than the originally suggested 5. Keep it in mind before
> any future release asks for more diamonds.

**Trail Collector becomes tiered — I, II, III.** Star trails DO count, but the achievement
splits so the early tiers stay reachable:

| Achievement | Requires |
|---|---|
| **Trail Collector I** | own the buyable/earnable trails (accent, sparkle, pastel) |
| **Trail Collector II** | + the bronze/silver tier star trails (Morning Mist, Tide Line) |
| **Trail Collector III** | + the gold/diamond tier (Aurora Veil, Starfall) — the app's hardest |

---

## What exists today

**8 trails**, unlocked two ways only — Challenge clears, or points.

| Trail | Emoji | Unlock now | Points price |
|---|---|---|---|
| No Trail | 🚫 | free | — |
| Game Accent | 🎯 | 30 clears | 300 |
| Sparkle Stars | ✨ | 100 clears | 1,500 |
| Pastel Glow | 🌸 | 250 clears | 4,000 |
| Neon Glow | ⚡ | points only | 9,000 |
| Rainbow Neon | 🌈 | points only | 16,000 |
| Fire Trail | 🔥 | points only | 25,000 |
| Zen Ripple | 🌿 | 50 **Zen** clears | not buyable |

Rules live in `lib/utils/trail_catalog.dart` — one source of truth, deliberately, after the
trails screen and the overlay drifted apart and made bought trails look locked.

## The gap this proposal fills

**Daily-challenge stars currently buy nothing.** You earn bronze, silver, gold and diamond
(`daily_challenge_manager.dart` — one star per day, upgrading bronze → silver → gold as you
finish 1, 2 or 3 challenges; diamond at `:1491`), they are counted, displayed on the daily
screen and pushed to the home widget — and then they **do nothing at all**.

Meanwhile every trail is bought with points or ground out with raw clear counts, so the
reward for *consistency* and the reward for *volume* are the same currency. Star-locked trails
fix both: stars get a purpose, and the trails they buy are ones grinding cannot reach.

> **Design rule for this whole file:** a star-locked trail must be **star-locked only** — never
> also purchasable. The moment one has a points price, the stars stop meaning anything, and
> you are back to a single currency with extra steps.

---

## The proposed trails

Ten ideas. Each names the star it costs, why that star, and what it looks like. Visual style
follows the existing set: soft and calm at the low end, dramatic at the top.

### 🥉 Bronze — "you showed up"
Bronze accrues fastest (one challenge finished on any day). Cheap, encouraging, low drama.

**1. Morning Mist** 🌫️ — **15 bronze**
A pale grey-blue vapour that widens and thins as it fades, like breath on cold glass. The
quietest trail in the set; the natural first thing a new player earns that is not the accent.
`previewColors: [0xFFCFD8DC, 0xFFECEFF1, 0xFFB0BEC5]`

**2. Ink Wash** 🖋️ — **40 bronze**
A single tapering brush stroke — thick where the finger pressed, dry-brushed at the tail. Uses
one ink tone, so it reads as calligraphy rather than a glow effect.
`previewColors: [0xFF37474F, 0xFF546E7A, 0xFF90A4AE]`

### 🥈 Silver — "you came back"
Silver needs two challenges in a day: a real session, not a tap-in.

**3. Tide Line** 🌊 — **25 silver**
A shallow wave that runs along the swipe and leaves a foam edge dissolving behind it. Two-tone
with a bright leading rim.
`previewColors: [0xFF4FC3F7, 0xFF81D4FA, 0xFFE1F5FE]`

**4. Petal Fall** 🌺 — **60 silver**
Small blossom shapes that detach from the trail and drift *sideways* as they sink — the only
trail whose particles do not follow the finger. Sibling to Sparkle Stars, gentler.
`previewColors: [0xFFF8BBD0, 0xFFF48FB1, 0xFFFCE4EC]`

### 🥇 Gold — "you finished the day"
Gold means all three challenges. It is the honest measure of a committed player.

**5. Aurora Veil** 🌌 — **20 gold**
Slow vertical curtains of green-to-violet that ripple perpendicular to the swipe. The first
trail that looks *expensive*.
`previewColors: [0xFF00E5A0, 0xFF00B0FF, 0xFF7C4DFF]`

**6. Constellation** ⭐ — **45 gold**
Points of light left at intervals, joined by thin lines a beat later — the trail draws itself
a star map as you go, then fades from the oldest star.
`previewColors: [0xFFFFF9C4, 0xFFFFFFFF, 0xFF9FA8DA]`

**7. Molten Gold** 🏆 — **80 gold**
Liquid metal with a bright core and a cooling dark-amber crust that cracks as it fades. The
"I finished a hundred days" flex.
`previewColors: [0xFFFFD700, 0xFFFFA000, 0xFF6D4C41]`

### 💎 Diamond — the genuinely rare ones
Diamond is the scarcest star. These should be **the only trails in the app that cannot be
bought, ground, or rushed** — the whole point is that money and volume do not reach them.

**8. Prism Cut** 💠 — **10 diamond**
Colourless until it moves: the trail refracts into split spectral edges at the turns, white in
the straights. Rewards *drawing* rather than swiping.
`previewColors: [0xFFFFFFFF, 0xFFB3E5FC, 0xFFF8BBD0]`

**9. Starfall** ☄️ — **25 diamond**
A single bright head with a long thin tail and a faint after-image that lingers about a second
longer than any other trail. Reads as one comet rather than particles.
`previewColors: [0xFFFFFFFF, 0xFF80D8FF, 0xFF1A237E]`

**10. Eclipse** 🌑 — **50 diamond**
The rarest, and the only *dark* trail: the swipe darkens the board behind it with a thin
corona at the edge, then releases. Inverted where everything else is additive — it should look
like nothing else in the app.
`previewColors: [0xFF000000, 0xFF212121, 0xFFFFB300]`

---

## Suggested implementation

### 1. `TrailCatalog` gains a star requirement
Today it answers two questions — `requiredClears(id)` and `price(id)`. Add a third:

```dart
enum StarTier { bronze, silver, gold, diamond }

class StarCost {
  final StarTier tier;
  final int count;
  const StarCost(this.tier, this.count);
}

/// Null when a trail is not star-locked.
static StarCost? starCost(String styleId) { ... }
```

Keep it in the same file for the reason already written there: the screen and the overlay
**must** agree, and they drifted once before.

### 2. Star-locked trails return `pointsOnly` for price AND clears
So the existing "can I afford it" and "have I ground enough" paths naturally say no, and only
the new star check can unlock them. That way the rule holds by construction rather than by
everyone remembering it.

### 3. Stars are spent, not just held — decide which
Two models, and this is a **product decision**:

| Model | Effect |
|---|---|
| **Threshold** (recommended) | Reaching 20 gold unlocks Aurora Veil permanently; the stars stay. Simple, never punishes the player for unlocking, and matches how clears already work. |
| **Spend** | Unlocking deducts the stars. Creates real choices between trails, but means a displayed total that drops — and the daily screen and widget both show these totals, so a falling number needs explaining. |

The threshold model also avoids touching `syncStarsToWidget` behaviour at all.

### 4. The trails screen needs a third card state
It currently shows *earned by clears* or *buy for N points*. Star trails need
**"18 / 20 gold stars"** with the tier's own colour, and no Buy button. That absence is the
message.

### 5. Achievement wording
`achievement_manager.dart` has *"Own all 6 swipe trail styles"* while the home card says
"N / 7 owned" — already inconsistent (see the audit). **Fix that first**, then decide whether
Trail Collector should count the star trails at all. Recommendation: **it should not** — an
achievement that needs 50 diamond stars is not a collection goal, it is a second job.

---

## Honest risks

**1. Ten new trails is a lot of `CustomPainter` work.** Each one is a distinct paint routine,
and three of these (Constellation's delayed line-joins, Prism Cut's turn-detection, Eclipse's
subtractive blend) are meaningfully harder than anything in the current set. **Ship two or
three, not ten.** Aurora Veil, Tide Line and Starfall are the strongest per unit of effort.

**2. Performance.** `remember.md` §E covers this: trails render every frame during a drag.
Eclipse's darkening and Prism Cut's refraction both risk a second pass over the same pixels.
Measure on a real device before committing — this is the one part of the app where a pretty
idea can cost frames in *every* game.

**3. Nobody has confirmed the stars are earnable at the rate assumed here.** The numbers above
(15 bronze, 20 gold, 10 diamond) are guesses. **Before setting a single threshold, check what
a real player actually accumulates in a month** — the daily system gives at most one star per
day, so 50 diamond is well over a year of near-perfect play. That may be exactly right for the
rarest trail, or absurd. Measure first; this project has been bitten repeatedly by numbers
that were reasoned rather than measured (`remember.md` §9c).

**4. It only rewards daily-challenge players.** Someone who plays fifty levels of Kakuro and
never touches a daily earns no stars at all. That is arguably the point — a currency for a
behaviour you want — but it does mean a whole class of player watches trails they can never
reach. Worth deciding deliberately rather than by accident.
