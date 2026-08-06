import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/expenses/widgets/expense_detail_body.dart';
import 'package:hisab/features/groups/providers/groups_provider.dart';
import 'package:hisab/core/settings/providers/settings_framework_providers.dart';

void main() {
  final now = DateTime(2025, 1, 15);
  const groupId = 'g1';
  const expenseId = 'e1';
  late Expense testExpense;
  late List<Participant> testParticipants;
  late Group testGroup;

  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  setUp(() {
    testExpense = Expense(
      id: expenseId,
      groupId: groupId,
      payerParticipantId: 'p1',
      amountCents: 5000,
      currencyCode: 'USD',
      title: 'Test expense',
      description: 'Receipt notes',
      date: now,
      splitType: SplitType.equal,
      splitShares: const {'p1': 5000},
      createdAt: now,
      updatedAt: now,
      tag: 'food',
      lineItems: const [
        ReceiptLineItem(description: 'Sandwich', amountCents: 5000),
      ],
    );
    testParticipants = [
      Participant(
        id: 'p1',
        groupId: groupId,
        name: 'Alice',
        order: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    testGroup = Group(
      id: groupId,
      name: 'Trip',
      currencyCode: 'USD',
      createdAt: now,
      updatedAt: now,
      isPersonal: false,
    );
  });

  testWidgets('ExpenseDetailBody shows title in header card', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expensesByGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data([testExpense])),
          futureExpenseProvider(
            expenseId,
          ).overrideWithValue(AsyncValue.data(testExpense)),
          participantsByGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data(testParticipants)),
          futureGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data(testGroup)),
          tagsByGroupProvider(
            groupId,
          ).overrideWithValue(const AsyncValue.data([])),
          use24HourFormatProvider.overrideWithValue(false),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: const [Locale('en')],
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(
            home: Scaffold(
              body: ExpenseDetailBody(groupId: groupId, expenseId: expenseId),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Test expense'), findsOneWidget);
    expect(find.byType(ExpenseDetailBodyHeader), findsOneWidget);
    expect(find.text('Receipt notes'), findsOneWidget);
    expect(find.text('Sandwich'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(_hasText(tester, const ['Paid By', 'paid_by_label']), isTrue);
    // Sole payer/share: split section omitted to avoid duplicating Alice.
    expect(_hasText(tester, const ['Split', 'split']), isFalse);
  });

  testWidgets('group expense shows split for multiple participants', (
    tester,
  ) async {
    final multiExpense = testExpense.copyWith(
      splitShares: const {'p1': 3000, 'p2': 2000},
    );
    final multiParticipants = [
      ...testParticipants,
      Participant(
        id: 'p2',
        groupId: groupId,
        name: 'Bob',
        order: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expensesByGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data([multiExpense])),
          futureExpenseProvider(
            expenseId,
          ).overrideWithValue(AsyncValue.data(multiExpense)),
          participantsByGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data(multiParticipants)),
          futureGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data(testGroup)),
          tagsByGroupProvider(
            groupId,
          ).overrideWithValue(const AsyncValue.data([])),
          use24HourFormatProvider.overrideWithValue(false),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: const [Locale('en')],
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(
            home: Scaffold(
              body: ExpenseDetailBody(groupId: groupId, expenseId: expenseId),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_hasText(tester, const ['Split', 'split']), isTrue);
    expect(find.text('Alice', skipOffstage: false), findsWidgets);
    expect(find.text('Bob', skipOffstage: false), findsOneWidget);
    expect(find.text('60%', skipOffstage: false), findsOneWidget);
    expect(find.text('40%', skipOffstage: false), findsOneWidget);
    expect(_hasText(tester, const ['Equal', 'equal']), isTrue);
  });

  testWidgets('income shows received-by label', (tester) async {
    final income = testExpense.copyWith(
      transactionType: TransactionType.income,
      title: 'Refund',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expensesByGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data([income])),
          futureExpenseProvider(
            expenseId,
          ).overrideWithValue(AsyncValue.data(income)),
          participantsByGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data(testParticipants)),
          futureGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data(testGroup)),
          tagsByGroupProvider(
            groupId,
          ).overrideWithValue(const AsyncValue.data([])),
          use24HourFormatProvider.overrideWithValue(false),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: const [Locale('en')],
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(
            home: Scaffold(
              body: ExpenseDetailBody(groupId: groupId, expenseId: expenseId),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      _hasText(tester, const ['Received By', 'received_by_label']),
      isTrue,
    );
    expect(_hasText(tester, const ['Paid By', 'paid_by_label']), isFalse);
  });

  testWidgets('transfer without recipient hides empty To section', (
    tester,
  ) async {
    final transfer = Expense(
      id: expenseId,
      groupId: groupId,
      payerParticipantId: 'p1',
      amountCents: 5000,
      currencyCode: 'USD',
      title: 'Pay back',
      date: now,
      splitType: SplitType.equal,
      splitShares: const {},
      createdAt: now,
      updatedAt: now,
      transactionType: TransactionType.transfer,
      toParticipantId: null,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expensesByGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data([transfer])),
          futureExpenseProvider(
            expenseId,
          ).overrideWithValue(AsyncValue.data(transfer)),
          participantsByGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data(testParticipants)),
          futureGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data(testGroup)),
          tagsByGroupProvider(
            groupId,
          ).overrideWithValue(const AsyncValue.data([])),
          use24HourFormatProvider.overrideWithValue(false),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: const [Locale('en')],
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(
            home: Scaffold(
              body: ExpenseDetailBody(groupId: groupId, expenseId: expenseId),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_hasText(tester, const ['From', 'from']), isTrue);
    expect(_hasText(tester, const ['To', 'to']), isFalse);
  });

  testWidgets('waits for group before showing people sections', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expensesByGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data([testExpense])),
          futureExpenseProvider(
            expenseId,
          ).overrideWithValue(AsyncValue.data(testExpense)),
          participantsByGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data(testParticipants)),
          futureGroupProvider(groupId).overrideWithValue(const AsyncLoading()),
          tagsByGroupProvider(
            groupId,
          ).overrideWithValue(const AsyncValue.data([])),
          use24HourFormatProvider.overrideWithValue(false),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: const [Locale('en')],
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(
            home: Scaffold(
              body: ExpenseDetailBody(groupId: groupId, expenseId: expenseId),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
  });

  testWidgets('personal expense hides who paid and self split', (tester) async {
    final personalGroup = Group(
      id: groupId,
      name: 'Personal',
      currencyCode: 'USD',
      createdAt: now,
      updatedAt: now,
      isPersonal: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expensesByGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data([testExpense])),
          futureExpenseProvider(
            expenseId,
          ).overrideWithValue(AsyncValue.data(testExpense)),
          participantsByGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data(testParticipants)),
          futureGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data(personalGroup)),
          tagsByGroupProvider(
            groupId,
          ).overrideWithValue(const AsyncValue.data([])),
          use24HourFormatProvider.overrideWithValue(false),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: const [Locale('en')],
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(
            home: Scaffold(
              body: ExpenseDetailBody(groupId: groupId, expenseId: expenseId),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsNothing);
    expect(_hasText(tester, const ['Paid By', 'paid_by_label']), isFalse);
    expect(_hasText(tester, const ['Split', 'split']), isFalse);
    expect(find.text('Receipt notes'), findsOneWidget);
  });
}

bool _hasText(WidgetTester tester, List<String> candidates) {
  for (final text in candidates) {
    // Detail body can be taller than the test surface; include offstage text.
    if (find.text(text, skipOffstage: false).evaluate().isNotEmpty) {
      return true;
    }
  }
  return false;
}
