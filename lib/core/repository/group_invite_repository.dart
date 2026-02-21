import '../../domain/domain.dart';

abstract class IGroupInviteRepository {
  Future<({GroupInvite invite, Group group})?> getByToken(String token);
  Future<({String id, String token})> createInvite(
    String groupId, {
    String? inviteeEmail,
    String? role,
    String? label,
    int? maxUses,
    Duration? expiresIn,
  });
  Future<String> accept(String token, {String? newParticipantName});
  Future<List<GroupInvite>> listByGroup(String groupId);
  Stream<List<GroupInvite>> watchByGroup(String groupId);
  Future<void> revoke(String inviteId);
  Future<void> toggleActive(String inviteId, bool active);
  Future<List<InviteUsage>> listUsages(String inviteId);
  Stream<List<InviteUsage>> watchUsages(String inviteId);
}
