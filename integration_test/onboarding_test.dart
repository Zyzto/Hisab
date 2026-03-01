import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_bootstrap.dart';
import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Onboarding', () {
    testWidgets('complete onboarding flow lands on home', (tester) async {
      recordStage('onboarding: bootstrap', 'STARTED');
      final ready = await runIntegrationTestApp(skipOnboarding: false);
      ensureBootstrapReady(ready);
      await pumpAndSettleWithTimeout(tester);
      recordStage('onboarding: bootstrap', 'PASSED');

      recordStage('onboarding: Welcome page', 'STARTED');
      await waitForWidget(tester, find.text('Welcome to Hisab'));
      expect(find.text('Welcome to Hisab'), findsOneWidget);
      recordStage('onboarding: Welcome page', 'PASSED');

      recordStage('onboarding: Preferences page', 'STARTED');
      await tapAndSettle(tester, find.text('Next'));
      await tester.pump(const Duration(milliseconds: 500));
      await pumpAndSettleWithTimeout(tester);
      await waitForWidget(tester, find.text('Preferences'));
      recordStage('onboarding: Preferences page', 'PASSED');

      recordStage('onboarding: Permissions page', 'STARTED');
      await tapAndSettle(tester, find.text('Next'));
      await tester.pump(const Duration(milliseconds: 500));
      await pumpAndSettleWithTimeout(tester);
      await waitForWidget(tester, find.text('Permissions'));
      recordStage('onboarding: Permissions page', 'PASSED');

      recordStage('onboarding: Connect page', 'STARTED');
      await tapAndSettle(tester, find.text('Next'));
      await tester.pump(const Duration(milliseconds: 500));
      await pumpAndSettleWithTimeout(tester);
      await waitForWidget(tester, find.text('Connect'));
      recordStage('onboarding: Connect page', 'PASSED');

      recordStage('onboarding: complete and land on home', 'STARTED');
      await tapAndSettle(tester, find.text('Start'));
      await pumpAndSettleWithTimeout(tester);
      await waitForWidget(tester, find.byIcon(Icons.add));
      final hasGroups = find.text('Groups').evaluate().isNotEmpty;
      final hasNoGroups = find.text('No Groups Yet').evaluate().isNotEmpty;
      expect(
        hasGroups || hasNoGroups,
        isTrue,
        reason: 'After onboarding, home page should be visible',
      );
      recordStage('onboarding: complete and land on home', 'PASSED');
    });
  });
}
