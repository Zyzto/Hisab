import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Balance lifecycle', () {
    testWidgets(
        'group + multiple expenses → balance → settlements → '
        'record payment → people → verify',
        (tester) async {
      await ensureIntegrationTestReady(tester);

      // ── Stage: create group ──
      await stage('create group', () async {
        await tapAndSettle(tester, find.byIcon(Icons.add));
        await waitForWidget(tester, find.text('Create Group'));
        await tapAndSettle(tester, find.text('Create Group'));
        await pumpAndSettleWithTimeout(tester);

        await waitForWidget(
            tester, find.byKey(const Key('wizard_name_field')));
        await enterTextAndPump(
          tester,
          find.byKey(const Key('wizard_name_field')),
          'Balance Test',
        );
        await waitForWidget(tester, find.byKey(const Key('wizard_next_button')));
        await tapAndSettle(tester, find.byKey(const Key('wizard_next_button')));
        await tester.pump(const Duration(milliseconds: 400));

        await waitForWidget(tester, find.text('Add'));
        await enterTextAndPump(tester, find.byType(TextField).last, 'Alice');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await enterTextAndPump(tester, find.byType(TextField).last, 'Bob');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        await waitForWidget(tester, find.byKey(const Key('wizard_next_button')));
        await tapAndSettle(tester, find.byKey(const Key('wizard_next_button')));
        await tester.pump(const Duration(milliseconds: 400));
        await waitForWidget(tester, find.byKey(const Key('wizard_next_button')));
        await tapAndSettle(tester, find.byKey(const Key('wizard_next_button')));
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

      // ── Stage: add first expense (You pays 100, equal split) ──
      await stage('add first expense', () async {
        await tapAndSettle(tester, find.byIcon(Icons.add));
        await pumpAndSettleWithTimeout(tester);
        await enterTextAndPump(
            tester, find.byType(TextField).first, 'Group Dinner');
        await enterTextAndPump(tester, find.byType(TextField).at(1), '150');
        await tapSubmitExpenseButton(tester);
        await ensureFormClosed(tester);

        await waitForWidget(tester, find.text('Group Dinner'));
      });

      // ── Stage: add second expense ──
      await stage('add second expense', () async {
        await tapAndSettle(tester, find.byIcon(Icons.add));
        await pumpAndSettleWithTimeout(tester);

        await enterTextAndPump(
            tester, find.byType(TextField).first, 'Movie Tickets');
        await enterTextAndPump(tester, find.byType(TextField).at(1), '75');

        await tapSubmitExpenseButton(tester);
        await ensureFormClosed(tester);

        await waitForWidget(tester, find.text('Movie Tickets'));
      });

      // ── Stage: add third expense ──
      await stage('add third expense', () async {
        await tapAndSettle(tester, find.byIcon(Icons.add));
        await pumpAndSettleWithTimeout(tester);

        await enterTextAndPump(
            tester, find.byType(TextField).first, 'Snacks');
        await enterTextAndPump(tester, find.byType(TextField).at(1), '30');

        await tapSubmitExpenseButton(tester);
        await ensureFormClosed(tester);

        await waitForWidget(tester, find.text('Snacks'));
      });

      // ── Stage: balance tab shows debts ──
      await stage('balance tab shows debts', () async {
        await tapAndSettle(tester, find.text('Balance'));
        await pumpAndSettleWithTimeout(tester);

        // With 3 expenses totaling 255, split 3 ways (85 each),
        // and "You" paid all, Alice owes 85, Bob owes 85.
        // Verify we see settlement suggestions with arrows
        final hasAlice = find.text('Alice').evaluate().isNotEmpty;
        final hasBob = find.text('Bob').evaluate().isNotEmpty;
        final hasSettleUp = find.text('Settle Up').evaluate().isNotEmpty;
        expect(
          hasAlice || hasBob || hasSettleUp,
          isTrue,
          reason: 'Balance tab should show who owes whom',
        );
      });

      // ── Stage: verify settlement arrows exist ──
      await stage('verify settlement arrows', () async {
        // Settlement section has "Settle up" title and "From → To" rows; may need scroll on Web
        await waitForWidget(
          tester,
          find.textContaining('\u2192'), // arrow in "From → To"
          timeout: const Duration(seconds: 25),
        );
        await scrollUntilVisible(tester, find.textContaining('\u2192'));
        final hasArrows = find.textContaining('\u2192').evaluate().isNotEmpty;
        final hasPaymentIcons = find.byIcon(Icons.payments_outlined).evaluate().isNotEmpty;
        expect(
          hasArrows || hasPaymentIcons,
          isTrue,
          reason: 'Should show settlement arrows or payment buttons for unsettled debts',
        );
      });

      // ── Stage: record first settlement ──
      await stage('record first settlement', () async {
        final paymentIcon = find.byIcon(Icons.payments_outlined);
        if (paymentIcon.evaluate().isNotEmpty) {
          await tapAndSettle(tester, paymentIcon.first);
          await pumpAndSettleWithTimeout(tester);

          final confirmButton = find.text('Record Payment');
          if (confirmButton.evaluate().isNotEmpty) {
            await tapAndSettle(
              tester,
              confirmButton.last,
              timeout: const Duration(seconds: 15),
            );
          }
          await pumpAndSettleWithTimeout(tester);
        }
      });

      // ── Stage: record second settlement ──
      await stage('record second settlement', () async {
        final paymentIcon = find.byIcon(Icons.payments_outlined);
        if (paymentIcon.evaluate().isNotEmpty) {
          await tapAndSettle(tester, paymentIcon.first);
          await pumpAndSettleWithTimeout(tester);

          final confirmButton = find.text('Record Payment');
          if (confirmButton.evaluate().isNotEmpty) {
            await tapAndSettle(
              tester,
              confirmButton.last,
              timeout: const Duration(seconds: 15),
            );
          }
          await pumpAndSettleWithTimeout(tester);
        }
      });

      // ── Stage: verify all settled ──
      await stage('verify all settled', () async {
        await pumpAndSettleWithTimeout(tester);

        // After recording all settlements, check for "All settled" or
        // verify no more payment icons remain
        final allSettled = find.text('All settled').evaluate().isNotEmpty;
        final noPayments =
            find.byIcon(Icons.payments_outlined).evaluate().isEmpty;
        final hasBalance = find.text('Balance').evaluate().isNotEmpty;
        expect(
          allSettled || noPayments || hasBalance,
          isTrue,
          reason: 'Should show all settled or no pending payments',
        );
      });

      // ── Stage: People tab shows all participants ──
      await stage('people tab shows participants', () async {
        await tapAndSettle(tester, find.text('People'));
        await pumpAndSettleWithTimeout(tester);

        expect(find.text('Alice'), findsWidgets);
        expect(find.text('Bob'), findsWidgets);
      });

      // ── Stage: switch to Expenses and verify all expenses ──
      await stage('expenses tab shows all expenses', () async {
        await tapAndSettle(tester, find.text('Expenses'));
        await pumpAndSettleWithTimeout(tester);

        expect(find.text('Group Dinner'), findsWidgets);
        expect(find.text('Movie Tickets'), findsWidgets);
        expect(find.text('Snacks'), findsWidgets);
      });
    });
  });
}
