import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/expenses/widgets/expense_amount_section.dart';

void main() {
  late TextEditingController controller;

  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  setUp(() {
    controller = TextEditingController(text: '25.00');
  });

  tearDown(() {
    controller.dispose();
  });

  testWidgets('ExpenseAmountSection shows amount and currency', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: ExpenseAmountSection(
              controller: controller,
              currencyCode: 'USD',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('25'), findsOneWidget);
    expect(find.textContaining('USD'), findsOneWidget);
  });
}
