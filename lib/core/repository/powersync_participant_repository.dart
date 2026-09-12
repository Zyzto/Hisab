part of 'powersync_repository.dart';

// =============================================================================
// PowerSync Participant Repository
// =============================================================================

class PowerSyncParticipantRepository implements IParticipantRepository {
  final PowerSyncDatabase _db;

  PowerSyncParticipantRepository(this._db);

  @override
  Future<List<Participant>> getAll() async {
    final rows = await _db.getAll(
      'SELECT * FROM participants ORDER BY sort_order ASC',
    );
    return rows.map(_participantFromRow).toList();
  }

  @override
  Stream<List<Participant>> watchAll() {
    if (kIsWeb) {
      return _pollStream(getAll, fingerprint: _participantsListFp);
    }
    return _db
        .watch('SELECT * FROM participants ORDER BY sort_order ASC')
        .map((rows) => rows.map(_participantFromRow).toList());
  }

  @override
  Future<List<Participant>> getByGroupId(String groupId) async {
    final rows = await _db.getAll(
      'SELECT * FROM participants WHERE group_id = ? ORDER BY sort_order ASC',
      [groupId],
    );
    return rows.map(_participantFromRow).toList();
  }

  @override
  Stream<List<Participant>> watchByGroupId(String groupId) {
    if (kIsWeb) {
      return _pollStream(
        () => getByGroupId(groupId),
        fingerprint: _participantsListFp,
      );
    }
    return _db
        .watch(
          'SELECT * FROM participants WHERE group_id = ? ORDER BY sort_order ASC',
          parameters: [groupId],
        )
        .map((rows) => rows.map(_participantFromRow).toList());
  }

  @override
  Future<Participant?> getById(String id) async {
    final rows = await _db.getAll('SELECT * FROM participants WHERE id = ?', [
      id,
    ]);
    if (rows.isEmpty) return null;
    return _participantFromRow(rows.first);
  }

  @override
  Future<String> create(
    String groupId,
    String name,
    int order, {
    String? userId,
    String? avatarId,
    String? parentParticipantId,
    int unnamedDependentCount = 0,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 100) {
      throw ArgumentError(
        'Participant name must be 1–100 characters (got ${trimmedName.length})',
      );
    }
    if (unnamedDependentCount < 0 || unnamedDependentCount > 999) {
      throw ArgumentError('unnamedDependentCount must be between 0 and 999');
    }
    final id = _uuid.v4();
    final now = _nowIso();
    await _validateHouseholdParticipant(
      Participant(
        id: id,
        groupId: groupId,
        name: trimmedName,
        order: order,
        userId: userId,
        avatarId: avatarId,
        parentParticipantId: parentParticipantId,
        unnamedDependentCount: unnamedDependentCount,
        createdAt: DateTime.parse(now),
        updatedAt: DateTime.parse(now),
      ),
    );
    await _db.execute(
      'INSERT INTO participants (id, group_id, name, sort_order, user_id, avatar_id, left_at, parent_participant_id, unnamed_dependent_count, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        groupId,
        trimmedName,
        order,
        userId,
        avatarId,
        null,
        parentParticipantId,
        unnamedDependentCount,
        now,
        now,
      ],
    );
    return id;
  }

  @override
  Future<void> update(Participant participant) async {
    final trimmedName = participant.name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 100) {
      throw ArgumentError(
        'Participant name must be 1–100 characters (got ${trimmedName.length})',
      );
    }
    if (participant.unnamedDependentCount < 0 ||
        participant.unnamedDependentCount > 999) {
      throw ArgumentError('unnamedDependentCount must be between 0 and 999');
    }
    if (participant.parentParticipantId == participant.id) {
      throw ArgumentError('A participant cannot be its own parent');
    }
    await _validateHouseholdParticipant(
      participant.copyWith(name: trimmedName),
    );
    final now = _nowIso();

    final leftAtIso = participant.leftAt?.toUtc().toIso8601String();
    final existing = await getById(participant.id);
    final householdChanged =
        existing == null ||
        existing.parentParticipantId != participant.parentParticipantId ||
        existing.unnamedDependentCount != participant.unnamedDependentCount;
    await _db.execute(
      'UPDATE participants SET name = ?, sort_order = ?, avatar_id = ?, left_at = ?, parent_participant_id = ?, unnamed_dependent_count = ?, updated_at = ? WHERE id = ?',
      [
        trimmedName,
        participant.order,
        participant.avatarId,
        leftAtIso,
        participant.parentParticipantId,
        participant.unnamedDependentCount,
        now,
        participant.id,
      ],
    );
  }

  Future<void> _validateHouseholdParticipant(Participant candidate) async {
    final parentId = candidate.parentParticipantId;
    if (parentId == null) return;
    if (parentId == candidate.id) {
      throw ArgumentError('A participant cannot be its own parent');
    }
    final parent = await getById(parentId);
    if (parent == null || parent.groupId != candidate.groupId) {
      throw ArgumentError('Household parent must belong to the same group');
    }
    final participants = await getByGroupId(candidate.groupId);
    final withoutCandidate = participants
        .where((p) => p.id != candidate.id)
        .toList();
    withoutCandidate.add(candidate);
    HouseholdService.rootByParticipant(withoutCandidate);
  }

  @override
  Future<void> archive(String groupId, String participantId) async {
    final now = _nowIso();
    await _db.execute(
      'UPDATE participants SET left_at = ?, updated_at = ? WHERE id = ?',
      [now, now, participantId],
    );
  }

  @override
  Future<void> updateProfileByUserId(
    String userId,
    String newName, {
    String? avatarId,
  }) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty || trimmedName.length > 100) {
      throw ArgumentError(
        'Participant name must be 1–100 characters (got ${trimmedName.length})',
      );
    }
    final now = _nowIso();
    if (avatarId != null) {
      await _db.execute(
        'UPDATE participants SET name = ?, avatar_id = ?, updated_at = ? WHERE user_id = ?',
        [trimmedName, avatarId, now, userId],
      );
    } else {
      await _db.execute(
        'UPDATE participants SET name = ?, updated_at = ? WHERE user_id = ?',
        [trimmedName, now, userId],
      );
    }
  }

  @override
  Future<void> delete(String id) async {
    await _db.execute('DELETE FROM participants WHERE id = ?', [id]);
  }
}
