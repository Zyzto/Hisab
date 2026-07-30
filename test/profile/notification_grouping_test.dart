import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/domain/user_notification.dart';
import 'package:hisab/features/profile/utils/notification_grouping.dart';

UserNotification _n({
  required String id,
  required String action,
  required DateTime createdAt,
  String? groupId = 'g1',
}) {
  return UserNotification(
    id: id,
    userId: 'u1',
    groupId: groupId,
    action: action,
    title: 't$id',
    body: 'b$id',
    createdAt: createdAt,
  );
}

void main() {
  final t0 = DateTime.utc(2026, 7, 29, 12);
  final t1 = t0.subtract(const Duration(minutes: 30));
  final t2 = t0.subtract(const Duration(hours: 3));

  test('groups same action family within window', () {
    final items = groupNotifications([
      _n(id: '1', action: 'expense_created', createdAt: t0),
      _n(id: '2', action: 'expense_updated', createdAt: t1),
      _n(id: '3', action: 'expense_created', createdAt: t2),
    ]);

    expect(items.length, 2);
    expect(items[0].isGroup, isTrue);
    expect(items[0].items.map((e) => e.id), ['1', '2']);
    expect(items[1].isGroup, isFalse);
    expect(items[1].single!.id, '3');
  });

  test('groups expense_deleted with other expense actions', () {
    final items = groupNotifications([
      _n(id: '1', action: 'expense_deleted', createdAt: t0),
      _n(id: '2', action: 'expense_created', createdAt: t1),
    ]);

    expect(items.length, 1);
    expect(items[0].isGroup, isTrue);
    expect(items[0].actionFamily, 'expense');
    expect(items[0].items.map((e) => e.id), ['1', '2']);
  });

  test('does not group across groups', () {
    final items = groupNotifications([
      _n(id: '1', action: 'expense_created', createdAt: t0, groupId: 'a'),
      _n(id: '2', action: 'expense_created', createdAt: t1, groupId: 'b'),
    ]);
    expect(items.length, 2);
    expect(items.every((e) => !e.isGroup), isTrue);
  });

  test('member_joined stays separate from expenses', () {
    final items = groupNotifications([
      _n(id: '1', action: 'expense_created', createdAt: t0),
      _n(id: '2', action: 'member_joined', createdAt: t1),
    ]);
    expect(items.length, 2);
  });
}
