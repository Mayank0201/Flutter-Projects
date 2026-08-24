import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cogniq/screens/games/odd_color_out/odd_color_out_screen.dart';
import 'package:cogniq/screens/games/spectrum/spectrum_screen.dart';

/// The seeded-RNG law (remember.md): a free-play level must draw the same board
/// on every device and on every replay.
///
/// Odd Color Out and Spectrum both used to fall back to an unseeded `Random()`
/// below level 90 / level 30 -- the whole realistic play range -- so the same
/// level looked different to every player, and every retry. This boots each
/// screen twice from identical stored state and compares the board it actually
/// paints.

/// Every tile colour the screen paints, in layout order. Both games draw their
/// board cells as an `AnimatedContainer` with a `BoxDecoration`, so this is the
/// generated board as the player sees it.
List<int> boardColors(WidgetTester tester) {
  final colors = <int>[];
  for (final w in tester.widgetList<AnimatedContainer>(
    find.byType(AnimatedContainer),
  )) {
    final d = w.decoration;
    if (d is BoxDecoration && d.color != null) {
      colors.add(d.color!.toARGB32());
    }
  }
  return colors;
}

Future<List<int>> bootAndRead(
  WidgetTester tester,
  Widget Function() build,
  Map<String, Object> prefs,
) async {
  SharedPreferences.setMockInitialValues(prefs);
  await tester.pumpWidget(MaterialApp(home: build()));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
  final colors = boardColors(tester);
  // Replacing the tree disposes the screen, which cancels its timers.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
  return colors;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  // Straddles the old unseeded cut-offs: below 30, between 30 and 90, above 90.
  const levels = [0, 4, 12, 45, 95];

  group('Odd Color Out draws a seeded board', () {
    for (final level in levels) {
      testWidgets('level ${level + 1} is identical on a second run',
          (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final first = await bootAndRead(
          tester,
          () => const OddColorOutScreen(),
          {'level_oddcolor': level, 'hints_oddcolor': 3},
        );
        final second = await bootAndRead(
          tester,
          () => const OddColorOutScreen(),
          {'level_oddcolor': level, 'hints_oddcolor': 3},
        );

        expect(first, isNotEmpty,
            reason: 'no board was painted at level ${level + 1}');
        expect(second, first,
            reason: 'level ${level + 1} drew a different board the second '
                'time -- the generator is not seeded');
      });
    }

    testWidgets('neighbouring levels do not draw the same board',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final a = await bootAndRead(tester, () => const OddColorOutScreen(),
          {'level_oddcolor': 45, 'hints_oddcolor': 3});
      final b = await bootAndRead(tester, () => const OddColorOutScreen(),
          {'level_oddcolor': 46, 'hints_oddcolor': 3});

      expect(a, isNot(equals(b)));
    });
  });

  group('Spectrum draws a seeded board', () {
    for (final level in levels) {
      testWidgets('level ${level + 1} is identical on a second run',
          (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final first = await bootAndRead(
          tester,
          () => const SpectrumScreen(),
          {'level_hue': level, 'hints_hue': 3},
        );
        final second = await bootAndRead(
          tester,
          () => const SpectrumScreen(),
          {'level_hue': level, 'hints_hue': 3},
        );

        expect(first, isNotEmpty,
            reason: 'no board was painted at level ${level + 1}');
        expect(second, first,
            reason: 'level ${level + 1} drew a different board the second '
                'time -- the generator is not seeded');
      });
    }

    testWidgets('neighbouring levels do not draw the same board',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final a = await bootAndRead(
          tester, () => const SpectrumScreen(), {'level_hue': 12, 'hints_hue': 3});
      final b = await bootAndRead(
          tester, () => const SpectrumScreen(), {'level_hue': 13, 'hints_hue': 3});

      expect(a, isNot(equals(b)));
    });
  });
}
