import '../../domain/domain.dart';

/// Contribution of an expense to the "total expenses" / "net spending" display.
/// - [TransactionType.expense]: +amount (spending).
/// - [TransactionType.income]: −amount (offsets spending).
/// - [TransactionType.transfer]: 0 (money moving inside the group).
int contributionToExpenseTotal(Expense e) {
  switch (e.transactionType) {
    case TransactionType.expense:
      return e.effectiveBaseAmountCents;
    case TransactionType.income:
      return -e.effectiveBaseAmountCents;
    case TransactionType.transfer:
      return 0;
  }
}
