import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/balance/providers/balance_provider.dart';
import 'package:hisab/features/balance/widgets/balance_list.dart';
import '../widget_test_helpers.dart';

void main() {
  const groupId = 'g1';
  final now = DateTime(2025, 1, 15);

  late GroupBalanceResult fakeResult;

  setUpAll(() {
    // Reduce console noise from Easy Localization (same as main.dart).
    EasyLocalization.logger.enableBuildModes = [];
  });

  setUp(() {
    final group = Group(
      id: groupId,
      name: 'Test Trip',
      currencyCode: 'USD',
      createdAt: now,
      updatedAt: now,
    );
    final participants = [
      Participant(
        id: 'p-a',
        groupId: groupId,
        name: 'Alice',
        order: 0,
        createdAt: now,
        updatedAt: now,
      ),
      Participant(
        id: 'p-b',
        groupId: groupId,
        name: 'Bob',
        order: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    final balances = [
      const ParticipantBalance(
        participantId: 'p-a',
        balanceCents: 5000,
        currencyCode: 'USD',
      ),
      const ParticipantBalance(
        participantId: 'p-b',
        balanceCents: -5000,
        currencyCode: 'USD',
      ),
    ];
    final settlements = [
      const SettlementTransaction(
        fromParticipantId: 'p-b',
        toParticipantId: 'p-a',
        amountCents: 5000,
        currencyCode: 'USD',
      ),
    ];
    fakeResult = GroupBalanceResult(
      group: group,
      participants: participants,
      balances: balances,
      settlements: settlements,
    );
  });

  Future<void> pumpBalanceList(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupBalanceProvider(groupId).overrideWithValue(
            AsyncValue.data(fakeResult),
          ),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: testSupportedLocales,
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(
            home: Scaffold(
              body: BalanceList(groupId: groupId),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('BalanceList shows participant names and settlement', (tester) async {
    await pumpBalanceList(tester);
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsAny);
    expect(find.text('Bob'), findsAny);
    // Settlement line: "Bob → Alice" (arrow U+2192)
    expect(find.textContaining('Bob'), findsAny);
    expect(find.textContaining('Alice'), findsAny);
    // 5000 cents = 50.00 USD (or similar)
    expect(find.textContaining('50'), findsAny);
    expect(find.textContaining('USD'), findsAny);
  });
}
