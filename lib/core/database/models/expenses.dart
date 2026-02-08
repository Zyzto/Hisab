import 'package:drift/drift.dart';
import 'groups.dart';
import 'participants.dart';

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId =>
      integer().references(Groups, #id, onDelete: KeyAction.cascade)();
  IntColumn get payerParticipantId =>
      integer().references(Participants, #id, onDelete: KeyAction.cascade)();
  IntColumn get amountCents => integer()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  DateTimeColumn get date => dateTime()();
  TextColumn get splitType => text()(); // 'equal' | 'parts' | 'amounts'
  TextColumn get splitSharesJson =>
      text().nullable()(); // JSON map participantId -> cents or percentage
  TextColumn get type => text().withDefault(const Constant('expense'))();
  IntColumn get toParticipantId =>
      integer().nullable().references(Participants, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
