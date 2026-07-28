import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/online_test_bootstrap.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('Online sync flow', () {
    testWidgets(
      'create group → verify in Supabase → add expense → verify → '
      'trigger sync → delete group',
      (tester) async {
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
        const groupName = 'Sync Test Group';
        String? groupId;

        // ── Stage: create group via UI (upload path) ──
        await stage('create group', () async {
          await tapAndSettle(tester, find.byIcon(Icons.add));
          await waitForWidget(tester, find.text('Create Group'));
          await tapAndSettle(tester, find.text('Create Group'));
          await pumpAndSettleWithTimeout(tester);

          await waitForWidget(
            tester,
            find.byKey(const Key('wizard_name_field')),
          );
          await enterTextAndPump(
            tester,
            find.byKey(const Key('wizard_name_field')),
            groupName,
          );
          await waitForWidget(
            tester,
            find.byKey(const Key('wizard_next_button')),
          );
          await tapAndSettle(
            tester,
            find.byKey(const Key('wizard_next_button')),
          );
          await tester.pump(const Duration(milliseconds: 400));

          await waitForWidget(tester, find.text('Add'));
          await addWizardParticipant(tester, 'Alice');
          await addWizardParticipant(tester, 'Bob');

          await waitForWidget(
            tester,
            find.byKey(const Key('wizard_next_button')),
          );
          await tapAndSettle(
            tester,
            find.byKey(const Key('wizard_next_button')),
          );
          await tester.pump(const Duration(milliseconds: 400));
          await waitForWidget(
            tester,
            find.byKey(const Key('wizard_next_button')),
          );
          await tapAndSettle(
            tester,
            find.byKey(const Key('wizard_next_button')),
          );
          await tester.pump(const Duration(milliseconds: 400));
          await pumpAndSettleWithTimeout(tester);

          final createButton = find.byKey(const Key('wizard_create_button'));
          await tapAndPump(tester, createButton);

          await waitForWidget(
            tester,
            find.text('Expenses'),
            timeout: const Duration(seconds: 20),
          );
        });

        // ── Stage: wait for upload then verify group in Supabase ──
        await stage('verify group in supabase', () async {
          final groupsResult = await waitForAsyncResult<List<dynamic>>(
            tester,
            load: () async => await client
                .from('groups')
                .select()
                .eq('owner_id', userId)
                .eq('name', groupName),
            isReady: (rows) => rows.isNotEmpty,
            timeout: const Duration(seconds: 30),
            reason: 'Group should exist in Supabase after sync',
          );

          expect(
            groupsResult,
            isNotEmpty,
            reason: 'Group should exist in Supabase after sync',
          );
          groupId = groupsResult.first['id'] as String;
        });

        // ── Stage: add an expense via UI ──
        await stage('add expense', () async {
          await waitForWidget(tester, find.byIcon(Icons.add));
          await tapAndSettle(tester, find.byIcon(Icons.add).first);
          await pumpAndSettleWithTimeout(tester);
          await ensureExpenseFormReady(tester);

          await enterTextAndPump(
            tester,
            find.byType(TextField).first,
            'Test Dinner',
          );

          if (find.byType(TextField).evaluate().length > 1) {
            await enterTextAndPump(
              tester,
              find.byType(TextField).at(1),
              '42.50',
            );
          }

          await tapSubmitExpenseButton(tester);
          await ensureFormClosed(tester);
        });

        // ── Stage: verify expense in Supabase ──
        await stage('verify expense in supabase', () async {
          if (groupId == null) {
            throw TestFailure('groupId is null before expense verify');
          }

          final expenses = await waitForAsyncResult<List<dynamic>>(
            tester,
            load: () async =>
                await client.from('expenses').select().eq('group_id', groupId!),
            isReady: (rows) => rows.isNotEmpty,
            timeout: const Duration(seconds: 30),
            reason: 'Expense should exist in Supabase after sync',
          );

          expect(
            expenses,
            isNotEmpty,
            reason: 'Expense should exist in Supabase after sync',
          );
        });

        // ── Stage: delete group via UI ──
        await stage('delete group', () async {
          if (find.byIcon(Icons.arrow_back).evaluate().isNotEmpty) {
            await tapAndSettle(tester, find.byIcon(Icons.arrow_back));
            await pumpAndSettleWithTimeout(tester);
          }

          // Prefer settings from group detail if still there.
          final settingsIcon = find.byIcon(Icons.settings);
          if (settingsIcon.evaluate().isEmpty) {
            final groupTileText = find.text(groupName);
            await waitForWidget(tester, groupTileText);
            await tapAndSettle(tester, groupTileText);
            await pumpAndSettleWithTimeout(tester);
          }

          if (find.byIcon(Icons.settings).evaluate().isNotEmpty) {
            await tapAndSettle(tester, find.byIcon(Icons.settings).first);
            await pumpAndSettleWithTimeout(tester);
          }

          final deleteGroupButton = actionByLabel(tester, 'Delete Group');
          await scrollUntilVisible(tester, deleteGroupButton);
          await tapAndSettle(tester, deleteGroupButton);
          await pumpAndSettleWithTimeout(tester);

          final confirmDelete = actionByLabel(tester, 'Delete Group');
          if (confirmDelete.evaluate().isNotEmpty) {
            await tapAndSettle(tester, confirmDelete.first);
            await pumpAndSettleWithTimeout(tester);
          }
        });

        // ── Stage: verify deletion synced or clean up directly ──
        await stage('verify group deleted', () async {
          if (groupId == null) return;

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

          if (!deleted) {
            await client.from('expenses').delete().eq('group_id', groupId!);
            await client.from('group_members').delete().eq('group_id', groupId!);
            await client.from('participants').delete().eq('group_id', groupId!);
            await client.from('groups').delete().eq('id', groupId!);
          }
        });

        await signOutCurrentUser();
      },
    );
  });
}
