import 'package:flutter_test/flutter_test.dart';
import 'package:cogniq/utils/trail_catalog.dart';

void main() {
  group('bought trails stay unlocked', () {
    // The reported bug: Pastel Glow bought with points still rendered its card
    // as "Locked: Requires 250 levels cleared" because availability was
    // computed from the level count alone.
    test('pastel bought with points is available below the clear requirement',
        () {
      expect(
        TrailCatalog.isAvailable(
          styleId: 'pastel',
          clears: 80,
          claimed: const ['none', 'pastel'],
        ),
        isTrue,
      );
    });

    test('pastel not bought and under the requirement stays locked', () {
      expect(
        TrailCatalog.isAvailable(
          styleId: 'pastel',
          clears: 80,
          claimed: const ['none'],
        ),
        isFalse,
      );
    });

    test('pastel earned purely by clears is available without buying', () {
      expect(
        TrailCatalog.isAvailable(
          styleId: 'pastel',
          clears: 250,
          claimed: const ['none'],
        ),
        isTrue,
      );
    });

    // The latent version of the same bug, which silently disabled a
    // 25,000-point purchase on the next app launch: points-only trails have no
    // reachable clear requirement, so a clears-only check always failed them.
    for (final id in const ['fire', 'rainbow', 'neon_glow']) {
      test('$id bought with points survives with zero clears', () {
        expect(
          TrailCatalog.isAvailable(
            styleId: id,
            clears: 0,
            claimed: ['none', id],
          ),
          isTrue,
        );
      });

      test('$id can never be earned by clearing levels alone', () {
        expect(
          TrailCatalog.isAvailable(
            styleId: id,
            clears: 100000,
            claimed: const ['none'],
          ),
          isFalse,
        );
      });
    }
  });

  group('zen trail', () {
    test('locked below the zen requirement', () {
      expect(
        TrailCatalog.isAvailable(
          styleId: TrailCatalog.zenTrailId,
          clears: 5000,
          claimed: const ['none'],
          zenClears: kZenTrailRequiredClears - 1,
        ),
        isFalse,
      );
    });

    test('unlocked at the zen requirement', () {
      expect(
        TrailCatalog.isAvailable(
          styleId: TrailCatalog.zenTrailId,
          clears: 0,
          claimed: const ['none'],
          zenClears: kZenTrailRequiredClears,
        ),
        isTrue,
      );
    });

    test('challenge clears never earn the zen trail', () {
      expect(
        TrailCatalog.isEarnedByClears(TrailCatalog.zenTrailId, 999999),
        isFalse,
      );
    });
  });

  group('catalog consistency', () {
    test('the free starter trail is always available', () {
      expect(
        TrailCatalog.isAvailable(
          styleId: 'none',
          clears: 0,
          claimed: const [],
        ),
        isTrue,
      );
    });

    test('an unknown style is not silently unlocked', () {
      expect(
        TrailCatalog.isAvailable(
          styleId: 'does_not_exist',
          clears: 999999,
          claimed: const ['none'],
        ),
        isFalse,
      );
    });
  });
}
