part of 'powersync_repository.dart';

// =============================================================================
// PowerSync GroupMember Repository
// =============================================================================

class PowerSyncGroupMemberRepository implements IGroupMemberRepository {
  final PowerSyncDatabase _db;
  final bool isLocalOnly;
  PowerSyncGroupMemberRepository(this._db, {this.isLocalOnly = false});

  String? get _currentUserId =>
      supabaseClientIfConfigured?.auth.currentUser?.id;

  SupabaseClient? get _supabase =>
      isLocalOnly ? null : supabaseClientIfConfigured;

  @override
  Future<GroupRole?> getMyRole(String groupId) async {
    final userId = _currentUserId;
    if (userId == null) return null;
    final rows = await _db.getAll(
      'SELECT role FROM group_members WHERE group_id = ? AND user_id = ?',
      [groupId, userId],
    );
    if (rows.isEmpty) return null;
    return GroupRole.fromString(rows.first['role'] as String?);
  }

  @override
  Future<GroupMember?> getMyMember(String groupId) async {
    final userId = _currentUserId;
    if (userId == null) return null;
    final rows = await _db.getAll(
      'SELECT * FROM group_members WHERE group_id = ? AND user_id = ?',
      [groupId, userId],
    );
    if (rows.isEmpty) return null;
    return _memberFromRow(rows.first);
  }

  @override
  Stream<GroupMember?> watchMyMember(String groupId) {
    if (kIsWeb) {
      return _pollStream(() => getMyMember(groupId), fingerprint: _memberFp);
    }
    final userId = _currentUserId;
    if (userId == null) {
      return Stream<GroupMember?>.value(null);
    }
    return _db
        .watch(
          'SELECT * FROM group_members WHERE group_id = ? AND user_id = ?',
          parameters: [groupId, userId],
        )
        .map((rows) => rows.isEmpty ? null : _memberFromRow(rows.first));
  }

  @override
  Future<List<GroupMember>> listMyMembers() async {
    final userId = _currentUserId;
    if (userId == null) return const [];
    final rows = await _db.getAll(
      'SELECT * FROM group_members WHERE user_id = ? ORDER BY joined_at ASC',
      [userId],
    );
    return rows.map(_memberFromRow).toList();
  }

  @override
  Stream<List<GroupMember>> watchMyMembers() {
    if (kIsWeb) {
      return _pollStream(listMyMembers, fingerprint: _membersListFp);
    }
    final userId = _currentUserId;
    if (userId == null) {
      return Stream<List<GroupMember>>.value(const []);
    }
    return _db
        .watch(
          'SELECT * FROM group_members WHERE user_id = ? ORDER BY joined_at ASC',
          parameters: [userId],
        )
        .map((rows) => rows.map(_memberFromRow).toList());
  }

  @override
  Future<List<GroupMember>> listByGroup(String groupId) async {
    final rows = await _db.getAll(
      'SELECT * FROM group_members WHERE group_id = ? ORDER BY joined_at ASC',
      [groupId],
    );
    return rows.map(_memberFromRow).toList();
  }

  @override
  Stream<List<GroupMember>> watchByGroup(String groupId) {
    if (kIsWeb) {
      return _pollStream(
        () => listByGroup(groupId),
        fingerprint: _membersListFp,
      );
    }
    return _db
        .watch(
          'SELECT * FROM group_members WHERE group_id = ? ORDER BY joined_at ASC',
          parameters: [groupId],
        )
        .map((rows) => rows.map(_memberFromRow).toList());
  }

  @override
  Future<void> kickMember(String groupId, String memberId) async {
    final client = _supabase;
    if (client != null) {
      await client.rpc(
        'kick_member',
        params: {'p_group_id': groupId, 'p_member_id': memberId},
      );
      Log.info('Member kicked via RPC');
    } else {
      throw UnsupportedError('kickMember requires online mode');
    }
  }

  @override
  Future<void> leave(String groupId) async {
    final client = _supabase;
    if (client != null) {
      await client.rpc('leave_group', params: {'p_group_id': groupId});
      Log.info('Left group via RPC');
    } else {
      throw UnsupportedError('leave requires online mode');
    }
  }

  @override
  Future<void> updateRole(
    String groupId,
    String memberId,
    GroupRole role,
  ) async {
    final client = _supabase;
    if (client != null) {
      await client.rpc(
        'update_member_role',
        params: {
          'p_group_id': groupId,
          'p_member_id': memberId,
          'p_role': role.name,
        },
      );
      Log.info('Member role updated via RPC');
    } else {
      throw UnsupportedError('updateRole requires online mode');
    }
  }

  @override
  Future<void> transferOwnership(
    String groupId,
    String newOwnerMemberId,
  ) async {
    final client = _supabase;
    if (client != null) {
      await client.rpc(
        'transfer_ownership',
        params: {
          'p_group_id': groupId,
          'p_new_owner_member_id': newOwnerMemberId,
        },
      );
      Log.info('Ownership transferred via RPC');
    } else {
      throw UnsupportedError('transferOwnership requires online mode');
    }
  }

  @override
  Future<void> mergeParticipantWithMember(
    String groupId,
    String participantId,
    String memberId,
  ) async {
    final client = _supabase;
    if (client != null) {
      await client.rpc(
        'merge_participant_with_member',
        params: {
          'p_group_id': groupId,
          'p_participant_id': participantId,
          'p_member_id': memberId,
        },
      );
      Log.info('Participant merged with member via RPC');
    } else {
      throw UnsupportedError('mergeParticipantWithMember requires online mode');
    }
  }
}
