// Non-web stub: browser Notification API is not used.

/// Whether the browser has already granted notification permission.
bool isBrowserNotificationPermissionGranted() => true;

/// Whether the browser Notification API exists.
bool isBrowserNotificationApiSupported() => true;

/// Requests the browser's notification permission.
Future<bool> requestBrowserNotificationPermission() async => true;
