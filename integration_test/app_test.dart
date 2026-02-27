import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'integration_test_bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app opens to home (smoke)', (WidgetTester tester) async {
    final ready = await runIntegrationTestApp();
    if (!ready) {
      throw TestFailure('Integration test bootstrap failed (e.g. PowerSync unavailable)');
    }
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // Home shows shell: either section headers / empty state, or FAB
    final hasGroups = find.text('Groups').evaluate().isNotEmpty;
    final hasNoGroups = find.text('No Groups Yet').evaluate().isNotEmpty;
    final hasPersonal = find.text('Personal').evaluate().isNotEmpty;
    final hasFab = find.byIcon(Icons.add).evaluate().isNotEmpty;
    expect(
      hasGroups || hasNoGroups || hasPersonal || hasFab,
      isTrue,
      reason: 'Expected home shell (Groups, No Groups Yet, Personal, or FAB)',
    );
  });

  testWidgets('create group flow', (WidgetTester tester) async {
    final ready = await runIntegrationTestApp();
    if (!ready) {
      throw TestFailure('Integration test bootstrap failed (e.g. PowerSync unavailable)');
    }
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Tap FAB to open create modal (FAB has Icons.add)
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Tap "Create Group" in the sheet (first ListTile)
    await tester.tap(find.text('Create Group').first);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Step 1: enter group name
    await tester.enterText(find.byType(TextField).first, 'Integration Test Group');
    await tester.pump(const Duration(milliseconds: 300));

    // Next
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Step 2: Skip participants
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Step 3: Next (icon/color)
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Step 4: Create Group
    await tester.tap(find.text('Create Group'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Should be on group detail or back at home with the new group
    expect(
      find.text('Integration Test Group').evaluate().isNotEmpty ||
          find.text('Groups').evaluate().isNotEmpty,
      isTrue,
    );
  });
}
