import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/domain/group.dart';
import 'package:hisab/features/profile/providers/profile_dashboard_provider.dart';

Group _personal({int? budgetCents}) {
  final now = DateTime.utc(2026, 1, 1);
  return Group(
    id: 'p1',
    name: 'Personal',
    currencyCode: 'USD',
    createdAt: now,
    updatedAt: now,
    isPersonal: true,
    budgetAmountCents: budgetCents,
  );
}

void main() {
  group('ProfilePersonalBudgetRow', () {
    test('hasBudget / progress / near / over thresholds', () {
      final group = _personal(budgetCents: 10000);
      expect(
        ProfilePersonalBudgetRow(
          group: group,
          spentCents: 0,
          budgetCents: 10000,
        ).hasBudget,
        isTrue,
      );
      expect(
        ProfilePersonalBudgetRow(
          group: group,
          spentCents: 5000,
          budgetCents: 10000,
        ).progress,
        0.5,
      );
      expect(
        ProfilePersonalBudgetRow(
          group: group,
          spentCents: 8000,
          budgetCents: 10000,
        ).nearBudget,
        isTrue,
      );
      expect(
        ProfilePersonalBudgetRow(
          group: group,
          spentCents: 10000,
          budgetCents: 10000,
        ).overBudget,
        isTrue,
      );
      expect(
        ProfilePersonalBudgetRow(
          group: group,
          spentCents: 12000,
          budgetCents: 10000,
        ).progress,
        1.2,
      );
    });

    test('no budget means not near/over', () {
      final group = _personal();
      final row = ProfilePersonalBudgetRow(group: group, spentCents: 999);
      expect(row.hasBudget, isFalse);
      expect(row.nearBudget, isFalse);
      expect(row.overBudget, isFalse);
      expect(row.progress, 0.0);
    });
  });

  group('ProfileBalanceRow', () {
    test('youOwe / owesYou from signed balance', () {
      final now = DateTime.utc(2026, 1, 1);
      final group = Group(
        id: 'g1',
        name: 'Trip',
        currencyCode: 'EUR',
        createdAt: now,
        updatedAt: now,
      );
      expect(
        ProfileBalanceRow(
          group: group,
          balanceCents: -500,
          currencyCode: 'EUR',
        ).youOwe,
        isTrue,
      );
      expect(
        ProfileBalanceRow(
          group: group,
          balanceCents: 250,
          currencyCode: 'EUR',
        ).owesYou,
        isTrue,
      );
    });
  });
}
