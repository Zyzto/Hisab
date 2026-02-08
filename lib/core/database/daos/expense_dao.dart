import 'package:drift/drift.dart';
import '../app_database.dart';
import '../models/expenses.dart';
import 'base_dao_mixin.dart';

part 'expense_dao.g.dart';

@DriftAccessor(tables: [Expenses])
class ExpenseDao extends DatabaseAccessor<AppDatabase>
    with _$ExpenseDaoMixin, BaseDaoMixin {
  ExpenseDao(super.db);

  Future<List<Expense>> getByGroupId(int groupId) async {
    return executeWithErrorHandling(
      operationName: 'getByGroupId',
      operation: () =>
          (select(db.expenses)
                ..where((t) => t.groupId.equals(groupId))
                ..orderBy([(t) => OrderingTerm.desc(t.date)]))
              .get(),
      onError: () => <Expense>[],
    );
  }

  Stream<List<Expense>> watchByGroupId(int groupId) {
    return (select(db.expenses)
          ..where((t) => t.groupId.equals(groupId))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  Future<Expense?> getById(int id) async {
    return (select(
      db.expenses,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertExpense(ExpensesCompanion companion) async {
    return into(db.expenses).insert(companion);
  }

  Future<bool> updateExpense(Expense expense) async {
    return update(db.expenses).replace(expense);
  }

  Future<int> deleteExpense(int id) async {
    return (delete(db.expenses)..where((t) => t.id.equals(id))).go();
  }
}
