import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/groups/providers/group_analytics_provider.dart';
import 'package:hisab/features/profile/providers/profile_my_expenses_provider.dart';

void main() {
  final now = DateTime(2026, 7, 29, 12);

  Group group(String id, String name) => Group(
    id: id,
    name: name,
    currencyCode: 'USD',
    createdAt: now,
    updatedAt: now,
  );

  Expense expense({
    required String id,
    required String groupId,
    required String title,
    required DateTime date,
    required Map<String, int> shares,
    String payer = 'p-me',
    TransactionType type = TransactionType.expense,
    String? tag,
  }) {
    return Expense(
      id: id,
      groupId: groupId,
      payerParticipantId: payer,
      amountCents: shares.values.fold(0, (a, b) => a + b),
      currencyCode: 'USD',
      title: title,
      date: date,
      splitType: SplitType.equal,
      splitShares: shares,
      createdAt: now,
      updatedAt: now,
      transactionType: type,
      tag: tag,
    );
  }

  ProfileExpenseItem item({
    required Expense e,
    required Group g,
    required int share,
    bool iPaid = true,
    String payerName = 'Me',
  }) {
    return ProfileExpenseItem(
      expense: e,
      group: g,
      myShareCents: share,
      payerName: payerName,
      iPaid: iPaid,
    );
  }

  test('search matches title group and payer', () {
    final g1 = group('g1', 'Trip');
    final g2 = group('g2', 'Home');
    final items = [
      item(
        e: expense(
          id: 'e1',
          groupId: 'g1',
          title: 'Dinner',
          date: now,
          shares: {'p-me': 500},
        ),
        g: g1,
        share: 500,
      ),
      item(
        e: expense(
          id: 'e2',
          groupId: 'g2',
          title: 'Rent',
          date: now.subtract(const Duration(days: 1)),
          shares: {'p-me': 1000},
          payer: 'p-other',
        ),
        g: g2,
        share: 1000,
        iPaid: false,
        payerName: 'Alex',
      ),
    ];

    expect(
      applyProfileExpensesFilter(
        items,
        const ProfileExpensesFilter(query: 'trip'),
      ).map((e) => e.expense.id),
      ['e1'],
    );
    expect(
      applyProfileExpensesFilter(
        items,
        const ProfileExpensesFilter(query: 'alex'),
      ).map((e) => e.expense.id),
      ['e2'],
    );
  });

  test('paid by and type filters', () {
    final g = group('g1', 'Trip');
    final items = [
      item(
        e: expense(
          id: 'e1',
          groupId: 'g1',
          title: 'A',
          date: now,
          shares: {'p-me': 100},
        ),
        g: g,
        share: 100,
      ),
      item(
        e: expense(
          id: 'e2',
          groupId: 'g1',
          title: 'B',
          date: now,
          shares: {'p-me': 200},
          payer: 'p-other',
          type: TransactionType.income,
        ),
        g: g,
        share: 200,
        iPaid: false,
      ),
    ];

    expect(
      applyProfileExpensesFilter(
        items,
        const ProfileExpensesFilter(paidBy: ProfileExpensePaidFilter.me),
      ).single.expense.id,
      'e1',
    );
    expect(
      applyProfileExpensesFilter(
        items,
        const ProfileExpensesFilter(type: ProfileExpenseTypeFilter.income),
      ).single.expense.id,
      'e2',
    );
  });

  test('sort by share high', () {
    final g = group('g1', 'Trip');
    final items = [
      item(
        e: expense(
          id: 'e1',
          groupId: 'g1',
          title: 'A',
          date: now,
          shares: {'p-me': 100},
        ),
        g: g,
        share: 100,
      ),
      item(
        e: expense(
          id: 'e2',
          groupId: 'g1',
          title: 'B',
          date: now.subtract(const Duration(days: 1)),
          shares: {'p-me': 900},
        ),
        g: g,
        share: 900,
      ),
    ];

    final sorted = applyProfileExpensesFilter(
      items,
      const ProfileExpensesFilter(sort: ProfileExpenseSort.shareHigh),
    );
    expect(sorted.map((e) => e.expense.id).toList(), ['e2', 'e1']);
  });

  test('range filter keeps recent only', () {
    final g = group('g1', 'Trip');
    final items = [
      item(
        e: expense(
          id: 'recent',
          groupId: 'g1',
          title: 'Recent',
          date: now,
          shares: {'p-me': 100},
        ),
        g: g,
        share: 100,
      ),
      item(
        e: expense(
          id: 'old',
          groupId: 'g1',
          title: 'Old',
          date: now.subtract(const Duration(days: 60)),
          shares: {'p-me': 100},
        ),
        g: g,
        share: 100,
      ),
    ];

    final filtered = applyProfileExpensesFilter(
      items,
      const ProfileExpensesFilter(range: AnalyticsRangePreset.days30),
    );
    expect(filtered.map((e) => e.expense.id).toList(), ['recent']);
  });
}
