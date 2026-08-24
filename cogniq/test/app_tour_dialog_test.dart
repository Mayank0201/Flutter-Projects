import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cogniq/theme/app_theme.dart';
import 'package:cogniq/utils/prefs_keys.dart';
import 'package:cogniq/widgets/app_tour_dialog.dart';

/// The first-run tour: it must appear exactly once, it must be escapable, and
/// it must fit on every window shape the app ships on.
///
/// The wide-short viewport below is not decoration. Every other size here is
/// taller than it is wide, and two shipped overflows (Hitori 2.0, Slitherlink
/// 2.1) hid behind exactly that gap — see `layout_overflow_test.dart`.
const viewports = <String, Size>{
  'small phone 320x568': Size(320, 568),
  'typical phone 412x915': Size(412, 915),
  'large phone 480x1000': Size(480, 1000),
  'wide-short 1568x696 (landscape / tablet / split screen)': Size(1568, 696),
};

/// A minimal host that offers the tour the way the home screen does.
Widget _host({
  required GlobalKey<NavigatorState> navKey,
  bool dark = false,
  bool autoShow = true,
}) {
  return MaterialApp(
    navigatorKey: navKey,
    theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              if (autoShow) {
                AppTourDialog.showIfFirstRun(context);
              } else {
                AppTourDialog.show(context);
              }
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Never reach for the network in a test; fall back to the bundled font.
  GoogleFonts.config.allowRuntimeFetching = false;

  final navKey = GlobalKey<NavigatorState>();

  testWidgets('shows on first run and marks itself seen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_host(navKey: navKey));

    await tester.tap(find.text('open'));
    await _settle(tester);

    expect(find.byType(AppTourDialog), findsOneWidget);
    expect(find.text('Welcome to CogniQ'), findsOneWidget);
    expect(find.text('Step 1 of ${AppTourDialog.steps.length}'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PrefsKeys.hasSeenAppTour), isTrue);
  });

  testWidgets('does not show on the second run', (tester) async {
    SharedPreferences.setMockInitialValues({PrefsKeys.hasSeenAppTour: true});
    await tester.pumpWidget(_host(navKey: navKey));

    await tester.tap(find.text('open'));
    await _settle(tester);

    expect(find.byType(AppTourDialog), findsNothing);
  });

  testWidgets('showIfFirstRun reports whether it showed anything',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_host(navKey: navKey, autoShow: false));
    await tester.pump();

    final context = navKey.currentContext!;

    // First call shows the tour; the future stays pending until it is closed,
    // which is what lets the home screen hold back the daily-challenge prompt.
    bool? firstResult;
    final first =
        AppTourDialog.showIfFirstRun(context).then((v) => firstResult = v);
    await _settle(tester);
    expect(find.byType(AppTourDialog), findsOneWidget);
    expect(firstResult, isNull, reason: 'must not complete while still open');

    await tester.tap(find.text('Skip'));
    await _settle(tester);
    await first;
    expect(firstResult, isTrue);

    // Second call is a no-op and completes immediately.
    expect(await AppTourDialog.showIfFirstRun(context), isFalse);
    await _settle(tester);
    expect(find.byType(AppTourDialog), findsNothing);
  });

  testWidgets('Skip closes the tour from the very first step', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_host(navKey: navKey));

    await tester.tap(find.text('open'));
    await _settle(tester);
    expect(find.byType(AppTourDialog), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await _settle(tester);
    expect(find.byType(AppTourDialog), findsNothing);
  });

  testWidgets('Skip works from a middle step too', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_host(navKey: navKey));

    await tester.tap(find.text('open'));
    await _settle(tester);

    await tester.tap(find.text('Next'));
    await _settle(tester);
    await tester.tap(find.text('Next'));
    await _settle(tester);
    expect(find.text('Step 3 of ${AppTourDialog.steps.length}'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await _settle(tester);
    expect(find.byType(AppTourDialog), findsNothing);
  });

  testWidgets('Next walks every step and the last one closes the tour',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_host(navKey: navKey));

    await tester.tap(find.text('open'));
    await _settle(tester);

    final steps = AppTourDialog.steps;
    for (var i = 0; i < steps.length; i++) {
      expect(
        find.text('Step ${i + 1} of ${steps.length}'),
        findsOneWidget,
        reason: 'expected to be on step ${i + 1}',
      );
      expect(
        find.text(steps[i].title),
        findsOneWidget,
        reason: 'step ${i + 1} should show its own title',
      );

      final isLast = i == steps.length - 1;
      await tester.tap(find.text(isLast ? 'Done' : 'Next'));
      await _settle(tester);
    }

    expect(find.byType(AppTourDialog), findsNothing);
  });

  testWidgets('Back returns to the previous step', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_host(navKey: navKey));

    await tester.tap(find.text('open'));
    await _settle(tester);

    // No Back on the first step — there is nothing to go back to.
    expect(find.text('Back'), findsNothing);

    await tester.tap(find.text('Next'));
    await _settle(tester);
    expect(find.text('Step 2 of ${AppTourDialog.steps.length}'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await _settle(tester);
    expect(find.text('Step 1 of ${AppTourDialog.steps.length}'), findsOneWidget);
    expect(find.text('Back'), findsNothing);
  });

  testWidgets('covers the features a new player must not miss', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_host(navKey: navKey));
    await tester.tap(find.text('open'));
    await _settle(tester);

    final titles =
        AppTourDialog.steps.map((s) => s.title.toLowerCase()).toList();
    for (final needed in const [
      'zen',
      'shuffle',
      'daily challenge',
      'achievements',
      'iq points',
      'hints',
    ]) {
      expect(
        titles.any((t) => t.contains(needed)),
        isTrue,
        reason: 'the tour must have a step about "$needed"',
      );
    }

    // Zen's parallel progression is the whole reason that step exists: a
    // player who toggles the leaf by accident must be told nothing was lost.
    final zen = AppTourDialog.steps
        .firstWhere((s) => s.title.toLowerCase().contains('zen'))
        .description
        .toLowerCase();
    expect(zen.contains('own levels'), isTrue);
    expect(zen.contains('nothing is deleted'), isTrue);
  });

  // ── Layout ────────────────────────────────────────────────────────────────
  for (final vp in viewports.entries) {
    for (final dark in const [false, true]) {
      final themeName = dark ? 'dark' : 'light';
      testWidgets('no overflow on any step at ${vp.key} ($themeName)',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = vp.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final overflows = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          final text = details.exceptionAsString();
          if (text.contains('overflowed by')) {
            overflows.add(text.split('\n').first);
          } else {
            previous?.call(details);
          }
        };

        try {
          await tester.pumpWidget(_host(navKey: navKey, dark: dark));
          await tester.tap(find.text('open'));
          await _settle(tester);

          // Walk every step, including the longest one (Zen), so a step that
          // only overflows because of its text length cannot hide behind
          // step 1 fitting.
          for (var i = 0; i < AppTourDialog.steps.length; i++) {
            expect(find.byType(AppTourDialog), findsOneWidget);
            final isLast = i == AppTourDialog.steps.length - 1;
            await tester.tap(find.text(isLast ? 'Done' : 'Next'));
            await _settle(tester);
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 50));
          FlutterError.onError = previous;
        }

        expect(
          overflows,
          isEmpty,
          reason: 'App tour overflows at ${vp.key} ($themeName):\n'
              '${overflows.join('\n')}',
        );
      });
    }
  }
}
