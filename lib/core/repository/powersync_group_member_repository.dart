part of 'powersync_repository.dart';

// =============================================================================
// PowerSync GroupMember Repository
// =============================================================================

class PowerSyncGroupMemberRepository implements IGroupMemberRepository {
  final PowerSyncDatabase _db;
  final bool isLocalOnly;
  PowerSyncGroupMemberRepository(this._db, {this.isLocalOnly = false});

  String? get _currentUserId => cloudBackend?.auth.currentUser?.id;

  /// Membership changes are always server-authorized, so they need the backend
  /// even when the caller is otherwise offline-capable.
  CloudGroups? get _groups => isLocalOnly ? null : cloudBackend?.groups;

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
    final groups = _groups;
    if (groups == null) {
      throw UnsupportedError('kickMember requires online mode');
    }
    await groups.kickMember(groupId, memberId);
    Log.info('Member kicked');
  }

  @override
  Future<void> leave(String groupId) async {
    final groups = _groups;
    if (groups == null) {
      throw UnsupportedError('leave requires online mode');
    }
    await groups.leaveGroup(groupId);
    Log.info('Left group');
  }

  @override
  Future<void> updateRole(
    String groupId,
    String memberId,
    GroupRole role,
  ) async {
    final groups = _groups;
    if (groups == null) {
      throw UnsupportedError('updateRole requires online mode');
    }
    await groups.updateMemberRole(groupId, memberId, role.name);
    Log.info('Member role updated');
  }

  @override
  Future<void> transferOwnership(
    String groupId,
    String newOwnerMemberId,
  ) async {
    final groups = _groups;
    if (groups == null) {
      throw UnsupportedError('transferOwnership requires online mode');
    }
    await groups.transferOwnership(groupId, newOwnerMemberId);
    Log.info('Ownership transferred');
  }

  @override
  Future<void> mergeParticipantWithMember(
    String groupId,
    String participantId,
    String memberId,
  ) async {
    final groups = _groups;
    if (groups == null) {
      throw UnsupportedError('mergeParticipantWithMember requires online mode');
    }
    await groups.mergeParticipantWithMember(groupId, participantId, memberId);
    Log.info('Participant merged with member');
  }
}
