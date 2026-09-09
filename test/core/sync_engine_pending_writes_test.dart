import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/database/sync_engine.dart';

void main() {
  test('kPendingWritesAllowedTables includes synced writable tables', () {
    expect(
      kPendingWritesAllowedTables,
      containsAll([
        'groups',
        'group_members',
        'participants',
        'expenses',
        'expense_tags',
        'household_balance_reassignments',
      ]),
    );
    expect(kPendingWritesAllowedTables.length, 6);
    expect(kPendingWritesAllowedTables, isNot(contains('user_notifications')));
  });
}
