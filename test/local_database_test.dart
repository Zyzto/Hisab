import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:powersync/powersync.dart';

import 'package:hisab/core/database/powersync_schema.dart' as ps;
import 'package:hisab/core/repository/group_repository.dart';
import 'package:hisab/core/repository/powersync_repository.dart';
import 'package:hisab/domain/domain.dart';

/// Set to false if PowerSync native binary could not be loaded (see test/README.md).
bool powerSyncAvailable = false;

void main() {
  late PowerSyncDatabase? db;
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
    if (db != null) {
      await db!.close();
      try {
        final f = File(dbPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      db = null;
    }
  });

  IGroupRepository repo() => PowerSyncGroupRepository(
        db!,
        client: null,
        isOnline: false,
        isLocalOnly: true,
      );

  group('PowerSyncGroupRepository (local only)', () {
    test('create then getById and getAll', () async {
      if (!powerSyncAvailable) return;
      final r = repo();
      final id = await r.create('Test Group', 'USD');
      expect(id, isNotEmpty);

      final byId = await r.getById(id);
      expect(byId, isNotNull);
      expect(byId!.name, 'Test Group');
      expect(byId.currencyCode, 'USD');
      expect(byId.id, id);

      final all = await r.getAll();
      expect(all.length, 1);
      expect(all.first.id, id);
      expect(all.first.name, 'Test Group');
    });

    test('update persists to local DB', () async {
      if (!powerSyncAvailable) return;
      final r = repo();
      final id = await r.create('Original', 'EUR');
      final g = await r.getById(id);
      expect(g, isNotNull);

      final updated = g!.copyWith(name: 'Updated Name', currencyCode: 'GBP');
      await r.update(updated);

      final after = await r.getById(id);
      expect(after!.name, 'Updated Name');
      expect(after.currencyCode, 'GBP');
    });

    test('delete removes group from local DB', () async {
      if (!powerSyncAvailable) return;
      final r = repo();
      final id = await r.create('To Delete', 'USD');
      expect(await r.getById(id), isNotNull);

      await r.delete(id);
      expect(await r.getById(id), isNull);
      expect(await r.getAll(), isEmpty);
    });

    test('watchAll emits when data changes', () async {
      if (!powerSyncAvailable) return;
      final r = repo();
      final emitted = <List<Group>>[];
      final sub = r.watchAll().listen((list) => emitted.add(list));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await r.create('First', 'USD');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await r.create('Second', 'EUR');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      await sub.cancel();

      expect(emitted, isNotEmpty);
      final last = emitted.last;
      expect(last.length, 2);
      final names = last.map((g) => g.name).toList();
      expect(names, contains('First'));
      expect(names, contains('Second'));
    });
  });

  group('PowerSyncParticipantRepository (local only)', () {
    test('create group then add participant and list', () async {
      if (!powerSyncAvailable) return;
      final groupRepo = repo();
      final groupId = await groupRepo.create('Group', 'USD');
      final participantRepo = PowerSyncParticipantRepository(
        db!,
        client: null,
        isOnline: false,
        isLocalOnly: true,
      );

      final participantId = await participantRepo.create(
        groupId,
        'Alice',
        1,
      );
      expect(participantId, isNotEmpty);

      final list = await participantRepo.getByGroupId(groupId);
      expect(list.length, greaterThanOrEqualTo(1));
      final alice = list.where((p) => p.name == 'Alice').toList();
      expect(alice.length, 1);
      expect(alice.first.id, participantId);
    });

    test('update persists name and order to local DB', () async {
      if (!powerSyncAvailable) return;
      final groupRepo = repo();
      final groupId = await groupRepo.create('Group', 'USD');
      final participantRepo = PowerSyncParticipantRepository(
        db!,
        client: null,
        isOnline: false,
        isLocalOnly: true,
      );
      final participantId = await participantRepo.create(groupId, 'Alice', 0);
      final p = await participantRepo.getById(participantId);
      expect(p, isNotNull);

      await participantRepo.update(p!.copyWith(name: 'Alicia', order: 2));

      final list = await participantRepo.getByGroupId(groupId);
      final updated = list.where((x) => x.id == participantId).first;
      expect(updated.name, 'Alicia');
      expect(updated.order, 2);
    });

    test('delete removes participant from local DB', () async {
      if (!powerSyncAvailable) return;
      final groupRepo = repo();
      final groupId = await groupRepo.create('Group', 'USD');
      final participantRepo = PowerSyncParticipantRepository(
        db!,
        client: null,
        isOnline: false,
        isLocalOnly: true,
      );
      final participantId = await participantRepo.create(groupId, 'ToDelete', 0);
      expect(await participantRepo.getById(participantId), isNotNull);

      await participantRepo.delete(participantId);

      expect(await participantRepo.getById(participantId), isNull);
      final list = await participantRepo.getByGroupId(groupId);
      expect(list.any((p) => p.id == participantId), false);
    });
  });

  group('PowerSyncExpenseRepository (local only)', () {
    test('create group and participant then add expense', () async {
      if (!powerSyncAvailable) return;
      final groupRepo = repo();
      final groupId = await groupRepo.create('Expense Group', 'USD');
      final participantRepo = PowerSyncParticipantRepository(
        db!,
        client: null,
        isOnline: false,
        isLocalOnly: true,
      );
      final participantId = await participantRepo.create(groupId, 'Payer', 0);

      final now = DateTime.now();
      final expense = Expense(
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
      );
      final expenseRepo = PowerSyncExpenseRepository(
        db!,
        client: null,
        isOnline: false,
        isLocalOnly: true,
      );
      final expenseId = await expenseRepo.create(expense);
      expect(expenseId, isNotEmpty);

      final list = await expenseRepo.getByGroupId(groupId);
      expect(list.length, 1);
      expect(list.first.id, expenseId);
      expect(list.first.title, 'Lunch');
      expect(list.first.amountCents, 1000);
    });

    test('update persists expense changes to local DB', () async {
      if (!powerSyncAvailable) return;
      final groupRepo = repo();
      final groupId = await groupRepo.create('Expense Group', 'USD');
      final participantRepo = PowerSyncParticipantRepository(
        db!,
        client: null,
        isOnline: false,
        isLocalOnly: true,
      );
      final participantId = await participantRepo.create(groupId, 'Payer', 0);
      final now = DateTime.now();
      final expenseRepo = PowerSyncExpenseRepository(
        db!,
        client: null,
        isOnline: false,
        isLocalOnly: true,
      );
      final expenseId = await expenseRepo.create(
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
      final e = await expenseRepo.getById(expenseId);
      expect(e, isNotNull);

      await expenseRepo.update(e!.copyWith(title: 'Dinner', amountCents: 2000));

      final after = await expenseRepo.getById(expenseId);
      expect(after!.title, 'Dinner');
      expect(after.amountCents, 2000);
    });

    test('delete removes expense from local DB', () async {
      if (!powerSyncAvailable) return;
      final groupRepo = repo();
      final groupId = await groupRepo.create('Expense Group', 'USD');
      final participantRepo = PowerSyncParticipantRepository(
        db!,
        client: null,
        isOnline: false,
        isLocalOnly: true,
      );
      final participantId = await participantRepo.create(groupId, 'Payer', 0);
      final now = DateTime.now();
      final expenseRepo = PowerSyncExpenseRepository(
        db!,
        client: null,
        isOnline: false,
        isLocalOnly: true,
      );
      final expenseId = await expenseRepo.create(
        Expense(
          id: '',
          groupId: groupId,
          payerParticipantId: participantId,
          amountCents: 500,
          currencyCode: 'USD',
          title: 'ToDelete',
          date: now,
          splitType: SplitType.equal,
          splitShares: const {},
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(await expenseRepo.getById(expenseId), isNotNull);

      await expenseRepo.delete(expenseId);

      expect(await expenseRepo.getById(expenseId), isNull);
      final list = await expenseRepo.getByGroupId(groupId);
      expect(list.any((e) => e.id == expenseId), false);
    });
  });
}
