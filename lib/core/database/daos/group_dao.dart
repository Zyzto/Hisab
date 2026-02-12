import 'package:drift/drift.dart';
import '../app_database.dart';
import '../models/groups.dart';
import 'base_dao_mixin.dart';

part 'group_dao.g.dart';

@DriftAccessor(tables: [Groups])
class GroupDao extends DatabaseAccessor<AppDatabase>
    with _$GroupDaoMixin, BaseDaoMixin {
  GroupDao(super.db);

  Future<List<Group>> getAll() async {
    return executeWithErrorHandling(
      operationName: 'getAll',
      operation: () => (select(
        db.groups,
      )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get(),
      onError: () => <Group>[],
    );
  }

  Stream<List<Group>> watchAll() {
    return (select(
      db.groups,
    )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();
  }

  Future<Group?> getById(int id) async {
    return (select(db.groups)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertGroup(GroupsCompanion companion) async {
    return into(db.groups).insert(companion);
  }

  Future<bool> updateGroup(Group group) async {
    return update(db.groups).replace(group);
  }

  Future<int> deleteGroup(int id) async {
    return (delete(db.groups)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes all groups. Cascades to participants, expenses, and expense_tags.
  Future<int> deleteAllGroups() async {
    return delete(db.groups).go();
  }
}
