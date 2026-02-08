import 'package:intl/intl.dart';

/// Format amounts. [amountCents] is in smallest unit (e.g. cents).
class CurrencyFormatter {
  static String formatCents(int amountCents, String currencyCode) {
    final amount = amountCents / 100.0;
    final formatter = NumberFormat.currency(symbol: '', decimalDigits: 2);
    return '${formatter.format(amount)} $currencyCode';
  }

  static String formatCompactCents(int amountCents) {
    final amount = amountCents / 100.0;
    final formatter = NumberFormat.currency(symbol: '', decimalDigits: 2);
    return formatter.format(amount);
  }
}
