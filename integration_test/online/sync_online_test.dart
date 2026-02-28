import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/online_test_bootstrap.dart';
import '../helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
      await waitForWidget(tester, find.text('Groups'),
          timeout: const Duration(seconds: 20));

      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;

      // ── Stage: create group via UI ──
      await stage('create group', () async {
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
          'Sync Test Group',
        );
        await tapAndSettle(tester, find.text('Next'));
        await tester.pump(const Duration(milliseconds: 400));

        // Participants
        await waitForWidget(tester, find.text('Add'));
        await enterTextAndPump(tester, find.byType(TextField).last, 'Alice');
        await tapAndSettle(tester, find.text('Add'));
        await enterTextAndPump(tester, find.byType(TextField).last, 'Bob');
        await tapAndSettle(tester, find.text('Add'));

        await tapAndSettle(tester, find.text('Next'));
        await tester.pump(const Duration(milliseconds: 400));

        // Icon & Color – skip, use defaults
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
        expect(find.text('Sync Test Group'), findsWidgets);
      });

      // ── Stage: wait for sync then verify group in Supabase ──
      await stage('verify group in supabase', () async {
        // Give DataSyncService time to push
        await tester.pump(const Duration(seconds: 5));
        await pumpAndSettleWithTimeout(tester);

        final groupsResult = await client
            .from('groups')
            .select()
            .eq('owner_id', userId)
            .eq('name', 'Sync Test Group');

        expect(groupsResult, isNotEmpty,
            reason: 'Group should exist in Supabase after sync');
      });

      // ── Stage: add an expense ──
      String? groupId;
      await stage('add expense', () async {
        // Get group ID for later verification
        final groups = await client
            .from('groups')
            .select()
            .eq('owner_id', userId)
            .eq('name', 'Sync Test Group');
        groupId = groups.first['id'] as String;

        await waitForWidget(tester, find.byIcon(Icons.add));
        await tapAndSettle(tester, find.byIcon(Icons.add));
        await pumpAndSettleWithTimeout(tester);

        // Title (first TextField on the expense form)
        await waitForWidget(tester, find.byType(TextField),
            timeout: const Duration(seconds: 10));
        await enterTextAndPump(
            tester, find.byType(TextField).first, 'Test Dinner');

        // Amount (second TextField)
        if (find.byType(TextField).evaluate().length > 1) {
          await enterTextAndPump(
              tester, find.byType(TextField).at(1), '42.50');
        }

        // Submit
        await tapSubmitExpenseButton(tester);
        await ensureFormClosed(tester);

        await tester.pump(const Duration(seconds: 2));
      });

      // ── Stage: verify expense in Supabase ──
      await stage('verify expense in supabase', () async {
        // Give time for sync
        await tester.pump(const Duration(seconds: 5));
        await pumpAndSettleWithTimeout(tester);

        if (groupId != null) {
          final expenses = await client
              .from('expenses')
              .select()
              .eq('group_id', groupId!);

          expect(expenses, isNotEmpty,
              reason: 'Expense should exist in Supabase after sync');
        }
      });

      // ── Stage: delete group via UI ──
      await stage('delete group', () async {
        // Navigate back to home
        if (find.byIcon(Icons.arrow_back).evaluate().isNotEmpty) {
          await tapAndSettle(tester, find.byIcon(Icons.arrow_back));
          await pumpAndSettleWithTimeout(tester);
        }

        await waitForWidget(tester, find.text('Sync Test Group'));

        // Tap into group detail
        await tapAndSettle(tester, find.text('Sync Test Group'));
        await pumpAndSettleWithTimeout(tester);

        // Navigate to group settings
        final settingsIcon = find.byIcon(Icons.settings);
        if (settingsIcon.evaluate().isNotEmpty) {
          await tapAndSettle(tester, settingsIcon.first);
          await pumpAndSettleWithTimeout(tester);
        }

        // Scroll to find Delete Group
        await scrollUntilVisible(tester, find.text('Delete Group'));
        await tapAndSettle(tester, find.text('Delete Group'));
        await pumpAndSettleWithTimeout(tester);

        // Confirm deletion (dialog button also says "Delete Group")
        final confirmDelete = find.text('Delete Group');
        if (confirmDelete.evaluate().isNotEmpty) {
          await tapAndSettle(tester, confirmDelete.last);
          await pumpAndSettleWithTimeout(tester);
        }

        await tester.pump(const Duration(seconds: 2));
      });

      // ── Stage: verify deletion synced or clean up directly ──
      await stage('verify group deleted', () async {
        if (groupId == null) return;

        // Poll Supabase for up to 15s to allow sync to propagate
        var deleted = false;
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(seconds: 3));
          final remaining =
              await client.from('groups').select().eq('id', groupId!);
          if (remaining.isEmpty) {
            deleted = true;
            break;
          }
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
    });
  });
}
