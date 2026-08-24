import 'package:shared_preferences/shared_preferences.dart';

import 'prefs_keys.dart';

/// Zen level clears needed to earn the Zen-only trail.
const int kZenTrailRequiredClears = 50;

/// The four daily-challenge star tiers, cheapest first.
///
/// The daily system awards at most one star per day and upgrades it as the
/// player finishes 1, 2 or 3 challenges (bronze -> silver -> gold); a diamond
/// costs seven consecutive perfect days. The 7:1 ratio below mirrors that:
/// 7 bronze = 1 silver = 1/7 gold = 1/49 diamond.
enum StarTier { bronze, silver, gold, diamond }

/// One star route to a trail: "[count] stars of [tier]".
class StarUnlock {
  final StarTier tier;
  final int count;
  const StarUnlock(this.tier, this.count);
}

/// A snapshot of the player's four star totals.
///
/// Stars are a **threshold**, never a cost: reaching a count unlocks the trail
/// permanently and nothing is ever deducted. The daily screen and the home
/// widget both display these totals, and a number that falls after an unlock
/// has no good explanation.
class StarCounts {
  final int bronze;
  final int silver;
  final int gold;
  final int diamond;

  const StarCounts({
    this.bronze = 0,
    this.silver = 0,
    this.gold = 0,
    this.diamond = 0,
  });

  int of(StarTier tier) {
    switch (tier) {
      case StarTier.bronze:
        return bronze;
      case StarTier.silver:
        return silver;
      case StarTier.gold:
        return gold;
      case StarTier.diamond:
        return diamond;
    }
  }

  /// Reads the four totals straight out of prefs.
  ///
  /// Every caller must come through here rather than reading the keys itself,
  /// for the same reason the rest of this file exists: three screens reading
  /// four keys by hand is three chances to read the wrong one.
  factory StarCounts.fromPrefs(SharedPreferences prefs) => StarCounts(
        bronze: prefs.getInt(PrefsKeys.dailyBronzeStars) ?? 0,
        silver: prefs.getInt(PrefsKeys.dailySilverStars) ?? 0,
        gold: prefs.getInt(PrefsKeys.dailyGoldStars) ?? 0,
        diamond: prefs.getInt(PrefsKeys.diamondStars) ?? 0,
      );
}

/// Every route into one star-locked trail. Meeting **any** single route is
/// enough — they are alternatives, not a checklist.
class StarTrailRules {
  /// Star routes, cheapest tier first.
  final List<StarUnlock> starRoutes;

  /// Lifetime level clears that also unlock the trail, so a player who never
  /// touches a daily challenge still has a way in. Deliberately far above the
  /// 30/100/250 thresholds of the ordinary trails: it is a long grind, not a
  /// shortcut.
  final int clears;

  const StarTrailRules({required this.starRoutes, required this.clears});
}

/// Single source of truth for swipe-trail unlock rules.
///
/// Both the trails screen (which draws the cards) and the swipe trail overlay
/// (which decides whether to actually render a trail) must agree on these
/// numbers. They previously kept separate copies that had drifted apart, which
/// made bought trails look locked and, worse, silently stop rendering after a
/// restart.
class TrailCatalog {
  TrailCatalog._();

  /// Sentinel for trails that cannot be earned by clearing Challenge levels.
  static const int pointsOnly = 999999;

  /// Trails earned through Zen play rather than bought or ground out in
  /// Challenge mode.
  static const String zenTrailId = 'zen';

  /// Star-locked trails, in release order.
  ///
  /// A star trail is **never purchasable** — see [price] and [requiredClears],
  /// which both return [pointsOnly] for these ids so the existing buy and
  /// grind paths refuse them by construction rather than by everyone
  /// remembering the rule.
  static const Map<String, StarTrailRules> _starTrails = {
    // 1.8
    'morning_mist': StarTrailRules(
      starRoutes: [
        StarUnlock(StarTier.bronze, 7),
        StarUnlock(StarTier.silver, 1),
      ],
      clears: 400,
    ),
    'tide_line': StarTrailRules(
      starRoutes: [
        StarUnlock(StarTier.silver, 7),
        StarUnlock(StarTier.gold, 1),
      ],
      clears: 700,
    ),
    // 1.9
    // 2.0
    // 2.1
    // 2.2
    // 2.3
  };

  /// The ordinary trails: bought with points or ground out in Challenge mode.
  /// This is exactly the set the original single `trail_collector` achievement
  /// required, kept intact so nobody who already earned it loses it.
  static const List<String> collectorTierI = [
    'accent',
    'pastel',
    'sparkle',
    'neon_glow',
    'rainbow',
    'fire',
  ];

  /// Tier I plus the bronze/silver star trails.
  static const List<String> collectorTierII = [
    ...collectorTierI,
    'morning_mist',
    'tide_line',
  ];

  /// Tier II plus every gold/diamond star trail — the app's hardest goal.
  static const List<String> collectorTierIII = [
    ...collectorTierII,
  ];

  static bool isZenTrail(String styleId) => styleId == zenTrailId;

  /// True when the trail is unlocked by stars (or the long clears route)
  /// rather than bought.
  static bool isStarTrail(String styleId) => _starTrails.containsKey(styleId);

  /// Every unlock route for a star trail, or null when it is not star-locked.
  static StarTrailRules? starRules(String styleId) => _starTrails[styleId];

  /// The star routes only. Meeting **either** unlocks the trail.
  static List<StarUnlock>? starUnlocks(String styleId) =>
      _starTrails[styleId]?.starRoutes;

  /// The lifetime-clears route, or null when the trail is not star-locked.
  ///
  /// Deliberately *not* wired into [requiredClears]: that answers "can this be
  /// ground out through the ordinary trail path", and star trails must keep
  /// answering no there so the Claim/Buy plumbing never treats them as normal.
  static int? starTrailClears(String styleId) => _starTrails[styleId]?.clears;

  static int requiredClears(String styleId) {
    // Star trails are never obtainable through the ordinary clears path.
    if (isStarTrail(styleId)) return pointsOnly;
    switch (styleId) {
      case 'none':
        return 0;
      case 'accent':
        return 30;
      case 'sparkle':
        return 100;
      case 'pastel':
        return 250;
      case 'neon_glow':
      case 'rainbow':
      case 'fire':
      case zenTrailId:
        return pointsOnly;
      default:
        return pointsOnly;
    }
  }

  static int price(String styleId) {
    // A star trail with a points price would make the stars mean nothing, so
    // the refusal lives here rather than in each caller.
    if (isStarTrail(styleId)) return pointsOnly;
    switch (styleId) {
      case 'none':
        return 0;
      case 'accent':
        return 300;
      case 'sparkle':
        return 1500;
      case 'pastel':
        return 4000;
      case 'neon_glow':
        return 9000;
      case 'rainbow':
        return 16000;
      case 'fire':
        return 25000;
      default:
        return pointsOnly;
    }
  }

  /// True when points can buy this trail at all. Star trails, the Zen trail
  /// and the free starter are all false, which is what suppresses the Buy
  /// button and makes a stray purchase call a no-op.
  static bool isPurchasable(String styleId) {
    if (styleId == 'none') return false;
    if (isZenTrail(styleId)) return false;
    if (isStarTrail(styleId)) return false;
    return price(styleId) < pointsOnly;
  }

  /// True when the trail was earned purely by clearing Challenge levels, which
  /// is what makes the free "Claim" button appear.
  ///
  /// [pointsOnly] is a sentinel meaning "not obtainable this way", not a real
  /// threshold, so it must never be satisfied by a large enough clear count.
  static bool isEarnedByClears(String styleId, int clears) {
    if (isZenTrail(styleId)) return false;
    final required = requiredClears(styleId);
    if (required >= pointsOnly) return false;
    return clears >= required;
  }

  /// True when the trail was earned through Zen play.
  static bool isEarnedByZen(String styleId, int zenClears) =>
      isZenTrail(styleId) && zenClears >= kZenTrailRequiredClears;

  /// True when a star-locked trail's threshold has been reached by **any** of
  /// its routes: either star route, or the lifetime clears route.
  ///
  /// Nothing is spent here. Reaching the count is the whole condition, so the
  /// answer can only ever go from false to true.
  static bool isEarnedByStars({
    required String styleId,
    StarCounts stars = const StarCounts(),
    int clears = 0,
  }) {
    final rules = _starTrails[styleId];
    if (rules == null) return false;
    for (final route in rules.starRoutes) {
      if (stars.of(route.tier) >= route.count) return true;
    }
    return clears >= rules.clears;
  }

  /// True when the player may select and render this trail: they bought or
  /// claimed it, cleared enough Challenge levels, earned it in Zen, or hit a
  /// star-trail threshold.
  ///
  /// Purchases must be honoured regardless of level count. A points-only trail
  /// has no reachable clear requirement, so [claimed] is the only way in.
  static bool isAvailable({
    required String styleId,
    required int clears,
    required List<String> claimed,
    int zenClears = 0,
    StarCounts stars = const StarCounts(),
  }) {
    if (claimed.contains(styleId)) return true;
    if (isEarnedByZen(styleId, zenClears)) return true;
    if (isEarnedByStars(styleId: styleId, stars: stars, clears: clears)) {
      return true;
    }
    return isEarnedByClears(styleId, clears);
  }

  /// True when the trail has been earned for free by any route and is waiting
  /// to be claimed — the single check the trails screen, the home card and the
  /// overlay all share.
  static bool isEarnedFree({
    required String styleId,
    required int clears,
    int zenClears = 0,
    StarCounts stars = const StarCounts(),
  }) {
    if (isZenTrail(styleId)) return isEarnedByZen(styleId, zenClears);
    if (isStarTrail(styleId)) {
      return isEarnedByStars(styleId: styleId, stars: stars, clears: clears);
    }
    return isEarnedByClears(styleId, clears);
  }

  /// Evaluates star totals and lifetime clears to find any star-locked trails
  /// newly earned and not yet notified.
  static Future<List<({String id, String name, String emoji})>> checkStarUnlocks() async {
    final prefs = await SharedPreferences.getInstance();
    final stars = StarCounts.fromPrefs(prefs);
    final clears = prefs.getInt(PrefsKeys.globalLevelClearedCount) ?? 0;
    final newlyUnlocked = <({String id, String name, String emoji})>[];

    const starTrailData = <String, ({String name, String emoji})>{
      'morning_mist': (name: 'Morning Mist', emoji: '🌫️'),
      'tide_line': (name: 'Tide Line', emoji: '🌊'),
    };

    for (final entry in starTrailData.entries) {
      final styleId = entry.key;
      final key = 'trail_unlocked_toast_$styleId';
      if (prefs.getBool(key) == true) continue;

      if (isEarnedByStars(styleId: styleId, stars: stars, clears: clears)) {
        await prefs.setBool(key, true);
        newlyUnlocked.add((id: styleId, name: entry.value.name, emoji: entry.value.emoji));
      }
    }
    return newlyUnlocked;
  }
}
