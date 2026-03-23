import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/expense_totals.dart';
import '../../../domain/domain.dart';
import '../../expenses/category_icons.dart';
import 'group_member_provider.dart';
import 'groups_provider.dart';

enum AnalyticsRangePreset { days30, days90, all }
enum TrendGranularity { daily, weekly, monthly }

class GroupAnalyticsQuery {
  const GroupAnalyticsQuery({
    required this.groupId,
    this.range = AnalyticsRangePreset.days90,
    this.participantId,
    this.tagId,
  });

  final String groupId;
  final AnalyticsRangePreset range;
  final String? participantId;
  final String? tagId;

  GroupAnalyticsQuery copyWith({
    String? groupId,
    AnalyticsRangePreset? range,
    String? participantId,
    String? tagId,
    bool clearParticipant = false,
    bool clearTag = false,
  }) {
    return GroupAnalyticsQuery(
      groupId: groupId ?? this.groupId,
      range: range ?? this.range,
      participantId: clearParticipant ? null : (participantId ?? this.participantId),
      tagId: clearTag ? null : (tagId ?? this.tagId),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GroupAnalyticsQuery &&
        other.groupId == groupId &&
        other.range == range &&
        other.participantId == participantId &&
        other.tagId == tagId;
  }

  @override
  int get hashCode => Object.hash(groupId, range, participantId, tagId);
}

class TrendPoint {
  const TrendPoint({
    required this.start,
    required this.end,
    required this.amountCents,
    required this.count,
  });

  final DateTime start;
  final DateTime end;
  final int amountCents;
  final int count;
}

class TrendSeries {
  const TrendSeries({required this.id, required this.label, required this.points});

  final String id;
  final String label;
  final List<TrendPoint> points;
}

class TrendWindow {
  const TrendWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class TrendBuildResult {
  const TrendBuildResult({required this.granularity, required this.points, required this.windows});

  final TrendGranularity granularity;
  final List<TrendPoint> points;
  final List<TrendWindow> windows;
}

class AmountBreakdownItem {
  const AmountBreakdownItem({
    required this.id,
    required this.label,
    required this.amountCents,
    required this.count,
  });

  final String id;
  final String label;
  final int amountCents;
  final int count;
}

class GroupAnalyticsData {
  const GroupAnalyticsData({
    required this.group,
    required this.participants,
    required this.tags,
    required this.filteredExpenses,
    required this.totalAmountCents,
    required this.myAmountCents,
    required this.averagePerDayCents,
    required this.transactionCount,
    required this.trendGranularity,
    required this.trendPoints,
    required this.participantTrendSeries,
    required this.categoryTrendSeries,
    required this.byTag,
    required this.byParticipant,
  });

  final Group group;
  final List<Participant> participants;
  final List<ExpenseTag> tags;
  final List<Expense> filteredExpenses;
  final int totalAmountCents;
  final int myAmountCents;
  final int averagePerDayCents;
  final int transactionCount;
  final TrendGranularity trendGranularity;
  final List<TrendPoint> trendPoints;
  final List<TrendSeries> participantTrendSeries;
  final List<TrendSeries> categoryTrendSeries;
  final List<AmountBreakdownItem> byTag;
  final List<AmountBreakdownItem> byParticipant;
}

final groupAnalyticsDataProvider =
    Provider.family<AsyncValue<GroupAnalyticsData?>, GroupAnalyticsQuery>((
      ref,
      query,
    ) {
      final groupAsync = ref.watch(futureGroupProvider(query.groupId));
      final participantsAsync = ref.watch(participantsByGroupProvider(query.groupId));
      final expensesAsync = ref.watch(expensesByGroupProvider(query.groupId));
      final tagsAsync = ref.watch(tagsByGroupProvider(query.groupId));
      final myMemberAsync = ref.watch(myMemberInGroupProvider(query.groupId));

      return groupAsync.when(
        data: (group) {
          if (group == null) return const AsyncValue.data(null);
          return participantsAsync.when(
            data: (participants) {
              return expensesAsync.when(
                data: (expenses) {
                  return tagsAsync.when(
                    data: (tags) {
                      return myMemberAsync.when(
                        data: (myMember) {
                          return AsyncValue.data(
                            computeGroupAnalytics(
                              group: group,
                              participants: participants,
                              tags: tags,
                              expenses: expenses,
                              query: query,
                              currentUserParticipantId: myMember?.participantId,
                            ),
                          );
                        },
                        loading: () => const AsyncValue.loading(),
                        error: (e, s) => AsyncValue.error(e, s),
                      );
                    },
                    loading: () => const AsyncValue.loading(),
                    error: (e, s) => AsyncValue.error(e, s),
                  );
                },
                loading: () => const AsyncValue.loading(),
                error: (e, s) => AsyncValue.error(e, s),
              );
            },
            loading: () => const AsyncValue.loading(),
            error: (e, s) => AsyncValue.error(e, s),
          );
        },
        loading: () => const AsyncValue.loading(),
        error: (e, s) => AsyncValue.error(e, s),
      );
    });

GroupAnalyticsData computeGroupAnalytics({
  required Group group,
  required List<Participant> participants,
  required List<ExpenseTag> tags,
  required List<Expense> expenses,
  required GroupAnalyticsQuery query,
  required String? currentUserParticipantId,
  DateTime? now,
}) {
  final localNow = now ?? DateTime.now();
  final rangeStart = _rangeStart(query.range, localNow);

  final filtered = expenses.where((expense) {
    if (_isTransferOnly(expense)) return false;

    final localDate = expense.date.isUtc ? expense.date.toLocal() : expense.date;
    if (rangeStart != null && localDate.isBefore(rangeStart)) return false;
    if (query.participantId != null && query.participantId!.isNotEmpty) {
      if (expense.payerParticipantId != query.participantId) return false;
    }
    if (query.tagId != null && query.tagId!.isNotEmpty) {
      if (expense.tag != query.tagId) return false;
    }
    return true;
  }).toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  int totalCents = 0;
  int myCents = 0;
  for (final expense in filtered) {
    final contribution = contributionToExpenseTotal(expense);
    totalCents += contribution;
    if (currentUserParticipantId != null &&
        expense.payerParticipantId == currentUserParticipantId) {
      myCents += contribution;
    }
  }

  final averagePerDay = filtered.isEmpty
      ? 0
      : (totalCents / _effectiveDays(filtered, rangeStart, localNow)).round();
  final trend = _buildTrendPoints(filtered, query.range, localNow);

  return GroupAnalyticsData(
    group: group,
    participants: participants,
    tags: tags,
    filteredExpenses: filtered,
    totalAmountCents: totalCents,
    myAmountCents: myCents,
    averagePerDayCents: averagePerDay,
    transactionCount: filtered.length,
    trendGranularity: trend.granularity,
    trendPoints: trend.points,
    participantTrendSeries: _buildParticipantTrendSeries(
      filtered,
      participants,
      trend.windows,
    ),
    categoryTrendSeries: _buildCategoryTrendSeries(filtered, tags, trend.windows),
    byTag: _buildTagBreakdown(filtered, tags),
    byParticipant: _buildParticipantBreakdown(filtered, participants),
  );
}

String resolveTagLabel(String tagId, List<ExpenseTag> tags) {
  for (final custom in tags) {
    if (custom.id == tagId) return custom.label;
  }
  for (final preset in presetCategoryTags) {
    if (preset.id == tagId) return preset.label;
  }
  return tagId;
}

bool _isTransferOnly(Expense expense) =>
    contributionToExpenseTotal(expense) == 0;

DateTime? _rangeStart(AnalyticsRangePreset range, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  switch (range) {
    case AnalyticsRangePreset.days30:
      return today.subtract(const Duration(days: 29));
    case AnalyticsRangePreset.days90:
      return today.subtract(const Duration(days: 89));
    case AnalyticsRangePreset.all:
      return null;
  }
}

int _effectiveDays(List<Expense> filtered, DateTime? rangeStart, DateTime now) {
  if (filtered.isEmpty) return 1;
  final localNow = DateTime(now.year, now.month, now.day);
  if (rangeStart != null) {
    return localNow.difference(rangeStart).inDays + 1;
  }
  final first = filtered.first.date;
  final firstDay = DateTime(first.year, first.month, first.day);
  return localNow.difference(firstDay).inDays + 1;
}

const _maxComparisonSeries = 4;

TrendBuildResult _buildTrendPoints(
  List<Expense> expenses,
  AnalyticsRangePreset range,
  DateTime now,
) {
  final DateTime localNow = DateTime(now.year, now.month, now.day);
  late final TrendGranularity granularity;
  late List<TrendWindow> windows;
  switch (range) {
    case AnalyticsRangePreset.days30:
      granularity = TrendGranularity.daily;
      windows = _buildDailyWindows(
        localNow.subtract(const Duration(days: 29)),
        localNow,
      );
      break;
    case AnalyticsRangePreset.days90:
      granularity = TrendGranularity.weekly;
      windows = _buildWeeklyWindows(
        localNow.subtract(const Duration(days: 90 - 1)),
        localNow,
      );
      break;
    case AnalyticsRangePreset.all:
      if (expenses.isEmpty) {
        granularity = TrendGranularity.monthly;
        windows = _buildMonthlyWindows(localNow, localNow);
      } else {
        DateTime firstDay = DateTime(
          localNow.year,
          localNow.month,
          localNow.day,
        );
        DateTime lastDay = firstDay;
        for (final expense in expenses) {
          final date = expense.date.isUtc ? expense.date.toLocal() : expense.date;
          final day = DateTime(date.year, date.month, date.day);
          if (day.isBefore(firstDay)) firstDay = day;
          if (day.isAfter(lastDay)) lastDay = day;
        }
        final spanDays = lastDay.difference(firstDay).inDays + 1;

        if (spanDays <= 45) {
          granularity = TrendGranularity.daily;
          windows = _buildDailyWindows(firstDay, lastDay);
        } else if (spanDays <= 180) {
          granularity = TrendGranularity.weekly;
          windows = _buildWeeklyWindows(firstDay, lastDay);
        } else {
          granularity = TrendGranularity.monthly;
          windows = _buildMonthlyWindows(firstDay, lastDay);
        }

      }
      break;
  }
  final points = windows
      .map((window) => _bucket(expenses, window.start, window.end))
      .toList();

  if (range == AnalyticsRangePreset.all && points.isNotEmpty) {
    int firstNonEmpty = 0;
    while (firstNonEmpty < points.length && points[firstNonEmpty].count == 0) {
      firstNonEmpty += 1;
    }

    int lastNonEmpty = points.length - 1;
    while (lastNonEmpty >= 0 && points[lastNonEmpty].count == 0) {
      lastNonEmpty -= 1;
    }

    if (firstNonEmpty <= lastNonEmpty &&
        (firstNonEmpty > 0 || lastNonEmpty < points.length - 1)) {
      windows = windows.sublist(firstNonEmpty, lastNonEmpty + 1);
      points
        ..clear()
        ..addAll(
          windows.map((window) => _bucket(expenses, window.start, window.end)),
        );
    }
  }

  return TrendBuildResult(granularity: granularity, points: points, windows: windows);
}

List<TrendWindow> _buildDailyWindows(DateTime startDay, DateTime endDayInclusive) {
  final start = DateTime(startDay.year, startDay.month, startDay.day);
  final end = DateTime(
    endDayInclusive.year,
    endDayInclusive.month,
    endDayInclusive.day,
  );
  final windows = <TrendWindow>[];
  DateTime cursor = start;
  while (!cursor.isAfter(end)) {
    final next = cursor.add(const Duration(days: 1));
    windows.add(TrendWindow(start: cursor, end: next));
    cursor = next;
  }
  return windows;
}

List<TrendWindow> _buildWeeklyWindows(DateTime startDay, DateTime endDayInclusive) {
  final start = DateTime(startDay.year, startDay.month, startDay.day);
  final endExclusive = DateTime(
    endDayInclusive.year,
    endDayInclusive.month,
    endDayInclusive.day,
  ).add(const Duration(days: 1));
  final windows = <TrendWindow>[];
  DateTime cursor = start;
  while (cursor.isBefore(endExclusive)) {
    DateTime next = cursor.add(const Duration(days: 7));
    if (next.isAfter(endExclusive)) next = endExclusive;
    windows.add(TrendWindow(start: cursor, end: next));
    cursor = next;
  }
  return windows;
}

List<TrendWindow> _buildMonthlyWindows(DateTime startDay, DateTime endDayInclusive) {
  final start = DateTime(startDay.year, startDay.month, 1);
  final end = DateTime(endDayInclusive.year, endDayInclusive.month, 1);
  final windows = <TrendWindow>[];
  DateTime cursor = start;
  while (!cursor.isAfter(end)) {
    final next = DateTime(cursor.year, cursor.month + 1, 1);
    windows.add(TrendWindow(start: cursor, end: next));
    cursor = next;
  }
  return windows;
}

TrendPoint _bucket(
  List<Expense> expenses,
  DateTime start,
  DateTime end, {
  bool Function(Expense expense)? includeWhere,
}) {
  int amount = 0;
  int count = 0;
  for (final expense in expenses) {
    if (includeWhere != null && !includeWhere(expense)) continue;
    final date = expense.date.isUtc ? expense.date.toLocal() : expense.date;
    if (date.isBefore(start) || !date.isBefore(end)) continue;
    amount += contributionToExpenseTotal(expense);
    count += 1;
  }
  return TrendPoint(start: start, end: end, amountCents: amount, count: count);
}

List<TrendSeries> _buildParticipantTrendSeries(
  List<Expense> expenses,
  List<Participant> participants,
  List<TrendWindow> windows,
) {
  if (expenses.isEmpty || windows.isEmpty) return const [];
  final namesById = {for (final p in participants) p.id: p.name};
  final totals = <String, int>{};
  for (final expense in expenses) {
    final key = expense.payerParticipantId;
    totals[key] = (totals[key] ?? 0) + contributionToExpenseTotal(expense);
  }
  final rankedIds = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return rankedIds
      .take(_maxComparisonSeries)
      .map((entry) {
        final participantId = entry.key;
        final points = windows
            .map(
              (window) => _bucket(
                expenses,
                window.start,
                window.end,
                includeWhere: (expense) =>
                    expense.payerParticipantId == participantId,
              ),
            )
            .toList();
        return TrendSeries(
          id: participantId,
          label: namesById[participantId] ?? participantId,
          points: points,
        );
      })
      .toList();
}

List<TrendSeries> _buildCategoryTrendSeries(
  List<Expense> expenses,
  List<ExpenseTag> tags,
  List<TrendWindow> windows,
) {
  if (expenses.isEmpty || windows.isEmpty) return const [];
  final totals = <String, int>{};
  for (final expense in expenses) {
    final key = (expense.tag == null || expense.tag!.isEmpty)
        ? 'untagged'
        : expense.tag!;
    totals[key] = (totals[key] ?? 0) + contributionToExpenseTotal(expense);
  }
  final rankedTags = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return rankedTags
      .take(_maxComparisonSeries)
      .map((entry) {
        final tagId = entry.key;
        final points = windows
            .map(
              (window) => _bucket(
                expenses,
                window.start,
                window.end,
                includeWhere: (expense) {
                  final currentTag = (expense.tag == null || expense.tag!.isEmpty)
                      ? 'untagged'
                      : expense.tag!;
                  return currentTag == tagId;
                },
              ),
            )
            .toList();
        return TrendSeries(
          id: tagId,
          label: tagId == 'untagged' ? 'untagged' : resolveTagLabel(tagId, tags),
          points: points,
        );
      })
      .toList();
}

List<AmountBreakdownItem> _buildTagBreakdown(
  List<Expense> expenses,
  List<ExpenseTag> tags,
) {
  final map = <String, (String label, int amount, int count)>{};
  for (final expense in expenses) {
    final key = (expense.tag == null || expense.tag!.isEmpty)
        ? 'untagged'
        : expense.tag!;
    final label = key == 'untagged' ? 'untagged' : resolveTagLabel(key, tags);
    final current = map[key];
    final amount = contributionToExpenseTotal(expense);
    if (current == null) {
      map[key] = (label, amount, 1);
    } else {
      map[key] = (current.$1, current.$2 + amount, current.$3 + 1);
    }
  }

  final rows = map.entries
      .map(
        (entry) => AmountBreakdownItem(
          id: entry.key,
          label: entry.value.$1,
          amountCents: entry.value.$2,
          count: entry.value.$3,
        ),
      )
      .toList();
  rows.sort((a, b) => b.amountCents.compareTo(a.amountCents));
  return rows;
}

List<AmountBreakdownItem> _buildParticipantBreakdown(
  List<Expense> expenses,
  List<Participant> participants,
) {
  final namesById = {for (final p in participants) p.id: p.name};
  final map = <String, (String label, int amount, int count)>{};
  for (final expense in expenses) {
    final key = expense.payerParticipantId;
    final label = namesById[key] ?? key;
    final current = map[key];
    final amount = contributionToExpenseTotal(expense);
    if (current == null) {
      map[key] = (label, amount, 1);
    } else {
      map[key] = (current.$1, current.$2 + amount, current.$3 + 1);
    }
  }

  final rows = map.entries
      .map(
        (entry) => AmountBreakdownItem(
          id: entry.key,
          label: entry.value.$1,
          amountCents: entry.value.$2,
          count: entry.value.$3,
        ),
      )
      .toList();
  rows.sort((a, b) => b.amountCents.compareTo(a.amountCents));
  return rows;
}
