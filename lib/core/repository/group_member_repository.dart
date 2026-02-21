import '../../domain/domain.dart';

abstract class IGroupMemberRepository {
  Future<GroupRole?> getMyRole(String groupId);
  Future<GroupMember?> getMyMember(String groupId);
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
