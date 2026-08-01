import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/database/sync_engine.dart';

void main() {
  test('kPendingWritesAllowedTables includes core tables only', () {
    expect(kPendingWritesAllowedTables, containsAll([
      'groups',
      'group_members',
      'participants',
      'expenses',
      'expense_tags',
    ]));
    expect(kPendingWritesAllowedTables.length, 5);
    expect(kPendingWritesAllowedTables, isNot(contains('user_notifications')));
  });
}
