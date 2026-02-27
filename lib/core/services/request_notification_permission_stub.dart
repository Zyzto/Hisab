// Stub for non-web: no browser Notification API.

/// No-op on non-web. Returns true so callers do not block.
Future<bool> requestBrowserNotificationPermission() async => true;

/// On non-web this is not used; return true.
bool isBrowserNotificationPermissionGranted() => true;
