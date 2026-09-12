part of 'powersync_repository.dart';

/// Compatibility reader for the legacy group_members table.
class PowerSyncGroupMemberRepository implements IGroupMemberRepository {
  PowerSyncGroupMemberRepository(this._db);

  final PowerSyncDatabase _db;

  @override
  Future<GroupRole?> getMyRole(String groupId) async => null;

  @override
  Future<GroupMember?> getMyMember(String groupId) async => null;

  @override
  Stream<GroupMember?> watchMyMember(String groupId) =>
      Stream<GroupMember?>.value(null);

  @override
  Future<List<GroupMember>> listMyMembers() async => const [];

  @override
  Stream<List<GroupMember>> watchMyMembers() =>
      Stream<List<GroupMember>>.value(const []);

  @override
  Future<List<GroupMember>> listByGroup(String groupId) async {
    final rows = await _db.getAll(
      'SELECT * FROM group_members WHERE group_id = ? ORDER BY joined_at ASC',
      [groupId],
    );
    return rows.map(_legacyMemberFromRow).toList();
  }

  @override
  Stream<List<GroupMember>> watchByGroup(String groupId) {
    if (kIsWeb) return _pollStream(() => listByGroup(groupId));
    return _db
        .watch(
          'SELECT * FROM group_members WHERE group_id = ? ORDER BY joined_at ASC',
          parameters: [groupId],
        )
        .map((rows) => rows.map(_legacyMemberFromRow).toList());
  }

  @override
  Future<void> kickMember(String groupId, String memberId) =>
      _unsupported();

  @override
  Future<void> leave(String groupId) => _unsupported();

  @override
  Future<void> updateRole(String groupId, String memberId, GroupRole role) =>
      _unsupported();

  @override
  Future<void> transferOwnership(String groupId, String newOwnerMemberId) =>
      _unsupported();

  @override
  Future<void> mergeParticipantWithMember(
    String groupId,
    String participantId,
    String memberId,
  ) => _unsupported();

  Future<void> _unsupported() async {
    throw UnsupportedError('Legacy membership is read-only');
  }
}

GroupMember _legacyMemberFromRow(Map<String, dynamic> row) => GroupMember(
  id: row['id'] as String,
  groupId: row['group_id'] as String,
  userId: row['user_id'] as String,
  role: row['role'] as String? ?? 'member',
  participantId: row['participant_id'] as String?,
  joinedAt: _parseDateTime(row['joined_at']),
);
