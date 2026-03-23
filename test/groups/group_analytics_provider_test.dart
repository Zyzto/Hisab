import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/groups/providers/group_analytics_provider.dart';

void main() {
  const groupId = 'g1';
  final now = DateTime(2026, 3, 20, 12);

  Group makeGroup() => Group(
    id: groupId,
    name: 'Trip',
    currencyCode: 'USD',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  List<Participant> makeParticipants() => [
    Participant(
      id: 'p1',
      groupId: groupId,
      name: 'Ali',
      order: 0,
      createdAt: now,
      updatedAt: now,
    ),
    Participant(
      id: 'p2',
      groupId: groupId,
      name: 'Sara',
      order: 1,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  List<ExpenseTag> makeTags() => [
    ExpenseTag(
      id: 't1',
      groupId: groupId,
      label: 'Coffee',
      iconName: 'coffee',
      createdAt: now,
      updatedAt: now,
    ),
  ];

  List<Expense> makeExpenses() => [
    Expense(
      id: 'e1',
      groupId: groupId,
      payerParticipantId: 'p1',
      amountCents: 1200,
      currencyCode: 'USD',
      title: 'Coffee',
      date: DateTime(2026, 3, 19),
      splitType: SplitType.equal,
      splitShares: const {},
      createdAt: now,
      updatedAt: now,
      tag: 't1',
    ),
    Expense(
      id: 'e2',
      groupId: groupId,
      payerParticipantId: 'p2',
      amountCents: 2400,
      currencyCode: 'USD',
      title: 'Groceries',
      date: DateTime(2026, 3, 18),
      splitType: SplitType.equal,
      splitShares: const {},
      createdAt: now,
      updatedAt: now,
      tag: 'groceries',
    ),
    Expense(
      id: 'e3',
      groupId: groupId,
      payerParticipantId: 'p2',
      amountCents: 500,
      currencyCode: 'USD',
      title: 'Transfer',
      date: DateTime(2026, 3, 17),
      splitType: SplitType.equal,
      splitShares: const {},
      createdAt: now,
      updatedAt: now,
      transactionType: TransactionType.transfer,
    ),
  ];

  test('computes totals and excludes transfers', () {
    final result = computeGroupAnalytics(
      group: makeGroup(),
      participants: makeParticipants(),
      tags: makeTags(),
      expenses: makeExpenses(),
      query: const GroupAnalyticsQuery(groupId: groupId),
      currentUserParticipantId: 'p1',
      now: now,
    );

    expect(result.transactionCount, 2);
    expect(result.totalAmountCents, 3600);
    expect(result.myAmountCents, 1200);
    expect(result.byParticipant.first.id, 'p2');
    expect(result.byTag.first.label, 'Groceries');
  });

  test('applies participant and tag filters', () {
    final result = computeGroupAnalytics(
      group: makeGroup(),
      participants: makeParticipants(),
      tags: makeTags(),
      expenses: makeExpenses(),
      query: const GroupAnalyticsQuery(
        groupId: groupId,
        participantId: 'p1',
        tagId: 't1',
      ),
      currentUserParticipantId: 'p1',
      now: now,
    );

    expect(result.transactionCount, 1);
    expect(result.totalAmountCents, 1200);
    expect(result.byParticipant.single.label, 'Ali');
    expect(result.byTag.single.label, 'Coffee');
  });

  test('builds expected trend bucket counts by range', () {
    final group = makeGroup();
    final participants = makeParticipants();
    final tags = makeTags();
    final expenses = makeExpenses();

    final d30 = computeGroupAnalytics(
      group: group,
      participants: participants,
      tags: tags,
      expenses: expenses,
      query: const GroupAnalyticsQuery(
        groupId: groupId,
        range: AnalyticsRangePreset.days30,
      ),
      currentUserParticipantId: 'p1',
      now: now,
    );
    final d90 = computeGroupAnalytics(
      group: group,
      participants: participants,
      tags: tags,
      expenses: expenses,
      query: const GroupAnalyticsQuery(
        groupId: groupId,
        range: AnalyticsRangePreset.days90,
      ),
      currentUserParticipantId: 'p1',
      now: now,
    );
    final all = computeGroupAnalytics(
      group: group,
      participants: participants,
      tags: tags,
      expenses: expenses,
      query: const GroupAnalyticsQuery(
        groupId: groupId,
        range: AnalyticsRangePreset.all,
      ),
      currentUserParticipantId: 'p1',
      now: now,
    );

    expect(d30.trendPoints.length, 30);
    expect(d30.trendGranularity, TrendGranularity.daily);
    expect(d90.trendPoints.length, 13);
    expect(d90.trendGranularity, TrendGranularity.weekly);
    expect(all.trendPoints.length, greaterThan(1));
    expect(all.trendGranularity, TrendGranularity.daily);
    expect(all.participantTrendSeries, isNotEmpty);
    expect(all.categoryTrendSeries, isNotEmpty);
  });

  test('all-time uses monthly buckets for long spans', () {
    final longSpanExpenses = [
      Expense(
        id: 'old',
        groupId: groupId,
        payerParticipantId: 'p1',
        amountCents: 1000,
        currencyCode: 'USD',
        title: 'Old',
        date: DateTime(2025, 1, 2),
        splitType: SplitType.equal,
        splitShares: const {},
        createdAt: now,
        updatedAt: now,
        tag: 't1',
      ),
      ...makeExpenses(),
    ];
    final all = computeGroupAnalytics(
      group: makeGroup(),
      participants: makeParticipants(),
      tags: makeTags(),
      expenses: longSpanExpenses,
      query: const GroupAnalyticsQuery(
        groupId: groupId,
        range: AnalyticsRangePreset.all,
      ),
      currentUserParticipantId: 'p1',
      now: now,
    );

    expect(all.trendGranularity, TrendGranularity.monthly);
    expect(all.trendPoints.length, lessThanOrEqualTo(24));
  });
}
