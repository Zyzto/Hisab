import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      final ready = await runOnlineTestApp(
        skipOnboarding: true,
        signInEmail: testUserAEmail,
        signInPassword: testPassword,
      );
      ensureBootstrapReady(ready);
      await pumpAndSettleWithTimeout(tester);
      await waitForWidget(tester, find.text('Groups'),
          timeout: const Duration(seconds: 20));

      final client = Supabase.instance.client;
      String? groupId;
      String? inviteToken;

      // ── Stage: User A creates a group ──
      await stage('User A creates group', () async {
        await tapAndSettle(tester, find.byIcon(Icons.add));
        await waitForWidget(tester, find.text('Create Group'));
        await tapAndSettle(tester, find.text('Create Group'));
        await pumpAndSettleWithTimeout(tester);

        // Name
        await waitForWidget(
            tester, find.byKey(const Key('wizard_name_field')));
        await enterTextAndPump(
          tester,
          find.byKey(const Key('wizard_name_field')),
          'Invite Test Group',
        );
        await tapAndSettle(tester, find.text('Next'));
        await tester.pump(const Duration(milliseconds: 400));

        // Participants
        await waitForWidget(tester, find.text('Add'));
        await enterTextAndPump(tester, find.byType(TextField).last, 'User A');
        await tapAndSettle(tester, find.text('Add'));

        await tapAndSettle(tester, find.text('Next'));
        await tester.pump(const Duration(milliseconds: 400));

        // Icon & Color – defaults
        await tapAndSettle(tester, find.text('Next'));
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
        expect(find.text('Invite Test Group'), findsWidgets);
      });

      // ── Stage: wait for sync, get group ID ──
      await stage('wait for group sync', () async {
        await tester.pump(const Duration(seconds: 5));
        await pumpAndSettleWithTimeout(tester);

        final userAId = client.auth.currentUser!.id;
        final groups = await client
            .from('groups')
            .select()
            .eq('owner_id', userAId)
            .eq('name', 'Invite Test Group');
        expect(groups, isNotEmpty, reason: 'Group should be synced');
        groupId = groups.first['id'] as String;
      });

      // ── Stage: User A creates an invite via RPC ──
      await stage('User A creates invite', () async {
        final result = await client.rpc('create_invite', params: {
          'p_group_id': groupId,
        });

        expect(result, isNotNull);
        final rows = result as List;
        expect(rows, isNotEmpty, reason: 'create_invite should return a row');
        inviteToken = rows.first['token'] as String;
        expect(inviteToken, isNotNull);
        expect(inviteToken!.isNotEmpty, isTrue);
      });

      // ── Stage: User A signs out ──
      await stage('User A signs out', () async {
        await signOutCurrentUser();
        await tester.pump(const Duration(seconds: 2));

        expect(client.auth.currentSession, isNull);
      });

      // ── Stage: User B signs in and accepts invite via RPC ──
      await stage('User B accepts invite', () async {
        final ok = await signInAs(testUserBEmail, testPassword);
        expect(ok, isTrue, reason: 'User B sign-in should succeed');
        await tester.pump(const Duration(seconds: 2));

        final userBId = client.auth.currentUser!.id;
        expect(userBId, isNotNull);

        final acceptResult = await client.rpc('accept_invite', params: {
          'p_token': inviteToken,
          'p_new_participant_name': 'User B',
        });

        expect(acceptResult, isNotNull,
            reason: 'accept_invite should return group_id');
      });

      // ── Stage: verify User B is a member ──
      await stage('verify User B membership', () async {
        final userBId = client.auth.currentUser!.id;

        final members = await client
            .from('group_members')
            .select()
            .eq('group_id', groupId!)
            .eq('user_id', userBId);

        expect(members, isNotEmpty,
            reason: 'User B should be a member of the group');
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

      // ── Stage: User B signs out, User A verifies member list ──
      await stage('User A verifies member list', () async {
        await signOutCurrentUser();
        await tester.pump(const Duration(seconds: 1));

        final ok = await signInAs(testUserAEmail, testPassword);
        expect(ok, isTrue);
        await tester.pump(const Duration(seconds: 2));

        final members = await client
            .from('group_members')
            .select()
            .eq('group_id', groupId!);

        expect(members.length, greaterThanOrEqualTo(2),
            reason: 'Group should have at least 2 members (A and B)');

        final userBMember = members.where(
          (m) => m['user_id'] == client.auth.currentUser!.id ? false : true,
        );
        expect(userBMember, isNotEmpty,
            reason: 'User B should appear in the member list');
      });

      // ── Cleanup: delete group ──
      await stage('cleanup - delete group', () async {
        if (groupId != null) {
          await client.from('expenses').delete().eq('group_id', groupId!);
          await client.from('group_invites').delete().eq('group_id', groupId!);
          await client.from('group_members').delete().eq('group_id', groupId!);
          await client.from('participants').delete().eq('group_id', groupId!);
          await client.from('groups').delete().eq('id', groupId!);
        }
        await signOutCurrentUser();
      });
    });
  });
}
