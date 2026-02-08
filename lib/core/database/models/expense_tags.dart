import 'package:drift/drift.dart';
import 'groups.dart';

@DataClassName('ExpenseTagRow')
class ExpenseTags extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId =>
      integer().references(Groups, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text().withLength(min: 1, max: 100)();
  TextColumn get iconName => text().withLength(min: 1, max: 80)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
