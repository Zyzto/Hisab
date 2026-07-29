import '../../../domain/domain.dart';

/// One chronological feed entry — either a single notification or a collapsed group.
class NotificationFeedItem {
  const NotificationFeedItem.single(UserNotification notification)
    : notifications = const [],
      single = notification;

  const NotificationFeedItem.group(this.notifications) : single = null;

  final UserNotification? single;
  final List<UserNotification> notifications;

  bool get isGroup => single == null;

  List<UserNotification> get items =>
      single != null ? [single!] : notifications;

  bool get hasUnread => items.any((n) => n.isUnread);

  DateTime get sortKey => items.first.createdAt;

  String get actionFamily => _actionFamily(items.first.action);

  String? get groupId => items.first.groupId;
}

String _actionFamily(String action) {
  switch (action) {
    case 'expense_created':
    case 'expense_updated':
      return 'expense';
    case 'member_joined':
      return 'member';
    default:
      return action;
  }
}

/// Collapse notifications that share group + action family within [window].
///
/// Input should already be newest-first; output stays newest-first.
List<NotificationFeedItem> groupNotifications(
  List<UserNotification> notifications, {
  Duration window = const Duration(hours: 2),
  DateTime Function()? now,
}) {
  if (notifications.isEmpty) return const [];

  final sorted = List<UserNotification>.from(notifications)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  final items = <NotificationFeedItem>[];
  var i = 0;
  while (i < sorted.length) {
    final head = sorted[i];
    final family = _actionFamily(head.action);
    final groupId = head.groupId;
    final bucket = <UserNotification>[head];
    var j = i + 1;
    while (j < sorted.length) {
      final next = sorted[j];
      if (next.groupId != groupId) break;
      if (_actionFamily(next.action) != family) break;
      if (head.createdAt.difference(next.createdAt) > window) break;
      bucket.add(next);
      j++;
    }
    if (bucket.length == 1) {
      items.add(NotificationFeedItem.single(bucket.first));
    } else {
      items.add(NotificationFeedItem.group(bucket));
    }
    i = j;
  }

  // [now] reserved for future digest cutoffs; silence unused in v1.
  now?.call();
  return items;
}
