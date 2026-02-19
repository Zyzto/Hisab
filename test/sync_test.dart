import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:powersync/powersync.dart';

import 'package:hisab/core/database/powersync_schema.dart' as ps;
import 'package:hisab/core/database/sync_backend.dart';
import 'package:hisab/core/database/sync_engine.dart';

bool _powerSyncAvailable = false;

void main() {
  PowerSyncDatabase? db;
  late String dbPath;

  setUpAll(() async {
    try {
      final p = path.join(Directory.systemTemp.path, 'hisab_sync_probe.db');
      final probe = PowerSyncDatabase(schema: ps.schema, path: p);
      await probe.initialize();
      await probe.close();
      File(p).deleteSync();
      _powerSyncAvailable = true;
    } catch (_) {
      _powerSyncAvailable = false;
    }
    if (!_powerSyncAvailable) return;
    dbPath = path.join(
      Directory.systemTemp.path,
      'hisab_sync_test_${DateTime.now().millisecondsSinceEpoch}.db',
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

  group('SyncEngine.fetchAllWithBackend', () {
    test('clears local cache when user has no groups', () async {
      if (!_powerSyncAvailable || db == null) return;
      final backend = _FakeSyncBackend(userId: 'user-1', groupIds: []);
      await SyncEngine().fetchAllWithBackend(db!, backend);
      final groups = await db!.getAll('SELECT * FROM groups');
      expect(groups, isEmpty);
    });

    test('writes groups and related data from backend into local DB', () async {
      if (!_powerSyncAvailable || db == null) return;
      const groupId = 'group-123';
      const userId = 'user-456';
      final backend = _FakeSyncBackend(
        userId: userId,
        groupIds: [groupId],
        groups: [
          {
            'id': groupId,
            'name': 'Test Group',
            'currency_code': 'USD',
            'owner_id': userId,
            'settlement_method': 'greedy',
            'treasurer_participant_id': null,
            'settlement_freeze_at': null,
            'settlement_snapshot_json': null,
            'allow_member_add_expense': true,
            'allow_member_add_participant': true,
            'allow_member_change_settings': true,
            'require_participant_assignment': false,
            'icon': null,
            'color': null,
            'created_at': '2025-01-01T00:00:00Z',
            'updated_at': '2025-01-01T00:00:00Z',
          },
        ],
        members: [
          {
            'id': 'member-1',
            'group_id': groupId,
            'user_id': userId,
            'role': 'owner',
            'participant_id': 'part-1',
            'joined_at': '2025-01-01T00:00:00Z',
          },
        ],
        participants: [
          {
            'id': 'part-1',
            'group_id': groupId,
            'name': 'Owner',
            'sort_order': 0,
            'user_id': userId,
            'avatar_id': null,
            'created_at': '2025-01-01T00:00:00Z',
            'updated_at': '2025-01-01T00:00:00Z',
          },
        ],
        expenses: [],
        tags: [],
        invites: [],
      );
      await SyncEngine().fetchAllWithBackend(db!, backend);

      final groups = await db!.getAll('SELECT * FROM groups');
      expect(groups.length, 1);
      expect(groups.first['id'], groupId);
      expect(groups.first['name'], 'Test Group');
      expect(groups.first['currency_code'], 'USD');

      final members = await db!.getAll('SELECT * FROM group_members WHERE group_id = ?', [groupId]);
      expect(members.length, 1);
      final participants = await db!.getAll('SELECT * FROM participants WHERE group_id = ?', [groupId]);
      expect(participants.length, 1);
      expect(participants.first['name'], 'Owner');
    });
  });

  group('SyncEngine.pushPendingWritesWithBackend', () {
    test('removes pending_writes row after successful push', () async {
      if (!_powerSyncAvailable || db == null) return;
      final captured = <Map<String, dynamic>>[];
      final backend = _FakeSyncBackend(userId: 'u', groupIds: [], capture: captured);
      final rowId = 'row-${DateTime.now().millisecondsSinceEpoch}';
      final data = {'id': rowId, 'name': 'A Group', 'currency_code': 'USD'};
      await db!.execute(
        '''INSERT INTO pending_writes (table_name, operation, row_id, data_json, created_at)
          VALUES (?, ?, ?, ?, ?)''',
        ['groups', 'insert', rowId, jsonEncode(data), DateTime.now().toUtc().toIso8601String()],
      );

      await SyncEngine().pushPendingWritesWithBackend(db!, backend);

      final remaining = await db!.getAll('SELECT * FROM pending_writes WHERE row_id = ?', [rowId]);
      expect(remaining, isEmpty);
      expect(captured.length, 1);
      expect(captured.first['table'], 'groups');
      expect(captured.first['operation'], 'insert');
      expect(captured.first['data']!['name'], 'A Group');
    });
  });
}

class _FakeSyncBackend implements SyncBackend {
  _FakeSyncBackend({
    required this.userId,
    required this.groupIds,
    this.groups = const [],
    this.members = const [],
    this.participants = const [],
    this.expenses = const [],
    this.tags = const [],
    this.invites = const [],
    List<Map<String, dynamic>>? capture,
  }) : _captured = capture;

  final String userId;
  final List<String> groupIds;
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> participants;
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> tags;
  final List<Map<String, dynamic>> invites;
  final List<Map<String, dynamic>> inviteUsages = const [];
  final List<Map<String, dynamic>>? _captured;

  @override
  String? get currentUserId => userId;

  @override
  Future<List<Map<String, dynamic>>> getGroupIdsForUser(String _) async {
    return groupIds.map((id) => {'group_id': id}).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getGroups(List<String> ids) async {
    return groups.where((g) => ids.contains(g['id'])).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getMembers(List<String> ids) async {
    return members.where((m) => ids.contains(m['group_id'])).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getParticipants(List<String> ids) async {
    return participants.where((p) => ids.contains(p['group_id'])).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getExpenses(List<String> ids) async {
    return expenses.where((e) => ids.contains(e['group_id'])).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getTags(List<String> ids) async {
    return tags.where((t) => ids.contains(t['group_id'])).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getInvites(List<String> ids) async {
    return invites.where((i) => ids.contains(i['group_id'])).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getInviteUsages(List<String> ids) async {
    return inviteUsages.where((u) => ids.contains(u['invite_id'])).toList();
  }

  @override
  Future<void> upsert(String table, Map<String, dynamic> data) async {
    _captured?.add({'table': table, 'operation': 'insert', 'data': data});
  }

  @override
  Future<void> update(String table, Map<String, dynamic> data, String id) async {
    _captured?.add({'table': table, 'operation': 'update', 'data': data, 'id': id});
  }

  @override
  Future<void> delete(String table, String id) async {
    _captured?.add({'table': table, 'operation': 'delete', 'id': id});
  }
}
