# Achievements & Swipe Trails — Plan & Fixes

> **Audience:** a reading agent (Gemini) to understand the current systems, and a planning/coding agent (Opus)
> to implement the changes below.
> **Scope:** (1) the achievements catalogue (names/thresholds/rewards), (2) the swipe-trail unlock ladder — with a
> new levels-cleared progression **and** a cost-based alternative, (3) making the achievement & trail toasts
> **tap-to-claim**, and (4) reconciling the two conflicting trail-unlock mechanisms into one source of truth.

Relevant files:
- `lib/utils/achievement_manager.dart` — 20 achievements + unlock/claim logic
- `lib/screens/achievements_screen.dart` — achievements UI (claim)
- `lib/screens/trails_screen.dart` — trail catalogue + `getRequiredClears` gate + claim/select
- `lib/widgets/achievement_toast.dart` — "Achievement Unlocked!" toast (auto-dismiss)
- `lib/widgets/trail_unlock_toast.dart` — "Swipe Trail Unlocked!" toast (auto-dismiss)
- `lib/widgets/swipe_trail_overlay.dart` — renders the active trail
- `lib/utils/prefs_keys.dart` — SharedPreferences keys

---

## 1. Current state (and the core problem)

There are **two independent, conflicting ways a trail unlocks:**

1. **Achievement rewards** — some achievements grant a `rewardTrailStyle` on claim:
   `centurion` (100 total clears) → `accent`, `master` (50 levels in one game) → `pastel`,
   `obsessed` (100 levels in one game) → `rainbow`, `monthly_grind` (30-day streak) → `sparkle`.
2. **Trails screen clears-gate** — `trails_screen.dart:getRequiredClears` gates the *same* trails purely by
   **total levels cleared**: accent 30, pastel 60, sparkle 120, neon_glow 200, rainbow 250, fire 300.

→ These disagree (e.g. a player could get `rainbow` from the `obsessed` achievement at 100 levels-in-one-game,
while the Trails screen says rainbow needs 250 total clears). **Decision in §4: trails unlock in ONE place
(the Trails screen), driven by the new ladder; achievements stop granting trails.**

Also: **both toasts are currently non-interactive** — they slide in, wait, and auto-dismiss. The user wants them
**tappable → open the relevant screen to claim** (§5).

---

## 2. Achievements catalogue (current — cleaned & documented)

20 achievements across 5 categories. Names are mostly good; issues to fix are flagged **⚠️**.

| id | Name | Icon | Category | Condition | Rewards |
|----|------|------|----------|-----------|---------|
| first_step | First Step | ⚡ | milestone | 1 total level | 50 pts |
| getting_started | Getting Started | ⭐ | milestone | 10 total | 150 pts |
| half_century | Half Century | 🎖️ | milestone | 50 total | 250 pts |
| centurion | Centurion | 🏆 | milestone | 100 total | 500 pts ~~+ accent trail~~ |
| dedication | Dedication | 🔥 | milestone | 250 total | 750 pts |
| grandmaster | Grandmaster | 👑 | milestone | 500 total | 1000 pts + title "Grandmaster" |
| legend | Legend | ✨ | milestone | 1000 total | 2500 pts + title "Legend" |
| curious_mind | Curious Mind | 🧭 | exploration | play 3 games | 100 pts |
| well_rounded | Well Rounded | 🎯 | exploration | play 5 games | 200 pts |
| jack_of_all | Jack of All Trades | ⚙️ | exploration | play 10 games | 400 pts |
| completionist | Completionist | 🎒 | exploration | play all active games | 750 pts + title "Completionist" |
| apprentice | Apprentice | ⭐ | mastery | 10 levels in one game | 150 pts + title |
| expert | Expert | ✨ | mastery | 25 in one game | 250 pts + title |
| master | Master | 💎 | mastery | 50 in one game | 500 pts ~~+ pastel trail~~ + title |
| obsessed | Obsessed | ☄️ | mastery | 100 in one game | 1000 pts ~~+ rainbow trail~~ + title |
| consistent | Consistent | 📅 | streak | 3-day streak | 100 pts |
| weekly_warrior | Weekly Warrior | ⚔️ | streak | 7-day streak | 250 pts + title |
| monthly_grind | Monthly Grind | 💎 | streak | 30-day streak | 750 pts ~~+ sparkle trail~~ ⚠️ title |
| shuffle_master | Shuffle Master | 🔀 | special | 10 Shuffle-Mode clears | 250 pts + title |
| perfect_memory | Perfect Memory | 🐒 | special | reach Level 15 in Chimp Test | 250 pts |

### ⚠️ Fixes to make
- **`completionist`** — description says *"Play all 15 active games"* but the code checks `playedGamesCount >= 12`.
  Make the description and threshold agree with the real active-game count (`kAllGames.where((g)=>!g.isStashed).length`).
  Ideally compute the threshold from that count rather than hardcoding `12`.
- **`monthly_grind`** — name is "Monthly Grind" but its `rewardTitle` is `"Zen Master"` (mismatch). Pick one
  (suggest title "Zen Master" is fine, but make the toast/label consistent). It also currently grants the sparkle
  trail — remove per §4.
- **`master` / `obsessed` / `centurion`** — strip `rewardTrailStyle` (trails move to the clears ladder, §4).
  Keep their point/title rewards.
- **`perfect_memory`** — "Reach Level 15 in Chimp Test" assumes the old Chimp leveling. Under the Chimp redesign
  (visible numbers + running clock, sawtooth count — see `difficulty_scaling_part_2_fix.md` §5.3), confirm "Level 15"
  still maps to a meaningful milestone, or re-word to "Reach a count of 15 in Chimp Test".

### 2.1 New achievements to ADD

Ten new achievements, chosen to (a) extend the ladders past their current caps, (b) reward the new scaling
mechanics (endgame/rotation, hard timers, big grids), and (c) add skill + cosmetic + retention hooks.

| id | Name | Icon | Category | Condition | Rewards | Reads / needs |
|----|------|------|----------|-----------|---------|---------------|
| marathon | Marathon | 🏔️ | milestone | 2,500 total levels cleared | 5000 pts + title "Ascendant" | `globalLevelClearedCount` (exists) |
| into_the_deep | Into the Deep | 🌀 | mastery | Reach level 90+ in any game (enter rotation/endgame) | 750 pts + title "Deep Diver" | `maxLevelReached >= 90` (already computed) |
| big_board | Big Board | 🔲 | special | Clear a max-size grid (9×9 Masyu / Sudoku / Killer, or a game's largest) | 400 pts | **new flag** `bigBoardCleared` set on clearing a max-grid level |
| flawless | Flawless | 🎯 | special | Clear 25 levels total without using a hint | 400 pts + title "Purist" | **new counter** `noHintClears` (increment on hint-free clear) |
| speed_demon | Speed Demon | ⚡ | special | Clear a hard-timer level with >50% time remaining | 300 pts | **new flag** set when a hard-timer clear has `timeLeft > totalTime/2` |
| on_a_roll | On a Roll | 🔥 | special | Clear 15 levels in a row with no loss/restart | 300 pts | **new counter** `clearStreak` (increment on clear, reset on loss/timeout) |
| unbroken | Unbroken | 🗓️ | streak | Maintain a 100-day daily streak | 2500 pts + title "Unbroken" | `dailyStreak >= 100` (exists) |
| stylish | Stylish | 🌈 | special | Clear 50 levels with a swipe trail active | 250 pts | **new counter** `trailActiveClears` (increment when clearing while trail ≠ none) |
| trail_collector | Trail Collector | 🎨 | special | Own all 6 trail styles | 1000 pts + title "Stylist" | `claimedTrailStyles` contains all 6 |
| welcome_back | Welcome Back | 🔁 | special | Return and clear a level after 7+ days away | 200 pts | **new** compare `lastPlayedDate` vs now on clear |

**New tracking counters/flags to add** (SharedPreferences keys in `prefs_keys.dart`, incremented at the level-clear /
loss hooks that already fire `AchievementManager.checkAndUnlock`):
`noHintClears`, `clearStreak` (reset on loss/timeout), `trailActiveClears`, `bigBoardCleared` (bool),
`speedDemonEarned` (bool), `lastPlayedDate` (ISO string). Wire the new `case` branches into both
`checkAndUnlock` and `getProgress` in `achievement_manager.dart`, mirroring the existing pattern.

> Note: `into_the_deep`, `marathon`, `unbroken`, `trail_collector` need **no new tracking** — they read stats that
> already exist. Prioritise those; the flag/counter-based ones (`flawless`, `speed_demon`, `on_a_roll`, `stylish`,
> `big_board`, `welcome_back`) need the small hooks above.

---

## 3. Swipe Trails — the NEW unlock ladder (by levels cleared)

Replace `getRequiredClears` in `trails_screen.dart` with the user's ladder. The 6 unlockable trails (plus "none"):

| id | Name | Emoji | Description | **New required total clears** | (old) |
|----|------|-------|-------------|------------------------------|-------|
| none | No Trail | 🚫 | Disables swipe trails | 0 | 0 |
| accent | **Game Accent** | 🎯 | Matches the active game's signature colour (single tone, custom colour picker) | **30** | 30 |
| pastel | **Pastel Glow** | 🌸 | Soft pink/blue/sky blend | **100** | 60 |
| sparkle | **Sparkle Stars** | ✨ | Golden star particles with gravity | **250** | 120 |
| neon_glow | **Neon Glow** | ⚡ | Cyan + magenta dual-pass glow | **500** | 200 |
| rainbow | **Rainbow Neon** | 🌈 | Electric rainbow dual-pass glow | **750** | 250 |
| fire | **Fire Trail** | 🔥 | Crackling flame + rising embers | **1000** | 300 |

```dart
// trails_screen.dart
int getRequiredClears(String styleId) {
  switch (styleId) {
    case 'none':       return 0;
    case 'accent':     return 30;
    case 'pastel':     return 100;
    case 'sparkle':    return 250;
    case 'neon_glow':  return 500;
    case 'rainbow':    return 750;
    case 'fire':       return 1000;
    default:           return 9999;
  }
}
```

The locked-card copy already reads *"Locked: Requires N levels cleared (Current: X)"*, so it updates automatically.

---

## 4. "By levels cleared" vs "by cost" — recommendation

> **✅ DECISION (confirmed by product owner): HYBRID.** A trail is owned if the player *either* reaches the
> levels-cleared milestone (§3) *or* buys it with points. Implement Option C below.

The user asked whether trails should unlock by **cost** (spend points) instead of level milestones. Points already
exist (`PointManager`) and currently sink mainly into hints (`buy_hints_dialog.dart`). Here are the options:

- **Option A — Pure clears ladder (§3).** Simple, predictable, paces cosmetics across the journey, feels *earned*.
  Con: fixed unlock order; no player agency; points get no new sink.
- **Option B — Pure cost.** Each trail has a price; buy in any order. Pro: agency + a real point sink.
  Con: a grinder can rush all of them; loses the "reward for progress" feel; needs careful pricing.
- **Option C — Hybrid ✅ CHOSEN.** A trail is **owned if EITHER** the clears threshold (§3) is met **OR** it's
  been **bought with points**. Keeps the milestone feel as the default path, but lets a player who wants a specific
  trail *now* buy it — giving points a meaningful sink and the player agency.

### Hybrid — with these starting prices
Tune against the real economy (points come from per-level bonuses + achievement rewards). Prices set to roughly
parallel the effort of reaching each clears milestone:

| Trail | Clears path | Buy price (pts) |
|-------|-------------|-----------------|
| accent | 30 | 300 |
| pastel | 100 | 1,500 |
| sparkle | 250 | 4,000 |
| neon_glow | 500 | 9,000 |
| rainbow | 750 | 16,000 |
| fire | 1000 | 25,000 |

Implementation for hybrid:
- Add `int trailPrice(String id)` alongside `getRequiredClears`.
- `isUnlocked = globalClears >= getRequiredClears(id) || claimedStyles.contains(id)`.
- On the locked card, show a **"Buy for N ✦"** button when `points >= trailPrice(id)`; on tap, deduct via
  `PointManager` and add to `claimedTrailStyles`.
- Keep the free "Claim" button when the clears threshold is already met.

### Single source of truth (the §1 fix)
- **Remove `rewardTrailStyle` from all achievements.** Trails unlock **only** through the Trails screen
  (clears ladder + optional buy). Convert the removed trail rewards to extra points or a title so those
  achievements still feel rewarding.
- Delete the special-case `if (target.id == 'centurion') swipe_trail_unlocked=true` in `achievement_manager.claim`.
- `swipe_trail_unlocked` should be set the first time *any* trail is owned (already handled in `_selectStyle`).

---

## 5. Make the toasts tap-to-claim

Both toasts currently only auto-dismiss. Requirement:
- **Tap the Achievement toast → open the Achievements screen** (so the player claims it there).
- **Tap the Trail-unlock toast → open the Trails screen** (so the player claims/selects it there).

### Implementation notes
In `achievement_toast.dart` and `trail_unlock_toast.dart`:
1. Wrap the toast body (`Material`/`Container`) in a `GestureDetector` (or `InkWell`) with an `onTap`.
2. On tap: **cancel the auto-dismiss** (guard the pending `Future.delayed` reverse so it doesn't fire after
   navigation), remove the overlay entry, then navigate:
   ```dart
   onTap: () {
     _dismissNow();                       // remove overlay + reset _isShowing
     Navigator.of(context).push(MaterialPageRoute(
       builder: (_) => const AchievementsScreen(),   // TrailsScreen() for the trail toast
     ));
   }
   ```
   (If routes are registered in `main.dart`, use `Navigator.pushNamed` instead — currently neither
   `/achievements` nor `/trails` is a named route, so either register them or use `MaterialPageRoute`.)
3. **Pass the id through the toast** so the target screen can highlight/scroll to the just-unlocked item and make
   its **Claim** button obvious:
   - `AchievementToast.show(context, achievement)` already has the `Achievement` → pass `achievement.id` onward and
     have `AchievementsScreen` accept an optional `highlightId`.
   - `TrailUnlockToast.show(context, name, emoji)` currently passes only name/emoji → **also pass the trail `id`**
     so `TrailsScreen` can accept an optional `highlightId` and surface its Claim/Buy button.
4. Add a subtle affordance (e.g. a small "Tap to claim →" line, or a chevron) so users know the toast is actionable.
5. Keep the auto-dismiss as the fallback if the user doesn't tap.

---

## 6. Implementation checklist

- [ ] `trails_screen.dart`: update `getRequiredClears` to the new ladder (30/100/250/500/750/1000).
- [ ] **Hybrid (confirmed):** add `trailPrice`, a "Buy for N ✦" button + `PointManager` deduction, and
      `isUnlocked = clears >= required OR bought`.
- [ ] `achievement_manager.dart`: **add the 10 new achievements (§2.1)** + their `case` branches in `checkAndUnlock`
      and `getProgress`; add the new counters/flags (`noHintClears`, `clearStreak`, `trailActiveClears`,
      `bigBoardCleared`, `speedDemonEarned`, `lastPlayedDate`) in `prefs_keys.dart` and their increment hooks.
- [ ] `achievement_manager.dart`: remove all `rewardTrailStyle`; drop the `centurion` special-case; convert those
      rewards to points/titles. Fix `completionist` (desc vs `>=12`) and `monthly_grind` name/title consistency.
- [ ] `achievement_toast.dart`: make tappable → `AchievementsScreen(highlightId: ...)`, cancel auto-dismiss on tap.
- [ ] `trail_unlock_toast.dart`: pass trail `id`; make tappable → `TrailsScreen(highlightId: ...)`.
- [ ] `achievements_screen.dart` / `trails_screen.dart`: accept optional `highlightId` to scroll-to + emphasise Claim.
- [ ] Verify `perfect_memory` still maps to a real Chimp milestone after the Chimp redesign.
- [ ] Confirm one source of truth: trails owned only via Trails screen; achievements never grant trails.

---

*Cross-references: Chimp redesign & scaling → `difficulty_scaling_part_2_fix.md`; point economy lives in
`lib/utils/point_manager.dart`; trail rendering in `lib/widgets/swipe_trail_overlay.dart`.*
