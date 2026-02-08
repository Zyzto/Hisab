import 'package:drift/drift.dart';
import '../app_database.dart';
import '../models/expense_tags.dart';
import 'base_dao_mixin.dart';

part 'expense_tag_dao.g.dart';

@DriftAccessor(tables: [ExpenseTags])
class ExpenseTagDao extends DatabaseAccessor<AppDatabase>
    with _$ExpenseTagDaoMixin, BaseDaoMixin {
  ExpenseTagDao(super.db);

  Future<List<ExpenseTagRow>> getByGroupId(int groupId) async {
    return executeWithErrorHandling(
      operationName: 'getByGroupId',
      operation: () =>
          (select(db.expenseTags)
                ..where((t) => t.groupId.equals(groupId))
                ..orderBy([(t) => OrderingTerm.asc(t.label)]))
              .get(),
      onError: () => <ExpenseTagRow>[],
    );
  }

  Stream<List<ExpenseTagRow>> watchByGroupId(int groupId) {
    return (select(db.expenseTags)
          ..where((t) => t.groupId.equals(groupId))
          ..orderBy([(t) => OrderingTerm.asc(t.label)]))
        .watch();
  }

  Future<ExpenseTagRow?> getById(int id) async {
    return (select(
      db.expenseTags,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertTag(ExpenseTagsCompanion companion) async {
    return into(db.expenseTags).insert(companion);
  }

  Future<bool> updateTag(ExpenseTagRow row) async {
    return update(db.expenseTags).replace(row);
  }

  Future<int> deleteTag(int id) async {
    return (delete(db.expenseTags)..where((t) => t.id.equals(id))).go();
  }
}
