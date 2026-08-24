import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cogniq/screens/games/sandsort/sandsort_logic.dart';
import 'package:cogniq/screens/games/sandsort/sandsort_screen.dart';
import 'package:cogniq/utils/rotation_engine.dart';

/// Widget tests for the Sand Sort screen.
///
/// The screen is pumped directly rather than through a named route, so these
/// pass before the game is registered in `main.dart`.
///
/// The board the screen deals is not a mystery to the test: the screen seeds
/// generation with `RotationEngine.getDeterminism('sandsort', level)`, so the
/// test rebuilds the identical board and knows exactly which pour is legal and
/// how many layers it should move. That is what makes the pour assertion
/// specific rather than "something changed".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Never reach for the network in a test; fall back to the bundled font.
  GoogleFonts.config.allowRuntimeFetching = false;

  /// The exact board `SandSortScreen` will deal for [level].
  SandSortBoard boardFor(int level) => SandSortLogic.generate(
        RotationEngine.getDeterminism('sandsort', level),
        level,
      );

  Finder tube(int t) => find.byKey(ValueKey('sandsort_tube_$t'));
  Finder layer(int t, int i) => find.byKey(ValueKey('sandsort_layer_${t}_$i'));

  /// Pumps the screen and lets the async level load settle.
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SandSortScreen()));
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

  // ------------------------------------------------------------------ layout

  group('layout', () {
    const viewports = <String, Size>{
      'small phone 320x568': Size(320, 568),
      'typical phone 412x915': Size(412, 915),
      'large phone 480x1000': Size(480, 1000),
    };

    // Level 0 has 5 tubes, level 60 has the maximum 8 (6 colours + 2 empties),
    // and level 60 also carries modifiers, so the strip is on screen too.
    for (final level in [0, 60]) {
      for (final vp in viewports.entries) {
        testWidgets('level $level has no overflow at ${vp.key}',
            (tester) async {
          SharedPreferences.setMockInitialValues({'level_sandsort': level});
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
            expect(tube(0), findsOneWidget);
          } finally {
            await tearDownScreen(tester);
            FlutterError.onError = previous;
          }

          expect(overflows, isEmpty,
              reason: 'Sand Sort overflows at ${vp.key}:\n${overflows.join('\n')}');
        });
      }
    }

    testWidgets('every tube of the dealt board is on screen', (tester) async {
      SharedPreferences.setMockInitialValues({'level_sandsort': 60});
      setViewport(tester, const Size(320, 568));

      await pumpScreen(tester);
      final board = boardFor(60);
      expect(board.tubeCount, 8);
      for (var t = 0; t < board.tubeCount; t++) {
        expect(tube(t), findsOneWidget, reason: 'tube $t is missing');
      }
      await tearDownScreen(tester);
    });

    testWidgets('boots at every stage of the curve without an exception',
        (tester) async {
      // The same level ladder test/all_games_all_levels_test.dart uses, run here
      // so the screen is known good before it is added to that harness.
      const levels = [0, 5, 11, 14, 20, 30, 45, 60, 90, 120];
      setViewport(tester, const Size(412, 915));

      final failures = <String>[];
      for (final level in levels) {
        SharedPreferences.setMockInitialValues({
          'level_sandsort': level,
          'hints_sandsort': 3,
        });

        final previous = FlutterError.onError;
        FlutterError.onError = (details) =>
            failures.add('level $level: ${details.exceptionAsString().split('\n').first}');
        try {
          await pumpScreen(tester);
          expect(tube(0), findsOneWidget, reason: 'level $level did not deal');
        } finally {
          await tearDownScreen(tester);
          FlutterError.onError = previous;
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    testWidgets('renders in light theme too', (tester) async {
      SharedPreferences.setMockInitialValues({'level_sandsort': 0});
      setViewport(tester, const Size(412, 915));

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.light(),
        home: const SandSortScreen(),
      ));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(tube(0), findsOneWidget);
      await tearDownScreen(tester);
    });
  });

  // -------------------------------------------------------------------- header

  group('header', () {
    testWidgets('the level chip shows the saved level, one-based',
        (tester) async {
      SharedPreferences.setMockInitialValues({'level_sandsort': 7});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);

      expect(find.text('Level 8'), findsOneWidget);
      // remember.md E2 section 7: nothing else on the screen may show the level.
      expect(find.textContaining('Level '), findsOneWidget);
      expect(find.text('Sand Sort'), findsOneWidget);

      await tearDownScreen(tester);
    });

    testWidgets('a fresh player starts on level 1', (tester) async {
      SharedPreferences.setMockInitialValues({});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);
      expect(find.text('Level 1'), findsOneWidget);
      await tearDownScreen(tester);
    });
  });

  // -------------------------------------------------------------------- play

  group('pouring', () {
    testWidgets('tapping a source then a destination performs a legal pour',
        (tester) async {
      const level = 0;
      SharedPreferences.setMockInitialValues({'level_sandsort': level});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);

      // Work out the pour the screen must perform, from the identical board.
      final board = boardFor(level);
      final tubes = board.cloneTubes();
      int? from, to;
      for (var a = 0; a < tubes.length && from == null; a++) {
        for (var b = 0; b < tubes.length; b++) {
          if (SandSortLogic.canPourState(tubes, board.capacity, a, b)) {
            from = a;
            to = b;
            break;
          }
        }
      }
      expect(from, isNotNull, reason: 'the dealt board has no legal pour');

      final beforeDepth = tubes[to!].length;
      final moved =
          SandSortLogic.pourState(tubes, board.capacity, from!, to);
      expect(moved, greaterThan(0));

      // The destination's new top layer must not exist yet.
      expect(layer(to, beforeDepth), findsNothing);

      await tester.tap(tube(from));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(tube(to));
      await tester.pump(const Duration(milliseconds: 250));

      // The destination gained exactly the layers the logic says it should.
      for (var i = 0; i < tubes[to].length; i++) {
        expect(layer(to, i), findsOneWidget,
            reason: 'destination tube $to is missing layer $i after the pour');
      }
      expect(layer(to, tubes[to].length), findsNothing,
          reason: 'destination tube $to gained too much sand');

      // And the source lost them.
      for (var i = 0; i < tubes[from].length; i++) {
        expect(layer(from, i), findsOneWidget);
      }
      expect(layer(from, tubes[from].length), findsNothing,
          reason: 'source tube $from did not lose its poured layers');

      await tearDownScreen(tester);
    });

    testWidgets('tapping the same tube twice puts the sand back down',
        (tester) async {
      const level = 0;
      SharedPreferences.setMockInitialValues({'level_sandsort': level});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);
      final board = boardFor(level);
      final depths = [for (final t in board.tubes) t.length];

      await tester.tap(tube(0));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(tube(0));
      await tester.pump(const Duration(milliseconds: 250));

      for (var t = 0; t < depths.length; t++) {
        expect(layer(t, depths[t]), findsNothing,
            reason: 'tube $t changed on a select/deselect');
      }
      await tearDownScreen(tester);
    });

    testWidgets('an illegal pour changes nothing and moves the selection',
        (tester) async {
      const level = 0;
      SharedPreferences.setMockInitialValues({'level_sandsort': level});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);

      final board = boardFor(level);
      final tubes = board.cloneTubes();
      int? from, to;
      for (var a = 0; a < tubes.length && from == null; a++) {
        for (var b = 0; b < tubes.length; b++) {
          if (a != b &&
              !SandSortLogic.canPourState(tubes, board.capacity, a, b) &&
              tubes[a].isNotEmpty) {
            from = a;
            to = b;
            break;
          }
        }
      }
      expect(from, isNotNull,
          reason: 'the dealt board has no illegal pair to test with');

      await tester.tap(tube(from!));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(tube(to!));
      await tester.pump(const Duration(milliseconds: 250));

      for (var t = 0; t < tubes.length; t++) {
        for (var i = 0; i < tubes[t].length; i++) {
          expect(layer(t, i), findsOneWidget);
        }
        expect(layer(t, tubes[t].length), findsNothing,
            reason: 'tube $t changed on an illegal pour');
      }
      await tearDownScreen(tester);
    });

    testWidgets('Restart puts the dealt board back', (tester) async {
      const level = 0;
      SharedPreferences.setMockInitialValues({'level_sandsort': level});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);

      final board = boardFor(level);
      final tubes = board.cloneTubes();
      int? from, to;
      for (var a = 0; a < tubes.length && from == null; a++) {
        for (var b = 0; b < tubes.length; b++) {
          if (SandSortLogic.canPourState(tubes, board.capacity, a, b)) {
            from = a;
            to = b;
            break;
          }
        }
      }
      SandSortLogic.pourState(tubes, board.capacity, from!, to!);

      await tester.tap(tube(from));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(tube(to));
      await tester.pump(const Duration(milliseconds: 250));
      expect(layer(to, tubes[to].length - 1), findsOneWidget);

      await tester.tap(find.text('Restart'));
      await tester.pump(const Duration(milliseconds: 250));

      for (var t = 0; t < board.tubes.length; t++) {
        for (var i = 0; i < board.tubes[t].length; i++) {
          expect(layer(t, i), findsOneWidget);
        }
        expect(layer(t, board.tubes[t].length), findsNothing,
            reason: 'Restart did not put tube $t back');
      }
      await tearDownScreen(tester);
    });
  });

  // --------------------------------------------------------------- modifiers

  group('modifiers', () {
    testWidgets('no modifier strip before the modifier start level',
        (tester) async {
      SharedPreferences.setMockInitialValues({'level_sandsort': 0});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);
      expect(find.textContaining('Timer'), findsNothing);
      expect(find.text('Monochrome'), findsNothing);
      await tearDownScreen(tester);
    });

    testWidgets('an active modifier is named on screen', (tester) async {
      // Whatever the engine picks from the pool must be visible to the player
      // (remember.md E2 section 8). This used to keep its own copy of the pool
      // and silently disagreed with the screen the moment the screen's pool
      // changed; it now reads `kSandSortModifierPool` directly, so the two can
      // never drift. Entries beyond two exist because two left the engine
      // repeating one combination for 30 levels straight. Fog was tried first
      // and removed — it hid the tubes the player has to compare.
      const level = 40;
      SharedPreferences.setMockInitialValues({'level_sandsort': level});
      setViewport(tester, const Size(412, 915));

      final active = RotationEngine.getActiveModifiers(
        gameId: 'sandsort',
        levelIndex: level,
        pool: kSandSortModifierPool,
        minActive: 1,
        maxActive: 2,
      );
      expect(active, isNotEmpty,
          reason: 'level $level should carry at least one modifier');

      await pumpScreen(tester);
      for (final name in active) {
        // The timer chip carries its live countdown, so match on the prefix.
        const labels = {
          'timer': 'Timer',
          'monochrome': 'Monochrome',
          'quota': 'Move Budget',
          'heartbeat': 'Pulse Vision',
        };
        final label = labels[name]!;
        expect(find.textContaining(label), findsOneWidget,
            reason: '$name is active but never shown to the player');
      }
      await tearDownScreen(tester);
    });
  });

  // -------------------------------------------------------------------- hints

  group('hints', () {
    testWidgets('the hint button plays a legal pour', (tester) async {
      const level = 0;
      SharedPreferences.setMockInitialValues({
        'level_sandsort': level,
        'hints_sandsort': 3,
      });
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);

      final board = boardFor(level);
      final tubes = board.cloneTubes();
      final hint = SandSortLogic.bestPourState(tubes, board.capacity);
      expect(hint, isNotNull);
      SandSortLogic.pourState(tubes, board.capacity, hint!.$1, hint.$2);

      await tester.tap(find.byTooltip('Hint'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      for (var t = 0; t < tubes.length; t++) {
        for (var i = 0; i < tubes[t].length; i++) {
          expect(layer(t, i), findsOneWidget,
              reason: 'tube $t layer $i missing after the hint');
        }
        expect(layer(t, tubes[t].length), findsNothing);
      }

      // The hint was charged for, because it actually played a move.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('hints_sandsort'), 2);

      await tearDownScreen(tester);
    });
  });

  // --------------------------------------------------------------- win path

  group('winning', () {
    testWidgets('following hints to the end saves progress and awards points',
        (tester) async {
      const level = 0;
      SharedPreferences.setMockInitialValues({
        'level_sandsort': level,
        'hints_sandsort': 999,
        'points': 0,
      });
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);

      // Play the board out with the solver's own shortest line, tapping the
      // real tube widgets so the screen's tap handling is what finishes it.
      final tubes = boardFor(level).cloneTubes();
      const capacity = SandSortLogic.capacity;
      var guard = 0;
      while (!SandSortLogic.isWonState(tubes, capacity) && guard++ < 200) {
        final move = SandSortLogic.bestPourState(tubes, capacity);
        expect(move, isNotNull);
        SandSortLogic.pourState(tubes, capacity, move!.$1, move.$2);

        await tester.tap(tube(move.$1));
        await tester.pump(const Duration(milliseconds: 220));
        await tester.tap(tube(move.$2));
        await tester.pump(const Duration(milliseconds: 220));
      }
      expect(SandSortLogic.isWonState(tubes, capacity), isTrue);

      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('level_sandsort'), level + 1,
          reason: 'the win did not advance saved progress');
      // 10, the base award from `HintManager.onLevelCleared`.
      //
      // The extra 5 that Grid Path, Star Battle and the rest grant is a SPEED
      // BONUS gated on `_timeLeft > 0` — not a flat per-clear payment. This level
      // has no timer running, so no bonus is due. An earlier draft of this screen
      // paid the 5 unconditionally (and Kakuro paid 10), which made a clear here
      // worth more than the identical clear in any other game.
      expect(prefs.getInt('points'), 10,
          reason: 'the win did not award points');
      expect(prefs.getInt('cleared_count_sandsort'), 1,
          reason: 'the clear was not routed through HintManager.onLevelCleared');

      await tearDownScreen(tester);
    });
  });
}
