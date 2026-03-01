import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Smoke', () {
    testWidgets('app opens to home with FAB visible', (tester) async {
      recordStage('smoke: bootstrap', 'STARTED');
      await ensureIntegrationTestReady(tester);
      recordStage('smoke: bootstrap', 'PASSED');

      recordStage('smoke: FAB visible', 'STARTED');
      expect(find.byIcon(Icons.add), findsOneWidget);
      recordStage('smoke: FAB visible', 'PASSED');
    });

    testWidgets('can navigate to Settings and back', (tester) async {
      recordStage('smoke: bootstrap', 'STARTED');
      await ensureIntegrationTestReady(tester);
      recordStage('smoke: bootstrap', 'PASSED');

      recordStage('smoke: open Settings', 'STARTED');
      await tapAndSettle(tester, find.text('Settings'));
      expect(find.text('Appearance'), findsWidgets);
      recordStage('smoke: open Settings', 'PASSED');

      recordStage('smoke: back to Home', 'STARTED');
      await tapAndSettle(tester, find.text('Groups'));
      final hasFab = find.byIcon(Icons.add).evaluate().isNotEmpty;
      expect(hasFab, isTrue, reason: 'FAB should be visible after returning to Home');
      recordStage('smoke: back to Home', 'PASSED');
    });
  });
}
