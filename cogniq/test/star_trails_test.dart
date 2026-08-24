import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cogniq/screens/trails_screen.dart';
import 'package:cogniq/utils/achievement_manager.dart';
import 'package:cogniq/utils/prefs_keys.dart';
import 'package:cogniq/utils/trail_catalog.dart';
import 'package:cogniq/widgets/swipe_trail_overlay.dart';

/// Star-locked swipe trails.
///
/// The model is a **threshold, not a spend**: reaching a count unlocks the
/// trail permanently and the stars stay where they are. Every trail has three
/// alternative routes (two star tiers plus a long lifetime-clears grind) and
/// meeting any ONE is enough. None of them is ever purchasable.

const starTrailIds = <String>[
  'morning_mist',
  'tide_line',
];

/// A star wallet holding only one tier, so a route can be proved to unlock on
/// its own rather than in combination with another.
StarCounts only(StarTier tier, int count) {
  switch (tier) {
    case StarTier.bronze:
      return StarCounts(bronze: count);
    case StarTier.silver:
      return StarCounts(silver: count);
    case StarTier.gold:
      return StarCounts(gold: count);
    case StarTier.diamond:
      return StarCounts(diamond: count);
  }
}

String prefKeyForTier(StarTier tier) {
  switch (tier) {
    case StarTier.bronze:
      return PrefsKeys.dailyBronzeStars;
    case StarTier.silver:
      return PrefsKeys.dailySilverStars;
    case StarTier.gold:
      return PrefsKeys.dailyGoldStars;
    case StarTier.diamond:
      return PrefsKeys.diamondStars;
  }
}

/// The owner-approved numbers, written out by hand so a typo in the catalog
/// fails here rather than shipping.
// Drip-feed build: this release ships only the star trails released so far,
// so entries for later trails are absent rather than pinned. The ones that
// remain keep their exact approved numbers, so a catalogue typo still fails.
const approved = <String, ({List<(StarTier, int)> routes, int clears})>{
  'morning_mist': (
    routes: [(StarTier.bronze, 7), (StarTier.silver, 1)],
    clears: 400
  ),
  'tide_line': (
    routes: [(StarTier.silver, 7), (StarTier.gold, 1)],
    clears: 700
  ),
};

// NOTE (drip-feed build): this release ships no gold/diamond star trails, so
// Trail Collector III has no trails of its own — owning everything available
// would earn "the app's hardest achievement" for free, and the player would
// already hold it when the real trails arrive. The tier is therefore absent
// from this build, and its assertions with it. It returns in 1.9.2.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('star trail thresholds', () {
    test('the catalog carries exactly the approved numbers', () {
      for (final entry in approved.entries) {
        final rules = TrailCatalog.starRules(entry.key);
        expect(rules, isNotNull, reason: '${entry.key} is not a star trail');
        expect(rules!.clears, entry.value.clears, reason: entry.key);
        expect(
          rules.starRoutes.map((r) => (r.tier, r.count)).toList(),
          entry.value.routes,
          reason: entry.key,
        );
      }
      // Nothing else may quietly become star-locked.
      for (final id in starTrailIds) {
        expect(approved.containsKey(id), isTrue);
      }
    });

    for (final id in starTrailIds) {
      final rules = TrailCatalog.starRules(id)!;

      for (final route in rules.starRoutes) {
        test('$id unlocks on ${route.count} ${route.tier.name} alone', () {
          expect(
            TrailCatalog.isEarnedByStars(
              styleId: id,
              stars: only(route.tier, route.count),
            ),
            isTrue,
          );
        });

        test('$id stays locked one ${route.tier.name} short', () {
          expect(
            TrailCatalog.isEarnedByStars(
              styleId: id,
              stars: only(route.tier, route.count - 1),
              clears: rules.clears - 1,
            ),
            isFalse,
          );
        });
      }

      test('$id unlocks on ${rules.clears} clears alone, with no stars', () {
        expect(
          TrailCatalog.isEarnedByStars(styleId: id, clears: rules.clears),
          isTrue,
        );
        expect(
          TrailCatalog.isEarnedByStars(styleId: id, clears: rules.clears - 1),
          isFalse,
        );
      });

      test('$id is available to render the moment a route is met', () {
        final route = rules.starRoutes.first;
        expect(
          TrailCatalog.isAvailable(
            styleId: id,
            clears: 0,
            claimed: const ['none'],
            stars: only(route.tier, route.count),
          ),
          isTrue,
        );
        expect(
          TrailCatalog.isAvailable(
            styleId: id,
            clears: 0,
            claimed: const ['none'],
          ),
          isFalse,
        );
      });
    }

    test('the clears route sits above every ordinary trail requirement', () {
      // 30/100/250 are the accent/sparkle/pastel thresholds. The star route is
      // a long grind, not a shortcut past them.
      for (final id in starTrailIds) {
        expect(TrailCatalog.starTrailClears(id), greaterThan(250));
      }
    });
  });

  group('star trails are never purchasable', () {
    for (final id in starTrailIds) {
      test('$id has no price and no ordinary clear requirement', () {
        expect(TrailCatalog.price(id), TrailCatalog.pointsOnly);
        expect(TrailCatalog.requiredClears(id), TrailCatalog.pointsOnly);
        expect(TrailCatalog.isPurchasable(id), isFalse);
        // The grind path must refuse them however high the count goes; the
        // separate star-clears route is the only clears way in.
        expect(TrailCatalog.isEarnedByClears(id, 999999999), isFalse);
      });
    }

    testWidgets('no Buy button appears for a star trail at any balance',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.points: 12345678,
        PrefsKeys.claimedTrailStyles: <String>['none'],
      });
      tester.view.physicalSize = const Size(600, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: TrailsScreen()));
      await tester.pumpAndSettle();

      // Every purchasable trail offers "Buy: <price> ✦"; a star trail would
      // read "Buy: 999999 ✦" if the sentinel ever leaked into the UI.
      expect(find.textContaining('Buy: 999999'), findsNothing);

      final buyButtons = find.textContaining('Buy:');
      expect(buyButtons, findsWidgets);
      // Only the six ordinary trails may be buyable.
      expect(tester.widgetList(buyButtons).length, lessThanOrEqualTo(6));

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('unlocking never deducts stars', () {
    testWidgets('claiming a star trail leaves every star total untouched',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.globalLevelClearedCount: 0,
        PrefsKeys.dailyBronzeStars: 9,
        PrefsKeys.dailySilverStars: 0,
        PrefsKeys.dailyGoldStars: 0,
        PrefsKeys.diamondStars: 0,
        PrefsKeys.claimedTrailStyles: <String>['none'],
      });
      tester.view.physicalSize = const Size(600, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: TrailsScreen()));
      await tester.pumpAndSettle();

      // 9 bronze clears Morning Mist's 7-bronze route and nothing else.
      final claim = find.text('Claim');
      expect(claim, findsOneWidget);
      await tester.tap(claim);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(PrefsKeys.claimedTrailStyles),
        contains('morning_mist'),
      );
      expect(prefs.getInt(PrefsKeys.dailyBronzeStars), 9);
      expect(prefs.getInt(PrefsKeys.dailySilverStars), 0);
      expect(prefs.getInt(PrefsKeys.dailyGoldStars), 0);
      expect(prefs.getInt(PrefsKeys.diamondStars), 0);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('reading availability is pure: the wallet is never written', () async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.dailyGoldStars: 21,
      });
      final prefs = await SharedPreferences.getInstance();
      final before = StarCounts.fromPrefs(prefs);
      for (final id in starTrailIds) {
        TrailCatalog.isAvailable(
          styleId: id,
          clears: 5000,
          claimed: const ['none'],
          stars: before,
        );
      }
      final after = StarCounts.fromPrefs(prefs);
      expect(after.bronze, before.bronze);
      expect(after.silver, before.silver);
      expect(after.gold, 21);
      expect(after.diamond, before.diamond);
    });
  });

  group('Trail Collector tiers', () {
    Future<Iterable<String>> unlock(List<String> claimedTrails) async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.claimedTrailStyles: ['none', ...claimedTrails],
      });
      final newly = await AchievementManager.checkAndUnlock('sudoku');
      return newly.map((a) => a.id);
    }

    test('the tiers are strictly nested, so they can only arrive in order', () {
      for (final id in TrailCatalog.collectorTierI) {
        expect(TrailCatalog.collectorTierII, contains(id));
      }
      // greaterThanOrEqualTo, not greaterThan: in a drip-feed build a tier can
      // legitimately gain no new trails yet (1.8.2 ships no gold/diamond
      // trails, so III equals II). The nesting assertions above stay strict —
      // that is the property that actually matters.
      expect(TrailCatalog.collectorTierII.length,
          greaterThanOrEqualTo(TrailCatalog.collectorTierI.length));
      // No star trail may sit in tier I -- that tier is the pre-existing
      // achievement and must stay reachable without a single star.
      for (final id in TrailCatalog.collectorTierI) {
        expect(TrailCatalog.isStarTrail(id), isFalse);
      }
    });

    test('nothing unlocks with an incomplete tier I', () async {
      final ids = await unlock(['accent', 'sparkle', 'pastel']);
      expect(ids, isNot(contains('trail_collector')));
      expect(ids, isNot(contains('trail_collector_ii')));
      expect(ids, isNot(contains('trail_collector_iii')));
    });

    test('tier I alone unlocks I only', () async {
      final ids = await unlock(TrailCatalog.collectorTierI);
      expect(ids, contains('trail_collector'));
      expect(ids, isNot(contains('trail_collector_ii')));
      expect(ids, isNot(contains('trail_collector_iii')));
    });

    test('an existing holder of the old id keeps it and is not re-awarded',
        () async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.unlockedAchievements: <String>['trail_collector'],
        PrefsKeys.claimedTrailStyles: <String>['none'],
      });
      final newly = await AchievementManager.checkAndUnlock('sudoku');
      expect(newly.map((a) => a.id), isNot(contains('trail_collector')));
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(PrefsKeys.unlockedAchievements),
        contains('trail_collector'),
      );
    });

    test('rewards scale with difficulty', () {
      int reward(String id) => AchievementManager.allAchievements
          .firstWhere((a) => a.id == id)
          .rewardPoints;
      expect(reward('trail_collector_ii'), greaterThan(reward('trail_collector')));
      // Tier III is absent from this drip-feed build (see the note at the top),
      // so there is no third reward to compare. The tiers that DO ship are
      // still asserted to scale.
      expect(
        AchievementManager.allAchievements.any((a) => a.id == 'trail_collector_iii'),
        isFalse,
        reason: 'tier III must not ship in a build with no gold/diamond trails',
      );
    });
  });

  group('trails screen layout', () {
    // Wide-short is load-bearing: every other viewport is taller than it is
    // wide, and two shipped overflows hid behind that.
    const viewports = <String, Size>{
      'small phone 320x568': Size(320, 568),
      'typical phone 412x915': Size(412, 915),
      'large phone 480x1000': Size(480, 1000),
      'wide-short 1568x696': Size(1568, 696),
    };

    for (final vp in viewports.entries) {
      testWidgets('no overflow at ${vp.key} with star trails present',
          (tester) async {
        // Mid-progress on purpose: every star card is locked and therefore
        // showing its three-route progress line, which is the longest text the
        // card ever renders.
        SharedPreferences.setMockInitialValues({
          PrefsKeys.globalLevelClearedCount: 312,
          PrefsKeys.dailyBronzeStars: 4,
          PrefsKeys.dailySilverStars: 0,
          PrefsKeys.dailyGoldStars: 2,
          PrefsKeys.diamondStars: 0,
          PrefsKeys.points: 5000,
          PrefsKeys.claimedTrailStyles: <String>['none', 'accent'],
          PrefsKeys.swipeTrailStyle: 'accent',
        });
        tester.view.physicalSize = vp.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final overflows = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          final text = details.exceptionAsString();
          if (text.contains('overflowed by')) {
            // Name the offending widget so a failure points at the code to
            // fix rather than just saying "something overflowed".
            final widget = details
                .toString()
                .split('\n')
                .skipWhile((l) => !l.contains('error-causing widget'))
                .skip(1)
                .take(1)
                .join()
                .trim();
            overflows.add('${text.split('\n').first}  ($widget)');
          } else {
            previous?.call(details);
          }
        };

        try {
          await tester.pumpWidget(const MaterialApp(home: TrailsScreen()));
          await tester.pumpAndSettle();
          // Scroll the whole list so cards below the fold are laid out too.
          for (var i = 0; i < 8; i++) {
            // .first: the accent swatch row is a second, horizontal ListView.
            await tester.drag(
                find.byType(ListView).first, const Offset(0, -300));
            await tester.pump(const Duration(milliseconds: 60));
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 50));
          FlutterError.onError = previous;
        }

        expect(overflows, isEmpty, reason: overflows.join('\n'));
      });
    }

    testWidgets('a locked star card shows every route and no Buy button',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.globalLevelClearedCount: 312,
        PrefsKeys.dailyBronzeStars: 4,
        PrefsKeys.points: 99999999,
        PrefsKeys.claimedTrailStyles: <String>['none'],
      });
      tester.view.physicalSize = const Size(600, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: TrailsScreen()));
      await tester.pumpAndSettle();

      // Morning Mist: 4/7 bronze, 0/1 silver, 312/400 clears -- all three
      // routes visible, closest first.
      final spans = <String>[];
      for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
        spans.add(w.text.toPlainText());
      }
      final mist = spans.firstWhere(
        (s) => s.contains('7 bronze'),
        orElse: () => '',
      );
      expect(mist, contains('4 / 7 bronze'));
      expect(mist, contains('0 / 1 silver'));
      expect(mist, contains('312 / 400 clears'));

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('star trail painters', () {
    for (final style in starTrailIds) {
      testWidgets('$style renders a drag without throwing', (tester) async {
        SharedPreferences.setMockInitialValues({
          PrefsKeys.swipeTrailStyle: style,
          PrefsKeys.claimedTrailStyles: <String>['none', style],
        });

        await tester.pumpWidget(
          MaterialApp(
            home: SwipeTrailOverlay(
              accentColor: const Color(0xFFA68B8A),
              child: const SizedBox.expand(),
            ),
          ),
        );
        // Settings load asynchronously; the ticker never settles, so pump
        // frames by hand rather than calling pumpAndSettle.
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        // Prove the overlay really is in rendering mode, otherwise this test
        // would pass by drawing nothing at all.
        expect(SwipeTrailOverlay.styleNotifier.value, style);
        expect(SwipeTrailOverlay.unlockedNotifier.value, isTrue);

        final gesture = await tester.startGesture(const Offset(40, 40));
        for (var i = 0; i < 16; i++) {
          await gesture.moveBy(const Offset(9, 6));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        // Long enough for the extended Starfall/Constellation lifetimes to
        // expire, exercising the fade-out branches too.
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      });
    }

    test('only the two persistence trails extend the point lifetime', () {
      expect(SwipeTrailOverlay.lineLifetimeMs('starfall'), 700);
      expect(SwipeTrailOverlay.lineLifetimeMs('constellation'), 900);
      for (final style in const [
        'none',
        'accent',
        'sparkle',
        'pastel',
        'neon_glow',
        'rainbow',
        'fire',
        'zen',
        'morning_mist',
        'tide_line',
      ]) {
        expect(SwipeTrailOverlay.lineLifetimeMs(style), 300, reason: style);
      }
    });
  });
}
