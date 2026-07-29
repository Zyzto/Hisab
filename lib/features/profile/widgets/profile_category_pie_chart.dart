import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../expenses/category_icons.dart';
import '../../expenses/widgets/breakdown_pie_chart.dart';
import '../../expenses/widgets/filtered_expenses_sheet.dart';
import '../../groups/providers/group_analytics_provider.dart';
import '../providers/profile_activity_provider.dart';
import 'profile_expense_tile.dart';

const _kMaxSlices = 6;
const _kOtherId = '__other__';

/// Profile analytics donut: my-share spend by category.
///
/// Uses the shared [BreakdownPieChart] (select → tap again → expense list).
class ProfileCategoryPieChart extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final slices = _buildSlices(theme, cs);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: BreakdownPieChart(
        title: 'analytics_category_title'.tr(),
        slices: slices,
        currencyCode: displayCurrencyCode,
        centerIdleLabel: 'analytics_kpi_my_spend'.tr(),
        emptyLabel: 'analytics_empty_chart'.tr(),
        onOpenSlice: (slice) => _openSliceExpenses(context, slice),
      ),
    );
  }

  List<BreakdownPieSlice> _buildSlices(ThemeData theme, ColorScheme cs) {
    final positive = byTag.where((row) => row.amountCents > 0).toList();
    if (positive.isEmpty) return const [];

    final top = positive.take(_kMaxSlices).toList();
    final rest = positive.skip(_kMaxSlices).toList();
    final slices = <BreakdownPieSlice>[
      for (final row in top)
        BreakdownPieSlice(
          id: row.tagKey,
          label: _label(row.tagKey),
          amountCents: row.amountCents,
          color: _colorFor(row.tagKey, theme, cs),
          icon: row.tagKey == 'untagged'
              ? Icons.label_off_outlined
              : iconForExpenseTag(row.tagKey, null),
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
      final tag = (item.expense.tag == null || item.expense.tag!.isEmpty)
          ? 'untagged'
          : item.expense.tag!;
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
        namedArgs: {'category': slice.label},
      ),
      emptyLabel: 'analytics_category_expenses_empty'.tr(),
      rows: rows,
    );
  }

  Color _colorFor(String tagKey, ThemeData theme, ColorScheme cs) {
    final chromeId = tagKey == 'untagged' ? null : tagKey;
    return chromeForExpenseTag(
      chromeId,
      brightness: theme.brightness,
      surface: cs.surface,
    ).container;
  }

  String _label(String key) {
    if (key == 'untagged') return 'analytics_untagged'.tr();
    final resolved = resolveTagLabel(key, const []);
    if (resolved.startsWith('category_')) return resolved.tr();
    return resolved;
  }
}
