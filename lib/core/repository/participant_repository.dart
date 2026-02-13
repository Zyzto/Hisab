import '../../domain/domain.dart';

abstract class IParticipantRepository {
  Future<List<Participant>> getByGroupId(String groupId);
  Stream<List<Participant>> watchByGroupId(String groupId);
  Future<Participant?> getById(String id);
  Future<String> create(String groupId, String name, int order, {String? userId, String? avatarId});
  Future<void> update(Participant participant);
  Future<void> updateProfileByUserId(String userId, String newName, {String? avatarId});
  Future<void> delete(String id);
}
