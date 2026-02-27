import '../../domain/domain.dart';

abstract class ITagRepository {
  Future<List<ExpenseTag>> getAll();
  Future<List<ExpenseTag>> getByGroupId(String groupId);
  Stream<List<ExpenseTag>> watchByGroupId(String groupId);
  Future<ExpenseTag?> getById(String id);
  Future<String> create(String groupId, String label, String iconName);
  Future<void> update(ExpenseTag tag);
  Future<void> delete(String id);
}
