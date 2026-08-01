import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/widgets/amount_text.dart';
import 'package:hisab/features/expenses/widgets/expense_list_tile.dart';
import 'package:hisab/domain/domain.dart';

void main() {
  testWidgets('AmountText forces LTR even inside RTL Directionality', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: AmountText('792.50 ريال')),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('792.50 ريال'));
    expect(text.textDirection, TextDirection.ltr);
  });

  testWidgets(
    'ExpenseListTile amount is LTR and chevron flips in RTL',
    (tester) async {
      final now = DateTime(2025, 1, 15);
      final expense = Expense(
        id: 'e1',
        groupId: 'g1',
        payerParticipantId: 'p1',
        amountCents: 79250,
        currencyCode: 'SAR',
        title: 'Lunch',
        date: now,
        splitType: SplitType.equal,
        splitShares: const {'p1': 79250},
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: ExpenseListTile(
                expense: expense,
                payerName: 'abcd',
                groupCurrencyCode: 'SAR',
                showPaidBy: false,
                showDisclosure: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // AmountText keeps Flutter TextDirection.ltr (clash-safe vs intl).
      final amount = tester.widget<Text>(find.textContaining('792.50'));
      expect(amount.textDirection, TextDirection.ltr);

      // RTL disclosure chevron points toward the trailing/start edge.
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    },
  );
}
