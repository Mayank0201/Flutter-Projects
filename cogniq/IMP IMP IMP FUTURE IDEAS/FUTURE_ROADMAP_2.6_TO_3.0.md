# CogniQ — Future Ideas, 2.6 → 3.0

*Written 2026-08-23, after shipping 2.5. **Nothing here is built.** This is a design document
with worked code, so a future session can start building instead of re-deriving.*

---

# ⭐ READ THIS FIRST — the one fact everything depends on

Open `lib/utils/rotation_engine.dart` line 15:

```dart
static Random getDeterminism(String gameId, int levelIndex) {
  final seed = _stableHash(gameId) ^ (levelIndex * 2654435761 & 0x7fffffff);
  return Random(seed);
}
```

**A board is a pure function of `(gameId, levelIndex)`.** There is no timestamp, no device id,
no random salt. That means:

> **Every player on Earth who opens Kakuro level 30 gets the byte-identical board.**

This has been true since 1.8 and has never been used for anything. It is the single most
valuable unexploited asset in this codebase, because it makes the following free:

- Two people can play **the same puzzle** with no server, no accounts, no sync.
- A puzzle can be **shared as a short text code** — the code *is* the puzzle.
- A **leaderboard is possible without a backend**, because "level 30" already means one exact
  board for everybody.
- The app's **zero-network property survives completely intact** (`md/RELEASE_PLAN.md` §1).

Almost every idea in this file is cheap *because of that one line*. Keep it that way: if
anyone ever adds `DateTime.now()` or a device id into that seed, all of this dies.

---

# The plan at a glance

| Version | Theme | Needs a decision from the owner? |
|---|---|---|
| **2.6** | Speed & Endless modes + Nurikabe | ✅ yes — three questions, see below |
| **2.7** | **Play With Friends** (Hot Seat + Challenge Codes) | no |
| **2.8** | Go Deeper (fix the difficulty ceilings) | no |
| **2.9** | Old Puzzles, New Life (Vault, Birthday, Ghost) | no |
| **3.0** | The Big One (Mastery, Clue Holder, fresh look) | some |

**Only 2.6 is fixed** (it is already started). **2.7, 2.8 and 2.9 can be reordered freely.**

---
---

# 2.6 — Modes + Nurikabe

Already planned in `md/RELEASE_PLAN.md` §4.8. Summarised here for completeness.

## What ships
- **Speed mode** — a timed variant with per-level clocks and time-based scoring
- **Endless mode** — one continuous scaling run instead of discrete levels
- **Nurikabe** — the second prototype revival

## 🔴 Three decisions needed before any code

1. **Which games participate?** Almost certainly not all 28. Speed makes no sense for a game
   with no time pressure; Endless needs a game that scales naturally.
2. **How does the home-screen mode switch scale past two modes?** Today it is a single leaf
   icon toggling Zen on/off. Three or four modes needs a different control.
3. **Scoring multipliers** — what is a Speed clear worth versus a Challenge clear?

## 🔴 A fourth decision nobody has raised yet

**Do Speed and Endless clears feed the Challenge-side counters?**

Zen deliberately does **not**. See `lib/utils/hint_manager.dart` around line 114 — a Zen clear
returns early and never increments `PrefsKeys.globalLevelClearedCount`. That rule is what stops
a player farming easy, modifier-free levels to unlock trails and achievements.

**Speed and Endless need the same call, or the star-trail economy gains a back door.** An
Endless run could rack up hundreds of "clears" in one sitting, which would trivialise
`Eclipse` (4,000 clears) — the trail explicitly designed to be the hardest thing in the app.

**Recommendation:** treat them exactly like Zen. Own counters, own records, no feed into
Challenge totals.

## How to build the modes — copy Zen exactly

**Do not invent a third persistence pattern.** `PrefsKeys` already resolves keys by mode
(`lib/utils/prefs_keys.dart:115`):

```dart
static String gameLevel(String gameId) =>
    ZenMode.isEnabled ? ZenMode.zenGameLevel(gameId) : normalGameLevel(gameId);
```

With more than two modes this two-branch shape stops scaling. Refactor to an enum **once**,
before adding either mode:

```dart
// lib/utils/play_mode.dart  (new)
enum PlayMode { challenge, zen, speed, endless }

class PlayModeManager {
  static const _key = 'active_play_mode';
  static PlayMode _active = PlayMode.challenge;
  static PlayMode get active => _active;

  /// Short, stable prefix used in every SharedPreferences key.
  /// NEVER change these strings — they are on disk on real devices.
  static String get prefix => switch (_active) {
        PlayMode.challenge => 'normal',
        PlayMode.zen       => 'zen',
        PlayMode.speed     => 'speed',
        PlayMode.endless   => 'endless',
      };

  static Future<void> setActive(PlayMode m) async {
    _active = m;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, m.name);
  }
}
```

then `PrefsKeys` collapses to one line per key:

```dart
static String gameLevel(String gameId) =>
    '${PlayModeManager.prefix}_level_$gameId';
```

⚠️ **Migration matters.** Zen's existing keys are `zen_level_<id>`, and Challenge's are
`normal_level_<id>`. Keeping those exact prefixes means **no migration at all** — the new enum
produces byte-identical key strings for the two modes that already exist. Do not "tidy" them.

---
---

# 2.7 — Play With Friends 🎮

**The release I would build first.** Entirely offline. Works across all 28 games on day one,
because it adds no puzzle logic whatsoever.

## 2.7 A — Hot Seat

Two people, one phone, the same board.

**Flow:** pick a game → "Hot Seat" → Player 1 solves against a stopwatch → handover screen →
Player 2 solves **the identical board** → result card.

Determinism does all the work: both players open the same `(gameId, level)`, so fairness is
guaranteed by construction rather than by copying a board around.

### Data model

```dart
// lib/utils/hotseat_manager.dart  (new)
class HotSeatResult {
  final String playerName;   // "Player 1" unless they type one
  final Duration time;
  final int hintsUsed;
  final bool finished;       // false if they gave up
  const HotSeatResult({...});
}

class HotSeatSession {
  final String gameId;
  final int levelIndex;
  final Set<String> modifiers;   // frozen at session start, identical for both
  final List<HotSeatResult> results = [];

  bool get isComplete => results.length == 2;

  /// Lower is better; an unfinished attempt always loses.
  HotSeatResult? get winner {
    if (!isComplete) return null;
    final a = results[0], b = results[1];
    if (a.finished != b.finished) return a.finished ? a : b;
    if (!a.finished && !b.finished) return null;   // draw: neither finished
    return a.time <= b.time ? a : b;
  }
}
```

### The four traps, and how to avoid them

**1. Progress corruption — the big one.**
A Hot Seat game must **never** write to the player's real level. It is a friendly match, not
progression. Route it through a throwaway prefix:

```dart
// during a Hot Seat session
PlayModeManager.setActive(PlayMode.hotSeat);   // prefix 'hotseat'
// ... play ...
PlayModeManager.setActive(previousMode);       // always restore, even on back-press
```

Look at how the daily challenge already does exactly this — it backs up the real level, plays,
and restores (`lib/screens/daily_screen.dart`, the `daily_backup_*` keys, and the restore block
in `lib/main.dart` around line 127). **Copy that pattern, including the crash-safety**: the
restore happens at next app start if the player force-quits mid-match.

**2. Points and achievements must not fire.**
`HintManager.onLevelCleared` awards 10 points and can unlock achievements. In Hot Seat it must
early-return, the same way it already does for Zen.

**3. Modifiers must be frozen and identical.**
Resolve `RotationEngine.getActiveModifiers(...)` **once** at session start and pass the same
`Set<String>` to both players. Do not call it twice — a future change to the rotation could
otherwise hand the two players different boards.

**4. Player 2 must not see Player 1's solution.**
The handover screen has to fully cover the board, and the board state must be reset before it
is revealed. An `AnimatedOpacity` is not enough — build the board fresh.

### Where it lives in the UI
A "Hot Seat" entry on each game's card long-press menu, plus one on the home screen. It needs
**no new route per game** — one `HotSeatScreen` wraps the existing game screen.

---

## 2.7 B — Challenge Codes 📮 — the viral loop

**Send a friend eight characters. They get your exact puzzle.**

```
KAK-30-2F
 |    |  |
 |    |  └─ modifier bitmask (hex)
 |    └──── level index
 └───────── game (3 letters)
```

Because a board is `(gameId, level)`, **the code is the entire payload.** No upload, no
database, no account. It can be sent over WhatsApp, written on paper, or read aloud on a phone
call.

### Implementation sketch

```dart
// lib/utils/challenge_code.dart  (new)
class ChallengeCode {
  final String gameId;
  final int levelIndex;
  final Set<String> modifiers;

  /// Three-letter codes are FROZEN once shipped: a code someone texted last
  /// month must still open the same puzzle next year. Never re-map one.
  static const Map<String, String> _codes = {
    'KAK': 'kakuro', 'SUD': 'sudoku', 'ORB': 'orbit',
    'ONE': 'onestroke', 'SKY': 'skyscrapers', 'UNT': 'untangle',
    // ... one per game, and never reused for a different game
  };

  /// Modifier order is also frozen — the bit position IS the wire format.
  static const List<String> _modBits = [
    'timer', 'fog', 'zoom', 'decay', 'mirror', 'quota',
    'heartbeat', 'monochrome', 'seismic', 'inverse', 'drift', 'vertigo',
  ];

  String encode() {
    final letters = _codes.entries.firstWhere((e) => e.value == gameId).key;
    var mask = 0;
    for (var i = 0; i < _modBits.length; i++) {
      if (modifiers.contains(_modBits[i])) mask |= (1 << i);
    }
    return '$letters-$levelIndex-${mask.toRadixString(16).toUpperCase()}';
  }

  static ChallengeCode? decode(String raw) {
    final parts = raw.trim().toUpperCase().split('-');
    if (parts.length != 3) return null;
    final gameId = _codes[parts[0]];
    final level = int.tryParse(parts[1]);
    final mask = int.tryParse(parts[2], radix: 16);
    if (gameId == null || level == null || mask == null) return null;
    if (level < 0 || level > 500) return null;          // reject nonsense
    return ChallengeCode(
      gameId: gameId,
      levelIndex: level,
      modifiers: {
        for (var i = 0; i < _modBits.length; i++)
          if (mask & (1 << i) != 0) _modBits[i],
      },
    );
  }
}
```

### 🔴 The rules that make this safe long-term

1. **Three-letter codes and modifier bit positions are a wire format.** Once shipped, they are
   frozen forever. A code texted in March must still work in December. Add new games by
   appending; never re-map an existing entry.
2. **Validate hard on decode.** A typo'd code must show "that code doesn't look right", never
   crash. Reject unknown games, negative levels, absurd levels.
3. **A stashed game must be rejected.** If someone on 2.7 sends a `SKY-...` code to a friend
   still on 1.8.2 where Skyscrapers is stashed, the receiver must get a friendly "you need a
   newer version" — **not** a crash. This is the exact failure `DailyChallengeManager._isLiveGame`
   already guards against (`lib/utils/daily_challenge_manager.dart:1121`). **Reuse that guard.**
4. **Codes must not touch real progress** — same throwaway-prefix rule as Hot Seat.

### Extension worth designing for now
Add a third seed component so codes can address boards that exist nowhere in the ladder:

```dart
static Random getDeterminism(String gameId, int levelIndex, {int roomSeed = 0}) {
  final seed = _stableHash(gameId)
      ^ (levelIndex * 2654435761 & 0x7fffffff)
      ^ (roomSeed * 40503 & 0x7fffffff);
  return Random(seed);
}
```

**`roomSeed: 0` must reproduce today's boards exactly** — otherwise every existing player's
current level silently changes underneath them. Assert that in a test before shipping.

---
---

# 2.8 — Go Deeper

**Stop adding games. Make the 28 you have go further.** Every item below is grounded in
measurements taken 2026-08-23, not opinion.

## The measured problem

| Game | Board stops changing at |
|---|---|
| **Slitherlink** | level **12** |
| **Kakuro** | level **12** |
| **Cipher Decoder** | level **20** |
| **Chimp** | level **24** |
| Colour Link | 44 — *then gets easier* |

A player who reaches Kakuro level 60 has had **48 levels with no new board**. Modifiers carry
the curve after a plateau, which is the intended design — but a plateau at level 12 is a very
different thing from one at level 90.

## What ships

1. **Extend the late game** for the four earliest-plateauing games. Kakuro capping at an 8×8
   with two fixed layouts is the clearest case: more layouts, or larger grids.
2. **Fix Colour Link.** It peaks at level 45 (8×8, 8 colours), drops to 6 colours at level 60,
   and from level 80 cycles *below* its own peak forever. **A level-100 player faces easier
   boards than at level 50.** Exact code is written up in `md/3_GAME_FIXES_FOR_1.8.3.md`.
3. **Fix Chimp's dead stretch** — board caps at 24, modifiers start at 30. One line.
4. **Delete Grid Path's dead code** — three branches above level 30 that have never executed
   once, because a floor below them always wins.

## The test that should have caught all of this

`test/difficulty_curve_test.dart` checks that modifiers start early and vary. **It never
asserts difficulty does not go backwards.** Nothing in the project does. That is why Colour
Link shipped.

```dart
test('difficulty never runs backwards', () {
  for (final id in pools.keys) {
    var previous = 0;
    for (var level = 0; level < 150; level++) {
      final signature = difficultySignatureFor(id, level);
      expect(signature, greaterThanOrEqualTo(previous),
          reason: '$id gets EASIER going into level $level');
      previous = signature;
    }
  }
});
```

The work is `difficultySignatureFor` — each game scales different things, so it needs a small
per-game accessor. Worth it: this is the third difficulty-curve defect found by reading code
rather than by a test.

---
---

# 2.9 — Old Puzzles, New Life

**Three features built almost entirely from content that already exists.**

## 2.9 A — The Vault 🗄️

The daily challenge runs a **30-week / 210-day cycle** (`DailyChallengeManager.kTotalDays`).
Players miss days constantly, and that content is then gone forever.

**Let them play any past day.** 210 days of puzzles you have already designed, already tested,
and which most players will never otherwise see. It also converts a guilt mechanic ("I broke my
streak") into a content library.

```dart
// Everything needed already exists:
final challenges = DailyChallengeManager.getChallengesForDay(anyPastDay);
```

**Rules:**
- Vault plays award **no stars and no streak** — otherwise a player could grind 210 days of
  perfect stars in an afternoon and mint the diamond trails instantly.
- Mark them visually as "from the archive".
- Keep the substituted-slot guard: 16 of the 90 slots still point at deleted games.

## 2.9 B — Birthday Puzzle 🎂

A board is a function of a number. **So make that number a date.**

```dart
int seedForDate(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

// "The Sudoku for 14 March 1990"
final board = SudokuLogic.generate(
  RotationEngine.getDeterminism('sudoku', 0, roomSeed: seedForDate(birthday)),
  /* level */ 12,
);
```

Every date in history has a unique, reproducible CogniQ puzzle. Shareable, sentimental, costs
almost nothing once `roomSeed` exists from 2.7. Pairs naturally with Challenge Codes — a
birthday puzzle *is* a challenge code with a date-derived seed.

## 2.9 C — Ghost Race 👻

Record your input timeline on a level; replay it as a translucent ghost next time.

```dart
// lib/utils/ghost_recorder.dart  (new)
class GhostMove {
  final int atMs;        // ms since level start
  final String action;   // game-specific, e.g. "place:4,2=7"
  const GhostMove(this.atMs, this.action);
}

// Stored per (gameId, levelIndex, mode) — keep only the personal best.
// A 6x6 Sudoku solve is ~40 moves; ~1KB as JSON. Trivial storage.
```

**Why this matters more than it looks:** it is single-player multiplayer. All the tension of
racing someone, with **no second human required** — which matters, because you cannot assume a
player's friends have the app. It is the competitive feature that works for the player sitting
alone on a bus.

**Start with 3–4 games**, not 28. Ghosts need a per-game way to describe a move, and that is
real work each time. Grid Path, Sudoku, Kakuro and Untangle are the natural first set.

---
---

# 3.0 — The Big One 🎉

**Make 28 games feel like one product.**

Today the only things spanning your games are points, 44 achievements and a streak. There is no
answer to *"am I actually getting better at Sudoku?"*

## 3.0 A — Mastery

A visible skill track per game, computed from data you **already store**:

```dart
// lib/utils/mastery_manager.dart  (new)
enum MasteryTier { novice, apprentice, skilled, expert, master }

class MasteryManager {
  /// Deliberately uses only values already on disk. No new tracking, no
  /// analytics dependency, and therefore no privacy question at all.
  static MasteryTier tierFor(String gameId, SharedPreferences prefs) {
    final level   = prefs.getInt(PrefsKeys.normalGameLevel(gameId)) ?? 0;
    final cleared = prefs.getInt(PrefsKeys.normalClearedCount(gameId)) ?? 0;
    final hints   = prefs.getInt('hints_used_$gameId') ?? 0;

    // Hint dependence is the interesting signal: someone at level 40 who has
    // never used a hint is genuinely better than someone at level 40 who has
    // used sixty.
    final ratio = cleared == 0 ? 1.0 : hints / cleared;
    if (level >= 60 && ratio < 0.10) return MasteryTier.master;
    if (level >= 40 && ratio < 0.25) return MasteryTier.expert;
    if (level >= 25) return MasteryTier.skilled;
    if (level >= 10) return MasteryTier.apprentice;
    return MasteryTier.novice;
  }
}
```

⚠️ **The thresholds above are guesses.** This project has been bitten repeatedly by numbers
that were reasoned rather than measured (`md/remember.md` §9c). Before shipping, check what a
real player's numbers actually look like — even one device's data is better than none.

## 3.0 B — Clue Holder 🗣️

**The genuinely strange one, and the reason to call it 3.0.**

Two phones. Both players enter the same challenge code. **One phone shows only the clues; the
other shows only the grid.** Neither can see the other's screen. They have to talk.

Works beautifully with Skyscrapers, Kakuro, Nurikabe and Slitherlink — any game where clues sit
around the outside of a grid.

Nothing in the puzzle category does this. It turns a silent solo experience into a
conversation, and it needs **no connection between the two phones** — determinism plus a shared
code is the entire sync mechanism.

**Build note:** the two roles are two render modes of the same screen. `showGrid` and
`showClues` booleans through the existing painter, plus a role-picker. It is far less work than
it sounds.

## 3.0 C — A fresh look

A milestone version deserves one. Also the natural moment to spend the accessibility work:
the accent colours currently fail contrast in **22 places** when used as text.

---
---

# Deliberately NOT on this list

Worth recording so nobody re-proposes them.

| Idea | Why not |
|---|---|
| **Online multiplayer / leaderboards** | Needs a backend, accounts, a privacy policy, and moderation. It would destroy the zero-network property, which is a genuine selling point. Determinism gives you 80% of the value at 0% of the cost. |
| **Cloud save / accounts** | Same. Offline-first is a feature, not a limitation. |
| **More new games after Nurikabe** | Two independent reviewers said 28 is already plenty. 8 of them are variations on "draw a path". |
| **Ads beyond what exists** | Nothing to gain, plenty of goodwill to lose. |

> **Recorded so nobody re-proposes them in six months — but keep them in mind. These are not
> forbidden ideas, only wrong-for-now ones.** Each is parked on a specific reason, and reasons
> expire. If the app ever outgrows offline-first, or a backend arrives for something else
> anyway, or the game mix genuinely stops feeling repetitive — come back and re-read this
> table rather than assuming the answer is still no.

---

# Honest caveats — read before committing

**1. All of this is reasoning, not evidence.** I have no data showing your players want
multiplayer, or a vault, or mastery — because analytics is still off (`NoopSink`, verified).
Nobody knows what your players want. **Challenge Codes is the cheapest way to find out**,
because it is small enough that being wrong costs one release rather than a quarter.

**2. Ghost Race and Clue Holder are per-game work**, not app-wide. Every game needs its own
notion of "a move" or "a clue". Budget them as several small jobs, not one big one.

**3. The determinism guarantee is load-bearing now.** If any future change puts a timestamp or
device id into `getDeterminism`, Hot Seat, Challenge Codes, Birthday Puzzles and Clue Holder
all break at once. **Add a test that pins a few known boards**, so that breakage is caught by
CI rather than by a confused player.

```dart
test('a board is a pure function of (gameId, level) — this is load-bearing', () {
  // If this fails, Challenge Codes and Hot Seat are broken. Do not "fix" it by
  // updating the expected values; find out what put entropy into the seed.
  final a = KakuroLogic.generate(RotationEngine.getDeterminism('kakuro', 30), 30);
  final b = KakuroLogic.generate(RotationEngine.getDeterminism('kakuro', 30), 30);
  expect(a.toString(), b.toString());
});
```

**4. None of your eight bundles has ever run on a phone.** Honestly, one release of pure
device-testing-and-fixing would probably be worth more than any single item above.

---

*Companion documents: `md/RELEASE_PLAN.md` (the plan of record), `md/CHECKLIST.md` (map of
every `.md`), `md/3_GAME_FIXES_FOR_1.8.3.md` (the 2.8 fixes, with exact code),
`md/remember.md` §14 (widget) and §15 (analytics).*
