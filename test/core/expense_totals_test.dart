import 'package:flutter_test/flutter_test.dart';

import 'package:hisab/core/utils/expense_totals.dart';
import 'package:hisab/domain/domain.dart';

void main() {
  final now = DateTime(2025, 1, 15);

  Expense expense({
    required TransactionType transactionType,
    int amountCents = 1000,
    int? baseAmountCents,
  }) {
    return Expense(
      id: 'e1',
      groupId: 'g1',
      payerParticipantId: 'p1',
      amountCents: amountCents,
      currencyCode: 'USD',
      baseAmountCents: baseAmountCents,
      title: 'Test',
      date: now,
      splitType: SplitType.equal,
      splitShares: const {},
      createdAt: now,
      updatedAt: now,
      transactionType: transactionType,
    );
  }

  group('contributionToExpenseTotal', () {
    test('expense type returns positive amount', () {
      final e = expense(transactionType: TransactionType.expense, amountCents: 5000);
      expect(contributionToExpenseTotal(e), 5000);
    });

    test('income type returns negative amount', () {
      final e = expense(transactionType: TransactionType.income, amountCents: 3000);
      expect(contributionToExpenseTotal(e), -3000);
    });

    test('transfer type returns zero', () {
      final e = expense(transactionType: TransactionType.transfer, amountCents: 2000);
      expect(contributionToExpenseTotal(e), 0);
    });

    test('expense uses effectiveBaseAmountCents when baseAmountCents set', () {
      final e = expense(
        transactionType: TransactionType.expense,
        amountCents: 5000,
        baseAmountCents: 2500,
      );
      expect(contributionToExpenseTotal(e), 2500);
    });

    test('income uses effectiveBaseAmountCents when baseAmountCents set', () {
      final e = expense(
        transactionType: TransactionType.income,
        amountCents: 5000,
        baseAmountCents: 2500,
      );
      expect(contributionToExpenseTotal(e), -2500);
    });

    test('sum of mixed types gives net spending', () {
      final list = [
        expense(transactionType: TransactionType.expense, amountCents: 10000),
        expense(transactionType: TransactionType.income, amountCents: 3000),
        expense(transactionType: TransactionType.transfer, amountCents: 2000),
        expense(transactionType: TransactionType.expense, amountCents: 500),
      ];
      final total = list.fold<int>(0, (s, e) => s + contributionToExpenseTotal(e));
      expect(total, 10000 - 3000 + 0 + 500); // 7500
    });
  });
}
