import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/currency_formatter.dart';
import '../utils/currency_helpers.dart';
import '../../features/settings/providers/settings_framework_providers.dart';
import '../../features/settings/providers/display_currency_rate_provider.dart';
import 'amount_text.dart';

/// Shows a primary amount in [groupCurrencyCode] and, when [displayCurrency] is set and rate is available,
/// a smaller secondary line "(X displayCurrency)".
class AmountWithSecondaryDisplay extends ConsumerWidget {
  final int amountCents;
  final String groupCurrencyCode;

  /// Optional: style for the primary amount. Defaults to titleMedium with fontWeight w600.
  final TextStyle? primaryStyle;

  /// Optional: style for the secondary line. Defaults to bodySmall, onSurfaceVariant.
  final TextStyle? secondaryStyle;

  /// When true, primary shows "- amount" and secondary shows "(- amount code)" so the minus stays with the amount in all layouts (e.g. RTL).
  final bool isNegative;

  /// When false, only the primary amount is shown (e.g. for trailing when secondary is in subtitle).
  final bool showSecondary;

  /// When true and secondary is shown, primary and secondary are in one row (e.g. "XXX EUR  (YYY USD)").
  final bool secondaryOnSameRow;

  /// Forwarded to the primary [AmountText] (e.g. false inside [FittedBox]).
  final bool? softWrap;

  /// Forwarded to the primary [AmountText].
  final int? maxLines;

  /// Forwarded to the primary [AmountText].
  final TextOverflow? overflow;

  const AmountWithSecondaryDisplay({
    super.key,
    required this.amountCents,
    required this.groupCurrencyCode,
    this.primaryStyle,
    this.secondaryStyle,
    this.isNegative = false,
    this.showSecondary = true,
    this.secondaryOnSameRow = false,
    this.softWrap,
    this.maxLines,
    this.overflow,
  });

  static double _divisor(int decimalDigits) {
    switch (decimalDigits) {
      case 0:
        return 1.0;
      case 3:
        return 1000.0;
      default:
        return 100.0;
    }
  }

  /// Convert [amountCents] in group currency to display-currency cents using [rate].
  static int toDisplayCents(
    int amountCents,
    String groupCurrencyCode,
    String displayCurrencyCode,
    double rate,
  ) {
    return _toDisplayCents(
      amountCents,
      groupCurrencyCode,
      displayCurrencyCode,
      rate,
    );
  }

  static int _toDisplayCents(
    int amountCents,
    String groupCurrencyCode,
    String displayCurrencyCode,
    double rate,
  ) {
    final groupDecimals =
        CurrencyHelpers.fromCode(groupCurrencyCode)?.decimalDigits ?? 2;
    final displayDecimals =
        CurrencyHelpers.fromCode(displayCurrencyCode)?.decimalDigits ?? 2;
    final groupAmount = amountCents / _divisor(groupDecimals);
    final displayAmount = groupAmount / rate;
    return (displayAmount * _divisor(displayDecimals)).round();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final displayCurrency = ref.watch(displayCurrencyProvider);
    final rateKey = displayCurrency.isEmpty
        ? null
        : '$groupCurrencyCode|$displayCurrency';
    final rateAsync = rateKey == null
        ? null
        : ref.watch(displayCurrencyRateProvider(rateKey));

    final primaryStyle =
        this.primaryStyle ??
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
    final secondaryStyle =
        this.secondaryStyle ??
        theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );

    final primaryFormatted = CurrencyFormatter.formatCents(
      amountCents,
      groupCurrencyCode,
    );
    final primaryWidget = AmountText(
      isNegative ? '- $primaryFormatted' : primaryFormatted,
      style: primaryStyle,
      softWrap: softWrap,
      maxLines: maxLines,
      overflow: overflow,
    );

    final rate = rateAsync?.asData?.value;
    final hasSecondary =
        showSecondary &&
        displayCurrency.isNotEmpty &&
        groupCurrencyCode != displayCurrency &&
        rate != null &&
        rate > 0;

    if (!hasSecondary) {
      return primaryWidget;
    }
    final displayCents = _toDisplayCents(
      amountCents,
      groupCurrencyCode,
      displayCurrency,
      rate,
    );
    final displayFormatted = CurrencyFormatter.formatCents(
      displayCents,
      displayCurrency,
    );
    final secondaryText = isNegative
        ? '(- $displayFormatted)'
        : '($displayFormatted)';
    final secondaryWidget = AmountText(
      secondaryText,
      style:
          secondaryStyle?.copyWith(height: 1.0) ??
          theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.0,
          ),
    );

    if (secondaryOnSameRow) {
      // Keep primary → secondary order in RTL shells (don't flip the money row).
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [primaryWidget, const SizedBox(width: 8), secondaryWidget],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [primaryWidget, const SizedBox(height: 2), secondaryWidget],
    );
  }
}

/// Centered secondary amount line for use as list tile subtitle (e.g. middle bottom of tile).
/// Shows nothing when display currency is unset or rate unavailable.
class SecondaryAmountLine extends ConsumerWidget {
  final int amountCents;
  final String groupCurrencyCode;
  final bool isNegative;
  final TextStyle? secondaryStyle;

  const SecondaryAmountLine({
    super.key,
    required this.amountCents,
    required this.groupCurrencyCode,
    this.isNegative = false,
    this.secondaryStyle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final displayCurrency = ref.watch(displayCurrencyProvider);
    final rateKey = displayCurrency.isEmpty
        ? null
        : '$groupCurrencyCode|$displayCurrency';
    final rateAsync = rateKey == null
        ? null
        : ref.watch(displayCurrencyRateProvider(rateKey));
    final rate = rateAsync?.asData?.value;
    final showSecondary =
        displayCurrency.isNotEmpty &&
        groupCurrencyCode != displayCurrency &&
        rate != null &&
        rate > 0;
    if (!showSecondary) return const SizedBox.shrink();
    final displayCents = AmountWithSecondaryDisplay._toDisplayCents(
      amountCents,
      groupCurrencyCode,
      displayCurrency,
      rate,
    );
    final displayFormatted = CurrencyFormatter.formatCents(
      displayCents,
      displayCurrency,
    );
    final secondaryText = isNegative
        ? '(- $displayFormatted)'
        : '($displayFormatted)';
    final style =
        secondaryStyle ??
        theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: AmountText(secondaryText, style: style),
      ),
    );
  }
}
