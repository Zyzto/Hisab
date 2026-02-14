import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Centralized permission handling.
///
/// All methods are static and take [BuildContext] so they can show a
/// non-blocking dialog when a permission is permanently denied.
/// On web, permission checks are skipped (browser handles prompts natively).
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
  static Future<bool> requestNotificationPermission(
    BuildContext context,
  ) async {
    if (kIsWeb) return true;
    return _requestPermission(
      context,
      Permission.notification,
      'permission_notification_message'.tr(),
    );
  }

  /// Show the "notifications are disabled" dialog without requesting again.
  /// Useful when the Firebase permission check already ran and was denied.
  static void showNotificationDeniedInfo(BuildContext context) {
    if (kIsWeb) return;
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

  /// Non-blocking dialog explaining the denied permission with an
  /// "Open Settings" button. Never blocks app usage.
  static void _showPermissionDeniedDialog(
    BuildContext context,
    String message,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('permission_denied_title'.tr()),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('permission_cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: Text('permission_open_settings'.tr()),
          ),
        ],
      ),
    );
  }
}
