import '../../domain/domain.dart';

abstract class IUserNotificationRepository {
  Stream<List<UserNotification>> watchRecent({int limit = 100});
  Stream<int> watchUnreadCount();
  Future<void> markRead(String id);
  Future<void> markAllRead();
}
