part of 'powersync_repository.dart';

// =============================================================================
// PowerSync Group Repository
// =============================================================================

class PowerSyncGroupRepository implements IGroupRepository {
  final PowerSyncDatabase _db;
  final CloudBackend? _cloud;
  final bool _isOnline;
  final bool _isLocalOnly;

  PowerSyncGroupRepository(
    this._db, {
    CloudBackend? cloud,
    bool isOnline = false,
    bool isLocalOnly = true,
  }) : _cloud = cloud,
       _isOnline = isOnline,
       _isLocalOnly = isLocalOnly;

  static const _activeGroupsWhere = "(archived_at IS NULL OR archived_at = '')";
  static const _archivedGroupsWhere =
      "archived_at IS NOT NULL AND archived_at != ''";

  @override
  Future<List<Group>> getAll() async {
    final rows = await _db.getAll(
      'SELECT * FROM groups WHERE $_activeGroupsWhere ORDER BY updated_at DESC',
    );
    return rows.map(_groupFromRow).toList();
  }

  @override
  Stream<List<Group>> watchAll() {
    if (kIsWeb) {
      return _pollStream(() async {
        final rows = await _db.getAll(
          'SELECT * FROM groups WHERE $_activeGroupsWhere ORDER BY updated_at DESC',
        );
        return rows.map(_groupFromRow).toList();
      }, fingerprint: _groupsListFp);
    }
    return _db
        .watch(
          'SELECT * FROM groups WHERE $_activeGroupsWhere ORDER BY updated_at DESC',
        )
        .map((rows) => rows.map(_groupFromRow).toList());
  }

  @override
  Stream<List<Group>> watchArchived() {
    if (kIsWeb) {
      return _pollStream(() async {
        final rows = await _db.getAll(
          'SELECT * FROM groups WHERE $_archivedGroupsWhere ORDER BY updated_at DESC',
        );
        return rows.map(_groupFromRow).toList();
      }, fingerprint: _groupsListFp);
    }
    return _db
        .watch(
          'SELECT * FROM groups WHERE $_archivedGroupsWhere ORDER BY updated_at DESC',
        )
        .map((rows) => rows.map(_groupFromRow).toList());
  }

  @override
  Future<Group?> getById(String id) async {
    final rows = await _db.getAll('SELECT * FROM groups WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return _groupFromRow(rows.first);
  }

  @override
  Stream<Group?> watchById(String id) {
    if (kIsWeb) {
      return _pollStream(() => getById(id), fingerprint: _groupFp);
    }
    return _db
        .watch('SELECT * FROM groups WHERE id = ?', parameters: [id])
        .map((rows) => rows.isEmpty ? null : _groupFromRow(rows.first));
  }

  @override
  Future<String> create(
    String name,
    String currencyCode, {
    String? icon,
    int? color,
    List<String> initialParticipants = const [],
    bool isPersonal = false,
    int? budgetAmountCents,
    SettlementMethod settlementMethod = SettlementMethod.greedy,
    bool allowMemberAddExpense = true,
    bool allowMemberChangeSettings = true,
    bool allowExpenseAsOtherParticipant = true,
    bool allowMemberSettleForOthers = false,
    String? treasurerInitialParticipantName,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 200) {
      throw ArgumentError(
        'Group name must be 1–200 characters (got ${trimmedName.length})',
      );
    }
    if (currencyCode.trim().length != 3) {
      throw ArgumentError('currency_code must be 3 characters');
    }
    final id = _uuid.v4();
    final now = _nowIso();
    String? ownerId;
    String? ownerDisplayName;
    String? ownerAvatarId;
    final user = cloudBackend?.auth.currentUser;
    if (user != null) {
      ownerId = user.id;
      ownerDisplayName =
          user.metadata['display_name'] as String? ??
          user.fullName ??
          user.email ??
          'default_owner_name'.tr();
      ownerAvatarId = user.avatarId;
    }

    final groupData = <String, dynamic>{
      'id': id,
      'name': trimmedName,
      'currency_code': currencyCode,
      'owner_id': ownerId,
      'settlement_method': settlementMethod.name,
      'allow_member_add_expense': allowMemberAddExpense,
      'allow_member_change_settings': allowMemberChangeSettings,
      'allow_expense_as_other_participant': allowExpenseAsOtherParticipant,
      'allow_member_settle_for_others': allowMemberSettleForOthers,
      'icon': icon,
      'color': _colorToSigned(color),
      'is_personal': isPersonal,
      'budget_amount_cents': budgetAmountCents,
      'created_at': now,
      'updated_at': now,
    };

    // Pre-generate participant IDs for additional participants so Supabase and local use the same IDs
    final additionalParticipantIds =
        <({String id, String name, int sortOrder})>[];
    for (int i = 0; i < initialParticipants.length; i++) {
      final pName = initialParticipants[i].trim();
      if (pName.isEmpty) continue;
      if (pName.length > 100) {
        throw ArgumentError('Participant name must be at most 100 characters');
      }
      additionalParticipantIds.add((
        id: _uuid.v4(),
        name: pName,
        sortOrder: i + 1,
      ));
    }

    // Auto-create a participant for the owner
    final participantId = _uuid.v4();
    final String? treasurerParticipantId;
    if (settlementMethod == SettlementMethod.treasurer) {
      final wanted = treasurerInitialParticipantName?.trim();
      String? matchedId;
      if (wanted != null && wanted.isNotEmpty) {
        for (final entry in additionalParticipantIds) {
          if (entry.name == wanted) {
            matchedId = entry.id;
            break;
          }
        }
      }
      treasurerParticipantId = matchedId ?? participantId;
    } else {
      treasurerParticipantId = null;
    }
    if (treasurerParticipantId != null) {
      groupData['treasurer_participant_id'] = treasurerParticipantId;
    }
    final ownerMemberId = ownerId != null ? _uuid.v4() : null;
    // participants.name CHECK is 1–100; clamp auth display names so group
    // create cannot fail after the groups row is already inserted.
    final fallbackOwnerName = 'default_owner_name'.tr();
    final rawOwnerName = (ownerDisplayName ?? fallbackOwnerName).trim();
    final participantName = rawOwnerName.isEmpty
        ? fallbackOwnerName
        : clampCodePoints(rawOwnerName, maxCodePoints: 100);

    if (!_isLocalOnly && _isOnline && _cloud != null) {
      // Online: write to Supabase first
      await _cloud.sync.upsert('groups', groupData);
      // Create owner membership first (without participant_id) so that
      // get_user_role() returns 'owner' for subsequent RLS checks.
      if (ownerId != null && ownerMemberId != null) {
        await _cloud.sync.upsert('group_members', {
          'id': ownerMemberId,
          'group_id': id,
          'user_id': ownerId,
          'role': 'owner',
          'joined_at': now,
        });
      }
      // Create participant for owner (RLS now passes via get_user_role)
      await _cloud.sync.upsert('participants', {
        'id': participantId,
        'group_id': id,
        'name': participantName,
        'sort_order': 0,
        'user_id': ownerId,
        'avatar_id': ownerAvatarId,
        'created_at': now,
        'updated_at': now,
      });
      // Link participant to the membership record
      if (ownerMemberId != null) {
        await _cloud.sync.update('group_members', {'participant_id': participantId}, ownerMemberId);
      }
      // Create additional participants from the wizard (use same IDs as local loop below)
      for (int i = 0; i < additionalParticipantIds.length; i++) {
        final entry = additionalParticipantIds[i];
        await _cloud.sync.upsert('participants', {
          'id': entry.id,
          'group_id': id,
          'name': entry.name,
          'sort_order': entry.sortOrder,
          'created_at': now,
          'updated_at': now,
        });
      }
    } else if (_shouldQueueOffline(
      isLocalOnly: _isLocalOnly,
      isOnline: _isOnline,
    )) {
      await _enqueue(
        _db,
        tableName: 'groups',
        operation: 'insert',
        rowId: id,
        data: groupData,
      );
      await _enqueue(
        _db,
        tableName: 'participants',
        operation: 'insert',
        rowId: participantId,
        data: {
          'id': participantId,
          'group_id': id,
          'name': participantName,
          'sort_order': 0,
          'user_id': ownerId,
          'avatar_id': ownerAvatarId,
          'created_at': now,
          'updated_at': now,
        },
      );
      if (ownerId != null && ownerMemberId != null) {
        await _enqueue(
          _db,
          tableName: 'group_members',
          operation: 'insert',
          rowId: ownerMemberId,
          data: {
            'id': ownerMemberId,
            'group_id': id,
            'user_id': ownerId,
            'role': 'owner',
            'participant_id': participantId,
            'joined_at': now,
          },
        );
      }
      for (final entry in additionalParticipantIds) {
        await _enqueue(
          _db,
          tableName: 'participants',
          operation: 'insert',
          rowId: entry.id,
          data: {
            'id': entry.id,
            'group_id': id,
            'name': entry.name,
            'sort_order': entry.sortOrder,
            'created_at': now,
            'updated_at': now,
          },
        );
      }
    }

    // Always write to local DB (use signed color for consistency with Supabase and reader)
    final colorStored = _colorToSigned(color);
    await _db.execute(
      '''INSERT INTO groups (
        id, name, currency_code, owner_id, settlement_method,
        treasurer_participant_id,
        allow_member_add_expense, allow_member_change_settings,
        allow_expense_as_other_participant, allow_member_settle_for_others,
        icon, color, archived_at, is_personal, budget_amount_cents,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        id,
        trimmedName,
        currencyCode,
        ownerId,
        settlementMethod.name,
        treasurerParticipantId,
        allowMemberAddExpense ? 1 : 0,
        allowMemberChangeSettings ? 1 : 0,
        allowExpenseAsOtherParticipant ? 1 : 0,
        allowMemberSettleForOthers ? 1 : 0,
        icon,
        colorStored,
        null,
        isPersonal ? 1 : 0,
        budgetAmountCents,
        now,
        now,
      ],
    );
    // Local participant for owner
    await _db.execute(
      'INSERT INTO participants (id, group_id, name, sort_order, user_id, avatar_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [participantId, id, participantName, 0, ownerId, ownerAvatarId, now, now],
    );
    if (ownerId != null && ownerMemberId != null) {
      await _db.execute(
        'INSERT INTO group_members (id, group_id, user_id, role, participant_id, joined_at) VALUES (?, ?, ?, ?, ?, ?)',
        [ownerMemberId, id, ownerId, 'owner', participantId, now],
      );
    }
    // Create additional participants from the wizard in local DB (same IDs as Supabase)
    for (final entry in additionalParticipantIds) {
      await _db.execute(
        'INSERT INTO participants (id, group_id, name, sort_order, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
        [entry.id, id, entry.name, entry.sortOrder, now, now],
      );
    }

    Log.debug('Group created: $id');
    return id;
  }

  @override
  Future<void> update(Group group) async {
    final trimmedName = group.name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 200) {
      throw ArgumentError(
        'Group name must be 1–200 characters (got ${trimmedName.length})',
      );
    }
    if (group.currencyCode.trim().length != 3) {
      throw ArgumentError('currency_code must be 3 characters');
    }
    final now = _nowIso();
    final data = <String, dynamic>{
      'id': group.id,
      'name': trimmedName,
      'currency_code': group.currencyCode.trim().toUpperCase(),
      'settlement_method': group.settlementMethod.name,
      'treasurer_participant_id': group.treasurerParticipantId,
      'settlement_freeze_at': group.settlementFreezeAt
          ?.toUtc()
          .toIso8601String(),
      'settlement_snapshot_json': group.settlementSnapshotJson,
      'allow_member_add_expense': group.allowMemberAddExpense,
      'allow_member_change_settings': group.allowMemberChangeSettings,
      'allow_expense_as_other_participant':
          group.allowExpenseAsOtherParticipant,
      'allow_member_settle_for_others': group.allowMemberSettleForOthers,
      'icon': group.icon,
      'color': _colorToSigned(group.color),
      'archived_at': group.archivedAt?.toUtc().toIso8601String(),
      'is_personal': group.isPersonal,
      'budget_amount_cents': group.budgetAmountCents,
      'updated_at': now,
    };

    if (!_isLocalOnly && _isOnline && _cloud != null) {
      // Omit id (PK) and archived_at (archive/unarchive use dedicated methods).
      // Personal/budget/settle/permission columns are part of the groups schema
      // (migrations 12/16/19/20260728120000) and must sync or local edits revert on fetch.
      final supabaseData = Map<String, dynamic>.from(data)
        ..remove('archived_at')
        ..remove('id');
      await _cloud.sync.update('groups', supabaseData, group.id);
    } else if (_shouldQueueOffline(
      isLocalOnly: _isLocalOnly,
      isOnline: _isOnline,
    )) {
      await _enqueue(
        _db,
        tableName: 'groups',
        operation: 'update',
        rowId: group.id,
        data: data,
      );
    }

    await _db.execute(
      '''UPDATE groups SET
        name = ?, currency_code = ?, settlement_method = ?,
        treasurer_participant_id = ?, settlement_freeze_at = ?,
        settlement_snapshot_json = ?, allow_member_add_expense = ?,
        allow_member_change_settings = ?, allow_expense_as_other_participant = ?,
        allow_member_settle_for_others = ?, icon = ?, color = ?, archived_at = ?, is_personal = ?, budget_amount_cents = ?, updated_at = ?
      WHERE id = ?''',
      [
        trimmedName,
        data['currency_code'],
        group.settlementMethod.name,
        group.treasurerParticipantId,
        group.settlementFreezeAt?.toUtc().toIso8601String(),
        group.settlementSnapshotJson,
        group.allowMemberAddExpense ? 1 : 0,
        group.allowMemberChangeSettings ? 1 : 0,
        group.allowExpenseAsOtherParticipant ? 1 : 0,
        group.allowMemberSettleForOthers ? 1 : 0,
        group.icon,
        _colorToSigned(group.color),
        group.archivedAt?.toUtc().toIso8601String(),
        group.isPersonal ? 1 : 0,
        group.budgetAmountCents,
        now,
        group.id,
      ],
    );
  }

  @override
  Future<void> archive(String groupId) async {
    final now = _nowIso();
    final rows = await _db.getAll(
      'SELECT settlement_freeze_at, settlement_snapshot_json FROM groups WHERE id = ?',
      [groupId],
    );
    final current = rows.isNotEmpty ? rows.first : null;
    final shouldAutoFreeze = shouldAutoFreezeOnArchive(
      current?['settlement_freeze_at'],
    );

    final updateData = <String, Object?>{'archived_at': now, 'updated_at': now};
    if (shouldAutoFreeze) {
      updateData['settlement_freeze_at'] = now;
      updateData['settlement_snapshot_json'] = _archiveAutoFreezeMarker;
    }

    if (!_isLocalOnly && _isOnline && _cloud != null) {
      await _cloud.sync.update('groups', updateData, groupId);
    } else if (_shouldQueueOffline(
      isLocalOnly: _isLocalOnly,
      isOnline: _isOnline,
    )) {
      await _enqueue(
        _db,
        tableName: 'groups',
        operation: 'update',
        rowId: groupId,
        data: updateData,
      );
    }
    if (shouldAutoFreeze) {
      await _db.execute(
        'UPDATE groups SET archived_at = ?, settlement_freeze_at = ?, settlement_snapshot_json = ?, updated_at = ? WHERE id = ?',
        [now, now, _archiveAutoFreezeMarker, now, groupId],
      );
    } else {
      await _db.execute(
        'UPDATE groups SET archived_at = ?, updated_at = ? WHERE id = ?',
        [now, now, groupId],
      );
    }
  }

  @override
  Future<void> unarchive(String groupId) async {
    final now = _nowIso();
    final rows = await _db.getAll(
      'SELECT settlement_snapshot_json FROM groups WHERE id = ?',
      [groupId],
    );
    final current = rows.isNotEmpty ? rows.first : null;
    final shouldAutoUnfreeze = shouldAutoUnfreezeOnUnarchive(
      current?['settlement_snapshot_json'],
    );

    final updateData = <String, Object?>{
      'archived_at': null,
      'updated_at': now,
    };
    if (shouldAutoUnfreeze) {
      updateData['settlement_freeze_at'] = null;
      updateData['settlement_snapshot_json'] = null;
    }

    if (!_isLocalOnly && _isOnline && _cloud != null) {
      await _cloud.sync.update('groups', updateData, groupId);
    } else if (_shouldQueueOffline(
      isLocalOnly: _isLocalOnly,
      isOnline: _isOnline,
    )) {
      await _enqueue(
        _db,
        tableName: 'groups',
        operation: 'update',
        rowId: groupId,
        data: updateData,
      );
    }
    if (shouldAutoUnfreeze) {
      await _db.execute(
        'UPDATE groups SET archived_at = NULL, settlement_freeze_at = NULL, settlement_snapshot_json = NULL, updated_at = ? WHERE id = ?',
        [now, groupId],
      );
    } else {
      await _db.execute(
        'UPDATE groups SET archived_at = NULL, updated_at = ? WHERE id = ?',
        [now, groupId],
      );
    }
  }

  /// Local-only: not written to pending_writes or Supabase. Persists on device only.
  @override
  Future<void> setLocalArchived(String groupId) async {
    final now = _nowIso();
    await _db.execute('DELETE FROM local_archived_groups WHERE group_id = ?', [
      groupId,
    ]);
    await _db.execute(
      'INSERT INTO local_archived_groups (id, group_id, archived_at) VALUES (?, ?, ?)',
      [groupId, groupId, now],
    );
  }

  @override
  Future<void> clearLocalArchived(String groupId) async {
    await _db.execute('DELETE FROM local_archived_groups WHERE group_id = ?', [
      groupId,
    ]);
  }

  @override
  Future<Set<String>> getLocallyArchivedGroupIds() async {
    final rows = await _db.getAll('SELECT group_id FROM local_archived_groups');
    return rows
        .map((r) => r['group_id'] as String?)
        .whereType<String>()
        .toSet();
  }

  @override
  Stream<Set<String>> watchLocallyArchivedGroupIds() {
    const q = 'SELECT group_id FROM local_archived_groups';
    if (kIsWeb) {
      return _pollStream(() async {
        final rows = await _db.getAll(q);
        return rows
            .map((r) => r['group_id'] as String?)
            .whereType<String>()
            .toSet();
      }, fingerprint: _stringSetFp);
    }
    return _db
        .watch(q)
        .map(
          (rows) => rows
              .map((r) => r['group_id'] as String?)
              .whereType<String>()
              .toSet(),
        );
  }

  static const _locallyArchivedGroupsQuery = '''
    SELECT g.* FROM groups g
    INNER JOIN local_archived_groups l ON g.id = l.group_id
    WHERE (g.archived_at IS NULL OR g.archived_at = '')
    ORDER BY g.updated_at DESC
  ''';

  @override
  Stream<List<Group>> watchLocallyArchivedGroups() {
    if (kIsWeb) {
      return _pollStream(() async {
        final rows = await _db.getAll(_locallyArchivedGroupsQuery);
        return rows.map(_groupFromRow).toList();
      }, fingerprint: _groupsListFp);
    }
    return _db
        .watch(_locallyArchivedGroupsQuery)
        .map((rows) => rows.map(_groupFromRow).toList());
  }

  @override
  Future<void> delete(String id) async {
    if (!_isLocalOnly && _isOnline && _cloud != null) {
      await _cloud.sync.delete('groups', id);
    } else if (_shouldQueueOffline(
      isLocalOnly: _isLocalOnly,
      isOnline: _isOnline,
    )) {
      await _enqueue(_db, tableName: 'groups', operation: 'delete', rowId: id);
    }
    await _db.execute('DELETE FROM groups WHERE id = ?', [id]);
  }

  @override
  Future<void> freezeSettlement(
    String groupId,
    SettlementSnapshot snapshot,
  ) async {
    final now = _nowIso();
    final snapshotJson = snapshot.toJsonString();

    if (!_isLocalOnly && _isOnline && _cloud != null) {
      await _cloud.sync.update('groups', {
            'settlement_freeze_at': now,
            'settlement_snapshot_json': snapshotJson,
            'updated_at': now,
          }, groupId);
    } else if (_shouldQueueOffline(
      isLocalOnly: _isLocalOnly,
      isOnline: _isOnline,
    )) {
      await _enqueue(
        _db,
        tableName: 'groups',
        operation: 'update',
        rowId: groupId,
        data: {
          'settlement_freeze_at': now,
          'settlement_snapshot_json': snapshotJson,
          'updated_at': now,
        },
      );
    }

    await _db.execute(
      'UPDATE groups SET settlement_freeze_at = ?, settlement_snapshot_json = ?, updated_at = ? WHERE id = ?',
      [now, snapshotJson, now, groupId],
    );
  }

  @override
  Future<void> unfreezeSettlement(String groupId) async {
    final now = _nowIso();

    if (!_isLocalOnly && _isOnline && _cloud != null) {
      await _cloud.sync.update('groups', {
            'settlement_freeze_at': null,
            'settlement_snapshot_json': null,
            'updated_at': now,
          }, groupId);
    } else if (_shouldQueueOffline(
      isLocalOnly: _isLocalOnly,
      isOnline: _isOnline,
    )) {
      await _enqueue(
        _db,
        tableName: 'groups',
        operation: 'update',
        rowId: groupId,
        data: {
          'settlement_freeze_at': null,
          'settlement_snapshot_json': null,
          'updated_at': now,
        },
      );
    }

    await _db.execute(
      'UPDATE groups SET settlement_freeze_at = NULL, settlement_snapshot_json = NULL, updated_at = ? WHERE id = ?',
      [now, groupId],
    );
  }
}
