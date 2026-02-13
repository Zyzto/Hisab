import 'dart:io' show Platform;
import 'package:currency_picker/currency_picker.dart';

/// Thin wrapper around [currency_picker] package for app-wide currency utilities.
class CurrencyHelpers {
  CurrencyHelpers._();

  static final _service = CurrencyService();

  /// Currencies to show at the top of the picker (favorites).
  static const favoriteCurrencies = ['SAR'];

  /// Symbol overrides for currencies whose bundled symbol is outdated.
  /// SAR: the package ships "﷼" (U+FDFC, generic Rial sign) but the official
  /// Saudi Riyal symbol is U+20C1 (SAUDI RIYAL SIGN), approved in Unicode 17.0
  /// (September 2025) by royal directive. See:
  /// https://www.sama.gov.sa/en-US/Currency/SRS/Pages/default.aspx
  static const _symbolOverrides = <String, String>{
    'SAR': '\u20C1',
  };

  /// Placement overrides: true = symbol on left, false = symbol on right.
  /// SAMA guidelines: "The symbol should be positioned to the left of the
  /// numeral" with "A space required between the symbol and the numeral."
  static const _symbolOnLeftOverrides = <String, bool>{
    'SAR': true,
  };

  /// Get the correct display symbol for a currency code,
  /// applying any local overrides.
  static String symbolFor(String code) {
    return _symbolOverrides[code.toUpperCase()] ??
        fromCode(code)?.symbol ??
        code;
  }

  /// Whether the symbol should be placed on the left of the numeral.
  /// Checks overrides first, then falls back to the package data.
  static bool symbolOnLeft(String code) {
    return _symbolOnLeftOverrides[code.toUpperCase()] ??
        fromCode(code)?.symbolOnLeft ??
        true;
  }

  /// Look up a [Currency] by its ISO 4217 code (e.g. "USD", "SAR").
  /// Returns `null` if not found.
  static Currency? fromCode(String code) {
    try {
      return _service.findByCode(code.toUpperCase());
    } catch (_) {
      return null;
    }
  }

  /// Detect the user's likely default currency based on device locale.
  /// Falls back to USD if detection fails.
  static Currency defaultCurrencyForLocale() {
    try {
      final locale = Platform.localeName; // e.g. "en_US", "ar_SA"
      final parts = locale.split('_');
      if (parts.length >= 2) {
        final countryCode = parts.last.toUpperCase();
        final match = _countryToCurrency[countryCode];
        if (match != null) {
          final currency = fromCode(match);
          if (currency != null) return currency;
        }
      }
    } catch (_) {}
    // USD will always be found in the bundled currency data
    return _service.findByCode('USD')!;
  }

  /// Formatted display label: "USD - US Dollar ($)" or "SAR - Saudi Arabia Riyal (ر.س)"
  static String displayLabel(Currency c) {
    final symbol = _symbolOverrides[c.code] ?? c.symbol;
    return '${c.code} - ${c.name} ($symbol)';
  }

  /// Short display: flag + code, e.g. "🇺🇸 USD"
  static String shortLabel(Currency c) {
    final flag = CurrencyUtils.currencyToEmoji(c);
    return '$flag ${c.code}';
  }

  /// Map common country codes (ISO 3166-1 alpha-2) to currency codes.
  static const _countryToCurrency = <String, String>{
    'US': 'USD',
    'GB': 'GBP',
    'EU': 'EUR',
    'JP': 'JPY',
    'CN': 'CNY',
    'IN': 'INR',
    'SA': 'SAR',
    'AE': 'AED',
    'EG': 'EGP',
    'KW': 'KWD',
    'BH': 'BHD',
    'QA': 'QAR',
    'OM': 'OMR',
    'JO': 'JOD',
    'LB': 'LBP',
    'IQ': 'IQD',
    'SY': 'SYP',
    'YE': 'YER',
    'MA': 'MAD',
    'TN': 'TND',
    'DZ': 'DZD',
    'LY': 'LYD',
    'SD': 'SDG',
    'TR': 'TRY',
    'PK': 'PKR',
    'BD': 'BDT',
    'ID': 'IDR',
    'MY': 'MYR',
    'TH': 'THB',
    'KR': 'KRW',
    'AU': 'AUD',
    'NZ': 'NZD',
    'CA': 'CAD',
    'MX': 'MXN',
    'BR': 'BRL',
    'AR': 'ARS',
    'CL': 'CLP',
    'CO': 'COP',
    'PE': 'PEN',
    'ZA': 'ZAR',
    'NG': 'NGN',
    'KE': 'KES',
    'GH': 'GHS',
    'RU': 'RUB',
    'UA': 'UAH',
    'PL': 'PLN',
    'CZ': 'CZK',
    'HU': 'HUF',
    'RO': 'RON',
    'SE': 'SEK',
    'NO': 'NOK',
    'DK': 'DKK',
    'CH': 'CHF',
    'SG': 'SGD',
    'HK': 'HKD',
    'TW': 'TWD',
    'PH': 'PHP',
    'VN': 'VND',
    // Eurozone countries
    'DE': 'EUR',
    'FR': 'EUR',
    'IT': 'EUR',
    'ES': 'EUR',
    'NL': 'EUR',
    'BE': 'EUR',
    'AT': 'EUR',
    'PT': 'EUR',
    'IE': 'EUR',
    'FI': 'EUR',
    'GR': 'EUR',
    'SK': 'EUR',
    'SI': 'EUR',
    'LT': 'EUR',
    'LV': 'EUR',
    'EE': 'EUR',
    'CY': 'EUR',
    'MT': 'EUR',
    'LU': 'EUR',
    'HR': 'EUR',
  };
}
