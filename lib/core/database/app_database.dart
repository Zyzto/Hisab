import 'package:drift/drift.dart';
import 'models/groups.dart';
import 'models/participants.dart';
import 'models/expenses.dart';
import 'database_connection.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Groups, Participants, Expenses])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Future migrations go here
    },
  );
}
