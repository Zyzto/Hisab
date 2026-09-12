part of 'powersync_repository.dart';

class PowerSyncHouseholdBalanceReassignmentRepository
    implements IHouseholdBalanceReassignmentRepository {
  PowerSyncHouseholdBalanceReassignmentRepository(
    this._db,
  );

  static const _uuid = Uuid();
  final PowerSyncDatabase _db;

  HouseholdBalanceReassignment _fromRow(Map<String, dynamic> row) =>
      HouseholdBalanceReassignment(
        id: row['id'] as String,
        groupId: row['group_id'] as String,
        sourceParticipantId: row['source_participant_id'] as String,
        targetParticipantId: row['target_participant_id'] as String,
        amountCents: (row['amount_cents'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
      );

  @override
  Future<List<HouseholdBalanceReassignment>> getByGroupId(
    String groupId,
  ) async {
    final rows = await _db.getAll(
      'SELECT * FROM household_balance_reassignments WHERE group_id = ? ORDER BY created_at ASC',
      [groupId],
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Stream<List<HouseholdBalanceReassignment>> watchByGroupId(String groupId) {
    if (kIsWeb) {
      return _pollStream(
        () => getByGroupId(groupId),
        fingerprint: (rows) => rows
            .map(
              (r) =>
                  '${r.id}:${r.sourceParticipantId}:${r.targetParticipantId}:${r.amountCents}',
            )
            .join('|'),
      );
    }
    return _db
        .watch(
          'SELECT * FROM household_balance_reassignments WHERE group_id = ? ORDER BY created_at ASC',
          parameters: [groupId],
        )
        .map((rows) => rows.map(_fromRow).toList());
  }

  @override
  Future<void> create({
    required String groupId,
    required String sourceParticipantId,
    required String targetParticipantId,
    required int amountCents,
  }) async {
    if (sourceParticipantId == targetParticipantId) {
      throw ArgumentError('A balance cannot be reassigned to itself');
    }
    if (amountCents == 0) return;
    final id = _uuid.v4();
    final now = _nowIso();
    final data = <String, dynamic>{
      'id': id,
      'group_id': groupId,
      'source_participant_id': sourceParticipantId,
      'target_participant_id': targetParticipantId,
      'amount_cents': amountCents,
      'created_at': now,
    };

    await _db.execute(
      'INSERT INTO household_balance_reassignments (id, group_id, source_participant_id, target_participant_id, amount_cents, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      [id, groupId, sourceParticipantId, targetParticipantId, amountCents, now],
    );
  }
}
