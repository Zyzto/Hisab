import '../../domain/domain.dart';

abstract class IGroupRepository {
  Future<List<Group>> getAll();
  Stream<List<Group>> watchAll();
  Future<Group?> getById(String id);
  Future<String> create(String name, String currencyCode);
  Future<void> update(Group group);
  Future<void> delete(String id);
}
