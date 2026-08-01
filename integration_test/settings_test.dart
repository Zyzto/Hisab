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
          // Sections start expanded; only tap the header if Export is hidden.
          await scrollUntilVisible(
            tester,
            textAnyOf(tester, ['Data & Backup', 'البيانات والنسخة الاحتياطية']),
          );
          final exportTile = textAnyOf(tester, [
            'Export data',
            'تصدير البيانات',
          ]);
          if (exportTile.evaluate().isEmpty) {
            await tapAndSettle(
              tester,
              textAnyOf(tester, [
                'Data & Backup',
                'البيانات والنسخة الاحتياطية',
              ]),
            );
            await pumpAndSettleWithTimeout(tester);
          }

          await scrollUntilVisible(tester, exportTile);
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
          expect(
            find.text('Import Data').evaluate().isNotEmpty ||
                find.text('استيراد البيانات').evaluate().isNotEmpty,
            isTrue,
          );
          // Do NOT tap Import on device: FilePicker.platform.pickFiles()
          // opens a native picker that blocks the test.
          // Verify we're still on settings
          await waitForAnyText(tester, ['Settings', 'الإعدادات']);
        });

        // ── Stage: toggle telemetry ──
        await stage('toggle telemetry', () async {
          // Sections start expanded; only tap the header if the tile is hidden.
          await scrollUntilVisible(
            tester,
            textAnyOf(tester, ['Privacy', 'الخصوصية']),
          );
          final telemetryLabel = textAnyOf(tester, [
            'Send anonymous usage data',
            'إرسال بيانات استخدام مجهولة',
          ]);
          if (telemetryLabel.evaluate().isEmpty) {
            await tapAndSettle(
              tester,
              textAnyOf(tester, ['Privacy', 'الخصوصية']),
            );
            await tester.pumpAndSettle();
          }

          await scrollUntilVisible(tester, telemetryLabel);

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

          final viewLogs = find.text('View logs').evaluate().isNotEmpty
              ? find.text('View logs')
              : find.text('عرض السجلات');
          if (viewLogs.evaluate().isEmpty) {
            await tapAndSettle(tester, textAnyOf(tester, ['About', 'حول']));
            await pumpAndSettleWithTimeout(tester);
          }

          final viewLogsAfter = find.text('View logs').evaluate().isNotEmpty
              ? find.text('View logs')
              : find.text('عرض السجلات');
          if (viewLogsAfter.evaluate().isNotEmpty) {
            expect(viewLogsAfter, findsOneWidget);
          }
        });

        // ── Stage: settings persist ──
        await stage('settings persist', () async {
          // After about/telemetry the browse list is scrolled down and Theme is
          // lazily disposed. Scroll the settings ListView specifically — the
          // page-section index also owns a Scrollable that must not be dragged.
          final settingsScrollable = find.descendant(
            of: find.byKey(const PageStorageKey<String>('settings_list')),
            matching: find.byType(Scrollable),
          );
          final themeTile = textAnyOf(tester, ['Theme', 'المظهر']);
          await scrollUntilVisible(
            tester,
            themeTile,
            scrollable: settingsScrollable,
            delta: 200,
          );
          if (themeTile.evaluate().isEmpty) {
            await tapAndSettle(
              tester,
              textAnyOf(tester, ['Appearance', 'المظهر']),
            );
            await pumpAndSettleWithTimeout(tester);
            await scrollUntilVisible(
              tester,
              themeTile,
              scrollable: settingsScrollable,
              delta: 200,
            );
          }
          await tapAndSettle(tester, themeTile);

          await tapAnyText(tester, ['Dark', 'داكن']);

          await tapAnyText(tester, ['Groups', 'المجموعات']);
          await pumpAndSettleWithTimeout(tester);

          await waitForAnyText(tester, ['Settings', 'الإعدادات']);
          await tapAnyText(tester, ['Settings', 'الإعدادات']);

          await scrollUntilVisible(
            tester,
            themeTile,
            scrollable: settingsScrollable,
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
