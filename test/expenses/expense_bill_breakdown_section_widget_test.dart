import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/expenses/widgets/expense_bill_breakdown_section.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('ExpenseBillBreakdownSection shows label and add button', (tester) async {
    final controllers = <({TextEditingController desc, TextEditingController amount})>[];
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: ExpenseBillBreakdownSection(
              lineItems: const [],
              lineItemControllers: controllers,
              onAddItem: () {},
              onRemoveItem: (_) {},
              onItemChanged: (_, _, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byType(ExpenseBillBreakdownSection), findsOneWidget);
  });

  testWidgets('ExpenseBillBreakdownSection shows line items when not empty', (tester) async {
    final desc1 = TextEditingController(text: 'Item 1');
    final amount1 = TextEditingController(text: '10');
    final controllers = [
      (desc: desc1, amount: amount1),
    ];
    addTearDown(() {
      desc1.dispose();
      amount1.dispose();
    });
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: ExpenseBillBreakdownSection(
              lineItems: const [
                ReceiptLineItem(description: 'Item 1', amountCents: 1000),
              ],
              lineItemControllers: controllers,
              onAddItem: () {},
              onRemoveItem: (_) {},
              onItemChanged: (_, _, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Item 1'), findsOneWidget);
  });
}
