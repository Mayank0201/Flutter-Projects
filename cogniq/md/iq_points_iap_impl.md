# In-App Purchases — Implementation Spec (Point Packs, Bundle, Remove Ads)

**Goal:** Extend the existing `PurchaseManager` (which today only handles the one non-consumable
`remove_ads_premium`) into a general IAP layer that also sells **consumable CogniQ Point packs**
and a **non-consumable Starter Bundle**, credits `PointManager`, consumes purchases so packs can be
re-bought, and exposes a purchase UI.

> This is an implementation plan only. No code has been changed. All file/line references are against
> branch `v5_Puzzle` @ `aa1f5ef`.

---

## 0. Current state (what exists today)

| File | Relevant API | Notes |
|---|---|---|
| `lib/utils/purchase_manager.dart` | `adFreeProductId = 'remove_ads_premium'`, `initialize()`, `loadProducts()`, `buyAdFree()`, `_triggerPurchase()` → `buyNonConsumable`, `_handlePurchaseUpdates()`, `restorePurchases()` | Only knows ONE product; only calls `buyNonConsumable`; on success calls `settingsNotifier.setAdsRemoved(true)` |
| `lib/utils/point_manager.dart` | `getPoints()→int`, `addPoints(int)`, `consumePoints(int)→bool`; pref key `PrefsKeys.points` = `'points'` | Soft-currency store. **This is where purchased points get credited.** |
| `lib/theme/settings_manager.dart` | `settingsNotifier.setAdsRemoved(bool)`, `settingsNotifier.adsRemoved` | Ad-free flag; pref `settings_ads_removed` |
| `lib/utils/hint_manager.dart` | `HintManager.addHints(gameId, qty)` | Hints are point-gated; not sold directly |
| `lib/widgets/buy_hints_dialog.dart` | Uses `PointManager` + `AdManager` | Existing "spend points / watch ad" sheet — will link to the new store |
| `lib/utils/prefs_keys.dart` | `points`, `adsRemoved`, plus dynamic helpers | Add new keys here (§2) |
| pubspec | `in_app_purchase` | Plugin already integrated |

**Key architectural fact:** Google Play has NO "consumable" setting in the console. Consumable vs
non-consumable is decided **here in code** — consumables call `buyConsumable` and must be *consumed*
after granting so the user can buy again; non-consumables call `buyNonConsumable` and are restored on
reinstall.

---

## 1. Product catalog (single source of truth)

Create a new file `lib/utils/iap_catalog.dart` describing every product once. Everything else reads
from this — no hard-coded IDs scattered around.

```dart
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
    id: 'remove_ads_premium', kind: IapKind.removeAds,
    consumable: false, grantsAdFree: true, title: 'Remove Ads',
  );
  static const bundle = IapProduct(
    id: 'starter_bundle', kind: IapKind.bundle,
    consumable: false, points: 1500, grantsAdFree: true, title: 'Starter Bundle',
  );
  static const points500  = IapProduct(id: 'points_500',  kind: IapKind.points, consumable: true, points: 500,  title: '500 Points');
  static const points1200 = IapProduct(id: 'points_1200', kind: IapKind.points, consumable: true, points: 1200, title: '1,200 Points', bestValue: true);
  static const points3000 = IapProduct(id: 'points_3000', kind: IapKind.points, consumable: true, points: 3000, title: '3,000 Points');
  static const points7000 = IapProduct(id: 'points_7000', kind: IapKind.points, consumable: true, points: 7000, title: '7,000 Points');

  static const all = <IapProduct>[
    removeAds, bundle, points500, points1200, points3000, points7000,
  ];

  static Set<String> get allIds => {for (final p in all) p.id};
  static IapProduct? byId(String id) {
    for (final p in all) { if (p.id == id) return p; }
    return null;
  }
}
```

**Console products to create** (all under *In-app products / one-time*), IDs must match above:

| Product ID | Type in code | Price ₹ | Grants |
|---|---|---|---|
| `remove_ads_premium` | non-consumable | 99 ✅ already live | ad-free |
| `points_500` | consumable | 29 | +500 pts |
| `points_1200` | consumable | 59 | +1,200 pts |
| `points_3000` | consumable | 149 | +3,000 pts |
| `points_7000` | consumable | 299 | +7,000 pts |
| `starter_bundle` | non-consumable | 149 | ad-free + 1,500 pts (once) |

> Prices are a starting ladder (rising points-per-₹). Adjust freely; the code doesn't hard-code price —
> it reads the localized price string from the store (`ProductDetails.price`).

---

## 2. New pref keys (`prefs_keys.dart`)

Add under "IQ & Profile" / a new "IAP" section:

```dart
// IAP
static const String bundleGranted = 'iap_starter_bundle_granted'; // bool — one-time bundle points guard
static const String processedPurchaseIds = 'iap_processed_purchase_ids'; // List<String> — consumable dedup
```

- `bundleGranted` — prevents the bundle's 1,500 points being re-credited every time Play re-delivers the
  non-consumable (on restore/reinstall).
- `processedPurchaseIds` — dedup ledger so a consumable that was granted but not yet consumed (app killed
  mid-flow) is **not double-credited** when Play re-delivers it on next launch.

---

## 3. `PurchaseManager` refactor

Rewrite `lib/utils/purchase_manager.dart`. Keep `initialize()`, the stream subscription, and
`restorePurchases()` shape; generalize product handling.

### 3.1 loadProducts — query the whole catalog
```dart
static Future<void> loadProducts() async {
  final ids = IapCatalog.allIds;
  final response = await _iap.queryProductDetails(ids);
  if (response.notFoundIDs.isNotEmpty) {
    debugPrint('PurchaseManager: Not found: ${response.notFoundIDs}'); // fine until products go live
  }
  products = response.productDetails; // List<ProductDetails>
}
```
Expose a lookup: `static ProductDetails? detailsFor(String id)`.

### 3.2 buy() — one entry point, routes by consumable flag
Replace `buyAdFree()` with a generic:
```dart
static Future<void> buy(
  IapProduct product, {
  required VoidCallback onStoreUnavailable,
  required VoidCallback onProductNotFound,
}) async {
  if (!isStoreAvailable) return onStoreUnavailable();
  final details = detailsFor(product.id) ?? (await _reloadAndGet(product.id));
  if (details == null) return onProductNotFound();
  final param = PurchaseParam(productDetails: details);
  if (product.consumable) {
    _iap.buyConsumable(purchaseParam: param); // autoConsume defaults true on Android
  } else {
    _iap.buyNonConsumable(purchaseParam: param);
  }
}
```
> Keep a thin `buyAdFree(...)` wrapper that calls `buy(IapCatalog.removeAds, ...)` so existing call
> sites (settings screen etc.) don't break. Grep for `buyAdFree(` before deleting.

### 3.3 _handlePurchaseUpdates — grant by product kind
This is the heart. On `purchased` OR `restored`:
```dart
Future<void> _grant(PurchaseDetails d) async {
  final product = IapCatalog.byId(d.productID);
  if (product == null) return; // unknown id — ignore, still complete

  // ----- consumables: dedup by purchaseID, credit points, then consume -----
  if (product.consumable) {
    if (await _alreadyProcessed(d.purchaseID)) {
      await _consumeIfNeeded(d);
      return;
    }
    await PointManager.addPoints(product.points);
    await _markProcessed(d.purchaseID);
    await _consumeIfNeeded(d); // Android auto-consumes; call explicitly for safety/iOS parity
    _notify('+${product.points} points added!');
    return;
  }

  // ----- non-consumables (removeAds, bundle) -----
  if (product.grantsAdFree) settingsNotifier.setAdsRemoved(true); // idempotent
  if (product.kind == IapKind.bundle) {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(PrefsKeys.bundleGranted) ?? false)) {
      await PointManager.addPoints(product.points); // 1,500 — ONCE
      await prefs.setBool(PrefsKeys.bundleGranted, true);
    }
  }
}
```
Then, exactly as today, after grant:
```dart
if (d.pendingCompletePurchase) _iap.completePurchase(d);
```

### 3.4 Grant/consume ordering (do not reorder)
1. **Credit first**, then **consume**. If the app dies between, the un-consumed purchase is re-delivered
   next launch and the `processedPurchaseIds` guard stops a double credit while still consuming it.
2. **Never** consume before crediting — that can drop points on a crash.
3. `completePurchase` is still required for non-consumables and for consumables even when auto-consumed.

### 3.5 Helpers to add
```dart
static Future<bool> _alreadyProcessed(String? id) async {...}   // reads processedPurchaseIds list
static Future<void> _markProcessed(String? id) async {...}       // appends, cap list length ~200
static Future<void> _consumeIfNeeded(PurchaseDetails d) async {...} // ConsumePurchaseParam / already auto on Android
static ProductDetails? detailsFor(String id) {...}
```

### 3.6 restorePurchases — unchanged behavior
`restorePurchases()` only meaningfully returns **non-consumables** (`remove_ads_premium`, `starter_bundle`).
Consumables are NOT restored (they're spent). The `restored` status routes through the same `_grant`,
and the `bundleGranted` guard ensures bundle points aren't re-added on restore. ✅

---

## 4. Purchase UI

### 4.1 New store sheet `lib/widgets/points_store_dialog.dart`
Modeled on `buy_hints_dialog.dart` (same bottom-sheet style, `AppTheme` colors, GoogleFonts.outfit).
Contents:
- Header: "Get Points" + current balance chip (`PointManager.getPoints()`), same as Buy Hints sheet.
- A card per consumable pack (`points500/1200/3000/7000`) showing: points amount, **localized store price**
  (`detailsFor(id)?.price`), a "BEST VALUE" badge when `product.bestValue`.
- Tapping a card → `PurchaseManager.buy(product, onStoreUnavailable:..., onProductNotFound:...)`.
- Optional footer row: the Starter Bundle card (if `!settingsNotifier.adsRemoved`) — hides once ad-free.
- While a purchase is in flight show a spinner; the stream callback (§4.3) closes/refreshes it.

### 4.2 Entry points
- Add a "Get more points" button in `buy_hints_dialog.dart` (next to "Watch Ad") that opens
  `PointsStoreDialog`.
- Optionally a coin/"+" affordance on any balance chip in the app.
- "Remove Ads" and "Starter Bundle" also surfaced in `settings_screen.dart` (remove-ads may already be there — grep `buyAdFree`).

### 4.3 Reflecting results in the UI
`_handlePurchaseUpdates` runs in `PurchaseManager` (not the widget). To refresh balances:
- Simplest: after `PointManager.addPoints`, call an existing notifier if one exists, else expose a
  lightweight `PurchaseManager.onGrant` `ValueNotifier<int>`/callback the store sheet listens to.
- On `PurchaseStatus.pending` show "Processing…"; on `error`/`canceled` show a snackbar and re-enable buttons.

---

## 5. Purchase status handling (all branches)

In `_handlePurchaseUpdates`, handle every status (today only pending/error/purchased/restored are handled):

| Status | Action |
|---|---|
| `pending` | Show "Processing…"; do nothing else |
| `purchased` | `_grant(d)` then `completePurchase` |
| `restored` | `_grant(d)` then `completePurchase` (guards prevent double-grant) |
| `error` | Snackbar with `d.error`; if `pendingCompletePurchase` still `completePurchase(d)` |
| `canceled` | Silent (user backed out); complete if pending |

---

## 6. Security / anti-fraud (choose a tier)

Client-side granting (what this spec does) is the standard starting point and fine for launch, but points
are then only guarded locally. Hardening options, in order of effort:

1. **Launch tier (this spec):** trust the plugin's verified purchase stream, dedup by `purchaseID`,
   grant locally. Acceptable for a low-ARPU casual game.
2. **Play Integrity + server verify (later):** send the purchase token to a small backend that calls
   Google Play Developer API `purchases.products.get` to confirm, then returns the grant. Prevents
   tampered/local-replay grants. Add only if abuse shows up.
3. Never expose the points balance as trivially editable if you move to server-authoritative economy.

Document which tier you shipped; do not silently assume server verification exists.

---

## 7. Edge cases / correctness checklist

- [ ] **Double-credit on relaunch** — un-consumed consumable re-delivered → blocked by `processedPurchaseIds`.
- [ ] **Bundle points re-added on restore/reinstall** — blocked by `bundleGranted` bool.
- [ ] **`notFoundIDs` before products are Active** — logged, not fatal; buttons show "unavailable".
- [ ] **Web / desktop** — `kIsWeb` early-return already present; keep store hidden on web.
- [ ] **Store unavailable / offline** — `onStoreUnavailable` path shows a friendly message.
- [ ] **`purchaseID` null** (rare on some flows) — fall back to a composite key
      (`productID + purchaseDetails.transactionDate`) for the dedup ledger.
- [ ] **Points list cap** — `processedPurchaseIds` trimmed to last ~200 to avoid unbounded prefs growth.
- [ ] **Existing `buyAdFree` callers** — keep wrapper or update all call sites.
- [ ] **`completePurchase` always called** — otherwise Play refunds after 3 days and re-delivers forever.

---

## 8. Testing / QA

1. **License testers**: add test Gmail accounts in Play Console → Setup → License testing (test purchases,
   no real charge). Build must be on an internal/closed track for IAP to resolve.
2. Verify each `points_*` pack: balance rises by the exact amount; **buy the same pack twice** → credited
   both times (consume worked).
3. Kill the app immediately after paying, before it credits → relaunch → credited exactly once.
4. `remove_ads_premium`: interstitials stop; reinstall → **Restore** brings ad-free back.
5. `starter_bundle`: ad-free + 1,500 pts once; press **Restore** repeatedly → points do NOT keep climbing.
6. Cancel a purchase mid-flow → no credit, buttons re-enable.
7. Airplane mode → tap buy → `onStoreUnavailable` message, no crash.
8. Confirm localized price strings render from `ProductDetails.price` (not hard-coded ₹).

---

## 9. Ordered work list

1. Create `lib/utils/iap_catalog.dart` (§1).
2. Add pref keys `bundleGranted`, `processedPurchaseIds` (§2).
3. Refactor `purchase_manager.dart`: catalog query, generic `buy()`, `_grant()` by kind, dedup +
   consume helpers, keep `buyAdFree` wrapper (§3).
4. Build `points_store_dialog.dart` + wire entry points from `buy_hints_dialog.dart` / settings (§4).
5. Add UI refresh hook so balances update after a grant (§4.3).
6. Handle all purchase statuses (§5).
7. QA with license testers (§8).
8. Create the 5 new products in Play Console (IDs from §1 table), set prices, set **Active**.
9. (Later, optional) server-side verification (§6 tier 2).

> **Do §1–§7 before §8.** Products created in the console are unbuyable until the consumable code path
> exists. `remove_ads_premium` already works because it's the one case the current code handles.
