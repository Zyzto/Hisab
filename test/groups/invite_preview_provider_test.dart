import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/groups/providers/invite_preview_provider.dart';

void main() {
  test('falls back to get_invite_by_token when preview group RPC hits missing column', () async {
    final calls = <String>[];
    final container = ProviderContainer(
      overrides: [
        invitePreviewRpcProvider.overrideWithValue((rpcName, params) async {
          calls.add(rpcName);
          if (rpcName == 'get_invite_preview_group') {
            throw Exception(
              'PostgrestException(message: column g.allow_member_settle_for_others does not exist, code: 42703)',
            );
          }
          if (rpcName == 'get_invite_by_token') {
            return [
              {
                'invite_id': 'invite-1',
                'group_id': 'group-1',
                'access_mode': 'readonly_join',
                'group_name': 'Trip',
                'group_currency_code': 'USD',
                'group_created_at': '2026-01-01T00:00:00Z',
                'group_updated_at': '2026-01-01T00:00:00Z',
              },
            ];
          }
          if (rpcName == 'get_invite_preview_participants') {
            return <Map<String, dynamic>>[];
          }
          if (rpcName == 'get_invite_preview_expenses') {
            return <Map<String, dynamic>>[];
          }
          throw UnimplementedError(rpcName);
        }),
      ],
    );
    addTearDown(container.dispose);

    final data = await container.read(invitePreviewDataProvider('t1').future);
    expect(data, isNotNull);
    expect(data!.group.id, 'group-1');
    expect(data.group.allowMemberSettleForOthers, isFalse);
    expect(data.invite.accessMode, InviteAccessMode.readonlyJoin);
    expect(calls, contains('get_invite_preview_group'));
    expect(calls, contains('get_invite_by_token'));
  });

  test('maps participant avatar_id from preview RPC', () async {
    final container = ProviderContainer(
      overrides: [
        invitePreviewRpcProvider.overrideWithValue((rpcName, params) async {
          if (rpcName == 'get_invite_preview_group') {
            return [
              {
                'invite_id': 'invite-1',
                'group_id': 'group-1',
                'invite_access_mode': 'readonly_join',
                'group_name': 'Trip',
                'group_currency_code': 'USD',
                'group_created_at': '2026-01-01T00:00:00Z',
                'group_updated_at': '2026-01-01T00:00:00Z',
              },
            ];
          }
          if (rpcName == 'get_invite_preview_participants') {
            return [
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
            ];
          }
          if (rpcName == 'get_invite_preview_expenses') {
            return <Map<String, dynamic>>[];
          }
          throw UnimplementedError(rpcName);
        }),
      ],
    );
    addTearDown(container.dispose);

    final data = await container.read(invitePreviewDataProvider('t-avatar').future);
    expect(data, isNotNull);
    expect(data!.participants, hasLength(1));
    expect(data.participants.first.avatarId, 'smile');
    expect(data.participants.first.userId, 'u1');
  });

  test('fallback keeps standard invite hidden from preview', () async {
    final container = ProviderContainer(
      overrides: [
        invitePreviewRpcProvider.overrideWithValue((rpcName, params) async {
          if (rpcName == 'get_invite_preview_group') {
            throw Exception(
              'PostgrestException(message: column g.allow_member_settle_for_others does not exist, code: 42703)',
            );
          }
          if (rpcName == 'get_invite_by_token') {
            return [
              {
                'invite_id': 'invite-1',
                'group_id': 'group-1',
                'access_mode': 'standard',
                'group_name': 'Trip',
                'group_currency_code': 'USD',
                'group_created_at': '2026-01-01T00:00:00Z',
                'group_updated_at': '2026-01-01T00:00:00Z',
              },
            ];
          }
          return <Map<String, dynamic>>[];
        }),
      ],
    );
    addTearDown(container.dispose);

    final data = await container.read(invitePreviewDataProvider('t2').future);
    expect(data, isNull);
  });
}
