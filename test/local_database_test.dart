import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:powersync/powersync.dart';

import 'package:hisab/core/database/powersync_schema.dart' as ps;
import 'package:hisab/core/repository/powersync_repository.dart';
import 'package:hisab/domain/domain.dart';

/// Set to false when the native PowerSync library is unavailable.
bool powerSyncAvailable = false;

void main() {
  PowerSyncDatabase? db;
  late String dbPath;

  setUpAll(() async {
    try {
      dbPath = path.join(
        Directory.systemTemp.path,
        'hisab_test_init_${DateTime.now().millisecondsSinceEpoch}.db',
      );
      final testDb = PowerSyncDatabase(schema: ps.schema, path: dbPath);
      await testDb.initialize();
      await testDb.close();
      File(dbPath).deleteSync();
      powerSyncAvailable = true;
    } catch (_) {
      powerSyncAvailable = false;
    }
  });

  setUp(() async {
    db = null;
    if (!powerSyncAvailable) return;
    dbPath = path.join(
      Directory.systemTemp.path,
      'hisab_test_${DateTime.now().millisecondsSinceEpoch}.db',
    );
    db = PowerSyncDatabase(schema: ps.schema, path: dbPath);
    await db!.initialize();
  });

  tearDown(() async {
    final current = db;
    if (current != null) {
      await current.close();
      final file = File(dbPath);
      if (await file.exists()) await file.delete();
      db = null;
    }
  });

  PowerSyncGroupRepository groups() => PowerSyncGroupRepository(db!);
  PowerSyncParticipantRepository participants() =>
      PowerSyncParticipantRepository(db!);
  PowerSyncExpenseRepository expenses() => PowerSyncExpenseRepository(db!);

  group('local database repositories', () {
    test('create a group with participants and read it back', () async {
      if (!powerSyncAvailable) return;

      final groupId = await groups().create(
        'Test Group',
        'USD',
        initialParticipants: const ['Alice', 'Bob'],
      );
      final group = await groups().getById(groupId);
      final people = await participants().getByGroupId(groupId);

      expect(group?.name, 'Test Group');
      expect(group?.currencyCode, 'USD');
      expect(
        people.map((person) => person.name),
        containsAll(['Alice', 'Bob']),
      );
    });

    test('updates and deletes local groups', () async {
      if (!powerSyncAvailable) return;

      final groupId = await groups().create('Original', 'EUR');
      final group = await groups().getById(groupId);
      await groups().update(
        group!.copyWith(name: 'Updated', currencyCode: 'GBP'),
      );

      expect((await groups().getById(groupId))?.name, 'Updated');
      await groups().delete(groupId);
      expect(await groups().getById(groupId), isNull);
    });

    test('creates, updates, and deletes participants', () async {
      if (!powerSyncAvailable) return;

      final groupId = await groups().create('People', 'USD');
      final participantId = await participants().create(groupId, 'Alice', 1);
      final participant = await participants().getById(participantId);

      await participants().update(
        participant!.copyWith(name: 'Alicia', order: 2),
      );
      expect((await participants().getById(participantId))?.name, 'Alicia');
      await participants().delete(participantId);
      expect(await participants().getById(participantId), isNull);
    });

    test('creates and reads a local expense', () async {
      if (!powerSyncAvailable) return;

      final groupId = await groups().create('Expenses', 'USD');
      final participantId = await participants().create(groupId, 'Payer', 0);
      final now = DateTime.now();
      final expenseId = await expenses().create(
        Expense(
          id: '',
          groupId: groupId,
          payerParticipantId: participantId,
          amountCents: 1000,
          currencyCode: 'USD',
          title: 'Lunch',
          date: now,
          splitType: SplitType.equal,
          splitShares: const {},
          createdAt: now,
          updatedAt: now,
        ),
      );

      final expense = await expenses().getById(expenseId);
      expect(expense?.title, 'Lunch');
      expect(expense?.amountCents, 1000);
    });

    test('reopens without dropping legacy tables or rows', () async {
      if (!powerSyncAvailable) return;

      await db!.execute(
        '''
        INSERT INTO group_invites
          (id, group_id, token, created_at, is_active)
        VALUES (?, ?, ?, ?, ?)
        ''',
        ['legacy-invite', 'legacy-group', 'legacy-token', '2026-01-01', 1],
      );
      await db!.execute(
        '''
        INSERT INTO pending_writes
          (id, table_name, operation, row_id, data_json, created_at, silent)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          'legacy-write',
          'groups',
          'insert',
          'legacy-group',
          '{"id":"legacy-group"}',
          '2026-01-01',
          0,
        ],
      );

      await db!.close();
      db = PowerSyncDatabase(schema: ps.schema, path: dbPath);
      await db!.initialize();

      final invite = await db!.get(
        'SELECT token FROM group_invites WHERE id = ?',
        ['legacy-invite'],
      );
      final pendingWrite = await db!.get(
        'SELECT data_json FROM pending_writes WHERE id = ?',
        ['legacy-write'],
      );
      expect(invite['token'], 'legacy-token');
      expect(pendingWrite['data_json'], '{"id":"legacy-group"}');
    });
  });
}
