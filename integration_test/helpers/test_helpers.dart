import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_bootstrap.dart';

/// Records stage progress in the binding's reportData so the web driver
/// can display which stage passed/failed even when failure details are empty.
void recordStage(String testName, String info) {
  try {
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    binding.reportData ??= <String, dynamic>{};
    final log = (binding.reportData!['stage_log'] as List<dynamic>?) ?? [];
    log.add('[$testName] $info');
    binding.reportData!['stage_log'] = log;
    binding.reportData!['last_stage'] = '[$testName] $info';
  } catch (_) {}
}

/// [pumpAndSettle] with a configurable timeout (default 30s).
Future<void> pumpAndSettleWithTimeout(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, timeout);
}

/// Tap a widget and wait for animations to settle.
Future<void> tapAndSettle(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  await tester.tap(finder);
  await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, timeout);
}

/// Tap a widget and pump manually (no pumpAndSettle). Use this for buttons
/// that trigger async operations like DB writes + navigation, where
/// pumpAndSettle would return before the Future completes.
Future<void> tapAndPump(
  WidgetTester tester,
  Finder finder, {
  int pumps = 20,
  Duration interval = const Duration(milliseconds: 200),
}) async {
  await tester.tap(finder);
  for (var i = 0; i < pumps; i++) {
    await tester.pump(interval);
  }
}

/// Enter text into a field and pump. Falls back to direct controller
/// manipulation when [tester.enterText] doesn't work (e.g. web release).
Future<void> enterTextAndPump(
  WidgetTester tester,
  Finder finder,
  String text, {
  Duration pumpDuration = const Duration(milliseconds: 300),
}) async {
  await tester.enterText(finder, text);
  await tester.pump(pumpDuration);

  // Verify the text was applied; set via controller as fallback for web.
  try {
    final editableFinder = find.descendant(
      of: finder,
      matching: find.byType(EditableText),
    );
    if (editableFinder.evaluate().isNotEmpty) {
      final editable = tester.widget<EditableText>(editableFinder.first);
      if (editable.controller.text != text) {
        editable.controller.text = text;
        editable.controller.selection =
            TextSelection.collapsed(offset: text.length);
        await tester.pump(pumpDuration);
      }
    }
  } catch (_) {}
}

/// Poll until [finder] finds at least one widget, or throw after [timeout].
Future<void> waitForWidget(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsWidgets, reason: 'Timed out waiting for $finder');
}

/// Scroll until [finder] is visible, using [tester.ensureVisible] when the
/// widget is already in the tree, or manual drag-scrolling otherwise.
Future<void> scrollUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Finder? scrollable,
  double delta = -200,
  int maxScrolls = 50,
}) async {
  if (finder.evaluate().isNotEmpty) {
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    return;
  }
  final scrollFinder = scrollable ?? find.byType(Scrollable).first;
  for (var i = 0; i < maxScrolls; i++) {
    await tester.drag(scrollFinder, Offset(0, delta));
    await tester.pumpAndSettle();
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder.first);
      await tester.pumpAndSettle();
      return;
    }
  }
  expect(finder, findsWidgets, reason: 'Could not scroll to $finder');
}

/// Tap the expense form's submit button ("Add Expense" / "Submit") reliably.
/// Uses [FilledButton] type to avoid ambiguity with the AppBar title.
Future<void> tapSubmitExpenseButton(WidgetTester tester) async {
  var submitButton = find.widgetWithText(FilledButton, 'Add Expense');
  if (submitButton.evaluate().isEmpty) {
    submitButton = find.widgetWithText(FilledButton, 'Submit');
  }
  if (submitButton.evaluate().isNotEmpty) {
    await tester.ensureVisible(submitButton);
    await tapAndSettle(tester, submitButton,
        timeout: const Duration(seconds: 15));
  }
  await tester.pump(const Duration(seconds: 1));
}

/// After calling [tapSubmitExpenseButton], call this to ensure we're not
/// stuck on the expense form. On web, the form save sometimes fails silently;
/// this navigates back if the form submit button is still showing.
Future<void> ensureFormClosed(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  // If the submit button is still visible, the form didn't close
  final formStillOpen =
      find.widgetWithText(FilledButton, 'Add Expense').evaluate().isNotEmpty ||
      find.widgetWithText(FilledButton, 'Submit').evaluate().isNotEmpty;
  if (formStillOpen) {
    final back = find.byIcon(Icons.arrow_back);
    if (back.evaluate().isNotEmpty) {
      await tapAndSettle(tester, back.first);
      await pumpAndSettleWithTimeout(tester);
    }
  }
}

/// Wraps a logical test stage so failures include the stage name.
/// On web, also records progress in the binding's reportData for diagnostics.
Future<void> stage(String name, Future<void> Function() body) async {
  recordStage(name, 'STARTED');
  try {
    await body();
    recordStage(name, 'PASSED');
  } catch (e) {
    recordStage(name, 'FAILED: $e');
    throw TestFailure('FAILED at stage "$name": $e');
  }
}

/// Bootstrap guard: call at the start of each test group.
/// Throws [TestFailure] with a descriptive message if bootstrap returned false.
void ensureBootstrapReady(bool ready) {
  if (!ready) {
    throw TestFailure(
      'Integration test bootstrap failed (e.g. PowerSync unavailable)',
    );
  }
}

/// Runs the integration test app, ensures bootstrap succeeded, and waits for
/// the home FAB (Icons.add) to be visible. Call at the start of each test that
/// expects the app to be on the home screen.
Future<void> ensureIntegrationTestReady(
  WidgetTester tester, {
  bool skipOnboarding = true,
  Duration? waitTimeout,
}) async {
  final ready = await runIntegrationTestApp(skipOnboarding: skipOnboarding);
  ensureBootstrapReady(ready);
  await waitForWidget(
    tester,
    find.byIcon(Icons.add),
    timeout: waitTimeout ?? const Duration(seconds: 30),
  );
}
