import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/expenses/widgets/expense_detail_body.dart';

void main() {
  final now = DateTime(2025, 1, 15, 12, 0);
  late Expense testExpense;

  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  setUp(() {
    testExpense = Expense(
      id: 'e1',
      groupId: 'g1',
      payerParticipantId: 'p1',
      amountCents: 5000,
      currencyCode: 'USD',
      title: 'Coffee',
      date: now,
      splitType: SplitType.equal,
      splitShares: const {},
      createdAt: now,
      updatedAt: now,
      transactionType: TransactionType.expense,
    );
  });

  Widget wrap(Widget child) {
    return ProviderScope(
      child: EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
  }

  testWidgets('ExpenseDetailBodyHeader shows amount and date', (tester) async {
    await tester.pumpWidget(
      wrap(
        ExpenseDetailBodyHeader(
          expense: testExpense,
          use24HourFormat: false,
          amountCents: 5000,
          displayCurrencyCode: 'USD',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('2025'), findsOneWidget);
    expect(find.textContaining('50'), findsWidgets);
  });

  testWidgets('ExpenseDetailBodyHeader shows category chip when tagged', (
    tester,
  ) async {
    final tagged = testExpense.copyWith(tag: 'coffee');
    await tester.pumpWidget(
      wrap(
        ExpenseDetailBodyHeader(
          expense: tagged,
          amountCents: 5000,
          displayCurrencyCode: 'USD',
        ),
      ),
    );
    await tester.pumpAndSettle();
    // One chip icon only (big duplicate icon removed).
    expect(find.byIcon(Icons.coffee), findsOneWidget);
    expect(
      find.textContaining('Coffee').evaluate().isNotEmpty ||
          find.text('category_coffee').evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('ExpenseDetailBodyHeader income shows income chip', (
    tester,
  ) async {
    final income = Expense(
      id: 'e2',
      groupId: 'g1',
      payerParticipantId: 'p1',
      amountCents: 10000,
      currencyCode: 'USD',
      title: 'Refund',
      date: now,
      splitType: SplitType.equal,
      splitShares: const {},
      createdAt: now,
      updatedAt: now,
      transactionType: TransactionType.income,
    );
    await tester.pumpWidget(
      wrap(
        ExpenseDetailBodyHeader(
          expense: income,
          amountCents: 10000,
          displayCurrencyCode: 'USD',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Income').evaluate().isNotEmpty ||
          find.text('income').evaluate().isNotEmpty,
      isTrue,
    );
  });
}
