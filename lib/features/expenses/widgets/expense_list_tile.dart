import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../domain/domain.dart';
import '../../../core/utils/currency_formatter.dart';
import '../category_icons.dart';

class ExpenseListTile extends StatelessWidget {
  final Expense expense;
  final String payerName;

  /// Icon for the expense (e.g. from [iconForExpenseTag]). When null, uses [defaultExpenseIcon].
  final IconData? icon;

  /// When false (e.g. personal group), the "Paid by" line is hidden.
  final bool showPaidBy;

  /// When set, the primary amount is shown in group currency (using stored conversion when expense currency differs).
  final String? groupCurrencyCode;

  /// Optional tap callback to open expense details.
  final VoidCallback? onTap;

  /// Show a trailing chevron when the tile is navigable.
  final bool showDisclosure;

  const ExpenseListTile({
    super.key,
    required this.expense,
    required this.payerName,
    this.icon,
    this.showPaidBy = true,
    this.groupCurrencyCode,
    this.onTap,
    this.showDisclosure = false,
  });

  /// Primary amount for display: group currency when [groupCurrencyCode] is set and differs from expense currency, else expense amount.
  (int cents, String currencyCode) get _primaryAmount {
    if (groupCurrencyCode != null &&
        groupCurrencyCode!.isNotEmpty &&
        expense.currencyCode != groupCurrencyCode) {
      return (expense.effectiveBaseAmountCents, groupCurrencyCode!);
    }
    return (expense.amountCents, expense.currencyCode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveIcon = icon ?? defaultExpenseIcon;
    final (cents, currencyCode) = _primaryAmount;
    final surface = colorScheme.surface;
    final chrome = chromeForExpenseTag(
      expense.tag,
      brightness: theme.brightness,
      surface: surface,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: chrome.container,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    effectiveIcon,
                    size: 22,
                    color: chrome.onContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        expense.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showPaidBy) ...[
                        const SizedBox(height: 3),
                        Text(
                          'paid_by'.tr(namedArgs: {'name': payerName}),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.formatCents(cents, currencyCode),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (showDisclosure) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Directionality.of(context) == ui.TextDirection.rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
