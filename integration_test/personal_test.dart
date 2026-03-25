import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  group('Personal lifecycle', () {
    testWidgets('create → verify UI → expense → income → settings → delete', (
      tester,
    ) async {
      await ensureIntegrationTestReady(tester);

      // ── Stage: create personal budget ──
      await stage('create personal budget', () async {
        await tapAndSettle(tester, find.byIcon(Icons.add));
        await waitForWidget(tester, find.text('Create Personal'));
        await tapAndSettle(tester, find.text('Create Personal'));
        await pumpAndSettleWithTimeout(tester);

        await waitForWidget(tester, find.byKey(const Key('wizard_name_field')));
        await enterTextAndPump(
          tester,
          find.byKey(const Key('wizard_name_field')),
          'My Budget',
        );
        // Optional budget (integer): enter 500
        await enterTextAndPump(
          tester,
          find.byKey(const Key('wizard_budget_field')),
          '500',
        );

        // Step 1 → Step 2 (icon/color for personal)
        await tapAndSettle(tester, find.text('Next'));
        await tester.pump(const Duration(milliseconds: 400));

        // Step 2 → Step 3 (summary)
        await tapAndSettle(tester, find.text('Next'));
        await tester.pump(const Duration(milliseconds: 400));
        await pumpAndSettleWithTimeout(tester);

        final createButton = find.byKey(const Key('wizard_create_button'));
        await tapAndPump(tester, createButton);

        await waitForWidget(
          tester,
          find.text('Add Expense'),
          timeout: const Duration(seconds: 20),
        );
      });

      // ── Stage: verify simplified UI ──
      await stage('verify simplified UI', () async {
        expect(find.text('My Budget'), findsWidgets);
        expect(find.text('Balance'), findsNothing);
        expect(find.text('People'), findsNothing);
        // Budget set on create (500) is displayed in the header; wait for expenses
        // to load (_PersonalBudgetHeader shows loading until expensesByGroupProvider emits)
        await waitForWidget(
          tester,
          find.byKey(const Key('personal_budget_amount')),
          timeout: const Duration(seconds: 15),
        );
        expect(find.byKey(const Key('personal_budget_amount')), findsOneWidget);
      });

      // ── Stage: add expense ──
      await stage('add expense', () async {
        await tapAndSettle(tester, find.byIcon(Icons.add).first);
        await pumpAndSettleWithTimeout(tester);
        await ensureExpenseFormReady(tester);

        await enterTextAndPump(tester, find.byType(TextField).first, 'Coffee');
        await enterTextAndPump(tester, find.byType(TextField).at(1), '5.50');
        await tapSubmitExpenseButton(tester);
        await ensureFormClosed(tester);

        await waitForWidget(tester, find.text('Coffee'));
        expect(find.text('Coffee'), findsWidgets);
      });

      // ── Stage: add personal income ──
      await stage('add personal income', () async {
        await tapAndSettle(tester, find.byIcon(Icons.add).first);
        await pumpAndSettleWithTimeout(tester);
        await ensureExpenseFormReady(tester);

        final incomeTab = find.text('Income');
        if (incomeTab.evaluate().isNotEmpty) {
          await tester.ensureVisible(incomeTab);
          await tapAndSettle(tester, incomeTab);
        }

        await enterTextAndPump(tester, find.byType(TextField).first, 'Salary');
        await enterTextAndPump(tester, find.byType(TextField).at(1), '3000');

        await tapSubmitExpenseButton(tester);
        await ensureFormClosed(tester);

        await waitForWidget(tester, find.text('Salary'));
        expect(find.text('Salary'), findsWidgets);
      });

      // ── Stage: open personal settings ──
      await stage('open personal settings', () async {
        await tapAndSettle(tester, find.byIcon(Icons.settings).last);
        await pumpAndSettleWithTimeout(tester);
        // Personal list settings page uses the group settings page,
        // which shows the list name in the profile header.
        expect(find.text('My Budget'), findsWidgets);
      });

      // ── Stage: delete personal budget ──
      await stage('delete personal budget', () async {
        await scrollUntilVisible(tester, find.text('Delete List'));
        await tapAndSettle(tester, find.text('Delete List'));

        // Timed confirm dialog with 10-second countdown
        await tester.pump(const Duration(seconds: 11));
        await pumpAndSettleWithTimeout(tester);

        final confirmDelete = find.text('Delete List');
        if (confirmDelete.evaluate().isNotEmpty) {
          await tapAndSettle(tester, confirmDelete.last);
        }

        await waitForWidget(tester, find.byIcon(Icons.add));
      });
    });
  });
}
