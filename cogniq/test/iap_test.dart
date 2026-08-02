import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cogniq/utils/purchase_manager.dart';
import 'package:cogniq/utils/point_manager.dart';
import 'package:cogniq/utils/iap_catalog.dart';
import 'package:cogniq/utils/prefs_keys.dart';

// Hand-written mock implementation for InAppPurchase class
class MockInAppPurchase implements InAppPurchase {
  bool isStoreAvailable = true;
  final StreamController<List<PurchaseDetails>> _purchaseStreamController =
      StreamController<List<PurchaseDetails>>.broadcast();
  List<ProductDetails> mockProducts = [];
  final List<PurchaseDetails> completedPurchases = [];

  @override
  Future<bool> isAvailable() async => isStoreAvailable;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _purchaseStreamController.stream;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async {
    final found = mockProducts.where((p) => identifiers.contains(p.id)).toList();
    final notFound = identifiers.where((id) => !mockProducts.any((p) => p.id == id)).toList();
    return ProductDetailsResponse(productDetails: found, notFoundIDs: notFound);
  }

  @override
  Future<bool> buyConsumable({required PurchaseParam purchaseParam, bool autoConsume = true}) async {
    return true;
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    return true;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchases.add(purchase);
  }

  @override
  Future<String> countryCode() async => 'IN';

  @override
  T getPlatformAddition<T extends InAppPurchasePlatformAddition?>() {
    throw UnimplementedError('getPlatformAddition is not implemented in MockInAppPurchase');
  }

  void sendPurchaseUpdate(List<PurchaseDetails> updates) {
    _purchaseStreamController.add(updates);
  }
}

// Simple concrete subclass of ProductDetails for testing
class TestProductDetails implements ProductDetails {
  @override
  final String id;
  @override
  final String title;
  @override
  final String description;
  @override
  final String price;
  @override
  final double rawPrice;
  @override
  final String currencyCode;
  @override
  final String currencySymbol;

  TestProductDetails({
    required this.id,
    this.title = 'Test Product',
    this.description = 'Test Description',
    this.price = '₹59.00',
    this.rawPrice = 59.0,
    this.currencyCode = 'INR',
    this.currencySymbol = '₹',
  });
}

// Simple implementation of PurchaseDetails for testing
class TestPurchaseDetails implements PurchaseDetails {
  @override
  final String? purchaseID;
  @override
  final String productID;
  @override
  final PurchaseVerificationData verificationData;
  @override
  final String? transactionDate;
  @override
  PurchaseStatus status;
  @override
  IAPError? error;
  @override
  bool pendingCompletePurchase;

  TestPurchaseDetails({
    required this.purchaseID,
    required this.productID,
    required this.status,
    this.transactionDate,
    this.error,
    this.pendingCompletePurchase = true,
  }) : verificationData = PurchaseVerificationData(
          localVerificationData: 'local_data',
          serverVerificationData: 'server_data',
          source: 'google_play',
        );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockInAppPurchase mockIap;

  setUp(() async {
    mockIap = MockInAppPurchase();
    PurchaseManager.iapInstance = mockIap;

    // Seed shared preferences with fresh slate
    SharedPreferences.setMockInitialValues({});
    await PointManager.setBalance(100);

    // Seed mock products
    mockIap.mockProducts = IapCatalog.all
        .map((p) => TestProductDetails(id: p.id, title: p.title))
        .toList();

    PurchaseManager.purchaseStateNotifier.value = PurchaseState.idle;
  });

  tearDown(() {
    PurchaseManager.dispose();
  });

  group('IAP Flow Automated Checks', () {
    test('Initialize and Load Products', () async {
      await PurchaseManager.initialize();
      expect(PurchaseManager.isStoreAvailable, true);
      expect(PurchaseManager.products.length, IapCatalog.all.length);
    });

    test('Test A: Long Payment Delay sets Pending state correctly', () async {
      await PurchaseManager.initialize();

      // Trigger purchase
      bool storeUnavailable = false;
      bool productNotFound = false;
      
      final purchaseFuture = PurchaseManager.buy(
        IapCatalog.points1200,
        onStoreUnavailable: () => storeUnavailable = true,
        onProductNotFound: () => productNotFound = true,
      );

      // Yield control for 50ms so that the asynchronous initialization in buy() runs
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify immediately enters pending state and locks
      expect(PurchaseManager.purchaseStateNotifier.value, PurchaseState.pending);
      expect(storeUnavailable, false);
      expect(productNotFound, false);

      await purchaseFuture;
      // Stays pending because payment sheet is active and stream hasn't responded
      expect(PurchaseManager.purchaseStateNotifier.value, PurchaseState.pending);
    });

    test('Test B: Cancellation Lifecycle completes and unlocks queue', () async {
      await PurchaseManager.initialize();

      // Trigger buy flow to enter pending state
      await PurchaseManager.buy(
        IapCatalog.points1200,
        onStoreUnavailable: () {},
        onProductNotFound: () {},
      );

      // Yield control to let async parts of buy run
      await Future.delayed(const Duration(milliseconds: 50));
      expect(PurchaseManager.purchaseStateNotifier.value, PurchaseState.pending);

      // Simulate native sheet cancel update via stream
      final cancelUpdate = TestPurchaseDetails(
        purchaseID: 'tx_cancel_1',
        productID: IapCatalog.points1200.id,
        status: PurchaseStatus.canceled,
      );
      
      mockIap.sendPurchaseUpdate([cancelUpdate]);

      // Allow microtasks to process stream event
      await Future.delayed(Duration.zero);

      // Verify unlocks and resets
      expect(PurchaseManager.purchaseStateNotifier.value, PurchaseState.canceled);
      expect(mockIap.completedPurchases.length, 1);
      expect(mockIap.completedPurchases.first.purchaseID, 'tx_cancel_1');
    });

    test('Test C: Airplane Mode dynamically blocks buy flow', () async {
      await PurchaseManager.initialize();

      // Simulate toggle to airplane mode
      mockIap.isStoreAvailable = false;

      bool storeUnavailable = false;
      await PurchaseManager.buy(
        IapCatalog.points1200,
        onStoreUnavailable: () => storeUnavailable = true,
        onProductNotFound: () {},
      );

      expect(storeUnavailable, true);
      expect(PurchaseManager.purchaseStateNotifier.value, PurchaseState.idle);
    });

    test('Test D: Null Transaction IDs credit points and resolve duplicates via composite key', () async {
      await PurchaseManager.initialize();

      // First purchase with null ID
      final purchase1 = TestPurchaseDetails(
        purchaseID: null,
        productID: IapCatalog.points1200.id,
        status: PurchaseStatus.purchased,
        transactionDate: '2026-07-31_12-00-00',
      );

      mockIap.sendPurchaseUpdate([purchase1]);
      await Future.delayed(Duration.zero);

      // Verify points credited (+1200 points on top of initial 100)
      int balance = await PointManager.getPoints();
      expect(balance, 1300);
      expect(PurchaseManager.purchaseStateNotifier.value, PurchaseState.success);

      // Second purchase with null ID (same product, but unique transactionDate/epoch timestamp)
      final purchase2 = TestPurchaseDetails(
        purchaseID: null,
        productID: IapCatalog.points1200.id,
        status: PurchaseStatus.purchased,
        transactionDate: '2026-07-31_12-01-00',
      );

      mockIap.sendPurchaseUpdate([purchase2]);
      await Future.delayed(Duration.zero);

      // Verify points credited a second time (+1200 points to 2500)
      balance = await PointManager.getPoints();
      expect(balance, 2500);
      expect(PurchaseManager.purchaseStateNotifier.value, PurchaseState.success);
    });
  });
}
