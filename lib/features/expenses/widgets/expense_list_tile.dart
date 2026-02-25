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

  const ExpenseListTile({
    super.key,
    required this.expense,
    required this.payerName,
    this.icon,
    this.showPaidBy = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIcon = icon ?? defaultExpenseIcon;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              effectiveIcon,
              size: 28,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    expense.title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showPaidBy) ...[
                    const SizedBox(height: 2),
                    Text(
                      'paid_by'.tr(namedArgs: {'name': payerName}),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              CurrencyFormatter.formatCents(
                expense.amountCents,
                expense.currencyCode,
              ),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
