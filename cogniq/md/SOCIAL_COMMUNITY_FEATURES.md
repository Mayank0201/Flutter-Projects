# CogniQ Social & Community Features Strategy

**Date:** July 18, 2026  
**Scope:** Social engagement mechanics, community building, multiplayer-adjacent features

---

## ⚠️ STATUS: PROPOSAL — not approved; major architectural prerequisite (flagged 2026-07-18)

The user has **not** approved building social features. Two hard caveats before anyone scopes this:

1. **This requires a backend and user accounts that do not exist today.** The app is fully offline — all state is local `SharedPreferences`, with zero network calls (verified in source). Leaderboards, friends, and clans need a server, auth, an anti-cheat story, and privacy/moderation handling. That is a large, ongoing commitment, not a feature sprint.
2. **All the numbers are invented.** Every "+X% retention / +X% session frequency / viral coefficient" figure is an illustrative assumption. With no analytics in the app, none of it is measured or currently measurable.

Keep as an idea backlog. If pursued, step one is a product decision to go online + add analytics — not any of the UI below.

---

## Executive Summary

Currently CogniQ is **single-player focused**. Social features are a commonly-cited retention lever in the genre (qualitative — the app has no analytics to quantify any of this):

- **Leaderboards:** give competitive players a reason to return
- **Clans:** community belonging + a word-of-mouth growth path
- **Challenges:** progression relative to others
- **Friends:** social motivation when friends play

**Potentially a major growth opportunity — but unproven for this app, and it requires a backend that doesn't exist yet (see status banner).**

---

## Feature Recommendations (Prioritized)

# TIER 1: LEADERBOARDS (Q1 2027, January)

## Overview
Global, friend, clan, and regional leaderboards. Players compete for ranks, see scores, drive session frequency.

## Leaderboard Types

### 1.1 Global Leaderboards (All-Time)
```
Display:
  Rank | Player Name | Score | Achievements | Streak
  ───────────────────────────────────────────────────
  1    | PuzzleMaster | 145k  | 🏆🏆🏆      | 89 days
  2    | LogicNinja   | 142k  | 🏆🏆        | 76 days
  3    | ZenPlayer    | 139k  | 🏆          | 65 days
  ...
  127  | You (rank)   | 12k   |              | 5 days

Per-Game Leaderboards:
  [Sudoku Leaderboard] [Grid Path] [Colour Link] ...
  (separate ranking for each game)
```

**Scoring System:**
```
Points per level completion:
  Base: 1 point per level
  Bonus: (1000 - time_taken) * difficulty_multiplier
  Example: Sudoku level 15 in 120s = 1 + (1000-120)*1.5 = 1,331 points

Calculation:
  score = base_points + (max_time - actual_time) * multiplier
  
Where:
  - base_points = 1 per level
  - max_time = estimated completion time for level
  - actual_time = player's completion time
  - multiplier = difficulty (1.0x to 2.0x based on level)
```

**Monthly Reset Leaderboards:**
```
Reset on 1st of each month
Encourages repeat engagement ("chase the leaderboard again")
Monthly rewards for top players (cosmetics, badges)
```

**By-Game Leaderboards:**
```
Each game has separate ranking (e.g., top Sudoku players)
Allows specialists to compete in their domain
Encourages trying all games (to compete on multiple leaderboards)
```

### 1.2 Friend Leaderboards
```
See where you rank vs friends
Shows friend scores, streaks, progress
Notifications when friend surpasses you (gamify rivalry)

Interface:
  [Your friends] [Compare with friend X] [Invite friends]
  
  Friend Name | Score | Levels | Streak | vs You
  ─────────────────────────────────────────────────
  Alice       | 52k   | 156    | 12d    | +15k
  Bob         | 38k   | 127    | 8d     | +8k
  YOU         | 30k   | 98     | 5d     | —
  Charlie     | 22k   | 76     | 3d     | -8k
```

**Notifications:**
```
"Alice beat your score on Sudoku! 45,230 points"
"Bob reached level 100 on Grid Path!"
"Charlie has a 10-day streak, you have 5 days"
```

### 1.3 Clan Leaderboards
```
Clans compete as groups
Rankings by cumulative score + levels + streaks

Clan Leaderboard Display:
  Rank | Clan Name    | Total Points | Members | vs Clan
  ──────────────────────────────────────────────────────
  1    | Zen Masters  | 2,450,000   | 47      | —
  2    | Logic Strike | 2,280,000   | 52      | -170k
  3    | Sudoku Elite | 1,920,000   | 38      | -530k
  
  Per-member average: 2.45M / 47 = 52,128 points/member
```

**Clan-Specific Features:**
```
- Clan milestones ("1M points unlocked!")
- Clan events (weekly challenges)
- Clan leaderboards vs other clans
- Clan roles (captain, moderator, member)
```

### 1.4 Regional Leaderboards
```
Players grouped by country/region
Drives local competition, community

Optional by country:
  [Global] [Your Country] [Your Region] [Your City]
  
Example:
  [Global USA California San Francisco]
```

## Leaderboard Mechanics

### Scoring Deep Dive
```
Formula: score = level_completed + speed_bonus + streak_bonus

Level completed:
  - 1 point per level
  - Resets don't count (only progression counts once)
  - Accounts for all 20+ games

Speed bonus:
  - Score increases if completed faster than avg player
  - Avg completion time varies by level
  - Bonus: +100 to +500 points based on speed
  - Example: Sudoku level 15 avg time = 3min
              Player completes in 1min = +300 speed bonus

Streak bonus:
  - 7-day streak: +50 points/day
  - 30-day streak: +100 points/day
  - 100-day streak: +200 points/day
  - Example: 30-day streak completing 1 level/day = +3,000 bonus

Perfect game bonus:
  - Complete game without hints = +500 bonus
  - Complete without mistakes = +300 bonus

Difficulty multiplier:
  - Casual: 1.0x
  - Normal: 1.5x
  - Hard: 2.0x
  - Expert: 3.0x
```

### Leaderboard Updates
```
Real-time updates (within 5 seconds)
Live score notifications
Rank change notifications when you move up/down 10+ spots
```

### Cheating Prevention
```
- Must complete puzzle before getting points
- Points awarded only for valid solutions
- Track completion time (flag suspicious speed)
- Replay detection (same pattern = flagged)
- Automated validation
- Manual review for top 100 players
```

## UI Design

### Leaderboard Screen Layout
```
┌─────────────────────────────────┐
│  Leaderboards                  │
├─────────────────────────────────┤
│ [Global] [Friends] [Clans] [Regional] │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ #1  🥇 LogicMaster   142k   │ │
│ │ #2  🥈 ZenPuzzler     138k  │ │
│ │ #3  🥉 SudokuKing     135k  │ │
│ │ ... (7 more)              │ │
│ │ #127 📍 You            12k   │ │
│ │                             │ │
│ │ [See more] [Invite friends] │ │
│ └─────────────────────────────┘ │
│                                 │
│ Tap profile to see details      │
├─────────────────────────────────┤
│ [Refresh] [Share] [Report]     │
└─────────────────────────────────┘
```

### Player Profile Card (Leaderboard)
```
Tap on player → see detailed profile:

┌──────────────────────────────┐
│ LogicMaster              1/15 │
│ ⭐⭐⭐⭐⭐ (Elite Tier)    │
├──────────────────────────────┤
│ Score:      145,230         │
│ Levels:     347 total       │
│ Streak:     89 days         │
│ Favorite:   Sudoku (98%)    │
│ Top Game:   Star Battle     │
│             Level 67        │
│ Joined:     Feb 2024        │
│ Region:     USA - CA        │
├──────────────────────────────┤
│ [Add Friend] [View Games]    │
│ [Challenge]  [Send Message]  │
└──────────────────────────────┘
```

## Leaderboard Release Strategy

### Phase 1: Launch (Week 1)
- Global leaderboards live
- All-time + monthly rankings
- Per-game leaderboards
- Rank notifications

### Phase 2: Expansion (Week 2-3)
- Friend leaderboards
- Regional leaderboards
- Clan leaderboards (after clans launch)

### Phase 3: Engagement (Week 4+)
- Monthly leaderboard reset/refresh
- Seasonal leaderboards
- Special event leaderboards

---

# TIER 2: FRIEND SYSTEM (Q1 2027, January-February)

## Overview
Add friends, see their progress, send challenges, build community.

## Features

### 2.1 Friend Requests
```
Search by username or share friend code
Accept/decline requests
See friend's full profile

Flow:
  1. Search for friend (username/code)
  2. Send request
  3. Friend gets notification
  4. Friend accepts/declines
  5. Added to friend list
```

### 2.2 Friend Activity Feed
```
See what friends are doing:
  - "Alice just reached level 50 on Sudoku!"
  - "Bob achieved 'Speed Demon' badge"
  - "Charlie started a 7-day streak"
  - "Diana unlocked Zen Mode"
```

### 2.3 Friend Challenges
```
Challenge a friend to beat your score:
  
  "Hey, I just got 1,450 points on Sudoku level 23.
   Can you beat my score?"
   
   [Challenge Screenshot] [Accept] [Dismiss]
   
Challenge tracking:
  - Friend gets notification
  - Friend accepts challenge
  - Leaderboard shows "vs Friend"
  - Who won? Notification sent
```

### 2.4 Send Puzzle Screenshots
```
Share your achievement:
  "Completed Sudoku without hints! 🎉"
  [Screenshot of completed puzzle]
  
Send to:
  - Individual friends
  - Group chat (if messaging enabled)
  - Public profile
```

## Friend Features Impact

**Notifications:**
```
"Alice sent you a challenge on Sudoku!"
"Bob beat your score on Grid Path (47,230 vs 45,120)"
"Charlie is now your friend"
"Diana invited you to a clan"
```

**Friend List UI:**
```
Friends
  [Add Friends] [Friend Requests] [Block List]

Friend Name    | Score | Level | Streak | Status
─────────────────────────────────────────────────
Alice          | 52k   | 156   | 12d    | Online
Bob            | 38k   | 127   | 8d     | Offline
Charlie        | 22k   | 76    | 3d     | Online
  
[See all friends]
```

---

# TIER 3: CLANS (Q1 2027, February-March)

## Overview
Join groups (clans) of 10-100 players. Compete together, complete clan quests, build community.

## Clan Features

### 3.1 Clan Creation & Membership
```
Create a clan:
  - Name (required)
  - Description (optional)
  - Privacy: Public / Invite-only
  - Member limit: 10-100
  - Roles: Captain, Moderator, Member

Join a clan:
  - Browse public clans
  - Search by name
  - Join with invite code
  - Request membership (invite-only)
```

### 3.2 Clan Leaderboards
```
Clan members ranked by:
  - Total clan points
  - Levels completed (this season)
  - Contribution to clan milestones
  
Clan vs Clan:
  - Clans ranked by total points
  - Monthly clan competition
  - Seasonal clan tournaments
```

### 3.3 Clan Quests (Optional)
```
Weekly clan challenges:
  "All members complete 5 levels in Sudoku" = +500 clan points
  "Any member reaches level 40 in 3 games" = +300 clan points
  
Rewards:
  - Cosmetics for members
  - Badges (clan-specific)
  - Bonus points
```

### 3.4 Clan Milestones
```
Unlock perks at clan-wide milestones:
  1M points → Custom clan color
  5M points → Exclusive clan badge
  10M points → Private clan leaderboard
  25M points → Clan event (exclusive content)
```

### 3.5 Clan Roles & Permissions
```
Captain:
  - Edit clan info
  - Remove members
  - Manage roles
  - Set clan quests

Moderator:
  - Remove members
  - Manage discussions (if clan chat)
  - Pin announcements

Member:
  - Participate in clan
  - Contribute to quests
  - View clan leaderboards
```

## Clan Discovery

```
Clan Browser:
  - Featured clans (new, trending)
  - Search by name/keyword
  - Filter by size, activity, region
  - See clan stats (total points, members, avg level)

Clan Profile:
┌─────────────────────────────┐
│ Zen Masters                 │
│ ⭐⭐⭐⭐⭐ (5.0)            │
│ Captain: MasterMind         │
├─────────────────────────────┤
│ Members: 47/50             │
│ Total Points: 2.4M         │
│ Avg Level: 156             │
│ Activity: Very Active      │
│ Region: Global             │
│ Founded: Jan 2024          │
│ Description:               │
│ "Passionate logic puzzle   │
│  community. Daily events." │
├─────────────────────────────┤
│ [Join] [Message Captain]   │
│ [View Members] [View Stats]│
└─────────────────────────────┘
```

## Clan Chat (Optional - Low Priority)

If implemented (not priority):
```
Simple text chat for clan members
Moderation tools for captains
No DMs (keeps it simple)
Max 100 messages visible (prevent scrolling overload)
```

---

# TIER 4: SEASONAL EVENTS & CHALLENGES

## Overview
Limited-time events drive engagement during key periods.

## Event Types

### 4.1 Seasonal Events (Quarterly)
```
Q1 (Jan-Mar): Winter Challenge
  - Limited-time puzzle variant
  - Leaderboard reset
  - Special cosmetics

Q2 (Apr-Jun): Spring Rush
  - Speed challenges
  - Bonus points
  - Exclusive badges

Q3 (Jul-Sep): Summer Series
  - Difficulty increase
  - Cooperative challenges
  - Team rewards

Q4 (Oct-Dec): Holiday Marathon
  - Multi-week event
  - Gift system
  - Community goals
```

### 4.2 Weekly Challenges
```
Each week:
  "Complete 5 games without hints" = +500 bonus points
  "Reach a 3-day streak" = Exclusive badge
  "Get top 100 on any leaderboard" = Cosmetic reward
  
Rotating every Monday
Players compete week-by-week
Keeps engagement fresh
```

### 4.3 Community Goals
```
"Together, let's complete 1M puzzles this month!"
  [Progress bar]
  
When community hits milestone:
  - Unlock new game variant
  - Bonus points for all players
  - Special event cosmetic
  
Builds unity, shared purpose
```

---

# SOCIAL FEATURE INTEGRATION POINTS

## Where Social Appears

### Home Screen
- "Your friend Alice just reached level 100!"
- Leaderboard rank chip (shows current global rank)
- "2 friends sent you challenges"

### Game Complete Screen
- "Share this achievement" (screenshot)
- "Challenge a friend"
- Leaderboard comparison

### Settings/Profile
- Friend list
- Clan membership
- Social preferences
- Notification settings

### Notifications
- Friend requests
- Challenge notifications
- Leaderboard updates
- Clan milestones

---

# SOCIAL FEATURE IMPACT

## Expected direction (NOT quantified — no numbers behind these)

There is no analytics layer, so no lift can be estimated. Qualitatively, each feature *should* help in the direction shown:

| Feature | Likely effect on retention | Likely effect on session frequency |
|---------|----------------------------|-------------------------------------|
| Leaderboards | positive | positive |
| Friends | positive | positive |
| Clans | positive (strongest) | positive |
| Challenges | positive | positive |
| Events | positive (time-boxed spikes) | positive |

## Viral growth (qualitative)

- Friends inviting friends is a plausible acquisition path
- Clan discovery and public leaderboards add word-of-mouth surface
- **No coefficient or percentage can be claimed without measurement.**

---

# PRIVACY & SAFETY CONSIDERATIONS

## Data Privacy
```
Player data visible on leaderboards:
  - Username only
  - Score/rank
  - Clan (if applicable)
  
NOT visible:
  - Email address
  - Payment info
  - Exact device info
  - Location (except opt-in regional)
```

## Safety Features
```
- Block players (no interaction)
- Report abuse (harassment, cheating)
- Clan moderation (captain can remove)
- No DMs (use clan chat only)
- Profanity filter (clan names, messages)
```

## Cheating Prevention
```
- Detect impossible scores
- Replay pattern matching
- Rate-limit score submissions
- Manual review of top players
- Feedback loop for suspicious activity
```

---

# IMPLEMENTATION TIMELINE

### Phase 1: Q1 2027 (January-March)
- Week 1-2: Leaderboards
- Week 3-4: Friend system
- Week 5-8: Clans
- Week 9-12: Events integration

### Phase 2: Q2 2027 (If resources available)
- Social graph features
- Community events
- Seasonal leaderboards

---

# METRICS TO TRACK (once analytics + a backend exist)

No targets can be grounded today (no analytics). If built, these are the right things to measure — the "Target" values are **aspirational placeholders, not projections**:

| Metric | Aspiration (unvalidated) | Measurement |
|--------|--------------------------|-------------|
| Friends per player | some | needs analytics |
| Clan participation | meaningful share | adoption rate |
| Challenge completion | meaningful share | challenge acceptance |
| Leaderboard check rate | recurring | needs analytics |
| Viral coefficient | > 1 ideally | new-user attribution |
| Social-driven retention | positive | 30-day cohort analysis |

---

# Conclusion

Social features are widely used as a retention lever, and *could* be one here:
- Leaderboards provide a competitive goal
- Friends provide social motivation
- Clans provide community belonging
- Events provide time-limited urgency

**Reality check:** this is unproven for CogniQ and requires a backend + accounts the app doesn't have. Treat as an idea backlog pending a product decision to go online.

---

**Document prepared:** July 18, 2026  
**Status:** proposal only — not approved, not scoped  
**Prerequisite:** backend + user accounts + analytics (none exist today)  
**Expected impact:** directional/positive; unquantified
