import '../../domain/domain.dart';

abstract class IGroupInviteRepository {
  Future<({GroupInvite invite, Group group})?> getByToken(String token);
  Future<({String id, String token})> createInvite(
    String groupId, {
    String? inviteeEmail,
    String? role,
  });
  Future<String> accept(
    String token, {
    String? participantId,
    String? newParticipantName,
  });
  Future<List<GroupInvite>> listByGroup(String groupId);
  Stream<List<GroupInvite>> watchByGroup(String groupId);
  Future<void> revoke(String inviteId);
}
