part of 'powersync_repository.dart';

// =============================================================================
// PowerSync Tag Repository
// =============================================================================

class PowerSyncTagRepository implements ITagRepository {
  final PowerSyncDatabase _db;
  final SupabaseClient? _client;
  final bool _isOnline;
  final bool _isLocalOnly;

  PowerSyncTagRepository(
    this._db, {
    SupabaseClient? client,
    bool isOnline = false,
    bool isLocalOnly = true,
  }) : _client = client,
       _isOnline = isOnline,
       _isLocalOnly = isLocalOnly;

  @override
  Future<List<ExpenseTag>> getAll() async {
    final rows = await _db.getAll(
      'SELECT * FROM expense_tags ORDER BY label ASC',
    );
    return rows.map(_tagFromRow).toList();
  }

  @override
  Future<List<ExpenseTag>> getByGroupId(String groupId) async {
    final rows = await _db.getAll(
      'SELECT * FROM expense_tags WHERE group_id = ? ORDER BY label ASC',
      [groupId],
    );
    return rows.map(_tagFromRow).toList();
  }

  @override
  Stream<List<ExpenseTag>> watchByGroupId(String groupId) {
    if (kIsWeb) {
      return _pollStream(
        () => getByGroupId(groupId),
        fingerprint: (list) => Object.hashAll(
          list.map((t) => Object.hash(t.id, t.groupId, t.label)),
        ),
      );
    }
    return _db
        .watch(
          'SELECT * FROM expense_tags WHERE group_id = ? ORDER BY label ASC',
          parameters: [groupId],
        )
        .map((rows) => rows.map(_tagFromRow).toList());
  }

  @override
  Future<ExpenseTag?> getById(String id) async {
    final rows = await _db.getAll('SELECT * FROM expense_tags WHERE id = ?', [
      id,
    ]);
    if (rows.isEmpty) return null;
    return _tagFromRow(rows.first);
  }

  @override
  Future<String> create(
    String groupId,
    String label,
    String iconName, {
    String? colorHex,
  }) async {
    final trimmedLabel = label.trim();
    final trimmedIcon = iconName.trim();
    final normalizedColor = _normalizeTagColorHex(colorHex);
    if (trimmedLabel.isEmpty || trimmedLabel.length > 100) {
      throw ArgumentError(
        'Tag label must be 1–100 characters (got ${trimmedLabel.length})',
      );
    }
    if (trimmedIcon.isEmpty || trimmedIcon.length > 80) {
      throw ArgumentError(
        'Tag icon_name must be 1–80 characters (got ${trimmedIcon.length})',
      );
    }
    final id = _uuid.v4();
    final now = _nowIso();
    final data = <String, dynamic>{
      'id': id,
      'group_id': groupId,
      'label': trimmedLabel,
      'icon_name': trimmedIcon,
      'color': normalizedColor,
      'created_at': now,
      'updated_at': now,
    };

    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client.from('expense_tags').insert(data);
    } else if (_shouldQueueOffline(
      isLocalOnly: _isLocalOnly,
      isOnline: _isOnline,
    )) {
      await _enqueue(
        _db,
        tableName: 'expense_tags',
        operation: 'insert',
        rowId: id,
        data: data,
      );
    }

    await _db.execute(
      'INSERT INTO expense_tags (id, group_id, label, icon_name, color, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [id, groupId, trimmedLabel, trimmedIcon, normalizedColor, now, now],
    );
    return id;
  }

  @override
  Future<void> update(ExpenseTag tag) async {
    final trimmedLabel = tag.label.trim();
    final trimmedIcon = tag.iconName.trim();
    final normalizedColor = _normalizeTagColorHex(tag.colorHex);
    if (trimmedLabel.isEmpty || trimmedLabel.length > 100) {
      throw ArgumentError(
        'Tag label must be 1–100 characters (got ${trimmedLabel.length})',
      );
    }
    if (trimmedIcon.isEmpty || trimmedIcon.length > 80) {
      throw ArgumentError(
        'Tag icon_name must be 1–80 characters (got ${trimmedIcon.length})',
      );
    }
    final now = _nowIso();

    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client
          .from('expense_tags')
          .update({
            'label': trimmedLabel,
            'icon_name': trimmedIcon,
            'color': normalizedColor,
            'updated_at': now,
          })
          .eq('id', tag.id);
    } else if (_shouldQueueOffline(
      isLocalOnly: _isLocalOnly,
      isOnline: _isOnline,
    )) {
      await _enqueue(
        _db,
        tableName: 'expense_tags',
        operation: 'update',
        rowId: tag.id,
        data: {
          'label': trimmedLabel,
          'icon_name': trimmedIcon,
          'color': normalizedColor,
          'updated_at': now,
        },
      );
    }

    await _db.execute(
      'UPDATE expense_tags SET label = ?, icon_name = ?, color = ?, updated_at = ? WHERE id = ?',
      [trimmedLabel, trimmedIcon, normalizedColor, now, tag.id],
    );
  }

  @override
  Future<void> delete(String id) async {
    if (!_isLocalOnly && _isOnline && _client != null) {
      await _client.from('expense_tags').delete().eq('id', id);
    } else if (_shouldQueueOffline(
      isLocalOnly: _isLocalOnly,
      isOnline: _isOnline,
    )) {
      await _enqueue(
        _db,
        tableName: 'expense_tags',
        operation: 'delete',
        rowId: id,
      );
    }
    await _db.execute('DELETE FROM expense_tags WHERE id = ?', [id]);
  }
}
