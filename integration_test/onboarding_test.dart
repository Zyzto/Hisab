import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_bootstrap.dart';
import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Onboarding', () {
    testWidgets('complete onboarding flow lands on home', (tester) async {
      final ready = await runIntegrationTestApp(skipOnboarding: false);
      ensureBootstrapReady(ready);
      await pumpAndSettleWithTimeout(tester);

      // Page 1: Welcome
      await waitForWidget(tester, find.text('Welcome to Hisab'));
      expect(find.text('Welcome to Hisab'), findsOneWidget);

      // Tap Next to go to page 2 (Permissions)
      await tapAndSettle(tester, find.text('Next'));
      await tester.pump(const Duration(milliseconds: 500));
      await pumpAndSettleWithTimeout(tester);

      await waitForWidget(tester, find.text('Permissions'));

      // Tap Next to go to page 3 (Connect / mode selection)
      await tapAndSettle(tester, find.text('Next'));
      await tester.pump(const Duration(milliseconds: 500));
      await pumpAndSettleWithTimeout(tester);

      await waitForWidget(tester, find.text('Connect'));

      // Complete onboarding
      await tapAndSettle(tester, find.text('Start'));
      await pumpAndSettleWithTimeout(tester);

      // Should land on Home
      await waitForWidget(tester, find.byIcon(Icons.add));
      final hasGroups = find.text('Groups').evaluate().isNotEmpty;
      final hasNoGroups = find.text('No Groups Yet').evaluate().isNotEmpty;
      expect(
        hasGroups || hasNoGroups,
        isTrue,
        reason: 'After onboarding, home page should be visible',
      );
    });
  });
}
