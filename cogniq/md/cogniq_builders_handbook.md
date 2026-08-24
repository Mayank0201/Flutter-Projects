# CogniQ Builder's Handbook — Modifiers & New Games, Fully Detailed

> ### 📏 How to use this handbook
>
> **It is a design sketch, not a specification.** Both games built from it so far needed
> defects fixed before a line of screen code was written — Zen Slide **6**, Untangle **4** —
> and in both cases its *core idea* was correct and was kept verbatim.
>
> So the rule is not "distrust this file". It is: **transcribe the generator, run it a few
> thousand times, and measure the properties it claims — then build.** Both sets of defects
> were found in under ten minutes that way, and every one of them would have shipped.
>
> The five things to measure are listed in `md/remember.md` §9c. Where a section has already
> been built, a ⚠️ block at the top records what was measured; the shipped `_logic.dart`
> file is the source of truth, not the code here.

### v3 — written for a developer who knows Flutter basics only

---

# PART 0 — HOW TO USE THIS DOCUMENT

Every feature in this doc comes in **two tiers**:

- **TIER 1 — "Make it work."** Uses only basic widgets you already know or will learn in Part 1: `Container`, `GridView`, `GestureDetector`, `setState`, `Timer`. It will run fine. On big boards with fast dragging it may drop frames on 120Hz phones — that's expected and okay.
- **TIER 2 — "Make it smooth."** The upgrade: `CustomPainter`, `ValueNotifier`, `RepaintBoundary`, `AnimationController`. This is what `remember.md` in your repo demands, and what your best games (Grid Path, Pearl Loop) already do.

**The trick that makes upgrading painless:** every game is split into TWO files —

```
lib/screens/games/<id>/<id>_logic.dart    ← pure Dart. No Flutter imports. The brain.
lib/screens/games/<id>/<id>_screen.dart   ← the UI. The face.
```

The logic file never changes between tiers. When you upgrade Tier 1 → Tier 2 you ONLY rewrite the screen file's board area. Rules, generation, win-checking: untouched. This is the single most important architectural decision in this document.

**Recommended path:** Read Part 1 once → build Phase 1 (4 easy modifiers, Part 4) → build Sand Sort Tier 1 (Part 5, B7) → play it → upgrade it to Tier 2 → then everything else is repetition.

---

# PART 1 — FLUTTER WIDGET PRIMER
### Every widget and concept used in this doc, explained in plain language

You know `StatelessWidget`, `StatefulWidget`, `Column`, `Row`, `Text`, `Container`. Here is everything else this doc uses. Come back to this section whenever a term looks scary.

### 1.1 `setState` — the sledgehammer
```dart
setState(() { score += 1; });
```
Rebuilds the **entire** widget's `build()` method. Fine for taps. Bad inside a drag that fires 120 times per second on a big screen — that's the jank `remember.md` warns about. Tier 1 uses it anyway; Tier 2 replaces it in hot paths.

### 1.2 `ValueNotifier` + `ValueListenableBuilder` — the scalpel
A tiny box holding one value. Widgets can listen to JUST that box and rebuild alone.
```dart
final moves = ValueNotifier<int>(0);         // create (in your State class)
moves.value = 5;                              // update — NO setState needed

// In build(): only this Text rebuilds when moves changes:
ValueListenableBuilder<int>(
  valueListenable: moves,
  builder: (context, value, _) => Text('Moves: $value'),
)
```
Rule of thumb: things that change many times per second (drag position, timers, counters) live in a `ValueNotifier`. Things that change on discrete taps can use `setState`.
Always `moves.dispose();` in your `dispose()` method.

### 1.3 `GestureDetector` — how you read fingers
```dart
GestureDetector(
  onTap: () { ... },
  onPanStart:  (details) { print(details.localPosition); }, // finger down + moved
  onPanUpdate: (details) { ... },  // fires continuously while dragging
  onPanEnd:    (details) { ... },  // finger lifted
  child: yourBoard,
)
```
`details.localPosition` is an `Offset` (has `.dx`, `.dy`) measured from the **top-left of the child**. To find which grid cell a finger is on:
```dart
final col = (details.localPosition.dx / cellSize).floor();
final row = (details.localPosition.dy / cellSize).floor();
// ALWAYS guard: if (row < 0 || row >= rows || col < 0 || col >= cols) return;
```
This one formula powers every board game in your app.

### 1.4 `LayoutBuilder` — "how much space do I have?"
You can't hardcode cell sizes — phones differ. `LayoutBuilder` hands you the available space:
```dart
LayoutBuilder(builder: (context, constraints) {
  final boardSize = constraints.maxWidth;        // e.g. 380 on one phone, 411 on another
  final cellSize  = boardSize / cols;
  return SizedBox(width: boardSize, height: boardSize, child: ...);
})
```

### 1.5 `AspectRatio` — keep the board square
```dart
AspectRatio(aspectRatio: 1, child: board)   // width == height, always
```

### 1.6 `Stack` + `Positioned` — layers
Things drawn on top of each other (board below, overlay above, a piece at exact coordinates):
```dart
Stack(children: [
  boardWidget,                                            // bottom layer
  Positioned(left: x, top: y, child: DraggedPiece()),     // exact pixel position
  if (showConfetti) const ConfettiOverlay(),              // top layer
])
```

### 1.7 `GridView.builder` — the Tier 1 board
Builds a scrollable-by-default grid of widgets. For game boards we DISABLE scrolling:
```dart
GridView.builder(
  physics: const NeverScrollableScrollPhysics(),   // board must not scroll!
  shrinkWrap: true,
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: cols,        // number of columns
    mainAxisSpacing: 4, crossAxisSpacing: 4,
  ),
  itemCount: rows * cols,
  itemBuilder: (context, index) {
    final row = index ~/ cols;   // ~/ is integer division
    final col = index % cols;
    return buildCell(row, col);  // return a Container / GestureDetector per cell
  },
)
```

### 1.8 Implicit animations — free smoothness, zero setup
Swap a value, Flutter animates the change automatically. Your app already uses these everywhere (Odd Color Out uses 150–400ms).
```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 200),
  curve: Curves.easeOut,
  color: isSelected ? AppTheme.warmAmber : AppTheme.bgCardLight,  // change → animates
  ...)
AnimatedOpacity(opacity: visible ? 1 : 0.15, duration: ..., child: ...)
AnimatedScale(scale: popped ? 1.15 : 1.0, duration: ..., child: ...)
AnimatedRotation(turns: quarterTurns / 4, duration: ..., child: ...)   // 0.25 = 90°
```
**Tier 1 secret weapon:** `AnimatedContainer` + `AnimatedOpacity` implement half the modifiers in this doc with no controllers at all.

### 1.9 `TweenAnimationBuilder` — animate ANY number once
```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0, end: 1),
  duration: const Duration(milliseconds: 300),
  builder: (context, t, child) => Opacity(opacity: t, child: child),
  child: Text('fades in'),
)
```

### 1.10 `AnimationController` — the manual gearbox (Tier 2)
For looping or precisely-controlled motion (spinning boards, pulsing blackouts):
```dart
class _MyState extends State<MyGame> with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: const Duration(seconds: 60))
      ..repeat();                       // loops forever, value goes 0.0 → 1.0
  }

  @override
  void dispose() { _spin.dispose(); super.dispose(); }   // ALWAYS dispose

  // In build(): AnimatedBuilder rebuilds ONLY its subtree every frame
  AnimatedBuilder(
    animation: _spin,
    builder: (context, child) =>
        Transform.rotate(angle: _spin.value * 2 * 3.14159, child: child),
    child: board,   // 'child' is built ONCE and reused — this is the perf trick
  )
}
```
`vsync: this` needs the `SingleTickerProviderStateMixin` on your State class (use `TickerProviderStateMixin` if you have several controllers).

### 1.11 `Transform` — move/rotate without relayout
```dart
Transform.rotate(angle: radians, child: board)        // radians = degrees * pi / 180
Transform.translate(offset: Offset(dx, dy), child: board)
```
Cheap: it happens at paint time. Note: it moves PIXELS, not touch targets — Part 4 A5 shows how to fix touch coordinates.

### 1.12 `CustomPaint` + `CustomPainter` — draw anything (Tier 2)
Instead of hundreds of Container cells, ONE canvas you draw on:
```dart
CustomPaint(
  size: Size(boardSize, boardSize),
  painter: BoardPainter(cells: cells, repaint: dragNotifier),
)

class BoardPainter extends CustomPainter {
  final List<List<int>> cells;
  BoardPainter({required this.cells, Listenable? repaint}) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / cells[0].length;
    final paintFill = Paint()..color = AppTheme.softSage;
    for (var r = 0; r < cells.length; r++) {
      for (var c = 0; c < cells[r].length; c++) {
        if (cells[r][c] == 1) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(c * cell + 2, r * cell + 2, cell - 4, cell - 4),
              const Radius.circular(8)),
            paintFill);
        }
      }
    }
    // also: canvas.drawLine(p1, p2, paint), drawCircle(center, radius, paint),
    // canvas.drawPath(path, paint), canvas.save()/translate()/rotate()/restore()
  }

  @override
  bool shouldRepaint(BoardPainter old) => old.cells != cells;  // repaint only when data changed
}
```
Two golden rules from `remember.md`: pass `repaint:` a Listenable (like your drag ValueNotifier) so painting bypasses `setState` entirely, and implement `shouldRepaint` honestly.
Text on canvas needs `TextPainter` — fiddly; your `_MasyuPainter` has working examples to copy.

### 1.13 `RepaintBoundary` — the fence
```dart
RepaintBoundary(child: CustomPaint(...))
```
Isolates repaints: the board repainting doesn't force the header to repaint, and vice versa. Wrap every game board in one (Grid Path line 1065 already does — copy that pattern).

### 1.14 Clocks and timers
```dart
// Tier 1 clock — simple and fine:
_timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => elapsed++));
// cancel in dispose(): _timer?.cancel();

// One-shot delay:
Future.delayed(const Duration(milliseconds: 400), () { if (mounted) ... });

// Tier 2 clock — a smooth per-frame clock without setState:
late final Ticker _ticker;                    // needs SingleTickerProviderStateMixin
final clock = ValueNotifier<double>(0);
_ticker = createTicker((elapsed) => clock.value = elapsed.inMilliseconds / 1000.0)..start();
```
`if (mounted)` before touching state in any delayed callback — prevents crashes when the user already left the screen.

### 1.15 Haptics — 1-line juice
```dart
import 'package:flutter/services.dart';
HapticFeedback.lightImpact();     // soft tick — cell snap, detent
HapticFeedback.mediumImpact();    // thud — wall hit
HapticFeedback.selectionClick();  // tiny — scrolling through options
```
Your app currently uses ZERO haptics. Part 3.8 adds the settings toggle; then sprinkle these at the "juice" moments each game lists.

### 1.16 `flutter_animate` — one-line effects (already in pubspec)
```dart
import 'package:flutter_animate/flutter_animate.dart';
Text('hi').animate().fadeIn(duration: 240.ms)
board.animate(target: shakeCount.toDouble())        // increments retrigger the effect
     .shake(duration: 400.ms, hz: 6, offset: const Offset(6, 0))
```

### 1.17 Reading finger position relative to board center (for rotation games)
```dart
final center = Offset(boardSize / 2, boardSize / 2);
final v = details.localPosition - center;
final angle = math.atan2(v.dy, v.dx);   // radians, 0 = right, pi/2 = down
final dist  = v.distance;               // pixels from center
```
`import 'dart:math' as math;` — you'll use `math.pi`, `math.atan2`, `math.cos`, `math.sin`, `math.Random`.

### 1.18 Your app's own building blocks (already exist — just import and use)
| Widget / API | File | What it does |
|---|---|---|
| `ConfettiOverlay` | `lib/widgets/confetti_overlay.dart` | win celebration layer |
| `AutoNextCountdown` | `lib/widgets/auto_next_countdown.dart` | "next level in 3…2…1" |
| `LossOverlay` | `lib/widgets/loss_overlay.dart` | defeat screen w/ retry |
| `GameTutorialDialog` | `lib/widgets/game_tutorial_dialog.dart` | first-open rules popup |
| `BuyHintsDialog` | `lib/widgets/buy_hints_dialog.dart` | hint purchase sheet |
| `FogOverlay` | `lib/widgets/fog_overlay.dart` | existing fog modifier layer |
| `AnimatedLevelIndicator` | `lib/widgets/animated_level_indicator.dart` | header level pill |
| `HintManager.startLevel(id)` / `.useHint(id)` / `.onLevelCleared(id)` | `lib/utils/hint_manager.dart` | hint economy |
| `PointManager.addPoints(n)` / `.consumePoints(n)` | `lib/utils/point_manager.dart` | points economy |
| `RotationEngine.getDeterminism(id, level)` → `Random` | `lib/utils/rotation_engine.dart` | seeded RNG — same level always generates identically |
| `RotationEngine.getDecayValue(level:, start:, floor:, rate:)` | same | smooth difficulty curve number |
| `RotationEngine.getActiveModifiers(gameId:, levelIndex:, pool:, minActive:, maxActive:)` | same | picks this level's modifiers |
| `AppTheme.accentFor(id)` / palette constants | `lib/theme/app_theme.dart` | game colors |

**The seeded-RNG law:** never write `Random()` in game code. Always
```dart
final rng = RotationEngine.getDeterminism('sandsort', levelIndex);
```
Same `(gameId, level)` → same puzzle, forever, on every device. This is what makes hints, daily challenges, and bug reports reproducible.


---

# PART 2 — THE ARCHITECTURE PATTERN (read once, use forever)

### 2.1 Files for every new game

```
lib/screens/games/sandsort/
├── sandsort_logic.dart      ← pure Dart game brain (NO 'package:flutter' imports)
├── sandsort_screen.dart     ← the UI (Tier 1 now, Tier 2 later)
└── sandsort_painter.dart    ← created only when you upgrade to Tier 2
```

### 2.2 The logic-file contract

Every `_logic.dart` exposes the same four things. If you follow this shape, all nine games feel identical to build:

```dart
// sandsort_logic.dart — NO flutter imports. 'dart:math' is allowed.
import 'dart:math';

class SandSortGame {
  // 1. STATE — plain fields
  late List<List<int>> tubes;      // tubes[t] = list of color ids, bottom→top
  int tubeCapacity = 4;
  int pours = 0;

  // 2. GENERATION — deterministic, from a Random you pass in
  void generate(Random rng, int level) { ... }

  // 3. MOVES — mutate state, return whether the move was legal/what happened
  bool pour(int from, int to) { ... }

  // 4. QUERIES — read-only checks the UI calls after every move
  bool get isWon => ...;
  bool canPour(int from, int to) => ...;
}
```

Why this matters for YOU specifically: you can unit-test the brain without any UI (`test/sandsort_test.dart`: create game, call `generate(Random(42), 1)`, assert `isWon` after replaying solution), and you can rewrite the screen twice (Tier 1 → Tier 2) without ever touching game rules.

### 2.3 The screen-file skeleton (Tier 1) — memorize this shape

Every Tier 1 screen in Part 5 is this exact skeleton with the board area swapped:

```dart
// <id>_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';                 // haptics
import '../../../theme/app_theme.dart';
import '../../../utils/rotation_engine.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/point_manager.dart';
import '../../../widgets/confetti_overlay.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/loss_overlay.dart';
import '../../../widgets/game_tutorial_dialog.dart';
import 'sandsort_logic.dart';

class SandSortScreen extends StatefulWidget {
  const SandSortScreen({super.key});
  @override
  State<SandSortScreen> createState() => _SandSortScreenState();
}

class _SandSortScreenState extends State<SandSortScreen> {
  final game = SandSortGame();
  int level = 0;                       // TODO: load from SharedPreferences (see 3.6)
  bool won = false, lost = false;
  Set<String> activeModifiers = {};

  @override
  void initState() {
    super.initState();
    _startLevel();
  }

  void _startLevel() {
    won = false; lost = false;
    activeModifiers = RotationEngine.getActiveModifiers(
      gameId: 'sandsort', levelIndex: level,
      pool: ['quota', 'ratchet', 'monochrome'], minActive: 0, maxActive: 2);
    game.generate(RotationEngine.getDeterminism('sandsort', level), level);
    HintManager.startLevel('sandsort');
    setState(() {});
  }

  Future<void> _onWin() async {
    setState(() => won = true);
    HapticFeedback.mediumImpact();
    await PointManager.addPoints(10);
    await HintManager.onLevelCleared('sandsort');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sand Sort')),
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            _buildHeader(),                       // level pill, hint button, modifier chips
            const SizedBox(height: 12),
            Expanded(child: Center(child: _buildBoard())),   // ← the only part that varies
          ]),
          if (won) ...[
            const ConfettiOverlay(),
            AutoNextCountdown(onNext: () { level++; _startLevel(); }),
          ],
          if (lost) LossOverlay(onRetry: _startLevel),
        ]),
      ),
    );
  }

  Widget _buildHeader() { /* Part 3.4 template */ return const SizedBox(); }
  Widget _buildBoard()  { /* per-game, see Part 5 */ return const SizedBox(); }
}
```

> ⚠️ Check the constructor parameters of `AutoNextCountdown` and `LossOverlay` in `lib/widgets/` before using — copy a call site from `grid_path_screen.dart` line ~1249 so the named params match exactly. (I'm giving you the shape; the widget files are the source of truth for exact parameter names.)

### 2.4 The Tier 1 → Tier 2 upgrade recipe (same 5 steps every time)

1. **Create `<id>_painter.dart`.** Move all the visual math from your `itemBuilder`/cell Containers into a `CustomPainter.paint()` that loops over `game` state and draws rects/circles/lines (Primer 1.12).
2. **Replace the board widget.** `GridView.builder` → `RepaintBoundary(child: GestureDetector(child: CustomPaint(painter: ...)))`. Your tap math barely changes: you were computing row/col from `localPosition` already.
3. **Move the hot value into a `ValueNotifier`.** Whatever changes during a drag (dragged piece position, current trace path, ring angle) becomes a notifier. Pass it to the painter as `repaint:`.
4. **Delete `setState` from `onPanUpdate`.** Update the notifier instead. Keep `setState` only in `onPanEnd`/`onTap` where a discrete game-state change commits.
5. **Implement `shouldRepaint`** comparing the fields that matter, and run the profile-mode drag test (Part 6.2).

That's it. Steps 1–2 are an afternoon; 3–5 are an hour. After you've done it once on Sand Sort, the other games are muscle memory.

### 2.5 Modifier plumbing — one tiny shared file

Create **`lib/utils/modifier_params.dart`** (new file):

```dart
/// Central defaults for modifier tuning. Daily challenges can override
/// these via extraParams; free-play uses these values.
class ModifierParams {
  static const drift      = {'interval': 12, 'animMs': 300};
  static const decay      = {'grace': 25, 'fadeMs': 5000, 'revealCostSec': 2};
  static const quota      = {'multStart': 2.0, 'multFloor': 1.15, 'rate': 40.0};
  static const heartbeat  = {'visibleMs': 1500, 'blackoutMs': 2500};
  static const vertigo    = {'degPerSec': 6};
  static const silence    = {'attempts': 3};
  static const wildcard   = {'hidePct': 0.3};
  static const ratchet    = {'strikes': 2};
  static const momentum   = {'windowMs': 4000, 'cap': 5};
  static const seismic    = {'hidePerMistake': 1};
}
```

In every game screen you already get `activeModifiers` (a `Set<String>`) from `RotationEngine.getActiveModifiers`. Modifier checks are then just:

```dart
final noUndo = activeModifiers.contains('ratchet');
```

Daily-challenge mode instead passes ONE forced `modifierType` string + `extraParams` map (this is how your existing games do it — see `grid_path_screen.dart` line ~1196). Support both: `bool has(String m) => activeModifiers.contains(m) || dailyModifierType == m;`

---

# PART 3 — COPY-PASTE INTEGRATION TEMPLATES
### Exact files, exact insert locations, exact code

### 3.1 Register the game — `lib/models/game_info.dart`
Find the `kAllGames` list. Add one line (keep the column alignment style):
```dart
  GameInfo(id:'sandsort', name:'Sand Sort', description:'Pour sand layers until every tube is one color', emoji:'⏳', routeName:'/sandsort'),
```
Set `isStashed: true` to soft-launch hidden. **Do not** put new games in the beta tab.

### 3.2 Route — `lib/main.dart`
Find the routes map (around line 200, where `'/zip'` and `'/sudoku'` live). Add:
```dart
            '/sandsort': (ctx) => const SandSortScreen(),
```
…and the import at the top of `main.dart`:
```dart
import 'screens/games/sandsort/sandsort_screen.dart';
```

### 3.3 Accent color — `lib/theme/app_theme.dart`
Inside `static Color accentFor(String id)`'s switch, before `default:`:
```dart
      case 'sandsort':    return terracotta;
```
(Use the accent assigned per game in Part 5. Then use `AppTheme.accentFor('sandsort')` inside the screen for buttons/highlights — never hardcode colors.)

### 3.4 Header template (used by every screen) — goes in your screen file
```dart
Widget _buildHeader() {
  final accent = AppTheme.accentFor('sandsort');
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(children: [
      // Level pill
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10)),
        child: Text('Level ${level + 1}',
          style: TextStyle(fontWeight: FontWeight.w600, color: accent)),
      ),
      const SizedBox(width: 8),
      // Modifier chips
      ...activeModifiers.map((m) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Chip(label: Text(m), visualDensity: VisualDensity.compact))),
      const Spacer(),
      // Hint button
      IconButton(
        icon: const Icon(Icons.lightbulb_outline),
        color: AppTheme.warmAmber,
        onPressed: _onHintPressed,
      ),
    ]),
  );
}

Future<void> _onHintPressed() async {
  final hints = await HintManager.getHints('sandsort');
  if (hints <= 0) {
    if (mounted) showDialog(context: context, builder: (_) => BuyHintsDialog(gameId: 'sandsort'));
    return;   // (check BuyHintsDialog's real constructor params in lib/widgets/)
  }
  await HintManager.useHint('sandsort');
  _applyHint();   // per-game, defined in Part 5
}
```

### 3.5 Rules text — `lib/utils/rules_helper.dart`
Open the file, find the map/switch keyed by game id, add your entry following the exact existing format (look at `'zip'`). Keep it 2–3 short sentences: what to do, how to win, one tip.

### 3.6 Level persistence — `lib/utils/prefs_keys.dart` + screen
Add the key constant to `prefs_keys.dart` following its naming pattern, e.g.:
```dart
static const sandsortLevel = 'sandsort_level';
```
Load/save in the screen:
```dart
final prefs = await SharedPreferences.getInstance();
level = prefs.getInt(PrefsKeys.sandsortLevel) ?? 0;      // in an async _init() from initState
await prefs.setInt(PrefsKeys.sandsortLevel, level);       // after every win, before _startLevel
```
(Match the exact class/constant naming style already in `prefs_keys.dart`.)

### 3.7 Daily challenge rows — `lib/utils/daily_challenge_manager.dart`
Only AFTER the game has been live and stable. Find the `_ChallengeData` list; copy an existing game's 3 rows and adapt:
```dart
// name, description, modifierType, extraParams — follow the exact constructor
// of _ChallengeData in this file. Example intent:
//  Sand Sort easy  → modifierType: 'quota',   extraParams: ModifierParams.quota
//  Sand Sort med   → modifierType: 'ratchet', extraParams: ModifierParams.ratchet
//  Sand Sort hard  → modifierType: 'fog',     extraParams: {}
```

### 3.8 Haptics setting (do this once, first) 
1. In `lib/utils/settings_manager.dart` (or wherever `settingsNotifier` lives — search `settingsNotifier`): add a `hapticsEnabled` bool persisted to prefs, default `true`, following the exact pattern of the existing sound/theme toggles.
2. Create **`lib/utils/haptics.dart`**:
```dart
import 'package:flutter/services.dart';
import 'settings_manager.dart';

class Haptics {
  static void light()  { if (SettingsManager.hapticsEnabled) HapticFeedback.lightImpact(); }
  static void medium() { if (SettingsManager.hapticsEnabled) HapticFeedback.mediumImpact(); }
  static void select() { if (SettingsManager.hapticsEnabled) HapticFeedback.selectionClick(); }
}
```
(Adapt the guard to however settings are actually exposed in that file.) 3. Add the toggle row in the settings screen UI next to the sound toggle. From now on, every "juice" note in Parts 4–5 means calling `Haptics.light()` etc.

### 3.9 The full new-game checklist (print this)
- [ ] `<id>_logic.dart` written, unit-testable, no Flutter imports
- [ ] `<id>_screen.dart` Tier 1 running
- [ ] `kAllGames` entry (3.1) — stashed if soft-launching
- [ ] Route + import in `main.dart` (3.2)
- [ ] `accentFor` case (3.3)
- [ ] Rules text (3.5) + `GameTutorialDialog` shown on first open (copy how grid_path does it)
- [ ] Level persistence (3.6)
- [ ] Hints wired (3.4) with a real `_applyHint()`
- [ ] Points: `PointManager.addPoints(10)` on win
- [ ] `RecentlyPlayedManager` called on open (copy one line from any active game)
- [ ] Haptics at the listed juice moments
- [ ] Tier 2 upgrade done (2.4) + profile drag test passed (6.2)
- [ ] Daily rows (3.7) once stable

---

# PART 4 — THE 12 MODIFIERS, FULLY DETAILED
### Each: what the player sees → files → Tier 1 code → Tier 2 upgrade → tests

Modifiers are branches inside EXISTING game screens, keyed off `activeModifiers` / the daily `modifierType`. Build them in the order listed — the first four need no timers or painters at all.

---

## A6 `silence` — "No Feedback" ⭐ BUILD FIRST (easiest)

**Player sees:** no red flashes, no error sounds. A **Submit** button appears. Wrong submit → "3 cells are wrong" (never which ones). 3 attempts, then loss.
**Games:** Sudoku, Killer Sudoku, Sum Strike, Mine Finder, Bridges, Star Battle.
**Files touched:** each target game's `_screen.dart` only.

### Tier 1 (this IS the final tier — nothing to upgrade)
Step 1 — add state to the game's State class:
```dart
bool get _silent => activeModifiers.contains('silence');
int _submitAttempts = 3;
```
Step 2 — find the game's per-move validation. Search the file for where it colors a cell red / plays error / checks correctness after input (in Sudoku it's right after a number is placed). Wrap it:
```dart
if (!_silent) {
  // ...the existing validation/feedback code, unchanged...
}
```
Step 3 — add the Submit button to the header row (only when `_silent`):
```dart
if (_silent)
  FilledButton.tonal(
    onPressed: _onSubmitSilent,
    child: Text('Submit ($_submitAttempts)'),
  ),
```
Step 4 — implement submit using the game's existing solution data (every logic game stores its solution — search for `solution`, `_answer`, or the win-check function):
```dart
void _onSubmitSilent() {
  int wrong = 0;
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (playerGrid[r][c] != 0 && playerGrid[r][c] != solution[r][c]) wrong++;
    }
  }
  if (wrong == 0 && _boardIsFull()) { _onWin(); return; }
  setState(() => _submitAttempts--);
  Haptics.medium();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(wrong == 0 ? 'No errors — but the board is not complete'
                                      : '$wrong cell${wrong == 1 ? '' : 's'} wrong')));
  if (_submitAttempts <= 0) setState(() => lost = true);
}
```
**Tests:** place a known-wrong cell → no red flash; submit shows "1 cell wrong"; 3 bad submits → LossOverlay; correct full board → win.

---

## A3 `quota` — "Move Budget"

**Player sees:** a pill "Moves: 12" counting down with every action; flashes terracotta at ≤3; 0 → loss with "Watch ad +5".
**Games:** Color Flood, Circuit Guide, Grid Path, Colour Link, Pattern Lock (+ every new Part 5 game that lists it).
**Files:** each game's `_screen.dart`; `lib/utils/modifier_params.dart` (already created in 2.5).

### Tier 1
```dart
// State:
int _movesLeft = 0;
bool get _quota => activeModifiers.contains('quota');

// In _startLevel(), AFTER generation (each game knows its optimal — see note):
if (_quota) {
  final mult = RotationEngine.getDecayValue(
      level: level, start: 2.0, floor: 1.15, rate: 40);
  _movesLeft = (optimalMoves * mult).ceil();
}

// At the TOP of every state-mutating input handler:
if (_quota) {
  if (_movesLeft <= 0) return;
  setState(() => _movesLeft--);
  if (_movesLeft == 0 && !game.isWon) _onOutOfMoves();
}
```
Header pill (drop into `_buildHeader`'s Row):
```dart
if (_quota)
  AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: (_movesLeft <= 3 ? AppTheme.terracotta : AppTheme.slateBlue)
             .withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(10)),
    child: Text('Moves: $_movesLeft', style: const TextStyle(fontWeight: FontWeight.w600)),
  ),
```
Out-of-moves flow (reuse the rewarded-ad pattern — copy the exact `AdManager` call from wherever the app already shows rewarded ads, search `showRewarded` in `lib/`):
```dart
void _onOutOfMoves() {
  setState(() => lost = true);
  // In LossOverlay's retry area, offer: watch ad → _movesLeft += 5; lost = false;
}
```
**Where `optimalMoves` comes from per game:** Color Flood & Circuit Guide — they already compute a solution for hints; count its steps. Grid Path — the path length is known at generation. Colour Link — sum of solution link lengths. New games — Part 5 tells you each one's optimal at generation time.

### Tier 2 upgrade
Move `_movesLeft` into a `ValueNotifier<int>` and wrap ONLY the pill in `ValueListenableBuilder`, so decrementing during a drag chain doesn't rebuild the whole screen. 10-minute change.

**Tests:** optimal-length play wins with moves to spare; wasting moves hits 0 → loss; pill turns terracotta at 3.

---

## A8 `ratchet` — "No Way Back"

**Player sees:** undo/erase buttons greyed with a lock; first mistake turns the cell amber permanently ("crack"); second mistake = loss.
**Games:** Sudoku, Star Battle, Mine Finder, Grid Path, Colour Link, Pearl Loop.

### Tier 1 (final)
```dart
bool get _ratchet => activeModifiers.contains('ratchet');
int _strikes = 0;
final Set<int> _crackedCells = {};   // r * cols + c

// Gate the existing undo/erase buttons:
IconButton(
  icon: Icon(_ratchet ? Icons.lock_outline : Icons.undo),
  onPressed: _ratchet ? null : _undo,    // null = automatically greyed out
),

// Where the game detects a wrong placement (the code you gated in `silence` —
// ratchet and silence are mutually exclusive in pools, don't combine them):
if (_ratchet && isWrong) {
  _strikes++;
  _crackedCells.add(r * cols + c);
  Haptics.medium();
  if (_strikes >= 2) { setState(() => lost = true); return; }
}

// In the cell rendering, tint cracked cells:
color: _crackedCells.contains(r * cols + c)
    ? AppTheme.warmAmber.withValues(alpha: 0.35)
    : normalColor,
```
**Pool note:** when adding to a game's modifier pool, ensure `ratchet` and `silence` aren't both in the same pool list (they contradict — one defers validation, the other punishes instantly).
**Tests:** undo greyed; 1st error → amber cell, game continues; 2nd → loss.

---

## A7 `wildcard` — "Mystery Clues"

**Player sees:** ~30% of clue numbers show "?" — the rule still applies.
**Games:** Killer Sudoku (cage sums), Sum Strike, Mine Finder, Bridges, Skyscraper-likes.

### Tier 1 (final)
The whole modifier is a render-time mask. In `_startLevel()` after generation:
```dart
Set<int> _hiddenClues = {};
if (activeModifiers.contains('wildcard')) {
  final rng = RotationEngine.getDeterminism('minesweeper_wild', level); // unique salt!
  _hiddenClues = {
    for (var i = 0; i < clueCount; i++)
      if (rng.nextDouble() < 0.3) i
  };
}
```
Then in clue rendering:
```dart
Text(_hiddenClues.contains(clueIndex) ? '?' : '$clueValue')
```
Two rules: **never** mutate the underlying data (only the displayed string), and use a salted gameId (`'<id>_wild'`) so the hidden set differs from other seeded choices in the same level.
**Tests:** same level → same ?s every time; validation still uses true values; % roughly 30 over many clues.

---

## A9 `momentum` — "Combo Streak" (first reward-positive modifier)

> ## ⚠️ BUILT IN 2.2 — **4 defects**. See `lib/widgets/momentum_meter.dart`.
>
> 1. **The points instruction is impossible and double-pays.** "Replace `addPoints(10)`" —
>    there is no `addPoints(10)` in any game screen. `HintManager.onLevelCleared` holds the
>    base 10 for all 23 games and a screen cannot remove it. Following this pays
>    `10 + 10x avg`. **Shipped composition:** momentum pays only the *excess over base*,
>    `(10*avg).round() - 10` clamped 0..40, so an unchained clear (x1) pays **0** and is
>    worth exactly what it was before. The `addPoints(5)` speed bonus is separate and is
>    **not** multiplied.
> 2. **`correct()` increments before recording**, so the *first* correct action is credited
>    x2 — every level with one scored action paid double for nothing.
> 3. **Most suggested games have no scored move.** Odd Colour Out is one tap per level (its
>    average is a constant, so this is flat inflation with no skill signal); Colour Flood and
>    Spectrum have no correct/incorrect move at all.
> 4. **The meter grows its font with the multiplier** (`fontSize: 13.0 + m`). A chip that
>    grows is a chip that overflows.


**Player sees:** a small flame meter; correct actions within 4s of each other build ×1→×5; completion points = 10 × average multiplier; mistakes/idle reset to ×1.
**Games:** Odd Color Out, Spectrum, Chimp Test, Word Hive, Color Flood, Sum Strike + new perception games.
**New file:** `lib/widgets/momentum_meter.dart` (shared).

### Tier 1
The meter is a self-contained widget so the host game barely changes:
```dart
// lib/widgets/momentum_meter.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MomentumController {
  int multiplier = 1;
  int _events = 0; double _multSum = 0;
  Timer? _decay;
  final void Function() onChanged;
  MomentumController({required this.onChanged});

  void correct() {
    multiplier = (multiplier + 1).clamp(1, 5);
    _events++; _multSum += multiplier;
    _restartDecay(); onChanged();
  }
  void mistake() { multiplier = 1; _restartDecay(); onChanged(); }
  void _restartDecay() {
    _decay?.cancel();
    _decay = Timer(const Duration(milliseconds: 4000), () { multiplier = 1; onChanged(); });
  }
  double get averageMultiplier => _events == 0 ? 1 : _multSum / _events;
  void dispose() => _decay?.cancel();
}

class MomentumMeter extends StatelessWidget {
  final MomentumController controller;
  const MomentumMeter({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final m = controller.multiplier;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.warmAmber.withValues(alpha: 0.10 + 0.12 * m),
        borderRadius: BorderRadius.circular(10)),
      child: Text('🔥 ×$m',
        style: TextStyle(fontWeight: FontWeight.w700,
          fontSize: 13.0 + m,          // grows as it heats up
          color: AppTheme.warmAmber)),
    );
  }
}
```
Host-game wiring:
```dart
late final momentum = MomentumController(onChanged: () => setState(() {}));
// on every correct action:   momentum.correct(); Haptics.select();
// on every mistake:          momentum.mistake();
// header:                    if (_hasMomentum) MomentumMeter(controller: momentum),
// on win, REPLACE addPoints(10):
await PointManager.addPoints((10 * momentum.averageMultiplier).round());
// dispose():                 momentum.dispose();
```
### Tier 2 upgrade
Swap `onChanged: () => setState((){})` for a `ValueNotifier<int>` + `ValueListenableBuilder` around just the meter. Add a `flutter_animate` `.shimmer()` on the meter at ×5.
**Tests:** rapid corrects climb to ×5 and stop; 4s idle resets; win points scale.

---

## A2 `decay` — "Fading Clues"

> ## ⚠️ BUILT IN 2.2 — **3 defects**. See `lib/widgets/decaying_clue.dart`.
>
> 1. **The 5-point re-reveal charge is an unbounded points sink** and ignores
>    `consumePoints`'s return value — so a rich player is charged and a broke player
>    re-reveals free. **Refused.** The cost shipped is the short reveal window itself, plus
>    2s off the clock on a timed level.
> 2. **Code and prose contradict.** The prose promises a 3-second re-reveal;
>    `_revealedAt[i] = _clock` hands back the full 25-second hold. A permanent restore is
>    not a modifier.
> 3. Clue **ink** may fade; clue **values** must never be touched, or the solver and win
>    check diverge from what the player sees.


**Player sees:** each clue slowly fades to 15% after ~25s on screen; tapping a faded clue re-reveals it 3s but costs (2s on timer, or 5 points untimed).
**Games:** Sudoku, Killer Sudoku, Mine Finder, Sum Strike, Bridges.

### Tier 1 — with a plain 1-second Timer + AnimatedOpacity (good enough!)
```dart
// State:
bool get _decay => activeModifiers.contains('decay');
int _clock = 0;                                   // seconds since level start
final Map<int, int> _revealedAt = {};             // clueIndex → reveal second
Timer? _decayTimer;

// _startLevel():
if (_decay) {
  _decayTimer?.cancel();
  _clock = 0;
  _decayTimer = Timer.periodic(const Duration(seconds: 1),
      (_) => setState(() => _clock++));
}
// dispose(): _decayTimer?.cancel();

double _clueOpacity(int i) {
  if (!_decay) return 1;
  final shownAt = _revealedAt[i] ?? 0;
  final visibleFor = _clock - shownAt;
  if (visibleFor < 25) return 1;
  if (visibleFor < 30) return 1 - 0.85 * ((visibleFor - 25) / 5);  // fade 25→30s
  return 0.15;
}

void _tapClue(int i) {
  if (!_decay || _clueOpacity(i) > 0.9) return;
  PointManager.consumePoints(5);          // or add 2s to the game's timer if timed
  setState(() => _revealedAt[i] = _clock);
  Haptics.light();
}
```
Render each clue wrapped in:
```dart
GestureDetector(
  onTap: () => _tapClue(i),
  child: AnimatedOpacity(
    opacity: _clueOpacity(i),
    duration: const Duration(milliseconds: 400),
    child: Text('$clueValue')),
)
```
The 1-second tick makes fades slightly steppy — `AnimatedOpacity` smooths each step, and honestly it looks fine.

### Tier 2 upgrade
Replace `Timer.periodic` + `setState` with a `Ticker` writing a `ValueNotifier<double> clock` (Primer 1.14), and compute opacity inside the game's `CustomPainter` using `clock` as the `repaint:` listenable. Buttery fades, zero rebuilds. Only worth it on painter-based games (Bridges, Mine Finder Tier 2).
**Tests:** clue fades after 25s; tap re-reveals and deducts; all clues fade independently.

---

## A4 `heartbeat` — "Pulse Vision"

> ## ⚠️ BUILT IN 2.2 — **4 defects**. See `lib/widgets/pulse_vision.dart`.
>
> 1. **It is `eclipse` under a second name.** `eclipse` already *is* a periodic blackout in
>    this codebase (`odd_color_out_screen.dart` toggles `_isShadowed` on a 3s
>    `Timer.periodic`). The two must never share a pool.
> 2. **The `schedule()` loop never stops** — no won/lost guard, so the pulse and its haptic
>    keep firing behind the win overlay.
> 3. **The ghost-grid overlay does not generalise** — it builds a fresh `GridView`, and Sand
>    Sort's board is a `Wrap` of tubes. Fade contents *in place* so hit targets never move.
> 4. **62% blind in a turn-based puzzle is a patience tax, not difficulty** — a patient
>    player waits every blank phase out for free. Only pool it alongside `timer`, where
>    waiting has a price.


**Player sees:** board visible 1.5s, silhouette 2.5s, looping. Input works during blackout.
**Games:** Odd Color Out, Spectrum, Mine Finder, Chimp Test, Pearl Loop.

### Tier 1 — Timer + AnimatedOpacity trick
Don't hide the board — cover it with a "silhouette sheet" that shows only cell borders:
```dart
bool _pulseVisible = true;
Timer? _pulse;

void _startPulse() {
  _pulse?.cancel();
  void schedule() {
    _pulse = Timer(Duration(milliseconds: _pulseVisible ? 1500 : 2500), () {
      if (!mounted) return;
      setState(() => _pulseVisible = !_pulseVisible);
      if (_pulseVisible) Haptics.light();
      schedule();
    });
  }
  schedule();
}
// call _startPulse() in _startLevel() when active; cancel in dispose()
```
Board area becomes a Stack:
```dart
Stack(children: [
  _buildBoard(),                                  // your normal board, input intact
  IgnorePointer(                                  // sheet never blocks touches
    child: AnimatedOpacity(
      opacity: _pulseVisible ? 0 : 1,
      duration: const Duration(milliseconds: 250),
      child: Container(                            // flat silhouette
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12)),
        child: GridView.builder(                   // borders-only ghost grid
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols),
          itemCount: rows * cols,
          itemBuilder: (_, __) => Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline, width: 1),
              borderRadius: BorderRadius.circular(6))),
        ),
      ),
    ),
  ),
]),
```
`IgnorePointer` is the key: taps pass straight through the cover to the real board — "playing blind" works for free.

### Tier 2 upgrade
`AnimationController` looping 4000ms; painter reads phase and draws contents only when `phase < 0.375`; silhouette drawn by the same painter. One widget instead of a Stack.
**Tests:** rhythm correct; taps register during blackout; haptic tick on reveal.

---

## A10 `seismic` — "Aftershock"

**Player sees:** every mistake → violent 400ms shake AND one clue disappears forever.
**Games:** Sudoku, Killer Sudoku, Mine Finder, Bridges, Sum Strike.

### Tier 1 (final for most games)
```dart
// State:
int _shakeCount = 0;                       // incrementing retriggers the effect
late List<int> _clueDoomOrder;             // precomputed seeded order
int _cluesHidden = 0;

// _startLevel():
final rng = RotationEngine.getDeterminism('sudoku_seismic', level);
_clueDoomOrder = List.generate(clueCount, (i) => i)..shuffle(rng);
_cluesHidden = 0; _shakeCount = 0;

// On mistake (same hook as ratchet's):
if (activeModifiers.contains('seismic')) {
  setState(() { _shakeCount++; _cluesHidden++; });
  Haptics.medium();
}

// Clue visibility check (combine with wildcard's mask if both exist):
bool _clueDoomed(int i) =>
    _clueDoomOrder.indexOf(i) < _cluesHidden;
// render doomed clues as '' (empty), NOT '?'

// Wrap the board in the shake:
import 'package:flutter_animate/flutter_animate.dart';
_buildBoard()
  .animate(target: _shakeCount.toDouble())
  .shake(duration: 400.ms, hz: 6, offset: const Offset(6, 0)),
```
Precomputing `_clueDoomOrder` keeps it deterministic: the SAME clues die in the SAME order for everyone on that level — fair daily challenges.
**Tests:** each mistake shakes + removes exactly one clue; replay level → same doom order.

---

## A1 `drift` — "Drifting Board"

**Player sees:** every N seconds the whole board slides one cell (wrapping) with a 300ms glide. Contents/logic unchanged — only WHERE things render.
**Games:** Grid Path, Pearl Loop, Colour Link, Mine Finder, Star Battle.

### Tier 1 — logical drift (recommended to start): shift the DATA, not the pixels
Much easier than render offsets, looks identical for tap games:
```dart
int _driftRow = 0, _driftCol = 0;          // logical offset
Timer? _drift;
final _dirs = const [(0,1),(1,0),(0,-1),(-1,0)];  // R, D, L, U
int _dirIndex = 0;

void _startDrift() {
  final rng = RotationEngine.getDeterminism('minesweeper_drift', level);
  _dirIndex = rng.nextInt(4);
  _drift = Timer.periodic(const Duration(seconds: 12), (_) {
    final d = _dirs[_dirIndex];
    _dirIndex = (_dirIndex + 1) % 4;
    setState(() {
      _driftRow = (_driftRow + d.$1) % rows;
      _driftCol = (_driftCol + d.$2) % cols;
    });
    Haptics.light();
  });
}
// Mapping helpers — use EVERYWHERE the UI touches the grid:
int _vr(int screenRow) => (screenRow + _driftRow) % rows;   // view→data
int _vc(int screenCol) => (screenCol + _driftCol) % cols;
// itemBuilder: final value = grid[_vr(row)][_vc(col)];
// tap handler: game.tap(_vr(row), _vc(col));
```
The board "teleports" each step rather than gliding — acceptable for Tier 1.

### Tier 2 — smooth pixel glide
Add `Offset renderOffset` animated by a 300ms `AnimationController` between drift steps; the painter does `canvas.translate(renderOffset.dx, renderOffset.dy)` and draws the grid twice (main + wrapped edge strip); pan handlers subtract `renderOffset` before hit-testing. Do this only after the target game is already painter-based.
**Tests:** clue at (0,0) reappears shifted after each interval; taps still hit the intended cell; direction cycles R→D→L→U.

---

## A5 `vertigo` — "Spinning Table"

**Player sees:** board rotates continuously (4–10°/s). Everything still works.
**Games:** Star Battle, Odd Color Out, Pattern Lock, Mine Finder, Sudoku(4×4).

### Tier 1 — rotate a TAP-ONLY game (start with Odd Color Out)
For pure-tap games, `Transform.rotate` rotates both pixels AND hit-testing correctly (Flutter transforms pointer events through the transform automatically for widget children). So Tier 1 is genuinely tiny:
```dart
late final AnimationController _spin;   // + SingleTickerProviderStateMixin

// initState:
_spin = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
// dispose: _spin.dispose();

// Wrap the board:
AnimatedBuilder(
  animation: _spin,
  builder: (context, child) => Transform.rotate(
    angle: _spin.value * 2 * math.pi * (6 / 6),   // 6°/s over a 60s controller = 360°
    child: child),
  child: RepaintBoundary(child: _buildBoard()),   // child built once — cheap
)
```
Speed control: `degPerSec / 6` as the multiplier with a 60s controller.
### Tier 2 — rotation over a CustomPainter board (drag games)
Painter boards receive raw `localPosition` — you must inverse-rotate it yourself:
```dart
Offset _unrotate(Offset p, double angle, Size board) {
  final c = Offset(board.width / 2, board.height / 2);
  final v = p - c;
  final ca = math.cos(-angle), sa = math.sin(-angle);
  return Offset(v.dx * ca - v.dy * sa, v.dx * sa + v.dy * ca) + c;
}
// onPanUpdate: final p = _unrotate(details.localPosition, currentAngle, boardSize);
```
`currentAngle = _spin.value * 2 * math.pi * speedFactor` read at event time.
**Tests:** taps land on the visually-touched cell at 0°, 90°, 173°; no jank (rotation is a raster transform thanks to RepaintBoundary).

---

## A11 `inverse` — "Opposite Day"

**Player sees:** a persistent "🔄 INVERTED" chip; controls mean the opposite.
**Games + their inversion:** Mine Finder (tap⇄long-press: tap flags, hold reveals) · Sudoku (number cycling runs backward) · Grid Path (dragging over filled cells erases; over empty draws) · Color Flood (tapped color floods from the border inward — skip this one until last, it needs logic changes).

### Tier 1 (final) — it's a tiny input-mapping shim
Mine Finder example — find its tap and long-press handlers:
```dart
bool get _inv => activeModifiers.contains('inverse');

onTap:       () => _inv ? _flagCell(r, c)   : _revealCell(r, c),
onLongPress: () => _inv ? _revealCell(r, c) : _flagCell(r, c),
```
Sudoku number-cycle example:
```dart
value = _inv ? (value - 1 <= 0 ? 4 : value - 1)   // 4→3→2→1→4
             : (value + 1 > 4 ? 1 : value + 1);   // 1→2→3→4→1
```
Header chip (always visible while active — players must never wonder):
```dart
if (_inv)
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppTheme.dustyMauve.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(10)),
    child: const Text('🔄 INVERTED', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
```
**Tests:** each mapped action does the opposite; chip always shown; tutorial dialog explains it on first encounter (add to rules text).

---

## A12 `twin` — "Gemini Board" (grand-finale tier — build LAST)

**Player sees:** two half-size boards stacked; every move applies to both at mirrored coordinates; both must be solved.
**Games:** Grid Path, Pattern Lock, Colour Link, Star Battle (small grids only).

### Tier 1 — same widget twice, shared brain
Key insight: your logic class is pure (Part 2), so run ONE logic instance and render it twice — the twin isn't a second game, it's a second VIEW with a mirrored input map.
```dart
// Board A (normal) and Board B (mirrored) both call the same handler:
void _handleTap(int r, int c, {required bool mirrored}) {
  final realC = mirrored ? (cols - 1 - c) : c;
  game.tap(r, realC);              // ONE game state mutated once
  setState(() {});
}
// Board B's cells render grid[r][cols - 1 - c].
```
Generation constraint: the puzzle must be solvable under mirrored duplication — trivially true here because both views show the SAME underlying board (B is just A mirrored). The challenge for the player is purely perceptual: they must read a mirrored board half the time. Win condition unchanged: `game.isWon`.
Layout: `Column(children: [Expanded(child: boardA), SizedBox(height: 12), Expanded(child: boardB)])` inside the board area, each board in its own `AspectRatio(1)`.
### Tier 2
One painter class with a `mirror` flag: `if (mirror) { canvas.translate(size.width, 0); canvas.scale(-1, 1); }` at the top of `paint()` — then all drawing code is shared. Input un-mirroring stays in the handler as above.
**Tests:** tapping either board updates both instantly; mirrored board is a true reflection; win fires once.

---

### Modifier build order recap
1. `silence` → 2. `quota` → 3. `ratchet` → 4. `wildcard` (no timers, no painters)
5. `momentum` → 6. `decay` → 7. `heartbeat` → 8. `seismic` (Timer/animate level)
9. `drift` → 10. `vertigo` → 11. `inverse` (input remapping)
12. `twin` (after your first Tier 2 painter exists)

After each: add its 1-line explanation to the rules text of every game that uses it, and its `_ChallengeData` rows (3.7).

---

# PART 5 — THE 9 NEW GAMES, FULLY DETAILED

Order below = recommended build order. Sand Sort is written at maximum detail as your teaching project; later games reference its patterns instead of repeating them.

---

## B7 — SAND SORT ⭐ BUILD THIS FIRST
`id: sandsort` · route `/sandsort` · emoji ⏳ · accent **terracotta** · pillar: tactile tap-logic

**Rules:** Tubes hold layers of colored sand. Tap a source tube, tap a destination — the top color pours if the destination's top layer matches or the tube is empty. Contiguous same-color layers pour together. Win when every tube is single-colored (or empty).

### Files
```
lib/screens/games/sandsort/sandsort_logic.dart
lib/screens/games/sandsort/sandsort_screen.dart
lib/screens/games/sandsort/sandsort_painter.dart   (Tier 2 only)
```

### 5.7.1 The brain — `sandsort_logic.dart` (complete, copy this)
```dart
import 'dart:math';

class SandSortGame {
  /// tubes[t] is a stack of color ids (0..colors-1), index 0 = bottom.
  late List<List<int>> tubes;
  int capacity = 4;
  int colors = 3;
  int pours = 0;
  int optimalHint = 0;              // K from generation — quota uses ceil(K * mult)

  bool get isWon => tubes.every((t) =>
      t.isEmpty || (t.length == capacity && t.every((c) => c == t.first)));

  bool canPour(int from, int to) {
    if (from == to) return false;
    final f = tubes[from], t = tubes[to];
    if (f.isEmpty || t.length >= capacity) return false;
    return t.isEmpty || t.last == f.last;
  }

  /// Pours the contiguous top block. Returns how many units moved (0 = illegal).
  int pour(int from, int to) {
    if (!canPour(from, to)) return 0;
    final f = tubes[from], t = tubes[to];
    final color = f.last;
    var block = 0;
    for (var i = f.length - 1; i >= 0 && f[i] == color; i--) block++;
    final space = capacity - t.length;
    final moved = min(block, space);
    for (var i = 0; i < moved; i++) { f.removeLast(); t.add(color); }
    pours++;
    return moved;
  }

  /// Deterministic, ALWAYS-solvable generation:
  /// start solved, apply K legal REVERSE pours. (Random shuffling can deadlock;
  /// reverse-walking from solved cannot.)
  void generate(Random rng, int level) {
    colors = 3 + (level ~/ 15).clamp(0, 3);                 // 3 → 6
    final filled = colors;
    final empties = level < 25 ? 2 : 1;
    capacity = 4;
    pours = 0;
    tubes = [
      for (var c = 0; c < filled; c++) List.filled(capacity, c),
      for (var e = 0; e < empties; e++) <int>[],
    ];
    final k = (8 + level * 0.8).clamp(8, 60).toInt();       // scramble depth
    optimalHint = k;
    var applied = 0, guard = 0;
    while (applied < k && guard < k * 20) {
      guard++;
      final from = rng.nextInt(tubes.length);
      final to = rng.nextInt(tubes.length);
      if (!_reversePourOk(from, to)) continue;
      // reverse pour = move 1 unit from top of `from` onto `to`
      tubes[to].add(tubes[from].removeLast());
      applied++;
    }
    if (isWon) generate(Random(rng.nextInt(1 << 31)), level); // ultra-rare: re-roll
  }

  /// A reverse pour is legal iff the FORWARD pour (to→from) would be legal later.
  bool _reversePourOk(int from, int to) {
    if (from == to) return false;
    final f = tubes[from], t = tubes[to];
    if (f.isEmpty || t.length >= capacity) return false;
    // don't create trivial states: avoid pouring onto identical color from a pure tube
    if (f.length == capacity && f.every((c) => c == f.first)) return true; // breaking solved tubes is the point
    return true;
  }

  /// Greedy + 1-ply lookahead hint. Returns (from, to) or null.
  (int, int)? bestPour() {
    (int, int)? fallback;
    for (var a = 0; a < tubes.length; a++) {
      for (var b = 0; b < tubes.length; b++) {
        if (!canPour(a, b)) continue;
        fallback ??= (a, b);
        final t = tubes[b];
        // prefer pours that complete or grow a same-color stack, never into empty
        if (t.isNotEmpty && t.last == tubes[a].last) return (a, b);
      }
    }
    return fallback;
  }
}
```
**Concepts you just used:** records `(int,int)` for a pair, `clamp`, integer division `~/`, list-as-stack (`last`, `removeLast`, `add`). All plain Dart.

### 5.7.2 Tier 1 screen — the interesting parts
Start from the Part 2.3 skeleton with `SandSortGame`, pool `['quota','ratchet','monochrome','momentum']` (min 0, max 2). Then:

**State additions:**
```dart
int? _selected;                     // tapped source tube, null = none
```
**The board:** tubes laid out with `Wrap` (wraps to 2 rows automatically when tubes > 5):
```dart
Widget _buildBoard() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Wrap(
      spacing: 14, runSpacing: 20, alignment: WrapAlignment.center,
      children: [for (var t = 0; t < game.tubes.length; t++) _buildTube(t)],
    ),
  );
}
```
**One tube** — a tap target + a Column of layer Containers, bottom-aligned. `AnimatedContainer` on each layer makes pours look alive with zero animation code:
```dart
static const _sandColors = [AppTheme.terracotta, AppTheme.slateBlue, AppTheme.softSage,
                            AppTheme.warmAmber, AppTheme.dustyMauve, AppTheme.roseGold];

Widget _buildTube(int t) {
  final tube = game.tubes[t];
  final selected = _selected == t;
  const unitH = 34.0, tubeW = 52.0;
  return GestureDetector(
    onTap: () => _tapTube(t),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: tubeW,
      height: unitH * game.capacity + 12,
      // selected tube lifts up 8px — the classic sort-game affordance:
      transform: Matrix4.translationValues(0, selected ? -8 : 0, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(
          color: selected ? AppTheme.terracotta
                          : Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
          width: selected ? 2 : 1),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(8), bottom: Radius.circular(16)),
        boxShadow: AppTheme.cardShadow),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,        // layers sit at the bottom
        children: [
          for (var i = tube.length - 1; i >= 0; i--)     // draw top→bottom
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: unitH - 4, width: double.infinity,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: _sandColors[tube[i]],
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(i == tube.length - 1 ? 6 : 2),
                  bottom: Radius.circular(i == 0 ? 12 : 2))),
            ),
        ],
      ),
    ),
  );
}
```
**Tap logic** — the entire game loop:
```dart
void _tapTube(int t) {
  if (won || lost) return;
  if (_selected == null) {
    if (game.tubes[t].isEmpty) return;               // can't pick up from empty
    setState(() => _selected = t);
    Haptics.select();
    return;
  }
  if (_selected == t) { setState(() => _selected = null); return; }  // deselect
  final moved = game.pour(_selected!, t);
  if (moved == 0) {
    // illegal — snap selection to the new tube instead (feels better than error)
    setState(() => _selected = game.tubes[t].isEmpty ? null : t);
    return;
  }
  Haptics.light();
  momentum.correct();                                 // if momentum active
  setState(() => _selected = null);
  if (game.isWon) _onWin();
}
```
**Hint:**
```dart
void _applyHint() {
  final h = game.bestPour();
  if (h == null) return;
  setState(() => _selected = h.$1);                   // select the source…
  Future.delayed(const Duration(milliseconds: 600), () {
    if (mounted) _tapTube(h.$2);                       // …then auto-tap the destination
  });
}
```
**Modifier integration:** `quota` uses `optimalMoves = game.optimalHint` (A3 code verbatim). `ratchet` here means "no undo" only — there are no 'mistakes', so skip strikes. `monochrome`: replace `_sandColors[tube[i]]` fills with 6 distinct *patterns* — Tier 1 shortcut: same 6 colors but overlay a distinct icon per color id (`Icons.circle, square, change_history, star, favorite, hexagon` at 40% white) so colorblind-mode is honest.

### 5.7.3 Tier 2 upgrade (after you've played it!)
1. Tube fills → one `CustomPainter` per tube (or one for the whole board) drawing rounded rects; keeps the Wrap layout.
2. The pour animation: on pour, spawn an overlay entry — a small painter that draws `moved` grains falling along a quadratic curve from source-top to dest-top over 300ms (`TweenAnimationBuilder<double>` drives `t`, position = `lerp` between tube tops with a lifted control point). Granular haptic: `Haptics.light()` at start and end.
3. `_selected` → `ValueNotifier<int?>` so selection changes stop rebuilding all tubes.
### Tests
Same level twice → identical tubes. Pour merges contiguous blocks. Win detection with empty tubes. `bestPour` never returns illegal. Quota: solvable within budget at levels 1, 25, 60.

---

## B5 — ZEN SLIDE (build second — introduces BFS + swipes)

> ## ⚠️ BUILT IN 2.1 — the sketch below had **six defects**. See `zenslide_logic.dart`.
>
> The worst: the 200-attempt fallback kept the **last rejected** board and wrote
> `optimal = solve(stone).$1.clamp(1, 99)`. `solve` returns **-1** for an unreachable lotus,
> and `(-1).clamp(1, 99)` is **1** — so an unsolvable board was relabelled *"one move to
> solve"* and dealt. The clamp did not fix the failure, it **erased the evidence of it**.
>
> Also wrong: `d >= wantOptimal` let difficulty run backwards (an at-least gate accepts the
> first board over the bar, so level 10 could deal a 12-swipe puzzle and level 11 a 5-swipe
> one — shipped version gates on **equality**); an unbounded wall-placement rejection loop
> with no connectivity check; stone and lotus drawn independently so `stone == lotus`;
> `solve` with no node budget; a `late int lotus` dereferenced before first `generate`.
> In the screen snippets: `onPanEnd` keyed off `details.velocity` alone, so **every slow
> deliberate drag was silently discarded**, and one `cellSize` derived from width only.
>
> The ice-slide rule, "the lotus catches the stone", and "BFS doubles as the generation
> gate" are all sound and were kept.

`id: zenslide` · route `/zenslide` · emoji 🪨 · accent **softSage** · pillar: swipe-logic

**Rules:** Swipe anywhere — the sage stone slides in that direction until it hits a wall/edge/another stone (ice floor). Get the sage stone onto the lotus. Grey stones are movable obstacles (a swipe moves ALL stones one after another in swipe order from the far side — Tier 1 simplification: only the sage stone moves; grey stones are static walls. Ship that first; movable greys are the level-40 unlock).

### Files
```
lib/screens/games/zenslide/zenslide_logic.dart
lib/screens/games/zenslide/zenslide_screen.dart
```
### 5.5.1 `zenslide_logic.dart` (complete)
```dart
import 'dart:collection';
import 'dart:math';

class ZenSlideGame {
  late int rows, cols;
  late Set<int> walls;         // r * cols + c
  late int stone;              // sage stone position
  late int lotus;              // target position
  int moves = 0;
  int optimal = 0;

  int _idx(int r, int c) => r * cols + c;

  /// Slide from `pos` in direction (dr,dc) until blocked. Returns landing index.
  int _slide(int pos, int dr, int dc) {
    var r = pos ~/ cols, c = pos % cols;
    while (true) {
      final nr = r + dr, nc = c + dc;
      if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) break;
      if (walls.contains(_idx(nr, nc))) break;
      r = nr; c = nc;
      if (_idx(r, c) == lotus) break;     // lotus catches the stone (nice feel)
    }
    return _idx(r, c);
  }

  /// Player move. Returns true if the stone actually moved.
  bool swipe(int dr, int dc) {
    final next = _slide(stone, dr, dc);
    if (next == stone) return false;
    stone = next; moves++;
    return true;
  }

  bool get isWon => stone == lotus;

  static const dirs = [(-1,0),(1,0),(0,-1),(0,1)];

  /// BFS over stone positions → shortest swipe count from `from` to lotus.
  /// Also used by hints: returns the first direction of an optimal path.
  (int, (int,int)?) solve(int from) {
    final dist = <int,int>{from: 0};
    final firstDir = <int,(int,int)?>{from: null};
    final q = Queue<int>()..add(from);
    while (q.isNotEmpty) {
      final p = q.removeFirst();
      if (p == lotus) return (dist[p]!, firstDir[p]);
      for (final d in dirs) {
        final n = _slide(p, d.$1, d.$2);
        if (n == p || dist.containsKey(n)) continue;
        dist[n] = dist[p]! + 1;
        firstDir[n] = firstDir[p] ?? d;
        q.add(n);
      }
    }
    return (-1, null);   // unreachable
  }

  void generate(Random rng, int level) {
    rows = (6 + level ~/ 20).clamp(6, 9);
    cols = (5 + level ~/ 25).clamp(5, 7);
    final wantOptimal = (3 + level ~/ 6).clamp(3, 14);
    moves = 0;
    for (var attempt = 0; attempt < 200; attempt++) {
      walls = {};
      final wallCount = (rows * cols * 0.14).round() + rng.nextInt(3);
      while (walls.length < wallCount) {
        walls.add(rng.nextInt(rows * cols));
      }
      final open = [for (var i = 0; i < rows * cols; i++) if (!walls.contains(i)) i];
      if (open.length < 2) continue;
      lotus = open[rng.nextInt(open.length)];
      stone = open[rng.nextInt(open.length)];
      if (stone == lotus) continue;
      final (d, _) = solve(stone);
      if (d >= wantOptimal && d != -1) { optimal = d; return; }
    }
    // fallback: accept best-effort board (log it)
    optimal = solve(stone).$1.clamp(1, 99);
  }
}
```
**New concepts:** `Queue` from `dart:collection` (BFS frontier), records for direction pairs, attempt-loop generation ("generate → test with solver → keep or retry" — the pattern behind half of all puzzle generators).

### 5.5.2 Tier 1 screen highlights
**Swipe detection** — wrap the whole board:
```dart
GestureDetector(
  onPanEnd: (details) {
    final v = details.velocity.pixelsPerSecond;
    if (v.distance < 150) return;                       // ignore micro-drags
    final horizontal = v.dx.abs() > v.dy.abs();
    final d = horizontal ? (0, v.dx > 0 ? 1 : -1) : (v.dy > 0 ? 1 : -1, 0);
    _onSwipe(d.$1, d.$2);
  },
  child: boardGrid,
)
```
**The stone glides, not teleports** — the one-widget trick: draw the grid WITHOUT the stone, and place the stone in a `Stack` with `AnimatedPositioned`:
```dart
// inside LayoutBuilder giving you cellSize:
Stack(children: [
  gridOfCells,                                          // walls sage-tinted, lotus 🪷 cell
  AnimatedPositioned(
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOutQuart,                          // fast → sudden stop = ice feel
    left: (game.stone % game.cols) * cellSize + 4,
    top:  (game.stone ~/ game.cols) * cellSize + 4,
    child: Container(
      width: cellSize - 8, height: cellSize - 8,
      decoration: BoxDecoration(
        color: AppTheme.softSage,
        shape: BoxShape.circle,
        boxShadow: AppTheme.cardShadow)),
  ),
]),
```
`AnimatedPositioned` = `AnimatedContainer`'s sibling for `Positioned` — change left/top, it glides. When `swipe()` returns true: `Haptics.medium()` after the 250ms (that's the wall-thud), via `Future.delayed`.
**Hint:** `final (_, dir) = game.solve(game.stone); if (dir != null) show a ghost arrow` — a `Positioned` arrow Icon at the stone, fading via `AnimatedOpacity`, pointing `dir`.
**Modifiers:** `quota` → `optimalMoves = game.optimal`, budget +2. `fog` → reuse `FogOverlay` widget. `ratchet` n/a (no wrong moves) — instead: strikes on swipes that don't move the stone. `inverse` → negate the swipe direction in `_onSwipe`.
**Win juice:** lotus cell `AnimatedScale` 1→1.25→1 + `ConfettiOverlay`.
### Tier 2
Grid → painter; stone stays an `AnimatedPositioned` (it's ONE widget — already cheap). Only upgrade if you add movable grey stones (then all stones live in the painter with a slide `AnimationController`).
### Tests
`solve` returns known distances on a handcrafted 3×3. Generation always solvable at levels 1/30/80. Swipe into wall from adjacent cell = no move.

---

## B1 — UNTANGLE (the tactile showpiece — teaches free dragging)

> ## ⚠️ BUILT IN 2.2 — the generator below has **four measured defects**. Read this first.
>
> The code in §5.1.1 was transcribed verbatim and run over **4,000 boards** before anything
> was built on it. Shipped implementation is
> `lib/screens/games/untangle/untangle_logic.dart`; use that, not this.
>
> | Claim | Measured |
> |---|---|
> | planar by construction ⇒ always winnable | ✅ **0 failures in 4,000.** Kept verbatim. |
> | boards are a puzzle | ❌ **54% of level-1 boards were already solved when dealt** (48% at level 5). `side = 2` is 4 nodes and ~4 edges. Shipped version starts at `side = 3` and **gates on a minimum crossing count**. |
> | nodes are draggable | ❌ **99% of boards at level 24+ had two nodes overlapping.** `rng.nextDouble() * 2 * pi` per node clumps — birthday problem. Two nodes drawn on each other cannot be told apart or dragged separately. Shipped version spaces slots **evenly and shuffles the assignment**: the tangle stays random, separation is guaranteed. |
> | every node matters | ❌ **6–10% of boards had a node with no edges at all** — draggable but unable to participate in any crossing. Shipped version has a repair pass. |
> | difficulty climbs | ❌ **flat from level 24** (`side` capped at 5). Shipped version ramps **edge density** to level 75. |
>
> **Do not use the minimum-crossing count as a difficulty knob.** It was written up as one
> and it is not: level 16 asks for 7 crossings and a circle scramble delivers ~322, so the
> gate almost never binds. It is a floor that stops a pre-solved board shipping. Edge
> density is the actual lever.
>
> The `else` on the diagonal roll is **correct and load-bearing** — two diagonals in one cell
> would cross in the *solved* layout and make the board unwinnable. Keep it.

`id: untangle` · route `/untangle` · emoji 🕸️ · accent **slateBlue** · pillar: trace/drag

**Rules:** Nodes connected by lines, scrambled. Drag nodes until no two lines cross. Crossing lines = terracotta; clean = softSage. Live crossing counter.

### Files
```
lib/screens/games/untangle/untangle_logic.dart
lib/screens/games/untangle/untangle_screen.dart      (Tier 1 draws lines with a MINIMAL painter — see note)
```
> **Honest note:** lines between arbitrary points can't be drawn with plain Containers — this game needs a ~20-line `CustomPainter` even at Tier 1. It's the gentlest possible painter introduction: just `canvas.drawLine` in a loop. Nodes stay ordinary widgets you drag. This is deliberately your painter on-ramp.

### 5.1.1 `untangle_logic.dart` (complete)
```dart
import 'dart:math';

class Edge { final int a, b; const Edge(this.a, this.b); }

class UntangleGame {
  late List<Point<double>> nodes;     // positions in 0..1 space (scale by boardSize in UI)
  late List<Edge> edges;
  late List<Point<double>> solved;    // the planar layout (for hints)

  /// Planar-by-construction generation:
  /// nodes on a jittered grid, edges only between grid neighbors (never cross),
  /// then SCRAMBLE the display positions.
  void generate(Random rng, int level) {
    final side = (2 + (level ~/ 8)).clamp(2, 5);           // grid side → 4..25 nodes
    solved = [];
    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        solved.add(Point(
          (c + 0.5) / side + (rng.nextDouble() - 0.5) * 0.4 / side,
          (r + 0.5) / side + (rng.nextDouble() - 0.5) * 0.4 / side));
      }
    }
    int id(int r, int c) => r * side + c;
    edges = [];
    for (var r = 0; r < side; r++) {
      for (var c = 0; c < side; c++) {
        if (c + 1 < side && rng.nextDouble() < 0.85) edges.add(Edge(id(r,c), id(r,c+1)));
        if (r + 1 < side && rng.nextDouble() < 0.85) edges.add(Edge(id(r,c), id(r+1,c)));
        if (c + 1 < side && r + 1 < side && rng.nextDouble() < 0.35) {
          edges.add(Edge(id(r,c), id(r+1,c+1)));           // one diagonal per cell max:
        } else if (c + 1 < side && r + 1 < side && rng.nextDouble() < 0.35) {
          edges.add(Edge(id(r,c+1), id(r+1,c)));           // (never both — they'd cross)
        }
      }
    }
    // scramble display positions on a circle (max tangle):
    nodes = List.generate(solved.length, (i) {
      final a = rng.nextDouble() * 2 * pi;
      return Point(0.5 + 0.42 * cos(a), 0.5 + 0.42 * sin(a));
    });
  }

  /// Segment intersection (proper crossing, shared endpoints don't count).
  static bool _cross(Point<double> p1, Point<double> p2, Point<double> p3, Point<double> p4) {
    double d(Point<double> a, Point<double> b, Point<double> c) =>
        (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
    final d1 = d(p3, p4, p1), d2 = d(p3, p4, p2), d3 = d(p1, p2, p3), d4 = d(p1, p2, p4);
    return ((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0));
  }

  Set<int> crossingEdges() {
    final bad = <int>{};
    for (var i = 0; i < edges.length; i++) {
      for (var j = i + 1; j < edges.length; j++) {
        final e = edges[i], f = edges[j];
        if (e.a == f.a || e.a == f.b || e.b == f.a || e.b == f.b) continue;
        if (_cross(nodes[e.a], nodes[e.b], nodes[f.a], nodes[f.b])) { bad.add(i); bad.add(j); }
      }
    }
    return bad;
  }

  bool get isWon => crossingEdges().isEmpty;
}
```
### 5.1.2 Tier 1 screen highlights
Board = `AspectRatio(1)` → `LayoutBuilder` → `Stack`:
```dart
Stack(children: [
  // LAYER 1 — the lines (your first painter — 20 lines):
  CustomPaint(
    size: Size(s, s),
    painter: _LinesPainter(
      nodes: game.nodes, edges: game.edges, bad: _bad, boardSize: s)),
  // LAYER 2 — draggable nodes:
  for (var i = 0; i < game.nodes.length; i++)
    Positioned(
      left: game.nodes[i].x * s - 18, top: game.nodes[i].y * s - 18,
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            game.nodes[i] = Point(
              (game.nodes[i].x + d.delta.dx / s).clamp(0.03, 0.97),
              (game.nodes[i].y + d.delta.dy / s).clamp(0.03, 0.97));
          });                                    // Tier 1: setState is FINE here to learn
        },
        onPanEnd: (_) {
          final before = _bad.length;
          setState(() => _bad = game.crossingEdges());
          if (_bad.length < before) Haptics.light();      // resolved ≥1 crossing
          if (game.isWon) _onWin();
        },
        child: Container(width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppTheme.slateBlue, shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: AppTheme.cardShadow)),
      ),
    ),
]),
```
```dart
class _LinesPainter extends CustomPainter {
  final List<Point<double>> nodes; final List<Edge> edges; final Set<int> bad; final double boardSize;
  _LinesPainter({required this.nodes, required this.edges, required this.bad, required this.boardSize});
  @override
  void paint(Canvas canvas, Size size) {
    final ok  = Paint()..color = AppTheme.softSage..strokeWidth = 3..strokeCap = StrokeCap.round;
    final err = Paint()..color = AppTheme.terracotta..strokeWidth = 3..strokeCap = StrokeCap.round;
    for (var i = 0; i < edges.length; i++) {
      final e = edges[i];
      canvas.drawLine(
        Offset(nodes[e.a].x * boardSize, nodes[e.a].y * boardSize),
        Offset(nodes[e.b].x * boardSize, nodes[e.b].y * boardSize),
        bad.contains(i) ? err : ok);
    }
  }
  @override
  bool shouldRepaint(_LinesPainter old) => true;   // Tier 1 honesty; fixed in Tier 2
}
```
Recompute `_bad = game.crossingEdges()` only on `onPanEnd` (Tier 1) — during the drag, lines follow but colors update on release. Counter pill: `'${_bad.length ~/ 2} crossings'` roughly, or just `_bad.length` labelled "tangled lines".
**Hint:** animate node `i` toward `game.solved[i]` — pick the node whose move resolves the most crossings (try each: temporarily set, count, restore) or simply the first node participating in `_bad`.
### Tier 2 upgrade
1. Live crossing colors during drag: recompute only edges touching the dragged node in `onPanUpdate` (cheap), full recompute on end. 2. Dragged node position → `ValueNotifier<Offset>` passed as `repaint:`; nodes drawn IN the painter (circles), dropping the 25 Positioned widgets. 3. `shouldRepaint` compares a version counter you bump on commit.
### Tests
`_cross` truth table (crossing, parallel, shared-endpoint, T-touch). Generated layout has 0 crossings before scrambling (`nodes = solved` → `isWon`). Level 1 & 40 sizes correct.

---

## B8 — SPLIT (perception — pure geometry, almost no widgets)
`id: split` · route `/split` · emoji ✂️ · accent **slateBlue** · pillar: perception

**Rules:** An organic blob appears. Drag a straight cut across it. Release → the two halves drift apart showing their area %; ≥48/52 split = pass, ≥49/51 = perfect. 5 shapes per level.

### `split_logic.dart` essentials (complete math, copy verbatim)
```dart
import 'dart:math';

class SplitGame {
  late List<Point<double>> blob;         // polygon in 0..1 space

  void generate(Random rng, int level, int shapeIndex) {
    final n = 24;
    final wobble = (0.08 + level * 0.004).clamp(0.08, 0.30);
    final freqs = [2 + rng.nextInt(2), 3 + rng.nextInt(3)];
    final phases = [rng.nextDouble() * 2 * pi, rng.nextDouble() * 2 * pi];
    final amps = [wobble * rng.nextDouble(), wobble * rng.nextDouble()];
    blob = List.generate(n, (i) {
      final a = i / n * 2 * pi;
      var r = 0.36;
      for (var k = 0; k < 2; k++) { r += amps[k] * sin(freqs[k] * a + phases[k]); }
      return Point(0.5 + r * cos(a), 0.5 + r * sin(a));
    });
  }

  static double area(List<Point<double>> poly) {           // shoelace formula
    var s = 0.0;
    for (var i = 0; i < poly.length; i++) {
      final j = (i + 1) % poly.length;
      s += poly[i].x * poly[j].y - poly[j].x * poly[i].y;
    }
    return s.abs() / 2;
  }

  /// Split polygon by the infinite line through p1→p2.
  /// Returns the two halves (either may be empty if the line misses).
  static (List<Point<double>>, List<Point<double>>) cut(
      List<Point<double>> poly, Point<double> p1, Point<double> p2) {
    double side(Point<double> p) =>
        (p2.x - p1.x) * (p.y - p1.y) - (p2.y - p1.y) * (p.x - p1.x);
    final left = <Point<double>>[], right = <Point<double>>[];
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i], b = poly[(i + 1) % poly.length];
      final sa = side(a), sb = side(b);
      if (sa >= 0) left.add(a);
      if (sa <= 0) right.add(a);
      if ((sa > 0) != (sb > 0) && sa != sb) {
        final t = sa / (sa - sb);                           // intersection point
        final ip = Point(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
        left.add(ip); right.add(ip);
      }
    }
    return (left, right);
  }

  /// 0.5 = perfect. Call with the player's released cut line.
  double splitRatio(Point<double> p1, Point<double> p2) {
    final (l, r) = cut(blob, p1, p2);
    final total = area(blob);
    if (l.length < 3 || r.length < 3 || total == 0) return 0;   // missed the blob
    return area(l) / total;
  }
}
```
### Tier 1 screen highlights
- Blob drawn by a tiny painter: build a `Path` with `moveTo`/`lineTo` around `blob` points × boardSize, `close()`, fill slateBlue at 0.25 alpha + 2.5px stroke. (Optional smoothness: `quadraticBezierTo` midpoints — skip at first.)
- The cut line: `onPanStart` stores `_cutA`, `onPanUpdate` sets `_cutB` (both `ValueNotifier<Offset?>` OR plain fields + setState at Tier 1), painter draws a dashed line between them (dashes = loop drawing short segments).
- `onPanEnd`: `final ratio = game.splitRatio(a01, b01)` (divide by boardSize first). Score: `perfect = (ratio - 0.5).abs() <= 0.01`, `pass <= 0.02`.
- Result juice: draw the two cut halves as separate Paths, `TweenAnimationBuilder` translating them ±12px apart along the cut normal while two `Text('${(ratio*100).round()}%')` labels count up. Pass → next shape; 5 shapes → level clear, `momentum.correct()` per pass.
- **Modifiers:** `vertigo` (Tier 1 tap-rotation trick DOESN'T apply — the blob painter needs the Tier 2 unrotate; defer), `heartbeat`, `time_warp` (shrink per-shape timer), `momentum` (core), `glitch` (blob outline jitters ±1px per 200ms — a Timer nudging a jitter seed).
### Tests
`area` of unit square = 1. `cut` of a square through center = two 0.5 halves. Ratio symmetric: line reversed → `1 - ratio`.

---

## B9 — SHADOW MATCH (perception/arcade — no gestures, all logic)
`id: shadowmatch` · route `/shadowmatch` · emoji 🔍 · accent **deepLavender**

**Rules:** Top: a polyomino. Bottom: 4 silhouettes at random rotations — exactly one is the same shape rotated; distractors are its mirror or one-cell mutations. Tap the match. 45s run, streak scoring, 3 lives.

### Logic essentials
```dart
class ShadowMatchGame {
  /// Polyomino as a set of (r,c) cells, normalized to top-left = (0,0).
  static Set<(int,int)> _normalize(Set<(int,int)> s) {
    final minR = s.map((p) => p.$1).reduce(min), minC = s.map((p) => p.$2).reduce(min);
    return {for (final p in s) (p.$1 - minR, p.$2 - minC)};
  }
  static Set<(int,int)> rotate(Set<(int,int)> s) =>       // 90° CW: (r,c) → (c, maxR - r)
      _normalize({for (final p in s) (p.$2, -p.$1)});
  static Set<(int,int)> mirror(Set<(int,int)> s) =>
      _normalize({for (final p in s) (p.$1, -p.$2)});

  /// Canonical form = the lexicographically smallest of the 8 rotations/mirrors.
  /// Two shapes are "the same" iff canonical forms match — this is how we VERIFY
  /// distractors are truly different from the target.
  static String canonical(Set<(int,int)> s) {
    var forms = <String>[];
    var cur = s;
    for (var m = 0; m < 2; m++) {
      for (var r = 0; r < 4; r++) {
        final sorted = cur.toList()..sort((a,b) => a.$1 != b.$1 ? a.$1-b.$1 : a.$2-b.$2);
        forms.add(sorted.map((p) => '${p.$1},${p.$2}').join(';'));
        cur = rotate(cur);
      }
      cur = mirror(s);
    }
    return forms.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
  }

  Set<(int,int)> growPolyomino(Random rng, int cells) {
    final shape = {(0, 0)};
    while (shape.length < cells) {
      final base = shape.elementAt(rng.nextInt(shape.length));
      final d = const [(-1,0),(1,0),(0,-1),(0,1)][rng.nextInt(4)];
      shape.add((base.$1 + d.$1, base.$2 + d.$2));
    }
    return _normalize(shape);
  }

  Set<(int,int)> mutate(Random rng, Set<(int,int)> s) {   // move one edge cell
    for (var tries = 0; tries < 50; tries++) {
      final removed = Set.of(s)..remove(s.elementAt(rng.nextInt(s.length)));
      if (!_connected(removed)) continue;
      // add a random neighbor cell not in shape:
      final cand = <(int,int)>{};
      for (final p in removed) {
        for (final d in const [(-1,0),(1,0),(0,-1),(0,1)]) {
          final n = (p.$1 + d.$1, p.$2 + d.$2);
          if (!removed.contains(n)) cand.add(n);
        }
      }
      final grown = _normalize(Set.of(removed)..add(cand.elementAt(rng.nextInt(cand.length))));
      if (canonical(grown) != canonical(s)) return grown;   // must be genuinely different
    }
    return mirror(s);                                        // fallback distractor
  }
  // _connected: BFS flood from any cell — copy the pattern from ZenSlide's solve.
}
```
Round build: target = grow(5 + level bonus cells); options = [rotate^k(target)] + mirror(target) + 2 mutations, each displayed pre-rotated by a seeded rotation count, shuffled; verify via `canonical` that exactly one option matches the target. If the shape is symmetric (mirror == itself), regenerate — otherwise two options would both be "correct".
### Tier 1 screen
Each shape rendered as a mini grid of Containers (cells at ~18px, deepLavender fill, transparent elsewhere) inside a Card. Option tap → correct: pop `AnimatedScale`, `momentum.correct()`, next round; wrong: card shakes (`flutter_animate`), lose a heart. 45s `Timer.periodic` countdown bar (a `LinearProgressIndicator` fed remaining/45). Score = rounds cleared; save best in prefs.
### Tests
`canonical` equal across all 8 transforms of one shape; mutation always differs; symmetric-shape regeneration triggers.

---

## B3 — ORBIT (drag rotation — angle math introduction)
`id: orbit` · route `/orbit` · emoji 🪐 · accent **deepLavender** · pillar: trace/drag

**Rules:** 2–4 concentric rings of colored beads. Drag a ring to rotate it; it snaps to bead positions. Win when every radial spoke is a single color.

### `orbit_logic.dart` essentials
```dart
class OrbitGame {
  late int ringCount, beadsPerRing, colorCount;
  late List<List<int>> rings;      // rings[ring][slot] = color id
  late List<int> offsets;          // current rotation of each ring, in slots
  int rotations = 0;
  int optimal = 0;                 // total scramble slots (for quota)

  bool get isWon {
    for (var s = 0; s < beadsPerRing; s++) {
      final c = rings[0][(s + offsets[0]) % beadsPerRing];
      for (var r = 1; r < ringCount; r++) {
        if (rings[r][(s + offsets[r]) % beadsPerRing] != c) return false;
      }
    }
    return true;
  }

  void rotateRing(int r, int slots) {
    offsets[r] = ((offsets[r] + slots) % beadsPerRing + beadsPerRing) % beadsPerRing;
    if (slots != 0) rotations++;
  }

  void generate(Random rng, int level) {
    ringCount   = (2 + level ~/ 20).clamp(2, 4);
    beadsPerRing = (6 + (level ~/ 10) * 2).clamp(6, 12);
    colorCount  = (3 + level ~/ 25).clamp(3, 5);
    rotations = 0;
    // Solved state: spoke s has color pattern[s]
    final pattern = List.generate(beadsPerRing, (s) => s % colorCount)..shuffle(rng);
    rings = List.generate(ringCount, (_) => List.of(pattern));
    offsets = List.filled(ringCount, 0);
    // Scramble with seeded offsets (ring 0 stays fixed as the reference):
    optimal = 0;
    for (var r = 1; r < ringCount; r++) {
      final k = 1 + rng.nextInt(beadsPerRing - 1);
      offsets[r] = k;
      optimal += min(k, beadsPerRing - k);      // shortest way back
    }
    if (isWon) generate(Random(rng.nextInt(1 << 31)), level);
  }
}
```
### Tier 1 screen — the angle-drag pattern (the whole reason this game exists)
Rendering Tier 1: each bead is a small `Positioned` circle — position ring `r`, slot `s`:
```dart
// inside LayoutBuilder, boardSize s, center = s/2:
final radius = s * (0.18 + 0.11 * r);
final angle = 2 * math.pi * (slot + game.offsets[r]) / game.beadsPerRing
              + _dragExtra(r);                      // live drag offset, radians
left: s/2 + radius * math.cos(angle) - beadR,
top:  s/2 + radius * math.sin(angle) - beadR,
```
Wrap ALL beads in `AnimatedContainer`? No — position changes each frame during drag; Tier 1 just uses `setState` in `onPanUpdate` (yes, it'll be the jankiest Tier 1 in this doc on old phones — that's the motivation to upgrade).
**Which ring did the finger grab + how far has it rotated:**
```dart
double _startAngle = 0; int _activeRing = -1; double _dragRadians = 0;

void _panStart(DragStartDetails d, double s) {
  final v = d.localPosition - Offset(s/2, s/2);
  final dist = v.distance / s;                       // 0..~0.5
  _activeRing = -1;
  for (var r = 0; r < game.ringCount; r++) {
    if ((dist - (0.18 + 0.11 * r)).abs() < 0.055) _activeRing = r;   // ±band
  }
  _startAngle = math.atan2(v.dy, v.dx);
  _dragRadians = 0;
}

void _panUpdate(DragUpdateDetails d, double s) {
  if (_activeRing < 0) return;
  final v = d.localPosition - Offset(s/2, s/2);
  var delta = math.atan2(v.dy, v.dx) - _startAngle;
  // unwrap the ±pi jump:
  if (delta > math.pi) delta -= 2 * math.pi;
  if (delta < -math.pi) delta += 2 * math.pi;
  setState(() => _dragRadians += delta);
  _startAngle = math.atan2(v.dy, v.dx);
  // haptic detent each time we cross a bead pitch:
  final pitch = 2 * math.pi / game.beadsPerRing;
  if (_dragRadians.abs() >= pitch) { Haptics.select(); }
}

void _panEnd(DragEndDetails d) {
  if (_activeRing < 0) return;
  final pitch = 2 * math.pi / game.beadsPerRing;
  final slots = (_dragRadians / pitch).round();      // SNAP
  game.rotateRing(_activeRing, slots);
  setState(() { _dragRadians = 0; _activeRing = -1; });
  if (game.isWon) _onWin();
}

double _dragExtra(int r) => r == _activeRing ? _dragRadians : 0;
```
The snap on release + `Haptics.select()` per detent is the entire feel of this game.
**Hint:** animate ring `r`'s offset to 0 shortest-way: run a `TweenAnimationBuilder` over the extra radians, then `rotateRing(r, -offsets[r])`.
**Modifiers:** `quota` (`optimalMoves = game.optimal` counted in slots — decrement by `slots.abs()` per release), `vertigo` (whole Stack in the A5 Tier 1 wrapper — but see Tier 2 note), `monochrome` (bead colors → 5 distinct icons), `heartbeat`, `momentum`.
### Tier 2
Beads → one painter (drawCircle loop), `_dragRadians` → `ValueNotifier` as `repaint:` — this converts the worst Tier 1 janker into the smoothest game in the app in ~1 hour. With vertigo active, add the A5 `_unrotate` before `_panStart/Update` math.
### Tests
`isWon` after generate+undo offsets. Snap rounds correctly at ±half pitch. `optimal` = sum of shortest returns.

---

## B6 — LIGHT BEAM (tap-logic — teaches ray marching)
`id: lightbeam` · route `/lightbeam` · emoji 🔦 · accent **warmAmber** · pillar: tap-logic

**Rules:** A source shoots a beam. Tap an empty cell to place a mirror (/), tap again → (\), tap again → remove. Beam re-routes live. Light all crystals. Mirror budget shown.

### `lightbeam_logic.dart` essentials
```dart
enum Cell { empty, slash, backslash, block }        // '/' and '\' mirrors, wall

class LightBeamGame {
  late int n;                                        // n×n board
  late List<List<Cell>> grid;
  late (int,int) source; late (int,int) sourceDir;   // e.g. (0,1) = firing right
  late Set<(int,int)> crystals;
  int mirrorBudget = 0;
  int placed = 0;

  /// March the beam; returns every cell the beam passes through (for drawing)
  /// and which crystals it hits.
  (List<(int,int)>, Set<(int,int)>) trace() {
    var (r, c) = source; var (dr, dc) = sourceDir;
    final path = <(int,int)>[]; final lit = <(int,int)>{};
    for (var steps = 0; steps < n * n * 4; steps++) {      // loop guard
      r += dr; c += dc;
      if (r < 0 || r >= n || c < 0 || c >= n) break;
      path.add((r, c));
      if (crystals.contains((r, c))) { lit.add((r, c)); continue; }  // beam passes through
      switch (grid[r][c]) {
        case Cell.slash:      (dr, dc) = (-dc, -dr); break;   // '/' reflection
        case Cell.backslash:  (dr, dc) = (dc, dr);   break;   // '\' reflection
        case Cell.block:      return (path, lit);
        case Cell.empty:      break;
      }
    }
    return (path, lit);
  }

  bool get isWon => trace().$2.length == crystals.length;

  void tapCell(int r, int c) {
    if (crystals.contains((r,c)) || (r,c) == source || grid[r][c] == Cell.block) return;
    switch (grid[r][c]) {
      case Cell.empty:
        if (placed >= mirrorBudget) return;
        grid[r][c] = Cell.slash; placed++;
      case Cell.slash:     grid[r][c] = Cell.backslash;
      case Cell.backslash: grid[r][c] = Cell.empty; placed--;
      case Cell.block:     break;
    }
  }

  /// Generation by FORWARD construction: fire the beam, place solution mirrors
  /// at seeded points along it, drop crystals on the final path, then clear mirrors.
  late List<((int,int), Cell)> solutionMirrors;      // for hints
  void generate(Random rng, int level) {
    n = (5 + level ~/ 20).clamp(5, 8);
    final wantMirrors = (1 + level ~/ 12).clamp(1, 5);
    final wantCrystals = (1 + level ~/ 15).clamp(1, 4);
    for (var attempt = 0; attempt < 100; attempt++) {
      grid = List.generate(n, (_) => List.filled(n, Cell.empty));
      // a few walls for flavor:
      for (var w = 0; w < n ~/ 2; w++) {
        grid[rng.nextInt(n)][rng.nextInt(n)] = Cell.block;
      }
      final edge = rng.nextInt(4);
      source = switch (edge) {
        0 => (-1, rng.nextInt(n)), 1 => (n, rng.nextInt(n)),
        2 => (rng.nextInt(n), -1), _ => (rng.nextInt(n), n) };
      sourceDir = switch (edge) { 0 => (1,0), 1 => (-1,0), 2 => (0,1), _ => (0,-1) };
      // walk placing mirrors:
      solutionMirrors = [];
      var (r, c) = source; var (dr, dc) = sourceDir;
      final visited = <(int,int)>{};
      var ok = true;
      for (var m = 0; m <= wantMirrors; m++) {
        final run = 2 + rng.nextInt(n - 2);
        for (var s = 0; s < run; s++) {
          r += dr; c += dc;
          if (r < 0 || r >= n || c < 0 || c >= n ||
              grid[r][c] == Cell.block || visited.contains((r,c))) { ok = false; break; }
          visited.add((r, c));
        }
        if (!ok) break;
        if (m < wantMirrors) {
          final mirror = rng.nextBool() ? Cell.slash : Cell.backslash;
          grid[r][c] = mirror; solutionMirrors.add(((r, c), mirror));
          (dr, dc) = mirror == Cell.slash ? (-dc, -dr) : (dc, dr);
        }
      }
      if (!ok || solutionMirrors.length < wantMirrors) continue;
      // crystals on the last segment cells:
      final segment = visited.toList();
      crystals = {};
      while (crystals.length < wantCrystals && segment.isNotEmpty) {
        crystals.add(segment.removeAt(rng.nextInt(segment.length)));
      }
      // clear solution mirrors — the player rebuilds them:
      for (final (pos, _) in solutionMirrors) { grid[pos.$1][pos.$2] = Cell.empty; }
      mirrorBudget = wantMirrors + (level < 20 ? 1 : 0);
      placed = 0;
      if (!isWon) return;                            // must not be pre-solved
    }
    RotationEngineFallbackNote:; // if we get here, log + simplest fallback board
  }
}
```
(Note: crystals must sit where the SOLUTION beam passes — the code above adds them from `visited`, which is exactly that path. `isWon` check at the end rejects boards solvable with zero mirrors.)
### Tier 1 screen
`GridView.builder` cells: wall = filled outline cell; crystal = 💎 emoji Text, `AnimatedContainer` background flips to warmAmber-0.3 when lit; mirrors = `Text('/')` / `Text('\\')` in w700. **The beam at Tier 1: no painter needed** — color every cell in `trace().$1` with warmAmber at 0.18 alpha via each cell's `AnimatedContainer` (the beam appears as a glowing corridor of cells — genuinely looks good). Tap → `game.tapCell` → `setState` → the corridor re-flows with 200ms fades. Budget pill = `'${game.mirrorBudget - game.placed} mirrors'`.
### Tier 2
Painter draws the beam as a real polyline: rebuild the path as corner points (source + every mirror bounce + exit), `canvas.drawPath` twice — 6px stroke warmAmber 0.25 alpha under a 2.5px full-alpha core = glow without shaders. Crystals/mirrors stay widgets.
**Hint:** reveal one `solutionMirrors` entry not yet placed correctly (place it for free, doesn't consume budget).
### Tests
`trace` reflection table: beam going right hits '/' → goes up; hits '\' → goes down (derive: '/' maps (dr,dc)→(-dc,-dr)). Generation: replaying `solutionMirrors` lights all crystals. Budget sufficiency.

---

## B2 — ONE STROKE (trace — reuses Grid Path's muscle)
`id: onestroke` · route `/onestroke` · emoji ✍️ · accent **roseGold** · pillar: trace/drag

**Rules:** Trace every line of the figure in ONE continuous stroke, no edge twice. (Vertices may repeat.)

### Logic essentials
Graph of nodes (points on screen, 0..1 space like Untangle) + edge list. **Eulerian guarantee:** a connected graph has a one-stroke path iff it has exactly 0 or 2 odd-degree vertices.
```dart
void generate(Random rng, int level) {
  // 1. nodes: jittered ring + center points (pretty figures):
  //    outer ring of R nodes + 1..3 inner nodes, R = 4 + level ~/ 10 (cap 9)
  // 2. edges: ring edges + seeded chords/spokes, no duplicates, keep planar-ish
  //    by only allowing chords between ring nodes ≤3 apart or to inner nodes.
  // 3. FIX PARITY: count odd-degree vertices. While count > 2:
  //      pick two odd vertices, add (or if edge exists, remove) the edge between
  //      them, recount. This ALWAYS terminates (each fix changes parity of 2).
  // 4. Verify connectivity (BFS); if disconnected, add an edge between components.
  // startNode = an odd-degree vertex if any exist, else any vertex.
}
```
Traversal state: `Set<int> usedEdges`, `int currentNode`, `List<int> visitedPath` (for drawing). A drag entering the ±22px circle of a node adjacent to `currentNode` via an unused edge consumes that edge. `isWon => usedEdges.length == edges.length`.
**Dead-end forgiveness:** it's possible to trace yourself into a corner even on a valid graph. When the player is stuck (current node has no unused edges but edges remain): flash the stroke terracotta and offer "Rewind 1" (un-consume the last edge) — or under `ratchet`, that's the loss.
### Tier 1 screen
Copy Untangle's Stack: `_LinesPainter` variant where used edges draw 5px roseGold, unused 3px outline-color; nodes are non-draggable dots (currentNode pulses via `AnimatedScale` loop: wrap in `TweenAnimationBuilder` retriggered by a 700ms Timer, or simply a bigger static dot at Tier 1). Drag handling on the whole board:
```dart
onPanUpdate: (d) {
  for (var i = 0; i < nodes.length; i++) {
    if ((d.localPosition - nodePx(i)).distance < 22 && i != game.currentNode) {
      if (game.tryTraverse(i)) { Haptics.light(); setState(() {}); }
    }
  }
}
onPanEnd: (_) { if (game.isWon) _onWin(); }
```
**Hint:** run Hierholzer's algorithm from `currentNode` on the remaining subgraph (20 lines — standard Euler path construction; or Tier-1 shortcut: brute-force DFS for edges ≤ 24, instant) → flash the next edge.
### Tier 2
Live stroke follows the finger between nodes: `ValueNotifier<Offset>` fingerPos as `repaint:`, painter draws a segment from currentNode to finger. Everything else stays.
### Tests
Parity fixer: random graphs → always 0 or 2 odd vertices after fix. Traversal rejects reused edges. Handmade square-with-X (the classic "envelope") is traceable from its odd corners only.

---

## B4 — MIRROR TRACE (trace — Grid Path's sibling, build last of the trace trio)
`id: mirrortrace` · route `/mirrortrace` · emoji 🪞 · accent **dustyMauve**

**Rules:** Left half of a dot-grid shows a path. Draw its mirror image on the right half. Your stroke mirrors live as a faint preview; wrong segments flash terracotta and rewind.

### Logic
```dart
void generate(Random rng, int level) {
  final h = (5 + level ~/ 15).clamp(5, 8);      // grid h rows × (2*halfW) cols
  final halfW = (3 + level ~/ 20).clamp(3, 5);
  final len = (6 + level).clamp(6, 26);
  // Self-avoiding walk on the LEFT half grid (cols 0..halfW-1):
  // start at seeded cell, repeatedly pick a random unvisited orthogonal neighbor
  // (diagonals allowed from level 20); dead end before len → retry (cap 200 tries,
  //  then accept shorter path). Store as List<(int,int)> targetPath.
}
// The mirror of left cell (r, c) is right cell (r, 2*halfW - 1 - c).
// Player must trace mirrorOf(targetPath) IN ORDER.
// tryStep(cell): legal iff cell == mirrorOf(targetPath[progress]) → progress++.
```
### Tier 1 screen
Grid of dot Containers (small circles). Left half: target path pre-drawn (connect consecutive path cells — Tier 1 trick: instead of drawing lines, fill the path CELLS dustyMauve-0.5; looks like a pixel path, totally readable). Right half: player drags; `onPanUpdate` → cell under finger (Primer 1.3) → `tryStep`. Correct: fill cell dustyMauve + `Haptics.light`. Wrong: flash the cell terracotta 250ms (`AnimatedContainer` + revert Timer) and do NOT advance. Progress `LinearProgressIndicator` on top. Hard mode ≥ level 35: after 3s, left half fades to 0.12 (`AnimatedOpacity`) — built-in `ghost`.
### Tier 2
Both halves → one painter drawing real polylines (copy `_MasyuPainter` line style); live mirrored preview of the finger stroke on the LEFT (draw the mirror of the player's committed path faintly). This preview is the game's magic moment — worth the upgrade.
### Tests
mirrorOf is an involution. Walk generator: no repeats, length within bounds. tryStep order enforcement.

---

# PART 6 — TESTING, DEBUGGING & ROADMAP

### 6.1 Unit tests you can actually write (per game, ~30 min)
`test/<id>_logic_test.dart` — logic files have no Flutter deps, so tests are trivial:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'dart:math';
import 'package:cogniq/screens/games/sandsort/sandsort_logic.dart'; // check package name in pubspec

void main() {
  test('generation is deterministic', () {
    final a = SandSortGame()..generate(Random(42), 7);
    final b = SandSortGame()..generate(Random(42), 7);
    expect(a.tubes, b.tubes);
  });
  test('always solvable-shaped', () {
    for (var lvl = 0; lvl < 100; lvl += 7) {
      final g = SandSortGame()..generate(Random(1234 + lvl), lvl);
      expect(g.isWon, false);
      // stronger: replay reverse of scramble if you record it, or run a solver
    }
  });
}
```
Run: `flutter test`. Every game in Part 5 lists its 3 must-have tests.

### 6.2 The profile-mode jank test (Tier 2 gate)
```
flutter run --profile
```
Open the game, drag continuously 30s, watch the performance overlay (`P` in DevTools or add `showPerformanceOverlay: true` temporarily to MaterialApp). Raster bars must stay under ~8.3ms for 120Hz. If they spike: you have a `setState` in a pan handler (remember.md rule 1) or a missing `RepaintBoundary`.

### 6.3 Debugging cheatsheet for the errors you WILL hit
| Symptom | Cause | Fix |
|---|---|---|
| `setState() called after dispose()` | Timer/Future fired after leaving screen | `if (!mounted) return;` first line of every callback; cancel timers in `dispose()` |
| Board scrolls when dragging | GridView default physics | `physics: NeverScrollableScrollPhysics()` |
| Taps hit wrong cell | using `globalPosition` or forgetting padding | use `localPosition`; hit-test inside the SAME widget that sizes the board |
| `RangeError (index)` | finger left the board mid-drag | guard row/col bounds before EVERY grid access |
| Nothing repaints (painter) | `shouldRepaint` returns false / same list mutated | return true while developing; later compare a version int you increment on change |
| `vsync` error | missing mixin | add `with SingleTickerProviderStateMixin` to the State class |
| Colors look wrong in dark mode | hardcoded light colors | only `AppTheme.*` + `Theme.of(context)` colors |
| Two fingers break dragging | multi-touch | wrap board GestureDetector's child in `AbsorbPointer` during active drag, or track a pointer id — simplest: ignore `onPanStart` while one is active |

### 6.4 The complete roadmap (checkbox form)
**Phase 0 — one-time setup**
- [ ] `lib/utils/haptics.dart` + settings toggle (3.8)
- [ ] `lib/utils/modifier_params.dart` (2.5)

**Phase 1 — flag modifiers:** silence → quota → ratchet → wildcard, into Sudoku + Mine Finder first, then spread.
**Phase 2 — first game:** Sand Sort Tier 1 → play a week → Tier 2 upgrade (2.4).
**Phase 3 — timer modifiers:** momentum (+ meter widget) → decay → heartbeat → seismic.
**Phase 4 — games:** Zen Slide → Untangle → Split → Shadow Match (each: Tier 1, ship stashed, Tier 2 when it feels earned).
**Phase 5 — motion modifiers:** drift → vertigo → inverse.
**Phase 6 — showpieces:** Orbit → Light Beam → One Stroke → Mirror Trace → `twin` modifier.
**After each item:** rules text, tests, checklist 3.9, and only then daily-challenge rows.

### 6.5 Glossary (the terms this doc kept using)
- **Deterministic / seeded** — same inputs → same puzzle. All randomness from `RotationEngine.getDeterminism`.
- **Hit-testing** — converting a finger position to a game coordinate (Primer 1.3).
- **Retrograde generation** — start from the solved state and walk backward with legal reverse moves; guarantees solvability (Sand Sort, Zen Slide walls variant, Orbit).
- **Generate-and-verify** — random board + solver check, retry on failure, deterministic retries via attempt-salted seeds (Zen Slide, Light Beam).
- **Canonical form** — a normalized representation so two shapes/boards can be compared regardless of rotation/mirroring (Shadow Match).
- **Hot path** — code running many times per second (pan handlers, painters). No setState, no allocation-heavy work there.
- **Juice** — the tiny animations + haptics that make a correct move feel physical. Every game section lists its juice moments; do not skip them — they are why the 16 survived.

*End of handbook. Build Sand Sort first. Everything else is that, again, with different math.*
