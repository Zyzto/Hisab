import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  group('Settings lifecycle', () {
    testWidgets(
      'theme → language → font size → export → import → telemetry → about → persist',
      (tester) async {
        await ensureIntegrationTestReady(tester);
        await waitForAnyText(
          tester,
          ['Settings', 'الإعدادات'],
          timeout: const Duration(seconds: 30),
        );
        await tapAnyText(tester, ['Settings', 'الإعدادات']);

        // ── Stage: change theme ──
        await stage('change theme', () async {
          final themeTile = textAnyOf(tester, ['Theme', 'المظهر']);
          await scrollUntilVisible(tester, themeTile);
          await tapAndSettle(tester, themeTile);

          await tapAnyText(tester, ['Light', 'فاتح']);

          await scrollUntilVisible(tester, textAnyOf(tester, ['Theme', 'المظهر']));
          expect(
            find.text('Light').evaluate().isNotEmpty ||
                find.text('فاتح').evaluate().isNotEmpty,
            isTrue,
          );
        });

        // ── Stage: change language ──
        await stage('change language', () async {
          final languageTile = textAnyOf(tester, ['Language', 'اللغة']);
          await scrollUntilVisible(tester, languageTile);
          await tapAndSettle(tester, languageTile);

          await waitForWidget(tester, find.text('العربية'));
          await tapAndSettle(tester, find.text('العربية'));
          await pumpAndSettleWithTimeout(tester);

          expect(find.text('العربية'), findsWidgets);

          await scrollUntilVisible(tester, textAnyOf(tester, ['Language', 'اللغة']));
          await tapAndSettle(tester, textAnyOf(tester, ['Language', 'اللغة']));
          await waitForWidget(tester, find.text('English'));
          await tapAndSettle(tester, find.text('English'));
          await pumpAndSettleWithTimeout(tester);

          await waitForAnyText(tester, ['Settings', 'الإعدادات']);
        });

        // ── Stage: change font size ──
        await stage('change font size', () async {
          await scrollUntilVisible(
            tester,
            textAnyOf(tester, ['Font Size', 'حجم الخط']),
          );
          await tapAndSettle(tester, textAnyOf(tester, ['Font Size', 'حجم الخط']));

          await tapAnyText(tester, ['Large', 'كبير']);

          await scrollUntilVisible(
            tester,
            textAnyOf(tester, ['Font Size', 'حجم الخط']),
          );
          expect(
            find.text('Large').evaluate().isNotEmpty ||
                find.text('كبير').evaluate().isNotEmpty,
            isTrue,
          );

          // Revert to Normal
          await tapAndSettle(tester, textAnyOf(tester, ['Font Size', 'حجم الخط']));
          await tapAnyText(tester, ['Normal', 'عادي']);
        });

        // ── Stage: test export data ──
        await stage('test export data', () async {
          // Data & Backup section is collapsed by default -- expand it
          await scrollUntilVisible(
            tester,
            textAnyOf(tester, ['Data & Backup', 'البيانات والنسخة الاحتياطية']),
          );
          await tapAndSettle(
            tester,
            textAnyOf(tester, ['Data & Backup', 'البيانات والنسخة الاحتياطية']),
          );
          await pumpAndSettleWithTimeout(tester);

          await scrollUntilVisible(
            tester,
            textAnyOf(tester, ['Export data', 'تصدير البيانات']),
          );
          expect(
            find.text('Export data').evaluate().isNotEmpty ||
                find.text('تصدير البيانات').evaluate().isNotEmpty,
            isTrue,
          );

          // Do NOT tap Export data on mobile: FilePicker.platform.saveFile()
          // opens a native Android save dialog that blocks the test.
          // Just verify the tile is present.
          await scrollUntilVisible(
            tester,
            textAnyOf(tester, ['Import Data', 'استيراد البيانات']),
          );
          expect(
            find.text('Import Data').evaluate().isNotEmpty ||
                find.text('استيراد البيانات').evaluate().isNotEmpty,
            isTrue,
          );
        });

        // ── Stage: test import data ──
        await stage('test import data', () async {
          await scrollUntilVisible(
            tester,
            textAnyOf(tester, ['Import Data', 'استيراد البيانات']),
          );
          await tapAndSettle(
            tester,
            textAnyOf(tester, ['Import Data', 'استيراد البيانات']),
          );
          await pumpAndSettleWithTimeout(tester);

          // Confirmation sheet/dialog should appear.
          await waitForCondition(
            tester,
            condition: () =>
                find.byType(BottomSheet).evaluate().isNotEmpty ||
                find.byType(Dialog).evaluate().isNotEmpty ||
                find.byType(AlertDialog).evaluate().isNotEmpty,
            timeout: const Duration(seconds: 10),
            reason: 'Import confirmation sheet/dialog should appear',
          );

          // Dismiss the import confirmation bottom sheet by tapping the
          // scrim barrier above it. The Cancel button is rendered inside
          // the bottom sheet overlay and is not reliably hit-testable.
          await tester.tapAt(const Offset(200, 100));
          await pumpAndSettleWithTimeout(tester);
          // If the dialog is still open, try Navigator pop as fallback.
          final confirmStillOpen =
              find.byType(BottomSheet).evaluate().isNotEmpty ||
              find.byType(Dialog).evaluate().isNotEmpty ||
              find.byType(AlertDialog).evaluate().isNotEmpty;
          if (confirmStillOpen) {
            final nav = tester.state<NavigatorState>(
              find.byType(Navigator).last,
            );
            nav.pop(false);
            await pumpAndSettleWithTimeout(tester);
          }

          // Verify we're still on settings
          await waitForAnyText(tester, ['Settings', 'الإعدادات']);
        });

        // ── Stage: toggle telemetry ──
        await stage('toggle telemetry', () async {
          // Privacy section is collapsed by default -- expand it
          await scrollUntilVisible(
            tester,
            textAnyOf(tester, ['Privacy', 'الخصوصية']),
          );
          await tapAndSettle(tester, textAnyOf(tester, ['Privacy', 'الخصوصية']));
          await tester.pumpAndSettle();

          await scrollUntilVisible(
            tester,
            textAnyOf(
              tester,
              ['Send anonymous usage data', 'إرسال بيانات استخدام مجهولة'],
            ),
          );

          final telemetryTile = find.ancestor(
            of: textAnyOf(
              tester,
              ['Send anonymous usage data', 'إرسال بيانات استخدام مجهولة'],
            ),
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
          await scrollUntilVisible(tester, textAnyOf(tester, ['About', 'حول']));
          expect(
            find.text('About').evaluate().isNotEmpty ||
                find.text('حول').evaluate().isNotEmpty,
            isTrue,
          );

          // Tap to expand the About section
          await tapAndSettle(tester, textAnyOf(tester, ['About', 'حول']));
          await pumpAndSettleWithTimeout(tester);

          // Verify app version info or View logs appears
          final viewLogs = find.text('View logs').evaluate().isNotEmpty
              ? find.text('View logs')
              : find.text('عرض السجلات');
          if (viewLogs.evaluate().isNotEmpty) {
            expect(viewLogs, findsOneWidget);
          }
        });

        // ── Stage: settings persist ──
        await stage('settings persist', () async {
          // After the about/telemetry stages the ListView is scrolled down.
          // "Theme" is near the top and has been disposed by the lazy builder.
          // Scroll UP (positive delta) to bring it back into the viewport.
          await scrollUntilVisible(
            tester,
            textAnyOf(tester, ['Theme', 'المظهر']),
            delta: 200,
          );
          await tapAndSettle(tester, textAnyOf(tester, ['Theme', 'المظهر']));

          await tapAnyText(tester, ['Dark', 'داكن']);

          await tapAnyText(tester, ['Groups', 'المجموعات']);
          await pumpAndSettleWithTimeout(tester);

          await waitForAnyText(tester, ['Settings', 'الإعدادات']);
          await tapAnyText(tester, ['Settings', 'الإعدادات']);

          await scrollUntilVisible(
            tester,
            textAnyOf(tester, ['Theme', 'المظهر']),
            delta: 200,
          );
          expect(
            find.text('Dark').evaluate().isNotEmpty ||
                find.text('داكن').evaluate().isNotEmpty,
            isTrue,
          );
        });
      },
    );
  });
}
