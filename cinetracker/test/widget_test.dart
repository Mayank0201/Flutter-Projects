import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cinetracker/features/home/widgets/empty_state.dart';
import 'package:cinetracker/features/home/widgets/star_rating.dart';

// this file was empty since the first commit, which made `flutter test` fail.
// these cover the two widgets every tv screen leans on and need no network.

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('StarRating', () {
    testWidgets('draws full, half and empty stars for 3.5', (tester) async {
      await tester.pumpWidget(_wrap(const StarRating(value: 3.5)));

      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.star_half_rounded), findsOneWidget);
      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
    });

    testWidgets('draws five empty stars when unrated', (tester) async {
      await tester.pumpWidget(_wrap(const StarRating(value: 0)));

      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(5));
    });

    testWidgets('ignores taps with no onChanged', (tester) async {
      await tester.pumpWidget(_wrap(const StarRating(value: 2)));
      await tester.tap(find.byType(StarRating));
      await tester.pump();

      // still 2, since a read only row must not become an input
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
    });

    testWidgets('reports a half step when tapped', (tester) async {
      double? picked;
      await tester.pumpWidget(_wrap(
        StarRating(value: 0, size: 40, onChanged: (v) => picked = v),
      ));

      // 40px a star, so 60px in is the back half of the second star
      final origin = tester.getTopLeft(find.byType(StarRating));
      await tester.tapAt(origin + const Offset(60, 20));
      await tester.pump();

      expect(picked, 1.5);
    });
  });

  group('EmptyState', () {
    testWidgets('shows the title and hint', (tester) async {
      await tester.pumpWidget(_wrap(const EmptyState(
        icon: Icons.tv_off_rounded,
        title: 'Nothing here',
        hint: 'Try another genre',
      )));

      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.text('Try another genre'), findsOneWidget);
    });

    testWidgets('fires the action button', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load',
        actionLabel: 'Try again',
        onAction: () => tapped++,
      )));

      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(tapped, 1);
    });

    testWidgets('hides the button with no action', (tester) async {
      await tester.pumpWidget(_wrap(const EmptyState(
        icon: Icons.search_rounded,
        title: 'Find a show',
      )));

      expect(find.byType(OutlinedButton), findsNothing);
    });
  });
}
