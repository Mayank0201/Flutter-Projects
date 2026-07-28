enum IapKind { removeAds, points, bundle }

class IapProduct {
  final String id;            // MUST match Play Console product ID exactly
  final IapKind kind;
  final bool consumable;      // true => buyConsumable + consume after grant
  final int points;           // points granted (0 for pure remove-ads)
  final bool grantsAdFree;    // true for removeAds + bundle
  final String title;         // fallback label if store title unavailable
  final bool bestValue;       // UI badge only
  const IapProduct({
    required this.id,
    required this.kind,
    required this.consumable,
    this.points = 0,
    this.grantsAdFree = false,
    required this.title,
    this.bestValue = false,
  });
}

class IapCatalog {
  static const removeAds = IapProduct(
    id: 'remove_ads_premium',
    kind: IapKind.removeAds,
    consumable: false,
    grantsAdFree: true,
    title: 'Remove Ads',
  );
  static const bundle = IapProduct(
    id: 'starter_bundle',
    kind: IapKind.bundle,
    consumable: false,
    points: 1500,
    grantsAdFree: true,
    title: 'Starter Bundle',
  );
  static const points500 = IapProduct(
    id: 'points_500',
    kind: IapKind.points,
    consumable: true,
    points: 500,
    title: '500 Points',
  );
  static const points1200 = IapProduct(
    id: 'points_1200',
    kind: IapKind.points,
    consumable: true,
    points: 1200,
    title: '1,200 Points',
    bestValue: true,
  );
  static const points3000 = IapProduct(
    id: 'points_3000',
    kind: IapKind.points,
    consumable: true,
    points: 3000,
    title: '3,000 Points',
  );
  static const points7000 = IapProduct(
    id: 'points_7000',
    kind: IapKind.points,
    consumable: true,
    points: 7000,
    title: '7,000 Points',
  );

  static const all = <IapProduct>[
    removeAds,
    bundle,
    points500,
    points1200,
    points3000,
    points7000,
  ];

  static Set<String> get allIds => {for (final p in all) p.id};
  static IapProduct? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
