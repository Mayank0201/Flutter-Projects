# CogniQ Game Suggestions - Mechanics & Visual Design

**Date:** July 18, 2026  
**Focus:** 10 new game concepts with complete mechanics, progression, and visual design guidelines

---

## STATUS: design proposals (flagged 2026-07-18)

These are concepts, not verified against anything in the codebase (they're new games). Reasonable to use as design starting points. Caveats: the **dev-time estimates and "proven popular" / difficulty ratings are opinion, not scoped work**, and the visual specs (hex palettes, cell sizes) are suggestions to reconcile with the real `app_theme.dart`, not measured values. Per the user's decisions in `remember.md`: the priority additions are **Kakuro, Cipher Decoder (as a scaled logic puzzle), Hitori, Slitherlink, Killer Sudoku**; **Nonogram was rejected** (allows ambiguous multiple solutions); Chain Breaker / Frequency / Vault Builder are parked (high-cost, niche).

---

## Table of Contents

1. [Game Selection Matrix](#game-selection-matrix)
2. [Tier 1 Games (High Priority)](#tier-1-high-priority)
3. [Tier 2 Games (Good Additions)](#tier-2-good-additions)
4. [Tier 3 Games (Experimental)](#tier-3-experimental)
5. [Visual Design System](#visual-design-system)
6. [Implementation Complexity](#implementation-complexity)

---

## Game Selection Matrix

| Game | Type | Difficulty | Scaling | Visual Appeal | Priority | Est. Dev |
|------|------|-----------|---------|---------------|----------|----------|
| Futoshiki | Constraint | Medium | Excellent | 7/10 | Tier 1 | 2 weeks |
| Kuromasu | Deduction | Medium | Excellent | 8/10 | Tier 1 | 2 weeks |
| Skyscrapers | Visibility | Medium-Hard | Excellent | 7/10 | Tier 1 | 2.5 weeks |
| Shakashaka | Geometric | Medium | Good | 8/10 | Tier 2 | 2 weeks |
| Norinori | Region-based | Medium | Good | 7/10 | Tier 2 | 2 weeks |
| Yin-Yang | Connectivity | Medium | Good | 8/10 | Tier 2 | 2 weeks |
| Chain Breaker | Real-time | Hard | Good | 9/10 | Tier 3 | 3 weeks |
| Frequency | Audio-Visual | Hard | Good | 9/10 | Tier 3 | 4 weeks |
| Thermostat | Placement | Easy-Medium | Good | 7/10 | Tier 2 | 2 weeks |
| Vault Builder | Strategy | Hard | Excellent | 9/10 | Tier 3 | 4 weeks |

---

# TIER 1: HIGH PRIORITY GAMES

## 1. Futoshiki (Inequality Sudoku)

### Game Overview
**Concept:** Fill a grid with numbers 1-N (N = grid size), respecting inequality signs between cells.

**Core Mechanic:**
- Grid size: 4x4 to 9x9
- Each row/column contains numbers 1-N exactly once (like Sudoku)
- Between cells: < > symbols show inequality constraints
- < means left value < right value
- \> means left value > right value
- No region constraints (unlike Sudoku)

### Gameplay Example (4x4 Grid)
```
  [_] > [_] | [_] < [_]
      |     v
  [_] < [_] | [_] > [_]
  --------- + ---------
  [_] > [_] | [_] < [_]
      |     v
  [_] < [_] | [_] > [_]
```
Goal: Fill with 1-4, each row/column has 1,2,3,4, respect all > and < signs.

### Scaling Progression

| Level Range | Grid | Inequality Density | Time Limit | Secondary |
|-------------|------|-------------------|-----------|-----------|
| 0-9 | 4x4 | 30% (sparse) | None | Show candidates |
| 10-19 | 5x5 | 40% | None | Show candidates |
| 20-29 | 6x6 | 50% (medium) | 120 sec | Hide candidates |
| 30-39 | 7x7 | 60% | 90 sec | Hide candidates |
| 40-49 | 8x8 | 70% (dense) | 60 sec | Show only locked cells |
| 50-59 | 9x9 | 80% | 45 sec | Blind mode (no numbers shown) |
| 60-69 | 5x5 | 70% | 30 sec | **Multiple grids**: solve 2 grids simultaneously |
| 70+ | Scales | 90%+ | Variable | **Chained grids**: solution of one affects another |

**Why This Scaling Works:**
- Grid size naturally increases difficulty
- Inequality density tightens constraint satisfaction
- Time pressure changes strategy
- Blind mode adds memory element
- Multiple grids add complexity without just bigger

### Difficulty Curve
- Levels 0-20: Learning curve (sparse inequalities, candidate hints)
- Levels 21-40: Medium (denser constraints, time pressure)
- Levels 41-60: Hard (very dense, blind mode, memory)
- Levels 61+: Expert (multiple conditions combined)

---

### Visual Design

#### Color Scheme
```
Primary Grid:
- Cell bg (empty): #F5F4F0 (light zen)
- Cell bg (filled): #E8E3D8
- Cell text (number): #1C1A18 (dark)
- Inequality symbol: #8B7E8F (dustyMauve)
- Selected cell bg: #E8DFF0 (light mauve tint)

Accents:
- Constraint highlight: #A89FB0 (mauve, when selected)
- Error state: #D4889C (dusty rose)
- Candidate numbers: #9B8FA0 (muted mauve)
```

#### Layout Design
```
┌─────────────────────────────────┐
│  Futoshiki                    L1 │
├─────────────────────────────────┤
│                                 │
│    ┌─────────────────────┐     │
│    │ ┌─┐ > ┌─┐   ┌─┐ < ┌─┐   │
│    │ └─┘   └─┘   └─┘   └─┘   │
│    │   <   >       >   <       │
│    │ ┌─┐ < ┌─┐   ┌─┐ > ┌─┐   │
│    │ │2│   └─┘   │4│   └─┘   │
│    └─────────────────────┘     │
│                                 │
│ Time: 120s  |  Mistakes: 0     │
├─────────────────────────────────┤
│ [Hint] [Undo] [Check] [New]    │
└─────────────────────────────────┘
```

#### Cell Design
- Cells: 48x48 px (responsive)
- Border: 2px, color #D8D3CC
- Cell radius: 4px
- Inequality symbols: Between cells, centered, 14px font
- Numbers: 18px, bold, centered
- Candidate mode: Show 1-4 in corners (6px font)

#### Interactions
- Tap cell → select (highlight with mauve tint)
- Tap number → fill (animates in)
- Tap inequality → highlight constraint path
- Swipe left/right → previous/next inequality
- Long press → show constraint explanation

#### Animation
- Cell fill: 200ms ease-out (scale + fade)
- Inequality highlight: 300ms pulse
- Error shake: 200ms (shake 3px left/right)
- Candidate fade: 150ms

---

### Game Flow
1. **Level Start:** Show grid with some numbers pre-filled
2. **Gameplay:** Tap cell → tap number 1-N to place
3. **Validation:** Real-time (highlight if violates inequality)
4. **Completion:** All cells filled, all constraints satisfied → "Level Complete"
5. **Next Level:** Auto-advance or show "Next Level" button

### Hint System
- Hint 1: Show one valid number in an empty cell
- Hint 2: Highlight one constraint path
- Hint 3: Show candidate numbers for one cell
- Cost: 1 IQ point per hint

---

## 2. Kuromasu (Black Cells)

### Game Overview
**Concept:** Determine which cells are black/white, with numbers showing visible white cells in each direction.

**Core Mechanic:**
- Grid size: 4x4 to 9x9
- Each cell contains number or is empty/black
- Numbers show: how many white cells visible in that direction
- Black cells block vision (like walls)
- All white cells must form one connected group
- No 2x2 square can be all black

### Gameplay Example (4x4)
```
┌─────────────────────┐
│ 2 | _ | 1 | _ |    │
├─────────────────────┤
│ _ | 2 | _ | 0 |    │
├─────────────────────┤
│ 1 | _ | 3 | _ |    │
├─────────────────────┤
│ _ | 1 | _ | 2 |    │
└─────────────────────┘

Goal: Place black cells such that:
- "2" in top-left can see 2 white cells to right
- "0" means cell itself is black (surrounded by visibility)
- All white cells form one connected group
```

### Scaling Progression

| Level Range | Grid | Number Density | Connectivity Complexity | Time | Secondary |
|-------------|------|----------------|------------------------|------|-----------|
| 0-9 | 4x4 | Sparse (20%) | Simple (obvious groups) | None | Show black cells |
| 10-19 | 5x5 | Sparse (25%) | Simple | None | Show black cells |
| 20-29 | 6x6 | Medium (35%) | Medium (some ambiguity) | 120s | Partial black cells shown |
| 30-39 | 7x7 | Medium (40%) | Complex (tight constraints) | 90s | No hints |
| 40-49 | 8x8 | Dense (50%) | Very complex | 60s | **Bidirectional view**: numbers show visibility left AND right |
| 50-59 | 9x9 | Very dense (60%) | Extreme | 45s | **Multi-cell numbers**: span 2 cells |
| 60-69 | 8x8 | Dense | Complex | 30s | **Hidden numbers**: some numbers don't show until deduced |
| 70+ | 9x9 | Dense | Extreme | Variable | **Chained puzzles**: solve 2-3 grids with shared constraints |

**Why This Scaling Works:**
- Grid size increases naturally
- Number density tightens constraints
- Connectivity rules make later levels extremely deductive
- Bidirectional view changes strategy (more info = harder logic)
- Hidden numbers add mystery/discovery

### Difficulty Curve
- Levels 0-20: Learning (clear patterns, obvious black cells)
- Levels 21-40: Medium (complex deduction, tight connectivity)
- Levels 41-60: Hard (very dense, bidirectional rules)
- Levels 61+: Expert (hidden numbers, chained puzzles)

---

### Visual Design

#### Color Scheme
```
Cells:
- White cell bg: #F5F4F0 (light zen)
- Black cell bg: #2C2A27 (dark gray)
- Black cell animation: Gradient #2C2A27 → #1C1A18 (fills)
- Number text: #1C1A18 (dark on white)
- Selected cell border: #8B7E8F (mauve), 3px
- Connected group highlight: #C9B8D4 (light mauve pulse), 50% opacity

Accents:
- Direction indicator: #A89FB0 (mauve arrow)
- Error state: #D4889C (rose)
- Visibility path: #E0D5E8 (mauve glow)
```

#### Layout Design
```
┌─────────────────────────────────┐
│  Kuromasu                   L15  │
├─────────────────────────────────┤
│                                 │
│    ┌──────────────────────┐    │
│    │  2   .   1   .      │    │
│    │  .   2   .  [0]     │    │
│    │  1   .   3   .      │    │
│    │  .   1   .   2      │    │
│    └──────────────────────┘    │
│                                 │
│ Filled: 6/16  |  Connected: ✓  │
├─────────────────────────────────┤
│ [Hint] [Undo] [Check] [New]    │
└─────────────────────────────────┘
```

#### Cell Design
- White cells: 48x48 px
- Black cells: 48x48 px (solid dark)
- Border: 1px, #D8D3CC
- Number: 16px, centered, bold
- Direction indicator: Small arrow (↑→↓←) showing which direction "sees"
- Connectivity glow: 2px border, 50% opacity mauve when cell is part of connected group

#### Interactions
- Tap cell → toggle black/white
- Double tap → peek (show if black or white, locks for 3 sec)
- Hold → show visibility line (highlights which cells this number "sees")
- Tap number → show what it should see (preview)

#### Animation
- Cell color change: 200ms (smooth transition)
- Connectivity update: 150ms (pulse neighbors when group updates)
- Number reveal: 300ms fade-in
- Vision ray: Animated line showing visibility (200ms draw)

---

### Game Flow
1. **Level Start:** Show grid with numbers, all cells unknown
2. **Gameplay:** Tap cell to mark black/white
3. **Real-time Feedback:** 
   - Shows if connectivity is broken
   - Shows if a white cell group is formed
   - Highlights when all constraints satisfied
4. **Completion:** All cells marked, connectivity verified → "Level Complete"

### Hint System
- Hint 1: Reveal one cell's color (black or white)
- Hint 2: Show visibility line from one number
- Hint 3: Highlight one connected white group
- Cost: 1 IQ point per hint

---

## 3. Skyscrapers

### Game Overview
**Concept:** Arrange buildings by height (1-N) such that clues show correct number of visible buildings.

**Core Mechanic:**
- Grid size: 4x4 to 9x9
- Each row/column contains heights 1-N exactly once
- Like Sudoku but NO region constraints
- Clues around grid: how many buildings visible from that direction
- Taller buildings hide shorter ones behind (occluded)
- Strategy: Work backwards from clue visibility

### Gameplay Example (4x4)
```
     3  |  2  |  1  |  4
   ─────────────────────
 2 │ 1  │  4  │  2  │  3  │ 2
 1 │ 2  │  1  │  4  │  3  │ 1
 4 │ 3  │  2  │  1  │  4  │ 3
 1 │ 4  │  3  │  2  │  1  │ 1
```

**How It Works:**
- From left: see 3 buildings (4 is tallest, visible; all hidden behind)
- From top: see 3 buildings (each row's first building in that column)
- From right: see 2 buildings (4 hidden behind, 3 visible, then all hidden behind)

### Scaling Progression

| Level Range | Grid | Clue Density | Difficulty | Time | Secondary |
|-------------|------|-------------|-----------|------|-----------|
| 0-9 | 4x4 | 75% clues | Easy (obvious paths) | None | Show candidates |
| 10-19 | 5x5 | 75% clues | Easy-Medium | None | Show candidates |
| 20-29 | 6x6 | 60% clues | Medium (gaps to deduce) | 120s | Partial candidates |
| 30-39 | 7x7 | 50% clues | Medium-Hard | 90s | No candidates |
| 40-49 | 8x8 | 40% clues | Hard (many gaps) | 60s | **Corner clues only**: clues only on 4 corners |
| 50-59 | 9x9 | 30% clues | Hard | 45s | Corner clues + time pressure |
| 60-69 | 7x7 | 25% clues | Expert (minimal info) | 30s | **Partial clues**: some clues are question marks (hidden) |
| 70+ | 9x9 | 20% clues | Expert | Variable | **Multiple grids**: 2 grids with shared edge constraints |

**Why This Scaling Works:**
- Grid size increases naturally
- Fewer clues = more deduction required
- Corner-only clues force backward reasoning
- Partial/hidden clues add mystery
- Multiple grids add interconnected logic

### Difficulty Curve
- Levels 0-20: Learning (full clues, obvious visibility)
- Levels 21-40: Medium (gaps to fill in, no candidates)
- Levels 41-60: Hard (corner clues only, deductive reasoning)
- Levels 61+: Expert (minimal info, hidden clues, chained puzzles)

---

### Visual Design

#### Color Scheme
```
Grid:
- Cell bg (empty): #F5F4F0 (light zen)
- Cell bg (building): #D8E5F0 (light blue tint)
- Cell text (height): #1C1A18 (dark), 24px bold
- Clue text: #5F7A8F (slate blue), 16px
- Clue bg: #E8F0F5 (very light blue), rounded 8px
- Selected building: #A8C5D8 (light blue), 2px border
- Visibility highlight: #7FA8C9 (medium blue), 30% opacity

Accents:
- Error state: #D4889C (rose)
- Correct column/row: #B8D4C9 (sage pulse)
- Candidate numbers: #9FB8C9 (muted blue)
```

#### Layout Design
```
┌────────────────────────────────┐
│  Skyscrapers                 L8 │
├────────────────────────────────┤
│          2   3   1   4         │
│      ┌───────────────────┐     │
│   2  │ _ │ _ │ _ │ _ │  1     │
│      │───────────────────│     │
│   1  │ _ │ _ │ _ │ _ │  2     │
│      │───────────────────│     │
│   3  │ _ │ _ │ _ │ _ │  1     │
│      │───────────────────│     │
│   4  │ _ │ _ │ _ │ _ │  2     │
│      └───────────────────┘     │
│          4   1   2   3         │
│                                 │
│ Filled: 4/16  |  Valid: ✓      │
├────────────────────────────────┤
│ [Hint] [Undo] [Check] [New]   │
└────────────────────────────────┘
```

#### Building Visualization
- Each height 1-4: Different color gradient or height visualization
  - Height 1: Light #E8F0F5
  - Height 2: Medium #A8C5D8
  - Height 3: Darker #7FA8C9
  - Height 4: Darkest #5F7A8F
- Option: Draw small building silhouettes (simple 3D boxes)
- Number overlay: Clear, large, centered in cell

#### Clue Display
- Arranged around grid edges
- Bg: Rounded rectangle with light tint
- Hover/select: Highlight visibility path from that clue
- Animation: Show "visibility line" when clue tapped

#### Interactions
- Tap cell → select (shows height options 1-N)
- Tap number → place that height
- Tap clue → highlight visibility path from that clue (animated ray)
- Swipe through cells → cycle through heights
- Long press → show constraint explanation

#### Animation
- Building fill: 200ms ease-out (scale in from center)
- Visibility ray: 300ms animated line showing visible buildings
- Height change: 150ms fade
- Row/column glow: 200ms pulse when complete

---

### Game Flow
1. **Level Start:** Show grid with clues, no buildings placed
2. **Gameplay:** Tap cell → tap height 1-N to place
3. **Real-time Feedback:** Show if clue is satisfied when row/column complete
4. **Completion:** All cells filled, all clues validated → "Level Complete"

### Hint System
- Hint 1: Reveal one building's height
- Hint 2: Show visibility line for one clue
- Hint 3: Highlight one column/row that's correct
- Cost: 1 IQ point per hint

---

# TIER 2: GOOD ADDITIONS

## 4. Shakashaka (Triangle Tetromino)

### Game Overview
**Concept:** Fill cells with triangles (4 orientations) to form complete rectangles. Numbers show adjacent triangle count.

**Core Mechanic:**
- Grid size: 4x4 to 8x8
- Black cells are immovable (walls)
- Empty cells get triangles in 4 rotations: ↙ ↖ ↗ ↘
- Triangles must form rectangular regions
- Number in black cell = count of adjacent triangles touching it
- Each black cell forms corner of rectangles formed by triangles

### Visual Layout Example (4x4)
```
┌─────────────────────┐
│ ◺  │  0  │ ◹  ◹     │
├─────────────────────┤
│ ◹  │ ◺  │ ◻ ◻      │
├─────────────────────┤
│ ◻  │ ◹  │  2  ◻     │
├─────────────────────┤
│ ◺  ◺ │  1  │ ◹     │
└─────────────────────┘

Legend: ◺◹ = triangles, ◻ = rectangles, 0,1,2 = numbers
```

### Scaling Progression

| Level Range | Grid | Black Cells | Rectangle Complexity | Time |
|-------------|------|-----------|---------------------|------|
| 0-9 | 4x4 | 25% | Simple (2-4 cell rectangles) | None |
| 10-19 | 5x5 | 25% | Simple | None |
| 20-29 | 6x6 | 30% | Medium (1x4, 2x2, 2x3) | 120s |
| 30-39 | 6x6 | 35% | Medium-Complex | 90s |
| 40-49 | 7x7 | 35% | Complex (L-shaped regions) | 60s |
| 50-59 | 8x8 | 40% | Complex | 45s |
| 60-69 | 7x7 | 40% | Very complex (tight fitting) | 30s |
| 70+ | 8x8 | 45% | Expert | Variable |

---

## 5. Norinori (Region Coloring)

### Game Overview
**Concept:** Shade exactly 2-4 cells per region. Shaded cells must connect; no 2x2 squares entirely shaded.

**Color Scheme:**
```
Cell bg (unshaded): #F5F4F0
Cell bg (shaded): #8B7E8F (dustyMauve)
Region border: #D8D3CC, 2px
Region number: Shows target shade count (2, 3, or 4)
```

### Scaling Progression

| Level | Grid | Regions | Shade Count | Connectivity |
|-------|------|---------|------------|--------------|
| 0-9 | 5x5 | 5-6 | All same (2s) | Simple |
| 10-19 | 6x6 | 6-8 | Mixed (2,3) | Medium |
| 20-39 | 7x7 | 8-10 | Mixed (2,3,4) | Complex |
| 40+ | 8x8 | 12+ | All different | Expert |

---

## 6. Yin-Yang (Connectivity & Coloring)

### Game Overview
**Concept:** Color cells black/white with connectivity rules. No 2x2 square can be single color.

**Rules:**
- All black cells form one connected group
- All white cells form one connected group
- No 2x2 square entirely black
- No 2x2 square entirely white
- Some cells pre-colored as starting clues

**Color Scheme:**
```
White cell: #F5F4F0
Black cell: #2C2A27
Selected: #8B7E8F border, 2px
Connectivity glow: Pulse animation, 150ms
```

### Scaling Progression

| Level | Grid | Pre-colored | Connectivity Tightness |
|-------|------|-----------|------------------------|
| 0-9 | 5x5 | 8 cells | Obvious groups |
| 10-19 | 6x6 | 6 cells | Medium |
| 20-39 | 7x7 | 4 cells | Tight |
| 40+ | 8x8 | 2 cells | Expert |

---

## 7. Thermostat (Thermometers)

### Game Overview
**Concept:** Place thermometer shapes on grid; numbers show filled mercury cells. Mercury rises from bulb.

**Visual:**
- Thermometer shape: Bulb at one end, thin stem, mercury fills upward
- Row/column number: Shows how many cells filled with mercury
- Mercury animates rising from bulb (visual satisfaction)

**Color Scheme:**
```
Thermometer bg: #E8F0F5 (light blue)
Mercury: #D4656F (red) → #8B3B47 (dark red gradient)
Bulb: #B8A8C0 (mauve circle)
Stem: #D8D3CC (light gray)
Number: #1C1A18 (dark), 18px
```

### Scaling Progression

| Level | Grid | Thermometer Count | Number Density | Orientation |
|-------|------|-----------------|----------------|-------------|
| 0-9 | 5x5 | 3-4 | 50% | Horizontal/Vertical |
| 10-19 | 6x6 | 4-5 | 60% | Horizontal/Vertical |
| 20-39 | 6x6 | 5-6 | 70% | Mixed angles (45°) |
| 40+ | 7x7 | 6-7 | 80% | All angles |

---

# TIER 3: EXPERIMENTAL GAMES

## 8. Chain Breaker (Original - Real-Time + Puzzle Hybrid)

### Game Overview
**Concept:** Colored chains advance toward center. Player places "break" pieces to stop them before reaching center.

**Unique Feature:** Real-time puzzle (not turn-based) — creates urgency + strategy.

**Mechanics:**
- Grid with center point
- 4 colored chains (red, blue, green, yellow) emanate from edges
- Chains move toward center at different speeds
- Player places "break" pieces (walls) to block/redirect chains
- If chain reaches center before break placed, game over
- As levels progress: more chains, faster movement, more complex paths

**Visual:**
```
┌──────────────────────────────┐
│  Chain Breaker            L8  │
├──────────────────────────────┤
│  🔴🟢🔴                      │
│  ↓                            │
│  🟢→→→→→→→→→🟢                │
│           ▓                   │
│  ↑ 🔵  ↑  X (center)          │
│  🔵←←←←←←←←🔵                 │
│              ↓                │
│              🟡🟢🟡           │
│                               │
│ Chains: 4 | Break: 3 | Speed: ▓░░ │
├──────────────────────────────┤
│ [Place Break] [Rotate] [Reset]│
└──────────────────────────────┘
```

### Gameplay
1. Chains advance each frame (animation)
2. Player taps to place break pieces in grid
3. Break pieces redirect chains or stop them
4. Goal: Prevent ALL chains from reaching center for 60 seconds
5. Success: Advance to next level (more chains, faster speeds)

### Scaling Progression

| Level | Chains | Speed | Complexity | Time Limit |
|-------|--------|-------|-----------|-----------|
| 0-9 | 1-2 | Slow (1 cell/sec) | Single path | 90s |
| 10-19 | 2-3 | Medium (1.5 cell/sec) | Branching | 80s |
| 20-39 | 3 | Medium-Fast (2 cell/sec) | Complex weaving | 70s |
| 40-59 | 3-4 | Fast (2.5 cell/sec) | Very complex | 60s |
| 60+ | 4 | Very fast (3+ cell/sec) | Expert | 50s |

### Visual Design

**Color Scheme:**
```
Chain colors: 🔴Red, 🟢Green, 🔵Blue, 🟡Yellow
Chain: Gradient with glow, 3px width
Break piece: Gray #D8D3CC with cross pattern
Center: Mauve circle #8B7E8F with pulsing glow
Grid bg: Light #F5F4F0
Grid lines: Subtle #E8E3D8, 1px
Time remaining: Green → Yellow → Red countdown
```

**Animation:**
- Chain movement: Smooth, frame-by-frame
- Break placement: Pop-in 200ms with scale
- Chain collision: Flash 150ms + bounce back effect
- Center glow: Constant pulse (200ms cycle)
- Chain reaches center: Red glow pulse + game over screen

**UI Elements:**
- Chain counter (top right): Shows active chains
- Break pieces available: Shows remaining breaks
- Speed meter: Visual indicator of current speed
- Time remaining: Large countdown timer
- Lives/attempts: Show remaining attempts

---

## 9. Frequency (Original - Audio-Visual Puzzle)

### Game Overview
**Concept:** Match sound wave frequencies visually. Grid shows wave patterns; player adjusts waves to match target.

**Unique Feature:** Novel audio-visual mechanic — no other game on market combines these.

**Mechanics:**
- Grid displays 1-4 wave patterns (sine, square, sawtooth)
- Each wave has: frequency (Hz), amplitude (height), phase (shift)
- Player adjusts parameters to match target pattern
- Levels increase complexity: more waves, tighter tolerances, hidden targets
- Audio feedback (optional): Hear the waves to verify

**Visual:**
```
┌────────────────────────────────┐
│  Frequency                   L5 │
├────────────────────────────────┤
│                                 │
│  Target: ∿∿∿∿                  │
│  ─────────────────────          │
│                                 │
│  Your Wave:  ∿∿∿∿              │
│  ─────────────────────          │
│  Freq: 100Hz  [─────] Amp: 5    │
│  Phase: 45°   [─────]           │
│                                 │
│  Similarity: ████████░░ 80%    │
├────────────────────────────────┤
│ [Hear Target] [Hear Yours] [Check]│
└────────────────────────────────┘
```

### Gameplay
1. Show target wave pattern
2. Player adjusts frequency, amplitude, phase sliders
3. Wave updates in real-time
4. Goal: Match target pattern with 85%+ accuracy
5. Audio feedback available (optional toggle)
6. As levels progress: more waves, tighter tolerances, hidden targets (player adjusts blind)

### Scaling Progression

| Level | Waves | Target Visibility | Tolerance | Hidden Mode |
|-------|-------|------------------|-----------|------------|
| 0-9 | 1 | Visible | 70% match | No |
| 10-19 | 1 | Visible | 80% match | No |
| 20-29 | 2 | Visible | 85% match | No |
| 30-39 | 2 | Partially hidden | 90% match | 50% hidden |
| 40-49 | 3 | Mostly hidden | 95% match | 70% hidden |
| 50-59 | 3 | Hidden | 95% match | Fully hidden (audio only) |
| 60+ | 4 | Hidden | 98% match | Fully hidden + audio toggleable |

### Visual Design

**Color Scheme:**
```
Wave target: #8B7E8F (dustyMauve), 2px
Wave player: #5F7A8F (slate blue), 2px, glowing
Waveform bg: #F5F4F0, with grid lines #E8E3D8
Slider bg: #D8D3CC
Slider handle: #8B7E8F, 16px circle
Similarity meter: 🟢Green (>80%) → 🟡Yellow (60-80%) → 🔴Red (<60%)
```

**Animation:**
- Wave drawing: Smooth Bézier curve animation
- Slider drag: Real-time wave update
- Similarity pulse: 200ms pulse when close to target
- Target reveal: Fade-in 500ms at level start

**UI Elements:**
- Target wave (static)
- Player wave (dynamic)
- Frequency slider: 50-500Hz range
- Amplitude slider: 1-10 range
- Phase slider: 0-360° range
- Similarity percentage: Large, updates in real-time
- Audio toggle: Play/stop button for sound preview

---

## 10. Vault Builder (Original - Strategy + Planning)

### Game Overview
**Concept:** Design a vault security system. Player path must reach vault center; thieves must fail.

**Unique Feature:** Real-time emergent puzzle — player designs, then watches thieves attempt to break in.

**Mechanics:**
- Floor plan grid (8x8 to 10x10)
- Player places: doors, locks, pressure plates, vaults
- Player starts at edge, must reach center vault
- Thieves spawn at random edges, attempt to reach center
- Thieves have different strategies: random, smart (pathfinding), speed
- Level fails if thief reaches center before player completes vault
- Thief AI learns (harder thieves on later levels)

**Visual:**
```
┌──────────────────────────────┐
│  Vault Builder             L12│
├──────────────────────────────┤
│                              │
│  ╔══╗   ╔═════╗   ╔════╗   │
│  ║  ╠═══╣ P   ║   ║ T1 ║   │
│  ║  ║   ╚═════╝   ╚════╝   │
│  ╚══╝     ╔═╗              │
│     ╔═════╣V╠════╗          │
│     ║  T2 ╚═╝    ║          │
│     ╚═════════════╝          │
│                              │
│  Status: Vault Designed      │
│  Thieves: 3 | Player: Ready  │
├──────────────────────────────┤
│ [Place Door] [Lock] [Trap] [Play]│
└──────────────────────────────┘
```

### Gameplay Flow
1. **Design Phase:** Player places vault, doors, locks, traps
2. **Play Phase:** Player reaches vault (press "Go"); thieves spawn
3. **Watch Phase:** Thieves attempt break-in; watch if they succeed
4. **Result:** Player wins if vault secured + reached center
5. **Next Level:** More aggressive thieves, tighter time limits

### Scaling Progression

| Level | Thieves | Difficulty | Time Limit | Vault Size |
|-------|---------|-----------|-----------|-----------|
| 0-9 | 1 | Random | 120s | 2x2 |
| 10-19 | 2 | Random + Smart | 100s | 2x2 |
| 20-39 | 3 | Smart + Fast | 80s | 3x3 |
| 40+ | 4 | Expert AI | 60s | 4x4 |

### Visual Design

**Color Scheme:**
```
Floor: #F5F4F0 (light)
Wall: #2C2A27 (dark gray), 3px
Door: #8B7E8F (mauve), can open
Lock: #D4889C (rose), on door
Pressure plate: #B8A8C0 (mauve), on floor
Vault: #A89FB0 (mauve), pulsing glow
Player: 🟢Green, 20px circle
Thief 1: 🔴Red
Thief 2: 🔵Blue
Thief 3: 🟡Yellow
Path taken: Faint trail #E8DFF0
```

**Animation:**
- Door opening: 200ms swing
- Lock glowing: 300ms pulse when triggered
- Pressure plate: Flash 150ms when stepped on
- Thief movement: Smooth path animation
- Player reaching vault: Green glow explosion + success

**UI Elements:**
- Floor plan editor
- Building palette (door, lock, trap, vault)
- Thief count display
- Time remaining countdown
- "Play Simulation" button
- Success/failure overlay

---

# VISUAL DESIGN SYSTEM

## Unified Color Palette (All Games)

### Primary Colors
```
Light Background: #F5F4F0 (zen light)
Dark Gray: #2C2A27 (walls, black cells)
Text Primary: #1C1A18 (dark text)
Text Secondary: #5F7A8F (slate blue)
Text Muted: #9B8FA0 (muted mauve)
```

### Accent Colors (Game-Specific)
```
Futoshiki: #8B7E8F (dustyMauve) + #A89FB0 (light mauve)
Kuromasu: #2C2A27 (black) + #E0D5E8 (white glow)
Skyscrapers: #7FA8C9 (slate blue) + #E8F0F5 (light blue)
Shakashaka: #D4656F (red) + #8B3B47 (dark red)
Norinori: #8B7E8F (purple) + #E8DFF0 (light purple)
Yin-Yang: #2C2A27 (black) + #F5F4F0 (white)
Thermostat: #D4656F (red) + #B8A8C0 (mauve)
Chain Breaker: #D4656F (red), #5FD46F (green), #6F8FD4 (blue), #D4B95F (yellow)
Frequency: #7FA8C9 (blue) + #E8F0F5 (light blue)
Vault Builder: #8B7E8F (mauve) + #D4889C (rose)
```

## Typography

```
Headers: Google Fonts Outfit, Bold 22px
Labels: Google Fonts Outfit, Regular 14px
Numbers/Values: Google Fonts Outfit, Bold 18px
UI Buttons: Google Fonts Outfit, Bold 14px
Clues/Numbers: Google Fonts Outfit, Bold 16-24px (context-dependent)
```

## Grid Styling (Universal)

```
Cell size: 48px (responsive to screen size)
Cell border: 1px #D8D3CC
Cell padding: 4px
Border radius: 4px
Shadow: 0 2px 4px rgba(0,0,0,0.08)
Selected: 2-3px border in game-specific accent color
Highlight: 30-50% opacity accent color overlay
```

## Animation Principles

```
Cell fill/interaction: 200ms ease-out
Highlight/glow: 300ms ease-in-out
Error shake: 200ms (2-3 amplitude)
Transition between screens: 300ms fade
Wave/flow animations: 400-500ms smooth curves
Confetti/celebration: 800ms with gravity physics
```

## Responsive Design

```
Mobile (< 360px): 40px cells, 80% grid width
Standard (360-600px): 48px cells, 85% grid width
Tablet (600-900px): 56px cells, 90% grid width
Desktop (> 900px): 64px cells, 85% grid width, centered
```

---

# IMPLEMENTATION COMPLEXITY ASSESSMENT

## Development Estimates (Experienced Flutter Developer)

| Game | Mechanics | Procedural Gen | UI Complexity | Scaling System | Total Est. |
|------|-----------|----------------|--------------|----------------|-----------|
| Futoshiki | Medium | Medium (constraint solver) | Medium | 2-3 weeks, moderate | **2.5 weeks** |
| Kuromasu | Medium | Medium (flood fill) | Medium | 2-3 weeks, moderate | **2.5 weeks** |
| Skyscrapers | Medium | Medium (clue generator) | Medium-High | 2.5-3 weeks, complex | **3 weeks** |
| Shakashaka | Hard | Hard (geometry) | Hard | 2-3 weeks, complex | **3 weeks** |
| Norinori | Medium | Medium (region solver) | Medium | 2 weeks, simple | **2.5 weeks** |
| Yin-Yang | Medium | Medium (connectivity) | Medium | 2 weeks, simple | **2.5 weeks** |
| Thermostat | Easy-Medium | Easy | Medium | 2 weeks, simple | **2 weeks** |
| Chain Breaker | Hard | Hard (pathfinding + real-time) | High | 3-4 weeks, complex | **4 weeks** |
| Frequency | Hard | Medium | Hard (graphics) | 3-4 weeks, novel | **4 weeks** |
| Vault Builder | Hard | Hard (AI thieves) | Hard | 3-4 weeks, complex | **4 weeks** |

## Recommended Release Order

### Phase 1: Quick Wins (2-3 weeks each)
1. Thermostat (easiest, 2 weeks)
2. Norinori (simple regions, 2.5 weeks)
3. Yin-Yang (simple connectivity, 2.5 weeks)

### Phase 2: Core Logic Puzzles (3 weeks each)
4. Futoshiki (proven popular, 2.5 weeks)
5. Kuromasu (elegant puzzle, 2.5 weeks)
6. Skyscrapers (high engagement, 3 weeks)

### Phase 3: Advanced (3-4 weeks each)
7. Shakashaka (geometric, 3 weeks)
8. Chain Breaker (innovative real-time, 4 weeks)
9. Frequency (novel concept, 4 weeks)
10. Vault Builder (complex AI, 4 weeks)

**Total Timeline:** 6-7 months for all 10 games (if parallelized: 3-4 months with team of 2-3 devs)

---

## Complexity Legend

**Mechanics Complexity:**
- Easy: Simple placement/marking (Thermostat, Yin-Yang)
- Medium: Constraint satisfaction (Futoshiki, Kuromasu, Norinori)
- Hard: Geometry or AI (Shakashaka, Chain Breaker, Vault Builder)

**Procedural Generation:**
- Easy: Random placement (Thermostat)
- Medium: Constraint solver-based (most logic puzzles)
- Hard: Geometry or pathfinding algorithms (Shakashaka, Frequency)

**UI Complexity:**
- Medium: Standard grid + numbers (Futoshiki, Kuromasu)
- Medium-High: Grid + surrounding clues (Skyscrapers)
- Hard: Custom graphics, animations, real-time updates (Chain Breaker, Frequency, Vault Builder)

**Scaling System:**
- Simple: Grid size + time pressure (Norinori, Yin-Yang, Thermostat)
- Moderate: Grid size + constraint density (Futoshiki, Kuromasu)
- Complex: Multiple secondary mechanics (Skyscrapers, Shakashaka, Chain Breaker)

---

## Quality Assurance Checklist (Per Game)

- [ ] Procedural generation creates valid, solvable puzzles
- [ ] Difficulty curve is smooth (no sudden jumps)
- [ ] UI is responsive (no lag on 60+ cell grids)
- [ ] Animations are smooth (60fps)
- [ ] Hints work correctly and don't reveal answer
- [ ] Level progression saves/restores properly
- [ ] Scaling mechanics work as designed through 70+ levels
- [ ] Color contrast meets WCAG AA standards
- [ ] Accessibility labels added for screen readers
- [ ] Sound/haptic feedback functional (if applicable)
- [ ] Battery impact tested on low-end devices
- [ ] Tested on Android, iOS, Web platforms

---

## Recommendation Summary

**Start With:**
1. **Futoshiki** (high impact, proven, good scaling)
2. **Kuromasu** (elegant, satisfying, scales well)
3. **Skyscrapers** (unique mechanic, high engagement)

**Add Later:**
4. **Shakashaka** (geometric variety)
5. **Norinori** (region-based puzzle diversity)
6. **Yin-Yang** (connectivity puzzle)

**Long-term (If Resources Permit):**
7. **Thermostat** (quick add, low effort)
8. **Chain Breaker** (innovative real-time)
9. **Frequency** (novel audio-visual)
10. **Vault Builder** (complex strategy)

This gives CogniQ a portfolio of 18-22 games with excellent mechanical diversity, all scaling to 70+ levels, all fitting the logic-puzzle positioning.

---

**Document prepared:** July 18, 2026  
**Total game concepts:** 10 (3 Tier 1, 3 Tier 2, 4 Tier 3)  
**Visual design:** Complete for all  
**Development timeline:** 6-7 months (sequential) or 3-4 months (team of 2-3)
