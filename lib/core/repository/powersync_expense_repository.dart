part of 'powersync_repository.dart';

// =============================================================================
// PowerSync Expense Repository
// =============================================================================

class PowerSyncExpenseRepository implements IExpenseRepository {
  final PowerSyncDatabase _db;
  final CloudBackend? _cloud;
  final bool _isOnline;
  final bool _isLocalOnly;

  PowerSyncExpenseRepository(
    this._db, {
    CloudBackend? cloud,
    bool isOnline = false,
    bool isLocalOnly = true,
  }) : _cloud = cloud,
       _isOnline = isOnline,
       _isLocalOnly = isLocalOnly;

  @override
  Future<List<Expense>> getAll() async {
    final rows = await _db.getAll('SELECT * FROM expenses ORDER BY date DESC');
    return rows.map(_expenseFromRow).toList();
  }

  @override
  Stream<List<Expense>> watchAll() {
    if (kIsWeb) {
      return _pollStream(getAll, fingerprint: _expensesListFp);
    }
    return _db
        .watch('SELECT * FROM expenses ORDER BY date DESC')
        .map((rows) => rows.map(_expenseFromRow).toList());
  }

  @override
  Future<List<Expense>> getByGroupId(String groupId) async {
    final rows = await _db.getAll(
      'SELECT * FROM expenses WHERE group_id = ? ORDER BY date DESC',
      [groupId],
    );
    return rows.map(_expenseFromRow).toList();
  }

  @override
  Stream<List<Expense>> watchByGroupId(String groupId) {
    if (kIsWeb) {
      return _pollStream(
        () => getByGroupId(groupId),
        fingerprint: _expensesListFp,
      );
    }
    return _db
        .watch(
          'SELECT * FROM expenses WHERE group_id = ? ORDER BY date DESC',
          parameters: [groupId],
        )
        .map((rows) => rows.map(_expenseFromRow).toList());
  }

  @override
  Future<Expense?> getById(String id) async {
    final rows = await _db.getAll('SELECT * FROM expenses WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return _expenseFromRow(rows.first);
  }

  @override
  Stream<Expense?> watchById(String id) {
    if (kIsWeb) {
      return _pollStream(() => getById(id), fingerprint: _expenseFp);
    }
    return _db
        .watch('SELECT * FROM expenses WHERE id = ?', parameters: [id])
        .map((rows) => rows.isEmpty ? null : _expenseFromRow(rows.first));
  }

  @override
  Future<String> create(Expense expense) async {
    final title = expense.title.trim();
    if (title.isEmpty || title.length > 500) {
      throw ArgumentError(
        'Expense title must be 1–500 characters (got ${title.length})',
      );
    }
    if (expense.amountCents <= 0) {
      throw ArgumentError('Expense amount_cents must be positive');
    }
    if (expense.currencyCode.trim().length != 3) {
      throw ArgumentError('currency_code must be 3 characters');
    }
    final id = _uuid.v4();
    final now = _nowIso();
    final splitSharesJson = jsonEncode(expense.splitShares);
    final lineItemsJson = expense.lineItems != null
        ? jsonEncode(expense.lineItems!.map((e) => e.toJson()).toList())
        : null;

    final imagePaths =
        expense.imagePaths ??
        (expense.imagePath != null ? [expense.imagePath!] : null);
    final imagePath = imagePaths != null && imagePaths.isNotEmpty
        ? imagePaths.first
        : expense.imagePath;
    final imagePathsJson = imagePaths != null ? jsonEncode(imagePaths) : null;
    final data = <String, dynamic>{
      'id': id,
      'group_id': expense.groupId,
      'payer_participant_id': expense.payerParticipantId,
      'amount_cents': expense.amountCents,
      'currency_code': expense.currencyCode.trim().toUpperCase(),
      'exchange_rate': expense.exchangeRate,
      'base_amount_cents': expense.baseAmountCents,
      'title': title,
      'description': expense.description,
      'date': expense.date.toUtc().toIso8601String(),
      'split_type': expense.splitType.name,
      'split_shares_json': splitSharesJson,
      'type': expense.transactionType.name,
      'to_participant_id': expense.toParticipantId,
      'tag': expense.tag,
      'line_items_json': lineItemsJson,
      'image_path': imagePath,
      'image_paths': imagePathsJson,
      'created_at': now,
      'updated_at': now,
    };

    if (!_isLocalOnly && _isOnline && _cloud != null) {
      // Online: write to Supabase first
      await _cloud.sync.upsert('expenses', data);
    } else if (!_isLocalOnly && !_isOnline) {
      // Online mode but temporarily offline: queue for later push
      await _enqueue(
        _db,
        tableName: 'expenses',
        operation: 'insert',
        rowId: id,
        data: data,
      );
    }

    // Always write to local DB
    await _db.execute(
      '''INSERT INTO expenses (id, group_id, payer_participant_id, amount_cents,
        currency_code, exchange_rate, base_amount_cents,
        title, description, date, split_type, split_shares_json,
        type, to_participant_id, tag, line_items_json, image_path, image_paths,
        created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        id,
        expense.groupId,
        expense.payerParticipantId,
        expense.amountCents,
        data['currency_code'],
        expense.exchangeRate,
        expense.baseAmountCents,
        title,
        expense.description,
        expense.date.toUtc().toIso8601String(),
        expense.splitType.name,
        splitSharesJson,
        expense.transactionType.name,
        expense.toParticipantId,
        expense.tag,
        lineItemsJson,
        imagePath,
        imagePathsJson,
        now,
        now,
      ],
    );
    return id;
  }

  @override
  Future<void> update(Expense expense) async {
    final title = expense.title.trim();
    if (title.isEmpty || title.length > 500) {
      throw ArgumentError(
        'Expense title must be 1–500 characters (got ${title.length})',
      );
    }
    if (expense.amountCents <= 0) {
      throw ArgumentError('Expense amount_cents must be positive');
    }
    if (expense.currencyCode.trim().length != 3) {
      throw ArgumentError('currency_code must be 3 characters');
    }
    final now = _nowIso();
    final splitSharesJson = jsonEncode(expense.splitShares);
    final lineItemsJson = expense.lineItems != null
        ? jsonEncode(expense.lineItems!.map((e) => e.toJson()).toList())
        : null;
    final imagePaths =
        expense.imagePaths ??
        (expense.imagePath != null ? [expense.imagePath!] : null);
    final imagePath = imagePaths != null && imagePaths.isNotEmpty
        ? imagePaths.first
        : expense.imagePath;
    final imagePathsJson = imagePaths != null ? jsonEncode(imagePaths) : null;
    final currencyCode = expense.currencyCode.trim().toUpperCase();

    if (!_isLocalOnly && _isOnline && _cloud != null) {
      await _cloud.sync.update('expenses', {
        'title': title,
        'amount_cents': expense.amountCents,
        'currency_code': currencyCode,
        'exchange_rate': expense.exchangeRate,
        'base_amount_cents': expense.baseAmountCents,
        'payer_participant_id': expense.payerParticipantId,
        'description': expense.description,
        'date': expense.date.toUtc().toIso8601String(),
        'split_type': expense.splitType.name,
        'split_shares_json': splitSharesJson,
        'type': expense.transactionType.name,
        'to_participant_id': expense.toParticipantId,
        'tag': expense.tag,
        'line_items_json': lineItemsJson,
        'image_path': imagePath,
        'image_paths': imagePathsJson,
        'updated_at': now,
      }, expense.id);
    } else if (_shouldQueueOffline(
      isLocalOnly: _isLocalOnly,
      isOnline: _isOnline,
    )) {
      await _enqueue(
        _db,
        tableName: 'expenses',
        operation: 'update',
        rowId: expense.id,
        data: {
          'title': title,
          'amount_cents': expense.amountCents,
          'currency_code': currencyCode,
          'exchange_rate': expense.exchangeRate,
          'base_amount_cents': expense.baseAmountCents,
          'payer_participant_id': expense.payerParticipantId,
          'description': expense.description,
          'date': expense.date.toUtc().toIso8601String(),
          'split_type': expense.splitType.name,
          'split_shares_json': splitSharesJson,
          'type': expense.transactionType.name,
          'to_participant_id': expense.toParticipantId,
          'tag': expense.tag,
          'line_items_json': lineItemsJson,
          'image_path': imagePath,
          'image_paths': imagePathsJson,
          'updated_at': now,
        },
      );
    }

    await _db.execute(
      '''UPDATE expenses SET
        title = ?, amount_cents = ?, currency_code = ?,
        exchange_rate = ?, base_amount_cents = ?,
        payer_participant_id = ?,
        description = ?, date = ?, split_type = ?, split_shares_json = ?,
        type = ?, to_participant_id = ?, tag = ?,
        line_items_json = ?, image_path = ?, image_paths = ?, updated_at = ?
      WHERE id = ?''',
      [
        title,
        expense.amountCents,
        currencyCode,
        expense.exchangeRate,
        expense.baseAmountCents,
        expense.payerParticipantId,
        expense.description,
        expense.date.toUtc().toIso8601String(),
        expense.splitType.name,
        splitSharesJson,
        expense.transactionType.name,
        expense.toParticipantId,
        expense.tag,
        lineItemsJson,
        imagePath,
        imagePathsJson,
        now,
        expense.id,
      ],
    );
  }

  @override
  Future<void> delete(String id) async {
    if (!_isLocalOnly && _isOnline && _cloud != null) {
      await _cloud.sync.delete('expenses', id);
    } else if (_shouldQueueOffline(
      isLocalOnly: _isLocalOnly,
      isOnline: _isOnline,
    )) {
      await _enqueue(
        _db,
        tableName: 'expenses',
        operation: 'delete',
        rowId: id,
      );
    }
    await _db.execute('DELETE FROM expenses WHERE id = ?', [id]);
  }
}
