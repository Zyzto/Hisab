import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/anchored_dropdown_chip.dart';
import '../../../domain/domain.dart';
import '../../expenses/category_icons.dart';
import '../../groups/providers/group_analytics_provider.dart';
import '../../groups/providers/groups_provider.dart';
import '../providers/profile_my_expenses_provider.dart';

/// Search + tag-styled anchored filter dropdowns for the profile expenses page.
class ProfileExpensesFiltersBar extends ConsumerWidget {
  const ProfileExpensesFiltersBar({
    super.key,
    required this.searchController,
    required this.allItems,
    required this.onFilterChanged,
  });

  final TextEditingController searchController;
  final List<ProfileExpenseItem> allItems;
  final ValueChanged<ProfileExpensesFilter> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(profileExpensesFilterProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final groups = <String, String>{
      for (final item in allItems) item.group.id: item.group.name,
    };

    final customTags = <ExpenseTag>[];
    final seenTagIds = <String>{};
    for (final groupId in groups.keys) {
      final tags =
          ref.watch(tagsByGroupProvider(groupId)).asData?.value ??
          const <ExpenseTag>[];
      for (final tag in tags) {
        if (seenTagIds.add(tag.id)) customTags.add(tag);
      }
    }

    final tagKeys = <String>{};
    for (final item in allItems) {
      final tag = (item.expense.tag == null || item.expense.tag!.isEmpty)
          ? 'untagged'
          : item.expense.tag!;
      tagKeys.add(tag);
    }
    final tagList = tagKeys.toList()
      ..sort((a, b) {
        if (a == 'untagged') return 1;
        if (b == 'untagged') return -1;
        return _profileTagLabel(a, customTags)
            .compareTo(_profileTagLabel(b, customTags));
      });

    final period = switch (filter.range) {
      AnalyticsRangePreset.days30 => (
        Icons.calendar_view_week_rounded,
        'analytics_range_30d'.tr(),
      ),
      AnalyticsRangePreset.days90 => (
        Icons.calendar_view_month_rounded,
        'analytics_range_90d'.tr(),
      ),
      AnalyticsRangePreset.all => (
        Icons.all_inclusive_rounded,
        'analytics_range_all'.tr(),
      ),
    };

    final paidBy = switch (filter.paidBy) {
      ProfileExpensePaidFilter.all => (
        Icons.groups_outlined,
        'profile_expenses_paid_by_all'.tr(),
      ),
      ProfileExpensePaidFilter.me => (
        Icons.person_rounded,
        'profile_expenses_paid_by_me'.tr(),
      ),
      ProfileExpensePaidFilter.others => (
        Icons.person_outline_rounded,
        'profile_expenses_paid_by_others'.tr(),
      ),
    };

    final type = switch (filter.type) {
      ProfileExpenseTypeFilter.all => (
        Icons.tune_rounded,
        'profile_expenses_type_all'.tr(),
      ),
      ProfileExpenseTypeFilter.expense => (
        Icons.receipt_long_rounded,
        'expenses'.tr(),
      ),
      ProfileExpenseTypeFilter.income => (
        Icons.south_west_rounded,
        'income'.tr(),
      ),
    };

    final sort = switch (filter.sort) {
      ProfileExpenseSort.newest => (
        Icons.schedule_rounded,
        'profile_expenses_sort_newest'.tr(),
      ),
      ProfileExpenseSort.oldest => (
        Icons.history_rounded,
        'profile_expenses_sort_oldest'.tr(),
      ),
      ProfileExpenseSort.shareHigh => (
        Icons.arrow_downward_rounded,
        'profile_expenses_sort_share_high'.tr(),
      ),
      ProfileExpenseSort.shareLow => (
        Icons.arrow_upward_rounded,
        'profile_expenses_sort_share_low'.tr(),
      ),
    };

    final categoryIcon = filter.tagKey == null
        ? Icons.apps_rounded
        : (filter.tagKey == 'untagged'
              ? Icons.label_off_outlined
              : iconForExpenseTag(filter.tagKey, customTags));
    final categoryLabel = filter.tagKey == null
        ? 'analytics_filter_all_categories'.tr()
        : _profileTagLabel(filter.tagKey!, customTags);

    final groupIcon = filter.groupId == null
        ? Icons.workspaces_outline
        : Icons.group_outlined;
    final groupLabel = filter.groupId == null
        ? 'profile_expenses_all_groups'.tr()
        : (groups[filter.groupId] ?? 'profile_expenses_all_groups'.tr());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'profile_expenses_search_hint'.tr(),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: filter.query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'profile_expenses_clear_filters'.tr(),
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        searchController.clear();
                        onFilterChanged(filter.copyWith(query: ''));
                      },
                    ),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.55),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: cs.primary, width: 1.4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            onChanged: (value) => onFilterChanged(filter.copyWith(query: value)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              AnchoredDropdownChip<AnalyticsRangePreset>(
                icon: period.$1,
                label: period.$2,
                active: filter.range != AnalyticsRangePreset.all,
                selected: filter.range,
                options: [
                  AnchoredDropdownOption(
                    value: AnalyticsRangePreset.days30,
                    label: 'analytics_range_30d'.tr(),
                    icon: Icons.calendar_view_week_rounded,
                  ),
                  AnchoredDropdownOption(
                    value: AnalyticsRangePreset.days90,
                    label: 'analytics_range_90d'.tr(),
                    icon: Icons.calendar_view_month_rounded,
                  ),
                  AnchoredDropdownOption(
                    value: AnalyticsRangePreset.all,
                    label: 'analytics_range_all'.tr(),
                    icon: Icons.all_inclusive_rounded,
                  ),
                ],
                onSelected: (value) =>
                    onFilterChanged(filter.copyWith(range: value)),
              ),
              AnchoredDropdownChip<ProfileExpensePaidFilter>(
                icon: paidBy.$1,
                label: paidBy.$2,
                active: filter.paidBy != ProfileExpensePaidFilter.all,
                selected: filter.paidBy,
                options: [
                  AnchoredDropdownOption(
                    value: ProfileExpensePaidFilter.all,
                    label: 'profile_expenses_paid_by_all'.tr(),
                    icon: Icons.groups_outlined,
                  ),
                  AnchoredDropdownOption(
                    value: ProfileExpensePaidFilter.me,
                    label: 'profile_expenses_paid_by_me'.tr(),
                    icon: Icons.person_rounded,
                  ),
                  AnchoredDropdownOption(
                    value: ProfileExpensePaidFilter.others,
                    label: 'profile_expenses_paid_by_others'.tr(),
                    icon: Icons.person_outline_rounded,
                  ),
                ],
                onSelected: (value) =>
                    onFilterChanged(filter.copyWith(paidBy: value)),
              ),
              AnchoredDropdownChip<ProfileExpenseTypeFilter>(
                icon: type.$1,
                label: type.$2,
                active: filter.type != ProfileExpenseTypeFilter.all,
                selected: filter.type,
                options: [
                  AnchoredDropdownOption(
                    value: ProfileExpenseTypeFilter.all,
                    label: 'profile_expenses_type_all'.tr(),
                    icon: Icons.tune_rounded,
                  ),
                  AnchoredDropdownOption(
                    value: ProfileExpenseTypeFilter.expense,
                    label: 'expenses'.tr(),
                    icon: Icons.receipt_long_rounded,
                  ),
                  AnchoredDropdownOption(
                    value: ProfileExpenseTypeFilter.income,
                    label: 'income'.tr(),
                    icon: Icons.south_west_rounded,
                  ),
                ],
                onSelected: (value) =>
                    onFilterChanged(filter.copyWith(type: value)),
              ),
              if (tagList.isNotEmpty)
                AnchoredDropdownChip<String>(
                  icon: categoryIcon,
                  label: categoryLabel,
                  active: filter.tagKey != null,
                  selected: filter.tagKey ?? '',
                  options: [
                    AnchoredDropdownOption(
                      value: '',
                      label: 'analytics_filter_all_categories'.tr(),
                      icon: Icons.apps_rounded,
                    ),
                    for (final tag in tagList)
                      AnchoredDropdownOption(
                        value: tag,
                        label: _profileTagLabel(tag, customTags),
                        icon: tag == 'untagged'
                            ? Icons.label_off_outlined
                            : iconForExpenseTag(tag, customTags),
                      ),
                  ],
                  onSelected: (value) {
                    if (value.isEmpty) {
                      onFilterChanged(filter.copyWith(clearTagKey: true));
                    } else {
                      onFilterChanged(filter.copyWith(tagKey: value));
                    }
                  },
                ),
              if (groups.length > 1)
                AnchoredDropdownChip<String>(
                  icon: groupIcon,
                  label: groupLabel,
                  active: filter.groupId != null,
                  selected: filter.groupId ?? '',
                  options: [
                    AnchoredDropdownOption(
                      value: '',
                      label: 'profile_expenses_all_groups'.tr(),
                      icon: Icons.workspaces_outline,
                    ),
                    for (final entry in groups.entries)
                      AnchoredDropdownOption(
                        value: entry.key,
                        label: entry.value,
                        icon: Icons.group_outlined,
                      ),
                  ],
                  onSelected: (value) {
                    if (value.isEmpty) {
                      onFilterChanged(filter.copyWith(clearGroupId: true));
                    } else {
                      onFilterChanged(filter.copyWith(groupId: value));
                    }
                  },
                ),
              AnchoredDropdownChip<ProfileExpenseSort>(
                icon: sort.$1,
                label: sort.$2,
                active: filter.sort != ProfileExpenseSort.newest,
                selected: filter.sort,
                options: [
                  AnchoredDropdownOption(
                    value: ProfileExpenseSort.newest,
                    label: 'profile_expenses_sort_newest'.tr(),
                    icon: Icons.schedule_rounded,
                  ),
                  AnchoredDropdownOption(
                    value: ProfileExpenseSort.oldest,
                    label: 'profile_expenses_sort_oldest'.tr(),
                    icon: Icons.history_rounded,
                  ),
                  AnchoredDropdownOption(
                    value: ProfileExpenseSort.shareHigh,
                    label: 'profile_expenses_sort_share_high'.tr(),
                    icon: Icons.arrow_downward_rounded,
                  ),
                  AnchoredDropdownOption(
                    value: ProfileExpenseSort.shareLow,
                    label: 'profile_expenses_sort_share_low'.tr(),
                    icon: Icons.arrow_upward_rounded,
                  ),
                ],
                onSelected: (value) =>
                    onFilterChanged(filter.copyWith(sort: value)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _profileTagLabel(String tagId, List<ExpenseTag> customTags) {
  if (tagId == 'untagged') return 'analytics_untagged'.tr();
  final resolved = resolveTagLabel(tagId, customTags);
  if (resolved.startsWith('category_')) return resolved.tr();
  return resolved;
}
