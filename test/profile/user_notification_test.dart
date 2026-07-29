import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/domain/user_notification.dart';

void main() {
  group('UserNotification', () {
    final base = UserNotification(
      id: 'n1',
      userId: 'u1',
      action: 'expense_created',
      title: 'Title',
      body: 'Body',
      createdAt: DateTime.utc(2026, 1, 1),
      groupId: 'g1',
    );

    test('isUnread when readAt is null', () {
      expect(base.isUnread, isTrue);
    });

    test('isUnread is false after mark read', () {
      final read = base.copyWith(readAt: DateTime.utc(2026, 1, 2));
      expect(read.isUnread, isFalse);
      expect(read.readAt, DateTime.utc(2026, 1, 2));
    });

    test('copyWith clearReadAt restores unread', () {
      final read = base.copyWith(readAt: DateTime.utc(2026, 1, 2));
      final unreadAgain = read.copyWith(clearReadAt: true);
      expect(unreadAgain.isUnread, isTrue);
      expect(unreadAgain.readAt, isNull);
    });
  });
}
