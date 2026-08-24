import 'package:flutter/foundation.dart';

import 'analytics_event.dart';

/// The seam a future analytics backend plugs into.
///
/// ---------------------------------------------------------------------------
/// WHY THIS INTERFACE EXISTS BEFORE ANY BACKEND DOES
/// ---------------------------------------------------------------------------
/// CogniQ has shipped its entire life with **zero network calls** — no backend,
/// no accounts, no SDK phoning home (`md/RELEASE_PLAN.md` §1). That is a real
/// product property, not an accident, and it is far easier to keep than to
/// recover once lost.
///
/// The choice of vendor is the app owner's and has not been made. So rather
/// than pick one and retrofit an abstraction around it later — which always
/// ends with vendor types leaking into game screens — the abstraction lands
/// first and the vendor lands behind it. Everything upstream of this file
/// (the taxonomy, consent, the buffer, every call site in every game) is
/// finished and testable today, and the entire remaining work is one class
/// implementing one method.
///
/// **Nothing in this file, or anywhere else in `lib/utils/analytics/`, opens a
/// socket.** The default sink is [NoopSink]. Until someone writes a sink that
/// does I/O and installs it, the app's zero-network property is intact, and the
/// tests in `test/analytics_test.dart` hold it in place.
///
/// ---------------------------------------------------------------------------
/// HOW TO ADD A BACKEND LATER
/// ---------------------------------------------------------------------------
/// 1. Add the vendor package to `pubspec.yaml`.
/// 2. Write `class FooSink implements AnalyticsSink` — map [AnalyticsEvent]s to
///    the vendor's call, and return `true` only once the vendor has taken
///    ownership of the batch.
/// 3. Call `Analytics.setSink(FooSink())` during startup, after
///    `Analytics.initialize()`.
///
/// Nothing else changes. No game screen, no widget, and no other manager needs
/// to know a backend appeared. Take care in step 2 that the vendor SDK is not
/// initialised until [deliver] is actually reached, so an opted-out player
/// still makes no network calls: `Analytics` never calls [deliver] without
/// consent, but a vendor SDK constructed eagerly at startup will happily beacon
/// on its own.
abstract interface class AnalyticsSink {
  /// Short identifier for logs and tests. Not transmitted.
  String get id;

  /// Hand a batch of events to the backend.
  ///
  /// Returns `true` when the backend has accepted responsibility for the batch,
  /// which is the caller's cue to drop those events from the local buffer.
  /// Return `false` for anything retryable — offline, throttled, not yet
  /// initialised — and the events stay buffered for the next attempt. This
  /// return value is the whole of "graceful offline queuing": a sink that
  /// cannot reach the network simply says `false` and the buffer does the rest.
  ///
  /// Must not throw. A sink that throws is treated as a permanent failure by
  /// `Analytics.deliverPending`, and the events are retained rather than lost,
  /// but a throwing sink will retry forever — return `false` instead.
  Future<bool> deliver(List<AnalyticsEvent> batch);
}

/// The default sink: accepts every batch and does nothing with it.
///
/// This is what ships until the owner picks a vendor, and it is why installing
/// this layer cannot change the app's behaviour. `deliver` returning `true`
/// means buffered events are drained rather than accumulating forever against a
/// backend that does not exist.
class NoopSink implements AnalyticsSink {
  const NoopSink();

  @override
  String get id => 'noop';

  @override
  Future<bool> deliver(List<AnalyticsEvent> batch) async => true;
}

/// A development sink that prints each event through [debugPrint].
///
/// [debugPrint] rather than `print` on purpose: it is rate-limited by the
/// framework, so a burst of events during a fast level cannot stall the UI
/// isolate on console I/O, and it compiles out of release builds' noise.
///
/// Intended for `flutter run` while wiring call sites up — install it with
/// `Analytics.setSink(const DebugSink())` behind a `kDebugMode` check. It is
/// also the easiest way to eyeball the exact JSON a backend will receive,
/// because it prints the same [AnalyticsEvent.encode] form the buffer persists.
class DebugSink implements AnalyticsSink {
  const DebugSink({this.prefix = '[analytics]'});

  final String prefix;

  @override
  String get id => 'debug';

  @override
  Future<bool> deliver(List<AnalyticsEvent> batch) async {
    for (final event in batch) {
      debugPrint('$prefix ${event.encode()}');
    }
    return true;
  }
}
