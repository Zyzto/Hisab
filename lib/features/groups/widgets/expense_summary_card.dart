import 'package:flutter/material.dart';

import '../../../core/theme/accent_style.dart';

/// Summary card for my/total expenses in the expenses tab.
///
/// Keeps label + amount on one row when they fit. For large amounts (or when
/// the row would overflow), the label moves to a top-corner overlay and the
/// amount scales down via [FittedBox] so up to ~10,000,000.00 (8 digits) still
/// reads on one line (no currency wrap above the digits).
class ExpenseSummaryCard extends StatelessWidget {
  const ExpenseSummaryCard({
    super.key,
    required this.label,
    required this.value,
    this.valueWidget,
  });

  final String label;

  /// Formatted amount used for layout measurement and as a text fallback.
  final String value;

  /// When set, shown instead of [value] (e.g. [AmountWithSecondaryDisplay]).
  final Widget? valueWidget;

  /// Integer digits before the decimal in [value] (ignores grouping separators).
  @visibleForTesting
  static int integerDigitCount(String formatted) {
    final beforeDecimal = formatted.split('.').first;
    return beforeDecimal.replaceAll(RegExp(r'\D'), '').length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      height: 1.0,
    );
    final amountStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: AccentSurfaces.panel(
        colorScheme,
        subtle: context.subtleAccents,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textDir = Directionality.of(context);
          final labelPainter = TextPainter(
            text: TextSpan(text: label, style: labelStyle),
            textDirection: textDir,
            maxLines: 1,
          )..layout(maxWidth: constraints.maxWidth);
          final valuePainter = TextPainter(
            text: TextSpan(text: value, style: amountStyle),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();

          final fitsRow =
              labelPainter.width + 8 + valuePainter.width <=
              constraints.maxWidth;
          // 8+ integer digits (~10M+): always give the amount the full row.
          final useOverlay = !fitsRow || integerDigitCount(value) >= 8;

          final amount = DefaultTextStyle.merge(
            style: amountStyle,
            textAlign: TextAlign.end,
            child:
                valueWidget ??
                Text(
                  value,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.end,
                  textDirection: TextDirection.ltr,
                  style: amountStyle,
                ),
          );

          if (!useOverlay) {
            return Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: amount,
                  ),
                ),
              ],
            );
          }

          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: amount,
                  ),
                ),
              ),
              PositionedDirectional(
                top: 0,
                start: 0,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
