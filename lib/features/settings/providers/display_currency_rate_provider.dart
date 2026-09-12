import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'display_currency_rate_provider.g.dart';

/// Currency conversion is intentionally unavailable in the offline build.
/// Stored display-currency preferences remain intact for future overlays.
@riverpod
Future<double?> displayCurrencyRate(Ref ref, String key) async => null;
