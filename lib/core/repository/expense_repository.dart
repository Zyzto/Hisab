import '../../domain/domain.dart';

abstract class IExpenseRepository {
  Future<List<Expense>> getAll();

  /// Live updates for every expense (one query instead of per-group watches).
  Stream<List<Expense>> watchAll();
  Future<List<Expense>> getByGroupId(String groupId);
  Stream<List<Expense>> watchByGroupId(String groupId);
  Future<Expense?> getById(String id);

  /// Live updates for a single expense (native SQLite watch / web poll).
  Stream<Expense?> watchById(String id);
  Future<String> create(Expense expense);
  Future<void> update(Expense expense);
  Future<void> delete(String id);
}
