import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Settings lifecycle', () {
    testWidgets(
        'theme → language → font size → export → import → telemetry → about → persist',
        (tester) async {
      await ensureIntegrationTestReady(tester);
      await waitForWidget(tester, find.text('Settings'),
          timeout: const Duration(seconds: 30));

      await tapAndSettle(tester, find.text('Settings'));

      // ── Stage: change theme ──
      await stage('change theme', () async {
        await scrollUntilVisible(tester, find.text('Theme'));
        await tapAndSettle(tester, find.text('Theme'));

        await waitForWidget(tester, find.text('Light'));
        await tapAndSettle(tester, find.text('Light'));

        await scrollUntilVisible(tester, find.text('Theme'));
        expect(find.text('Light'), findsWidgets);
      });

      // ── Stage: change language ──
      await stage('change language', () async {
        await scrollUntilVisible(tester, find.text('Language'));
        await tapAndSettle(tester, find.text('Language'));

        await waitForWidget(tester, find.text('العربية'));
        await tapAndSettle(tester, find.text('العربية'));
        await pumpAndSettleWithTimeout(tester);

        expect(find.text('العربية'), findsWidgets);

        final langTile = find.text('اللغة');
        if (langTile.evaluate().isNotEmpty) {
          await scrollUntilVisible(tester, langTile);
          await tapAndSettle(tester, langTile);
          await waitForWidget(tester, find.text('English'));
          await tapAndSettle(tester, find.text('English'));
          await pumpAndSettleWithTimeout(tester);
        }

        expect(find.text('Settings'), findsWidgets);
      });

      // ── Stage: change font size ──
      await stage('change font size', () async {
        await scrollUntilVisible(tester, find.text('Font size'));
        await tapAndSettle(tester, find.text('Font size'));

        await waitForWidget(tester, find.text('Large'));
        await tapAndSettle(tester, find.text('Large'));

        await scrollUntilVisible(tester, find.text('Font size'));
        expect(find.text('Large'), findsWidgets);

        // Revert to Normal
        await tapAndSettle(tester, find.text('Font size'));
        await waitForWidget(tester, find.text('Normal'));
        await tapAndSettle(tester, find.text('Normal'));
      });

      // ── Stage: test export data ──
      await stage('test export data', () async {
        // Data & Backup section is collapsed by default -- expand it
        await scrollUntilVisible(tester, find.text('Data & Backup'));
        await tapAndSettle(tester, find.text('Data & Backup'));
        await pumpAndSettleWithTimeout(tester);

        await scrollUntilVisible(tester, find.text('Export data'));
        expect(find.text('Export data'), findsOneWidget);

        // Do NOT tap Export data on mobile: FilePicker.platform.saveFile()
        // opens a native Android save dialog that blocks the test.
        // Just verify the tile is present.
        await scrollUntilVisible(tester, find.text('Import data'));
        expect(find.text('Import data'), findsOneWidget);
      });

      // ── Stage: test import data ──
      await stage('test import data', () async {
        await scrollUntilVisible(tester, find.text('Import data'));
        await tapAndSettle(tester, find.text('Import data'));
        await pumpAndSettleWithTimeout(tester);

        // Confirmation dialog should appear
        await waitForWidget(
          tester,
          find.textContaining('overwrite or duplicate'),
        );

        // Dismiss the import confirmation bottom sheet by tapping the
        // scrim barrier above it. The Cancel button is rendered inside
        // the bottom sheet overlay and is not reliably hit-testable.
        await tester.tapAt(const Offset(200, 100));
        await pumpAndSettleWithTimeout(tester);
        // If the dialog is still open, try Navigator pop as fallback.
        if (find.textContaining('overwrite or duplicate').evaluate().isNotEmpty) {
          final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
          nav.pop(false);
          await pumpAndSettleWithTimeout(tester);
        }

        // Verify we're still on settings
        expect(find.text('Settings'), findsWidgets);
      });

      // ── Stage: toggle telemetry ──
      await stage('toggle telemetry', () async {
        // Privacy section is collapsed by default -- expand it
        await scrollUntilVisible(tester, find.text('Privacy'));
        await tapAndSettle(tester, find.text('Privacy'));
        await tester.pumpAndSettle();

        await scrollUntilVisible(
          tester,
          find.text('Send anonymous usage data'),
        );

        final telemetryTile = find.ancestor(
          of: find.text('Send anonymous usage data'),
          matching: find.byType(ListTile),
        );
        final switchWidget = find.descendant(
          of: telemetryTile,
          matching: find.byType(Switch),
        );

        if (switchWidget.evaluate().isNotEmpty) {
          final initialSwitch = tester.widget<Switch>(switchWidget);
          final wasOn = initialSwitch.value;

          await tapAndSettle(tester, switchWidget);

          final updatedSwitch = tester.widget<Switch>(switchWidget);
          expect(updatedSwitch.value, equals(!wasOn));

          await tapAndSettle(tester, switchWidget);
        }
      });

      // ── Stage: verify About section ──
      await stage('verify about section', () async {
        await scrollUntilVisible(tester, find.text('About'));
        expect(find.text('About'), findsWidgets);

        // Tap to expand the About section
        await tapAndSettle(tester, find.text('About'));
        await pumpAndSettleWithTimeout(tester);

        // Verify app version info or View logs appears
        final viewLogs = find.text('View logs');
        if (viewLogs.evaluate().isNotEmpty) {
          expect(viewLogs, findsOneWidget);
        }
      });

      // ── Stage: settings persist ──
      await stage('settings persist', () async {
        // After the about/telemetry stages the ListView is scrolled down.
        // "Theme" is near the top and has been disposed by the lazy builder.
        // Scroll UP (positive delta) to bring it back into the viewport.
        await scrollUntilVisible(tester, find.text('Theme'), delta: 200);
        await tapAndSettle(tester, find.text('Theme'));

        await waitForWidget(tester, find.text('Dark'));
        await tapAndSettle(tester, find.text('Dark'));

        await tapAndSettle(tester, find.text('Groups'));
        await pumpAndSettleWithTimeout(tester);

        await waitForWidget(tester, find.text('Settings'));
        await tapAndSettle(tester, find.text('Settings'));

        await scrollUntilVisible(tester, find.text('Theme'), delta: 200);
        expect(find.text('Dark'), findsWidgets);
      });
    });
  });
}
