import 'package:currency_picker/currency_picker.dart';
// ignore: implementation_imports
import 'package:currency_picker/src/currency_list_view.dart';
import 'package:flutter/material.dart';

/// Thin wrapper around [currency_picker] package for app-wide currency utilities.
class CurrencyHelpers {
  CurrencyHelpers._();

  static final _service = CurrencyService();

  /// Default currencies pinned at the top of the picker.
  static const defaultFavoriteCurrencies = ['SAR', 'JPY', 'CNY', 'EUR', 'USD'];

  /// Returns the effective favorite currencies list.
  /// If [userFavorites] (comma-separated codes from settings) is non-empty,
  /// it overrides the default list. Otherwise the default is used.
  static List<String> getEffectiveFavorites(String userFavorites) {
    if (userFavorites.trim().isEmpty) return defaultFavoriteCurrencies;
    return userFavorites
        .split(',')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Encode a list of currency codes to a comma-separated string for storage.
  static String encodeFavorites(List<String> codes) => codes.join(',');

  /// Look up a [Currency] by its ISO 4217 code (e.g. "USD", "SAR").
  /// Returns `null` if not found.
  static Currency? fromCode(String code) {
    try {
      return _service.findByCode(code.toUpperCase());
    } catch (_) {
      return null;
    }
  }

  /// Default currency for all users: SAR.
  static Currency defaultCurrency() {
    return _service.findByCode('SAR')!;
  }

  /// Formatted display label: "USD - US Dollar ($)" or "SAR - Saudi Riyal (﷼)"
  static String displayLabel(Currency c) {
    return '${c.code} - ${c.name} (${c.symbol})';
  }

  /// Short display: flag + code, e.g. "🇺🇸 USD"
  static String shortLabel(Currency c) {
    final flag = CurrencyUtils.currencyToEmoji(c);
    return '$flag ${c.code}';
  }

  /// Show a currency picker bottom sheet with a drag handle and 75% max height.
  /// Drop-in replacement for [showCurrencyPicker] with consistent UX.
  static void showPicker({
    required BuildContext context,
    required ValueChanged<Currency> onSelect,
    List<String>? favorite,
    List<String>? currencyFilter,
  }) {
    final maxHeight = MediaQuery.of(context).size.height * 0.75;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(maxHeight: maxHeight),
      builder: (_) => CurrencyListView(
        onSelect: (currency) {
          // CurrencyListView already calls Navigator.pop internally after
          // onSelect, so we must NOT pop here to avoid a double-pop that
          // would dismiss the parent page route.
          onSelect(currency);
        },
        favorite: favorite,
        currencyFilter: currencyFilter,
        showFlag: true,
        showSearchField: true,
        showCurrencyName: true,
        showCurrencyCode: true,
      ),
    );
  }
}
