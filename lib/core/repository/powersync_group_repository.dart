part of 'powersync_repository.dart';

// =============================================================================
// PowerSync Group Repository
// =============================================================================

class PowerSyncGroupRepository implements IGroupRepository {
  final PowerSyncDatabase _db;

  PowerSyncGroupRepository(this._db);

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
    bool householdCountingEnabled = false,
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
    const String? ownerId = null;
    const String? ownerAvatarId = null;

    // Pre-generate participant IDs so locally created records remain stable.
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
    // Keep the first participant local; there is no account owner in the FOSS
    // build. Clamp the fallback so the SQLite CHECK constraint is respected.
    final fallbackOwnerName = 'default_owner_name'.tr();
    final rawOwnerName = fallbackOwnerName.trim();
    final participantName = rawOwnerName.isEmpty
        ? fallbackOwnerName
        : clampCodePoints(rawOwnerName, maxCodePoints: 100);

    // Write directly to the local database.
    final colorStored = _colorToSigned(color);
    await _db.execute(
      '''INSERT INTO groups (
        id, name, currency_code, owner_id, settlement_method,
        treasurer_participant_id,
        allow_member_add_expense, allow_member_change_settings,
        allow_expense_as_other_participant, allow_member_settle_for_others,
        household_counting_enabled,
        icon, color, archived_at, is_personal, budget_amount_cents,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
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
        householdCountingEnabled ? 1 : 0,
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
      'INSERT INTO participants (id, group_id, name, sort_order, user_id, avatar_id, parent_participant_id, unnamed_dependent_count, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        participantId,
        id,
        participantName,
        0,
        ownerId,
        ownerAvatarId,
        null,
        0,
        now,
        now,
      ],
    );
    // Create additional participants from the wizard in local DB.
    for (final entry in additionalParticipantIds) {
      await _db.execute(
        'INSERT INTO participants (id, group_id, name, sort_order, parent_participant_id, unnamed_dependent_count, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [entry.id, id, entry.name, entry.sortOrder, null, 0, now, now],
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
      'household_counting_enabled': group.householdCountingEnabled,
      'icon': group.icon,
      'color': _colorToSigned(group.color),
      'archived_at': group.archivedAt?.toUtc().toIso8601String(),
      'is_personal': group.isPersonal,
      'budget_amount_cents': group.budgetAmountCents,
      'updated_at': now,
    };

    await _db.execute(
      '''UPDATE groups SET
        name = ?, currency_code = ?, settlement_method = ?,
        treasurer_participant_id = ?, settlement_freeze_at = ?,
        settlement_snapshot_json = ?, allow_member_add_expense = ?,
        allow_member_change_settings = ?, allow_expense_as_other_participant = ?,
        allow_member_settle_for_others = ?, household_counting_enabled = ?, icon = ?, color = ?, archived_at = ?, is_personal = ?, budget_amount_cents = ?, updated_at = ?
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
        group.householdCountingEnabled ? 1 : 0,
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

  /// Local-only: persists on the device without entering the legacy queue.
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
    await _db.execute('DELETE FROM groups WHERE id = ?', [id]);
  }

  @override
  Future<void> freezeSettlement(
    String groupId,
    SettlementSnapshot snapshot,
  ) async {
    final now = _nowIso();
    final snapshotJson = snapshot.toJsonString();

    await _db.execute(
      'UPDATE groups SET settlement_freeze_at = ?, settlement_snapshot_json = ?, updated_at = ? WHERE id = ?',
      [now, snapshotJson, now, groupId],
    );
  }

  @override
  Future<void> unfreezeSettlement(String groupId) async {
    final now = _nowIso();

    await _db.execute(
      'UPDATE groups SET settlement_freeze_at = NULL, settlement_snapshot_json = NULL, updated_at = ? WHERE id = ?',
      [now, groupId],
    );
  }
}
