import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Fetches live exchange rates from ExchangeRate-API (open access, 150+ currencies, no key).
/// Caches responses for 24 hours in SharedPreferences.
/// Falls back to cached data when offline; returns `null` if no cache exists.
class ExchangeRateService {
  ExchangeRateService();

  static const _baseUrl = 'https://open.er-api.com/v6/latest';
  static const _cacheDuration = Duration(hours: 24);
  static const _cachePrefix = 'exchange_rates_';
  static const _cacheTimestampPrefix = 'exchange_rates_ts_';

  /// Get the exchange rate: how many units of [fromCode] equal 1 unit of [toCode].
  ///
  /// Example: group currency = SAR, expense currency = JPY
  ///   `getRate('JPY', 'SAR')` -> returns ~41.15 (meaning 1 SAR = 41.15 JPY)
  ///
  /// Returns `null` if the rate cannot be fetched and no cache is available.
  Future<double?> getRate(String fromCode, String toCode) async {
    if (fromCode == toCode) return 1.0;

    final rates = await _fetchRates(toCode.toUpperCase());
    if (rates == null) return null;

    final rate = rates[fromCode.toUpperCase()];
    return rate?.toDouble();
  }

  /// Fetch all rates for a given base currency.
  /// Tries network first, then cache.
  Future<Map<String, dynamic>?> _fetchRates(String baseCurrency) async {
    // Check cache first
    final cached = await _getCachedRates(baseCurrency);
    if (cached != null) return cached;

    // Fetch from API
    try {
      final url = Uri.parse('$_baseUrl/$baseCurrency');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['result'] == 'success') {
          final rates = data['rates'] as Map<String, dynamic>;
          await _cacheRates(baseCurrency, rates);
          return rates;
        }
      }

      if (kDebugMode) {
        Log.debug(
          'ExchangeRate API returned status ${response.statusCode}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        Log.debug('ExchangeRate fetch error: $e');
      }
    }

    // Fallback to expired cache if network fails
    return _getCachedRates(baseCurrency, ignoreExpiry: true);
  }

  Future<Map<String, dynamic>?> _getCachedRates(
    String baseCurrency, {
    bool ignoreExpiry = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_cachePrefix$baseCurrency';
      final tsKey = '$_cacheTimestampPrefix$baseCurrency';

      final cachedJson = prefs.getString(key);
      final cachedTs = prefs.getInt(tsKey);

      if (cachedJson == null || cachedTs == null) return null;

      if (!ignoreExpiry) {
        final cachedTime = DateTime.fromMillisecondsSinceEpoch(cachedTs);
        if (DateTime.now().difference(cachedTime) > _cacheDuration) {
          return null; // Cache expired, try network
        }
      }

      return jsonDecode(cachedJson) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheRates(
    String baseCurrency,
    Map<String, dynamic> rates,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_cachePrefix$baseCurrency';
      final tsKey = '$_cacheTimestampPrefix$baseCurrency';

      await prefs.setString(key, jsonEncode(rates));
      await prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Caching failure is not critical
    }
  }
}
