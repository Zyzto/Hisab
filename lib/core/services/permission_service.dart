import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/supabase_config.dart';
import '../layout/layout_breakpoints.dart';
import '../layout/responsive_sheet.dart';
import '../widgets/sheet_helpers.dart';
import 'request_notification_permission_stub.dart'
    if (dart.library.html) 'request_notification_permission_web.dart'
    as browser_notification;

/// Centralized permission handling.
///
/// All methods are static and take [BuildContext] so they can show a
/// non-blocking dialog when a permission is permanently denied.
/// On web, camera/photos are skipped; notification permission is requested via
/// Firebase Messaging when Firebase is initialized.
class PermissionService {
  PermissionService._();

  // ───────────────────── Public API ─────────────────────

  /// Request camera permission. Returns `true` when granted.
  ///
  /// Shows an explanatory dialog with "Open Settings" when permanently denied.
  static Future<bool> requestCameraPermission(BuildContext context) async {
    if (kIsWeb) return true;
    return _requestPermission(
      context,
      Permission.camera,
      'permission_camera_message'.tr(),
    );
  }

  /// Request photo-library permission. Returns `true` when granted.
  ///
  /// Shows an explanatory dialog with "Open Settings" when permanently denied.
  static Future<bool> requestPhotosPermission(BuildContext context) async {
    if (kIsWeb) return true;
    return _requestPermission(
      context,
      Permission.photos,
      'permission_photos_message'.tr(),
    );
  }

  /// Request notification permission. Returns `true` when granted.
  ///
  /// Shows an explanatory dialog with "Open Settings" when permanently denied.
  /// On web, triggers the browser's native notification permission prompt
  /// so the user always sees a dialog when tapping Allow.
  static Future<bool> requestNotificationPermission(
    BuildContext context,
  ) async {
    if (kIsWeb) {
      final granted =
          await browser_notification.requestBrowserNotificationPermission();
      if (!granted) return false;
      if (!firebaseInitialized) return true;
      try {
        final messaging = FirebaseMessaging.instance;
        final settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        return settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      } catch (_) {
        return true;
      }
    }
    return _requestPermission(
      context,
      Permission.notification,
      'permission_notification_message'.tr(),
    );
  }

  /// Whether notification permission is currently granted (no request).
  static Future<bool> isNotificationPermissionGranted() async {
    if (kIsWeb) return browser_notification.isBrowserNotificationPermissionGranted();
    final status = await Permission.notification.status;
    return status.isGranted || status.isLimited;
  }

  /// Whether camera permission is currently granted (no request).
  static Future<bool> isCameraPermissionGranted() async {
    if (kIsWeb) return true;
    final status = await Permission.camera.status;
    return status.isGranted || status.isLimited;
  }

  /// Show the "notifications are disabled" dialog without requesting again.
  /// Useful when the Firebase permission check already ran and was denied.
  static void showNotificationDeniedInfo(BuildContext context) {
    if (kIsWeb || !context.mounted) return;
    _showPermissionDeniedDialog(
      context,
      'permission_notification_message'.tr(),
    );
  }

  // ───────────────────── Private helpers ─────────────────────

  /// Core flow: check → request → show dialog if permanently denied.
  static Future<bool> _requestPermission(
    BuildContext context,
    Permission permission,
    String deniedMessage,
  ) async {
    var status = await permission.status;

    if (status.isGranted || status.isLimited) return true;

    // First time: ask the OS.
    if (status.isDenied) {
      status = await permission.request();
      if (status.isGranted || status.isLimited) return true;
    }

    // Permanently denied — show a dialog pointing to Settings.
    if (status.isPermanentlyDenied && context.mounted) {
      _showPermissionDeniedDialog(context, deniedMessage);
    }

    return false;
  }

  /// Non-blocking sheet explaining the denied permission with an
  /// "Open Settings" button. Never blocks app usage.
  static void _showPermissionDeniedDialog(
    BuildContext context,
    String message,
  ) {
    if (!context.mounted) return;
    showResponsiveSheet<void>(
      context: context,
      title: 'permission_denied_title'.tr(),
      maxHeight: MediaQuery.of(context).size.height * 0.4,
      isScrollControlled: true,
      centerInFullViewport: true,
      child: Builder(
        builder: (ctx) => buildSheetShell(
          ctx,
          title: 'permission_denied_title'.tr(),
          showTitleInBody: !LayoutBreakpoints.isTabletOrWider(context),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(message),
          ),
          actions: [
            if (!LayoutBreakpoints.isTabletOrWider(context))
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('permission_cancel'.tr()),
              ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                openAppSettings();
              },
              child: Text('permission_open_settings'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
