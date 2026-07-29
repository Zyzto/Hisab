import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:powersync/powersync.dart';

import 'package:hisab/core/database/powersync_schema.dart' as ps;
import 'package:hisab/core/repository/powersync_repository.dart';

void main() {
  PowerSyncDatabase? db;
  late String dbPath;
  var available = false;

  setUpAll(() async {
    try {
      final probePath = path.join(
        Directory.systemTemp.path,
        'hisab_notif_probe.db',
      );
      final probe = PowerSyncDatabase(schema: ps.schema, path: probePath);
      await probe.initialize();
      await probe.close();
      File(probePath).deleteSync();
      available = true;
    } catch (_) {
      available = false;
    }
    if (!available) return;
    dbPath = path.join(
      Directory.systemTemp.path,
      'hisab_notif_repo_${DateTime.now().millisecondsSinceEpoch}.db',
    );
    db = PowerSyncDatabase(schema: ps.schema, path: dbPath);
    await db!.initialize();
  });

  tearDownAll(() async {
    if (db != null) {
      await db!.close();
      try {
        File(dbPath).deleteSync();
      } catch (_) {}
      db = null;
    }
  });

  Future<void> insertNotification({
    required String id,
    String? readAt,
  }) async {
    await db!.execute(
      '''INSERT INTO user_notifications
        (id, user_id, group_id, actor_user_id, action, title, body, expense_id,
         payload_json, read_at, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        id,
        'u1',
        'g1',
        'actor',
        'expense_created',
        'Title',
        'Body',
        null,
        null,
        readAt,
        '2026-01-01T00:00:00Z',
      ],
    );
  }

  test('markRead sets read_at locally', () async {
    if (!available || db == null) return;
    await db!.execute('DELETE FROM user_notifications');
    await insertNotification(id: 'n-read');

    final repo = PowerSyncUserNotificationRepository(
      db!,
      isOnline: false,
      isLocalOnly: true,
    );
    await repo.markRead('n-read');

    final row = await db!.getOptional(
      'SELECT read_at FROM user_notifications WHERE id = ?',
      ['n-read'],
    );
    expect(row, isNotNull);
    expect(row!['read_at'], isNotNull);
  });

  test('markAllRead clears unread count', () async {
    if (!available || db == null) return;
    await db!.execute('DELETE FROM user_notifications');
    await insertNotification(id: 'n-a');
    await insertNotification(id: 'n-b');

    final repo = PowerSyncUserNotificationRepository(
      db!,
      isOnline: false,
      isLocalOnly: true,
    );
    expect(await repo.watchUnreadCount().first, 2);
    await repo.markAllRead();
    expect(await repo.watchUnreadCount().first, 0);

    final recent = await repo.watchRecent().first;
    expect(recent.length, 2);
    expect(recent.every((n) => !n.isUnread), isTrue);
  });
}
