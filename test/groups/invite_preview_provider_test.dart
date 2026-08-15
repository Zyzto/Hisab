import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/groups/providers/invite_preview_provider.dart';

import '../support/fake_cloud.dart';

void main() {
  test(
    'falls back to getByToken when the group preview hits a missing column',
    () async {
      final invites = FakeCloudInvites(
        onPreviewGroup: (_) async => throw Exception(
          'column g.allow_member_settle_for_others does not exist, code: 42703',
        ),
        onGetByToken: (_) async => {
          'invite_id': 'invite-1',
          'group_id': 'group-1',
          'access_mode': 'readonly_join',
          'group_name': 'Trip',
          'group_currency_code': 'USD',
          'group_created_at': '2026-01-01T00:00:00Z',
          'group_updated_at': '2026-01-01T00:00:00Z',
        },
      );
      final container = ProviderContainer(
        overrides: [invitePreviewSourceProvider.overrideWithValue(invites)],
      );
      addTearDown(container.dispose);

      final data = await container.read(invitePreviewDataProvider('t1').future);
      expect(data, isNotNull);
      expect(data!.group.id, 'group-1');
      expect(data.group.allowMemberSettleForOthers, isFalse);
      expect(data.invite.accessMode, InviteAccessMode.readonlyJoin);
      expect(invites.calls, contains('previewGroup'));
      expect(invites.calls, contains('getByToken'));
    },
  );

  test('maps participant avatar_id from the preview', () async {
    final invites = FakeCloudInvites(
      onPreviewGroup: (_) async => {
        'invite_id': 'invite-1',
        'group_id': 'group-1',
        'invite_access_mode': 'readonly_join',
        'group_name': 'Trip',
        'group_currency_code': 'USD',
        'group_created_at': '2026-01-01T00:00:00Z',
        'group_updated_at': '2026-01-01T00:00:00Z',
      },
      onPreviewParticipants: (_) async => [
        {
          'id': 'p1',
          'group_id': 'group-1',
          'name': 'Alice',
          'sort_order': 0,
          'user_id': 'u1',
          'avatar_id': 'smile',
          'left_at': null,
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
          'member_role': 'owner',
        },
      ],
    );
    final container = ProviderContainer(
      overrides: [invitePreviewSourceProvider.overrideWithValue(invites)],
    );
    addTearDown(container.dispose);

    final data = await container.read(
      invitePreviewDataProvider('t-avatar').future,
    );
    expect(data, isNotNull);
    expect(data!.participants, hasLength(1));
    expect(data.participants.first.avatarId, 'smile');
    expect(data.participants.first.userId, 'u1');
  });

  test('fallback keeps a standard invite hidden from preview', () async {
    final invites = FakeCloudInvites(
      onPreviewGroup: (_) async => throw Exception(
        'column g.allow_member_settle_for_others does not exist, code: 42703',
      ),
      onGetByToken: (_) async => {
        'invite_id': 'invite-1',
        'group_id': 'group-1',
        'access_mode': 'standard',
        'group_name': 'Trip',
        'group_currency_code': 'USD',
        'group_created_at': '2026-01-01T00:00:00Z',
        'group_updated_at': '2026-01-01T00:00:00Z',
      },
    );
    final container = ProviderContainer(
      overrides: [invitePreviewSourceProvider.overrideWithValue(invites)],
    );
    addTearDown(container.dispose);

    final data = await container.read(invitePreviewDataProvider('t2').future);
    expect(data, isNull);
  });

  test('offline build has no preview source and yields no data', () async {
    final container = ProviderContainer(
      overrides: [invitePreviewSourceProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(invitePreviewDataProvider('t3').future),
      isNull,
    );
  });
}
