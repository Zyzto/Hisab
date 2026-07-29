import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../expenses/widgets/filtered_expenses_sheet.dart';
import '../providers/profile_my_expenses_provider.dart';

/// Profile-scoped expense row (my share) built on the shared [AppExpenseTile].
class ProfileExpenseTile extends StatelessWidget {
  const ProfileExpenseTile({
    super.key,
    required this.item,
    this.showManageMenu = false,
  });

  final ProfileExpenseItem item;
  final bool showManageMenu;

  /// Shared row model for list tiles and filtered expense sheets.
  static FilteredExpenseRow toFilteredRow(
    BuildContext context,
    ProfileExpenseItem item, {
    bool showManageMenu = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final paidLabel =
        item.iPaid ? 'profile_expense_you_paid'.tr() : item.payerName;

    return FilteredExpenseRow(
      expense: item.expense,
      payerName: item.payerName,
      groupId: item.group.id,
      groupCurrencyCode: item.group.currencyCode,
      amountCentsOverride: item.myShareCents,
      amountCaption: 'profile_your_share'.tr(),
      detail: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _MetaChip(
            icon: Icons.group_outlined,
            label: item.group.name,
            foreground: cs.onSurfaceVariant,
            background: cs.surfaceContainerHighest.withValues(alpha: 0.7),
            border: cs.outlineVariant.withValues(alpha: 0.45),
          ),
          _MetaChip(
            icon: item.iPaid
                ? Icons.person_rounded
                : Icons.person_outline_rounded,
            label: paidLabel,
            foreground:
                item.iPaid ? cs.onSecondaryContainer : cs.onSurfaceVariant,
            background: item.iPaid
                ? cs.secondaryContainer.withValues(alpha: 0.85)
                : cs.surfaceContainerHighest.withValues(alpha: 0.7),
            border: item.iPaid
                ? cs.secondary.withValues(alpha: 0.25)
                : cs.outlineVariant.withValues(alpha: 0.45),
          ),
        ],
      ),
      showManageMenu: showManageMenu,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppExpenseTile(
      row: toFilteredRow(
        context,
        item,
        showManageMenu: showManageMenu,
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.only(
        start: 8,
        end: 10,
        top: 4,
        bottom: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
