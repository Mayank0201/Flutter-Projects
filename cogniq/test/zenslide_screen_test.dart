import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cogniq/screens/games/zenslide/zenslide_logic.dart';
import 'package:cogniq/screens/games/zenslide/zenslide_screen.dart';
import 'package:cogniq/utils/rotation_engine.dart';

/// Widget tests for the Zen Slide screen.
///
/// The screen is pumped directly rather than through a named route, so these
/// pass before the game is registered in `main.dart`.
///
/// The board the screen deals is not a mystery to the test: the screen seeds
/// generation with `RotationEngine.getDeterminism('zenslide', level)`, so the
/// test rebuilds the identical board and knows exactly where the stone starts,
/// where the greys are, and which cell each swipe must land on. That is what
/// makes the assertions specific rather than "something changed".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Never reach for the network in a test; fall back to the bundled font.
  GoogleFonts.config.allowRuntimeFetching = false;

  /// The pool `ZenSlideScreen` passes to `RotationEngine`. Kept in step with
  /// the screen's `_modifierPool` by the "every active modifier is named on
  /// screen" test below, which fails the moment they diverge.
  const pool = ['timer', 'mirror', 'fog'];
  const labels = {
    'timer': 'Timer',
    'mirror': 'Mirrored',
    'fog': 'Icy Fog',
  };

  /// The exact board `ZenSlideScreen` will deal for [level].
  ZenSlideBoard boardFor(int level) => ZenSlideLogic.generate(
        RotationEngine.getDeterminism('zenslide', level),
        level,
      );

  Set<String> modifiersAt(int level) => RotationEngine.getActiveModifiers(
        gameId: 'zenslide',
        levelIndex: level,
        pool: pool,
        minActive: 1,
        maxActive: 2,
      );

  Finder board() => find.byKey(const ValueKey('zenslide_board'));
  Finder stoneAt(int r, int c) =>
      find.byKey(ValueKey('zenslide_stone_at_${r}_$c'));
  Finder greyAt(int r, int c) => find.byKey(ValueKey('zenslide_grey_${r}_$c'));

  /// A finger travel long enough to clear the screen's 18px swipe threshold.
  Offset dragFor(ZenSlideDir dir) => Offset(dir.$2 * 120.0, dir.$1 * 120.0);

  /// Pumps the screen and lets the async level load settle.
  Future<void> pumpScreen(WidgetTester tester, {ThemeData? theme}) async {
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: const ZenSlideScreen(),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// Replaces the tree so the screen is disposed and its timers cancelled.
  Future<void> tearDownScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  void setViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Performs one swipe and lets the 240ms glide finish.
  Future<void> swipe(WidgetTester tester, ZenSlideDir dir) async {
    await tester.drag(board(), dragFor(dir));
    await tester.pump(const Duration(milliseconds: 300));
  }

  // ------------------------------------------------------------------ layout

  group('layout', () {
    // 320x568 is the narrow phone the whole suite checks. 1568x696 is the wide
    // SHORT window that is missing from the shared harness — a wide-screen
    // overflow shipped undetected last release because every viewport in the
    // harness is phone-shaped. It is the case that breaks a board sized from the
    // width alone, which is exactly what the handbook's screen sketch does.
    const viewports = <String, Size>{
      'small phone 320x568': Size(320, 568),
      'typical phone 412x915': Size(412, 915),
      'wide short window 1568x696': Size(1568, 696),
      'square-ish tablet 800x800': Size(800, 800),
    };

    // Level 0 is the 5x5 opener; level 66 is the documented hardest board (8x7,
    // 8 greys, a nine-swipe solve) and carries modifiers, so the strip is on
    // screen too.
    for (final level in [0, 66]) {
      for (final vp in viewports.entries) {
        testWidgets('level $level has no overflow at ${vp.key}',
            (tester) async {
          SharedPreferences.setMockInitialValues({'level_zenslide': level});
          setViewport(tester, vp.value);

          final overflows = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) {
            if (details.exceptionAsString().contains('overflowed by')) {
              overflows.add(details.exceptionAsString().split('\n').first);
            } else {
              previous?.call(details);
            }
          };

          try {
            await pumpScreen(tester);
            expect(board(), findsOneWidget);
          } finally {
            await tearDownScreen(tester);
            FlutterError.onError = previous;
          }

          expect(overflows, isEmpty,
              reason: 'Zen Slide overflows at ${vp.key}:\n'
                  '${overflows.join('\n')}');
        });
      }
    }

    testWidgets('the whole hardest board fits on screen at 320x568 and at '
        '1568x696', (tester) async {
      for (final size in [const Size(320, 568), const Size(1568, 696)]) {
        SharedPreferences.setMockInitialValues({'level_zenslide': 66});
        setViewport(tester, size);
        await pumpScreen(tester);

        final b = boardFor(66);
        expect(b.rows, 8);
        expect(b.cols, 7);

        final rect = tester.getRect(board());
        expect(rect.width, greaterThan(0));
        // Square cells: the board's aspect ratio must be rows:cols, which only
        // holds if the cell size came from whichever axis is tighter.
        expect(rect.width / b.cols, closeTo(rect.height / b.rows, 0.5),
            reason: 'cells are not square at $size — the board was sized from '
                'one axis only');

        final screen = tester.getSize(find.byType(MaterialApp));
        expect(rect.width, lessThanOrEqualTo(screen.width + 0.5),
            reason: 'the board is wider than $size');
        expect(rect.height, lessThanOrEqualTo(screen.height + 0.5),
            reason: 'the board is taller than $size');

        // The stone and the lotus are both really on screen.
        expect(stoneAt(b.start ~/ b.cols, b.start % b.cols), findsOneWidget);
        expect(find.byKey(const ValueKey('zenslide_lotus')), findsOneWidget);

        await tearDownScreen(tester);
      }
    });

    testWidgets('boots at every stage of the curve without an exception',
        (tester) async {
      // The levels the work order names, plus the modifier-tier boundaries and
      // the documented hardest level.
      const levels = [0, 5, 14, 15, 20, 25, 40, 60, 66, 90, 120];
      setViewport(tester, const Size(412, 915));

      final failures = <String>[];
      for (final level in levels) {
        SharedPreferences.setMockInitialValues({
          'level_zenslide': level,
          'hints_zenslide': 3,
        });

        final previous = FlutterError.onError;
        FlutterError.onError = (details) => failures.add(
            'level $level: ${details.exceptionAsString().split('\n').first}');
        try {
          await pumpScreen(tester);
          expect(board(), findsOneWidget, reason: 'level $level did not deal');
        } finally {
          await tearDownScreen(tester);
          FlutterError.onError = previous;
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    testWidgets('renders in light theme too', (tester) async {
      SharedPreferences.setMockInitialValues({'level_zenslide': 0});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester, theme: ThemeData.light());
      expect(board(), findsOneWidget);
      await tearDownScreen(tester);
    });
  });

  // ------------------------------------------------------------------ header

  group('header', () {
    testWidgets('the level chip shows the saved level, one-based',
        (tester) async {
      SharedPreferences.setMockInitialValues({'level_zenslide': 7});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);

      expect(find.text('Level 8'), findsOneWidget);
      // remember.md E2 section 7: nothing else on the screen may show the level.
      expect(find.textContaining('Level '), findsOneWidget);
      expect(find.text('Zen Slide'), findsOneWidget);

      await tearDownScreen(tester);
    });

    testWidgets('a fresh player starts on level 1', (tester) async {
      SharedPreferences.setMockInitialValues({});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);
      expect(find.text('Level 1'), findsOneWidget);
      await tearDownScreen(tester);
    });

    testWidgets('the chip is still the only level readout at level 120, on the '
        'narrow phone', (tester) async {
      SharedPreferences.setMockInitialValues({'level_zenslide': 119});
      setViewport(tester, const Size(320, 568));

      await pumpScreen(tester);
      expect(find.text('Level 120'), findsOneWidget);
      expect(find.textContaining('Level '), findsOneWidget);
      await tearDownScreen(tester);
    });
  });

  // ------------------------------------------------------------------- play

  group('swiping', () {
    testWidgets('a swipe slides the stone to the cell the solver predicts',
        (tester) async {
      const level = 0;
      SharedPreferences.setMockInitialValues({'level_zenslide': level});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);
      final b = boardFor(level);
      expect(stoneAt(b.start ~/ b.cols, b.start % b.cols), findsOneWidget,
          reason: 'the stone did not start where the generator put it');

      // Every direction the stone can actually move, checked against
      // ZenSlideLogic.slide — the rule, not a re-implementation of it.
      var moved = 0;
      for (final dir in ZenSlideLogic.directions) {
        final expected = ZenSlideLogic.slide(
          from: b.start,
          dr: dir.$1,
          dc: dir.$2,
          rows: b.rows,
          cols: b.cols,
          stones: b.stones,
          target: b.target,
        );
        if (expected == b.start) continue; // flush against something
        moved++;

        await pumpScreen(tester); // fresh deal, same board
        await swipe(tester, dir);
        expect(stoneAt(expected ~/ b.cols, expected % b.cols), findsOneWidget,
            reason: 'swiping $dir should land the stone on cell $expected');
        expect(stoneAt(b.start ~/ b.cols, b.start % b.cols), findsNothing,
            reason: 'swiping $dir left the stone where it started');
        await tearDownScreen(tester);
      }
      expect(moved, greaterThan(0), reason: 'the stone cannot move at all');
    });

    testWidgets('a swipe into an immediate blocker leaves the stone put',
        (tester) async {
      // Find a level whose dealt stone is flush against something, then swipe
      // that way and assert nothing moved.
      int? level;
      ZenSlideDir? blocked;
      for (var l = 0; l < 40 && level == null; l++) {
        final b = boardFor(l);
        for (final dir in ZenSlideLogic.directions) {
          final landed = ZenSlideLogic.slide(
            from: b.start,
            dr: dir.$1,
            dc: dir.$2,
            rows: b.rows,
            cols: b.cols,
            stones: b.stones,
            target: b.target,
          );
          if (landed == b.start) {
            level = l;
            blocked = dir;
            break;
          }
        }
      }
      expect(level, isNotNull,
          reason: 'no level in 0-39 deals a stone flush against anything');

      SharedPreferences.setMockInitialValues({'level_zenslide': level!});
      setViewport(tester, const Size(412, 915));
      await pumpScreen(tester);

      final b = boardFor(level);
      await swipe(tester, blocked!);
      expect(stoneAt(b.start ~/ b.cols, b.start % b.cols), findsOneWidget,
          reason: 'a blocked swipe moved the stone anyway');
      expect(find.textContaining('Slides 0'), findsOneWidget,
          reason: 'a blocked swipe was counted as a slide');

      await tearDownScreen(tester);
    });

    testWidgets('a twitch below the swipe threshold is ignored', (tester) async {
      const level = 0;
      SharedPreferences.setMockInitialValues({'level_zenslide': level});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);
      final b = boardFor(level);

      await tester.drag(board(), const Offset(6, 0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(stoneAt(b.start ~/ b.cols, b.start % b.cols), findsOneWidget,
          reason: 'a 6px twitch moved the stone');

      await tearDownScreen(tester);
    });

    testWidgets('a SLOW drag still counts — this is the handbook bug',
        (tester) async {
      // The sketch reads `details.velocity` and bails below 150 px/s, so a slow
      // deliberate drag — which ends at roughly zero velocity — is thrown away
      // and the board feels dead. Driving the gesture manually with a long pause
      // before the release reproduces exactly that.
      const level = 0;
      SharedPreferences.setMockInitialValues({'level_zenslide': level});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);
      final b = boardFor(level);

      ZenSlideDir? dir;
      var expected = b.start;
      for (final d in ZenSlideLogic.directions) {
        final landed = ZenSlideLogic.slide(
          from: b.start,
          dr: d.$1,
          dc: d.$2,
          rows: b.rows,
          cols: b.cols,
          stones: b.stones,
          target: b.target,
        );
        if (landed != b.start) {
          dir = d;
          expected = landed;
          break;
        }
      }
      expect(dir, isNotNull);

      final centre = tester.getCenter(board());
      final gesture = await tester.startGesture(centre);
      for (var step = 0; step < 12; step++) {
        await gesture.moveBy(Offset(dir!.$2 * 8.0, dir.$1 * 8.0));
        await tester.pump(const Duration(milliseconds: 60));
      }
      // A long still pause, so the release velocity really is ~0.
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));

      expect(stoneAt(expected ~/ b.cols, expected % b.cols), findsOneWidget,
          reason: 'a slow drag was ignored — the velocity-only test is back');

      await tearDownScreen(tester);
    });

    testWidgets('Restart puts the stone back where it was dealt',
        (tester) async {
      const level = 0;
      SharedPreferences.setMockInitialValues({'level_zenslide': level});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);
      final b = boardFor(level);

      ZenSlideDir? dir;
      for (final d in ZenSlideLogic.directions) {
        final landed = ZenSlideLogic.slide(
          from: b.start,
          dr: d.$1,
          dc: d.$2,
          rows: b.rows,
          cols: b.cols,
          stones: b.stones,
          target: b.target,
        );
        if (landed != b.start && landed != b.target) {
          dir = d;
          break;
        }
      }
      expect(dir, isNotNull, reason: 'every legal swipe from the start wins');

      await swipe(tester, dir!);
      expect(stoneAt(b.start ~/ b.cols, b.start % b.cols), findsNothing);

      await tester.tap(find.text('Restart'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(stoneAt(b.start ~/ b.cols, b.start % b.cols), findsOneWidget);
      expect(find.textContaining('Slides 0'), findsOneWidget);

      await tearDownScreen(tester);
    });
  });

  // --------------------------------------------------------------- modifiers

  group('modifiers', () {
    testWidgets('no modifier strip before the modifier start level',
        (tester) async {
      SharedPreferences.setMockInitialValues({'level_zenslide': 0});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);
      for (final label in labels.values) {
        expect(find.textContaining(label), findsNothing);
      }
      await tearDownScreen(tester);
    });

    testWidgets('every active modifier is named on screen', (tester) async {
      // remember.md E2 section 8: whatever the engine picks from the pool must
      // be visible to the player. All three entries are implemented in
      // zenslide_screen.dart, and this fails if the screen's pool ever drifts
      // from the one declared at the top of this file.
      setViewport(tester, const Size(412, 915));

      for (final level in [15, 20, 30, 60, 90]) {
        final active = modifiersAt(level);
        expect(active, isNotEmpty,
            reason: 'level $level should carry at least one modifier');

        SharedPreferences.setMockInitialValues({'level_zenslide': level});
        await pumpScreen(tester);
        for (final name in active) {
          // The timer chip carries its live countdown, so match on the prefix.
          expect(find.textContaining(labels[name]!), findsOneWidget,
              reason: '$name is active at level $level but never shown');
        }
        await tearDownScreen(tester);
      }
    });

    test('the three-entry pool survives difficulty_curve_test\'s flat-run guard',
        () {
      // A local copy of the assertion in test/difficulty_curve_test.dart, run
      // with the same default min/maxActive that harness uses. A two-entry pool
      // fails it: RotationEngine runs a singles tier then a pairs tier, and two
      // entries give the pairs tier exactly one combination, which it then
      // serves for 35 straight levels.
      final start = RotationEngine.modifierStartLevel('zenslide');
      expect(start, lessThanOrEqualTo(30));

      String? previous;
      for (var l = start; l < start + 40; l++) {
        final set = (RotationEngine.getActiveModifiers(
              gameId: 'zenslide',
              levelIndex: l,
              pool: pool,
            ).toList()
              ..sort())
            .join('+');
        expect(set, isNot(previous),
            reason: 'zenslide repeats a modifier set back to back at level $l');
        previous = set;
      }
    });

    testWidgets('mirror really does invert the swipe', (tester) async {
      int? level;
      for (var l = 15; l < 60 && level == null; l++) {
        if (modifiersAt(l).contains('mirror')) level = l;
      }
      expect(level, isNotNull, reason: 'mirror never fires below level 60');

      final b = boardFor(level!);
      // A direction whose OPPOSITE moves the stone, so a mirrored swipe has a
      // visible, checkable effect.
      ZenSlideDir? finger;
      var expected = b.start;
      for (final d in ZenSlideLogic.directions) {
        final landed = ZenSlideLogic.slide(
          from: b.start,
          dr: -d.$1,
          dc: -d.$2,
          rows: b.rows,
          cols: b.cols,
          stones: b.stones,
          target: b.target,
        );
        if (landed != b.start) {
          finger = d;
          expected = landed;
          break;
        }
      }
      expect(finger, isNotNull);

      SharedPreferences.setMockInitialValues({'level_zenslide': level});
      setViewport(tester, const Size(412, 915));
      await pumpScreen(tester);

      expect(find.text('Mirrored'), findsOneWidget);
      await swipe(tester, finger!);
      expect(stoneAt(expected ~/ b.cols, expected % b.cols), findsOneWidget,
          reason: 'the stone went the way the finger did — mirror is inert');

      await tearDownScreen(tester);
    });

    testWidgets('fog really does hide the far greys', (tester) async {
      // Find a fog level where at least one grey starts outside the fog radius,
      // otherwise the assertion proves nothing.
      int? level;
      ZenSlideBoard? found;
      var hidden = <int>[];
      for (var l = 15; l < 100 && level == null; l++) {
        if (!modifiersAt(l).contains('fog')) continue;
        final b = boardFor(l);
        final radius = max(2, min(b.rows, b.cols) ~/ 2);
        final away = <int>[];
        for (final s in b.stones) {
          final dr = (s ~/ b.cols) - (b.start ~/ b.cols);
          final dc = (s % b.cols) - (b.start % b.cols);
          if (max(dr.abs(), dc.abs()) > radius) away.add(s);
        }
        if (away.isNotEmpty) {
          level = l;
          found = b;
          hidden = away;
        }
      }
      expect(level, isNotNull,
          reason: 'no fog level in 15-99 has a grey outside the fog radius');

      SharedPreferences.setMockInitialValues({'level_zenslide': level!});
      setViewport(tester, const Size(412, 915));
      await pumpScreen(tester);

      expect(find.text('Icy Fog'), findsOneWidget);
      final b = found!;
      final radius = max(2, min(b.rows, b.cols) ~/ 2);
      for (final s in b.stones) {
        final r = s ~/ b.cols;
        final c = s % b.cols;
        final near = max((r - b.start ~/ b.cols).abs(),
                (c - b.start % b.cols).abs()) <=
            radius;
        expect(greyAt(r, c), near ? findsOneWidget : findsNothing,
            reason: 'grey at $r,$c should be ${near ? 'visible' : 'fogged'}');
      }
      expect(hidden, isNotEmpty);

      await tearDownScreen(tester);
    });
  });

  // -------------------------------------------------------------------- hints

  group('hints', () {
    testWidgets('the hint points along a shortest path and charges for it',
        (tester) async {
      const level = 0;
      SharedPreferences.setMockInitialValues({
        'level_zenslide': level,
        'hints_zenslide': 3,
      });
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);
      expect(find.byKey(const ValueKey('zenslide_hint_arrow')), findsNothing);

      await tester.tap(find.byTooltip('Hint'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      expect(find.byKey(const ValueKey('zenslide_hint_arrow')), findsOneWidget,
          reason: 'the hint drew no arrow');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('hints_zenslide'), 2);

      // Following it must actually move the stone somewhere useful.
      final b = boardFor(level);
      final replay = ZenSlideGame()..loadBoard(b, level);
      final dir = replay.hintDirection()!;
      await swipe(tester, dir);
      replay.swipe(dir.$1, dir.$2);
      expect(stoneAt(replay.stone ~/ b.cols, replay.stone % b.cols),
          findsOneWidget);

      await tearDownScreen(tester);
    });
  });

  // ---------------------------------------------------------------- win path

  group('winning', () {
    testWidgets('a solved board saves progress and awards exactly 10 points',
        (tester) async {
      const level = 0;
      SharedPreferences.setMockInitialValues({
        'level_zenslide': level,
        'points': 0,
      });
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);

      // Play the board out through the real gesture path, so the screen's own
      // swipe handling is what finishes it.
      final b = boardFor(level);
      final replay = ZenSlideGame()..loadBoard(b, level);
      var guard = 0;
      while (!replay.isWon && guard++ <= b.solveDistance) {
        final dir = replay.hintDirection();
        expect(dir, isNotNull, reason: 'the replay lost the thread');
        replay.swipe(dir!.$1, dir.$2);
        await swipe(tester, dir);
      }
      expect(replay.isWon, isTrue, reason: 'the replay never reached the lotus');

      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(find.textContaining('slides!'), findsOneWidget,
          reason: 'the win overlay never appeared');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('level_zenslide'), level + 1,
          reason: 'the win did not advance saved progress');
      // 10, the base award from `HintManager.onLevelCleared`.
      //
      // The extra 5 that Grid Path, Star Battle and the rest grant is a SPEED
      // BONUS gated on `_timeLeft > 0` — not a flat per-clear payment. Level 0
      // has no timer running, so no bonus is due. Paying it unconditionally is
      // what made two games over-reward a clear last release.
      expect(prefs.getInt('points'), 10, reason: 'the win did not award points');
      expect(prefs.getInt('cleared_count_zenslide'), 1,
          reason: 'the clear was not routed through HintManager.onLevelCleared');

      await tearDownScreen(tester);
    });
  });
}
