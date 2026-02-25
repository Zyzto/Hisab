import 'package:flutter_test/flutter_test.dart';

import 'package:hisab/domain/domain.dart';

void main() {
  group('Expense', () {
    test('effectiveBaseAmountCents returns amountCents when baseAmountCents is null', () {
      final expense = Expense(
        id: 'e1',
        groupId: 'g1',
        payerParticipantId: 'p1',
        amountCents: 3000,
        currencyCode: 'USD',
        title: 'Test',
        date: DateTime(2025, 1, 1),
        splitType: SplitType.equal,
        splitShares: {},
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      expect(expense.effectiveBaseAmountCents, 3000);
    });

    test('effectiveBaseAmountCents returns baseAmountCents when set', () {
      final expense = Expense(
        id: 'e1',
        groupId: 'g1',
        payerParticipantId: 'p1',
        amountCents: 5000,
        currencyCode: 'JPY',
        baseAmountCents: 2500,
        title: 'Test',
        date: DateTime(2025, 1, 1),
        splitType: SplitType.equal,
        splitShares: {},
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      expect(expense.effectiveBaseAmountCents, 2500);
    });
  });

  group('ParticipantBalance', () {
    test('construction holds values', () {
      const b = ParticipantBalance(
        participantId: 'p1',
        balanceCents: -100,
        currencyCode: 'EUR',
      );
      expect(b.participantId, 'p1');
      expect(b.balanceCents, -100);
      expect(b.currencyCode, 'EUR');
    });
  });

  group('SettlementTransaction', () {
    test('fromJson round-trip equals original', () {
      const t = SettlementTransaction(
        fromParticipantId: 'p-a',
        toParticipantId: 'p-b',
        amountCents: 250,
        currencyCode: 'USD',
      );
      final decoded = SettlementTransaction.fromJson(t.toJson());
      expect(decoded.fromParticipantId, t.fromParticipantId);
      expect(decoded.toParticipantId, t.toParticipantId);
      expect(decoded.amountCents, t.amountCents);
      expect(decoded.currencyCode, t.currencyCode);
      expect(decoded.items, isNull);
    });

    test('fromJson round-trip with items', () {
      final t = const SettlementTransaction(
        fromParticipantId: 'p-a',
        toParticipantId: 'p-b',
        amountCents: 100,
        currencyCode: 'USD',
        items: [
          SettlementItem(expenseId: 'e1', title: 'Lunch', amountCents: 100),
        ],
      );
      final decoded = SettlementTransaction.fromJson(t.toJson());
      expect(decoded.items, isNotNull);
      expect(decoded.items!.length, 1);
      expect(decoded.items!.first.expenseId, 'e1');
      expect(decoded.items!.first.title, 'Lunch');
      expect(decoded.items!.first.amountCents, 100);
    });
  });

  group('Group', () {
    test('isSettlementFrozen is true when settlementFreezeAt is not null', () {
      final group = Group(
        id: 'g1',
        name: 'Trip',
        currencyCode: 'USD',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        settlementFreezeAt: DateTime(2025, 1, 15),
      );
      expect(group.isSettlementFrozen, true);
    });

    test('isSettlementFrozen is false when settlementFreezeAt is null', () {
      final group = Group(
        id: 'g1',
        name: 'Trip',
        currencyCode: 'USD',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      expect(group.isSettlementFrozen, false);
    });

    test('isArchived is true when archivedAt is not null', () {
      final group = Group(
        id: 'g1',
        name: 'Trip',
        currencyCode: 'USD',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        archivedAt: DateTime(2025, 2, 1),
      );
      expect(group.isArchived, true);
    });

    test('isArchived is false when archivedAt is null', () {
      final group = Group(
        id: 'g1',
        name: 'Trip',
        currencyCode: 'USD',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      expect(group.isArchived, false);
    });

    test('isPersonal and budgetAmountCents in constructor', () {
      final group = Group(
        id: 'g1',
        name: 'My list',
        currencyCode: 'USD',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        isPersonal: true,
        budgetAmountCents: 10000,
      );
      expect(group.isPersonal, true);
      expect(group.budgetAmountCents, 10000);
    });

    test('copyWith isPersonal and budgetAmountCents', () {
      final group = Group(
        id: 'g1',
        name: 'Trip',
        currencyCode: 'USD',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      final updated = group.copyWith(isPersonal: true, budgetAmountCents: 5000);
      expect(updated.isPersonal, true);
      expect(updated.budgetAmountCents, 5000);
      expect(updated.id, group.id);
    });

    test('copyWith clearBudgetAmountCents clears budget', () {
      final group = Group(
        id: 'g1',
        name: 'My list',
        currencyCode: 'USD',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        isPersonal: true,
        budgetAmountCents: 10000,
      );
      final cleared = group.copyWith(clearBudgetAmountCents: true);
      expect(cleared.budgetAmountCents, isNull);
      expect(cleared.isPersonal, true);
    });
  });
}
