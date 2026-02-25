import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('ExpenseDetailBodyHeader shows title and icon', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: ExpenseDetailBodyHeader(
              expense: testExpense,
              use24HourFormat: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.byIcon(Icons.credit_card), findsOneWidget);
  });

  testWidgets('ExpenseDetailBodyHeader shows date text', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: ExpenseDetailBodyHeader(
              expense: testExpense,
              use24HourFormat: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('2025'), findsOneWidget);
  });

  testWidgets('ExpenseDetailBodyHeader income shows trending icon', (tester) async {
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
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: ExpenseDetailBodyHeader(expense: income),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.trending_up), findsOneWidget);
  });
}
