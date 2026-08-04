import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/responsive_sheet.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../domain/domain.dart';
import '../category_icons.dart';
import 'expense_list_tile.dart';

/// One row for [showFilteredExpensesSheet] / [FilteredExpensesList].
class FilteredExpenseRow {
  const FilteredExpenseRow({
    required this.expense,
    required this.payerName,
    required this.groupId,
    this.toParticipantName,
    this.groupCurrencyCode,
    this.amountCentsOverride,
    this.detailLine,
    this.detail,
    this.amountCaption,
    this.customTags,
    this.showPaidBy = true,
    this.showManageMenu = false,
    this.popOverlayBeforeNavigate = false,
  });

  final Expense expense;
  final String payerName;
  final String? toParticipantName;
  final String groupId;
  final String? groupCurrencyCode;
  final int? amountCentsOverride;
  final String? detailLine;
  final Widget? detail;
  final String? amountCaption;
  final List<ExpenseTag>? customTags;
  final bool showPaidBy;
  final bool showManageMenu;

  /// When true (sheet/dialog), dismiss the overlay before pushing a route.
  /// Must stay false for in-page lists (e.g. profile) or back would pop the page.
  final bool popOverlayBeforeNavigate;
}

/// Opens a responsive sheet of expenses using the shared [ExpenseListTile] UI.
Future<void> showFilteredExpensesSheet({
  required BuildContext context,
  required String title,
  required String emptyLabel,
  required List<FilteredExpenseRow> rows,
}) {
  final sheetRows = [
    for (final row in rows)
      FilteredExpenseRow(
        expense: row.expense,
        payerName: row.payerName,
        toParticipantName: row.toParticipantName,
        groupId: row.groupId,
        groupCurrencyCode: row.groupCurrencyCode,
        amountCentsOverride: row.amountCentsOverride,
        detailLine: row.detailLine,
        detail: row.detail,
        amountCaption: row.amountCaption,
        customTags: row.customTags,
        showPaidBy: row.showPaidBy,
        showManageMenu: row.showManageMenu,
        popOverlayBeforeNavigate: true,
      ),
  ];

  final listHeight = MediaQuery.sizeOf(context).height * 0.7;

  return showResponsiveSheet<void>(
    context: context,
    title: title,
    maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    isScrollControlled: true,
    centerInFullViewport: true,
    child: SizedBox(
      height: listHeight,
      child: FilteredExpensesList(
        emptyLabel: emptyLabel,
        rows: sheetRows,
        shrinkWrap: false,
      ),
    ),
  );
}

/// Scrollable expense list matching profile / group expense tile styling.
class FilteredExpensesList extends StatelessWidget {
  const FilteredExpensesList({
    super.key,
    required this.rows,
    required this.emptyLabel,
    this.padding = const EdgeInsets.only(bottom: 16),
    this.shrinkWrap = true,
  });

  final List<FilteredExpenseRow> rows;
  final String emptyLabel;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Text(
          emptyLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: rows.length,
      itemBuilder: (context, index) {
        return AppExpenseTile(row: rows[index]);
      },
    );
  }
}

/// Single expense row using the shared [ExpenseListTile] look.
class AppExpenseTile extends StatelessWidget {
  const AppExpenseTile({super.key, required this.row});

  final FilteredExpenseRow row;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ExpenseListTile(
      expense: row.expense,
      payerName: row.payerName,
      toParticipantName: row.toParticipantName,
      icon: iconForExpenseTag(row.expense.tag, row.customTags),
      customTags: row.customTags,
      groupCurrencyCode: row.groupCurrencyCode,
      amountCentsOverride: row.amountCentsOverride,
      detailLine: row.detailLine,
      detail: row.detail,
      amountCaption: row.amountCaption,
      showPaidBy:
          row.showPaidBy && row.detailLine == null && row.detail == null,
      showDisclosure: !row.showManageMenu,
      onTap: () => _openPath(
        context,
        RoutePaths.groupExpenseDetail(row.groupId, row.expense.id),
        popOverlayFirst: row.popOverlayBeforeNavigate,
      ),
      trailing: row.showManageMenu
          ? Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TileActionButton(
                  tooltip: 'edit'.tr(),
                  icon: Icons.edit_outlined,
                  colorScheme: cs,
                  onPressed: () => _openPath(
                    context,
                    RoutePaths.groupExpenseEdit(row.groupId, row.expense.id),
                    popOverlayFirst: row.popOverlayBeforeNavigate,
                  ),
                ),
                _TileActionButton(
                  tooltip: 'profile_expense_open_group'.tr(),
                  icon: Icons.groups_outlined,
                  colorScheme: cs,
                  onPressed: () => _openPath(
                    context,
                    RoutePaths.groupDetail(row.groupId),
                    popOverlayFirst: row.popOverlayBeforeNavigate,
                  ),
                ),
              ],
            )
          : null,
    );
  }
}

/// Full-height trailing action flush with the card edges.
class _TileActionButton extends StatelessWidget {
  const _TileActionButton({
    required this.tooltip,
    required this.icon,
    required this.colorScheme,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final ColorScheme colorScheme;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            child: Center(
              child: Icon(
                icon,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _openPath(
  BuildContext context,
  String path, {
  required bool popOverlayFirst,
}) {
  final router = GoRouter.of(context);
  if (popOverlayFirst) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }
  router.push(path);
}
