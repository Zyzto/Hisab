import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:powersync/powersync.dart';

import 'package:hisab/core/database/powersync_schema.dart' as ps;
import 'package:hisab/core/repository/powersync_repository.dart';
import 'package:hisab/domain/domain.dart';

import '../../support/fake_cloud.dart';

void main() {
  bool powerSyncAvailable = false;
  PowerSyncDatabase? db;
  late String dbPath;
  late FakeCloudInvites invites;
  late FakeCloudBackend cloud;

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
    invites = FakeCloudInvites();
    cloud = FakeCloudBackend(invites: invites);
  });

  group('PowerSyncGroupInviteRepository', () {
    test('getByToken throws UnsupportedError in an offline build', () async {
      if (!powerSyncAvailable || db == null) return;
      final repo = PowerSyncGroupInviteRepository(db!, cloud: null);
      expect(() => repo.getByToken('abc'), throwsA(isA<UnsupportedError>()));
    });

    test('getByToken returns null for an unknown token', () async {
      if (!powerSyncAvailable || db == null) return;
      final repo = PowerSyncGroupInviteRepository(
        db!,
        cloud: FakeCloudBackend(
          invites: FakeCloudInvites(onGetByToken: (_) async => null),
        ),
      );

      expect(await repo.getByToken('abc'), isNull);
    });

    test('createInvite forwards the invite settings unchanged', () async {
      if (!powerSyncAvailable || db == null) return;
      invites.createResult = const {'id': 'invite-id', 'token': 'invite-token'};
      final repo = PowerSyncGroupInviteRepository(db!, cloud: cloud);

      final result = await repo.createInvite(
        'group-1',
        role: null,
        label: 'Family',
        maxUses: 5,
        expiresIn: const Duration(hours: 1),
      );

      expect(result.id, 'invite-id');
      expect(result.token, 'invite-token');
      expect(invites.createCalls, hasLength(1));
      final call = invites.createCalls.single;
      expect(call.groupId, 'group-1');
      expect(call.role, 'member');
      expect(call.label, 'Family');
      expect(call.maxUses, 5);
      expect(call.expiresIn, const Duration(hours: 1));
      expect(call.accessMode, 'standard');
    });

    test('createInvite passes a null duration for a never-expiring invite', () async {
      if (!powerSyncAvailable || db == null) return;
      invites.createResult = const {
        'id': 'invite-id-2',
        'token': 'invite-token-2',
      };
      final repo = PowerSyncGroupInviteRepository(db!, cloud: cloud);

      await repo.createInvite('group-2', expiresIn: null);

      final call = invites.createCalls.single;
      expect(call.groupId, 'group-2');
      expect(call.expiresIn, isNull);
      expect(call.accessMode, 'standard');
    });

    test('getByToken maps access_mode and group timestamps', () async {
      if (!powerSyncAvailable || db == null) return;
      final repo = PowerSyncGroupInviteRepository(
        db!,
        cloud: FakeCloudBackend(
          invites: FakeCloudInvites(
            onGetByToken: (_) async => {
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
          ),
        ),
      );

      final result = await repo.getByToken('tok-1');
      expect(result, isNotNull);
      expect(result!.invite.accessMode, InviteAccessMode.readonlyOnly);
      expect(result.group.name, 'Test Group');
      expect(
        result.group.updatedAt.toUtc(),
        DateTime.parse('2026-01-02T00:00:00Z'),
      );
    });

    test('getByToken defaults a missing access_mode to standard', () async {
      if (!powerSyncAvailable || db == null) return;
      final repo = PowerSyncGroupInviteRepository(
        db!,
        cloud: FakeCloudBackend(
          invites: FakeCloudInvites(
            onGetByToken: (_) async => {
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
          ),
        ),
      );

      final result = await repo.getByToken('tok-2');
      expect(result, isNotNull);
      expect(result!.invite.accessMode, InviteAccessMode.standard);
    });

    test('accept forwards the token and returns the group id', () async {
      if (!powerSyncAvailable || db == null) return;
      invites.acceptResult = 'group-xyz';
      final repo = PowerSyncGroupInviteRepository(db!, cloud: cloud);

      final result = await repo.accept('tok-123', newParticipantName: 'User B');

      expect(result, 'group-xyz');
      final call = invites.acceptCalls.single;
      expect(call.token, 'tok-123');
      expect(call.participantId, isNull);
      expect(call.newParticipantName, 'User B');
    });

    test('accept forwards an optional participantId for a claim', () async {
      if (!powerSyncAvailable || db == null) return;
      invites.acceptResult = 'group-claim';
      final repo = PowerSyncGroupInviteRepository(db!, cloud: cloud);

      final result = await repo.accept(
        'tok-claim',
        newParticipantName: 'Alice',
        participantId: 'participant-1',
      );

      expect(result, 'group-claim');
      final call = invites.acceptCalls.single;
      expect(call.token, 'tok-claim');
      expect(call.participantId, 'participant-1');
      expect(call.newParticipantName, 'Alice');
    });
  });
}
