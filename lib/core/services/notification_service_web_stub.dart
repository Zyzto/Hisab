// Stub for non-web platforms. Real implementation in notification_service_web_impl.dart.

/// No-op on non-web. On web, shows a browser Notification and navigates to group on tap.
void showWebForegroundNotification(
  String title,
  String body,
  String? groupId,
) {}
