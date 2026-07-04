import 'dart:async';
import 'package:flutter/foundation.dart';

class AdManager {
  static String get interstitialAdUnitId => '';
  static String get rewardedAdUnitId => '';

  static Future<void> initialize() async {
    debugPrint('AdManager: Ads are disabled on Web. Skipping initialization.');
  }

  static void loadInterstitial() {}
  static void loadRewarded() {}

  static bool isRewardedAdReady() => false;

  static void showInterstitialAd() {
    debugPrint('AdManager: Ads are disabled on Web. Skipping Interstitial.');
  }

  static void showRewardedAd({
    required Function(int amount) onRewardGranted,
    required VoidCallback onAdNotReady,
  }) {
    debugPrint('AdManager: Ads are disabled on Web. Triggering fallback.');
    onAdNotReady();
  }
}
