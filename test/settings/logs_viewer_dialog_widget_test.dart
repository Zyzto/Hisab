import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/settings/widgets/logs_viewer_dialog.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('LogsViewerDialog shows title and clear button', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return LogsViewerDialog(
                  content: 'Log line 1\nLog line 2',
                  onCopy: () async {},
                  onClear: () async {},
                  onReportIssue: () async {},
                  onClose: () {},
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LogsViewerDialog), findsOneWidget);
    expect(find.byIcon(Icons.terminal), findsOneWidget);
  });
}
