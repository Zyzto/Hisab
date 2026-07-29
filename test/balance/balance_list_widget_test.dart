import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/balance/providers/balance_provider.dart';
import 'package:hisab/features/balance/widgets/balance_list.dart';
import 'package:hisab/features/groups/providers/group_member_provider.dart';
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

  /// Pumps BalanceList with optional member/role overrides. Defaults to owner
  /// so the record-settlement button is enabled (owner can always record).
  Future<void> pumpBalanceList(
    WidgetTester tester, {
    AsyncValue<GroupMember?>? myMemberOverride,
    AsyncValue<GroupRole?>? myRoleOverride,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupBalanceProvider(
            groupId,
          ).overrideWithValue(AsyncValue.data(fakeResult)),
          myMemberInGroupProvider(
            groupId,
          ).overrideWithValue(myMemberOverride ?? const AsyncValue.data(null)),
          myRoleInGroupProvider(groupId).overrideWithValue(
            myRoleOverride ?? const AsyncValue.data(GroupRole.owner),
          ),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: testSupportedLocales,
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(
            home: Scaffold(body: BalanceList(groupId: groupId)),
          ),
        ),
      ),
    );
  }

  testWidgets('BalanceList shows participant names and settlement', (
    tester,
  ) async {
    await pumpBalanceList(tester);
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsAny);
    expect(find.text('Bob'), findsAny);
    // Settlement line: "Bob → Alice" (arrow U+2192)
    expect(find.textContaining('Bob'), findsAny);
    expect(find.textContaining('Alice'), findsAny);
    // 5000 cents = 50.00 (or similar; currency code may be in primary or secondary display)
    expect(find.textContaining('50'), findsAny);
  });

  testWidgets('BalanceList orders balances: most credited first, then most debited first', (
    tester,
  ) async {
    fakeResult = GroupBalanceResult(
      group: Group(
        id: groupId,
        name: 'Ordering Group',
        currencyCode: 'USD',
        createdAt: now,
        updatedAt: now,
      ),
      participants: [
        Participant(
          id: 'p-1',
          groupId: groupId,
          name: 'LargestCreditor',
          order: 0,
          createdAt: now,
          updatedAt: now,
        ),
        Participant(
          id: 'p-2',
          groupId: groupId,
          name: 'SmallDebtor',
          order: 1,
          createdAt: now,
          updatedAt: now,
        ),
        Participant(
          id: 'p-3',
          groupId: groupId,
          name: 'BigDebtor',
          order: 2,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      // Intentionally unsorted input order to verify UI sorting.
      balances: const [
        ParticipantBalance(
          participantId: 'p-3',
          balanceCents: -3000,
          currencyCode: 'USD',
        ),
        ParticipantBalance(
          participantId: 'p-1',
          balanceCents: 7000,
          currencyCode: 'USD',
        ),
        ParticipantBalance(
          participantId: 'p-2',
          balanceCents: -500,
          currencyCode: 'USD',
        ),
      ],
      settlements: const [],
    );

    await pumpBalanceList(tester);
    await tester.pumpAndSettle();

    final allTexts = tester.widgetList<Text>(find.byType(Text)).toList();
    int indexOfExactText(String value) => allTexts.indexWhere(
      (t) => t.data == value,
    );

    final largestCreditorIndex = indexOfExactText('LargestCreditor');
    final smallDebtorIndex = indexOfExactText('SmallDebtor');
    final bigDebtorIndex = indexOfExactText('BigDebtor');

    expect(largestCreditorIndex, greaterThanOrEqualTo(0));
    expect(smallDebtorIndex, greaterThanOrEqualTo(0));
    expect(bigDebtorIndex, greaterThanOrEqualTo(0));

    expect(largestCreditorIndex, lessThan(bigDebtorIndex));
    expect(bigDebtorIndex, lessThan(smallDebtorIndex));
  });

  testWidgets('BalanceList hides participants with zero balance', (
    tester,
  ) async {
    fakeResult = GroupBalanceResult(
      group: Group(
        id: groupId,
        name: 'Zero Balance Group',
        currencyCode: 'USD',
        createdAt: now,
        updatedAt: now,
      ),
      participants: [
        Participant(
          id: 'p-pos',
          groupId: groupId,
          name: 'Creditor',
          order: 0,
          createdAt: now,
          updatedAt: now,
        ),
        Participant(
          id: 'p-zero',
          groupId: groupId,
          name: 'ZeroPerson',
          order: 1,
          createdAt: now,
          updatedAt: now,
        ),
        Participant(
          id: 'p-neg',
          groupId: groupId,
          name: 'Debtor',
          order: 2,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      balances: const [
        ParticipantBalance(
          participantId: 'p-pos',
          balanceCents: 2000,
          currencyCode: 'USD',
        ),
        ParticipantBalance(
          participantId: 'p-zero',
          balanceCents: 0,
          currencyCode: 'USD',
        ),
        ParticipantBalance(
          participantId: 'p-neg',
          balanceCents: -2000,
          currencyCode: 'USD',
        ),
      ],
      settlements: const [],
    );

    await pumpBalanceList(tester);
    await tester.pumpAndSettle();

    expect(find.text('Creditor'), findsOneWidget);
    expect(find.text('Debtor'), findsOneWidget);
    expect(find.text('ZeroPerson'), findsNothing);
  });

  testWidgets('Settlement row handles mixed Arabic and English names', (
    tester,
  ) async {
    fakeResult = GroupBalanceResult(
      group: Group(
        id: groupId,
        name: 'Mixed Script Group',
        currencyCode: 'USD',
        createdAt: now,
        updatedAt: now,
      ),
      participants: [
        Participant(
          id: 'p-ar',
          groupId: groupId,
          name: 'علي',
          order: 0,
          createdAt: now,
          updatedAt: now,
        ),
        Participant(
          id: 'p-en',
          groupId: groupId,
          name: 'Bob',
          order: 1,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      balances: const [
        ParticipantBalance(
          participantId: 'p-ar',
          balanceCents: -2500,
          currencyCode: 'USD',
        ),
        ParticipantBalance(
          participantId: 'p-en',
          balanceCents: 2500,
          currencyCode: 'USD',
        ),
      ],
      settlements: const [
        SettlementTransaction(
          fromParticipantId: 'p-ar',
          toParticipantId: 'p-en',
          amountCents: 2500,
          currencyCode: 'USD',
        ),
      ],
    );

    await pumpBalanceList(tester);
    await tester.pumpAndSettle();

    expect(find.text('علي'), findsAny);
    expect(find.text('Bob'), findsAny);
    expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
  });

  testWidgets('BalanceList shows You Owe hero and excludes self from everyone else', (
    tester,
  ) async {
    final memberAsBob = GroupMember(
      id: 'm1',
      groupId: groupId,
      userId: 'u1',
      role: 'member',
      participantId: 'p-b',
      joinedAt: now,
    );
    await pumpBalanceList(
      tester,
      myMemberOverride: AsyncValue.data(memberAsBob),
      myRoleOverride: const AsyncValue.data(GroupRole.member),
    );
    await tester.pumpAndSettle();

    // EasyLocalization falls back to keys in this widget-test harness.
    expect(find.text('your_balance'), findsOneWidget);
    expect(find.text('you_owe'), findsOneWidget);
    expect(find.text('everyone_else'), findsOneWidget);
    expect(find.text('Alice'), findsWidgets);
    expect(find.text('balance_is_owed'), findsOneWidget);
    // Bob appears in the hero and settlement title, not as an everyone-else card.
    expect(find.text('balance_owes'), findsNothing);
  });

  testWidgets('BalanceList shows You are owed hero for creditor', (
    tester,
  ) async {
    final memberAsAlice = GroupMember(
      id: 'm1',
      groupId: groupId,
      userId: 'u1',
      role: 'member',
      participantId: 'p-a',
      joinedAt: now,
    );
    await pumpBalanceList(
      tester,
      myMemberOverride: AsyncValue.data(memberAsAlice),
      myRoleOverride: const AsyncValue.data(GroupRole.member),
    );
    await tester.pumpAndSettle();

    expect(find.text('you_are_owed'), findsOneWidget);
    expect(find.text('everyone_else'), findsOneWidget);
    expect(find.text('Bob'), findsWidgets);
    expect(find.text('balance_owes'), findsOneWidget);
    expect(find.text('balance_is_owed'), findsNothing);
  });

  testWidgets('BalanceList shows You are even when linked member net is zero', (
    tester,
  ) async {
    fakeResult = GroupBalanceResult(
      group: Group(
        id: groupId,
        name: 'Even Group',
        currencyCode: 'USD',
        createdAt: now,
        updatedAt: now,
      ),
      participants: [
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
        Participant(
          id: 'p-c',
          groupId: groupId,
          name: 'Carol',
          order: 2,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      balances: const [
        ParticipantBalance(
          participantId: 'p-a',
          balanceCents: 0,
          currencyCode: 'USD',
        ),
        ParticipantBalance(
          participantId: 'p-b',
          balanceCents: 3000,
          currencyCode: 'USD',
        ),
        ParticipantBalance(
          participantId: 'p-c',
          balanceCents: -3000,
          currencyCode: 'USD',
        ),
      ],
      settlements: const [
        SettlementTransaction(
          fromParticipantId: 'p-c',
          toParticipantId: 'p-b',
          amountCents: 3000,
          currencyCode: 'USD',
        ),
      ],
    );

    final memberAsAlice = GroupMember(
      id: 'm1',
      groupId: groupId,
      userId: 'u1',
      role: 'owner',
      participantId: 'p-a',
      joinedAt: now,
    );
    await pumpBalanceList(
      tester,
      myMemberOverride: AsyncValue.data(memberAsAlice),
      myRoleOverride: const AsyncValue.data(GroupRole.owner),
    );
    await tester.pumpAndSettle();

    expect(find.text('you_are_even'), findsOneWidget);
    expect(find.text('everyone_else'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsWidgets);
    expect(find.text('Carol'), findsWidgets);
  });

  testWidgets('Settle Up Me filter hides transfers that do not involve me', (
    tester,
  ) async {
    fakeResult = GroupBalanceResult(
      group: Group(
        id: groupId,
        name: 'Filter Group',
        currencyCode: 'USD',
        createdAt: now,
        updatedAt: now,
      ),
      participants: [
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
        Participant(
          id: 'p-c',
          groupId: groupId,
          name: 'Carol',
          order: 2,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      balances: const [
        ParticipantBalance(
          participantId: 'p-a',
          balanceCents: 0,
          currencyCode: 'USD',
        ),
        ParticipantBalance(
          participantId: 'p-b',
          balanceCents: 4000,
          currencyCode: 'USD',
        ),
        ParticipantBalance(
          participantId: 'p-c',
          balanceCents: -4000,
          currencyCode: 'USD',
        ),
      ],
      settlements: const [
        SettlementTransaction(
          fromParticipantId: 'p-c',
          toParticipantId: 'p-b',
          amountCents: 4000,
          currencyCode: 'USD',
        ),
      ],
    );

    final memberAsAlice = GroupMember(
      id: 'm1',
      groupId: groupId,
      userId: 'u1',
      role: 'owner',
      participantId: 'p-a',
      joinedAt: now,
    );
    await pumpBalanceList(
      tester,
      myMemberOverride: AsyncValue.data(memberAsAlice),
      myRoleOverride: const AsyncValue.data(GroupRole.owner),
    );
    await tester.pumpAndSettle();

    // Default Me filter: Carol → Bob does not involve Alice.
    expect(find.text('settle_up_none_for_me'), findsOneWidget);
    expect(find.byIcon(Icons.payments_outlined), findsNothing);

    await tester.tap(find.text('settle_filter_all'));
    await tester.pumpAndSettle();

    expect(find.text('settle_up_none_for_me'), findsNothing);
    expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
    expect(find.text('Carol'), findsWidgets);
  });

  testWidgets('Settle Up sorts you-pay before you-receive before others', (
    tester,
  ) async {
    fakeResult = GroupBalanceResult(
      group: Group(
        id: groupId,
        name: 'Sort Group',
        currencyCode: 'USD',
        createdAt: now,
        updatedAt: now,
      ),
      participants: [
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
        Participant(
          id: 'p-c',
          groupId: groupId,
          name: 'Carol',
          order: 2,
          createdAt: now,
          updatedAt: now,
        ),
        Participant(
          id: 'p-d',
          groupId: groupId,
          name: 'Dave',
          order: 3,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      // Zero nets so names only appear in settle-up rows (plus Alice in hero).
      balances: const [
        ParticipantBalance(
          participantId: 'p-a',
          balanceCents: 0,
          currencyCode: 'USD',
        ),
        ParticipantBalance(
          participantId: 'p-b',
          balanceCents: 0,
          currencyCode: 'USD',
        ),
        ParticipantBalance(
          participantId: 'p-c',
          balanceCents: 0,
          currencyCode: 'USD',
        ),
        ParticipantBalance(
          participantId: 'p-d',
          balanceCents: 0,
          currencyCode: 'USD',
        ),
      ],
      // Intentionally unordered: others, receive, pay.
      settlements: const [
        SettlementTransaction(
          fromParticipantId: 'p-c',
          toParticipantId: 'p-b',
          amountCents: 500,
          currencyCode: 'USD',
        ),
        SettlementTransaction(
          fromParticipantId: 'p-b',
          toParticipantId: 'p-a',
          amountCents: 2000,
          currencyCode: 'USD',
        ),
        SettlementTransaction(
          fromParticipantId: 'p-a',
          toParticipantId: 'p-d',
          amountCents: 1500,
          currencyCode: 'USD',
        ),
      ],
    );

    final memberAsAlice = GroupMember(
      id: 'm1',
      groupId: groupId,
      userId: 'u1',
      role: 'owner',
      participantId: 'p-a',
      joinedAt: now,
    );
    await pumpBalanceList(
      tester,
      myMemberOverride: AsyncValue.data(memberAsAlice),
      myRoleOverride: const AsyncValue.data(GroupRole.owner),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('settle_filter_all'));
    await tester.pumpAndSettle();

    // Names are wrapped in bidi isolates in settle rows.
    String unwrap(String? value) =>
        (value ?? '').replaceAll('\u2068', '').replaceAll('\u2069', '');
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => unwrap(t.data))
        .where((t) => t.isNotEmpty)
        .toList();
    final daveAsPayee = texts.indexOf('Dave');
    // First Bob in settle-up is payer on Bob→Alice (you receive).
    final bobAsPayer = texts.indexOf('Bob');
    final carolIndex = texts.indexOf('Carol');

    // Alice→Dave (you pay) before Bob→Alice (you receive) before Carol→Bob (others).
    expect(daveAsPayee, greaterThanOrEqualTo(0));
    expect(bobAsPayer, greaterThanOrEqualTo(0));
    expect(carolIndex, greaterThanOrEqualTo(0));
    expect(daveAsPayee, lessThan(bobAsPayer));
    expect(bobAsPayer, lessThan(carolIndex));
  });

  testWidgets('BalanceList disables record when not owner and not debtor', (
    tester,
  ) async {
    // User is member (not owner), and their participant is p-a (Alice).
    // Settlement is p-b → p-a (Bob owes Alice). So only owner or Bob can record.
    // As Alice (member), record button should be disabled.
    final memberAsAlice = GroupMember(
      id: 'm1',
      groupId: groupId,
      userId: 'u1',
      role: 'member',
      participantId: 'p-a',
      joinedAt: now,
    );
    await pumpBalanceList(
      tester,
      myMemberOverride: AsyncValue.data(memberAsAlice),
      myRoleOverride: const AsyncValue.data(GroupRole.member),
    );
    await tester.pumpAndSettle();

    // Record payment IconButton should be present but disabled (onPressed == null)
    final paymentButton = find.ancestor(
      of: find.byIcon(Icons.payments_outlined),
      matching: find.byType(IconButton),
    );
    expect(paymentButton.evaluate().isNotEmpty, isTrue);
    final btn = tester.widget<IconButton>(paymentButton.first);
    expect(btn.onPressed, isNull);
  });

  testWidgets('BalanceList disables record when group is archived', (tester) async {
    fakeResult = GroupBalanceResult(
      group: Group(
        id: groupId,
        name: 'Archived Group',
        currencyCode: 'USD',
        createdAt: now,
        updatedAt: now,
        archivedAt: now,
      ),
      participants: fakeResult.participants,
      balances: fakeResult.balances,
      settlements: fakeResult.settlements,
    );

    await pumpBalanceList(tester);
    await tester.pumpAndSettle();

    final paymentButton = find.ancestor(
      of: find.byIcon(Icons.payments_outlined),
      matching: find.byType(IconButton),
    );
    expect(paymentButton.evaluate().isNotEmpty, isTrue);
    final btn = tester.widget<IconButton>(paymentButton.first);
    expect(btn.onPressed, isNull);
  });
}
