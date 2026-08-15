part of 'powersync_repository.dart';

// =============================================================================
// PowerSync GroupInvite Repository
// =============================================================================

class PowerSyncGroupInviteRepository implements IGroupInviteRepository {
  final PowerSyncDatabase _db;
  final CloudBackend? cloud;
  PowerSyncGroupInviteRepository(this._db, {this.cloud});

  @override
  Future<({GroupInvite invite, Group group})?> getByToken(String token) async {
    final invites = cloud?.invites;
    if (invites == null) {
      throw UnsupportedError('getByToken requires online mode');
    }
    final row = await invites.getByToken(token);
    if (row == null) return null;

    // RPC returns invite + group columns; createdBy, label, maxUses, useCount, isActive may be absent (defaults used)
    final invite = GroupInvite(
      id: row['invite_id'] as String,
      groupId: row['group_id'] as String,
      token: row['token'] as String,
      inviteeEmail: row['invitee_email'] as String?,
      role: row['role'] as String? ?? 'member',
      createdAt: _parseDateTime(row['created_at']),
      expiresAt: _parseDateTimeNullable(row['expires_at']),
      accessMode: InviteAccessMode.fromValue(row['access_mode'] as String?),
    );
    final group = Group(
      id: row['group_id'] as String,
      name: row['group_name'] as String? ?? '',
      currencyCode: row['group_currency_code'] as String? ?? 'USD',
      createdAt: _parseDateTime(row['group_created_at']),
      updatedAt: _parseDateTime(row['group_updated_at']),
    );
    return (invite: invite, group: group);
  }

  @override
  Future<({String id, String token})> createInvite(
    String groupId, {
    String? inviteeEmail,
    String? role,
    String? label,
    int? maxUses,
    Duration? expiresIn,
    InviteAccessMode accessMode = InviteAccessMode.standard,
  }) async {
    final invites = cloud?.invites;
    if (invites == null) {
      throw UnsupportedError('createInvite requires online mode');
    }
    final effectiveRole = role ?? 'member';
    final row = await invites.create(
      groupId,
      inviteeEmail: inviteeEmail,
      role: effectiveRole,
      label: label,
      maxUses: maxUses,
      expiresIn: expiresIn,
      accessMode: accessMode.value,
    );
    final id = row['id'] as String;
    final token = row['token'] as String;

    // Insert into local DB so watchers update immediately
    final now = _nowIso();
    final expiresAtIso = expiresIn != null
        ? DateTime.now().toUtc().add(expiresIn).toIso8601String()
        : null;
    final createdBy = cloud?.auth.currentUser?.id;
    await _db.execute(
      '''INSERT OR REPLACE INTO group_invites
        (id, group_id, token, invitee_email, role, created_at, expires_at,
         created_by, label, max_uses, use_count, is_active, access_mode)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 1, ?)''',
      [
        id,
        groupId,
        token,
        inviteeEmail,
        effectiveRole,
        now,
        expiresAtIso,
        createdBy,
        label,
        maxUses,
        accessMode.value,
      ],
    );

    return (id: id, token: token);
  }

  @override
  Future<String> accept(
    String token, {
    String? newParticipantName,
    String? participantId,
  }) async {
    final invites = cloud?.invites;
    if (invites == null) {
      throw UnsupportedError('accept requires online mode');
    }
    final groupId = await invites.accept(
      token,
      participantId: participantId,
      newParticipantName: newParticipantName,
    );
    Log.info('Invite accepted');
    return groupId;
  }

  @override
  Future<List<GroupInvite>> listByGroup(String groupId) async {
    final rows = await _db.getAll(
      'SELECT * FROM group_invites WHERE group_id = ?',
      [groupId],
    );
    return rows.map(_inviteFromRow).toList();
  }

  @override
  Stream<List<GroupInvite>> watchByGroup(String groupId) {
    if (kIsWeb) {
      return _pollStream(() => listByGroup(groupId));
    }
    return _db
        .watch(
          'SELECT * FROM group_invites WHERE group_id = ?',
          parameters: [groupId],
        )
        .map((rows) => rows.map(_inviteFromRow).toList());
  }

  @override
  Future<void> revoke(String inviteId) async {
    await cloud?.invites.revoke(inviteId);
    // Always update local DB so watchers fire immediately
    await _db.execute('UPDATE group_invites SET is_active = 0 WHERE id = ?', [
      inviteId,
    ]);
  }

  @override
  Future<void> toggleActive(String inviteId, bool active) async {
    await cloud?.invites.toggleActive(inviteId, active);
    // Always update local DB so watchers fire immediately
    await _db.execute('UPDATE group_invites SET is_active = ? WHERE id = ?', [
      active ? 1 : 0,
      inviteId,
    ]);
  }

  @override
  Future<List<InviteUsage>> listUsages(String inviteId) async {
    final rows = await _db.getAll(
      'SELECT * FROM invite_usages WHERE invite_id = ? ORDER BY accepted_at DESC',
      [inviteId],
    );
    return rows.map(_inviteUsageFromRow).toList();
  }

  @override
  Stream<List<InviteUsage>> watchUsages(String inviteId) {
    if (kIsWeb) {
      return _pollStream(() => listUsages(inviteId));
    }
    return _db
        .watch(
          'SELECT * FROM invite_usages WHERE invite_id = ? ORDER BY accepted_at DESC',
          parameters: [inviteId],
        )
        .map((rows) => rows.map(_inviteUsageFromRow).toList());
  }
}
