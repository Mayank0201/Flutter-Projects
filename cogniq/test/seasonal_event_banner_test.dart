import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cogniq/models/game_info.dart';
import 'package:cogniq/utils/seasonal_event_manager.dart';
import 'package:cogniq/widgets/seasonal_event_banner.dart';
import 'package:cogniq/widgets/seasonal_event_sheet.dart';

/// Widget coverage for the S3 seasonal banner.
///
/// **Why this file has to exist.** The shipped calendar runs on a quarterly
/// rhythm — 18 Dec, 18 Mar, 18 Jun, 18 Sep — which is 64 live days a year out
/// of 365. Every other tool we use to catch layout bugs is a browser sweep done
/// on the day of the build, and the build days are almost never in a window, so
/// for ten months of the year a browser sweep renders `SizedBox.shrink()` and
/// reports "fine". A broken banner would then appear, for the first time in
/// front of real users, on the morning an event opens.
///
/// The banner takes an injectable `now`, so this is the one place any of the
/// four layouts is ever actually looked at. Each event has a different name and
/// tagline length, so all four are swept, not just winter. Treat a failure here
/// as a shipping bug, not a flaky test.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Mid-window, plus the day either side of the year boundary.
  final midWindow = DateTime(2026, 12, 22);
  final newYearEve = DateTime(2026, 12, 31);
  final newYearDay = DateTime(2027, 1, 1);

  Widget host(Widget child, {Brightness brightness = Brightness.light}) =>
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(body: ListView(children: [child])),
      );

  // Every shipped event, with a date inside its window. The name is pinned
  // here because it is the headline the player reads; the tagline is compared
  // against the definition so the banner is proved to render *this* event's
  // copy rather than whichever event happens to be first in the list.
  //
  // Names and taglines differ in length event to event, so the layout sweep
  // below genuinely measures four different banners.
  final events = <_EventCase>[
    _EventCase('winter_lights', 'Winter Lights', DateTime(2026, 12, 22)),
    _EventCase('spring_thaw', 'Spring Thaw', DateTime(2026, 3, 25)),
    _EventCase('summer_light', 'Long Light', DateTime(2026, 6, 25)),
    _EventCase('autumn_harvest', 'Gathering In', DateTime(2026, 9, 25)),
  ];

  SeasonalEventDefinition definitionOf(String id) => SeasonalEventManager
      .kSeasonalEvents
      .firstWhere((d) => d.id == id);

  /// Collects RenderFlex overflow errors for the rest of the current test.
  ///
  /// Anything that is not an overflow still reaches the previous handler, so a
  /// real exception is never swallowed by this.
  List<String> captureOverflows() {
    final overflows = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed')) {
        overflows.add(text.split('\n').first);
      } else {
        previous?.call(details);
      }
    };
    addTearDown(() => FlutterError.onError = previous);
    return overflows;
  }

  group('visibility', () {
    // One date from each of the four quiet stretches between events. Sampling
    // only 22 August would still pass if a window silently swallowed February.
    final quietDates = <DateTime>[
      DateTime(2026, 2, 10), // between winter and spring
      DateTime(2026, 5, 10), // between spring and summer
      DateTime(2026, 8, 22), // between summer and autumn
      DateTime(2026, 11, 10), // between autumn and winter
    ];

    for (final quiet in quietDates) {
      testWidgets('renders nothing on $quiet, outside every event window',
          (tester) async {
        await tester.pumpWidget(host(SeasonalEventBanner(now: quiet)));
        await tester.pumpAndSettle();

        // The banner collapses to SizedBox.shrink(), which a ListView culls
        // entirely — so the widget itself is legitimately absent from the tree.
        // What matters is that no event chrome renders and nothing takes height.
        expect(find.byType(SeasonalEventBanner), findsNothing);
        for (final event in events) {
          expect(find.text(event.name), findsNothing,
              reason: '${event.id} must not appear on $quiet');
        }
      });
    }

    for (final event in events) {
      testWidgets('renders ${event.id} mid-window, and only it', (tester) async {
        await tester.pumpWidget(host(SeasonalEventBanner(now: event.midWindow)));
        await tester.pumpAndSettle();

        expect(find.text(event.name), findsOneWidget,
            reason: 'the banner should headline "${event.name}" on '
                '${event.midWindow}');
        expect(find.text(definitionOf(event.id).tagline), findsOneWidget,
            reason: 'the banner must show this event\'s tagline, not another\'s');
        expect(tester.getSize(find.byType(SeasonalEventBanner)).height,
            greaterThan(0));

        // No other event's headline leaks onto the screen.
        for (final other in events) {
          if (other.id == event.id || other.name == event.name) continue;
          expect(find.text(other.name), findsNothing,
              reason: '${other.id} rendered during ${event.id}');
        }
      });
    }

    testWidgets('survives the 31 Dec -> 1 Jan boundary', (tester) async {
      for (final day in [newYearEve, newYearDay]) {
        await tester.pumpWidget(host(SeasonalEventBanner(now: day)));
        await tester.pumpAndSettle();
        expect(find.text('Winter Lights'), findsOneWidget,
            reason: 'the event should still be running on $day');
      }
    });
  });

  group('no layout overflow in any event window', () {
    // The sizes the rest of the suite uses, plus the narrowest phone we support.
    const sizes = <String, Size>{
      'small phone': Size(320, 568),
      'typical phone': Size(412, 915),
      'large phone': Size(480, 1000),
      'wide-short (landscape / tablet / split screen)': Size(1568, 696),
    };

    for (final event in events) {
      sizes.forEach((label, size) {
        testWidgets('${event.id}: no overflow at $label', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final overflows = captureOverflows();

          await tester
              .pumpWidget(host(SeasonalEventBanner(now: event.midWindow)));
          await tester.pumpAndSettle();

          // A banner that never rendered cannot overflow, and would make this
          // whole sweep vacuous. Prove there was something to measure first.
          expect(find.text(event.name), findsOneWidget,
              reason: '${event.id} did not render at $label, so nothing was '
                  'actually measured');
          expect(overflows, isEmpty,
              reason: '${event.id} at $label: ${overflows.join('; ')}');
        });
      });
    }

    for (final event in events) {
      testWidgets('${event.id}: no overflow in dark theme', (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final overflows = captureOverflows();

        await tester.pumpWidget(host(
          SeasonalEventBanner(now: event.midWindow),
          brightness: Brightness.dark,
        ));
        await tester.pumpAndSettle();

        expect(find.text(event.name), findsOneWidget, reason: event.id);
        expect(overflows, isEmpty,
            reason: '${event.id}: ${overflows.join('; ')}');
      });
    }

    testWidgets('the claim state fits too, on the narrowest phone',
        (tester) async {
      // The one banner layout the date-driven tests never reach: badge earned,
      // Claim chip present instead of the dismiss button. It is the widest row
      // the banner can produce.
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final overflows = captureOverflows();

      for (final event in events) {
        SharedPreferences.setMockInitialValues({});
        final required = definitionOf(event.id).badge.requiredProgress;
        for (var i = 0; i < required; i++) {
          await SeasonalEventManager.recordProgress(now: event.midWindow);
        }

        await tester.pumpWidget(host(
          SeasonalEventBanner(
            key: ValueKey(event.id),
            now: event.midWindow,
            onClaim: () {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Claim'), findsOneWidget, reason: event.id);
        expect(overflows, isEmpty,
            reason: '${event.id} claim state: ${overflows.join('; ')}');
      }
    });
  });

  group('dismissal', () {
    testWidgets('dismissal hides the banner and survives a rebuild',
        (tester) async {
      await tester.pumpWidget(host(SeasonalEventBanner(now: midWindow)));
      await tester.pumpAndSettle();
      expect(find.text('Winter Lights'), findsOneWidget);

      final dismiss = find.byIcon(Icons.close_rounded);
      expect(dismiss, findsOneWidget,
          reason: 'a banner the player cannot dismiss is a banner they resent');
      await tester.tap(dismiss);
      await tester.pumpAndSettle();
      expect(find.text('Winter Lights'), findsNothing);

      // A fresh widget on the same day must stay dismissed.
      await tester.pumpWidget(host(SeasonalEventBanner(now: midWindow)));
      await tester.pumpAndSettle();
      expect(find.text('Winter Lights'), findsNothing);
    });

    testWidgets('dismissal is stored per occurrence, not per event',
        (tester) async {
      await tester.pumpWidget(host(SeasonalEventBanner(now: midWindow)));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Same event, next year's occurrence. A distinct key is required: the
      // banner reads the date once in initState, so pumping a new widget at the
      // same position reuses the State and would never re-read. That is fine in
      // the app (the home tab is rebuilt on navigation) but it means this test
      // must force a fresh State or it tests nothing.
      await tester.pumpWidget(host(
        SeasonalEventBanner(
          key: const ValueKey('2027'),
          now: DateTime(2027, 12, 22),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Winter Lights'), findsOneWidget,
          reason: 'a player who dismissed the 2026 event must still see 2027');
    });

    testWidgets('dismissing one event does not dismiss any other',
        (tester) async {
      // Dismissing spring must not take summer, autumn and winter with it.
      final spring = events.firstWhere((e) => e.id == 'spring_thaw');
      await tester.pumpWidget(host(
        SeasonalEventBanner(
          key: const ValueKey('spring'),
          now: spring.midWindow,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text(spring.name), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text(spring.name), findsNothing);

      for (final other in events) {
        if (other.id == spring.id) continue;
        // A distinct key forces a fresh State, which is what re-reads the date.
        await tester.pumpWidget(host(
          SeasonalEventBanner(key: ValueKey(other.id), now: other.midWindow),
        ));
        await tester.pumpAndSettle();
        expect(find.text(other.name), findsOneWidget,
            reason: 'dismissing spring also hid ${other.id}');
      }
    });
  });

  group('what it says is what it does', () {
    testWidgets('progress shown matches what the manager recorded',
        (tester) async {
      SeasonalEventManager.clock = () => midWindow;
      addTearDown(() => SeasonalEventManager.clock = DateTime.now);

      await SeasonalEventManager.recordProgress();
      await SeasonalEventManager.recordProgress();

      await tester.pumpWidget(host(SeasonalEventBanner(now: midWindow)));
      await tester.pumpAndSettle();

      // remember.md rule 8: never announce what you do not apply. The count on
      // the banner has to be the count in storage.
      final stored = await SeasonalEventManager.progressFor();
      expect(stored, 2);
      expect(find.textContaining('2'), findsWidgets,
          reason: 'the banner should surface the 2 levels already cleared');
    });

    for (final event in events) {
      testWidgets('every game ${event.id} names is live and routable',
          (tester) async {
        final occurrence =
            SeasonalEventManager.activeEvent(now: event.midWindow);
        expect(occurrence, isNotNull);
        expect(occurrence!.definition.id, event.id);

        final definition = occurrence.definition;
        expect(definition.featuredGameIds, isNotEmpty,
            reason: 'an event that features nothing is a dead banner');

        // Checked against the *declared* ids: asserting isStashed == false on
        // liveFeaturedGames' output can never fail, because that filter drops
        // stashed games on the way out. A stashed id would open an
        // unregistered route and crash the app.
        for (final id in definition.featuredGameIds) {
          final matches = kAllGames.where((g) => g.id == id);
          expect(matches, hasLength(1),
              reason: '${event.id} features "$id", which is not in kAllGames');
          expect(matches.first.isStashed, isFalse,
              reason: '${event.id} features stashed game "$id"');
          expect(matches.first.routeName, isNotEmpty, reason: id);
        }
        expect(
          SeasonalEventManager.liveFeaturedGames(definition)
              .map((g) => g.id)
              .toList(),
          definition.featuredGameIds,
          reason: '${event.id} loses a featured game to the live filter',
        );
      });
    }
  });

  // ---------------------------------------------------------------------------
  // 2.2 — the night trail on the banner.
  //
  // Same December problem as everything above: none of this is visible outside
  // 18 Dec – 5 Jan, so these tests are the only eyes it will ever get.
  // ---------------------------------------------------------------------------

  group('the night trail', () {
    /// Day [index] (1-based) of the 2026 winter occurrence, which starts on
    /// 18 December 2026 and runs into January.
    DateTime winterDay(int index) => DateTime(2026, 12, 17 + index, 12);

    Future<void> play(int day) =>
        SeasonalEventManager.recordProgress(now: winterDay(day));

    testWidgets('an untouched event shows an empty trail and the first stage',
        (tester) async {
      await tester.pumpWidget(host(SeasonalEventBanner(now: winterDay(1))));
      await tester.pumpAndSettle();

      expect(find.text('0 of 19 nights lit — next: First Light'), findsOneWidget,
          reason: 'day one, nothing played yet');
      expect(find.byType(SeasonalNightTrail), findsOneWidget);
    });

    testWidgets('the label counts the nights the manager actually stored',
        (tester) async {
      // remember.md §8. The number on the banner is compared against storage,
      // not against itself.
      for (final day in <int>[1, 2, 4]) {
        await play(day);
      }
      final stored = await SeasonalEventManager.litNights(now: winterDay(5));
      expect(stored, {1, 2, 4}, reason: 'the fixture itself');

      await tester.pumpWidget(host(SeasonalEventBanner(now: winterDay(5))));
      await tester.pumpAndSettle();

      expect(find.text('${stored.length} of 19 nights lit — next: Five Nights'),
          findsOneWidget);

      // ...and the trail widget is handed the same set, not a recount.
      final trail = tester.widget<SeasonalNightTrail>(
          find.byType(SeasonalNightTrail));
      expect(trail.litNights, stored);
      expect(trail.totalNights, 19);
      expect(trail.tonight, 5);
    });

    testWidgets('the ladder advances as nights are lit', (tester) async {
      const expected = <int, String>{
        1: '1 of 19 nights lit — next: Five Nights',
        5: '5 of 19 nights lit — next: Twelve Nights',
        12: '12 of 19 nights lit — next: The Whole Winter',
        19: '19 of 19 nights lit — The Whole Winter',
      };

      for (var day = 1; day <= 19; day++) {
        await play(day);
        final label = expected[day];
        if (label == null) continue;

        await tester.pumpWidget(host(
          SeasonalEventBanner(key: ValueKey('day$day'), now: winterDay(day)),
        ));
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget, reason: 'on day $day');
      }
    });

    testWidgets('the trail carries across 31 December', (tester) async {
      await play(14); // 31 December
      await play(15); // 1 January
      await tester.pumpWidget(host(SeasonalEventBanner(now: DateTime(2027, 1, 2))));
      await tester.pumpAndSettle();
      expect(find.text('2 of 19 nights lit — next: Five Nights'), findsOneWidget,
          reason: 'the year rolling over must not restart the trail');
    });

    testWidgets('a full trail plus the claim chip still fits a small phone',
        (tester) async {
      // The tallest, busiest banner the app can produce: nineteen nights lit,
      // badge earned and unclaimed, six featured games.
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final overflows = captureOverflows();
      for (var day = 1; day <= 19; day++) {
        await play(day);
      }

      await tester.pumpWidget(host(
        SeasonalEventBanner(now: winterDay(19), onClaim: () {}),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Claim'), findsOneWidget);
      expect(find.text('19 of 19 nights lit — The Whole Winter'), findsOneWidget);
      expect(overflows, isEmpty, reason: overflows.join('; '));
    });

    for (final event in events) {
      testWidgets('${event.id}: the trail is as long as the window',
          (tester) async {
        await tester.pumpWidget(host(
          SeasonalEventBanner(key: ValueKey(event.id), now: event.midWindow),
        ));
        await tester.pumpAndSettle();

        final trail = tester.widget<SeasonalNightTrail>(
            find.byType(SeasonalNightTrail));
        expect(trail.totalNights, definitionOf(event.id).window.nominalLengthDays,
            reason: '${event.id} draws a trail that is not its own length');
      });
    }
  });

  // ---------------------------------------------------------------------------
  // 2.2 — featured games. Until this release every definition named five games
  // and no surface in the app rendered a single one of them.
  // ---------------------------------------------------------------------------

  group('featured games are reachable', () {
    final winterMid = DateTime(2026, 12, 22);

    /// Wide enough that the horizontal rail builds every chip; a narrow phone
    /// legitimately keeps the later ones off-screen until scrolled.
    Future<void> pumpWide(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(1568, 696);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(child));
      await tester.pumpAndSettle();
    }

    testWidgets('the banner names every live featured game', (tester) async {
      await pumpWide(tester, SeasonalEventBanner(now: winterMid));

      final featured =
          SeasonalEventManager.liveFeaturedGames(definitionOf('winter_lights'));
      expect(featured, isNotEmpty, reason: 'the fixture itself');
      for (final g in featured) {
        expect(find.text(g.name), findsOneWidget,
            reason: '"${g.name}" is featured but never rendered');
      }
    });

    testWidgets('tapping a chip reports that game, not the first one',
        (tester) async {
      final tapped = <String>[];
      await pumpWide(
        tester,
        SeasonalEventBanner(
          now: winterMid,
          onGameTap: (g) => tapped.add(g.id),
        ),
      );

      final featured =
          SeasonalEventManager.liveFeaturedGames(definitionOf('winter_lights'));
      // Tap the last chip as well as the first: an index bug that always
      // reported featured[0] would survive tapping only the first.
      for (final g in <GameInfo>[featured.first, featured.last]) {
        await tester.tap(find.text(g.name));
        await tester.pumpAndSettle();
      }
      expect(tapped, <String>[featured.first.id, featured.last.id]);
    });

    testWidgets('with no handler a chip pushes that game\'s own route',
        (tester) async {
      // The 1.8 crash class, in a test: a chip must land on a registered route.
      // Each featured game gets a distinct destination, so a chip that pushed
      // the wrong route — or nothing — fails here.
      final featured =
          SeasonalEventManager.liveFeaturedGames(definitionOf('winter_lights'));

      tester.view.physicalSize = const Size(1568, 696);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: [SeasonalEventBanner(now: winterMid)]),
        ),
        routes: <String, WidgetBuilder>{
          for (final g in featured)
            g.routeName: (_) => Scaffold(
                  appBar: AppBar(title: const Text('game')),
                  body: Text('arrived at ${g.id}'),
                ),
        },
      ));
      await tester.pumpAndSettle();

      for (final g in featured) {
        expect(find.text(g.name), findsOneWidget, reason: g.id);
        await tester.tap(find.text(g.name));
        await tester.pumpAndSettle();
        expect(find.text('arrived at ${g.id}'), findsOneWidget,
            reason: 'tapping "${g.name}" did not open ${g.routeName}');
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('opening a game from the event routes but earns nothing',
        (tester) async {
      // Launching a game is NOT progress. The badge says "Clear 5 levels", and
      // in 2.1 the hook sat on ActivityTracker.trackGamePlay — which fires on
      // game *launch* — so opening a game five times and quitting earned it.
      // That is the remember.md section 8 violation this test now pins down from
      // the other side: the tap must route and must record Recently Played, and
      // must NOT light a night. Nights are lit by HintManager.onLevelCleared.
      SeasonalEventManager.clock = () => winterMid;
      addTearDown(() => SeasonalEventManager.clock = DateTime.now);

      final featured =
          SeasonalEventManager.liveFeaturedGames(definitionOf('winter_lights'));
      final target = featured.first;

      expect(await SeasonalEventManager.litNights(now: winterMid), isEmpty);
      expect(await SeasonalEventManager.progressFor(now: winterMid), 0);

      tester.view.physicalSize = const Size(1568, 696);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: [SeasonalEventBanner(now: winterMid)]),
        ),
        routes: <String, WidgetBuilder>{
          target.routeName: (_) => const Scaffold(body: Text('playing')),
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text(target.name));
      await tester.pumpAndSettle();

      expect(find.text('playing'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('recently_played_games') ?? <String>[],
          contains(target.id),
          reason: 'a game opened from the event should be in Recently Played');

      // The important half: opening a game earns nothing.
      expect(await SeasonalEventManager.progressFor(now: winterMid), 0,
          reason: 'a launch is not a clear -- this is the 2.1 defect');
      expect(await SeasonalEventManager.litNights(now: winterMid), isEmpty,
          reason: 'a launch must not light a night');

      // And the other half: an actual clear does count.
      await SeasonalEventManager.recordProgress(now: winterMid);
      expect(await SeasonalEventManager.progressFor(now: winterMid), 1);
      expect(await SeasonalEventManager.litNights(now: winterMid), <int>{5},
          reason: '22 December is day 5 of the 2026 occurrence');
    });
  });

  // ---------------------------------------------------------------------------
  // 2.2 — the banner now leads somewhere. Before this release the home screen
  // passed no onTap and the widget had no default, so the InkWell wrapping the
  // whole banner had a null callback: tapping the event did nothing at all.
  // ---------------------------------------------------------------------------

  group('tapping the banner', () {
    final winterMid = DateTime(2026, 12, 22);

    testWidgets('opens the event sheet by default', (tester) async {
      await tester.pumpWidget(host(SeasonalEventBanner(now: winterMid)));
      await tester.pumpAndSettle();
      expect(find.byType(SeasonalEventSheet), findsNothing);

      // Tap the tagline: it is inside the banner and outside every control.
      await tester.tap(find.text(definitionOf('winter_lights').tagline));
      await tester.pumpAndSettle();

      expect(find.byType(SeasonalEventSheet), findsOneWidget);
      expect(find.text('Nights lit'), findsOneWidget);
      expect(find.text('Featured this event'), findsOneWidget);
    });

    testWidgets('an explicit handler wins and no sheet opens', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(
        SeasonalEventBanner(now: winterMid, onTap: () => taps++),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text(definitionOf('winter_lights').tagline));
      await tester.pumpAndSettle();

      expect(taps, 1);
      expect(find.byType(SeasonalEventSheet), findsNothing);
    });

    testWidgets('the dismiss button still wins over the banner tap',
        (tester) async {
      // The banner's InkWell gained a callback in 2.2; the controls sitting
      // inside it must still take their own taps.
      await tester.pumpWidget(host(SeasonalEventBanner(now: winterMid)));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(SeasonalEventSheet), findsNothing,
          reason: 'dismissing must not also open the sheet');
      expect(find.text('Winter Lights'), findsNothing);
    });

    testWidgets('the claim chip still wins over the banner tap', (tester) async {
      var claims = 0;
      final required = definitionOf('winter_lights').badge.requiredProgress;
      for (var i = 0; i < required; i++) {
        await SeasonalEventManager.recordProgress(now: winterMid);
      }

      await tester.pumpWidget(host(
        SeasonalEventBanner(now: winterMid, onClaim: () => claims++),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Claim'));
      await tester.pumpAndSettle();

      expect(claims, 1);
      expect(find.byType(SeasonalEventSheet), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // 2.2 — the event sheet.
  // ---------------------------------------------------------------------------

  group('the event sheet', () {
    Widget sheetHost(Widget child, {Brightness brightness = Brightness.light}) =>
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: child)),
        );

    testWidgets('shows the badge, the trail and every named stage',
        (tester) async {
      for (final day in <int>[1, 2, 3, 4, 5, 6]) {
        await SeasonalEventManager.recordProgress(
            now: DateTime(2026, 12, 17 + day, 12));
      }

      await tester.pumpWidget(
          sheetHost(SeasonalEventSheet(now: DateTime(2026, 12, 23))));
      await tester.pumpAndSettle();

      expect(find.text('Day 6 of 19'), findsOneWidget);
      expect(find.text('6 of 19'), findsOneWidget, reason: 'nights lit count');
      for (final stage in definitionOf('winter_lights').milestones) {
        expect(
          find.text('${stage.name} · ${stage.nights} '
              '${stage.nights == 1 ? 'night' : 'nights'}'),
          findsOneWidget,
          reason: 'stage "${stage.name}" is not shown',
        );
      }
      expect(find.text('Next: Twelve Nights at 12 nights.'), findsOneWidget);
    });

    testWidgets('renders nothing when no event is running', (tester) async {
      await tester
          .pumpWidget(sheetHost(SeasonalEventSheet(now: DateTime(2026, 8, 22))));
      await tester.pumpAndSettle();
      expect(find.text('Nights lit'), findsNothing);
      expect(find.text('Featured this event'), findsNothing);
      expect(tester.getSize(find.byType(SeasonalEventSheet)).height, 0);
    });

    testWidgets('never names a modifier, because nothing applies one',
        (tester) async {
      // remember.md §8 and §12b rule 3. featuredModifierTypes is still metadata
      // in 2.2; the day something applies it is the day the UI may say so.
      await tester.pumpWidget(
          sheetHost(SeasonalEventSheet(now: DateTime(2026, 12, 22))));
      await tester.pumpAndSettle();

      for (final d in SeasonalEventManager.kSeasonalEvents) {
        expect(d.featuredModifierTypes, isNotEmpty, reason: 'the fixture');
        for (final type in d.featuredModifierTypes) {
          expect(find.textContaining(type, findRichText: true), findsNothing,
              reason: '"$type" is advertised but nothing applies it');
        }
      }
    });

    testWidgets('a claimed badge says so instead of offering Claim again',
        (tester) async {
      final winter = definitionOf('winter_lights');
      for (var i = 0; i < winter.badge.requiredProgress; i++) {
        await SeasonalEventManager.recordProgress(now: DateTime(2026, 12, 22));
      }
      await SeasonalEventManager.claimBadge(winter.badge.id);

      await tester.pumpWidget(
          sheetHost(SeasonalEventSheet(now: DateTime(2026, 12, 22))));
      await tester.pumpAndSettle();

      expect(find.textContaining('Claim ${winter.badge.rewardPoints} points'),
          findsNothing);
      expect(
          find.text('Claimed — ${winter.badge.rewardPoints} points collected'),
          findsOneWidget);
    });

    testWidgets('an unclaimed badge can be claimed from the sheet',
        (tester) async {
      final winter = definitionOf('winter_lights');
      for (var i = 0; i < winter.badge.requiredProgress; i++) {
        await SeasonalEventManager.recordProgress(now: DateTime(2026, 12, 22));
      }

      await tester.pumpWidget(
          sheetHost(SeasonalEventSheet(now: DateTime(2026, 12, 22))));
      await tester.pumpAndSettle();

      expect(await SeasonalEventManager.isBadgeClaimed(winter.badge.id), isFalse);
      await tester.tap(find.text('Claim ${winter.badge.rewardPoints} points'));
      await tester.pumpAndSettle();

      expect(await SeasonalEventManager.isBadgeClaimed(winter.badge.id), isTrue);
      expect(
          find.text('Claimed — ${winter.badge.rewardPoints} points collected'),
          findsOneWidget);
    });

    testWidgets('a featured game in the sheet reports that game', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(sheetHost(SeasonalEventSheet(
        now: DateTime(2026, 12, 22),
        onGameTap: (g) => tapped.add(g.id),
      )));
      await tester.pumpAndSettle();

      final featured =
          SeasonalEventManager.liveFeaturedGames(definitionOf('winter_lights'));
      for (final g in featured) {
        expect(find.text(g.name), findsOneWidget,
            reason: '"${g.name}" missing from the sheet');
      }
      // The last chip, not the first: an index bug that always reported
      // featured[0] would survive tapping only the first.
      await tester.ensureVisible(find.text(featured.last.name));
      await tester.pumpAndSettle();
      await tester.tap(find.text(featured.last.name));
      await tester.pumpAndSettle();
      expect(tapped, <String>[featured.last.id]);
    });

    group('no layout overflow', () {
      const sizes = <String, Size>{
        'small phone': Size(320, 568),
        'typical phone': Size(412, 915),
        'large phone': Size(480, 1000),
        'wide-short (landscape / tablet / split screen)': Size(1568, 696),
      };

      for (final event in events) {
        sizes.forEach((label, size) {
          testWidgets('${event.id}: sheet fits at $label', (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            final overflows = captureOverflows();

            // A part-lit trail and an earned-but-unclaimed badge together give
            // the sheet its tallest, widest content.
            final required = definitionOf(event.id).badge.requiredProgress;
            for (var i = 0; i < required; i++) {
              await SeasonalEventManager.recordProgress(now: event.midWindow);
            }

            await tester.pumpWidget(
                sheetHost(SeasonalEventSheet(now: event.midWindow)));
            await tester.pumpAndSettle();

            // Prove there was something to measure, or the sweep is vacuous.
            expect(find.text('Nights lit'), findsOneWidget,
                reason: '${event.id} did not render at $label');
            expect(overflows, isEmpty,
                reason: '${event.id} at $label: ${overflows.join('; ')}');
          });
        });
      }

      for (final event in events) {
        testWidgets('${event.id}: sheet fits in dark theme', (tester) async {
          tester.view.physicalSize = const Size(412, 915);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final overflows = captureOverflows();

          await tester.pumpWidget(sheetHost(
            SeasonalEventSheet(now: event.midWindow),
            brightness: Brightness.dark,
          ));
          await tester.pumpAndSettle();

          expect(find.text('Nights lit'), findsOneWidget, reason: event.id);
          expect(overflows, isEmpty,
              reason: '${event.id}: ${overflows.join('; ')}');
        });
      }
    });
  });
}

/// One shipped event, with a date inside its window and the headline the
/// banner has to show on that date.
class _EventCase {
  _EventCase(this.id, this.name, this.midWindow);

  final String id;

  /// Pinned rather than read from `kSeasonalEvents`: this is the string a
  /// player reads, so the test has to state it independently.
  final String name;

  final DateTime midWindow;

  @override
  String toString() => id;
}
