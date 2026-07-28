import 'point_manager.dart';
import 'iap_catalog.dart';

class IapBackendResponse {
  final bool ok;
  final int pointsBalance;
  final bool adFree;
  final String? reason;

  IapBackendResponse({
    required this.ok,
    required this.pointsBalance,
    required this.adFree,
    this.reason,
  });
}

class IapBackend {
  // Define endpoint URL here once backend verification server is deployed (Tier 2)
  static const String _verifyUrl = '';

  static Future<IapBackendResponse> verify({
    required String userId,
    required String productId,
    required String purchaseToken,
    required String orderId,
  }) async {
    if (_verifyUrl.isNotEmpty) {
      try {
        // Placeholder for real HTTP call:
        // final response = await http.post(
        //   Uri.parse(_verifyUrl),
        //   body: jsonEncode({
        //     'userId': userId,
        //     'productId': productId,
        //     'purchaseToken': purchaseToken,
        //     'orderId': orderId,
        //     'platform': 'android',
        //   }),
        // );
        // ...
      } catch (e) {
        return IapBackendResponse(
          ok: false,
          pointsBalance: 0,
          adFree: false,
          reason: e.toString(),
        );
      }
    }

    // Default Tier 1 Local Fallback (automatically grants points & ad-free status)
    final product = IapCatalog.byId(productId);
    final currentPoints = await PointManager.getPoints();
    final bool adFree = product?.grantsAdFree ?? false;
    final int pointsToGrant = product?.points ?? 0;

    return IapBackendResponse(
      ok: true,
      pointsBalance: currentPoints + pointsToGrant,
      adFree: adFree,
    );
  }
}
