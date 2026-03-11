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

  testWidgets('ExpenseAmountSection shows base amount field with key when group currency differs', (tester) async {
    final exchangeRateController = TextEditingController(text: '0.27');
    final baseAmountController = TextEditingController();
    addTearDown(exchangeRateController.dispose);
    addTearDown(baseAmountController.dispose);

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
              groupCurrencyCode: 'SAR',
              exchangeRateController: exchangeRateController,
              baseAmountController: baseAmountController,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('expense_form_base_amount')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('expense_form_base_amount')), '375');
    await tester.pumpAndSettle();
    expect(baseAmountController.text, '375');
  });
}
