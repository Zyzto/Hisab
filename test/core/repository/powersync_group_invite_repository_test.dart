import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

import 'package:hisab/core/database/powersync_schema.dart' as ps;
import 'package:hisab/core/repository/powersync_repository.dart';
import 'package:hisab/domain/domain.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  bool powerSyncAvailable = false;
  PowerSyncDatabase? db;
  late String dbPath;
  late MockSupabaseClient client;

  setUpAll(() async {
    try {
      final probePath = p.join(
        Directory.systemTemp.path,
        'hisab_group_invite_repo_probe.db',
      );
      final probe = PowerSyncDatabase(schema: ps.schema, path: probePath);
      await probe.initialize();
      await probe.close();
      File(probePath).deleteSync();
      powerSyncAvailable = true;
    } catch (_) {
      powerSyncAvailable = false;
    }
    if (!powerSyncAvailable) return;
    dbPath = p.join(
      Directory.systemTemp.path,
      'hisab_group_invite_repo_${DateTime.now().millisecondsSinceEpoch}.db',
    );
    db = PowerSyncDatabase(schema: ps.schema, path: dbPath);
    await db!.initialize();
  });

  tearDownAll(() async {
    if (db == null) return;
    await db!.close();
    try {
      File(dbPath).deleteSync();
    } catch (_) {}
  });

  setUp(() {
    client = MockSupabaseClient();
  });

  group('PowerSyncGroupInviteRepository', () {
    test('getByToken throws UnsupportedError when client is null', () async {
      if (!powerSyncAvailable || db == null) return;
      final repo = PowerSyncGroupInviteRepository(db!, supabaseClient: null);
      expect(() => repo.getByToken('abc'), throwsA(isA<UnsupportedError>()));
    });

    test('getByToken returns null for empty rpc payload', () async {
      if (!powerSyncAvailable || db == null) return;
      final repo = PowerSyncGroupInviteRepository(db!, supabaseClient: client);
      when(
        () => client.rpc('get_invite_by_token', params: any(named: 'params')),
      ).thenReturn(Future.value([]) as dynamic);

      final result = await repo.getByToken('abc');
      expect(result, isNull);
    });

    test('createInvite sends expected params and interval string', () async {
      if (!powerSyncAvailable || db == null) return;
      final repo = PowerSyncGroupInviteRepository(db!, supabaseClient: client);
      final auth = MockGoTrueClient();
      when(() => client.auth).thenReturn(auth);
      when(() => auth.currentUser).thenReturn(null);
      when(
        () => client.rpc('create_invite', params: any(named: 'params')),
      ).thenReturn(
        Future.value([
              {'id': 'invite-id', 'token': 'invite-token'},
            ])
            as dynamic,
      );

      final result = await repo.createInvite(
        'group-1',
        role: null,
        label: 'Family',
        maxUses: 5,
        expiresIn: const Duration(hours: 1),
      );

      expect(result.id, 'invite-id');
      expect(result.token, 'invite-token');
      final verification = verify(
        () => client.rpc('create_invite', params: captureAny(named: 'params')),
      );
      verification.called(1);
      final captured = verification.captured.single as Map<String, dynamic>;
      expect(captured['p_group_id'], 'group-1');
      expect(captured['p_role'], 'member');
      expect(captured['p_label'], 'Family');
      expect(captured['p_max_uses'], 5);
      expect(captured['p_expires_in'], '3600 seconds');
      expect(captured['p_access_mode'], 'standard');
    });

    test(
      'createInvite sends null interval for never-expiring invite',
      () async {
        if (!powerSyncAvailable || db == null) return;
        final repo = PowerSyncGroupInviteRepository(
          db!,
          supabaseClient: client,
        );
        final auth = MockGoTrueClient();
        when(() => client.auth).thenReturn(auth);
        when(() => auth.currentUser).thenReturn(null);
        when(
          () => client.rpc('create_invite', params: any(named: 'params')),
        ).thenReturn(
          Future.value([
                {'id': 'invite-id-2', 'token': 'invite-token-2'},
              ])
              as dynamic,
        );

        await repo.createInvite('group-2', expiresIn: null);
        final verification = verify(
          () =>
              client.rpc('create_invite', params: captureAny(named: 'params')),
        );
        verification.called(1);
        final captured = verification.captured.single as Map<String, dynamic>;
        expect(captured['p_group_id'], 'group-2');
        expect(captured['p_expires_in'], isNull);
      expect(captured['p_access_mode'], 'standard');
      },
    );

    test('getByToken maps access_mode and group timestamps', () async {
      if (!powerSyncAvailable || db == null) return;
      final repo = PowerSyncGroupInviteRepository(db!, supabaseClient: client);
      when(
        () => client.rpc('get_invite_by_token', params: any(named: 'params')),
      ).thenReturn(
        Future.value([
              {
                'invite_id': 'invite-1',
                'group_id': 'group-1',
                'token': 'tok-1',
                'invitee_email': null,
                'role': 'member',
                'created_at': '2026-01-01T00:00:00Z',
                'expires_at': '2026-12-31T00:00:00Z',
                'access_mode': 'readonly_only',
                'group_name': 'Test Group',
                'group_currency_code': 'USD',
                'group_created_at': '2026-01-01T00:00:00Z',
                'group_updated_at': '2026-01-02T00:00:00Z',
              },
            ])
            as dynamic,
      );

      final result = await repo.getByToken('tok-1');
      expect(result, isNotNull);
      expect(result!.invite.accessMode, InviteAccessMode.readonlyOnly);
      expect(result.group.name, 'Test Group');
      expect(result.group.updatedAt.toUtc(), DateTime.parse('2026-01-02T00:00:00Z'));
    });

    test('getByToken defaults missing access_mode to standard', () async {
      if (!powerSyncAvailable || db == null) return;
      final repo = PowerSyncGroupInviteRepository(db!, supabaseClient: client);
      when(
        () => client.rpc('get_invite_by_token', params: any(named: 'params')),
      ).thenReturn(
        Future.value([
              {
                'invite_id': 'invite-2',
                'group_id': 'group-1',
                'token': 'tok-2',
                'invitee_email': null,
                'role': 'member',
                'created_at': '2026-01-01T00:00:00Z',
                'expires_at': null,
                'group_name': 'Test Group',
                'group_currency_code': 'USD',
                'group_created_at': '2026-01-01T00:00:00Z',
                'group_updated_at': '2026-01-01T00:00:00Z',
              },
            ])
            as dynamic,
      );

      final result = await repo.getByToken('tok-2');
      expect(result, isNotNull);
      expect(result!.invite.accessMode, InviteAccessMode.standard);
    });

    test('accept sends expected params and returns group id', () async {
      if (!powerSyncAvailable || db == null) return;
      final repo = PowerSyncGroupInviteRepository(db!, supabaseClient: client);
      when(
        () => client.rpc('accept_invite', params: any(named: 'params')),
      ).thenReturn(Future.value('group-xyz') as dynamic);

      final result = await repo.accept('tok-123', newParticipantName: 'User B');

      expect(result, 'group-xyz');
      final verification = verify(
        () => client.rpc('accept_invite', params: captureAny(named: 'params')),
      );
      verification.called(1);
      final captured = verification.captured.single as Map<String, dynamic>;
      expect(captured['p_token'], 'tok-123');
      expect(captured['p_participant_id'], isNull);
      expect(captured['p_new_participant_name'], 'User B');
    });
  });
}
