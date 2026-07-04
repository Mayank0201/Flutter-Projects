import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../theme/settings_manager.dart';

class AdManager {
  static InterstitialAd? _interstitialAd;
  static RewardedAd? _rewardedAd;

  static bool _isInterstitialLoading = false;
  static bool _isRewardedLoading = false;

  // Track retry counts for exponential backoff
  static int _interstitialRetryCount = 0;
  static int _rewardedRetryCount = 0;

  // Real vs Test Ad Unit IDs
  static String get interstitialAdUnitId {
    if (kDebugMode) {
      // Google's official Android/iOS interstitial test ad unit ID
      return 'ca-app-pub-3940256099942544/1033173712';
    }
    return 'ca-app-pub-3956033847102460/4214771278';
  }

  static String get rewardedAdUnitId {
    if (kDebugMode) {
      // Google's official Android/iOS rewarded test ad unit ID
      return 'ca-app-pub-3940256099942544/5224354917';
    }
    return 'ca-app-pub-3956033847102460/7535944897';
  }

  /// Initialize and preload the first ads
  static Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint(
        'AdManager: Ads are disabled on web. Skipping initialization.',
      );
      return;
    }

    await MobileAds.instance.initialize();
    loadInterstitial();
    loadRewarded();
  }

  /// Preload Interstitial Ad
  static void loadInterstitial() {
    if (kIsWeb) return;
    if (settingsNotifier.adsRemoved) return;
    if (_interstitialAd != null || _isInterstitialLoading) return;

    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          _interstitialRetryCount = 0;
          debugPrint('AdManager: InterstitialAd loaded successfully.');
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isInterstitialLoading = false;
          _interstitialRetryCount++;
          debugPrint(
            'AdManager: InterstitialAd failed to load: $error. Retrying...',
          );

          // Retry with basic backoff (max 1 minute)
          final delay = Duration(
            seconds: (_interstitialRetryCount * 10).clamp(5, 60),
          );
          Timer(delay, () => loadInterstitial());
        },
      ),
    );
  }

  /// Preload Rewarded Ad
  static void loadRewarded() {
    if (kIsWeb) return;
    if (_rewardedAd != null || _isRewardedLoading) return;

    _isRewardedLoading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
          _rewardedRetryCount = 0;
          debugPrint('AdManager: RewardedAd loaded successfully.');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isRewardedLoading = false;
          _rewardedRetryCount++;
          debugPrint(
            'AdManager: RewardedAd failed to load: $error. Retrying...',
          );

          final delay = Duration(
            seconds: (_rewardedRetryCount * 10).clamp(5, 60),
          );
          Timer(delay, () => loadRewarded());
        },
      ),
    );
  }

  /// Check if a Rewarded ad is loaded and ready
  static bool isRewardedAdReady() {
    if (kIsWeb) return false;
    return _rewardedAd != null;
  }

  /// Show Interstitial Ad if available and ads are not removed
  static void showInterstitialAd() {
    if (kIsWeb) return;
    if (settingsNotifier.adsRemoved) {
      debugPrint('AdManager: Ads are removed. Skipping Interstitial.');
      return;
    }

    if (_interstitialAd == null) {
      debugPrint('AdManager: Interstitial ad is not ready. Loading one now.');
      loadInterstitial();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('AdManager: Interstitial ad showed.');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('AdManager: Interstitial ad dismissed. Preloading next.');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdManager: Interstitial ad failed to show: $error.');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitial();
      },
    );

    _interstitialAd!.show();
    _interstitialAd = null;
  }

  /// Show Rewarded Ad and trigger callback on earned reward
  static void showRewardedAd({
    required Function(int amount) onRewardGranted,
    required VoidCallback onAdNotReady,
  }) {
    if (kIsWeb) {
      onAdNotReady();
      return;
    }

    if (_rewardedAd == null) {
      debugPrint('AdManager: Rewarded ad is not ready. Loading one now.');
      onAdNotReady();
      loadRewarded();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('AdManager: Rewarded ad showed.');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('AdManager: Rewarded ad dismissed. Preloading next.');
        ad.dispose();
        _rewardedAd = null;
        loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdManager: Rewarded ad failed to show: $error.');
        ad.dispose();
        _rewardedAd = null;
        loadRewarded();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        debugPrint(
          'AdManager: User earned reward: ${reward.amount} ${reward.type}',
        );
        // Default to +2 hints if reward amount is 0/unspecified in mock, or use reward.amount
        final amount = reward.amount.toInt() > 0 ? reward.amount.toInt() : 2;
        onRewardGranted(amount);
      },
    );
    _rewardedAd = null;
  }
}
