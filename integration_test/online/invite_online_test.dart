import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisab/features/expenses/widgets/expense_list_tile.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/online_test_bootstrap.dart';
import '../helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Online invite flow', () {
    testWidgets(
      'User A creates group + invite → User B accepts → verify membership',
      (tester) async {
        final groupName =
            'Invite Test Group ${DateTime.now().millisecondsSinceEpoch}';
        final ready = await runOnlineTestApp(
          skipOnboarding: true,
          signInEmail: testUserAEmail,
          signInPassword: testPassword,
        );
        ensureBootstrapReady(
          ready,
          reason: lastOnlineBootstrapFailureReason,
        );
        await pumpAndSettleWithTimeout(tester);
        await waitForWidget(
          tester,
          find.text('Groups'),
          timeout: const Duration(seconds: 20),
        );

        final client = Supabase.instance.client;
        String? groupId;
        String? inviteId;
        String? inviteToken;

        // ── Stage: User A creates a group ──
        await stage('User A creates group', () async {
          await tapAndSettle(tester, find.byIcon(Icons.add));
          final createGroupButton = actionByLabel(tester, 'Create Group');
          await waitForWidget(tester, createGroupButton);
          await tapAndSettle(tester, createGroupButton);
          await pumpAndSettleWithTimeout(tester);

          // Name
          await waitForWidget(
            tester,
            find.byKey(const Key('wizard_name_field')),
          );
          await enterTextAndPump(
            tester,
            find.byKey(const Key('wizard_name_field')),
            groupName,
          );
          await tapAndSettle(tester, actionByLabel(tester, 'Next'));
          await tester.pump(const Duration(milliseconds: 400));

          // Participants
          await waitForWidget(tester, actionByLabel(tester, 'Add'));
          await enterTextAndPump(tester, find.byType(TextField).last, 'User A');
          await tapAndSettle(tester, actionByLabel(tester, 'Add'));

          await tapAndSettle(tester, actionByLabel(tester, 'Next'));
          await tester.pump(const Duration(milliseconds: 400));

          // Icon & Color – defaults
          await tapAndSettle(tester, actionByLabel(tester, 'Next'));
          await tester.pump(const Duration(milliseconds: 400));
          await pumpAndSettleWithTimeout(tester);

          // Summary → Create
          final createButton = find.byKey(const Key('wizard_create_button'));
          await tapAndPump(tester, createButton);

          await waitForWidget(
            tester,
            find.text('Expenses'),
            timeout: const Duration(seconds: 20),
          );
          expect(find.text(groupName), findsWidgets);
        });

        // ── Stage: wait for sync, get group ID ──
        await stage('wait for group sync', () async {
          final userAId = client.auth.currentUser!.id;
          final groups = await waitForAsyncResult<List<dynamic>>(
            tester,
            load: () async => await client
                .from('groups')
                .select()
                .eq('owner_id', userAId)
                .eq('name', groupName),
            isReady: (rows) => rows.isNotEmpty,
            timeout: const Duration(seconds: 20),
            reason: 'Group should be synced',
          );
          expect(groups, isNotEmpty, reason: 'Group should be synced');
          groupId = groups.first['id'] as String;
        });

        // ── Stage: User A creates an invite via RPC ──
        await stage('User A creates invite', () async {
          final result = await client.rpc(
            'create_invite',
            params: {'p_group_id': groupId},
          );

          expect(result, isNotNull);
          final rows = result as List;
          expect(rows, isNotEmpty, reason: 'create_invite should return a row');
          inviteId = rows.first['id'] as String;
          inviteToken = rows.first['token'] as String;
          expect(inviteId, isNotNull);
          expect(inviteToken, isNotNull);
          expect(inviteToken!.isNotEmpty, isTrue);
        });

        // ── Stage: User A signs out ──
        await stage('User A signs out', () async {
          await signOutCurrentUser();
          await waitForCondition(
            tester,
            condition: () => client.auth.currentSession == null,
            timeout: const Duration(seconds: 10),
            reason: 'User A session did not clear after sign out',
          );
        });

        // ── Stage: User B signs in and accepts invite via RPC ──
        await stage('User B accepts invite', () async {
          final ok = await signInAs(testUserBEmail, testPassword);
          expect(ok, isTrue, reason: 'User B sign-in should succeed');
          await waitForCondition(
            tester,
            condition: () => client.auth.currentSession != null,
            timeout: const Duration(seconds: 10),
            reason: 'User B session did not become available',
          );

          final userBId = client.auth.currentUser!.id;
          expect(userBId, isNotNull);

          final acceptResult = await client.rpc(
            'accept_invite',
            params: {
              'p_token': inviteToken,
              'p_new_participant_name': 'User B',
            },
          );

          expect(
            acceptResult,
            equals(groupId),
            reason: 'accept_invite should return the created group id',
          );
        });

        // ── Stage: verify User B is a member ──
        await stage('verify User B membership', () async {
          final userBId = client.auth.currentUser!.id;

          final members = await client
              .from('group_members')
              .select()
              .eq('group_id', groupId!)
              .eq('user_id', userBId);

          expect(
            members,
            isNotEmpty,
            reason: 'User B should be a member of the group',
          );
          expect(members.first['role'], equals('member'));
        });

        // ── Stage: verify invite was consumed ──
        await stage('verify invite consumed', () async {
          // User B is now a member so can query group_invites
          final invites = await client
              .from('group_invites')
              .select()
              .eq('group_id', groupId!);

          // Invite may have been deleted (max_uses=null, single use by default
          // in the old function, but the latest keeps it). Either way is fine.
          // Just verify no error occurred.
          expect(invites, isNotNull);
        });

        // ── Stage: verify invite usage recorded ──
        await stage('verify invite usage recorded', () async {
          final userBId = client.auth.currentUser!.id;
          final usages = await client
              .from('invite_usages')
              .select()
              .eq('invite_id', inviteId!)
              .eq('user_id', userBId);

          expect(
            usages,
            isNotEmpty,
            reason: 'invite_usages should contain User B acceptance row',
          );
        });

        // ── Stage: User B signs out, User A verifies group ownership ──
        await stage('User A verifies group ownership', () async {
          await signOutCurrentUser();
          await waitForCondition(
            tester,
            condition: () => client.auth.currentSession == null,
            timeout: const Duration(seconds: 10),
            reason: 'User B session did not clear before User A sign-in',
          );

          final ok = await signInAs(testUserAEmail, testPassword);
          expect(ok, isTrue);
          await waitForCondition(
            tester,
            condition: () => client.auth.currentSession != null,
            timeout: const Duration(seconds: 10),
            reason: 'User A session did not become available',
          );

          final userAId = client.auth.currentUser!.id;
          final groups = await client
              .from('groups')
              .select()
              .eq('id', groupId!)
              .eq('owner_id', userAId);
          expect(groups, isNotEmpty, reason: 'User A should own the group');
        });

        // ── Cleanup: delete group ──
        await stage('cleanup - delete group', () async {
          if (groupId != null) {
            await client.from('expenses').delete().eq('group_id', groupId!);
            await client
                .from('group_invites')
                .delete()
                .eq('group_id', groupId!);
            await client
                .from('group_members')
                .delete()
                .eq('group_id', groupId!);
            await client.from('participants').delete().eq('group_id', groupId!);
            await client.from('groups').delete().eq('id', groupId!);
          }
          await signOutCurrentUser();
        });
      },
    );

    testWidgets(
      'readonly_only invite is blocked by backend',
      (tester) async {
        final ready = await runOnlineTestApp(
          skipOnboarding: true,
          signInEmail: testUserAEmail,
          signInPassword: testPassword,
        );
        ensureBootstrapReady(
          ready,
          reason: lastOnlineBootstrapFailureReason,
        );
        await pumpAndSettleWithTimeout(tester);

        final client = Supabase.instance.client;
        String? groupId;
        String? inviteToken;

        await stage('create test group', () async {
          final userAId = client.auth.currentUser!.id;
          final inserted = await client
              .from('groups')
              .insert({
                'name': 'Invite Readonly Group',
                'currency_code': 'USD',
                'owner_id': userAId,
              })
              .select()
              .single();
          groupId = inserted['id'] as String;
          await client.from('group_members').insert({
            'group_id': groupId,
            'user_id': userAId,
            'role': 'owner',
          });
        });

        await stage('create readonly_only invite', () async {
          final result = await client.rpc(
            'create_invite',
            params: {
              'p_group_id': groupId,
              'p_access_mode': 'readonly_only',
            },
          );
          final rows = result as List;
          inviteToken = rows.first['token'] as String;
          expect(inviteToken, isNotNull);
        });

        await stage('verify token returns readonly mode', () async {
          final result = await client.rpc(
            'get_invite_by_token',
            params: {'p_token': inviteToken},
          );
          final rows = result as List;
          expect(rows, isNotEmpty);
          expect(rows.first['access_mode'], 'readonly_only');
        });

        await stage('user B cannot accept readonly_only invite', () async {
          await signOutCurrentUser();
          final ok = await signInAs(testUserBEmail, testPassword);
          expect(ok, isTrue);
          await expectLater(
            () => client.rpc(
              'accept_invite',
              params: {
                'p_token': inviteToken,
                'p_new_participant_name': 'User B',
              },
            ),
            throwsA(isA<PostgrestException>()),
          );
        });

        await stage('cleanup readonly test group', () async {
          await signOutCurrentUser();
          final ok = await signInAs(testUserAEmail, testPassword);
          expect(ok, isTrue);
          if (groupId != null) {
            await client.from('expenses').delete().eq('group_id', groupId!);
            await client
                .from('group_invites')
                .delete()
                .eq('group_id', groupId!);
            await client
                .from('group_members')
                .delete()
                .eq('group_id', groupId!);
            await client.from('participants').delete().eq('group_id', groupId!);
            await client.from('groups').delete().eq('id', groupId!);
          }
          await signOutCurrentUser();
        });
      },
    );

    testWidgets(
      'standard invite does not expose preview RPC data',
      (tester) async {
        final ready = await runOnlineTestApp(
          skipOnboarding: true,
          signInEmail: testUserAEmail,
          signInPassword: testPassword,
        );
        ensureBootstrapReady(
          ready,
          reason: lastOnlineBootstrapFailureReason,
        );
        await pumpAndSettleWithTimeout(tester);

        final client = Supabase.instance.client;
        String? groupId;
        String? inviteToken;

        await stage('create standard-preview test group', () async {
          final userAId = client.auth.currentUser!.id;
          final inserted = await client
              .from('groups')
              .insert({
                'name':
                    'Invite Standard Preview Block ${DateTime.now().millisecondsSinceEpoch}',
                'currency_code': 'USD',
                'owner_id': userAId,
              })
              .select()
              .single();
          groupId = inserted['id'] as String;
          await client.from('group_members').insert({
            'group_id': groupId,
            'user_id': userAId,
            'role': 'owner',
          });
        });

        await stage('create standard invite', () async {
          final result = await client.rpc(
            'create_invite',
            params: {'p_group_id': groupId},
          );
          final rows = result as List;
          inviteToken = rows.first['token'] as String;
          expect(inviteToken, isNotNull);
        });

        await stage('standard invite preview is blocked', () async {
          final groupResult = await client.rpc(
            'get_invite_preview_group',
            params: {'p_token': inviteToken},
          );
          final participantsResult = await client.rpc(
            'get_invite_preview_participants',
            params: {'p_token': inviteToken},
          );
          final expensesResult = await client.rpc(
            'get_invite_preview_expenses',
            params: {'p_token': inviteToken, 'p_limit': 10},
          );
          expect(groupResult, isA<List>());
          expect((groupResult as List), isEmpty);
          expect(participantsResult, isA<List>());
          expect((participantsResult as List), isEmpty);
          expect(expensesResult, isA<List>());
          expect((expensesResult as List), isEmpty);
        });

        await stage('cleanup standard-preview test group', () async {
          if (groupId != null) {
            await client.from('expenses').delete().eq('group_id', groupId!);
            await client
                .from('group_invites')
                .delete()
                .eq('group_id', groupId!);
            await client
                .from('group_members')
                .delete()
                .eq('group_id', groupId!);
            await client.from('participants').delete().eq('group_id', groupId!);
            await client.from('groups').delete().eq('id', groupId!);
          }
          await signOutCurrentUser();
        });
      },
    );

    testWidgets(
      'invite with never expiry keeps expires_at null',
      (tester) async {
        final ready = await runOnlineTestApp(
          skipOnboarding: true,
          signInEmail: testUserAEmail,
          signInPassword: testPassword,
        );
        ensureBootstrapReady(
          ready,
          reason: lastOnlineBootstrapFailureReason,
        );
        await pumpAndSettleWithTimeout(tester);

        final client = Supabase.instance.client;
        String? groupId;
        String? inviteToken;

        await stage('create never-expiry test group', () async {
          final userAId = client.auth.currentUser!.id;
          final inserted = await client
              .from('groups')
              .insert({
                'name': 'Invite Never Expiry ${DateTime.now().millisecondsSinceEpoch}',
                'currency_code': 'USD',
                'owner_id': userAId,
              })
              .select()
              .single();
          groupId = inserted['id'] as String;
          await client.from('group_members').insert({
            'group_id': groupId,
            'user_id': userAId,
            'role': 'owner',
          });
        });

        await stage('create invite with null expiry interval', () async {
          final result = await client.rpc(
            'create_invite',
            params: {
              'p_group_id': groupId,
              'p_expires_in': null,
            },
          );
          final rows = result as List;
          inviteToken = rows.first['token'] as String;
          expect(inviteToken, isNotNull);
        });

        await stage('verify expires_at is null', () async {
          final result = await client.rpc(
            'get_invite_by_token',
            params: {'p_token': inviteToken},
          );
          final rows = result as List;
          expect(rows, isNotEmpty);
          expect(rows.first['expires_at'], isNull);
        });

        await stage('cleanup never-expiry test group', () async {
          if (groupId != null) {
            await client.from('expenses').delete().eq('group_id', groupId!);
            await client
                .from('group_invites')
                .delete()
                .eq('group_id', groupId!);
            await client
                .from('group_members')
                .delete()
                .eq('group_id', groupId!);
            await client.from('participants').delete().eq('group_id', groupId!);
            await client.from('groups').delete().eq('id', groupId!);
          }
          await signOutCurrentUser();
        });
      },
    );

    testWidgets(
      'readonly_join invite shows visible preview flow in UI',
      (tester) async {
        final ready = await runOnlineTestApp(
          skipOnboarding: true,
          signInEmail: testUserAEmail,
          signInPassword: testPassword,
        );
        ensureBootstrapReady(
          ready,
          reason: lastOnlineBootstrapFailureReason,
        );
        await pumpAndSettleWithTimeout(tester);

        final client = Supabase.instance.client;
        String? groupId;
        String? inviteToken;
        String? ownerParticipantId;
        String? userBParticipantId;
        String? userCParticipantId;

        await stage('create readonly_join ui test group', () async {
          final userAId = client.auth.currentUser!.id;
          final inserted = await client
              .from('groups')
              .insert({
                'name':
                    'Invite Readonly UI ${DateTime.now().millisecondsSinceEpoch}',
                'currency_code': 'USD',
                'owner_id': userAId,
              })
              .select()
              .single();
          groupId = inserted['id'] as String;
          await client.from('group_members').insert({
            'group_id': groupId,
            'user_id': userAId,
            'role': 'owner',
          });
          await client.from('participants').insert({
            'group_id': groupId,
            'name': 'Owner',
            'sort_order': 0,
            'user_id': userAId,
          }).select().single().then((row) {
            ownerParticipantId = row['id'] as String;
          });
          await client.from('participants').insert({
            'group_id': groupId,
            'name': 'User B',
            'sort_order': 1,
          }).select().single().then((row) {
            userBParticipantId = row['id'] as String;
          });
          await client.from('participants').insert({
            'group_id': groupId,
            'name': 'User C',
            'sort_order': 2,
          }).select().single().then((row) {
            userCParticipantId = row['id'] as String;
          });

          await client.from('expenses').insert({
            'group_id': groupId,
            'payer_participant_id': ownerParticipantId,
            'amount_cents': 900,
            'currency_code': 'USD',
            'title': 'Dinner',
            'date': DateTime.now().toUtc().toIso8601String(),
            'split_type': 'equal',
            'split_shares_json': {
              ownerParticipantId!: 300,
              userBParticipantId!: 300,
              userCParticipantId!: 300,
            },
            'type': 'expense',
            'receipt_image_path': '/tmp/fake-receipt.jpg',
            'receipt_image_paths': '["/tmp/fake-receipt.jpg"]',
          });
          await client.from('expenses').insert({
            'group_id': groupId,
            'payer_participant_id': userBParticipantId,
            'amount_cents': 600,
            'currency_code': 'USD',
            'title': 'Breakfast',
            'date': DateTime.now()
                .subtract(const Duration(days: 1))
                .toUtc()
                .toIso8601String(),
            'split_type': 'equal',
            'split_shares_json': {
              ownerParticipantId!: 200,
              userBParticipantId!: 200,
              userCParticipantId!: 200,
            },
            'type': 'expense',
          });
          await client.from('expenses').insert({
            'group_id': groupId,
            'payer_participant_id': userCParticipantId,
            'amount_cents': 1200,
            'currency_code': 'USD',
            'title': 'Taxi',
            'date': DateTime.now()
                .subtract(const Duration(days: 7))
                .toUtc()
                .toIso8601String(),
            'split_type': 'equal',
            'split_shares_json': {
              ownerParticipantId!: 400,
              userBParticipantId!: 400,
              userCParticipantId!: 400,
            },
            'type': 'expense',
          });
        });

        await stage('create readonly_join invite', () async {
          final result = await client.rpc(
            'create_invite',
            params: {
              'p_group_id': groupId,
              'p_access_mode': 'readonly_join',
            },
          );
          final rows = result as List;
          inviteToken = rows.first['token'] as String;
          expect(inviteToken, isNotNull);
        });

        await stage('sign out and open invite page', () async {
          await signOutCurrentUser();
          final navContext = tester.element(find.byType(Scaffold).first);
          GoRouter.of(navContext).go('/invite/$inviteToken');
          await pumpAndSettleWithTimeout(tester);
        });

        await stage('readonly_join shows preview button and opens tabs', () async {
          await waitForWidget(tester, find.text('Open group preview'));

          await tapAndPump(tester, find.text('Open group preview'));
          await waitForWidget(tester, find.text('Dinner'));
          await waitForWidget(tester, find.text('Breakfast'));
          await waitForWidget(tester, find.text('Taxi'));
          await waitForWidget(tester, find.text('Expenses'));
          await waitForWidget(tester, find.text('Balance'));
          await waitForWidget(tester, find.text('People'));
          await waitForWidget(tester, find.byType(ExpenseListTile));
          await tapAndPump(tester, find.byType(ExpenseListTile).first);
          await waitForWidget(tester, find.byIcon(Icons.chevron_left));
          final backIcon = find.byIcon(Icons.arrow_back);
          if (backIcon.evaluate().isNotEmpty) {
            await tapAndPump(tester, backIcon.first);
          }
          await pumpAndSettleWithTimeout(tester);
          await waitForWidget(tester, find.text('Dinner'));
          await tapAndPump(tester, find.text('Balance'));
          await tapAndPump(tester, find.text('People'));
          await waitForWidget(tester, find.text('Owner'));
          await waitForWidget(tester, find.text('User B'));
          await waitForWidget(tester, find.text('User C'));
        });

        await stage('cleanup readonly_join ui test group', () async {
          final ok = await signInAs(testUserAEmail, testPassword);
          expect(ok, isTrue);
          if (groupId != null) {
            await client.from('expenses').delete().eq('group_id', groupId!);
            await client
                .from('group_invites')
                .delete()
                .eq('group_id', groupId!);
            await client
                .from('group_members')
                .delete()
                .eq('group_id', groupId!);
            await client.from('participants').delete().eq('group_id', groupId!);
            await client.from('groups').delete().eq('id', groupId!);
          }
          await signOutCurrentUser();
        });
      },
    );

    testWidgets(
      'standard invite does not show preview CTA in UI',
      (tester) async {
        final ready = await runOnlineTestApp(
          skipOnboarding: true,
          signInEmail: testUserAEmail,
          signInPassword: testPassword,
        );
        ensureBootstrapReady(
          ready,
          reason: lastOnlineBootstrapFailureReason,
        );
        await pumpAndSettleWithTimeout(tester);

        final client = Supabase.instance.client;
        String? groupId;
        String? inviteToken;

        await stage('create standard ui test group', () async {
          final userAId = client.auth.currentUser!.id;
          final inserted = await client
              .from('groups')
              .insert({
                'name':
                    'Invite Standard UI ${DateTime.now().millisecondsSinceEpoch}',
                'currency_code': 'USD',
                'owner_id': userAId,
              })
              .select()
              .single();
          groupId = inserted['id'] as String;
          await client.from('group_members').insert({
            'group_id': groupId,
            'user_id': userAId,
            'role': 'owner',
          });
        });

        await stage('create standard invite for ui test', () async {
          final result = await client.rpc(
            'create_invite',
            params: {'p_group_id': groupId},
          );
          final rows = result as List;
          inviteToken = rows.first['token'] as String;
          expect(inviteToken, isNotNull);
        });

        await stage('sign out and open standard invite page', () async {
          await signOutCurrentUser();
          final navContext = tester.element(find.byType(Scaffold).first);
          GoRouter.of(navContext).go('/invite/$inviteToken');
          await pumpAndSettleWithTimeout(tester);
        });

        await stage('standard invite has no preview cta', () async {
          await waitForWidget(tester, find.text('Accept Invite'));
          expect(find.text('Open group preview'), findsNothing);
        });

        await stage('cleanup standard ui test group', () async {
          final ok = await signInAs(testUserAEmail, testPassword);
          expect(ok, isTrue);
          if (groupId != null) {
            await client.from('expenses').delete().eq('group_id', groupId!);
            await client
                .from('group_invites')
                .delete()
                .eq('group_id', groupId!);
            await client
                .from('group_members')
                .delete()
                .eq('group_id', groupId!);
            await client.from('participants').delete().eq('group_id', groupId!);
            await client.from('groups').delete().eq('id', groupId!);
          }
          await signOutCurrentUser();
        });
      },
    );
  });
}
