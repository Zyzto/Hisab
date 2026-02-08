import 'package:drift/drift.dart';
import '../app_database.dart';
import '../models/participants.dart';
import 'base_dao_mixin.dart';

part 'participant_dao.g.dart';

@DriftAccessor(tables: [Participants])
class ParticipantDao extends DatabaseAccessor<AppDatabase>
    with _$ParticipantDaoMixin, BaseDaoMixin {
  ParticipantDao(super.db);

  Future<List<Participant>> getByGroupId(int groupId) async {
    return executeWithErrorHandling(
      operationName: 'getByGroupId',
      operation: () =>
          (select(db.participants)
                ..where((t) => t.groupId.equals(groupId))
                ..orderBy([(t) => OrderingTerm.asc(t.order)]))
              .get(),
      onError: () => <Participant>[],
    );
  }

  Stream<List<Participant>> watchByGroupId(int groupId) {
    return (select(db.participants)
          ..where((t) => t.groupId.equals(groupId))
          ..orderBy([(t) => OrderingTerm.asc(t.order)]))
        .watch();
  }

  Future<Participant?> getById(int id) async {
    return (select(
      db.participants,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertParticipant(ParticipantsCompanion companion) async {
    return into(db.participants).insert(companion);
  }

  Future<bool> updateParticipant(Participant participant) async {
    return update(db.participants).replace(participant);
  }

  Future<int> deleteParticipant(int id) async {
    return (delete(db.participants)..where((t) => t.id.equals(id))).go();
  }
}
