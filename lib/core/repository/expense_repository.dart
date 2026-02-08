import '../../domain/domain.dart';

abstract class IExpenseRepository {
  Future<List<Expense>> getByGroupId(String groupId);
  Stream<List<Expense>> watchByGroupId(String groupId);
  Future<Expense?> getById(String id);
  Future<String> create(Expense expense);
  Future<void> update(Expense expense);
  Future<void> delete(String id);
}
