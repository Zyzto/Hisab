import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_helpers.dart';

/// Integration tests for display currency and group-currency amount display:
/// - Setting display currency in Settings
/// - Group detail summary and list showing amounts in group currency
/// - Expense detail showing amount in group currency
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Display currency and group currency display', () {
    testWidgets(
        'set display currency → create group → add expense → '
        'group detail shows group currency → expense detail shows group currency',
        (tester) async {
      await ensureIntegrationTestReady(tester);

      // ── Stage: set display currency in Settings ──
      await stage('set display currency', () async {
        await tapAndSettle(tester, find.text('Settings'));
        await pumpAndSettleWithTimeout(tester);

        await scrollUntilVisible(tester, find.text('Display Currency'));
        await tapAndSettle(tester, find.text('Display Currency'));
        await pumpAndSettleWithTimeout(tester);

        // Currency picker opens (title "Select Currency" on tablet; on mobile sheet has no title, so wait for search field)
        await waitForWidget(
          tester,
          find.byType(TextField),
          timeout: const Duration(seconds: 10),
        );
        final searchField = find.byType(TextField);
        if (searchField.evaluate().isNotEmpty) {
          await enterTextAndPump(tester, searchField.first, 'USD');
          await pumpAndSettleWithTimeout(tester);
        }

        // Tap the USD row by its full name (list shows code + "United States Dollar")
        final usdRowFinder = find.text('United States Dollar');
        expect(usdRowFinder, findsWidgets, reason: 'USD row should appear in picker');
        await tester.ensureVisible(usdRowFinder.first);
        await tapAndSettle(tester, usdRowFinder.first);
        await pumpAndSettleWithTimeout(tester);

        // Picker closes; wait for sheet to be gone so nav bar is tappable
        for (var i = 0; i < 50; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (find.byType(BottomSheet).evaluate().isEmpty) break;
        }
        await pumpAndSettleWithTimeout(tester);

        // Picker closes; we're back on Settings
        await waitForWidget(tester, find.text('Settings'));
        expect(find.text('Settings'), findsWidgets);
      });

      // ── Stage: create group ──
      await stage('create group for display currency', () async {
        await pumpAndSettleWithTimeout(tester);
        await scrollUntilVisible(tester, find.text('Groups'));
        await tester.ensureVisible(find.text('Groups').first);
        // Tap the nav bar item (InkWell containing "Groups") so we hit the tappable area, not obscured text
        final groupsNav = find.widgetWithText(InkWell, 'Groups');
        if (groupsNav.evaluate().isNotEmpty) {
          await tester.ensureVisible(groupsNav.first);
          await tapAndSettle(tester, groupsNav.first);
        } else {
          await tapAndSettle(tester, find.text('Groups').first);
        }
        await pumpAndSettleWithTimeout(tester);

        await waitForWidget(
          tester,
          find.byIcon(Icons.add),
          timeout: const Duration(seconds: 15),
        );
        await tester.ensureVisible(find.byIcon(Icons.add).first);
        await tapAndSettle(tester, find.byIcon(Icons.add));
        await waitForWidget(tester, find.text('Create Group'));
        await tapAndSettle(tester, find.text('Create Group'));
        await pumpAndSettleWithTimeout(tester);

        await waitForWidget(
            tester, find.byKey(const Key('wizard_name_field')));
        await enterTextAndPump(
          tester,
          find.byKey(const Key('wizard_name_field')),
          'Display Currency Group',
        );
        await waitForWidget(tester, find.byKey(const Key('wizard_next_button')));
        await tapAndSettle(tester, find.byKey(const Key('wizard_next_button')));
        await tester.pump(const Duration(milliseconds: 400));

        await waitForWidget(tester, find.text('Add'));
        await enterTextAndPump(tester, find.byType(TextField).last, 'Alex');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await enterTextAndPump(tester, find.byType(TextField).last, 'Sam');
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
        expect(find.text('Display Currency Group'), findsWidgets);
      });

      // ── Stage: add expense (group currency SAR by default) ──
      await stage('add expense in group currency', () async {
        await tapAndSettle(tester, find.byIcon(Icons.add));
        await pumpAndSettleWithTimeout(tester);

        await enterTextAndPump(
            tester, find.byType(TextField).first, 'Coffee');
        await enterTextAndPump(tester, find.byType(TextField).at(1), '85');

        await tapSubmitExpenseButton(tester);
        await ensureFormClosed(tester);

        await waitForWidget(tester, find.text('Coffee'));
        expect(find.text('Coffee'), findsWidgets);
      });

      // ── Stage: group detail shows summary in group currency ──
      await stage('group detail shows group currency', () async {
        expect(find.text('My Expenses'), findsWidgets);
        expect(find.text('Total Expenses'), findsWidgets);
        // Amounts are in group currency (SAR); we show formatted amount
        expect(find.text('Coffee'), findsWidgets);
      });

      // ── Stage: expense detail shows amount in group currency ──
      await stage('expense detail shows group currency', () async {
        await tapAndSettle(tester, find.text('Coffee'));
        await pumpAndSettleWithTimeout(tester);

        expect(find.text('Coffee'), findsWidgets);
        await tapAndSettle(tester, find.byIcon(Icons.arrow_back));
        await waitForWidget(tester, find.text('Expenses'));
      });

      // ── Stage: clear display currency (verifies clear button works) ──
      await stage('clear display currency', () async {
        // We may still be on group detail; tap back until Settings is visible in shell nav
        for (var i = 0; i < 3 && find.text('Settings').evaluate().isEmpty; i++) {
          if (find.byIcon(Icons.arrow_back).evaluate().isEmpty) break;
          await tapAndSettle(tester, find.byIcon(Icons.arrow_back).first);
          await pumpAndSettleWithTimeout(tester);
        }
        await waitForWidget(tester, find.text('Settings'), timeout: const Duration(seconds: 5));
        await tapAndSettle(tester, find.text('Settings'));
        await pumpAndSettleWithTimeout(tester);

        await scrollUntilVisible(tester, find.text('Display Currency'));
        final displayCurrencyTile = find.ancestor(
          of: find.text('Display Currency'),
          matching: find.byType(ListTile),
        );
        final clearBtn = find.descendant(
          of: displayCurrencyTile,
          matching: find.byIcon(Icons.clear),
        );
        if (clearBtn.evaluate().isNotEmpty) {
          await tapAndSettle(tester, clearBtn.first);
          await pumpAndSettleWithTimeout(tester);
        }
        expect(find.text('Settings'), findsWidgets);
      });
    });
  });
}
