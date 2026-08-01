import 'package:flutter/material.dart';
// Hide intl's TextDirection (LTR/RTL) so Flutter's TextDirection.ltr/rtl resolve.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../../../domain/domain.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/user_text.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/user_text.dart';
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

  /// When set, shows this amount instead of the expense total (e.g. profile my-share).
  final int? amountCentsOverride;

  /// Optional second line; when null and [showPaidBy], shows paid_by.
  /// Ignored when [detail] is non-null.
  final String? detailLine;

  /// Custom second-line content (e.g. visual chips). Takes precedence over [detailLine].
  final Widget? detail;

  /// Extra trailing controls inside the card (e.g. edit / open-group icons).
  final Widget? trailing;

  /// Optional caption under the primary amount (e.g. "Your share").
  final String? amountCaption;

  const ExpenseListTile({
    super.key,
    required this.expense,
    required this.payerName,
    this.icon,
    this.showPaidBy = true,
    this.groupCurrencyCode,
    this.onTap,
    this.showDisclosure = false,
    this.amountCentsOverride,
    this.detailLine,
    this.detail,
    this.trailing,
    this.amountCaption,
  });

  /// Primary amount for display: group currency when [groupCurrencyCode] is set and differs from expense currency, else expense amount.
  (int cents, String currencyCode) get _primaryAmount {
    if (amountCentsOverride != null) {
      final code = (groupCurrencyCode != null && groupCurrencyCode!.isNotEmpty)
          ? groupCurrencyCode!
          : expense.currencyCode;
      return (amountCentsOverride!, code);
    }
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

    final content = Row(
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
              UserText(
                expense.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (detail != null) ...[
                const SizedBox(height: 6),
                detail!,
              ] else if (detailLine != null || showPaidBy) ...[
                const SizedBox(height: 3),
                UserText(
                  detailLine ??
                      'paid_by'.tr(
                        namedArgs: {'name': isolateBidi(payerName)},
                      ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            AmountText(
              CurrencyFormatter.formatCents(cents, currencyCode),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            if (amountCaption != null) ...[
              const SizedBox(height: 2),
              Text(
                amountCaption!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        // Gap between amount and trailing actions / chevron.
        if (trailing != null || showDisclosure) const SizedBox(width: 10),
        if (showDisclosure && trailing == null)
          Icon(
            // Point toward the trailing edge in both LTR and RTL.
            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: trailing == null
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: content,
                  )
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              12,
                              12,
                              0,
                              12,
                            ),
                            child: content,
                          ),
                        ),
                        trailing!,
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
