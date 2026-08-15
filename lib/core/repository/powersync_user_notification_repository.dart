part of 'powersync_repository.dart';

// =============================================================================
// PowerSync User Notification Repository
// =============================================================================

UserNotification _userNotificationFromRow(Map<String, dynamic> row) {
  final payload = row['payload_json'] ?? row['payload'];
  return UserNotification(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    groupId: row['group_id'] as String?,
    actorUserId: row['actor_user_id'] as String?,
    action: row['action'] as String? ?? '',
    title: row['title'] as String? ?? '',
    body: row['body'] as String? ?? '',
    expenseId: row['expense_id'] as String?,
    payloadJson: payload == null
        ? null
        : (payload is String ? payload : jsonEncode(payload)),
    readAt: _parseDateTimeNullable(row['read_at']),
    createdAt: _parseDateTime(row['created_at']),
  );
}

class PowerSyncUserNotificationRepository
    implements IUserNotificationRepository {
  PowerSyncUserNotificationRepository(
    this._db, {
    this.cloud,
    this.isOnline = true,
    this.isLocalOnly = false,
  });

  final PowerSyncDatabase _db;
  final CloudBackend? cloud;
  final bool isOnline;
  final bool isLocalOnly;

  Future<List<UserNotification>> _listRecent({int limit = 100}) async {
    final rows = await _db.getAll(
      'SELECT * FROM user_notifications ORDER BY created_at DESC LIMIT ?',
      [limit],
    );
    return rows.map(_userNotificationFromRow).toList();
  }

  Future<int> _unreadCount() async {
    final row = await _db.getOptional(
      'SELECT COUNT(*) AS c FROM user_notifications WHERE read_at IS NULL',
    );
    return (row?['c'] as num?)?.toInt() ?? 0;
  }

  @override
  Stream<List<UserNotification>> watchRecent({int limit = 100}) {
    if (kIsWeb) {
      return _pollStream(() => _listRecent(limit: limit));
    }
    return _db
        .watch(
          'SELECT * FROM user_notifications ORDER BY created_at DESC LIMIT ?',
          parameters: [limit],
        )
        .map((rows) => rows.map(_userNotificationFromRow).toList());
  }

  @override
  Stream<int> watchUnreadCount() {
    if (kIsWeb) {
      return _pollStream(_unreadCount);
    }
    return _db
        .watch(
          'SELECT COUNT(*) AS c FROM user_notifications WHERE read_at IS NULL',
        )
        .map((rows) {
          if (rows.isEmpty) return 0;
          return (rows.first['c'] as num?)?.toInt() ?? 0;
        });
  }

  @override
  Future<void> markRead(String id) async {
    final readAt = _nowIso();
    await _db.execute(
      'UPDATE user_notifications SET read_at = ? WHERE id = ?',
      [readAt, id],
    );
    if (cloud != null && isOnline) {
      try {
        await cloud!.sync.update('user_notifications', {
          'read_at': readAt,
        }, id);
        return;
      } catch (e, st) {
        Log.warning(
          'markRead remote failed; queuing',
          error: e,
          stackTrace: st,
        );
      }
    }
    if (_shouldQueueOffline(isLocalOnly: isLocalOnly, isOnline: isOnline)) {
      await _enqueue(
        _db,
        tableName: 'user_notifications',
        operation: 'update',
        rowId: id,
        data: {'id': id, 'read_at': readAt},
      );
    }
  }

  @override
  Future<void> markAllRead() async {
    final readAt = _nowIso();
    final unread = await _db.getAll(
      'SELECT id FROM user_notifications WHERE read_at IS NULL',
    );
    await _db.execute(
      'UPDATE user_notifications SET read_at = ? WHERE read_at IS NULL',
      [readAt],
    );
    if (cloud != null && isOnline) {
      try {
        await cloud!.sync.updateWhere(
          'user_notifications',
          {'read_at': readAt},
          column: 'read_at',
          value: null,
        );
        return;
      } catch (e, st) {
        Log.warning(
          'markAllRead remote failed; queuing',
          error: e,
          stackTrace: st,
        );
      }
    }
    if (_shouldQueueOffline(isLocalOnly: isLocalOnly, isOnline: isOnline)) {
      for (final row in unread) {
        final id = row['id'] as String;
        await _enqueue(
          _db,
          tableName: 'user_notifications',
          operation: 'update',
          rowId: id,
          data: {'id': id, 'read_at': readAt},
        );
      }
    }
  }
}
