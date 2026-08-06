part of 'powersync_repository.dart';

// =============================================================================
// PowerSync GroupInvite Repository
// =============================================================================

class PowerSyncGroupInviteRepository implements IGroupInviteRepository {
  final PowerSyncDatabase _db;
  final SupabaseClient? supabaseClient;
  PowerSyncGroupInviteRepository(this._db, {this.supabaseClient});

  @override
  Future<({GroupInvite invite, Group group})?> getByToken(String token) async {
    final client = supabaseClient;
    if (client == null) {
      throw UnsupportedError('getByToken requires online mode');
    }
    final result = await client.rpc(
      'get_invite_by_token',
      params: {'p_token': token},
    );
    if (result == null || (result is List && result.isEmpty)) return null;
    final row = result is List ? result.first : result;

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
    final client = supabaseClient;
    if (client == null) {
      throw UnsupportedError('createInvite requires online mode');
    }
    final effectiveRole = role ?? 'member';
    final params = <String, dynamic>{
      'p_group_id': groupId,
      'p_invitee_email': inviteeEmail,
      'p_role': effectiveRole,
      'p_label': label,
      'p_max_uses': maxUses,
      'p_access_mode': accessMode.value,
    };
    // Convert Duration to PostgreSQL interval string, or null for never
    if (expiresIn == null) {
      params['p_expires_in'] = null;
    } else {
      final totalSeconds = expiresIn.inSeconds;
      params['p_expires_in'] = '$totalSeconds seconds';
    }
    final result = await client.rpc('create_invite', params: params);
    final row = result is List ? result.first : result;
    final id = row['id'] as String;
    final token = row['token'] as String;

    // Insert into local DB so watchers update immediately
    final now = _nowIso();
    final expiresAtIso = expiresIn != null
        ? DateTime.now().toUtc().add(expiresIn).toIso8601String()
        : null;
    final createdBy = client.auth.currentUser?.id;
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
    final client = supabaseClient;
    if (client == null) {
      throw UnsupportedError('accept requires online mode');
    }
    final result = await client.rpc(
      'accept_invite',
      params: {
        'p_token': token,
        'p_participant_id': participantId,
        'p_new_participant_name': newParticipantName,
      },
    );
    Log.info('Invite accepted');
    return result as String;
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
    final client = supabaseClient;
    if (client != null) {
      await client.rpc('revoke_invite', params: {'p_invite_id': inviteId});
    }
    // Always update local DB so watchers fire immediately
    await _db.execute('UPDATE group_invites SET is_active = 0 WHERE id = ?', [
      inviteId,
    ]);
  }

  @override
  Future<void> toggleActive(String inviteId, bool active) async {
    final client = supabaseClient;
    if (client != null) {
      await client.rpc(
        'toggle_invite_active',
        params: {'p_invite_id': inviteId, 'p_active': active},
      );
    }
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
