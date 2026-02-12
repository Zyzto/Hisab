import 'package:drift/drift.dart';
import 'models/groups.dart';
import 'models/participants.dart';
import 'models/expenses.dart';
import 'models/expense_tags.dart';
import 'database_connection.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Groups, Participants, Expenses, ExpenseTags])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(expenseTags);
      }
      if (from < 3) {
        try {
          await m.addColumn(expenses, expenses.description);
        } catch (e) {
          if (!e.toString().contains('duplicate column name')) rethrow;
        }
        try {
          await m.addColumn(expenses, expenses.receiptImagePath);
        } catch (e) {
          if (!e.toString().contains('duplicate column name')) rethrow;
        }
      }
      if (from < 4) {
        try {
          await m.addColumn(groups, groups.settlementMethod);
        } catch (e) {
          if (!e.toString().contains('duplicate column name')) rethrow;
        }
        try {
          await m.addColumn(groups, groups.treasurerParticipantId);
        } catch (e) {
          if (!e.toString().contains('duplicate column name')) rethrow;
        }
        try {
          await m.addColumn(groups, groups.settlementFreezeAt);
        } catch (e) {
          if (!e.toString().contains('duplicate column name')) rethrow;
        }
        try {
          await m.addColumn(groups, groups.settlementSnapshotJson);
        } catch (e) {
          if (!e.toString().contains('duplicate column name')) rethrow;
        }
      }
    },
  );
}
