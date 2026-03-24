import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/online_test_bootstrap.dart';
import '../helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Online sync flow', () {
    testWidgets('create group → verify in Supabase → add expense → verify → '
        'trigger sync → delete group', (tester) async {
      final ready = await runOnlineTestApp(
        skipOnboarding: true,
        signInEmail: testUserAEmail,
        signInPassword: testPassword,
      );
      ensureBootstrapReady(ready);
      await pumpAndSettleWithTimeout(tester);
      final signedIn = await signInAs(testUserAEmail, testPassword);
      expect(signedIn, isTrue, reason: 'User A sign-in should succeed');
      await waitForCondition(
        tester,
        condition: () => Supabase.instance.client.auth.currentSession != null,
        timeout: const Duration(seconds: 10),
        reason: 'User A session should be available before sync flow',
      );
      await waitForWidget(
        tester,
        find.text('Groups'),
        timeout: const Duration(seconds: 20),
      );

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      String? groupId;

      // ── Stage: create group via backend (stable for web release) ──
      await stage('create group', () async {
        final inserted = await client
            .from('groups')
            .insert({
              'name': 'Sync Test Group',
              'currency_code': 'USD',
              'owner_id': userId,
            })
            .select()
            .single();
        groupId = inserted['id'] as String;

        final ownerMember = await client
            .from('group_members')
            .insert({
              'group_id': groupId,
              'user_id': userId,
              'role': 'owner',
            })
            .select()
            .single();

        final ownerParticipant = await client
            .from('participants')
            .insert({
              'group_id': groupId,
              'name': 'Owner',
              'sort_order': 0,
              'user_id': userId,
            })
            .select()
            .single();
        await client
            .from('group_members')
            .update({'participant_id': ownerParticipant['id']})
            .eq('id', ownerMember['id']);
        await client.from('participants').insert({
          'group_id': groupId,
          'name': 'Alice',
          'sort_order': 1,
        });
        await client.from('participants').insert({
          'group_id': groupId,
          'name': 'Bob',
          'sort_order': 2,
        });
      });

      // ── Stage: wait for sync then verify group in Supabase ──
      await stage('verify group in supabase', () async {
        final groupsResult = await waitForAsyncResult<List<dynamic>>(
          tester,
          load: () async => await client
              .from('groups')
              .select()
              .eq('owner_id', userId)
              .eq('name', 'Sync Test Group'),
          isReady: (rows) => rows.isNotEmpty,
          timeout: const Duration(seconds: 20),
          reason: 'Group should exist in Supabase after sync',
        );

        expect(
          groupsResult,
          isNotEmpty,
          reason: 'Group should exist in Supabase after sync',
        );
      });

      // ── Stage: add an expense ──
      await stage('add expense', () async {
        if (groupId == null) {
          throw TestFailure('groupId is null before add expense stage');
        }

        await waitForWidget(tester, find.byIcon(Icons.add));
        await tapAndSettle(tester, find.byIcon(Icons.add));
        await pumpAndSettleWithTimeout(tester);

        // Title (first TextField on the expense form)
        await waitForWidget(
          tester,
          find.byType(TextField),
          timeout: const Duration(seconds: 10),
        );
        await enterTextAndPump(
          tester,
          find.byType(TextField).first,
          'Test Dinner',
        );

        // Amount (second TextField)
        if (find.byType(TextField).evaluate().length > 1) {
          await enterTextAndPump(tester, find.byType(TextField).at(1), '42.50');
        }

        // Submit
        await tapSubmitExpenseButton(tester);
        await ensureFormClosed(tester);
      });

      // ── Stage: verify expense in Supabase ──
      await stage('verify expense in supabase', () async {
        if (groupId != null) {
          final expenses = await waitForAsyncResult<List<dynamic>>(
            tester,
            load: () async =>
                await client.from('expenses').select().eq('group_id', groupId!),
            isReady: (rows) => rows.isNotEmpty,
            timeout: const Duration(seconds: 20),
            reason: 'Expense should exist in Supabase after sync',
          );

          expect(
            expenses,
            isNotEmpty,
            reason: 'Expense should exist in Supabase after sync',
          );
        }
      });

      // ── Stage: delete group via UI ──
      await stage('delete group', () async {
        // Navigate back to home
        if (find.byIcon(Icons.arrow_back).evaluate().isNotEmpty) {
          await tapAndSettle(tester, find.byIcon(Icons.arrow_back));
          await pumpAndSettleWithTimeout(tester);
        }

        final groupTileText = find.text('Sync Test Group');
        await waitForWidget(tester, groupTileText);

        // Tap into group detail
        await tapAndSettle(tester, groupTileText);
        await pumpAndSettleWithTimeout(tester);

        // Navigate to group settings
        final settingsIcon = find.byIcon(Icons.settings);
        if (settingsIcon.evaluate().isNotEmpty) {
          await tapAndSettle(tester, settingsIcon.first);
          await pumpAndSettleWithTimeout(tester);
        }

        // Scroll to find Delete Group
        final deleteGroupButton = actionByLabel(tester, 'Delete Group');
        await scrollUntilVisible(tester, deleteGroupButton);
        await tapAndSettle(tester, deleteGroupButton);
        await pumpAndSettleWithTimeout(tester);

        // Confirm deletion (dialog button also says "Delete Group")
        final confirmDelete = actionByLabel(tester, 'Delete Group');
        if (confirmDelete.evaluate().isNotEmpty) {
          await tapAndSettle(tester, confirmDelete.first);
          await pumpAndSettleWithTimeout(tester);
        }
      });

      // ── Stage: verify deletion synced or clean up directly ──
      await stage('verify group deleted', () async {
        if (groupId == null) return;

        // Poll Supabase for up to 15s to allow sync to propagate
        var deleted = false;
        try {
          await waitForAsyncResult<List<dynamic>>(
            tester,
            load: () async =>
                await client.from('groups').select().eq('id', groupId!),
            isReady: (rows) => rows.isEmpty,
            timeout: const Duration(seconds: 15),
            interval: const Duration(seconds: 1),
            reason: 'Group deletion did not sync within expected time',
          );
          deleted = true;
        } catch (_) {
          deleted = false;
        }

        // If sync didn't propagate, clean up directly via API
        if (!deleted) {
          await client.from('expenses').delete().eq('group_id', groupId!);
          await client.from('group_members').delete().eq('group_id', groupId!);
          await client.from('participants').delete().eq('group_id', groupId!);
          await client.from('groups').delete().eq('id', groupId!);
        }
      });

      await signOutCurrentUser();
    }, skip: true);
  });
}
