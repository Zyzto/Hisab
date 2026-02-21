// Web-only: show a browser Notification when an FCM message arrives in the foreground.

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Shows a browser Notification with [title] and [body]. On click, focuses the
/// window and navigates to the group detail if [groupId] is non-empty.
/// Only shows if Notification.permission is already 'granted' (e.g. from FCM setup).
void showWebForegroundNotification(
  String title,
  String body,
  String? groupId,
) {
  try {
    if (web.Notification.permission != 'granted') return;
    _show(title, body, groupId);
  } catch (_) {
    // Notifications not supported or permission denied; ignore.
  }
}

void _show(String title, String body, String? groupId) {
  final displayTitle = title.isNotEmpty ? title : 'Hisab';
  final options = web.NotificationOptions(body: body.isNotEmpty ? body : 'New notification');
  final notification = web.Notification(displayTitle, options);

  notification.onclick = (web.Event _) {
    notification.close();
    web.window.focus();
    if (groupId != null && groupId.isNotEmpty) {
      web.window.location.href = '/groups/$groupId';
    }
  }.toJS;
}
