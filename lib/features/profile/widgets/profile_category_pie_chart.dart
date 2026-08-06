import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/user_text.dart';
import '../../../domain/domain.dart';
import '../../expenses/category_icons.dart';
import '../../expenses/widgets/breakdown_pie_chart.dart';
import '../../expenses/widgets/filtered_expenses_sheet.dart';
import '../../groups/providers/group_analytics_provider.dart';
import '../../groups/providers/groups_provider.dart';
import '../providers/profile_activity_provider.dart';
import 'profile_expense_tile.dart';

const _kMaxSlices = 6;
const _kOtherId = '__other__';

/// Profile analytics donut: my-share spend by category.
///
/// Uses the shared [BreakdownPieChart] (select → tap again → expense list).
class ProfileCategoryPieChart extends ConsumerWidget {
  const ProfileCategoryPieChart({
    super.key,
    required this.byTag,
    required this.displayCurrencyCode,
    required this.rangeExpenses,
  });

  final List<ProfileTagSpend> byTag;
  final String displayCurrencyCode;

  /// Expenses already filtered to the analytics range (my-share items).
  final List<ProfileExpenseItem> rangeExpenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final customTags = _collectCustomTags(ref);
    final slices = _buildSlices(theme, cs, customTags);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: BreakdownPieChart(
        title: 'analytics_category_title'.tr(),
        slices: slices,
        currencyCode: displayCurrencyCode,
        emptyLabel: 'analytics_empty_chart'.tr(),
        onOpenSlice: (slice) => _openSliceExpenses(context, slice),
      ),
    );
  }

  List<ExpenseTag> _collectCustomTags(WidgetRef ref) {
    final groupIds = <String>{};
    for (final item in rangeExpenses) {
      groupIds.add(item.expense.groupId);
    }
    final customTags = <ExpenseTag>[];
    final seen = <String>{};
    for (final groupId in groupIds) {
      final tags =
          ref.watch(tagsByGroupProvider(groupId)).asData?.value ??
          const <ExpenseTag>[];
      for (final tag in tags) {
        if (seen.add(tag.id)) customTags.add(tag);
      }
    }
    return customTags;
  }

  List<BreakdownPieSlice> _buildSlices(
    ThemeData theme,
    ColorScheme cs,
    List<ExpenseTag> customTags,
  ) {
    final positive = byTag.where((row) => row.amountCents > 0).toList();
    if (positive.isEmpty) return const [];

    final top = positive.take(_kMaxSlices).toList();
    final rest = positive.skip(_kMaxSlices).toList();
    final slices = <BreakdownPieSlice>[
      for (final row in top)
        BreakdownPieSlice(
          id: row.tagKey,
          label: _label(row.tagKey, customTags),
          amountCents: row.amountCents,
          color: _colorFor(row.tagKey, theme, cs, customTags),
          icon: row.tagKey == 'untagged'
              ? Icons.label_off_outlined
              : iconForExpenseTag(row.tagKey, customTags),
          canOpen: true,
        ),
    ];

    if (rest.isNotEmpty) {
      final otherCents = rest.fold<int>(0, (s, r) => s + r.amountCents);
      final otherIds = rest.map((r) => r.tagKey).toSet();
      slices.add(
        BreakdownPieSlice(
          id: _kOtherId,
          label: 'analytics_pie_other'.tr(),
          amountCents: otherCents,
          color: cs.outline,
          icon: Icons.more_horiz_rounded,
          // Open list of all tags rolled into Other.
          canOpen: otherIds.isNotEmpty,
        ),
      );
    }
    return slices;
  }

  Future<void> _openSliceExpenses(
    BuildContext context,
    BreakdownPieSlice slice,
  ) async {
    final otherTagIds = byTag
        .where((row) => row.amountCents > 0)
        .skip(_kMaxSlices)
        .map((r) => r.tagKey)
        .toSet();

    final filtered = rangeExpenses.where((item) {
      final tag = item.expense.hasBlankTag ? 'untagged' : item.expense.tag!;
      if (slice.id == _kOtherId) return otherTagIds.contains(tag);
      return tag == slice.id;
    }).toList();

    final rows = filtered
        .map(
          (item) => ProfileExpenseTile.toFilteredRow(
            context,
            item,
            showManageMenu: true,
          ),
        )
        .toList();

    await showFilteredExpensesSheet(
      context: context,
      title: 'analytics_category_expenses_title'.tr(
        namedArgs: {'category': isolateBidi(slice.label)},
      ),
      emptyLabel: 'analytics_category_expenses_empty'.tr(),
      rows: rows,
    );
  }

  Color _colorFor(
    String tagKey,
    ThemeData theme,
    ColorScheme cs,
    List<ExpenseTag> customTags,
  ) {
    final chromeId = tagKey == 'untagged' ? null : tagKey;
    return chromeForExpenseTag(
      chromeId,
      brightness: theme.brightness,
      surface: cs.surface,
      customTags: customTags,
    ).container;
  }

  String _label(String key, List<ExpenseTag> customTags) {
    if (key == 'untagged') return 'analytics_untagged'.tr();
    final resolved = resolveTagLabel(key, customTags);
    if (resolved.startsWith('category_')) return resolved.tr();
    return resolved;
  }
}
