# CogniQ Onboarding Strategy

**Date:** July 18, 2026  
**Scope:** First-time user experience, tutorial flow, difficulty ramp, retention optimization

---

## ⚠️ STATUS: PROPOSAL — not approved, metrics are assumptions (flagged 2026-07-18)

Exploratory sub-agent output; the user has not approved an onboarding overhaul. The design ideas (welcome flow, difficulty pick, per-game interactive tutorials) are reasonable to consider.

**All numbers are invented** ("45% → 70% day-2 retention", "8 → 15 min session", etc.). The app has no analytics (verified in source), so there is no current baseline and no way to measure the effect of any change here. Any success target requires adding analytics first. One factual note that IS real: the app already has tutorial infrastructure (`game_tutorial_dialog.dart`, `interactive_tutorial_overlay.dart`) — build on that rather than from scratch.

---

## Executive Summary

**Current onboarding gaps:**
- No structured tutorial (players thrust into game)
- Difficulty ramp unclear (might start too hard/easy)
- Game variety not explained (players don't know what they're choosing)
- Rules assumed knowledge (new players confused)

**Opportunity (directional, not quantified — no analytics exists to measure these):**
- Structured tutorial → should improve day-2 return
- Progressive disclosure → should improve first-level completion
- Difficulty selection → should reduce early frustration / mismatch

**Timeline:** rough guess, 2-3 weeks effort (not scoped)

---

## Current State Assessment

### What Works ✅
- Games have built-in difficulty (0-70 levels)
- Daily challenges introduce fresh content
- Home screen shows all games

### What Needs Fixing ❌
- No tutorial (players don't know how to play)
- Rules not explained (unclear what buttons do)
- No difficulty recommendation (players pick wrong difficulty)
- No progression guidance (players don't know what to do next)
- Overwhelming choice (20+ games shown immediately)

---

# ONBOARDING FLOW

## Phase 1: Welcome & Introduction (60 seconds)

### 1.1 Splash Screen
```
┌─────────────────────────────┐
│                             │
│         CogniQ              │
│    Play. Think. Win.        │
│                             │
│  [Skip] [Let's Begin]       │
│                             │
└─────────────────────────────┘

Animation: Zen zen zen breathing animation (calm, centered)
Tone: Welcoming, not pushy
CTA: "Let's Begin" primary, "Skip" secondary
```

### 1.2 Quick Intro Screens (3 screens, swipeable)
```
Screen 1: "Train Your Mind"
  "CogniQ is a collection of 20+ logic puzzles
   designed to improve focus and mindfulness."
  [Image: Happy person solving puzzle]
  
Screen 2: "Daily Challenges"
  "Complete 3 different puzzles every day
   to build your streak and unlock rewards."
  [Image: Daily challenge UI]
  
Screen 3: "Compete & Connect"
  "Climb global leaderboards and join
   communities of puzzle enthusiasts."
  [Image: Leaderboard screenshot]
```

**Controls:**
- Swipe left/right between screens
- Progress dots at bottom
- "Skip" button (always available)
- "Next" button (each screen)

---

## Phase 2: Difficulty Selection (30 seconds)

### 2.1 Difficulty Preference
```
┌──────────────────────────────────┐
│ What's Your Skill Level?         │
├──────────────────────────────────┤
│ □ Casual                         │
│   "I like relaxing, easy puzzles"│
│                                  │
│ ◉ Normal (Recommended)           │
│   "I enjoy a good challenge"     │
│                                  │
│ □ Hard                           │
│   "I want to be challenged"      │
│                                  │
│ □ Expert                         │
│   "I'm a puzzle master"          │
├──────────────────────────────────┤
│ [Back] [Continue]               │
└──────────────────────────────────┘

Logic: This sets the starting level for their first game
Note: "Normal" is recommended for first-timers
```

**Why This Matters:**
- Casual: Levels 0-15, small grids, hints enabled, no time pressure
- Normal: Levels 0-30, medium grids, some hints, time pressure starts at L20+
- Hard: Levels 5-50, large grids, minimal hints, strict time limits
- Expert: Levels 20-70, expert only, no hints, extreme time pressure

---

## Phase 3: Game Selection (60 seconds)

### 3.1 Recommended First Game
```
┌─────────────────────────────────┐
│ Let's Start!                    │
├─────────────────────────────────┤
│ We recommend starting with:     │
│                                 │
│ ┌──────────────────────────────┐ │
│ │  🟦 Grid Path                │ │
│ │                              │ │
│ │  "Drag to complete a path"   │ │
│ │  Perfect for beginners!      │ │
│ │  ⭐⭐ (Easy)                 │ │
│ │  ⏱️ 3-5 min per level        │ │
│ └──────────────────────────────┘ │
│                                  │
│ [Not Ready] [Start Game]        │
│                                  │
│ [Other Games]                   │
└─────────────────────────────────┘

Why Grid Path first?
- Visual, intuitive mechanic
- Immediate feedback
- Forgiving (no hidden rules)
- Builds confidence quickly
```

### 3.2 Alternative Game Selection (If User Declines)
```
┌─────────────────────────────────┐
│ Choose Your First Game          │
├─────────────────────────────────┤
│ Easiest:                        │
│  □ Grid Path (Drag paths)       │
│  □ Odd Color Out (Find colors)  │
│  □ Word Hive (Form words)       │
│                                 │
│ More Challenge:                 │
│  □ Sudoku (Number logic)        │
│  □ Star Battle (Placement)      │
│  □ Spectrum (Color matching)    │
│                                 │
│ Advanced:                       │
│  □ Colour Link (Path logic)     │
│  □ Circuit Guide (Rotation)     │
│  □ Mine Finder (Deduction)      │
│                                 │
│ [Back to Recommended]           │
└─────────────────────────────────┘
```

**Categorization:**
- Easiest: Clear rules, visual, fast feedback
- More Challenge: Logic required, medium complexity
- Advanced: High complexity, requires strategy

---

## Phase 4: Interactive Tutorial (5-10 minutes)

### 4.1 In-Game Tutorial (Step-by-Step)

**For Grid Path:**
```
┌─────────────────────────────────────┐
│ Grid Path Tutorial                  │
├─────────────────────────────────────┤
│                                     │
│ Step 1: Understand the Goal        │
│ "Draw a path that touches every   │
│  cell exactly once."               │
│                                     │
│ Example grid shown with solution   │
│                                     │
│ [Next] [Skip Tutorial]             │
└─────────────────────────────────────┘

[User taps Next]

Step 2: Your First Move
"Tap and drag from any cell to start
 drawing a path."

[Animated hand shows tapping & dragging]
[Cell highlights green as you draw]

[Next] [Try It]

[User tries drawing path]

Step 3: Complete the Path
"Your path is almost done! Connect
 back to where you started."

[Shows partial path, need to finish]
[User completes]

Step 4: Success!
"Great job! You completed your
 first puzzle!"

[Confetti animation]
[Show completed grid]
[Next Level button]
```

**Tutorial Triggers:**
- Show only for first game of each type
- Can be skipped at any time
- Replayable from settings
- No tutorial for subsequent games

### 4.2 Tutorial Content (Game-Specific)

**Sudoku Tutorial:**
```
Step 1: Understand the Goal
- "Fill grid so each row, column, box has 1-4"
- Example: [Show completed 4x4]

Step 2: Read the Clues
- "Blue numbers are clues - already filled"
- "You fill the empty cells"

Step 3: Check Your Work
- "If two 3s are in same row, that's wrong!"
- "Numbers turn red if they break rules"

Step 4: Use Hints
- "Stuck? Tap [Hint] button"
- "Shows one correct cell"
```

**Odd Color Out Tutorial:**
```
Step 1: Find the Different Tile
- "All tiles are nearly the same color"
- "Find the ONE tile that's slightly different"
- [Shows grid with one tile having off-color]

Step 2: Tap to Select
- "Tap the different tile to select it"
- [User taps correct tile]

Step 3: Level Complete!
- "You found it! Great job"
- "Next level will be harder (bigger grid)"
```

**Pattern Lock Tutorial:**
```
Step 1: Memorize the Pattern
- "Watch this pattern for 3 seconds"
- [Shows dots connecting in sequence]
- Counts down: 3, 2, 1, 0

Step 2: Dots Hidden
- "Now the pattern is hidden"
- "Trace the same path you just saw"

Step 3: Retrace
- [User traces pattern]
- "Success! You remembered it!"
```

### 4.3 Tutorial Accessibility
```
For players with cognitive disabilities:
  [Simplified] [Normal] [Detailed]
  
Simplified:
  - One instruction at a time
  - Visual > text
  - No animations (distracting)
  
Normal (default):
  - 2-3 instructions per screen
  - Text + visuals
  - Animations help explain
  
Detailed:
  - Full explanation
  - Lots of examples
  - Step-by-step walk-through
```

---

## Phase 5: Progression Guidance (Ongoing)

### 5.1 First-Session Completion
```
Goal: Player completes 3-5 levels in first session

Flow:
1. Complete tutorial (1 level)
2. Auto-advance to next level
3. Show brief tips between levels ("You're doing great!")
4. After 3 levels, show "Daily Challenge" suggestion
5. After 5 levels, show "Time to take a break?" option

Positive reinforcement:
- ✓ Checkmarks for each level
- ⭐ Stars for perfect completion
- 🏆 Achievement unlocks
- Points awarded (visible counter)
```

### 5.2 End of First Session
```
Summary Screen:
┌──────────────────────────────┐
│ Awesome Job! 🎉              │
├──────────────────────────────┤
│ You completed 5 levels!      │
│ ⭐⭐⭐⭐⭐ (Perfect)         │
│                              │
│ Next recommendations:        │
│  • Try a different game      │
│  • Complete today's challenge│
│  • Build a streak            │
│                              │
│ Come back tomorrow for:      │
│  • Daily streaks            │
│  • Leaderboards             │
│  • New games                │
│                              │
│ [Quit for Now]              │
│ [Keep Playing]              │
└──────────────────────────────┘
```

### 5.3 Day 2 Retention Push
```
Push notification (next day):
"Welcome back! Your daily challenges are ready.
 Keep your streak alive! 🔥"

Home screen (day 2):
- Emphasize daily challenge
- Show streak counter
- Highlight new games available
- Show friend activity (if social feature exists)
```

---

# GAME-BY-GAME ONBOARDING

## Tier 1: Easiest (Start with these)

### Grid Path
```
Mechanic: Draw a path
Tutorial steps:
  1. "Click and drag to draw"
  2. "Touch every cell once"
  3. "Connect back to start"
Difficulty start: Level 1 (3x3 grid, 2 waypoints)
```

### Odd Color Out
```
Mechanic: Find different tile
Tutorial steps:
  1. "Look carefully at all tiles"
  2. "One is slightly different color"
  3. "Tap to select it"
Difficulty start: Level 1 (2x2 grid, obvious difference)
```

### Word Hive
```
Mechanic: Form words with letters
Tutorial steps:
  1. "Use letters to form words"
  2. "All words must use center letter"
  3. "Score points for each word"
Difficulty start: Level 1 (5-letter words, all letters show)
```

## Tier 2: Medium

### Sudoku
```
Mechanic: Fill grid, no duplicates
Tutorial steps:
  1. "Each row, column, box has 1-4"
  2. "Tap cell, tap number to place"
  3. "Red = wrong, green = correct"
Difficulty start: Level 5 (pre-filled helpful clues)
```

### Star Battle
```
Mechanic: Place stars with constraints
Tutorial steps:
  1. "Place one star per row/column/box"
  2. "Stars can't touch (diagonally ok)"
  3. "Use numbers as clues"
Difficulty start: Level 1 (5x5, obvious solutions)
```

## Tier 3: Hard

### Colour Link
```
Mechanic: Connect matching colors without crossing
Tutorial steps:
  1. "Connect same-colored pairs"
  2. "Paths can't cross"
  3. "Fill entire grid"
Difficulty start: Level 15 (4x4, 2 colors)
```

### Circuit Guide
```
Mechanic: Rotate wires to complete circuit
Tutorial steps:
  1. "Rotate wires to connect bulbs"
  2. "All bulbs must have power"
  3. "Wires must form continuous path"
Difficulty start: Level 1 (3x3, 1 target)
```

---

# DIFFICULTY RAMP STRATEGY

## How Levels Progress

### Early Levels (1-5)
```
Goal: Teach the core mechanic
- Minimal complexity
- Visual feedback (colors, animations)
- No time pressure
- Hints readily available
- Success rate: 95%+ for intended difficulty

Example: Sudoku level 1
  - Pre-filled: 8 of 16 cells
  - Player only places 8 numbers
  - Takes 1-2 minutes
  - No timer
```

### Confidence Levels (6-15)
```
Goal: Build player confidence
- Introduce variations
- Increase speed slightly
- Hints cost (IQ points) but still available
- Some failed attempts ok (learning)
- Success rate: 80-90%

Example: Sudoku level 10
  - Pre-filled: 5 of 16 cells
  - Player places 11 numbers
  - Takes 3-5 minutes
  - No timer yet
```

### Challenge Levels (16-30)
```
Goal: Provide meaningful challenge
- Complexity increases
- Time pressure introduced (soft)
- Hints have cost, limited availability
- Expected success rate: 60-80%
- Some levels expected to require retry

Example: Sudoku level 20
  - Pre-filled: 3 of 16 cells
  - Player places 13 numbers
  - Takes 5-8 minutes
  - Timer starts: 600 seconds (soft limit)
```

### Expert Levels (31-50)
```
Goal: Challenge veteran players
- High complexity
- Time pressure real
- Hints expensive or unavailable
- Expected success rate: 40-70%
- Multiple retries expected

Example: Sudoku level 40
  - Pre-filled: 1 of 16 cells
  - Player places 15 numbers
  - Takes 10-15 minutes
  - Hard timer: 900 seconds (fail if exceeded)
```

### Endgame Levels (51-70)
```
Goal: Extreme challenge
- Maximum complexity
- Tight time limits
- No hints
- Expected success rate: 20-50%
- Designed for "completionists"

Example: Sudoku level 60
  - No pre-filled cells
  - Player places all 16 numbers
  - Takes 15-30 minutes
  - Extreme timer: 1200 seconds
```

---

# PROGRESSION GUIDANCE

## Home Screen Recommendation Engine

### First Week (Levels 1-30)
```
Home Screen shows:
  "Your Game: Grid Path, Level 6"
  [Start Grid Path]
  
  "Recommended Next: Try Sudoku"
  [Try Sudoku, Level 1]
  
  "Today's Challenge: Odd Color Out"
  [Start Challenge]
```

### After One Week
```
Analyze player's performance:
  - Which games do they complete?
  - Which difficulty levels?
  - Speed of completion?
  - Hint usage?

Recommend:
  - More games in their strongest category
  - Next challenge in weakness category
  - Leaderboard/streak focus
```

### Adaptive Difficulty
```
If player completes 5 levels without mistakes:
  "Ready for harder challenges?"
  [Jump to level 20]
  
If player retries level 3 times:
  "Take a break? Try an easier game?"
  [Offer Level 1-5 games]
```

---

# ONBOARDING METRICS

## Metrics worth tracking (once analytics exists)

There is **no analytics in the app today**, so there are no current values and no targets can be grounded. If/when a measurement layer is added, these are the right things to watch — the "Target" column below is **aspirational, not derived from data**:

| Metric | Aspiration (unvalidated) | Current | 
|--------|--------------------------|---------|
| Tutorial completion | high | not measured |
| First 10 levels completion | high | not measured |
| Day 1 → Day 2 retention | improve | not measured |
| First session length | improve | not measured |
| Game variety tried (first week) | improve | not measured |
| Player satisfaction (tutorial) | high | not measured |

---

# IMPLEMENTATION PLAN

## Phase 1: Core Tutorial (Week 1)
- [ ] Welcome screens
- [ ] Difficulty selection
- [ ] Game selection UI
- [ ] In-game tutorial framework (Grid Path)
- [ ] Skip/replay options

## Phase 2: Game-Specific Tutorials (Week 1-2)
- [ ] Grid Path tutorial (4 steps)
- [ ] Sudoku tutorial (4 steps)
- [ ] Odd Color Out tutorial (3 steps)
- [ ] Star Battle tutorial (3 steps)
- [ ] 5 more game tutorials

## Phase 3: Progression Guidance (Week 2)
- [ ] Recommendation engine
- [ ] First-session summary
- [ ] Day 2 push notifications
- [ ] Adaptive difficulty suggestions

## Phase 4: Polish & Analytics (Week 2-3)
- [ ] A/B test tutorial messaging
- [ ] Measure tutorial effectiveness
- [ ] Fix drop-off points
- [ ] Optimize retention funnel

---

# EXPECTED OUTCOMES (directional only — no figures, nothing measured)

### With Structured Onboarding, plausibly:
- Higher day-2 return (players know how to play)
- More first-session levels completed
- Longer, less-frustrated first sessions
- More games tried in the first week
- New players feel confident rather than lost

### Long-term Impact (qualitative):
- Better-trained players → higher completion rates
- Higher completion → better monetization (less churn)
- Confident players → more likely to recommend
- None of the above is quantified; magnitudes are unknown without analytics.

---

# CONCLUSION

Structured onboarding is a **retention multiplier**:

1. **Educate:** Players understand how to play
2. **Confident:** Build success early (easy levels)
3. **Guided:** Show them what to do next
4. **Engaged:** Create habits (daily challenges, streaks)
5. **Retained:** Players return day 2, week 2, month 2

**Recommendation:** A reasonable early investment (rough guess ~2-3 weeks). Expected upside is real but **unquantified** — don't cite a number until analytics can measure it.

---

**Document prepared:** July 18, 2026  
**Implementation timeline:** rough guess ~2-3 weeks (not scoped)  
**Expected impact:** directional improvement to early retention/engagement; magnitude unknown (no analytics)
