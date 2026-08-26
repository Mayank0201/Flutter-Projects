import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cogniq/utils/prefs_keys.dart';
import 'package:cogniq/utils/review_prompt_manager.dart';
import 'package:cogniq/utils/zen_mode.dart';

class FakeInAppReview implements InAppReview {
  bool available = true;
  int requestReviewCallCount = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async {
    requestReviewCallCount++;
  }

  @override
  Future<void> openStoreListing({String? appStoreId, String? microsoftStoreId}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReviewPromptManager - recordAppOpen', () {
    test('increments distinctDaysOpened once per calendar day', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await ReviewPromptManager.recordAppOpen();
      expect(prefs.getInt(PrefsKeys.distinctDaysOpened), 1);
      final firstDate = prefs.getString(PrefsKeys.lastOpenDate);
      expect(firstDate, isNotNull);

      // Calling again on the same day should not increment
      await ReviewPromptManager.recordAppOpen();
      expect(prefs.getInt(PrefsKeys.distinctDaysOpened), 1);

      // Simulating a different previous date
      await prefs.setString(PrefsKeys.lastOpenDate, '2020-01-01');
      await ReviewPromptManager.recordAppOpen();
      expect(prefs.getInt(PrefsKeys.distinctDaysOpened), 2);
    });
  });

  group('ReviewPromptManager - maybeRequestReview gating', () {
    late FakeInAppReview fakeReview;

    setUp(() async {
      fakeReview = FakeInAppReview();
      await ZenMode.setEnabled(false);
    });

    test('returns early when Zen Mode is enabled', () async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.globalLevelClearedCount: 25,
        PrefsKeys.distinctDaysOpened: 5,
        PrefsKeys.reviewPromptLastShown: 0,
      });
      await ZenMode.setEnabled(true);

      await ReviewPromptManager.maybeRequestReview(reviewInstance: fakeReview);
      expect(fakeReview.requestReviewCallCount, 0);
    });

    test('returns early when levels completed < 20', () async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.globalLevelClearedCount: 19,
        PrefsKeys.distinctDaysOpened: 5,
        PrefsKeys.reviewPromptLastShown: 0,
      });

      await ReviewPromptManager.maybeRequestReview(reviewInstance: fakeReview);
      expect(fakeReview.requestReviewCallCount, 0);
    });

    test('returns early when distinct days opened < 3', () async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.globalLevelClearedCount: 25,
        PrefsKeys.distinctDaysOpened: 2,
        PrefsKeys.reviewPromptLastShown: 0,
      });

      await ReviewPromptManager.maybeRequestReview(reviewInstance: fakeReview);
      expect(fakeReview.requestReviewCallCount, 0);
    });

    test('returns early when prompted within 90 days', () async {
      final recentTimestamp = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        PrefsKeys.globalLevelClearedCount: 25,
        PrefsKeys.distinctDaysOpened: 5,
        PrefsKeys.reviewPromptLastShown: recentTimestamp,
      });

      await ReviewPromptManager.maybeRequestReview(reviewInstance: fakeReview);
      expect(fakeReview.requestReviewCallCount, 0);
    });

    test('returns early when in_app_review is not available on platform', () async {
      fakeReview.available = false;
      SharedPreferences.setMockInitialValues({
        PrefsKeys.globalLevelClearedCount: 25,
        PrefsKeys.distinctDaysOpened: 5,
        PrefsKeys.reviewPromptLastShown: 0,
      });

      await ReviewPromptManager.maybeRequestReview(reviewInstance: fakeReview);
      expect(fakeReview.requestReviewCallCount, 0);
    });

    test('requests review and records timestamp when all gates pass (first time)', () async {
      SharedPreferences.setMockInitialValues({
        PrefsKeys.globalLevelClearedCount: 20,
        PrefsKeys.distinctDaysOpened: 3,
        PrefsKeys.reviewPromptLastShown: 0,
      });
      final prefs = await SharedPreferences.getInstance();

      await ReviewPromptManager.maybeRequestReview(reviewInstance: fakeReview);
      expect(fakeReview.requestReviewCallCount, 1);
      final lastShown = prefs.getInt(PrefsKeys.reviewPromptLastShown);
      expect(lastShown, isNotNull);
      expect(lastShown, isNonZero);
    });

    test('requests review and updates timestamp when last prompt was > 90 days ago', () async {
      final oldTimestamp = DateTime.now().subtract(const Duration(days: 95)).millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        PrefsKeys.globalLevelClearedCount: 30,
        PrefsKeys.distinctDaysOpened: 10,
        PrefsKeys.reviewPromptLastShown: oldTimestamp,
      });
      final prefs = await SharedPreferences.getInstance();

      await ReviewPromptManager.maybeRequestReview(reviewInstance: fakeReview);
      expect(fakeReview.requestReviewCallCount, 1);
      final lastShown = prefs.getInt(PrefsKeys.reviewPromptLastShown);
      expect(lastShown! > oldTimestamp, isTrue);
    });
  });
}
