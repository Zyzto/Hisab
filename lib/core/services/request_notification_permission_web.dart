// Web-only: request browser notification permission (shows native prompt).

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Whether the browser Notification API is available.
bool isBrowserNotificationApiSupported() {
  try {
    // Accessing permission throws if Notification is missing.
    final _ = web.Notification.permission;
    return true;
  } catch (_) {
    return false;
  }
}

/// Whether the browser has already granted notification permission.
bool isBrowserNotificationPermissionGranted() {
  try {
    return web.Notification.permission == 'granted';
  } catch (_) {
    return false;
  }
}

/// Requests the browser's notification permission. Shows the native browser
/// permission prompt. Returns `true` if granted, `false` otherwise.
Future<bool> requestBrowserNotificationPermission() async {
  try {
    if (!isBrowserNotificationApiSupported()) return false;
    if (web.Notification.permission == 'granted') return true;
    if (web.Notification.permission == 'denied') return false;
    final p = web.Notification.requestPermission();
    final result = await p.toDart;
    return result.toDart == 'granted';
  } catch (_) {
    return false;
  }
}
