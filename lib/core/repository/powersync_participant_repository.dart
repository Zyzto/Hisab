part of 'powersync_repository.dart';

// =============================================================================
// PowerSync Participant Repository
// =============================================================================

class PowerSyncParticipantRepository implements IParticipantRepository {
  final PowerSyncDatabase _db;
  final SupabaseClient? _client;
  final bool _isOnline;
  final bool _isLocalOnly;

  PowerSyncParticipantRepository(
    this._db, {
    SupabaseClient? client,
    bool isOnline = false,
    bool isLocalOnly = true,
  }) : _client = client,
       _isOnline = isOnline,
       _isLocalOnly = isLocalOnly;

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
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 100) {
      throw ArgumentError(
        'Participant name must be 1–100 characters (got ${trimmedName.length})',
      );
    }
    final id = _uuid.v4();
    final now = _nowIso();
    final data = <String, dynamic>{
      'id': id,
      'group_id': groupId,
      'name': trimmedName,
      'sort_order': order,
      'user_id': userId,
      'avatar_id': avatarId,
      'created_at': now,
      'updated_at': now,
    };

    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client.from('participants').insert(data);
    } else if (_shouldQueueOffline(
      isLocalOnly: _isLocalOnly,
      isOnline: _isOnline,
    )) {
      await _enqueue(
        _db,
        tableName: 'participants',
        operation: 'insert',
        rowId: id,
        data: data,
      );
    }

    await _db.execute(
      'INSERT INTO participants (id, group_id, name, sort_order, user_id, avatar_id, left_at, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [id, groupId, trimmedName, order, userId, avatarId, null, now, now],
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
    final now = _nowIso();

    final leftAtIso = participant.leftAt?.toUtc().toIso8601String();
    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client
          .from('participants')
          .update({
            'name': trimmedName,
            'sort_order': participant.order,
            'avatar_id': participant.avatarId,
            'left_at': leftAtIso,
            'updated_at': now,
          })
          .eq('id', participant.id);
    } else if (_shouldQueueOffline(
      isLocalOnly: _isLocalOnly,
      isOnline: _isOnline,
    )) {
      await _enqueue(
        _db,
        tableName: 'participants',
        operation: 'update',
        rowId: participant.id,
        data: {
          'name': trimmedName,
          'sort_order': participant.order,
          'avatar_id': participant.avatarId,
          'left_at': leftAtIso,
          'updated_at': now,
        },
      );
    }

    await _db.execute(
      'UPDATE participants SET name = ?, sort_order = ?, avatar_id = ?, left_at = ?, updated_at = ? WHERE id = ?',
      [
        trimmedName,
        participant.order,
        participant.avatarId,
        leftAtIso,
        now,
        participant.id,
      ],
    );
  }

  @override
  Future<void> archive(String groupId, String participantId) async {
    final now = _nowIso();
    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client.rpc(
        'archive_participant',
        params: {'p_group_id': groupId, 'p_participant_id': participantId},
      );
      Log.info('Participant archived via RPC');
    } else if (_shouldQueueOffline(
      isLocalOnly: _isLocalOnly,
      isOnline: _isOnline,
    )) {
      await _enqueue(
        _db,
        tableName: 'participants',
        operation: 'update',
        rowId: participantId,
        data: {'left_at': now, 'updated_at': now},
      );
    }
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
    final updates = <String, dynamic>{'name': trimmedName, 'updated_at': now};
    if (avatarId != null) updates['avatar_id'] = avatarId;

    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client.from('participants').update(updates).eq('user_id', userId);
    } else if (_shouldQueueOffline(
      isLocalOnly: _isLocalOnly,
      isOnline: _isOnline,
    )) {
      final rows = await _db.getAll(
        'SELECT id FROM participants WHERE user_id = ?',
        [userId],
      );
      for (final row in rows) {
        final participantId = row['id'] as String?;
        if (participantId == null) continue;
        await _enqueue(
          _db,
          tableName: 'participants',
          operation: 'update',
          rowId: participantId,
          data: updates,
        );
      }
    }

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
    Log.info(
      'ParticipantRepository.delete: participantId=$id localOnly=$_isLocalOnly online=$_isOnline',
    );
    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client.from('participants').delete().eq('id', id);
      Log.info('ParticipantRepository.delete: deleted on server');
    } else if (_shouldQueueOffline(
      isLocalOnly: _isLocalOnly,
      isOnline: _isOnline,
    )) {
      await _enqueue(
        _db,
        tableName: 'participants',
        operation: 'delete',
        rowId: id,
      );
    }
    await _db.execute('DELETE FROM participants WHERE id = ?', [id]);
    Log.info('ParticipantRepository.delete: deleted from local DB');
  }
}
