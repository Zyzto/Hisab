// Web-only: request browser notification permission (shows native prompt).

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Whether the browser has already granted notification permission.
bool isBrowserNotificationPermissionGranted() =>
    web.Notification.permission == 'granted';

/// Requests the browser's notification permission. Shows the native browser
/// permission prompt. Returns `true` if granted, `false` otherwise.
Future<bool> requestBrowserNotificationPermission() async {
  try {
    final p = web.Notification.requestPermission();
    final result = await p.toDart;
    return result.toDart == 'granted';
  } catch (_) {
    return false;
  }
}
