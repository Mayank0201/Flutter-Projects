# IAP Server-Side Verification — Implementation Spec (Tier 2 hardening)

**Goal:** Move point/entitlement granting from *client-trusted* (Tier 1, shipped in
`iq_points_iap_impl.md`) to *server-verified* (Tier 2). Before crediting points or unlocking ad-free,
the app sends the purchase token to a small backend that asks Google whether the purchase is real,
un-refunded, and not already redeemed. Prevents tampered APKs, replayed tokens, and local prefs edits.

> Implementation plan only — no code changed. Add this **only when abuse/revenue justifies it**; Tier 1
> is fine for launch. This doc is the companion to `iq_points_iap_impl.md` (§6, tier 2).

---

## 0. Why (threat model)

| Attack | Tier 1 (client-only) | Tier 2 (this doc) |
|---|---|---|
| Edit `SharedPreferences` `points` on a rooted device | ✅ works — free points | ⚠️ still edits local balance, but **server is source of truth**; balance re-syncs to verified total |
| Replay a captured purchase token | Partly blocked by `processedPurchaseIds` (local only, wiped on reinstall) | ❌ blocked — server marks token consumed permanently |
| Tampered APK that fakes `PurchaseStatus.purchased` | ✅ works — grant fires | ❌ blocked — no valid Google token, server rejects |
| Refund-then-keep-points | Not detected | ❌ blocked — server sees `purchaseState`/voided status |

Tier 2 makes the **server** the authority on entitlements. The client becomes a cache.

---

## 1. Architecture

```
App (Flutter)                 Backend (Cloud Function / small API)          Google
  |  buyConsumable()              |                                            |
  |  <-- PurchaseDetails -------- | (purchaseID, productID, verificationData) |
  |  POST /verify  { token,       |                                            |
  |    productId, packageName } ->|  purchases.products.get(token) ---------->  |
  |                               |  <---- purchase resource (state, ack...) -- |
  |                               |  dedup token in DB, mark consumed          |
  |  <-- { ok, pointsToCredit } --|                                            |
  |  PointManager.setBalance()    |                                            |
  |  completePurchase()           |                                            |
```

**Principles**
- The app **never** self-credits in Tier 2. It calls `/verify` and applies the server's returned grant.
- The server **acknowledges/consumes** with Google (so Google doesn't auto-refund), OR the app still
  calls `completePurchase()` after the server confirms — pick one owner of acknowledgement (§5).
- Balance becomes **server-authoritative**: `/verify` (and an `/balance` endpoint) return the true total;
  the client stores it only as a display cache.

---

## 2. Backend choice

Any of these works; pick by what you already run:

| Option | Notes |
|---|---|
| **Firebase Cloud Functions** (recommended) | Easiest with a Flutter app; Firebase Auth gives you a per-user id for the ledger; free tier covers low volume |
| Supabase Edge Function + Postgres | If you prefer SQL ledger; you already have Supabase MCP available |
| Any Node/Go micro-service on Cloud Run | Full control; more ops |

The rest of this doc is backend-agnostic; examples use Node-ish pseudocode.

---

## 3. Google Play Developer API access (one-time setup)

1. **Google Cloud project** linked to the Play Console account.
2. Enable **Google Play Android Developer API**.
3. Create a **service account**; in Play Console → *Users & permissions*, grant it access with
   **"View financial data"** + **"Manage orders"** (enough to call `purchases.products.get` and
   `.acknowledge`/`.consume`).
4. Download the service-account **JSON key**; store it as a backend secret (NOT in the app, NOT in git).
5. Backend authenticates to Google with that key (scope
   `https://www.googleapis.com/auth/androidpublisher`).

> The **package name** is your app id (e.g. `com.lancerline.cogniq` — confirm the real one in
> `android/app/build.gradle` `applicationId`).

---

## 4. The verify endpoint

### 4.1 Request (app → backend)
```json
POST /verify
{
  "userId": "<firebase-uid-or-device-id>",
  "productId": "points_1200",
  "purchaseToken": "<PurchaseDetails.verificationData.serverVerificationData>",
  "orderId": "<PurchaseDetails.purchaseID>",
  "platform": "android"
}
```
In Flutter, the token is `purchaseDetails.verificationData.serverVerificationData`.

### 4.2 Backend logic (pseudocode)
```js
async function verify(req) {
  const { userId, productId, purchaseToken, orderId } = req.body;

  // 1. Catalog lookup — server has its OWN copy of the product→points map (never trust client amount)
  const product = SERVER_CATALOG[productId];
  if (!product) return deny('unknown_product');

  // 2. Idempotency — has this token already been redeemed?
  if (await db.tokens.exists(purchaseToken)) return deny('already_redeemed');

  // 3. Ask Google
  const g = await androidpublisher.purchases.products.get({
    packageName: PACKAGE_NAME, productId, token: purchaseToken,
  });
  //  g.purchaseState: 0=purchased, 1=canceled, 2=pending
  //  g.consumptionState: 0=yet to be consumed, 1=consumed
  //  g.acknowledgementState: 0=not ack'd, 1=ack'd
  if (g.purchaseState !== 0) return deny('not_purchased');

  // 4. (Consumables) tell Google it's consumed so it can be re-bought
  if (product.consumable) {
    await androidpublisher.purchases.products.consume({ packageName, productId, token: purchaseToken });
  } else {
    if (g.acknowledgementState === 0)
      await androidpublisher.purchases.products.acknowledge({ packageName, productId, token: purchaseToken });
  }

  // 5. Ledger — record token + credit user, atomically
  await db.transaction(async tx => {
    await tx.tokens.insert({ purchaseToken, orderId, userId, productId, at: now });
    if (product.consumable) await tx.users.incrementPoints(userId, product.points);
    if (product.grantsAdFree) await tx.users.setAdFree(userId, true);
    if (product.kind === 'bundle') await tx.users.grantBundleOnce(userId, product.points);
  });

  const balance = await db.users.getPoints(userId);
  return ok({ pointsBalance: balance, adFree: await db.users.isAdFree(userId) });
}
```

### 4.3 Response (backend → app)
```json
{ "ok": true, "pointsBalance": 3200, "adFree": false }
```
On failure: `{ "ok": false, "reason": "already_redeemed" }` — app shows a message, still calls
`completePurchase()` so Google doesn't keep re-delivering (§5).

---

## 5. Who acknowledges? (pick ONE, avoid double-ack)

Google auto-refunds any purchase not **acknowledged/consumed within 3 days**. Two valid ownership models:

- **Server owns it (recommended):** backend calls `consume` (consumables) / `acknowledge`
  (non-consumables). The app calls `completePurchase()` only as the local plugin bookkeeping after a
  successful `/verify`. Make sure the plugin's local completion doesn't *also* try to consume before the
  server did — on Android `buyConsumable(autoConsume: true)` will consume locally; set
  **`autoConsume: false`** in Tier 2 so the **server** is the sole consumer.
- **Client owns it:** app consumes/acknowledges via the plugin after `/verify` returns ok. Simpler but
  the server can't be certain Google was told.

> Decision to record in code comments: **Tier 2 uses server-side consume, `autoConsume: false`.**

---

## 6. Client (Flutter) changes vs Tier 1

In `PurchaseManager._grant(d)` (from `iq_points_iap_impl.md` §3.3), **replace local granting** with a
verify call:
```dart
Future<void> _grant(PurchaseDetails d) async {
  final product = IapCatalog.byId(d.productID);
  if (product == null) return;

  final token = d.verificationData.serverVerificationData;
  final res = await IapBackend.verify(
    userId: await _currentUserId(),
    productId: d.productID,
    purchaseToken: token,
    orderId: d.purchaseID,
  );

  if (res.ok) {
    await PointManager.setBalance(res.pointsBalance); // NEW setter — server is source of truth
    if (res.adFree) settingsNotifier.setAdsRemoved(true);
    _notify('Purchase confirmed!');
  } else {
    _notify('Could not verify purchase: ${res.reason}');
  }
  // Always complete locally so Google stops re-delivering. autoConsume:false at buy time.
  if (d.pendingCompletePurchase) _iap.completePurchase(d);
}
```
Additional client work:
- Add `PointManager.setBalance(int)` (absolute set, not increment) — needed because server returns the
  true total.
- Change consumable purchase call to `buyConsumable(purchaseParam: param, autoConsume: false)` (§5).
- Add `IapBackend` HTTP client (`/verify`, optional `/balance`).
- On app start, optionally call `/balance` to re-sync the cached points to the server total (recovers
  from local tampering).
- Keep the Tier 1 `processedPurchaseIds` guard as a cheap local pre-filter, but the **server ledger** is
  now the real dedup.

---

## 7. Data model (server ledger)

```
users        (userId PK, points int, adFree bool, bundleGranted bool, updatedAt)
redemptions  (purchaseToken PK, orderId, userId, productId, points, createdAt)
```
- `redemptions.purchaseToken` unique → idempotency.
- Never trust a client-sent point amount; `points` comes from the **server** catalog only.

---

## 8. Server catalog (must mirror the app, but authoritative)

Keep a server-side copy of the product→grant map. **This is the trusted one.**
```js
const SERVER_CATALOG = {
  remove_ads_premium: { kind:'removeAds', consumable:false, points:0,    grantsAdFree:true  },
  starter_bundle:     { kind:'bundle',    consumable:false, points:1500, grantsAdFree:true  },
  points_500:         { kind:'points',    consumable:true,  points:500,  grantsAdFree:false },
  points_1200:        { kind:'points',    consumable:true,  points:1200, grantsAdFree:false },
  points_3000:        { kind:'points',    consumable:true,  points:3000, grantsAdFree:false },
  points_7000:        { kind:'points',    consumable:true,  points:7000, grantsAdFree:false },
};
```
If the app catalog and server catalog disagree, the **server wins**.

---

## 9. Real-time Developer Notifications (optional, catches refunds/voids)

To revoke entitlements on refunds/chargebacks without the app being open:
1. Play Console → *Monetisation setup* → **Real-time developer notifications** → set a Pub/Sub topic.
2. Backend subscribes; on `VOIDED_PURCHASE` / refund notifications, look up the token in `redemptions`
   and deduct points / clear ad-free for that user.
3. Also use `purchases.voidedpurchases.list` on a schedule as a backstop.

Skip at first; add if refund abuse appears.

---

## 10. Edge cases

- [ ] **Offline at verify time** — queue the token locally, retry `/verify` on next launch; do NOT grant
      until server confirms. Show "Purchase pending verification."
- [ ] **Server down** — same as offline; never local-grant in Tier 2 or you reopen the hole.
- [ ] **`/verify` succeeds but app crashes before `completePurchase`** — Google re-delivers; server sees
      token already redeemed → returns current balance, app completes. Idempotent. ✅
- [ ] **User switches Google account / new device** — tie entitlements to your `userId` (Firebase Auth),
      not device; `/balance` restores. For pure device-id users, restore is best-effort.
- [ ] **`autoConsume` mismatch** — if left `true`, plugin consumes before server → server `consume` 400s.
      Ensure `false` (§5).
- [ ] **Clock/`transactionDate`** — don't rely on device time for anything authoritative; server stamps.

---

## 11. Ordered work list

1. Stand up backend (Firebase Functions or Supabase Edge) + service-account access to Play Developer API (§3).
2. Implement `/verify` with Google `purchases.products.get` + `consume`/`acknowledge` + ledger (§4–§5, §7–§8).
3. (Optional) `/balance` re-sync endpoint.
4. Client: add `IapBackend` client, `PointManager.setBalance`, flip `buyConsumable(autoConsume:false)`,
   rewrite `_grant` to verify-then-apply (§6).
5. Startup `/balance` re-sync (recovers from local tampering).
6. (Optional) Real-time Developer Notifications for refund revocation (§9).
7. QA: tamper prefs → next sync corrects; replay token → denied; refund → entitlement revoked (if §9).

> **Relationship to Tier 1:** ship `iq_points_iap_impl.md` first and launch. Layer this on top only when
> the numbers justify the backend. The client `_grant` is the single method that swaps from
> local-credit (Tier 1) to verify-then-apply (Tier 2); everything else (catalog, UI, product IDs) is reused.
