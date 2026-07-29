import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../../../core/services/settle_up_service.dart';
import '../../../domain/domain.dart';
import '../../groups/providers/group_analytics_provider.dart';
import '../../groups/providers/group_member_provider.dart';
import '../../groups/providers/groups_provider.dart';

/// One expense involving the current user, with their split share only.
class ProfileExpenseItem {
  const ProfileExpenseItem({
    required this.expense,
    required this.group,
    required this.myShareCents,
    required this.payerName,
    required this.iPaid,
  });

  final Expense expense;
  final Group group;

  /// Share in the group's base currency.
  final int myShareCents;
  final String payerName;
  final bool iPaid;
}

enum ProfileExpensePaidFilter { all, me, others }

enum ProfileExpenseTypeFilter { all, expense, income }

enum ProfileExpenseSort { newest, oldest, shareHigh, shareLow }

class ProfileExpensesFilter {
  const ProfileExpensesFilter({
    this.query = '',
    this.groupId,
    this.tagKey,
    this.paidBy = ProfileExpensePaidFilter.all,
    this.type = ProfileExpenseTypeFilter.all,
    this.range = AnalyticsRangePreset.all,
    this.sort = ProfileExpenseSort.newest,
  });

  final String query;
  final String? groupId;

  /// Null = all tags; `'untagged'` = no tag.
  final String? tagKey;
  final ProfileExpensePaidFilter paidBy;
  final ProfileExpenseTypeFilter type;
  final AnalyticsRangePreset range;
  final ProfileExpenseSort sort;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      groupId != null ||
      tagKey != null ||
      paidBy != ProfileExpensePaidFilter.all ||
      type != ProfileExpenseTypeFilter.all ||
      range != AnalyticsRangePreset.all ||
      sort != ProfileExpenseSort.newest;

  ProfileExpensesFilter copyWith({
    String? query,
    String? groupId,
    bool clearGroupId = false,
    String? tagKey,
    bool clearTagKey = false,
    ProfileExpensePaidFilter? paidBy,
    ProfileExpenseTypeFilter? type,
    AnalyticsRangePreset? range,
    ProfileExpenseSort? sort,
  }) {
    return ProfileExpensesFilter(
      query: query ?? this.query,
      groupId: clearGroupId ? null : (groupId ?? this.groupId),
      tagKey: clearTagKey ? null : (tagKey ?? this.tagKey),
      paidBy: paidBy ?? this.paidBy,
      type: type ?? this.type,
      range: range ?? this.range,
      sort: sort ?? this.sort,
    );
  }
}

final profileExpensesFilterProvider =
    StateProvider<ProfileExpensesFilter>((ref) => const ProfileExpensesFilter());

/// All expenses across groups where the current user is in the split (my share).
final profileMyExpensesProvider =
    Provider<AsyncValue<List<ProfileExpenseItem>>>((ref) {
  final groupsAsync = ref.watch(groupsProvider);

  return groupsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
    data: (groups) {
      final items = <ProfileExpenseItem>[];

      for (final group in groups) {
        final member =
            ref.watch(myMemberInGroupProvider(group.id)).asData?.value;
        final myParticipantId = member?.participantId;
        if (myParticipantId == null) continue;

        final expenses =
            ref.watch(expensesByGroupProvider(group.id)).asData?.value;
        if (expenses == null) continue;

        final participants = ref
            .watch(activeParticipantsByGroupProvider(group.id))
            .asData
            ?.value;
        final nameById = <String, String>{
          for (final p in participants ?? const <Participant>[]) p.id: p.name,
        };

        for (final expense in expenses) {
          if (expense.transactionType == TransactionType.transfer) continue;
          if (!expenseInvolvesParticipant(expense, myParticipantId)) continue;
          final share = participantSplitShareCents(expense, myParticipantId);
          if (share == null) continue;

          items.add(
            ProfileExpenseItem(
              expense: expense,
              group: group,
              myShareCents: share,
              payerName: nameById[expense.payerParticipantId] ?? '…',
              iPaid: expense.payerParticipantId == myParticipantId,
            ),
          );
        }
      }

      items.sort((a, b) => b.expense.date.compareTo(a.expense.date));
      return AsyncValue.data(items);
    },
  );
});

final filteredProfileExpensesProvider =
    Provider<AsyncValue<List<ProfileExpenseItem>>>((ref) {
  final allAsync = ref.watch(profileMyExpensesProvider);
  final filter = ref.watch(profileExpensesFilterProvider);

  return allAsync.when(
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
    data: (items) => AsyncValue.data(applyProfileExpensesFilter(items, filter)),
  );
});

List<ProfileExpenseItem> applyProfileExpensesFilter(
  List<ProfileExpenseItem> items,
  ProfileExpensesFilter filter,
) {
  final q = filter.query.trim().toLowerCase();
  DateTime? rangeStart;
  if (filter.range != AnalyticsRangePreset.all && items.isNotEmpty) {
    final latest = items.first.expense.date.isUtc
        ? items.first.expense.date.toLocal()
        : items.first.expense.date;
    // Prefer global latest across list (already sorted newest-first).
    final activityEnd = latest;
    rangeStart = _rangeStart(filter.range, activityEnd);
  }

  final filtered = items.where((item) {
    if (filter.groupId != null && item.group.id != filter.groupId) {
      return false;
    }

    if (filter.tagKey != null) {
      final tag = (item.expense.tag == null || item.expense.tag!.isEmpty)
          ? 'untagged'
          : item.expense.tag!;
      if (tag != filter.tagKey) return false;
    }

    switch (filter.paidBy) {
      case ProfileExpensePaidFilter.all:
        break;
      case ProfileExpensePaidFilter.me:
        if (!item.iPaid) return false;
      case ProfileExpensePaidFilter.others:
        if (item.iPaid) return false;
    }

    switch (filter.type) {
      case ProfileExpenseTypeFilter.all:
        break;
      case ProfileExpenseTypeFilter.expense:
        if (item.expense.transactionType != TransactionType.expense) {
          return false;
        }
      case ProfileExpenseTypeFilter.income:
        if (item.expense.transactionType != TransactionType.income) {
          return false;
        }
    }

    if (rangeStart != null) {
      final localDate = item.expense.date.isUtc
          ? item.expense.date.toLocal()
          : item.expense.date;
      if (localDate.isBefore(rangeStart)) return false;
    }

    if (q.isNotEmpty) {
      final haystack = [
        item.expense.title,
        item.expense.description ?? '',
        item.group.name,
        item.payerName,
        item.expense.tag ?? '',
      ].join(' ').toLowerCase();
      if (!haystack.contains(q)) return false;
    }

    return true;
  }).toList();

  switch (filter.sort) {
    case ProfileExpenseSort.newest:
      filtered.sort((a, b) => b.expense.date.compareTo(a.expense.date));
    case ProfileExpenseSort.oldest:
      filtered.sort((a, b) => a.expense.date.compareTo(b.expense.date));
    case ProfileExpenseSort.shareHigh:
      filtered.sort((a, b) => b.myShareCents.compareTo(a.myShareCents));
    case ProfileExpenseSort.shareLow:
      filtered.sort((a, b) => a.myShareCents.compareTo(b.myShareCents));
  }

  return filtered;
}

DateTime? _rangeStart(AnalyticsRangePreset range, DateTime activityEnd) {
  final end = DateTime(activityEnd.year, activityEnd.month, activityEnd.day);
  switch (range) {
    case AnalyticsRangePreset.days30:
      return end.subtract(const Duration(days: 29));
    case AnalyticsRangePreset.days90:
      return end.subtract(const Duration(days: 89));
    case AnalyticsRangePreset.all:
      return null;
  }
}
