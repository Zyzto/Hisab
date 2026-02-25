import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/widgets/currency_picker_list.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('AppCurrencyPickerList shows search and currency list', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: AppCurrencyPickerList(
                onSelect: (_) {},
                showSearchField: true,
                showFlag: true,
                showCurrencyCode: true,
                showCurrencyName: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppCurrencyPickerList), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    // Currency list is built in initState; list view is present
    expect(find.byType(ListView), findsOneWidget);
  });
}
