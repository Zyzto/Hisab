/// Persisted in-app notification for the signed-in user (synced via SyncEngine).
class UserNotification {
  const UserNotification({
    required this.id,
    required this.userId,
    required this.action,
    required this.title,
    required this.body,
    required this.createdAt,
    this.groupId,
    this.actorUserId,
    this.expenseId,
    this.payloadJson,
    this.readAt,
  });

  final String id;
  final String userId;
  final String? groupId;
  final String? actorUserId;
  final String action;
  final String title;
  final String body;
  final String? expenseId;
  final String? payloadJson;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  UserNotification copyWith({
    String? id,
    String? userId,
    String? groupId,
    String? actorUserId,
    String? action,
    String? title,
    String? body,
    String? expenseId,
    String? payloadJson,
    DateTime? readAt,
    DateTime? createdAt,
    bool clearReadAt = false,
  }) {
    return UserNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      groupId: groupId ?? this.groupId,
      actorUserId: actorUserId ?? this.actorUserId,
      action: action ?? this.action,
      title: title ?? this.title,
      body: body ?? this.body,
      expenseId: expenseId ?? this.expenseId,
      payloadJson: payloadJson ?? this.payloadJson,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
