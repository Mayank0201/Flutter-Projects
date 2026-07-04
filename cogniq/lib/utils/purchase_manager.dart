import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../theme/settings_manager.dart';

class PurchaseManager {
  static const String adFreeProductId = 'remove_ads_premium';

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
    const Set<String> ids = {adFreeProductId};
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

  /// Launch the checkout flow for Ad-Free Premium
  static Future<void> buyAdFree({
    required VoidCallback onStoreUnavailable,
    required VoidCallback onProductNotFound,
  }) async {
    if (!isStoreAvailable) {
      onStoreUnavailable();
      return;
    }

    ProductDetails? product;
    for (final p in products) {
      if (p.id == adFreeProductId) {
        product = p;
        break;
      }
    }

    if (product == null) {
      // Retry loading once
      await loadProducts();
      for (final p in products) {
        if (p.id == adFreeProductId) {
          product = p;
          break;
        }
      }
    }

    if (product == null) {
      onProductNotFound();
      return;
    }

    _triggerPurchase(product);
  }

  static void _triggerPurchase(ProductDetails product) {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Restore past purchases
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
        if (purchaseDetails.productID == adFreeProductId) {
          debugPrint('PurchaseManager: Ad-free premium purchased/restored successfully.');
          settingsNotifier.setAdsRemoved(true);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  static void dispose() {
    _subscription?.cancel();
  }
}
