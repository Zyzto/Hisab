import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/expenses/pages/expense_detail_shell.dart';
import 'package:hisab/features/expenses/widgets/expense_detail_body.dart';
import 'package:hisab/features/groups/providers/groups_provider.dart';
import 'package:hisab/core/settings/providers/settings_framework_providers.dart';

void main() {
  final now = DateTime(2025, 1, 15);
  const groupId = 'g1';

  late Group testGroup;
  late List<Participant> participants;
  late Expense newer;
  late Expense older;

  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  setUp(() {
    testGroup = Group(
      id: groupId,
      name: 'Trip',
      currencyCode: 'USD',
      createdAt: now,
      updatedAt: now,
      isPersonal: false,
    );
    participants = [
      Participant(
        id: 'p1',
        groupId: groupId,
        name: 'Alice',
        order: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    newer = Expense(
      id: 'e-new',
      groupId: groupId,
      payerParticipantId: 'p1',
      amountCents: 1000,
      currencyCode: 'USD',
      title: 'Newer expense',
      date: now,
      splitType: SplitType.equal,
      splitShares: const {'p1': 1000},
      createdAt: now,
      updatedAt: now,
    );
    older = Expense(
      id: 'e-old',
      groupId: groupId,
      payerParticipantId: 'p1',
      amountCents: 2000,
      currencyCode: 'USD',
      title: 'Older expense',
      date: now.subtract(const Duration(days: 1)),
      splitType: SplitType.equal,
      splitShares: const {'p1': 2000},
      createdAt: now,
      updatedAt: now,
    );
  });

  Future<void> pumpShell(WidgetTester tester, {required String openId}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Bodies resolve from the group list (shared watch) — no need for
          // per-id futureExpense overrides when the list is present.
          expensesByGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data([newer, older])),
          participantsByGroupProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data(participants)),
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
          child: MaterialApp(
            home: ExpenseDetailShell(
              groupId: groupId,
              expenseId: openId,
              child: ExpenseDetailBody(groupId: groupId, expenseId: openId),
            ),
          ),
        ),
      ),
    );
    // Enter animation + first frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('shows interactive PageView with adjacent expense on drag', (
    tester,
  ) async {
    await pumpShell(tester, openId: newer.id);

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Newer expense'), findsWidgets);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Older expense'), findsWidgets);
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('app bar next chevron pages to older expense', (tester) async {
    await pumpShell(tester, openId: newer.id);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('Older expense'), findsWidgets);
  });
}
