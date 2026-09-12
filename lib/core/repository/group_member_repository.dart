import '../../domain/domain.dart';

/// Read-only compatibility surface for membership rows from older databases.
///
/// Local-only groups use participants directly and never create these rows.
abstract class IGroupMemberRepository {
  Future<GroupRole?> getMyRole(String groupId);
  Future<GroupMember?> getMyMember(String groupId);
  Stream<GroupMember?> watchMyMember(String groupId);
  Future<List<GroupMember>> listMyMembers();
  Stream<List<GroupMember>> watchMyMembers();
  Future<List<GroupMember>> listByGroup(String groupId);
  Stream<List<GroupMember>> watchByGroup(String groupId);
  Future<void> kickMember(String groupId, String memberId);
  Future<void> leave(String groupId);
  Future<void> updateRole(String groupId, String memberId, GroupRole role);
  Future<void> transferOwnership(String groupId, String newOwnerMemberId);
  Future<void> mergeParticipantWithMember(
    String groupId,
    String participantId,
    String memberId,
  );
}
