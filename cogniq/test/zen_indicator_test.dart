import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cogniq/theme/app_theme.dart';
import 'package:cogniq/utils/zen_mode.dart';
import 'package:cogniq/widgets/game_level_chip.dart';

/// Zen mode changes the game's progression — separate saved levels, no
/// modifiers — and until 2.4 **nothing on any game screen said so**. A player
/// who toggled it by accident saw their levels change with no explanation.
///
/// `GameLevelChip` now reads [ZenMode] itself, so all 24 games get the
/// indicator from one place and none can forget it. These tests pin that, and
/// pin the two things it must not break: the Daily label, and the app bar's
/// width budget.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ZenMode.setEnabled(false);
  });

  tearDown(() async => ZenMode.setEnabled(false));

  Widget host(Widget child, {Size size = const Size(412, 915)}) => MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const GameTitle('Kakuro'), actions: [child]),
        ),
      );

  group('the indicator appears exactly when Zen is on', () {
    testWidgets('Challenge mode shows the level and no leaf', (tester) async {
      await tester.pumpWidget(host(
        GameLevelChip(level: 12, accent: AppTheme.dustyMauve),
      ));
      expect(find.text('Level 12'), findsOneWidget);
      expect(find.byIcon(Icons.spa_rounded), findsNothing);
    });

    testWidgets('Zen mode names itself AND keeps the level', (tester) async {
      await ZenMode.setEnabled(true);
      await tester.pumpWidget(host(
        GameLevelChip(level: 12, accent: AppTheme.dustyMauve),
      ));

      // The level must survive: in Zen it is still real progress, just a
      // different ladder. Showing only "Zen" would hide it.
      expect(find.textContaining('Zen'), findsOneWidget);
      expect(find.textContaining('12'), findsOneWidget);
      expect(find.byIcon(Icons.spa_rounded), findsOneWidget,
          reason: 'the leaf matches the home-screen mode icon');
    });

    testWidgets('turning Zen off removes it again', (tester) async {
      await ZenMode.setEnabled(true);
      await tester.pumpWidget(host(
        GameLevelChip(level: 3, accent: AppTheme.dustyMauve),
      ));
      expect(find.byIcon(Icons.spa_rounded), findsOneWidget);

      await ZenMode.setEnabled(false);
      await tester.pumpWidget(host(
        GameLevelChip(key: const ValueKey('off'), level: 3, accent: AppTheme.dustyMauve),
      ));
      expect(find.byIcon(Icons.spa_rounded), findsNothing);
      expect(find.text('Level 3'), findsOneWidget);
    });
  });

  group('it does not break the daily challenge label', () {
    testWidgets('Daily still says Daily, in Challenge mode', (tester) async {
      await tester.pumpWidget(host(
        GameLevelChip(modeLabel: 'Daily', accent: AppTheme.dustyMauve),
      ));
      expect(find.text('Daily'), findsOneWidget);
      expect(find.byIcon(Icons.spa_rounded), findsNothing);
    });

    testWidgets('Daily still says Daily even while Zen is on', (tester) async {
      // A daily is never played in Zen, and there is no campaign level to show.
      // Zen must not hijack that label.
      await ZenMode.setEnabled(true);
      await tester.pumpWidget(host(
        GameLevelChip(modeLabel: 'Daily', accent: AppTheme.dustyMauve),
      ));
      expect(find.text('Daily'), findsOneWidget);
      expect(find.textContaining('Zen'), findsNothing);
      expect(find.byIcon(Icons.spa_rounded), findsNothing);
    });
  });

  group('the wider label does not overflow the app bar', () {
    // The chip is the widest thing in the actions row, and adding a leaf plus
    // the word "Zen" makes it wider still. Three separate app-bar overflows
    // have shipped in this project from exactly this kind of growth.
    const sizes = <String, Size>{
      'small phone': Size(320, 568),
      'typical phone': Size(412, 915),
      'large phone': Size(480, 1000),
      'wide-short': Size(1568, 696),
    };

    sizes.forEach((label, size) {
      testWidgets('no overflow at $label with Zen on and a 3-digit level',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final overflows = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) {
            overflows.add(details.exceptionAsString().split('\n').first);
          } else {
            previous?.call(details);
          }
        };
        addTearDown(() => FlutterError.onError = previous);

        await ZenMode.setEnabled(true);
        await tester.pumpWidget(host(
          // Worst case: longest label, plus the debug pencil.
          GameLevelChip(
            level: 999,
            accent: AppTheme.dustyMauve,
            onTap: () {},
          ),
          size: size,
        ));
        await tester.pumpAndSettle();

        expect(overflows, isEmpty, reason: '$label: ${overflows.join('; ')}');
      });
    });

    testWidgets('the label scales down rather than clipping', (tester) async {
      await ZenMode.setEnabled(true);
      await tester.pumpWidget(host(
        GameLevelChip(level: 999, accent: AppTheme.dustyMauve, onTap: () {}),
      ));
      expect(find.byType(FittedBox), findsWidgets,
          reason: 'a long label must shrink, never clip');
    });
  });
}
