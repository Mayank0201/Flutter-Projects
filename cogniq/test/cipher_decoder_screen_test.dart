import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cogniq/screens/games/cipher_decoder/cipher_decoder_screen.dart';
import 'package:cogniq/screens/games/cipher_decoder/cipher_decoder_logic.dart';
import 'package:cogniq/utils/rotation_engine.dart';

/// End-to-end proof that a Cipher Decoder level can actually be *won*.
///
/// `test/cipher_decoder_logic_test.dart` proves every generated board has a
/// solution. This file proves the screen accepts it: it turns each word's dial
/// to the answer the logic reports and expects the clear overlay. The stashed
/// build would have failed this at level 6 and every level after it — 73.7% and
/// then 100% of its boards had no solution at all — which is exactly the class
/// of defect a green logic suite alone can miss.
///
/// Note the deliberate `pump` rather than `pumpAndSettle` after the win:
/// `AutoNextCountdown` runs to completion under pumpAndSettle and advances to
/// the next level before the assertion can see the overlay.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  // One level per band of the compressed ladder, plus one past the cap where
  // modifiers are live. Re-pinned from [0, 8, 20, 32, 60], which sampled the
  // 45-level draft's bands; those indices now land in different bands.
  //  0  global, 2 words          12  hidden rule backwards, 5 words
  //  4  stated rule, 3 words     15  free shifts, 3 words
  //  8  hidden rule, 4 words     18  free shifts, 4 words
  // 28  past the cap: free shifts, 3 words, with modifiers active
  for (final level in [0, 4, 8, 12, 15, 18, 28]) {
    testWidgets('level $level can be won by turning the dials', (tester) async {
      SharedPreferences.setMockInitialValues({
        'level_cipherdecoder': level,
        'hints_cipherdecoder': 3,
      });
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: CipherDecoderScreen()));
      await tester.pumpAndSettle();

      final board = CipherLogic.generate(
          level, RotationEngine.getDeterminism('cipherdecoder', level));
      final want = board.solutionDials;

      expect(find.text('Level ${level + 1} Cleared!'), findsNothing);

      for (var w = 0; w < board.wordCount; w++) {
        // Shorter way round, so the `quota` budget is never the thing that
        // fails the test.
        final forward = want[w] <= 13;
        final target = find.byTooltip(
            'Turn word ${w + 1} ${forward ? 'forward' : 'back'}');
        expect(target, findsOneWidget, reason: 'word ${w + 1} has no dial');
        final clicks = forward ? want[w] : 26 - want[w];
        for (var i = 0; i < clicks; i++) {
          await tester.tap(target);
          await tester.pump();
        }
      }
      // NOT pumpAndSettle: AutoNextCountdown would run to completion and jump
      // to the next level before the assertion.
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Level ${level + 1} Cleared!'), findsOneWidget);
      expect(find.text(board.plainPhrase), findsOneWidget);
    });
  }

  testWidgets('reset returns every dial to zero', (tester) async {
    SharedPreferences.setMockInitialValues({
      'level_cipherdecoder': 20,
      'hints_cipherdecoder': 3,
    });
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: CipherDecoderScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Turn word 1 forward'));
    await tester.pump();
    expect(find.text('01'), findsOneWidget);

    await tester.tap(find.text('Reset dials'));
    await tester.pumpAndSettle();
    expect(find.text('01'), findsNothing);
  });

  testWidgets('a hint sets one dial and spends exactly one hint',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'level_cipherdecoder': 20,
      'hints_cipherdecoder': 3,
    });
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: CipherDecoderScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Hint'));
    await tester.pumpAndSettle();

    final board = CipherLogic.generate(
        20, RotationEngine.getDeterminism('cipherdecoder', 20));
    final want = board.solutionDials[0].toString().padLeft(2, '0');
    expect(find.text(want), findsWidgets);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('hints_cipherdecoder'), 2);
  });
}
