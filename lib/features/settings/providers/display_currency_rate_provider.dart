import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/services/exchange_rate_service.dart';

part 'display_currency_rate_provider.g.dart';

/// Key format: "groupCurrency|displayCurrency". When displayCurrency is empty or equals groupCurrency, returns null.
@riverpod
Future<double?> displayCurrencyRate(Ref ref, String key) async {
  final parts = key.split('|');
  if (parts.length != 2) return null;
  final groupCurrency = parts[0].trim();
  final displayCurrency = parts[1].trim();
  if (displayCurrency.isEmpty || groupCurrency == displayCurrency) return null;
  final service = ExchangeRateService();
  // getRate(from, to) = how many units of [from] per 1 unit of [to]. So displayAmount = groupAmount / rate.
  return service.getRate(groupCurrency, displayCurrency);
}
