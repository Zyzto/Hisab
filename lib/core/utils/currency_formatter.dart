import 'package:intl/intl.dart';

import 'currency_helpers.dart';

/// Format amounts. [amountCents] is in smallest unit (e.g. cents).
/// Uses currency_picker's data for proper symbol, decimal digits, and placement.
class CurrencyFormatter {
  /// Format with symbol: "$12.34" or "12.34 ﷼" depending on currency.
  static String formatCents(int amountCents, String currencyCode) {
    final p = _currencyParams(currencyCode);
    final formatted = _formatNumber(amountCents, p.$1);
    return p.$3 ? '${p.$2} $formatted' : '$formatted ${p.$2}';
  }

  /// Format with both symbol and code: "$12.34 USD" or "12.34 ﷼ SAR".
  static String formatWithCode(int amountCents, String currencyCode) {
    final p = _currencyParams(currencyCode);
    final formatted = _formatNumber(amountCents, p.$1);
    if (p.$2.isNotEmpty && p.$3) {
      return '${p.$2} $formatted $currencyCode';
    }
    if (p.$2.isNotEmpty) {
      return '$formatted ${p.$2} $currencyCode';
    }
    return '$formatted $currencyCode';
  }

  /// Format number only, no symbol or code: "12.34"
  static String formatCompactCents(int amountCents, [String? currencyCode]) {
    final decimalDigits = currencyCode != null
        ? _currencyParams(currencyCode).$1
        : 2;
    return _formatNumber(amountCents, decimalDigits);
  }

  /// (decimalDigits, symbol, onLeft) from one fromCode lookup.
  static (int, String, bool) _currencyParams(String currencyCode) {
    final currency = CurrencyHelpers.fromCode(currencyCode);
    final decimalDigits = currency?.decimalDigits ?? 2;
    final symbol = currency?.symbol ?? currencyCode;
    final onLeft = currency?.symbolOnLeft ?? true;
    return (decimalDigits, symbol, onLeft);
  }

  static String _formatNumber(int amountCents, int decimalDigits) {
    final divisor = _divisor(decimalDigits);
    final amount = amountCents / divisor;
    final formatter = NumberFormat.currency(
      symbol: '',
      decimalDigits: decimalDigits,
    );
    return formatter.format(amount);
  }

  /// Get the divisor for converting smallest unit to main unit.
  /// e.g. 2 decimal digits -> 100, 0 -> 1, 3 -> 1000.
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
}
