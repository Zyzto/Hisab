import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/expenses/widgets/expense_detail_body.dart';
import 'package:hisab/features/groups/providers/groups_provider.dart';
import 'package:hisab/features/settings/providers/settings_framework_providers.dart';

void main() {
  final now = DateTime(2025, 1, 15);
  const groupId = 'g1';
  const expenseId = 'e1';
  late Expense testExpense;
  late List<Participant> testParticipants;

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
      date: now,
      splitType: SplitType.equal,
      splitShares: const {},
      createdAt: now,
      updatedAt: now,
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
  });

  testWidgets('ExpenseDetailBody shows header and section labels', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          futureExpenseProvider(expenseId).overrideWithValue(AsyncValue.data(testExpense)),
          participantsByGroupProvider(groupId).overrideWithValue(AsyncValue.data(testParticipants)),
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
  });
}
