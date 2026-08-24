# New games — researched, measured, ranked

*Written 2026-08-23. Ten ideas proposed by two agents, then **measured** by three more using
throwaway probes — Python for sweeps, AOT-compiled Dart for cost figures. Nothing here is a
description: every verdict is backed by hundreds or thousands of generated boards.*

> ## ⚠️ Read this before building any of them
>
> **Both proposing agents independently recommended not building a 25th game yet.**
>
> Of 24 live games, 12 are spatial and **eight of those are the same idea** — draw or complete
> a path (Grid Path, Colour Link, Circuit Guide, Slitherlink, Masyu, Bridges, Light Beam, and
> One Stroke in 2.4). The shading slot gets similarly crowded when Nurikabe lands in 2.6.
>
> One put it plainly: *the value of game #25 is lower than the value of the 2.5 systems
> pause.* This file exists so the research is not lost — not because a game is overdue.

---

## Scoreboard

| Game | Verdict | The number that decided it |
|---|---|---|
| **Tumble** | ✅ **build first** | solver **1.80 ms** measured, 4,022 states worst case, no tail |
| **Dominosa** | ✅ build | propagation-only 76% → 24%; **blanks** are the lever, not board size |
| **Driftwood** | ⚠️ build, hard **10,000-node cap** | uncapped tail **9.56 s**; capped, whole loop 43–78 ms |
| **Twin Step** | ⚠️ build, **drop both proposed variants** | mirror and ice add **zero** measured depth |
| **Slant** | ✅ **build — strongest of all eight** | every claim held; backtrack branch never fired in **452,000** trials |
| **Still Water** | ⚠️ build with caveats | uniqueness guarantee is **real and verified**, but the puzzle never gets *deeper*, only longer |
| **Fit** | ❌ 6x6 only, cannot scale | difficulty runs **backwards** — 7x7 averages 37 solutions vs 1 at 5x5 |
| **Nebula** | ❌ do not build | the "stranded single cell" fallback is **41.7% of the board** |
| **Fold** | ❌ do not build | under 32 reachable states; finishable by tapping |
| ~~Norinori~~ | withdrawn by owner | — |

---

# 1. TUMBLE ✅ — build this one first

**Rule for the player:** *Swipe to tip the stone die across the garden. Press each seal with
the face it asks for, in order.*

A die sits on a grid. A swipe tips it one cell, rolling it onto a new face. Marked cells
("seals") must be pressed showing a specific pip count, in sequence. Walls block cells.

### Why it wins
- **The cheapest exact solver on the roadmap** — 1.80 ms measured in AOT Dart, worst case
  4,022 states. No tail, no node budget to negotiate, no fallback to argue about. Every
  generation disaster in this project came from a heuristic believed instead of measured;
  Tumble has no expensive path to skip.
- **The only idea using a mechanic the app has never had**: hidden orientation state — you
  track which face is where, in 3-D, while moving in 2-D.
- **The smallest build.** No `CustomPainter`, no continuous drag, no free-form hit testing.

### The state space is a closed form, not a measurement
```
reachable = freeCells x 12 x (seals + 1) - 2 x seals
```
A die roll is a 90° rotation — an odd permutation of the cube's four diagonals — and it also
flips cell parity. So `sign(orientation) XOR parity(cell)` is invariant and exactly **12 of
the 24 orientations are reachable per cell**. The `-2` per seal are the
`(sealCell, correct-pip, not-yet-pressed)` states, which can never be occupied because
arriving there presses immediately. Verified: 32·12·2−2 = 766; 43·12·4−6 = 2,058;
56·12·6−10 = 4,022, with **zero variance across 50 boards each**.

### Build steps

**Step 1 — `lib/screens/games/tumble/tumble_logic.dart` (no Flutter imports).**
State is `(cell, orientation, sealsPressed)`; orientation is one of 24, stored as a permutation
index or a (top, north) pair.

**Step 2 — generation, reverse-BFS.** Place walls and seals from one bounded seeded pass, then
run **one reverse BFS from the goal states**, which yields the exact distance of *every* state
in a single sweep. Choose the start from the set at the target distance.

> **⚠️ Do NOT pick by exact distance.** Measured redeal rate at exact D: **12% at D=9, 45% at
> D=10, 93.5% at D=12** on 6x6/1 seal; **47.7% at D=25, 83.7% at D=44** on 8x8/5 seals.
> **Pick the nearest available distance instead** — reverse BFS already hands you every
> distance, so this is free, redeal drops to **0%**, and the achieved distance lands within
> ±1 of target across the mid-range.

**Step 3 — gate on an independent forward BFS.** Same rule as every other generator here:
verify with the predicate the win check uses, not with the heuristic that produced it.

**Step 4 — the difficulty ladder.** Measured levers, in order of strength:

| Lever | Effect (measured, deepest median) |
|---|---|
| **Seal count** 1→8 | **10 → 17 → 23 → 31 → 36 → 39 → 54** — strictly monotone. The primary lever. |
| **Wall count** 0→12 at 6x6 | **8 → 9 → 10 → 12 → 14** (+75%). A real second lever. |
| Grid size 4x4→9x9 | 8 → 9 → 10 → 10 → 12 → 12. **Weak — do not use as the ladder.** |

> The first pass called walls "decoration". **Refuted by measurement** — they are a stronger
> lever than growing the board. They do not change the state count; they lengthen paths.

**Step 5 — what changes early (§9 needs something new inside 30 levels):**
- **L1–5:** one seal, any face — a plain rolling maze that teaches the tipping.
- **L6:** the seal demands a *specific* face. This is the moment the game becomes itself.
- **L14:** a second seal, **and order matters**.
- **L22:** "void" cells the die may cross but must not stop on.

**Step 6 — plateau.** Cap at 8x8 / 5 seals / ~34 moves; `modifierStartLevel('tumble') = 12`.

**Step 7 — modifiers** (all implementable and visible, per §8):
- `blind` — the pip face is hidden while moving, revealed when it stops. Memory of your own rolls.
- `quota` — move budget = `solveDistance + 3`. **Free and exact**, because the generator knows
  the true optimum — which most games here cannot say.
- `ratchet` — no undo. Must **never** pool with `blind`.
- `mirror` — swipes inverted on one axis, shown by a flipped arrow in the header.

**Step 8 — screen.** `GridView` for cells, one `AnimatedPositioned` die with pips drawn on the
top face. The tip is a `Transform` rotation about a cell edge (~25 lines of `Matrix4`); Tier 1
may ship as slide-and-crossfade. Estimate ~600-line logic + ~750-line screen — **smaller than
Zen Slide** (746 + 922).

### Known limits
- **Depth maxima are higher than first reported**: 12 / 30 / **54**, not 9 / 29 / 44. The first
  pass sampled starts; the verification enumerated all of them.
- **Breaks above ~50% wall density** — at 7x7 with 24 walls only 88.9% of boards and 80.6% of
  start states solve, because dense walls leave corridors where only 4 orientations are
  reachable per cell. Keep density under ~35%, or add a retry budget.
- A 62 ms p99 comes from allocating a fresh `Int32List` per board. Reuse the buffer.

### The honest risk
On the home grid it will look like Zen Slide — swipe a thing across a grid toward a target.
The distinction is real (orientation, not momentum; the die stops every cell, so there is no
routing at all) but it is a *rules* distinction, invisible in a thumbnail.

---

# 1b. SLANT ✅ — the strongest result of all eight

**Rule:** *Put a `/` or a `\` in every square. A numbered circle on a corner says how many
lines touch it. The lines must never close into a loop.*

Every claim in the proposal held under measurement, and two came back **stronger** than
claimed. One real defect was found — in the difficulty design, not the generator.

### What was verified
- **Construction is provably sound.** Fill every cell with a random diagonal, maintaining
  union-find over corner vertices; if a diagonal would close a loop, take the other. **Across
  ~452,000 fills the backtrack branch never ran once**, across four different cell orders and
  n = 4…20. There is a structural reason worth putting in the code: the fill places n² edges on
  (n+1)² vertices, so the forest always has exactly **2n+1 components** — far too sparse for
  both diagonals of one cell to be internally connected. Keep the branch as insurance; know it
  is dead code.
- **The all-`/` fallback is provably valid** (§10b's one-sentence test): cell (r,c)'s `/` joins
  two vertices whose coordinate-sums are both r+c+1, so every `/` edge stays inside one
  anti-diagonal class, and within a class the edges form a simple path. Disjoint paths — a
  cycle is impossible at any size. **Put that argument in a comment so nobody deletes it.**
- **340 full generations, 5x5–8x8: 0 non-unique, 0 loops, 0 failures.** The solver's unique
  solution was byte-identical to the generator's own grid every time.
- **Generation is cheap**: ~333 ms median in Python at 8x8, **est. 11–22 ms in Dart**, worst
  ~60–120 ms. Max nodes for any single uniqueness solve at 8x8: **221**. No tail.
- **The no-loop rule measurably earns its place** — loop-forced cells go **0** at full clues to
  **12.5** at minimal density.

### The one real defect — and it is in the proposal, not the code
**"Remove clues while the solver still finds exactly one solution" runs all the way to
minimal — and at 8x8 that makes 100% of boards demand depth-1 what-if reasoning from level
one.** There is no easy end of the curve.

Gating removal on a weaker solver does **not** fix it. Measured clues remaining at 8x8:
arithmetic-only gate 38.5, +loop-rule 33, +what-if 32, proposal-as-written 32.5. **Six clues
out of 81 separate the easiest possible gate from no gate at all** — greedy removal converges
to the same board whatever you gate it on. That is the knob-that-doesn't-move-the-board trap.

**The fix is one line: stop removal early.** Clue density is a smooth, wide lever with a
continuous difficulty response:

| clue density | arithmetic alone | needs loop rule | needs what-if | cells the loop rule forces |
|---|---|---|---|---|
| 100% | 100% | 0% | 0% | 0 |
| 71% | 67% | 27% | 7% | 4 |
| 61% | 33% | 40% | 27% | 4 |
| 51% | 0% | 27% | 73% | 5 |
| 41% (minimal) | 0% | 0% | **100%** | **12.5** |

### Build steps
1. Union-find fill (keep the backtrack branch, document why it is unreachable).
2. Compute every vertex's true degree; that is the clue set.
3. **Remove clues to a target density from a per-level table — never to minimality.**
4. Solver: DFS with propagation (a satisfied vertex forces its remaining cells away; a vertex
   whose remaining capacity equals its remaining incident cells forces them toward it;
   union-find forbids loop closure). Bound it and **fail closed** — an over-budget solve means
   "not *provably* unique", so revert the removal.
5. Ladder 5x5 → 8x8, with clue density as the real lever. Input is one tap per cell cycling
   blank → `/` → `\` — the most phone-native input of any candidate, no drag at all.
6. Show a **live loop warning at the moment of the tap**, not a rejected win check — "no closed
   loop" is easy to violate by accident and feels arbitrary otherwise.

---

# 1c. STILL WATER ⚠️ — the guarantee is real; the ceiling is real too

**Rule:** *The board is split into tanks. Water fills each tank from the bottom and settles at
one flat level. Numbers beside each row and column say how many cells are wet.*

### The selling point survived, and it matters
Uniqueness is decided by a **fixed-depth DFS, depth = tank count**. It cannot fail to
terminate. Cross-checked against exhaustive enumeration on 395 boards: **0 mismatches**.
At 8x8 with 11 tanks it costs **57 nodes median**. So **"this generator can never deal an
unsolvable board" is true** — and for a project whose recurring bug is exactly that, that is
worth something on its own.

### But three proposal claims are wrong, and one is a design limit
1. **"Mean tank width" is NOT a lever.** It correlates −0.69 with difficulty only because it
   proxies tank count (+0.76). Hold tank count fixed and it collapses to noise (+0.18 to
   −0.38), inconsistent in sign. **Tank count is the lever.** Same shape as Untangle's
   minimum-crossings gate: a plausible mechanism that does not independently bind.
2. **Hidden clues are weak and expensive.** At 8x8/11 tanks, hiding 4 clues buys **+2** hard
   deductions for a 99.7%→51% accept rate. Raising tank count 11→16 buys **+4** for only
   99.0%→88.4%. **Cap hidden clues at 2.**
3. **"Thousands of nodes" holds only to ~16 tanks.** At 20 tanks on 8x8 the worst board hit
   **101,069 nodes / 4.5 s** in Python (est. 150–300 ms Dart). **Cap tanks at 16 for an 8x8.**
4. **The design limit: no board ever requires a guess.** Full bounds propagation solves
   **94–100%** of boards at every size with zero guesses. Difficulty scales by *length*
   (8→18 deductions) not *depth*. Each board is only **6–18 real decisions** — the number of
   tanks. That is a short, never-broken, low-ceiling puzzle. Ship it knowing that.

Also **gate out the all-dry / all-wet solution** — 0.33% at 5x5/8 tanks. Same class as
Untangle's "dealt already solved".

### Which of the two?
**Slant.** Wider difficulty range, cheaper generation, no tail risk, and its central mechanic
measurably does work. Still Water's virtue is a *guarantee* rather than a game.

---

# 2. DOMINOSA ✅

**Rule:** *A complete set of dominoes is hidden in this grid of numbers, each one exactly once.
Draw the lines to find where every domino sits.*

For set 0..N the grid is exactly (N+1)x(N+2) cells.

### Build steps

**Step 1 — generation is solvable by construction.** Randomly tile the rectangle with dominoes
(randomised backtracking; an even cell count always tiles), then assign the (N+1)(N+2)/2
distinct value-pairs to tiles at random. **5,150 boards, zero reporting no solution.**

**Step 2 — uniqueness needs a real solver.** Exact cover (every cell once, every value-pair
once) with two propagation rules — a pair with exactly one possible placement is forced; a cell
with exactly one possible partner is forced — then DFS capped at 2 solutions.

**Step 3 — expect to reject most boards, and do not care.** Accept rates: N=3 **6.27%**, N=5
3.70%, N=8 **1.78%**. That sounds fatal and is not: a rejection costs 0.02–0.4 ms. End-to-end
Dart time to produce one unique board — N=3 **0.28 ms** median, N=7 2.96 ms, N=8 7.68 ms.

**Step 4 — the difficulty lever is BLANKS, not size.** At fixed N, going from k=0 to k=2 blank
cells moves propagation-only solvability **72.5% → 13.0%** in one step. The entire five-size N
ladder only moves it 76% → 24%.

> **⚠️ Cap k from a table; never search it upward.** Past the usable band cost explodes
> non-linearly — N=5 k=12 hit **222 seconds**. Usable: k≤4 for N≤5, k≤6 for N≥6.

**Step 5 — the fallback is one-sentence provable (§10b): reduce k.** k=0 is unique by
construction. There is no stored board and there must not be one.

**Step 6 — generate off the UI thread.** Worst case 98 ms at k=0, 836 ms at N=7 k=6.

### Ladder
Five phone-playable sizes (N=3 is 4x5; N=8 at 9x10 is too dense to tap), plateauing ~level 20 —
which **matches §9k**, since other games plateau at 12. (N, k) gives 15 measured-distinct tiers
spanning 76.3% → 0.0% propagation-only.

### The honest risk
In a screenshot it is a grid of digits, filed next to Sudoku, Kakuro and Killer Sudoku even
though it plays nothing like them. That is a discovery problem — and discovery is already the
parked 2.3 item.

---

# 3. DRIFTWOOD ⚠️ — buildable only with a hard cap

**Rule:** *Slide the logs along the current to float the marked log out of the river mouth.*
Rush Hour, calmly re-skinned. Every move is reversible, so a player can never lose.

### The one number that decides it

The state graph is undirected, so **one BFS from the solved state gives exact distances for
everything**. But component size is the problem:

| blockers | median component | **max** |
|---|---|---|
| 7 | ~6,700 | 133,875 |
| 9 | ~13,000 | **1,055,718** |
| 11 | ~2,800 | 648,672 |

Uncapped, optimised AOT Dart: **9.56 second tail**. The first pass measured 3 s in Python and
called it "trivially removable"; rebuilding it properly proved otherwise — the cost is
component size, not the inner loop.

### Build steps

**Step 1 — cap the search at 10,000 nodes.** This is not a tuning parameter, it is the design.

**Step 2 — do NOT raise the budget.** Measured: 50,000 nodes is **1.8x slower at the median and
3.3x worse at the tail** (5.9 s) than 10,000, for **zero gain in success rate**. Rejecting a
fat component fast beats exploring it. Counter-intuitive, and it is what makes the game
shippable.

**Step 3 — reverse construction.** Place blockers, put the marked log flush at the exit (that is
the solved state), BFS the component, deal the start at the target distance.

**Step 4 — pick a move-counting convention and write it down.** Slide-any-distance (classic
Rush Hour) gives median depth 9–11; single-cell counting roughly doubles it (median 21, max 76).
**Every number in the level curve depends on which you choose.**

**Step 5 — ceiling is real.** Usable range is depth 6–14 slide-moves. D=18 fails 57% of the
time even after 60 deals.

**Step 6 — memory.** An uncapped 9-blocker BFS holds 1.06M states — order 50 MB on a phone. At
10,000 nodes it is ~0.5 MB. Generate off the UI thread or ship as data.

### Measured, with the cap in place
| blockers | budget | depth | success ≤60 deals | total ms med / max |
|---|---|---|---|---|
| 7 | 10,000 | 10 | 100% | 76 / 564 |
| 9 | 10,000 | 14 | 99% | 228 / 1,051 |
| 11 | 10,000 | 14 | 97% | 158 / 978 |

### The honest risk
It is a Rush Hour clone and everyone will know. The counter-argument is that CogniQ is already
a library of well-known puzzles executed properly, and its differentiator is verified
generation rather than novelty — but that is the owner's call, not the researcher's.

---

# 4. TWIN STEP ⚠️ — build the base game, drop both proposed variants

**Rule:** *Both stones move together. Swipe once; each stone steps that way unless something
stops it. Land every stone on its own pad.*

### The finding that matters most

Both mechanics proposed as the "something changes early" rung were **measured on identical
layouts and neither binds**:

| 5x5, 4 walls, 2 stones | reachable | deepest med | **median solve distance** |
|---|---|---|---|
| 2 plain | 420 | 14 | **7.5** |
| plain + **mirror** | 420 | 12 | **7.5** |
| plain + **ice** | 420 | 9 | 5.0 |
| 2 ice | **2** | 0 | 0.2 |

**Mirror gives an identical median to the decimal and a *lower* best depth** (26 vs 29
steelmanned). **Ice collapses reachability** for most pad sets — ~2x the generation retries for
no depth gain.

Per §9c, a plausible mechanism that does not bind is worse than none, because it stops anyone
looking for the real one. **If this game needs an early change, it must be a different
mechanic — and that mechanic must be measured before it is designed around.**

### Build steps
1. Reverse BFS from the solved configuration; state is the tuple of stone cells. Stones block
   each other, so the graph is **directed**.
2. **Add a pad-rejection test.** "Almost every configuration is reachable" is **false** —
   mean 73.3% at 7x7/3 stones, bimodal. Reject a goal whose reverse-reachable set is under
   ~90% of the state space.
3. Ladder: 5x5/2 stones (deepest 16) → 6x6/2 (20) → 6x6/3 (24) → 7x7/3 (26–28). Stone count
   2→3 is the only real step, and it costs a 25–60x jump in state space.
4. **Cost forces an isolate at 3 stones**: 6x6/3 is ~385 ms, 7x7/3 is ~610 ms — 37 dropped
   frames. And unlike Driftwood **there is no node-budget escape**: a Twin Step move is
   many-to-one, so you cannot compute a predecessor directly; reverse BFS requires building the
   entire forward graph first.

### The honest risk
Grid + swipe + get-the-thing-to-the-target is Zen Slide's exact surface, and unlike Tumble it
does not change the movement rule — only the number of things moving. On the home grid it will
read as "Zen Slide 2".

---

# Rejected — and why the negative results were worth the effort

## FIT ❌ — difficulty runs backwards
Polyomino packing. Three measured problems:
1. **Rotation must be off** — with free rotation, **99.7%** of 6x6 boards hit a 50-solution cap.
2. **Difficulty runs backwards.** At constant piece size, 5x5 gives a median of **1** solution
   (61% unique) and 7x7 gives **37** (2% unique). Bigger boards are *easier* while the check
   gets ~100x dearer. That violates §9 outright.
3. **All 19 logged "0 solutions" were false zeros** — the solver hitting its budget. One board
   reported "0" actually had **at least 50** solutions. See `remember.md` §9g.

Viable only at 6x6 with rotation disabled, which is ~3 tiers on one board size. Not a ladder.

## NEBULA ❌ — the fallback is the main path
Galaxies / Tentai Show. The admitted worry (expensive uniqueness) turned out **false** — it was
one missing propagation rule. The fatal problem was in none of the claims:

**"Stranded single cells become 1-cell regions" is not an edge case — it is 41.7% of the
board.** A 7x7 has ~21 galaxies on 49 cells, most of them single squares. A second, different
generator was tried; it was **worse** (63.8%). Boards are also 95–98% pure propagation — no
deduction at all.

That is §10b at its purest: the fallback *is* the main path. Revisit only if someone
demonstrates a generator producing large interlocking galaxies **and** a propagation-only rate
that *falls* as the knob rises.

## FOLD ❌ — measured, then killed
Folding paper until marks align. The most novel idea proposed, and the measurement killed it
twice: the first formulation ceilinged at **three folds**, and at depth 5 the measured minimum
came in *below* the scramble depth — the "deeper scramble ≠ harder board" failure Zen Slide's
header already warns about. The second formulation had **under 32 reachable states**; a player
with an undo button exhausts it by tapping.

---

# Four lessons worth keeping regardless of which game is built

1. **A "trivially removable" cost is not removable until someone removes it.** Driftwood's tail
   was attributed to an inefficiency. Rebuilt properly it is **9.56 s** — the cost was
   structural. The first agent was right to refuse to claim a number it had not measured.
2. **A bigger search budget can be strictly worse.** 50,000 nodes lost to 10,000 on median,
   tail *and* success rate.
3. **Every "0 solutions" must be proved, not believed.** 19 of 19 were false.
4. **Measure a proposed mechanic before designing around it.** Twin Step's mirror and ice were
   both intended as the required early-change rung. Neither moved the number.
