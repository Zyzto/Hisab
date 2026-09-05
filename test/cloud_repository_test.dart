import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:powersync/powersync.dart';

import 'package:hisab/core/database/powersync_schema.dart' as ps;
import 'package:hisab/core/repository/powersync_repository.dart';
import 'package:hisab/domain/settlement_method.dart';

import 'support/fake_cloud.dart';

/// Covers the seam between the repositories and the backend contract: what the
/// app pushes, and that a local-only build pushes nothing at all.

bool _powerSyncAvailable = false;

void main() {
  PowerSyncDatabase? db;
  late String dbPath;

  setUpAll(() async {
    try {
      final p = path.join(
        Directory.systemTemp.path,
        'hisab_cloud_repo_probe.db',
      );
      final probe = PowerSyncDatabase(schema: ps.schema, path: p);
      await probe.initialize();
      await probe.close();
      File(p).deleteSync();
      _powerSyncAvailable = true;
    } catch (_) {
      _powerSyncAvailable = false;
    }
    if (!_powerSyncAvailable) return;
    dbPath = path.join(
      Directory.systemTemp.path,
      'hisab_cloud_repo_test_${DateTime.now().millisecondsSinceEpoch}.db',
    );
    db = PowerSyncDatabase(schema: ps.schema, path: dbPath);
    await db!.initialize();
  });

  tearDownAll(() async {
    if (db != null) {
      await db!.close();
      try {
        File(dbPath).deleteSync();
      } catch (_) {}
      db = null;
    }
  });

  group('PowerSyncGroupRepository against the backend contract', () {
    test('local-only create never touches the backend', () async {
      if (!_powerSyncAvailable || db == null) return;
      final sync = FakeCloudSync();
      final repo = PowerSyncGroupRepository(
        db!,
        cloud: FakeCloudBackend(sync: sync),
        isOnline: false,
        isLocalOnly: true,
      );

      final id = await repo.create('Local Group', 'USD');

      expect(id, isNotEmpty);
      expect((await repo.getById(id))?.name, 'Local Group');
      expect(sync.upserts, isEmpty);
    });

    test('offline build with no backend still creates locally', () async {
      if (!_powerSyncAvailable || db == null) return;
      final repo = PowerSyncGroupRepository(
        db!,
        cloud: null,
        isOnline: false,
        isLocalOnly: true,
      );

      final id = await repo.create('Stub Group', 'USD');

      expect((await repo.getById(id))?.name, 'Stub Group');
    });

    test('online create upserts the group row', () async {
      if (!_powerSyncAvailable || db == null) return;
      final sync = FakeCloudSync();
      final repo = PowerSyncGroupRepository(
        db!,
        cloud: FakeCloudBackend(sync: sync),
        isOnline: true,
        isLocalOnly: false,
      );

      final id = await repo.create('Online Group', 'EUR');

      final groupUpserts = sync.upserts.where((u) => u.table == 'groups');
      expect(groupUpserts, hasLength(1));
      expect(groupUpserts.single.data['id'], id);
      expect(groupUpserts.single.data['name'], 'Online Group');
      expect(groupUpserts.single.data['currency_code'], 'EUR');
    });

    test(
      'online treasurer create links treasurer after participants exist',
      () async {
        if (!_powerSyncAvailable || db == null) return;
        final sync = FakeCloudSync();
        final repo = PowerSyncGroupRepository(
          db!,
          cloud: FakeCloudBackend(sync: sync),
          isOnline: true,
          isLocalOnly: false,
        );

        final id = await repo.create(
          'Treasurer Group',
          'USD',
          initialParticipants: const ['Alice', 'Bob'],
          settlementMethod: SettlementMethod.treasurer,
          treasurerInitialParticipantName: 'Bob',
        );

        final group = sync.upserts.singleWhere((u) => u.table == 'groups');
        expect(group.data, isNot(contains('treasurer_participant_id')));

        final bob = sync.upserts.singleWhere(
          (u) => u.table == 'participants' && u.data['name'] == 'Bob',
        );
        final treasurerLink = sync.updates.singleWhere(
          (u) => u.table == 'groups' && u.id == id,
        );
        expect(treasurerLink.data['treasurer_participant_id'], bob.data['id']);
      },
    );
  });
}
