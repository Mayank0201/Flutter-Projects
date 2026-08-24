# Logic-Grid Puzzles — Backlog Spec (55 Unimplemented Types)

50 levels of each

This document lists **55 puzzle types** suggested for CogniQ that have **not yet been implemented**. It contains **game logic specs only** — data models, rules, generation strategies, and solution-checking. Wire these into your existing themed UI.

---

## Already Implemented (Excluded)

The following games are **already shipped or in beta** and are NOT covered here:

**Mainline:** Sudoku, Star Battle, Nonogram, Word Ladder, Word Guess (Wordle), Word Hive (Spelling Bee), Word Search, Word Builder, Word Climb, Hangman, Mahjong, Mine Finder, Number Memory, Odd Color Out, Patches (Shikaku), Reaction, Sequence Memory, Spectrum, Grid Path (Zip), Flag Finder

**Beta:** Killer Sudoku, Binairo (Takuzu), Kakuro, Futoshiki, Skyscrapers, KenKen (Calcudoku), Sumplete, Light Up (Akari), Nurikabe, Color Flood, Cipher Decoder, Chess Puzzles, Numberlink, Hashi (Bridges), Masyu, Slitherlink, Circuit Guide (Pipes/Net), Rush Hour, Sliding Tile (15-Puzzle), Math Sprint, Mental Math Blocks, Map Memory, Pattern Lock, Buzzer

---

## Scope Assumptions

- You provide the rendering (grid widgets, input handling, theme).
- This spec gives you: the **state model**, the **rules**, **how to generate puzzles**, and **how to validate a solve** for each type.
- Difficulty is generally controlled by grid size and how many clues are removed/given.
- Build effort: 🟢 Easy · 🟡 Medium · 🔴 Hard

---

## Shared Foundations

### Core Grid Model

Use one generic grid container reused across puzzles:

```dart
class PuzzleGrid<T> {
  final int rows;
  final int cols;
  final List<T> cells; // length rows*cols, index = r*cols + c
  T at(int r, int c);
  void set(int r, int c, T value);
  bool inBounds(int r, int c);
  Iterable<(int, int)> neighbors4(int r, int c); // up/down/left/right
  Iterable<(int, int)> neighbors8(int r, int c); // includes diagonals
}
```

- Keep cell values as small ints or enums, not objects, for cheap copying during generation/solving.
- Separate three layers: **solution** (full answer), **givens** (clues shown to player), **playerState** (user input). Validation checks rules — never compares against stored solution directly.

### Universal Generation Pattern

1. Generate a **complete valid solved grid** (puzzle-specific).
2. **Remove cells / convert to clues** one at a time, in random order.
3. After each removal, run the **solver**. If still **exactly one** solution, keep; otherwise revert.
4. Stop when no more cells can be removed, or at target difficulty.

### Uniqueness Solver Pattern

```dart
int countSolutions(grid, {int cap = 2}) {
  find the most-constrained empty cell;
  if none empty -> return 1;
  for each candidate value valid here:
     place it;
     count += countSolutions(...);
     undo;
     if count >= cap -> return count; // early exit
  return count;
}
```

### Daily / Streak Loop (All Puzzles)

- Seed RNG with the **date** (`yyyymmdd`) for daily puzzles.
- Track per type: current streak, best streak, completion timestamp, best time.
- Separate "daily" (date-seeded) and "endless/practice" (random-seeded) modes.

### Shared UI Systems

Cluster builds around input models to maximize reuse:
- **Latin-square entry** — Suguru, Kropki, Renzoku, Sandwich Sudoku, Thermo Sudoku, Arrow Sudoku, Ripple Effect, Hidato, Calcudoku
- **Cell shading** — Tapa, LITS, Norinori, Yin-Yang, Kuromasu, Heyawake, Nurimisaki, Kurotto, Mosaic, Cave, Aqre, Shakashaka, Thermometers, Static Minesweeper
- **Region drawing** — Fillomino, Galaxies, Araf, Sashigane, Tatamibari, Dominosa, Cell Tower
- **Loop/path drawing** — Yajilin, Shingoki, Castle Wall, Country Road, Snake
- **Object placement** — Tents & Trees, Battleships, Statue Park, Aquarium

---

## Category 1 — Shading / Region-Shading Puzzles

*Pairs with: existing Nurikabe, Light Up, Nonogram, Mine Finder*

---

### 1. Tapa 🟡

**Rule:** Clues describe the lengths of shaded runs in the 8 cells around them; shaded cells form one connected group, no 2×2 block. Nurikabe's spicier cousin.

**Model:** `PuzzleGrid<int>` where cells are either clue cells (holding run-length lists) or shade-able (empty/shaded).

**Generate:** Place clue cells with valid surrounding run-length lists. Build a connected shading satisfying all clue constraints and the no-2×2 rule. Verify uniqueness with a constraint-propagation solver.

**Validate:** All clue cells' 8-neighbor shaded runs match their values; shading is connected; no 2×2 shaded block.

---

### 2. LITS 🟡

**Rule:** Shade one tetromino in each bordered region; all shading connects; identical tetrominoes never touch orthogonally; no 2×2 block.

**Model:** Grid divided into regions + `PuzzleGrid<bool>` shading layer. Each region must contain exactly one L/I/T/S tetromino shape.

**Generate:** Partition grid into regions (size ≥ 4). For each region, choose a valid tetromino placement. Ensure global connectivity, no matching adjacent tetrominoes, no 2×2. Backtrack if constraints fail.

**Validate:** Exactly one tetromino per region; all shading connected; touching tetrominoes differ in type; no 2×2.

---

### 3. Norinori 🟢

**Rule:** Shade exactly two cells per region; every shaded cell pairs with exactly one orthogonal neighbor into a domino.

**Model:** Grid divided into regions + `PuzzleGrid<bool>` shading.

**Generate:** Partition grid into regions. Find a valid 2-cell shading per region where all shaded cells form dominoes. Expose regions as clues (no numbers needed).

**Validate:** Each region has exactly 2 shaded cells; every shaded cell has exactly one shaded orthogonal neighbor.

---

### 4. Yin-Yang 🟢

**Rule:** Fill every cell black or white; each color forms one connected group; no 2×2 of one color.

**Model:** `PuzzleGrid<int>` with values {0 = empty, 1 = black, 2 = white}.

**Generate:** Generate a valid filled grid (both colors connected, no 2×2 monochrome). Remove givens while uniqueness holds.

**Validate:** All cells filled; both colors connected (BFS/DFS); no 2×2 monochrome block.

---

### 5. Kuromasu (Kurodoko) 🟡

**Rule:** Numbered cells state how many cells they can "see" in four directions (including themselves); shade cells (never adjacent, whites connected) to block visibility and make counts true.

**Model:** Grid with numbered clue cells + `PuzzleGrid<bool>` for shading.

**Generate:** Place numbered clues, determine valid shading that satisfies visibility constraints. Shaded cells must not be adjacent; unshaded cells must be connected.

**Validate:** Each numbered cell's visibility count matches its clue; no two shaded cells adjacent; all unshaded cells connected.

---

### 6. Heyawake 🔴

**Rule:** Shade cells per each room's count; no adjacent shading; whites connected; no white line may span more than two rooms. One of the deepest shading puzzles.

**Model:** Grid divided into rooms (with optional counts) + `PuzzleGrid<bool>`.

**Generate:** Partition grid into rooms. Assign counts. Solve with constraint propagation + backtracking. The "no white line spans 3+ rooms" rule makes generation hard — need a strong solver.

**Validate:** Room shade counts match; no orthogonally adjacent shaded cells; whites connected; no unshaded horizontal/vertical line crosses 3+ room boundaries.

---

### 7. Nurimisaki 🔴

**Rule:** Shade so white cells form a snaking connected group where circled cells are dead-end "capes" seeing exactly N cells along the unshaded path.

**Model:** Grid with circled clue cells + `PuzzleGrid<bool>`.

**Generate:** Build a valid white path with cape cells at dead ends, then shade the rest. Verify cape visibility counts. Complex solver needed.

**Validate:** White cells connected; circled cells have exactly one white neighbor (dead end) and see N cells; no 2×2 shaded.

---

### 8. Kurotto 🟢

**Rule:** Circles state the total size of the shaded blobs (connected shaded groups) touching them orthogonally.

**Model:** Grid with circled clue cells + `PuzzleGrid<bool>`.

**Generate:** Place clue circles, build valid shading where each circle's adjacent shaded blob sizes sum to its number. Simple constraint propagation.

**Validate:** Each circle's orthogonally adjacent shaded connected components' total size equals the clue.

---

### 9. Mosaic (Fill-a-Pix) 🟢

**Rule:** Minesweeper logic as picture-reveal: each clue counts shaded cells in its 3×3 neighborhood (including itself).

**Model:** `PuzzleGrid<int>` clues (0–9 or null) + `PuzzleGrid<bool>` for shading.

**Generate:** Create a target shaded image. Compute each cell's 3×3 neighborhood shaded count. Expose a subset of counts as clues (enough for uniqueness). Near-trivial generator.

**Validate:** Every clue cell's 3×3 neighborhood shaded count matches its value.

---

### 10. Cave (Corral) 🟡

**Rule:** Draw one closed cave region containing all clues; each clue counts the cells it sees inside the cave (in 4 directions, including itself).

**Model:** Grid with numbered clues + `PuzzleGrid<bool>` (inside/outside cave).

**Generate:** Build a connected cave region containing all clues, then verify visibility counts match. Use constraint propagation from border cells inward.

**Validate:** Cave is connected and contains all clues; each clue's 4-directional visibility within the cave equals its value; cells outside cave border the grid edge.

---

## Category 2 — Region-Division Puzzles

*Pairs with: existing Patches (Shikaku)*

---

### 11. Fillomino 🟡

**Rule:** Divide the grid into polyominoes where every cell's number equals its region's size. Numbers can repeat — two same-sized regions just can't be orthogonally adjacent.

**Model:** `PuzzleGrid<int>` where each cell holds its region size. Regions are implicitly defined by connected same-number groups.

**Generate:** Build a valid region partition, assign sizes. Expose some numbers as givens, remove while uniqueness holds. Deep, endlessly generatable.

**Validate:** Every connected group of same-valued cells has size equal to that value; no two same-sized groups are orthogonally adjacent.

---

### 12. Galaxies (Tentai Show) 🟡

**Rule:** Divide the grid into regions, each rotationally symmetric (180°) around its dot center. Dots may be on cells, edges, or corners.

**Model:** Grid with dot positions (cell/edge/corner) + region assignment per cell.

**Generate:** Place dots, grow rotationally symmetric regions around each until the grid is fully partitioned. Verify uniqueness.

**Validate:** Every cell belongs to exactly one region; each region is 180°-rotationally symmetric around its dot.

---

### 13. Ripple Effect 🟡

**Rule:** Regions of size N contain digits 1..N; if two identical digits appear in the same row or column, they must be at least N cells apart (where N is the digit's value).

**Model:** Grid divided into regions + `PuzzleGrid<int>`.

**Generate:** Partition into regions, fill with 1..N per region satisfying the distance constraint. Remove givens while uniqueness holds.

**Validate:** Each region contains 1..N; same digits in a row/column are ≥ N apart.

---

### 14. Araf 🔴

**Rule:** Each region contains exactly two numbered clues; the region's cell count must fall strictly between those two numbers.

**Model:** Grid with numbered clue cells + region assignment.

**Generate:** Place pairs of clues, grow regions of valid sizes between each pair. Complex — ensuring full grid coverage with valid regions requires sophisticated backtracking.

**Validate:** Every region contains exactly 2 clues; region size is strictly between the two clue values; grid fully covered.

---

### 15. Sashigane 🟡

**Rule:** Divide the grid entirely into L-shaped pieces (right-angle pieces of varying arm lengths). Arrow clues indicate L direction; number clues indicate total piece size.

**Model:** Grid with optional clue cells + L-piece partition.

**Generate:** Tile the grid with L-pieces, place clues. Reuses Shikaku-style region UI. Verify uniqueness with backtracking solver.

**Validate:** Every piece is L-shaped (right angle, two arms); clue constraints satisfied; grid fully covered.

---

### 16. Shakashaka 🔴

**Rule:** Place black half-cell triangles (4 orientations: ◸◹◺◿) so every remaining white area forms a rectangle (upright or at 45° diagonal). Nothing else looks or feels like it.

**Model:** Grid with some black-wall cells + `PuzzleGrid<enum>` for triangle placements. Numbered walls count adjacent triangles.

**Generate:** Complex — must verify all white regions form axis-aligned or diagonal rectangles. Needs specialized geometric solver.

**Validate:** Every contiguous white area (cells without triangles) forms a rectangle; numbered walls have correct adjacent triangle count.

---

### 17. Dominosa 🟢

**Rule:** A full domino set (0-0 through N-N) is hidden in a grid of numbers; recover the unique tiling. The grid shows all the numbers; you draw the domino boundaries.

**Model:** Rectangular grid of numbers + `List<Domino>` pairings. For standard set 0–6: 28 dominoes, 7×8 grid.

**Generate:** Lay out all dominoes of the set in a random valid tiling. Show the numbers, hide the boundaries. Verify uniqueness. Cheap to generate.

**Validate:** Every domino from the set appears exactly once; each pair of adjacent cells forming a domino contains matching numbers from the set.

---

## Category 3 — Object-Placement Puzzles

*Pairs with: existing Star Battle, Light Up (Akari)*

---

### 18. Tents & Trees 🟢

**Rule:** Attach one tent orthogonally to each tree; tents never touch (even diagonally); row/column counts given. Very approachable.

**Model:** Grid with tree positions + `PuzzleGrid<enum>` {empty, tree, tent}. Row/column tent counts as clues.

**Generate:** Place trees randomly, assign a valid tent adjacent to each, compute row/column counts. Verify uniqueness.

**Validate:** Each tree has exactly one orthogonally adjacent tent; each tent is next to exactly one tree; no two tents touch (including diagonally); row/column counts match.

---

### 19. Battleships 🟢

**Rule:** Place a hidden fleet (e.g., 1×4, 1×3, 2×2, 3×1) using row/column ship-segment counts and partial ship clues; ships never touch (even diagonally).

**Model:** Grid + fleet definition + row/col counts + revealed segments. `PuzzleGrid<enum>` {water, ship}.

**Generate:** Place fleet randomly with no touching. Compute row/column counts. Reveal some segments as clues. Verify uniqueness.

**Validate:** Fleet placed correctly (right shapes/sizes); ships don't touch; row/column counts match; revealed clues respected.

---

### 20. Statue Park 🔴

**Rule:** Place a given set of polyominoes (e.g., all 12 pentominoes) into the grid without overlapping or touching orthogonally; black dots must be covered, white dots must not.

**Model:** Grid with dot markers + set of polyomino shapes + placement positions/rotations.

**Generate:** Place polyominoes satisfying dot constraints and non-touching rules. Computationally hard — NP-complete placement problem. Use constraint solver.

**Validate:** All polyominoes placed; no overlapping; no orthogonal touching between different pieces; black dots covered; white dots uncovered.

---

### 21. Aquarium 🟡

**Rule:** Fill regions with water that obeys gravity (water level within a region is flat — all cells at or below the water line are filled); match row/column filled-cell counts.

**Model:** Grid divided into tank regions + water level per region. Row/column fill counts as clues.

**Generate:** Define tank regions. Set water levels. Compute row/column counts. Verify uniqueness. The gravity constraint makes this tractable.

**Validate:** Within each tank, filled cells form a contiguous bottom-up block (gravity); row/column fill counts match clues.

---

### 22. Snake 🟢

**Rule:** Draw a snake of given length between two endpoints using row/column body counts; the snake body never touches itself (even diagonally).

**Model:** Grid with start/end markers + row/col counts + `PuzzleGrid<bool>` for snake path.

**Generate:** Generate a valid non-self-touching snake path of target length. Compute row/column counts. Verify uniqueness.

**Validate:** Single contiguous path from start to end; correct length; no self-touching (including diagonals); row/column counts match.

---

### 23. Kakurasu 🟢

**Rule:** Shade cells so each row and column's shaded cells (weighted by their 1-indexed position) hit target sums. Sumplete-adjacent.

**Model:** `PuzzleGrid<bool>` + row/column target sums. Cell at column j has weight j+1 for row sums; cell at row i has weight i+1 for column sums.

**Generate:** Choose a random shading, compute weighted sums. Verify uniqueness. Very cheap to implement.

**Validate:** For each row, sum of (column-index weights of shaded cells) = row target; same for columns with row-index weights.

---

## Category 4 — Loop & Path Puzzles

*Pairs with: existing Slitherlink, Masyu, Numberlink, Hashi, Circuit Guide*

---

### 24. Yajilin 🔴

**Rule:** Arrows count shaded cells in a direction; a single loop must pass through every non-shaded, non-clue cell. Brilliant loop + shading hybrid.

**Model:** Grid with arrow clue cells (direction + count) + `PuzzleGrid<enum>` {clue, shaded, loop-path} + loop edges.

**Generate:** Build a valid loop + shading configuration satisfying all arrow counts. Needs combined loop/shading solver — hard.

**Validate:** Arrow clues correct; shaded cells not adjacent; loop passes through all remaining cells exactly once as a single closed loop.

---

### 25. Shingoki (Traffic Lights) 🟡

**Rule:** Loop puzzle: white circles = pass straight through, black circles = turn on the circle, numbers on circles give the segment length from that circle to the next turn. The natural "Masyu 2."

**Model:** Grid with circle clue cells (color + optional number) + loop edges.

**Generate:** Generate a valid loop, place circles at cells where the loop's behavior matches circle rules. Verify uniqueness.

**Validate:** Single closed loop; white circles: loop goes straight; black circles: loop turns; numbered circles: segment length matches.

---

### 26. Castle Wall 🔴

**Rule:** Clues sit inside or outside the loop and count loop segments in a direction (with arrows). White clues are outside, black clues inside.

**Model:** Grid with clue cells (color + direction + count) + loop edges.

**Generate:** Build a valid loop, place clues with correct counts/positions. High difficulty ceiling. Strong solver required.

**Validate:** Single closed loop; each clue's directional loop-segment count matches; white clues outside, black clues inside.

---

### 27. Country Road 🔴

**Rule:** The loop must visit every bordered region exactly once; numbered regions fix how many cells the loop uses there. Loop cells form a single closed path.

**Model:** Grid divided into regions (optional numbers) + loop edges.

**Generate:** Partition grid, route a loop through all regions. Numbered regions constrain path length within them. Complex solver.

**Validate:** Single closed loop; visits every region; numbered regions have correct cell count on loop; no region skipped.

---

### 28. Hidato (Hidoku) 🟡

**Rule:** Place consecutive numbers 1..N so each connects to the next via orthogonal or diagonal adjacency. Some numbers given as clues.

**Model:** `PuzzleGrid<int>` with 0 = empty. Given cells are fixed.

**Generate:** Build a Hamiltonian path on the grid (with diagonal adjacency), assign numbers 1..N along it. Remove intermediate numbers while uniqueness holds. Shares logic with Grid Path (Zip).

**Validate:** Numbers 1..N all present; each consecutive pair (k, k+1) occupies cells that are orthogonally or diagonally adjacent.

---

## Category 5 — Number / Latin-Square / Sudoku-Variant Puzzles

*Pairs with: existing Sudoku, Futoshiki, Kakuro, Killer Sudoku, Skyscrapers, KenKen*

---

### 29. Suguru (Tectonic) 🟡

**Rule:** Fill each region of size N with 1..N; identical numbers never touch, even diagonally. The best Sudoku-adjacent puzzle most players haven't met.

**Model:** Grid divided into irregular regions + `PuzzleGrid<int>`.

**Generate:** Partition grid into regions (sizes 1–5 typical). Fill each with 1..N respecting diagonal non-adjacency. Remove givens while uniqueness holds.

**Validate:** Each region contains exactly 1..N; no two identical numbers are orthogonally or diagonally adjacent.

---

### 30. Kropki 🟢

**Rule:** Latin square (1–N, no repeats per row/col) where white dots between cells mark consecutive neighbors (|a-b|=1) and black dots mark doubles (a=2b or b=2a). Absence of dot means neither relation holds.

**Model:** Latin-square grid + dot annotations on cell edges (white/black/none).

**Generate:** Generate random Latin square. Place dots per the rules. Verify uniqueness. Extends Futoshiki UI directly.

**Validate:** Latin-square property; white dots: consecutive; black dots: double; no dot: neither.

---

### 31. Renzoku 🟢

**Rule:** Latin square where dots between cells mark consecutive neighbors; absence of dot explicitly forbids consecutiveness. Futoshiki's sibling.

**Model:** Same as Kropki but with only one dot type (consecutive vs. not).

**Generate:** Generate Latin square, place dots for consecutive pairs. Verify uniqueness.

**Validate:** Latin-square property; dotted pairs consecutive; undotted pairs not consecutive.

---

### 32. Sandwich Sudoku 🟡

**Rule:** Standard Sudoku rules + outside clues give the sum of digits between the 1 and the 9 in each row/column. Popular with variant-Sudoku fans.

**Model:** Standard Sudoku grid + `List<int?>` for top/bottom/left/right sandwich clues.

**Generate:** Generate solved Sudoku. Compute sandwich sums (digits strictly between the 1 and 9 in each line). Use as clues. Remove some standard givens + some sandwich clues while uniqueness holds.

**Validate:** Standard Sudoku valid; each sandwich clue matches the sum of digits between 1 and 9 in that line.

---

### 33. Thermo Sudoku 🟡

**Rule:** Standard Sudoku + digits must strictly increase along thermometer shapes (from bulb to tip).

**Model:** Sudoku grid + `List<Thermometer>` where `Thermometer { List<(int,int)> cells; }` ordered bulb-to-tip.

**Generate:** Generate solved Sudoku. Place thermometers along paths where values already increase. Remove standard givens while uniqueness holds.

**Validate:** Standard Sudoku valid; each thermometer's digits strictly increase from bulb to tip.

---

### 34. Arrow Sudoku 🟡

**Rule:** Standard Sudoku + digits along each arrow sum to the digit in its circle (the arrow's starting cell).

**Model:** Sudoku grid + `List<Arrow>` where `Arrow { (int,int) circle; List<(int,int)> shaft; }`.

**Generate:** Generate solved Sudoku. Place arrows where the circle value equals the sum of shaft values. Remove givens while uniqueness holds.

**Validate:** Standard Sudoku valid; for each arrow, sum of shaft digits = circle digit.

---

### 35. Schrödinger-Cell Puzzles 🔴

**Rule:** A Sudoku variant where some cells hold two possible values simultaneously until surrounding logic collapses them. Cutting-edge design space.

**Model:** Sudoku grid where select cells can hold `Set<int>` of size 2 instead of a single digit. Rows/columns/boxes treat these as satisfying constraints for *either* value.

**Generate:** Extremely hard — need specialized solver that tracks superposition states. Research-level generation.

**Validate:** Standard Sudoku rules hold when each Schrödinger cell is resolved to one of its two values; resolution must be consistent.

---

### 36. Cryptarithms (Verbal Arithmetic) 🟡

**Rule:** Letters stand for digits; make the arithmetic work (SEND + MORE = MONEY). Each letter maps to a unique digit; leading digits ≠ 0.

**Model:** `List<String>` operands + operator + result. `Map<String, int>` letter-to-digit mapping.

**Generate:** Choose a valid equation template, assign digits, derive the puzzle. Verify unique mapping. Classic — barely present on mobile.

**Validate:** Each letter maps to a unique digit; no leading zeros; the arithmetic equation holds.

---

### 37. Mathler 🟢

**Rule:** Wordle for equations: guess a 6-character mathematical expression that equals a given target number, with color feedback per character.

**Model:** Target number + `List<String>` guesses + color feedback (green/yellow/gray per position).

**Generate:** Choose a valid expression (e.g., `12+3*4`) and compute its value as the target. Multiple valid expressions may exist — that's fine (like Wordle having multiple valid guesses).

**Validate:** Player's expression evaluates to the target; correct character positions match.

---

## Category 6 — Word Puzzles

*Pairs with: existing Word Ladder, Word Guess, Word Hive, Word Search, Word Builder*

---

### 38. Waffle (Letter Swap Grid) 🟡

**Rule:** A grid of crossing words (waffle shape) with letters scrambled; swap letters to fix all words, minimizing swap count. Wordle-style color feedback (green = correct position, yellow = wrong position right letter).

**Model:** Waffle-shaped grid of letter cells + target words + swap tracking.

**Generate:** Choose intersecting words, place them correctly, then scramble letters (keeping some green). Track optimal swap count.

**Validate:** All horizontal and vertical words are valid dictionary words; ≤ optimal swap count for bonus.

---

### 39. Semantle (Semantic Guess) 🟡

**Rule:** Guess the hidden word by *meaning*: feedback is semantic similarity score (0–100), not letter matching. Totally different flavor.

**Model:** Hidden target word + word embedding model (precomputed similarity scores) + `List<(String, double)>` guesses with scores.

**Generate:** Choose a target word. Requires a word-embedding dictionary (e.g., Word2Vec/GloVe precomputed for top N words).

**Validate:** Player guesses the exact target word.

**Note:** Requires bundling or fetching word embedding data — non-trivial asset requirement.

---

### 40. Anagram Hive 🟢

**Rule:** Make as many words as possible from a fixed set of 7 letters with one mandatory center letter. Score based on word count and length. Massive daily-ritual appeal.

**Model:** 7 letters (1 center + 6 outer) + valid word list + found words.

**Generate:** Choose a set of 7 letters that yields a good number of valid words (pre-filter dictionary). Ensure at least one pangram (uses all 7).

**Validate:** Each submitted word uses only the available letters, includes the center letter, and exists in the dictionary.

**Note:** You already have Word Hive — this may need differentiation or could replace it. Consider if this is a duplicate.

---

### 41. Cell Tower (Word-Grid Division) 🟡

**Rule:** Divide a letter grid into regions where each region spells a valid dictionary word. Essentially "word Shikaku."

**Model:** Grid of letters + region partition. Each region's letters (in reading order or path order) spell a word.

**Generate:** Place valid words in the grid as contiguous regions, fill remaining cells. Verify unique partition. Reuses Shikaku interaction model.

**Validate:** Grid fully partitioned; each region's letters form a valid dictionary word.

---

## Category 7 — Bonus & Modern Picks

---

### 42. Slant (Gokigen Naname) 🟡

**Rule:** Fill every cell with a `/` or `\` diagonal; circled numbers at grid intersections count the diagonals touching that vertex; no closed loops of diagonals may form.

**Model:** `PuzzleGrid<enum>` {empty, forward_slash, back_slash} + clue numbers at vertices (grid intersections).

**Generate:** Fill grid with valid diagonals (no closed loops). Compute vertex counts. Expose subset as clues. Verify uniqueness.

**Validate:** Every cell has a diagonal; vertex counts match clues; no closed loop of connected diagonals.

---

### 43. Stitches 🟢

**Rule:** "Stitch" neighboring regions together: each pair of adjacent regions is connected by exactly one stitch (a pair of orthogonally adjacent cells, one in each region). Row/column counts limit stitch endpoints.

**Model:** Grid divided into regions + stitch pairs + row/col endpoint counts.

**Generate:** Partition grid, place valid stitches between all adjacent region pairs. Compute row/column counts. Verify uniqueness.

**Validate:** Each adjacent region pair has exactly one stitch; row/column endpoint counts match.

---

### 44. Thermometers (Grid) 🟢

**Rule:** Fill thermometers from the bulb upward (contiguously from base); row/column filled-cell counts given. Gentle difficulty.

**Model:** Grid with thermometer shapes (each a path of cells from bulb to tip) + row/col fill counts.

**Generate:** Place thermometers in the grid. Choose fill levels. Compute row/column counts. Verify uniqueness. Simple.

**Validate:** Each thermometer filled contiguously from bulb; row/column fill counts match.

**Note:** Thermometers beta already exists — verify if this is a different mechanic or needs merging.

---

### 45. Tatamibari 🔴

**Rule:** Divide the grid into rectangles/squares: `+` clues mean the piece is a square, `−` means wider than tall, `|` means taller than wide. One clue per piece, all pieces have a clue.

**Model:** Grid with clue cells (+/−/|) + rectangular partition.

**Generate:** Partition grid into rectangles each containing exactly one clue satisfying shape constraints. Hard — constraint satisfaction with geometric constraints.

**Validate:** Grid fully covered by non-overlapping rectangles; each contains exactly one clue; shape matches clue type.

---

### 46. Aqre 🟡

**Rule:** Shade cells per region counts so all shading connects; no four consecutive shaded or unshaded cells in any row or column.

**Model:** Grid divided into regions (with shade counts) + `PuzzleGrid<bool>`.

**Generate:** Partition grid, assign shade counts. Find valid connected shading with no 4-in-a-row constraint. Verify uniqueness.

**Validate:** Region shade counts match; all shading connected; no 4 consecutive same-state cells in any row/column.

---

### 47. Static Minesweeper 🟢

**Rule:** A fixed Minesweeper board solvable by pure logic — no clicking risk. All mine positions deterministic from clues. Converts the game everyone knows into a deduction puzzle.

**Model:** `PuzzleGrid<int>` for number clues + `PuzzleGrid<enum>` {unknown, mine, safe} for player state.

**Generate:** Place mines, compute adjacency counts. Verify that a logical solver (constraint propagation over number cells) can determine all mine positions without guessing. Regenerate if not.

**Validate:** All mines correctly identified; all safe cells correctly marked.

**Note:** You already have Mine Finder — differentiate as "pure deduction" mode vs. the existing click-to-reveal mode.

---

### 48. Nurimaze 🔴

**Rule:** Shade entire rooms to create a maze; find a unique path from S to G through unshaded rooms, passing through marked passage cells and avoiding marked wall cells.

**Model:** Grid divided into rooms + S/G markers + passage/wall markers + `PuzzleGrid<bool>` room shading.

**Generate:** Very complex — must ensure unique maze path. Needs combined room-shading + pathfinding solver.

**Validate:** Shaded rooms block; unshaded rooms form a maze with exactly one path from S to G; path passes through all passage markers; path avoids all wall markers.

---

### 49. Calcudoku (Mathdoku) 🟡

**Rule:** Latin-square grid divided into cages; each cage has a target number and an operator (+, −, ×, ÷). Cage cells combine via operator to hit target.

**Model:** Latin-square grid + `List<Cage>` where `Cage { cells; target; op; }`.

**Generate:** Random Latin square → partition into cages → assign operators and compute targets. Verify uniqueness.

**Validate:** Latin-square property; each cage's values satisfy target under its operator.

**Note:** Already have KenKen beta — this IS KenKen under a non-trademarked name. Consider renaming existing KenKen to Calcudoku.

---

### 50. Zip-Style Path Fill 🟡

**Rule:** Draw one path visiting numbered waypoints in order (1, 2, 3...) while filling every cell. Close cousin of Grid Path (Zip).

**Model:** Grid with numbered waypoint cells + `List<(int,int)>` player path.

**Generate:** Generate a Hamiltonian path, place numbered waypoints along it. Remove intermediate waypoints for difficulty.

**Validate:** Single contiguous path covers all cells; waypoints visited in numeric order.

**Note:** You already have Grid Path (Zip) — this may be a duplicate. Differentiate or merge.

---

### 51. Tents & Trees (Variant: Forest Camp) 🟢

*(Duplicate entry from Category 3 — see #18 above. Included here for completeness in numbering.)*

---

### 52. Pipes (Net / Rotation) 🟢

**Rule:** Rotate tiles until the whole pipe network connects with no open ends. Each tile has pipe segments (straight, elbow, T-junction, cross) that can be rotated 90°.

**Model:** `PuzzleGrid<PipeTile>` where `PipeTile { int connections; int rotation; }`. Connections encoded as bitmask (up/right/down/left).

**Generate:** Build a connected pipe network, randomize rotations. The puzzle is to rotate back. Multiple solutions possible — accept or constrain with fixed tiles.

**Validate:** All pipe ends connect to neighbors; no open ends; entire network connected.

**Note:** Circuit Guide beta already implements this concept — verify overlap.

---

### 53. Wordle-Style Daily Word 🟢

**Rule:** Five-letter guesses with position/presence color feedback (green = right place, yellow = wrong place, gray = not in word). 6 guesses max.

**Model:** Target 5-letter word + `List<(String, List<Color>)>` guesses with feedback.

**Generate:** Pick a word from a curated 5-letter word list. Seed with date for daily mode.

**Validate:** Player guesses the exact word within 6 attempts.

**Note:** Word Guess already exists — this is likely the same game. Skip if duplicate.

---

### 54. Spelling Bee → Anagram Hive

*(Same as #40 above — consolidated.)*

---

### 55. Sumplete (Sum Delete)

*(Already in beta — skip.)*

---

## Variant Layers (Cheap Content Multipliers)

Instead of only adding new types, layer variants onto games you already have — each roughly doubles content for a fraction of the dev cost:

| Variant | Description | Applicable Games |
|---------|-------------|-----------------|
| **Size tiers** | 6×6 quick grids and 12×12+ expert grids | All Latin-square games (Suguru, Kropki, Renzoku, etc.) |
| **Toroidal (wrap-around)** | Rows/columns wrap around edges | Slitherlink, Star Battle, Nonogram |
| **Hex grids** | Hexagonal grid layout | Slitherlink, Masyu, Yin-Yang |
| **Mystery variants** | Hide the operations or some clue types | Calcudoku (mystery ops), Futoshiki (hidden inequalities) |
| **Hybrid grids** | One grid satisfying two rule sets | Slitherlink + Star Battle, Thermo + Arrow Sudoku |
| **Themed skins** | Visual reskins (seasonal, story) | All puzzles |

---

## Suggested Build Priorities (Best Variety per Effort)

### Tier 1 — Fastest Wins (🟢 effort, high impact)
1. **Mosaic (Fill-a-Pix)** — Huge casual appeal, trivial generator, Nonogram fans convert instantly.
2. **Tents & Trees** — Fills the missing easy tier. Very approachable.
3. **Kropki** — Reuses Futoshiki UI almost verbatim.
4. **Renzoku** — Same input model as Kropki. Two-for-one.
5. **Norinori** — Simple rules, sneaky logic. Quick build.
6. **Dominosa** — Cheap generator, satisfying solve. Distinctive.
7. **Yin-Yang** — Great on touch screens. Minimal UI.

### Tier 2 — Strong Additions (🟡 effort, distinctive mechanics)
8. **Suguru** — The strongest unclaimed Sudoku-adjacent puzzle.
9. **Shingoki** — Your loop fans need a third game after Masyu/Slitherlink.
10. **Fillomino** — Deep, endlessly generatable, fan favorite.
11. **Aquarium** — The gravity twist keeps it fresh.
12. **Slant** — Minimal rules, distinctive diagonal look.
13. **Tapa** — Nurikabe's spicier cousin, shares shading UI.
14. **Hidato** — Numeric cousin of Numberlink. Diagonal adjacency twist.

### Tier 3 — Prestige Picks (🔴 effort, expert audience)
15. **Heyawake** — Deepest shading puzzle ever designed. Prestige pick.
16. **Yajilin** — Brilliant loop + shading hybrid.
17. **Shakashaka** — Nothing else looks or feels like it.
18. **Castle Wall** — High difficulty ceiling for expert players.

---

## Implementation Notes

### No-Guessing Guarantee
Every generated puzzle should pass a solver that confirms **exactly one solution reachable by pure deduction**. This pipeline matters more than any individual mechanic for your audience.

### Trademark Awareness
- **KenKen** → ship as **Calcudoku** or **Mathdoku**
- **Tectonic** → ship as **Suguru** (the original Japanese name)
- **Picross** → already using **Nonogram** ✓
- **Rush Hour** → consider renaming (see trademark section below)
- **Unblock Me** → same
- Use generic names or your own branding for all puzzle types.

### Shared UI Systems (Build Clusters)

| Input Model | Puzzles |
|-------------|---------|
| **Latin-square entry** | Suguru, Kropki, Renzoku, Sandwich/Thermo/Arrow Sudoku, Ripple Effect, Hidato, Calcudoku |
| **Cell shading (tap to shade)** | Tapa, LITS, Norinori, Yin-Yang, Kuromasu, Heyawake, Nurimisaki, Kurotto, Mosaic, Cave, Aqre, Static Minesweeper |
| **Region drawing (drag boundaries)** | Fillomino, Galaxies, Araf, Sashigane, Tatamibari, Dominosa, Cell Tower |
| **Loop/path drawing** | Yajilin, Shingoki, Castle Wall, Country Road, Snake, Hidato |
| **Object placement** | Tents & Trees, Battleships, Statue Park, Aquarium, Thermometers |
| **Letter/word input** | Waffle, Semantle, Anagram Hive, Cell Tower, Cryptarithms, Mathler |

---

## Deduplicated Net-New Count

After removing entries that duplicate existing beta/mainline games:

| # | Skipped Entry | Reason |
|---|--------------|--------|
| 50 | Zip-Style Path Fill | = Grid Path (Zip) already implemented |
| 52 | Pipes (Net) | = Circuit Guide already in beta |
| 53 | Wordle-Style Daily Word | = Word Guess already implemented |
| 54 | Spelling Bee | = Word Hive already implemented |
| 55 | Sumplete | Already in beta |
| 49 | Calcudoku | = KenKen already in beta (rename, don't re-implement) |

**Net-new puzzle types to build: ~49**

---
