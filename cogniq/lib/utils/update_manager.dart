import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateManager {
  static Future<void> checkForUpdate() async {
    // Only run on Android since in_app_update is Android-only
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable &&
          info.flexibleUpdateAllowed) {
        // Start downloading the flexible update in the background
        await InAppUpdate.startFlexibleUpdate();
        // Once the download finishes, trigger the installation prompt
        await InAppUpdate.completeFlexibleUpdate();
      }
    } catch (_) {
      // Fail silently (offline, Google Play Services unavailable, or user cancelled)
    }
  }
}
