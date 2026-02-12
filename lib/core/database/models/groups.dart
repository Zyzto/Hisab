import 'package:drift/drift.dart';

class Groups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get settlementMethod =>
      text().withDefault(const Constant('greedy'))();
  IntColumn get treasurerParticipantId => integer().nullable()();
  DateTimeColumn get settlementFreezeAt => dateTime().nullable()();
  TextColumn get settlementSnapshotJson => text().nullable()();
}
