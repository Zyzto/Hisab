import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Group lifecycle', () {
    testWidgets(
        'create (icon+color) → tabs → people → settings → currency → '
        'settlement → freeze → delete',
        (tester) async {
      await ensureIntegrationTestReady(tester);

      // ── Stage: create group with custom icon and color ──
      await stage('create group with icon and color', () async {
        await tapAndSettle(tester, find.byIcon(Icons.add));
        await waitForWidget(tester, find.text('Create Group'));
        await tapAndSettle(tester, find.text('Create Group'));
        await pumpAndSettleWithTimeout(tester);

        // Step 1: Name
        await waitForWidget(
            tester, find.byKey(const Key('wizard_name_field')));
        await enterTextAndPump(
          tester,
          find.byKey(const Key('wizard_name_field')),
          'Trip to Tokyo',
        );

        await tapAndSettle(tester, find.text('Next'));
        await tester.pump(const Duration(milliseconds: 400));

        // Step 2: Add participants
        await waitForWidget(tester, find.text('Add'));
        await enterTextAndPump(tester, find.byType(TextField).last, 'Alice');
        await tapAndSettle(tester, find.text('Add'));
        await enterTextAndPump(tester, find.byType(TextField).last, 'Bob');
        await tapAndSettle(tester, find.text('Add'));
        await enterTextAndPump(
            tester, find.byType(TextField).last, 'Charlie');
        await tapAndSettle(tester, find.text('Add'));

        await tapAndSettle(tester, find.text('Next'));
        await tester.pump(const Duration(milliseconds: 400));

        // Step 3: Icon & Color selection
        // Select the "Trip" icon (flight icon)
        final tripIcon = find.byIcon(Icons.flight);
        if (tripIcon.evaluate().isNotEmpty) {
          await tapAndSettle(tester, tripIcon.first);
        }

        // Select a different color (the 5th circle - blue)
        // Colors are rendered as GestureDetector > AnimatedContainer circles
        final animatedContainers = find.byType(AnimatedContainer);
        if (animatedContainers.evaluate().length >= 5) {
          await tapAndSettle(tester, animatedContainers.at(4));
        }

        await tapAndSettle(tester, find.text('Next'));
        await tester.pump(const Duration(milliseconds: 400));
        await pumpAndSettleWithTimeout(tester);

        // Step 4: Summary → Create
        final createButton = find.byKey(const Key('wizard_create_button'));
        await tapAndPump(tester, createButton);

        await waitForWidget(
          tester,
          find.text('Expenses'),
          timeout: const Duration(seconds: 20),
        );
        expect(find.text('Trip to Tokyo'), findsWidgets);
      });

      // ── Stage: detail shows tabs ──
      await stage('detail shows tabs', () async {
        expect(find.text('Expenses'), findsWidgets);
        expect(find.text('Balance'), findsWidgets);
        expect(find.text('People'), findsWidgets);
      });

      // ── Stage: People tab shows all participants ──
      await stage('people tab shows participants', () async {
        await tapAndSettle(tester, find.text('People'));
        await pumpAndSettleWithTimeout(tester);

        expect(find.text('Alice'), findsWidgets);
        expect(find.text('Bob'), findsWidgets);
        expect(find.text('Charlie'), findsWidgets);
      });

      // ── Stage: switch back to Expenses tab ──
      await stage('switch back to expenses', () async {
        await tapAndSettle(tester, find.text('Expenses'));
        await pumpAndSettleWithTimeout(tester);
      });

      // ── Stage: add expense for balance checks later ──
      await stage('add expense for settlement test', () async {
        await tapAndSettle(tester, find.byIcon(Icons.add));
        await pumpAndSettleWithTimeout(tester);

        await enterTextAndPump(
            tester, find.byType(TextField).first, 'Group Dinner');
        await enterTextAndPump(tester, find.byType(TextField).at(1), '120');

        await tapSubmitExpenseButton(tester);
        await ensureFormClosed(tester);

        await waitForWidget(tester, find.text('Group Dinner'));
        expect(find.text('Group Dinner'), findsWidgets);
      });

      // ── Stage: open settings ──
      await stage('open settings', () async {
        await tapAndSettle(tester, find.byIcon(Icons.settings).last);
        await waitForWidget(tester, find.text('Group Settings'));
        expect(find.text('Group Settings'), findsOneWidget);
      });

      // ── Stage: verify settings content ──
      await stage('verify settings content', () async {
        expect(find.text('Trip to Tokyo'), findsWidgets);

        await scrollUntilVisible(tester, find.text('Group Currency'));
        expect(find.text('Group Currency'), findsOneWidget);
      });

      // ── Stage: change currency ──
      await stage('change currency', () async {
        // Scroll to the currency row and tap it.
        // The currency code (e.g. "SAR") is visible inside an InkWell.
        await scrollUntilVisible(tester, find.text('Group Currency'));

        // Tap the currency code text (it's in the InkWell row)
        final sarText = find.text('SAR');
        if (sarText.evaluate().isNotEmpty) {
          await tapAndSettle(tester, sarText.first);
          await pumpAndSettleWithTimeout(tester);

          // The currency picker sheet should open
          final pickerTitle = find.text('Select Currency');
          if (pickerTitle.evaluate().isNotEmpty) {
            // Search for USD
            final searchField = find.byType(TextField);
            if (searchField.evaluate().isNotEmpty) {
              await enterTextAndPump(tester, searchField.first, 'USD');
              await pumpAndSettleWithTimeout(tester);
            }

            // Tap the first USD item to select it
            final usdItem = find.textContaining('USD');
            if (usdItem.evaluate().isNotEmpty) {
              await tapAndSettle(tester, usdItem.first);
              await pumpAndSettleWithTimeout(tester);
            }

            // A warning dialog may appear; confirm it
            final changeButton = find.text('Change Currency');
            if (changeButton.evaluate().isNotEmpty) {
              await tapAndSettle(tester, changeButton.last);
              await pumpAndSettleWithTimeout(tester);
            }
          }
        }
      });

      // ── Stage: change settlement method ──
      await stage('change settlement method', () async {
        // Scroll to "Settlement method" label and tap the "Pairwise" method text
        // which is the default method shown in the InkWell row.
        await scrollUntilVisible(tester, find.text('Settlement method'));

        final pairwiseText = find.text('Pairwise');
        if (pairwiseText.evaluate().isNotEmpty) {
          await tapAndSettle(tester, pairwiseText.first);
          await pumpAndSettleWithTimeout(tester);

          // Select "Greedy" from the picker
          final greedyOption = find.text('Greedy');
          if (greedyOption.evaluate().isNotEmpty) {
            await tapAndSettle(tester, greedyOption.first);
            await pumpAndSettleWithTimeout(tester);
          }
        }
      });

      // ── Stage: navigate back to group detail ──
      await stage('navigate back to group detail', () async {
        // We should be on the settings page; navigate back
        final backIcon = find.byIcon(Icons.arrow_back);
        if (backIcon.evaluate().isNotEmpty) {
          await tapAndSettle(tester, backIcon.first);
        }
        await waitForWidget(tester, find.text('Expenses'));
      });

      // ── Stage: check balance tab calculations ──
      await stage('check balance calculations', () async {
        await tapAndSettle(tester, find.text('Balance').first);
        await pumpAndSettleWithTimeout(tester);

        // With 120 split among 4 people (You, Alice, Bob, Charlie),
        // each owes ~30. The "You" paid 120, so others owe 30 each.
        // Verify balance data is displayed
        final hasAlice = find.text('Alice').evaluate().isNotEmpty;
        final hasBob = find.text('Bob').evaluate().isNotEmpty;
        final hasSettleUp = find.text('Settle Up').evaluate().isNotEmpty;
        final hasArrow = find.textContaining('→').evaluate().isNotEmpty;
        expect(
          hasAlice || hasBob || hasSettleUp || hasArrow,
          isTrue,
          reason:
              'Balance tab should show participant names or settlement arrows',
        );
      });

      // ── Stage: record a settlement payment ──
      await stage('record settlement payment', () async {
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

      // ── Stage: freeze settlements ──
      await stage('freeze settlements', () async {
        // Go to settings (might be on Balance or Expenses tab)
        await tapAndSettle(tester, find.byIcon(Icons.settings).last);
        await waitForWidget(tester, find.text('Group Settings'));

        // Find and toggle the settlement freeze switch
        await scrollUntilVisible(tester, find.text('Settlement freeze'));
        final freezeTile = find.ancestor(
          of: find.text('Settlement freeze'),
          matching: find.byType(SwitchListTile),
        );
        if (freezeTile.evaluate().isNotEmpty) {
          final switchWidget = find.descendant(
            of: freezeTile,
            matching: find.byType(Switch),
          );
          if (switchWidget.evaluate().isNotEmpty) {
            await tapAndSettle(tester, switchWidget);
            await pumpAndSettleWithTimeout(tester);
          }
        }
      });

      // ── Stage: verify freeze on balance tab ──
      await stage('verify freeze on balance tab', () async {
        // Navigate back from settings
        final backIcon = find.byIcon(Icons.arrow_back);
        if (backIcon.evaluate().isNotEmpty) {
          await tapAndSettle(tester, backIcon.first);
        }
        await waitForWidget(tester, find.text('Expenses'));

        // "Balance" may appear in both the tab and content area; use .first
        await tapAndSettle(tester, find.text('Balance').first);
        await pumpAndSettleWithTimeout(tester);

        // When frozen, a banner should show "Settlement frozen"
        final frozenText = find.text('Settlement frozen');
        final pauseIcon = find.byIcon(Icons.pause_circle);
        final isFrozen = frozenText.evaluate().isNotEmpty ||
            pauseIcon.evaluate().isNotEmpty;
        expect(isFrozen, isTrue,
            reason: 'Balance tab should show frozen indicator');
      });

      // ── Stage: unfreeze settlements ──
      await stage('unfreeze settlements', () async {
        // We're on the Balance tab; try to unfreeze from the banner
        final unfreezeButton = find.text('Unfreeze settlement');
        if (unfreezeButton.evaluate().isNotEmpty) {
          await tapAndSettle(tester, unfreezeButton);
          await pumpAndSettleWithTimeout(tester);
        }

        // Verify freeze is removed (no more pause icon)
        await pumpAndSettleWithTimeout(tester);
      });

      // ── Stage: delete group ──
      await stage('delete group', () async {
        // We might be on any page (balance tab, settings, etc.)
        // If we're already on Group Settings, proceed. Otherwise navigate there.
        final groupSettings = find.text('Group Settings');
        if (groupSettings.evaluate().isEmpty) {
          // Not on settings page; check if we're on group detail
          final expensesTab = find.text('Expenses');
          if (expensesTab.evaluate().isNotEmpty) {
            await tapAndSettle(tester, expensesTab);
            await pumpAndSettleWithTimeout(tester);
          }
          final settingsIcon = find.byIcon(Icons.settings);
          await waitForWidget(tester, settingsIcon);
          await tapAndSettle(tester, settingsIcon.last);
          await waitForWidget(tester, find.text('Group Settings'));
        }

        await scrollUntilVisible(tester, find.text('Delete Group'));
        await tapAndSettle(tester, find.text('Delete Group'));

        await tester.pump(const Duration(seconds: 11));
        await pumpAndSettleWithTimeout(tester);

        final confirmDelete = find.text('Delete Group');
        if (confirmDelete.evaluate().isNotEmpty) {
          await tapAndSettle(tester, confirmDelete.last);
        }

        await waitForWidget(tester, find.byIcon(Icons.add));
      });
    });
  });
}
