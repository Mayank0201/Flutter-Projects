import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cogniq/screens/games/lightbeam/lightbeam_logic.dart';
import 'package:cogniq/screens/games/lightbeam/lightbeam_screen.dart';
import 'package:cogniq/utils/rotation_engine.dart';

/// Widget tests for the Light Beam screen.
///
/// The screen is pumped directly rather than through a named route, so these
/// pass before the game is registered in `main.dart`.
///
/// The board the screen deals is not a mystery to the test: the screen seeds
/// generation with `RotationEngine.getDeterminism('lightbeam', level)`, so the
/// test rebuilds the identical board and knows exactly which cells are free,
/// where the crystals are, and which mirrors finish it. That is what makes the
/// assertions specific rather than "something changed".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Never reach for the network in a test; fall back to the bundled font.
  GoogleFonts.config.allowRuntimeFetching = false;

  /// The exact board `LightBeamScreen` will deal for [level].
  LightBeamBoard boardFor(int level) => LightBeamLogic.generate(
        RotationEngine.getDeterminism('lightbeam', level),
        level,
      );

  Finder cell(int r, int c) => find.byKey(ValueKey('lightbeam_cell_${r}_$c'));
  Finder slashAt(int r, int c) =>
      find.byKey(ValueKey('lightbeam_slash_${r}_$c'));
  Finder backslashAt(int r, int c) =>
      find.byKey(ValueKey('lightbeam_backslash_${r}_$c'));

  /// The first cell that is neither a crystal nor a wall — always tappable.
  (int, int) freeCellOf(LightBeamBoard b) {
    for (var r = 0; r < b.n; r++) {
      for (var c = 0; c < b.n; c++) {
        if (b.grid[r][c] == LightBeamCell.empty && !b.crystals.contains((r, c))) {
          return (r, c);
        }
      }
    }
    throw StateError('the dealt board has no free cell');
  }

  /// Pumps the screen and lets the async level load settle.
  Future<void> pumpScreen(WidgetTester tester, {ThemeData? theme}) async {
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: const LightBeamScreen(),
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

  // ------------------------------------------------------------------ layout

  group('layout', () {
    const viewports = <String, Size>{
      'small phone 320x568': Size(320, 568),
      'typical phone 412x915': Size(412, 915),
      'large phone 480x1000': Size(480, 1000),
    };

    // Level 0 is a 5x5 with one crystal; level 66 is the documented hardest
    // board (8x8, 7 mirrors, 5 crystals, 3 walls) and also carries modifiers,
    // so the strip is on screen too.
    for (final level in [0, 66]) {
      for (final vp in viewports.entries) {
        testWidgets('level $level has no overflow at ${vp.key}',
            (tester) async {
          SharedPreferences.setMockInitialValues({'level_lightbeam': level});
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
            expect(cell(0, 0), findsOneWidget);
          } finally {
            await tearDownScreen(tester);
            FlutterError.onError = previous;
          }

          expect(overflows, isEmpty,
              reason:
                  'Light Beam overflows at ${vp.key}:\n${overflows.join('\n')}');
        });
      }
    }

    testWidgets('every cell of the dealt board is on screen at 320x568',
        (tester) async {
      SharedPreferences.setMockInitialValues({'level_lightbeam': 66});
      setViewport(tester, const Size(320, 568));

      await pumpScreen(tester);
      final board = boardFor(66);
      expect(board.n, 8);
      for (var r = 0; r < board.n; r++) {
        for (var c = 0; c < board.n; c++) {
          expect(cell(r, c), findsOneWidget, reason: 'cell $r,$c is missing');
        }
      }
      // And every crystal has a glyph.
      for (final (r, c) in board.crystals) {
        expect(find.byKey(ValueKey('lightbeam_crystal_${r}_$c')), findsOneWidget);
      }
      await tearDownScreen(tester);
    });

    testWidgets('boots at every stage of the curve without an exception',
        (tester) async {
      // Includes the levels the work order names (0, 5, 20, 60, 120) plus the
      // rest of the ladder test/all_games_all_levels_test.dart uses, so the
      // screen is known good before it is added to that harness.
      const levels = [0, 5, 11, 14, 15, 20, 30, 45, 60, 66, 90, 120];
      setViewport(tester, const Size(412, 915));

      final failures = <String>[];
      for (final level in levels) {
        SharedPreferences.setMockInitialValues({
          'level_lightbeam': level,
          'hints_lightbeam': 3,
        });

        final previous = FlutterError.onError;
        FlutterError.onError = (details) => failures
            .add('level $level: ${details.exceptionAsString().split('\n').first}');
        try {
          await pumpScreen(tester);
          expect(cell(0, 0), findsOneWidget, reason: 'level $level did not deal');
        } finally {
          await tearDownScreen(tester);
          FlutterError.onError = previous;
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    testWidgets('renders in light theme too', (tester) async {
      SharedPreferences.setMockInitialValues({'level_lightbeam': 0});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester, theme: ThemeData.light());
      expect(cell(0, 0), findsOneWidget);
      await tearDownScreen(tester);
    });
  });

  // -------------------------------------------------------------------- header

  group('header', () {
    testWidgets('the level chip shows the saved level, one-based',
        (tester) async {
      SharedPreferences.setMockInitialValues({'level_lightbeam': 7});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);

      expect(find.text('Level 8'), findsOneWidget);
      // remember.md E2 section 7: nothing else on the screen may show the level.
      expect(find.textContaining('Level '), findsOneWidget);
      expect(find.text('Light Beam'), findsOneWidget);

      await tearDownScreen(tester);
    });

    testWidgets('a fresh player starts on level 1', (tester) async {
      SharedPreferences.setMockInitialValues({});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);
      expect(find.text('Level 1'), findsOneWidget);
      await tearDownScreen(tester);
    });

    testWidgets('the level chip is still the only level readout at level 120',
        (tester) async {
      SharedPreferences.setMockInitialValues({'level_lightbeam': 119});
      setViewport(tester, const Size(320, 568));

      await pumpScreen(tester);
      expect(find.text('Level 120'), findsOneWidget);
      expect(find.textContaining('Level '), findsOneWidget);
      await tearDownScreen(tester);
    });
  });

  // -------------------------------------------------------------------- play

  group('tapping', () {
    testWidgets(r'a tap cycles a cell / -> \ -> empty', (tester) async {
      const level = 0;
      SharedPreferences.setMockInitialValues({'level_lightbeam': level});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);
      final (r, c) = freeCellOf(boardFor(level));

      expect(slashAt(r, c), findsNothing);
      expect(backslashAt(r, c), findsNothing);

      await tester.tap(cell(r, c));
      await tester.pump(const Duration(milliseconds: 250));
      expect(slashAt(r, c), findsOneWidget, reason: 'first tap should place /');
      expect(backslashAt(r, c), findsNothing);

      await tester.tap(cell(r, c));
      await tester.pump(const Duration(milliseconds: 250));
      expect(backslashAt(r, c), findsOneWidget,
          reason: r'second tap should flip to \');
      expect(slashAt(r, c), findsNothing);

      await tester.tap(cell(r, c));
      await tester.pump(const Duration(milliseconds: 250));
      expect(slashAt(r, c), findsNothing, reason: 'third tap should clear it');
      expect(backslashAt(r, c), findsNothing);

      await tearDownScreen(tester);
    });

    testWidgets('a crystal cell refuses the tap', (tester) async {
      const level = 0;
      SharedPreferences.setMockInitialValues({'level_lightbeam': level});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);
      final (r, c) = boardFor(level).crystals.first;

      await tester.tap(cell(r, c));
      await tester.pump(const Duration(milliseconds: 250));

      expect(slashAt(r, c), findsNothing);
      expect(backslashAt(r, c), findsNothing);
      expect(find.byKey(ValueKey('lightbeam_crystal_${r}_$c')), findsOneWidget);
      await tearDownScreen(tester);
    });

    testWidgets('the mirror counter tracks placements', (tester) async {
      const level = 0;
      SharedPreferences.setMockInitialValues({'level_lightbeam': level});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);
      final board = boardFor(level);
      final budget = board.mirrorBudget;
      expect(find.textContaining('Mirrors $budget / $budget'), findsOneWidget);

      final (r, c) = freeCellOf(board);
      await tester.tap(cell(r, c));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.textContaining('Mirrors ${budget - 1} / $budget'),
          findsOneWidget);

      await tearDownScreen(tester);
    });

    testWidgets('Restart clears the mirrors the player placed', (tester) async {
      const level = 0;
      SharedPreferences.setMockInitialValues({'level_lightbeam': level});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);
      final (r, c) = freeCellOf(boardFor(level));

      await tester.tap(cell(r, c));
      await tester.pump(const Duration(milliseconds: 250));
      expect(slashAt(r, c), findsOneWidget);

      await tester.tap(find.text('Restart'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(slashAt(r, c), findsNothing);
      expect(backslashAt(r, c), findsNothing);

      await tearDownScreen(tester);
    });
  });

  // --------------------------------------------------------------- modifiers

  group('modifiers', () {
    testWidgets('no modifier strip before the modifier start level',
        (tester) async {
      SharedPreferences.setMockInitialValues({'level_lightbeam': 0});
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);
      expect(find.textContaining('Timer'), findsNothing);
      expect(find.text('Exact Mirrors'), findsNothing);
      expect(find.text('Beam Fog'), findsNothing);
      await tearDownScreen(tester);
    });

    testWidgets('every active modifier is named on screen', (tester) async {
      // remember.md E2 section 8: whatever the engine picks from the pool must
      // be visible to the player. The pool here must mirror the screen's
      // exactly, and all three entries are implemented in lightbeam_screen.dart.
      const labels = {
        'timer': 'Timer',
        'tightBudget': 'Exact Mirrors',
        'fog': 'Beam Fog',
      };
      setViewport(tester, const Size(412, 915));

      for (final level in [15, 20, 30, 60]) {
        final active = RotationEngine.getActiveModifiers(
          gameId: 'lightbeam',
          levelIndex: level,
          pool: const ['timer', 'tightBudget', 'fog'],
          minActive: 1,
          maxActive: 2,
        );
        expect(active, isNotEmpty,
            reason: 'level $level should carry at least one modifier');

        SharedPreferences.setMockInitialValues({'level_lightbeam': level});
        await pumpScreen(tester);
        for (final name in active) {
          // The timer chip carries its live countdown, so match on the prefix.
          expect(find.textContaining(labels[name]!), findsOneWidget,
              reason: '$name is active at level $level but never shown');
        }
        await tearDownScreen(tester);
      }
    });

    test('the pool survives difficulty_curve_test\'s flat-run guard', () {
      // A local copy of the assertion in test/difficulty_curve_test.dart, run
      // with the same default min/maxActive that harness uses. A two-entry pool
      // would fail it: RotationEngine runs a singles tier then a pairs tier, and
      // two entries give the pairs tier exactly one combination, which it then
      // serves for 35 straight levels. Three entries keep it moving.
      const pool = ['timer', 'tightBudget', 'fog'];
      final start = RotationEngine.modifierStartLevel('lightbeam');
      expect(start, lessThanOrEqualTo(30));

      String? previous;
      for (var l = start; l < start + 40; l++) {
        final set = (RotationEngine.getActiveModifiers(
              gameId: 'lightbeam',
              levelIndex: l,
              pool: pool,
            ).toList()
              ..sort())
            .join('+');
        expect(set, isNot(previous),
            reason: 'lightbeam repeats a modifier set back to back at level $l');
        previous = set;
      }
    });

    testWidgets('tightBudget leaves no spare mirror', (tester) async {
      // Find a level where the engine picks tightBudget, then check the footer
      // reports exactly the solution length rather than the usual early spare.
      int? level;
      for (var l = 15; l < 30 && level == null; l++) {
        final active = RotationEngine.getActiveModifiers(
          gameId: 'lightbeam',
          levelIndex: l,
          pool: const ['timer', 'tightBudget', 'fog'],
          minActive: 1,
          maxActive: 2,
        );
        if (active.contains('tightBudget')) level = l;
      }
      expect(level, isNotNull,
          reason: 'tightBudget never fires in the singles tier');

      SharedPreferences.setMockInitialValues({'level_lightbeam': level!});
      setViewport(tester, const Size(412, 915));
      await pumpScreen(tester);

      final needed = boardFor(level).solutionMirrorCount;
      expect(find.textContaining('Mirrors $needed / $needed'), findsOneWidget,
          reason: 'the exact-mirrors modifier did not tighten the budget');
      await tearDownScreen(tester);
    });
  });

  // -------------------------------------------------------------------- hints

  group('hints', () {
    testWidgets('the hint button reveals a solution mirror and charges for it',
        (tester) async {
      const level = 0;
      SharedPreferences.setMockInitialValues({
        'level_lightbeam': level,
        'hints_lightbeam': 3,
      });
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);

      final (pos, mirror) = boardFor(level).solutionMirrors.first;
      await tester.tap(find.byTooltip('Hint'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      final expected = mirror == LightBeamCell.slash
          ? slashAt(pos.$1, pos.$2)
          : backslashAt(pos.$1, pos.$2);
      expect(expected, findsOneWidget,
          reason: 'the hint did not reveal the first solution mirror');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('hints_lightbeam'), 2);

      await tearDownScreen(tester);
    });
  });

  // --------------------------------------------------------------- win path

  group('winning', () {
    testWidgets('building the solution saves progress and awards 10 points',
        (tester) async {
      const level = 0;
      SharedPreferences.setMockInitialValues({
        'level_lightbeam': level,
        'points': 0,
      });
      setViewport(tester, const Size(412, 915));

      await pumpScreen(tester);

      // Play the board out through the real cell widgets, so the screen's own
      // tap handling is what finishes it.
      final board = boardFor(level);
      final replay = LightBeamGame()..loadBoard(board, level);
      for (final (pos, mirror) in board.solutionMirrors) {
        if (replay.isWon) break;
        var guard = 0;
        while (replay.grid[pos.$1][pos.$2] != mirror && guard++ < 4) {
          replay.tapCell(pos.$1, pos.$2);
          await tester.tap(cell(pos.$1, pos.$2));
          await tester.pump(const Duration(milliseconds: 220));
        }
      }
      expect(replay.isWon, isTrue, reason: 'the replay never reached a win');

      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      expect(find.textContaining('Every crystal lit'), findsOneWidget,
          reason: 'the win overlay never appeared');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('level_lightbeam'), level + 1,
          reason: 'the win did not advance saved progress');
      // 10, the base award from `HintManager.onLevelCleared`.
      //
      // The extra 5 that Grid Path, Star Battle and the rest grant is a SPEED
      // BONUS gated on `_timeLeft > 0` — not a flat per-clear payment. Level 0
      // has no timer running, so no bonus is due. Paying it unconditionally is
      // what made two games over-reward a clear last release.
      expect(prefs.getInt('points'), 10, reason: 'the win did not award points');
      expect(prefs.getInt('cleared_count_lightbeam'), 1,
          reason: 'the clear was not routed through HintManager.onLevelCleared');

      await tearDownScreen(tester);
    });
  });
}
