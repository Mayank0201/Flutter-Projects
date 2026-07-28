import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/settings_manager.dart';
import 'point_manager.dart';
import 'prefs_keys.dart';
import 'iap_catalog.dart';
import 'iap_backend.dart';

class PurchaseManager {
  static InAppPurchase get _iap => InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;

  static List<ProductDetails> products = [];
  static bool isStoreAvailable = false;

  /// Initialize and start listening to the purchase stream
  static Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('PurchaseManager: Store is disabled on Web.');
      isStoreAvailable = false;
      return;
    }

    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _handlePurchaseUpdates(purchaseDetailsList);
      },
      onDone: () {
        _subscription?.cancel();
      },
      onError: (error) {
        debugPrint('PurchaseManager Error: $error');
      },
    );

    // Check store availability
    isStoreAvailable = await _iap.isAvailable();
    if (isStoreAvailable) {
      await loadProducts();
    } else {
      debugPrint('PurchaseManager: Store is not available.');
    }
  }

  /// Fetch product details from Google Play / App Store
  static Future<void> loadProducts() async {
    final ids = IapCatalog.allIds;
    try {
      final response = await _iap.queryProductDetails(ids);
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('PurchaseManager: Products not found: ${response.notFoundIDs}');
      }
      products = response.productDetails;
      debugPrint('PurchaseManager: Loaded ${products.length} products.');
    } catch (e) {
      debugPrint('PurchaseManager: Failed to load products: $e');
    }
  }

  static ProductDetails? detailsFor(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Launch the checkout flow for a generic catalog product
  static Future<void> buy(
    IapProduct product, {
    required VoidCallback onStoreUnavailable,
    required VoidCallback onProductNotFound,
  }) async {
    if (!isStoreAvailable) {
      onStoreUnavailable();
      return;
    }

    ProductDetails? details = detailsFor(product.id);
    if (details == null) {
      // Retry loading once
      await loadProducts();
      details = detailsFor(product.id);
    }

    if (details == null) {
      onProductNotFound();
      return;
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: details);
    if (product.consumable) {
      await _iap.buyConsumable(purchaseParam: purchaseParam, autoConsume: true);
    } else {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    }
  }

  /// Backward compatible helper to buy Remove Ads
  static Future<void> buyAdFree({
    required VoidCallback onStoreUnavailable,
    required VoidCallback onProductNotFound,
  }) async {
    await buy(
      IapCatalog.removeAds,
      onStoreUnavailable: onStoreUnavailable,
      onProductNotFound: onProductNotFound,
    );
  }

  /// Restore past purchases (non-consumables)
  static Future<void> restorePurchases({
    required Function(bool success) onRestoreFinished,
  }) async {
    if (!isStoreAvailable) {
      onRestoreFinished(false);
      return;
    }
    try {
      await _iap.restorePurchases();
      // Wait briefly for the stream listener to capture restored items
      await Future.delayed(const Duration(seconds: 1));
      onRestoreFinished(true);
    } catch (e) {
      debugPrint('PurchaseManager Restore failed: $e');
      onRestoreFinished(false);
    }
  }

  /// Handle purchase updates from stream
  static void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('PurchaseManager: Purchase pending...');
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        debugPrint('PurchaseManager error: ${purchaseDetails.error}');
        if (purchaseDetails.pendingCompletePurchase) {
          _iap.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                 purchaseDetails.status == PurchaseStatus.restored) {
        _grant(purchaseDetails);
      }
    }
  }

  static Future<void> _grant(PurchaseDetails d) async {
    final product = IapCatalog.byId(d.productID);
    if (product == null) {
      if (d.pendingCompletePurchase) {
        await _iap.completePurchase(d);
      }
      return;
    }

    // 1. Consumable Points Packs
    if (product.consumable) {
      final purchaseId = d.purchaseID ?? '';
      if (purchaseId.isNotEmpty) {
        if (await _alreadyProcessed(purchaseId)) {
          await _consumeIfNeeded(d);
          if (d.pendingCompletePurchase) {
            await _iap.completePurchase(d);
          }
          return;
        }
      }

      final verifyRes = await IapBackend.verify(
        userId: 'local_user',
        productId: d.productID,
        purchaseToken: d.verificationData.serverVerificationData,
        orderId: purchaseId,
      );

      if (verifyRes.ok) {
        await PointManager.setBalance(verifyRes.pointsBalance);
        if (purchaseId.isNotEmpty) {
          await _markProcessed(purchaseId);
        }
        await _consumeIfNeeded(d);
        debugPrint('PurchaseManager: Successfully credited ${product.points} points.');
      } else {
        debugPrint('PurchaseManager Verification failed: ${verifyRes.reason}');
      }
    } else {
      // 2. Non-Consumables (removeAds, bundle)
      final verifyRes = await IapBackend.verify(
        userId: 'local_user',
        productId: d.productID,
        purchaseToken: d.verificationData.serverVerificationData,
        orderId: d.purchaseID ?? '',
      );

      if (verifyRes.ok) {
        if (verifyRes.adFree) {
          settingsNotifier.setAdsRemoved(true);
        }

        if (product.kind == IapKind.bundle) {
          final prefs = await SharedPreferences.getInstance();
          final alreadyGranted = prefs.getBool(PrefsKeys.bundleGranted) ?? false;
          if (!alreadyGranted) {
            await PointManager.setBalance(verifyRes.pointsBalance);
            await prefs.setBool(PrefsKeys.bundleGranted, true);
          }
        }
      }
    }

    if (d.pendingCompletePurchase) {
      await _iap.completePurchase(d);
    }
  }

  static Future<bool> _alreadyProcessed(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final processed = prefs.getStringList(PrefsKeys.processedPurchaseIds) ?? [];
    return processed.contains(id);
  }

  static Future<void> _markProcessed(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> processed = prefs.getStringList(PrefsKeys.processedPurchaseIds) ?? [];
    if (!processed.contains(id)) {
      processed.add(id);
      if (processed.length > 200) {
        processed = processed.sublist(processed.length - 200);
      }
      await prefs.setStringList(PrefsKeys.processedPurchaseIds, processed);
    }
  }

  static Future<void> _consumeIfNeeded(PurchaseDetails d) async {
    // Android autoConsume handles it natively.
  }

  static void dispose() {
    _subscription?.cancel();
  }
}
