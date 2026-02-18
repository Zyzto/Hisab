import 'package:flutter_test/flutter_test.dart';

import 'package:hisab/core/services/settle_up_service.dart';
import 'package:hisab/domain/domain.dart';

void main() {
  late List<Participant> twoParticipants;
  late List<Participant> threeParticipants;
  late DateTime now;

  setUp(() {
    now = DateTime(2025, 1, 15, 12, 0, 0);
    twoParticipants = [
      Participant(
        id: 'p-a',
        groupId: 'g1',
        name: 'Alice',
        order: 0,
        createdAt: now,
        updatedAt: now,
      ),
      Participant(
        id: 'p-b',
        groupId: 'g1',
        name: 'Bob',
        order: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    threeParticipants = [
      ...twoParticipants,
      Participant(
        id: 'p-c',
        groupId: 'g1',
        name: 'Carol',
        order: 2,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  });

  group('computeBalances', () {
    test('two participants one expense payer A equal split: A positive B negative', () {
      // A paid 1000, split equal: A 500, B 500. A balance = 1000 - 500 = 500, B = 0 - 500 = -500.
      final expense = Expense(
        id: 'e1',
        groupId: 'g1',
        payerParticipantId: 'p-a',
        amountCents: 1000,
        currencyCode: 'USD',
        title: 'Lunch',
        date: now,
        splitType: SplitType.equal,
        splitShares: {'p-a': 500, 'p-b': 500},
        createdAt: now,
        updatedAt: now,
      );
      final balances = computeBalances(twoParticipants, [expense], 'USD');
      expect(balances.length, 2);
      final byId = {for (final b in balances) b.participantId: b};
      expect(byId['p-a']!.balanceCents, 500);
      expect(byId['p-b']!.balanceCents, -500);
    });

    test('three participants one expense parts split sum of balances zero', () {
      // Parts 1:1:2 -> 250, 250, 500 for 1000 total. Payer p-a: paid 1000, owed 250 -> 750; p-b 0-250=-250; p-c 0-500=-500.
      final expense = Expense(
        id: 'e1',
        groupId: 'g1',
        payerParticipantId: 'p-a',
        amountCents: 1000,
        currencyCode: 'USD',
        title: 'Dinner',
        date: now,
        splitType: SplitType.parts,
        splitShares: {'p-a': 250, 'p-b': 250, 'p-c': 500},
        createdAt: now,
        updatedAt: now,
      );
      final balances = computeBalances(threeParticipants, [expense], 'USD');
      final sum = balances.fold<int>(0, (s, b) => s + b.balanceCents);
      expect(sum, 0);
      expect(balances.length, 3);
    });

    test('empty expenses all balances zero', () {
      final balances = computeBalances(twoParticipants, [], 'USD');
      expect(balances.length, 2);
      for (final b in balances) {
        expect(b.balanceCents, 0);
      }
    });

    test('multi-currency expense uses baseAmountCents for balance', () {
      // Expense 1000 JPY, baseAmountCents 500. splitShares in JPY sum to 1000; converted to base 250 each.
      final expense = Expense(
        id: 'e1',
        groupId: 'g1',
        payerParticipantId: 'p-a',
        amountCents: 1000,
        currencyCode: 'JPY',
        baseAmountCents: 500,
        exchangeRate: 2.0,
        title: 'Snack',
        date: now,
        splitType: SplitType.equal,
        splitShares: {'p-a': 500, 'p-b': 500},
        createdAt: now,
        updatedAt: now,
      );
      final balances = computeBalances(twoParticipants, [expense], 'USD');
      final byId = {for (final b in balances) b.participantId: b};
      expect(byId['p-a']!.balanceCents, 250);
      expect(byId['p-b']!.balanceCents, -250);
    });
  });

  group('computeSettleUpGreedy', () {
    test('one debtor one creditor single transaction', () {
      final balances = [
        const ParticipantBalance(participantId: 'p-a', balanceCents: 500, currencyCode: 'USD'),
        const ParticipantBalance(participantId: 'p-b', balanceCents: -500, currencyCode: 'USD'),
      ];
      final result = computeSettleUpGreedy(balances, 'USD');
      expect(result.length, 1);
      expect(result.first.fromParticipantId, 'p-b');
      expect(result.first.toParticipantId, 'p-a');
      expect(result.first.amountCents, 500);
    });

    test('two debtors one creditor two transactions creditor receives total', () {
      final balances = [
        const ParticipantBalance(participantId: 'p-a', balanceCents: 600, currencyCode: 'USD'),
        const ParticipantBalance(participantId: 'p-b', balanceCents: -300, currencyCode: 'USD'),
        const ParticipantBalance(participantId: 'p-c', balanceCents: -300, currencyCode: 'USD'),
      ];
      final result = computeSettleUpGreedy(balances, 'USD');
      expect(result.length, 2);
      final toA = result.where((t) => t.toParticipantId == 'p-a').toList();
      expect(toA.length, 2);
      expect(toA.fold<int>(0, (s, t) => s + t.amountCents), 600);
    });

    test('zero balances empty list', () {
      final balances = [
        const ParticipantBalance(participantId: 'p-a', balanceCents: 0, currencyCode: 'USD'),
        const ParticipantBalance(participantId: 'p-b', balanceCents: 0, currencyCode: 'USD'),
      ];
      final result = computeSettleUpGreedy(balances, 'USD');
      expect(result, isEmpty);
    });

    test('multiple creditors debtor total distributed correctly', () {
      final balances = [
        const ParticipantBalance(participantId: 'p-a', balanceCents: 200, currencyCode: 'USD'),
        const ParticipantBalance(participantId: 'p-b', balanceCents: 300, currencyCode: 'USD'),
        const ParticipantBalance(participantId: 'p-c', balanceCents: -500, currencyCode: 'USD'),
      ];
      final result = computeSettleUpGreedy(balances, 'USD');
      expect(result.length, 2);
      final fromC = result.where((t) => t.fromParticipantId == 'p-c').toList();
      expect(fromC.fold<int>(0, (s, t) => s + t.amountCents), 500);
    });
  });

  group('computeSettleUpPairwise', () {
    test('A paid for both B paid nothing one transaction B to A', () {
      // A paid 1000, A and B each owe 500 -> A balance 500, B -500. Pairwise: B owes A 500.
      final expenses = [
        Expense(
          id: 'e1',
          groupId: 'g1',
          payerParticipantId: 'p-a',
          amountCents: 1000,
          currencyCode: 'USD',
          title: 'Lunch',
          date: now,
          splitType: SplitType.equal,
          splitShares: {'p-a': 500, 'p-b': 500},
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final result = computeSettleUpPairwise(twoParticipants, expenses, 'USD');
      expect(result.length, 1);
      expect(result.first.fromParticipantId, 'p-b');
      expect(result.first.toParticipantId, 'p-a');
      expect(result.first.amountCents, 500);
    });

    test('A and B each paid for the other same amount no transactions', () {
      // A paid 100 for B (B owes A 100), B paid 100 for A (A owes B 100). Net zero.
      final expenses = [
        Expense(
          id: 'e1',
          groupId: 'g1',
          payerParticipantId: 'p-a',
          amountCents: 100,
          currencyCode: 'USD',
          title: 'A paid',
          date: now,
          splitType: SplitType.amounts,
          splitShares: {'p-b': 100},
          createdAt: now,
          updatedAt: now,
        ),
        Expense(
          id: 'e2',
          groupId: 'g1',
          payerParticipantId: 'p-b',
          amountCents: 100,
          currencyCode: 'USD',
          title: 'B paid',
          date: now,
          splitType: SplitType.amounts,
          splitShares: {'p-a': 100},
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final result = computeSettleUpPairwise(twoParticipants, expenses, 'USD');
      expect(result, isEmpty);
    });
  });

  group('computeSettleUpTreasurer', () {
    test('debtors pay treasurer creditors receive from treasurer', () {
      final balances = [
        const ParticipantBalance(participantId: 'p-a', balanceCents: 400, currencyCode: 'USD'),
        const ParticipantBalance(participantId: 'p-b', balanceCents: -300, currencyCode: 'USD'),
        const ParticipantBalance(participantId: 'p-c', balanceCents: -100, currencyCode: 'USD'),
      ];
      const treasurerId = 'p-a';
      final result = computeSettleUpTreasurer(balances, 'USD', treasurerId);
      expect(result.length, 2);
      final toTreasurer = result.where((t) => t.toParticipantId == treasurerId).toList();
      // Treasurer is the only creditor, so no fromTreasurer; debtors pay treasurer
      expect(toTreasurer.length, 2);
      expect(toTreasurer.fold<int>(0, (s, t) => s + t.amountCents), 400);
    });

    test('zero balance participants no transaction for them', () {
      final balances = [
        const ParticipantBalance(participantId: 'p-a', balanceCents: 0, currencyCode: 'USD'),
        const ParticipantBalance(participantId: 'p-b', balanceCents: -100, currencyCode: 'USD'),
        const ParticipantBalance(participantId: 'p-c', balanceCents: 100, currencyCode: 'USD'),
      ];
      final result = computeSettleUpTreasurer(balances, 'USD', 'p-c');
      expect(result.length, 1);
      expect(result.first.fromParticipantId, 'p-b');
      expect(result.first.toParticipantId, 'p-c');
      expect(result.first.amountCents, 100);
    });
  });

  group('computeSettleUpConsolidated', () {
    test('one expense two sharers one transaction with correct total', () {
      final expenses = [
        Expense(
          id: 'e1',
          groupId: 'g1',
          payerParticipantId: 'p-a',
          amountCents: 1000,
          currencyCode: 'USD',
          title: 'Dinner',
          date: now,
          splitType: SplitType.equal,
          splitShares: {'p-a': 500, 'p-b': 500},
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final result = computeSettleUpConsolidated(twoParticipants, expenses, 'USD');
      expect(result.length, 1);
      expect(result.first.amountCents, 500);
      expect(result.first.fromParticipantId, 'p-b');
      expect(result.first.toParticipantId, 'p-a');
      expect(result.first.items, isNotNull);
      expect(result.first.items!.length, 1);
      expect(result.first.items!.first.title, 'Dinner');
      expect(result.first.items!.first.amountCents, 500);
    });
  });

  group('computeSettlements', () {
    test('greedy returns list', () {
      final balances = [
        const ParticipantBalance(participantId: 'p-a', balanceCents: 100, currencyCode: 'USD'),
        const ParticipantBalance(participantId: 'p-b', balanceCents: -100, currencyCode: 'USD'),
      ];
      final result = computeSettlements(
        SettlementMethod.greedy,
        balances,
        twoParticipants,
        [],
        'USD',
        null,
      );
      expect(result.length, 1);
      expect(result.first.amountCents, 100);
    });

    test('pairwise returns list', () {
      final expenses = [
        Expense(
          id: 'e1',
          groupId: 'g1',
          payerParticipantId: 'p-a',
          amountCents: 200,
          currencyCode: 'USD',
          title: 'X',
          date: now,
          splitType: SplitType.equal,
          splitShares: {'p-a': 100, 'p-b': 100},
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final balances = computeBalances(twoParticipants, expenses, 'USD');
      final result = computeSettlements(
        SettlementMethod.pairwise,
        balances,
        twoParticipants,
        expenses,
        'USD',
        null,
      );
      expect(result.length, 1);
      expect(result.first.fromParticipantId, 'p-b');
      expect(result.first.toParticipantId, 'p-a');
    });

    test('consolidated returns list', () {
      final expenses = [
        Expense(
          id: 'e1',
          groupId: 'g1',
          payerParticipantId: 'p-a',
          amountCents: 200,
          currencyCode: 'USD',
          title: 'X',
          date: now,
          splitType: SplitType.equal,
          splitShares: {'p-a': 100, 'p-b': 100},
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final balances = computeBalances(twoParticipants, expenses, 'USD');
      final result = computeSettlements(
        SettlementMethod.consolidated,
        balances,
        twoParticipants,
        expenses,
        'USD',
        null,
      );
      expect(result.length, 1);
      expect(result.first.items, isNotNull);
    });

    test('treasurer returns list with treasurer as from or to', () {
      final balances = [
        const ParticipantBalance(participantId: 'p-a', balanceCents: 100, currencyCode: 'USD'),
        const ParticipantBalance(participantId: 'p-b', balanceCents: -100, currencyCode: 'USD'),
      ];
      final result = computeSettlements(
        SettlementMethod.treasurer,
        balances,
        twoParticipants,
        [],
        'USD',
        'p-a',
      );
      expect(result.length, 1);
      expect(result.first.fromParticipantId == 'p-a' || result.first.toParticipantId == 'p-a', true);
    });

    test('treasurer with no participants returns empty', () {
      final result = computeSettlements(
        SettlementMethod.treasurer,
        [],
        [],
        [],
        'USD',
        null,
      );
      expect(result, isEmpty);
    });
  });

  group('createSnapshot', () {
    test('smoke has balances settlements frozenAt', () {
      final group = Group(
        id: 'g1',
        name: 'Trip',
        currencyCode: 'USD',
        createdAt: now,
        updatedAt: now,
      );
      final expense = Expense(
        id: 'e1',
        groupId: 'g1',
        payerParticipantId: 'p-a',
        amountCents: 200,
        currencyCode: 'USD',
        title: 'Lunch',
        date: now,
        splitType: SplitType.equal,
        splitShares: {'p-a': 100, 'p-b': 100},
        createdAt: now,
        updatedAt: now,
      );
      final snapshot = createSnapshot(twoParticipants, [expense], group);
      expect(snapshot.balances, isNotEmpty);
      expect(snapshot.settlements, isNotEmpty);
      expect(snapshot.frozenAt, isNotNull);
    });
  });

  group('computeSettleUp legacy alias', () {
    test('matches computeSettleUpGreedy', () {
      final balances = [
        const ParticipantBalance(participantId: 'p-a', balanceCents: 50, currencyCode: 'EUR'),
        const ParticipantBalance(participantId: 'p-b', balanceCents: -50, currencyCode: 'EUR'),
      ];
      final greedy = computeSettleUpGreedy(balances, 'EUR');
      final legacy = computeSettleUp(balances, 'EUR');
      expect(legacy.length, greedy.length);
      expect(legacy.first.amountCents, greedy.first.amountCents);
    });
  });
}
