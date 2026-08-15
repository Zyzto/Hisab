import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/firebase_config.dart';
import '../layout/layout_breakpoints.dart';
import '../layout/responsive_sheet.dart';
import '../pwa/pwa_capabilities.dart';
import '../theme/accent_style.dart';
import '../widgets/pwa_install_guide_sheet.dart';
import '../widgets/sheet_helpers.dart';
import '../widgets/toast.dart';
import 'request_notification_permission_stub.dart'
    if (dart.library.html) 'request_notification_permission_web.dart'
    as browser_notification;

/// Centralized permission handling.
///
/// All methods are static and take [BuildContext] so they can show a
/// non-blocking dialog when a permission is permanently denied.
/// On web, camera/photos are skipped; notification permission is requested via
/// the browser Notification API (and FCM when Firebase is initialized).
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
  /// so the user always sees a dialog when tapping Allow. On iOS Safari /
  /// WebKit in the browser tab, guides the user to install the PWA first.
  static Future<bool> requestNotificationPermission(
    BuildContext context,
  ) async {
    if (kIsWeb) {
      return _requestWebNotificationPermission(context);
    }
    return _requestPermission(
      context,
      Permission.notification,
      'permission_notification_message'.tr(),
    );
  }

  /// Whether notification permission is currently granted (no request).
  static Future<bool> isNotificationPermissionGranted() async {
    if (kIsWeb) {
      if (pwaNotificationSupport == PwaNotificationSupport.needsInstall) {
        return false;
      }
      return browser_notification.isBrowserNotificationPermissionGranted();
    }
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
    if (!context.mounted) return;
    if (kIsWeb) {
      if (pwaNotificationSupport == PwaNotificationSupport.needsInstall) {
        _showWebNeedsInstallSheet(context);
        return;
      }
      _showPermissionDeniedDialog(
        context,
        'permission_notification_message_web'.tr(),
        showOpenSettings: false,
      );
      return;
    }
    _showPermissionDeniedDialog(
      context,
      'permission_notification_message'.tr(),
    );
  }

  // ───────────────────── Private helpers ─────────────────────

  static Future<bool> _requestWebNotificationPermission(
    BuildContext context,
  ) async {
    final support = pwaNotificationSupport;
    if (support == PwaNotificationSupport.unsupported ||
        !browser_notification.isBrowserNotificationApiSupported()) {
      if (context.mounted) {
        context.showToast('notifications_unsupported_browser'.tr());
      }
      return false;
    }
    if (support == PwaNotificationSupport.needsInstall) {
      if (context.mounted) {
        await _showWebNeedsInstallSheet(context);
      }
      return false;
    }

    final granted = await browser_notification
        .requestBrowserNotificationPermission();
    if (!granted) {
      if (context.mounted) {
        showNotificationDeniedInfo(context);
      }
      return false;
    }
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

  static Future<void> _showWebNeedsInstallSheet(BuildContext context) async {
    if (!context.mounted) return;
    final isTablet = LayoutBreakpoints.isTabletOrWider(context);
    final title = 'permission_notification_needs_install_title'.tr();
    await showResponsiveSheet<void>(
      context: context,
      title: title,
      maxHeight: MediaQuery.of(context).size.height * 0.55,
      isScrollControlled: true,
      centerInFullViewport: true,
      child: Builder(
        builder: (ctx) => buildSheetShell(
          ctx,
          title: title,
          showTitleInBody: !isTablet,
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'permission_notification_needs_install'.tr(),
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('permission_cancel'.tr()),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (context.mounted) {
                  showPwaInstallGuide(context);
                }
              },
              child: Text('install_app_how_to'.tr()),
            ),
          ],
        ),
      ),
    );
  }

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

  /// Non-blocking sheet explaining the denied permission.
  /// Never blocks app usage.
  static void _showPermissionDeniedDialog(
    BuildContext context,
    String message, {
    bool showOpenSettings = true,
  }) {
    if (!context.mounted) return;
    final isTablet = LayoutBreakpoints.isTabletOrWider(context);
    showResponsiveSheet<void>(
      context: context,
      title: 'permission_denied_title'.tr(),
      // Short copy — keep a modest cap; shell shrink-wraps to content.
      maxHeight: MediaQuery.of(context).size.height * 0.5,
      isScrollControlled: true,
      centerInFullViewport: true,
      child: Builder(
        builder: (ctx) {
          final cs = Theme.of(ctx).colorScheme;
          return buildSheetShell(
            ctx,
            title: 'permission_denied_title'.tr(),
            showTitleInBody: !isTablet,
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DecoratedBox(
                decoration: AccentSurfaces.flatPanel(cs),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    message,
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              if (!isTablet || !showOpenSettings)
                showOpenSettings
                    ? TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text('permission_cancel'.tr()),
                      )
                    : FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text('install_app_got_it'.tr()),
                      ),
              if (showOpenSettings)
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    openAppSettings();
                  },
                  child: Text('permission_open_settings'.tr()),
                ),
            ],
          );
        },
      ),
    );
  }
}
