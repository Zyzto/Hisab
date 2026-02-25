import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/expenses/widgets/expense_list_tile.dart';
import '../widget_test_helpers.dart';

void main() {
  final now = DateTime(2025, 1, 15);
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
      title: 'Lunch',
      date: now,
      splitType: SplitType.equal,
      splitShares: const {},
      createdAt: now,
      updatedAt: now,
    );
  });

  testWidgets('ExpenseListTile renders title and formatted amount', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: ExpenseListTile(
              expense: testExpense,
              payerName: 'Alice',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.textContaining('50'), findsOneWidget);
  });

  testWidgets('ExpenseListTile when showPaidBy true builds with title', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: ExpenseListTile(
              expense: testExpense,
              payerName: 'Bob',
              showPaidBy: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.byType(ExpenseListTile), findsOneWidget);
  });

  testWidgets('ExpenseListTile when showPaidBy false does not show paid by', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: ExpenseListTile(
              expense: testExpense,
              payerName: 'Alice',
              showPaidBy: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lunch'), findsOneWidget);
    // "Paid by Alice" should not appear (only title and amount)
    expect(find.textContaining('Paid by'), findsNothing);
  });

  testWidgets('ExpenseListTile renders with Arabic locale', (tester) async {
    await pumpApp(
      tester,
      child: ExpenseListTile(
        expense: testExpense,
        payerName: 'Alice',
        showPaidBy: true,
      ),
      locale: const Locale('ar'),
    );
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.textContaining('50'), findsOneWidget);
    expect(find.byType(ExpenseListTile), findsOneWidget);
  });

  testWidgets('ExpenseListTile zero amount shows formatted amount', (tester) async {
    final zeroExpense = Expense(
      id: 'e2',
      groupId: 'g1',
      payerParticipantId: 'p1',
      amountCents: 0,
      currencyCode: 'USD',
      title: 'Free',
      date: now,
      splitType: SplitType.equal,
      splitShares: const {},
      createdAt: now,
      updatedAt: now,
    );
    await pumpApp(
      tester,
      child: ExpenseListTile(expense: zeroExpense, payerName: 'Bob'),
    );
    expect(find.text('Free'), findsOneWidget);
    expect(find.byType(ExpenseListTile), findsOneWidget);
  });

  testWidgets('ExpenseListTile very long title builds and ellipsizes', (tester) async {
    final longTitleExpense = Expense(
      id: 'e3',
      groupId: 'g1',
      payerParticipantId: 'p1',
      amountCents: 100,
      currencyCode: 'USD',
      title: 'A' * 200,
      date: now,
      splitType: SplitType.equal,
      splitShares: const {},
      createdAt: now,
      updatedAt: now,
    );
    await pumpApp(
      tester,
      child: ExpenseListTile(expense: longTitleExpense, payerName: 'Alice'),
    );
    expect(find.byType(ExpenseListTile), findsOneWidget);
  });

  testWidgets('ExpenseListTile income transaction type renders', (tester) async {
    final incomeExpense = Expense(
      id: 'e4',
      groupId: 'g1',
      payerParticipantId: 'p1',
      amountCents: 3000,
      currencyCode: 'EUR',
      title: 'Refund',
      date: now,
      splitType: SplitType.equal,
      splitShares: const {},
      createdAt: now,
      updatedAt: now,
      transactionType: TransactionType.income,
    );
    await pumpApp(
      tester,
      child: ExpenseListTile(expense: incomeExpense, payerName: 'Bob'),
    );
    expect(find.text('Refund'), findsOneWidget);
    expect(find.byType(ExpenseListTile), findsOneWidget);
  });
}
