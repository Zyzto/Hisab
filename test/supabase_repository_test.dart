import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:powersync/powersync.dart';
import 'package:supabase/supabase.dart';

import 'package:hisab/core/database/powersync_schema.dart' as ps;
import 'package:hisab/core/repository/powersync_repository.dart';
import 'package:hisab/domain/domain.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

/// Supabase repository tests use a fake client that captures table calls
/// instead of mocking the full Postgrest builder chain.
/// For full integration tests against a real Supabase project, run manually
/// with dart-define SUPABASE_URL and SUPABASE_ANON_KEY.

bool _powerSyncAvailable = false;

void main() {
  PowerSyncDatabase? db;
  late String dbPath;

  setUpAll(() async {
    try {
      final p = path.join(Directory.systemTemp.path, 'hisab_supabase_repo_probe.db');
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
      'hisab_supabase_repo_test_${DateTime.now().millisecondsSinceEpoch}.db',
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

  group('PowerSyncGroupRepository with Supabase client', () {
    test('local-only create does not call Supabase', () async {
      if (!_powerSyncAvailable || db == null) return;
      final repo = PowerSyncGroupRepository(
        db!,
        client: null,
        isOnline: false,
        isLocalOnly: true,
      );
      final id = await repo.create('Local Group', 'USD');
      expect(id, isNotEmpty);
      final g = await repo.getById(id);
      expect(g?.name, 'Local Group');
    });

    test('online create calls Supabase insert for groups', () async {
      if (!_powerSyncAvailable || db == null) return;
      final mockClient = MockSupabaseClient();
      final mockBuilder = MockSupabaseQueryBuilder();
      when(() => mockClient.from(any())).thenReturn(mockBuilder);
      when(() => mockBuilder.insert(any())).thenThrow(Exception('supabase_insert_called'));

      final repo = PowerSyncGroupRepository(
        db!,
        client: mockClient,
        isOnline: true,
        isLocalOnly: false,
      );

      expect(
        () => repo.create('Online Group', 'EUR'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('supabase_insert_called'),
        )),
      );
      verify(() => mockClient.from('groups')).called(1);
      verify(() => mockBuilder.insert(any())).called(1);
    });
  });
}
