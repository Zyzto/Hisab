import 'package:flutter/foundation.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:upgrader/upgrader.dart';

/// On Android, tries the native in-app update first; if unavailable or denied,
/// opens the Play Store using [upgrader]. Call from [UpgradeAlert.onUpdate]
/// when user taps "Update now" (return false from onUpdate so upgrader doesn't
/// also open the store).
Future<void> handleAndroidUpdateThenStore(Upgrader upgrader) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }

  try {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability == UpdateAvailability.updateAvailable) {
      final result = await InAppUpdate.performImmediateUpdate();
      if (result == AppUpdateResult.success) return;
    }
  } catch (e) {
    Log.debug('In-app update unavailable; falling back to store', error: e);
  }

  await upgrader.sendUserToAppStore();
}
