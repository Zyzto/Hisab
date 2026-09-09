import 'package:flutter/foundation.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';

import '../build_env.dart';
import '../constants/app_config.dart';

/// Obtainium opens the existing Hisab source entry when it is already being
/// tracked, or its Add App screen when it is not. Keeping the source URL here
/// means a staging build never sends users to the production Play listing.
Uri get testUpdateSourceUri => Uri(
  scheme: 'obtainium',
  host: 'add',
  queryParameters: {'url': sourceCodeUrl},
);

/// Opens the Obtainium source for the staging app, falling back to the public
/// GitHub releases page when Obtainium is not installed.
Future<bool> openTestUpdateSource() async {
  if (kIsWeb ||
      !isStagingBuild ||
      defaultTargetPlatform != TargetPlatform.android) {
    return false;
  }

  try {
    if (await launchUrl(
      testUpdateSourceUri,
      mode: LaunchMode.externalApplication,
    )) {
      return true;
    }
  } catch (e) {
    Log.debug(
      'Obtainium update source unavailable; opening releases page',
      error: e,
    );
  }

  try {
    return await launchUrl(
      Uri.parse('$sourceCodeUrl/releases'),
      mode: LaunchMode.externalApplication,
    );
  } catch (e) {
    Log.debug('Opening test releases page failed', error: e);
    return false;
  }
}

/// On Android, tries the native in-app update first; if unavailable or denied,
/// opens the Play Store using [upgrader]. Call from [UpgradeAlert.onUpdate]
/// when user taps "Update now" (return false from onUpdate so upgrader doesn't
/// also open the store).
Future<void> handleAndroidUpdateThenStore(Upgrader upgrader) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }

  if (isStagingBuild) {
    await openTestUpdateSource();
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
