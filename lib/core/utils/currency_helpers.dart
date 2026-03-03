import 'package:currency_picker/currency_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../layout/responsive_sheet.dart';
import '../widgets/currency_picker_list.dart';

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

  /// Divisor to convert whole units to smallest unit (cents).
  /// Aligns with [CurrencyFormatter]: 0 -> 1, 1 -> 10, 2 -> 100, 3 -> 1000.
  static int divisorForDecimalDigits(int decimalDigits) {
    switch (decimalDigits) {
      case 0:
        return 1;
      case 1:
        return 10;
      case 3:
        return 1000;
      default:
        return 100;
    }
  }

  /// Show a currency picker bottom sheet with 75% max height.
  /// Drop-in replacement for [showCurrencyPicker] with consistent UX.
  ///
  /// [centerInFullViewport]: when true (e.g. from group settings), the dialog
  /// is centered in the full viewport on tablet+; when false (e.g. from app
  /// settings), it is centered in the content area to the right of the nav rail.
  /// [title]: when set (e.g. from app settings), used as the sheet title;
  /// otherwise uses 'select_currency'.tr().
  static void showPicker({
    required BuildContext context,
    required ValueChanged<Currency> onSelect,
    List<String>? favorite,
    List<String>? currencyFilter,
    bool centerInFullViewport = true,
    String? title,
  }) {
    final maxHeight = MediaQuery.of(context).size.height * 0.75;
    showResponsiveSheet<void>(
      context: context,
      title: title ?? 'select_currency'.tr(),
      maxHeight: maxHeight,
      isScrollControlled: true,
      useSafeArea: true,
      centerInFullViewport: centerInFullViewport,
      child: Builder(
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).padding.bottom + 24,
          ),
          child: AppCurrencyPickerList(
            onSelect: (currency) {
              onSelect(currency);
              // Do not pop here: AppCurrencyPickerList already calls Navigator.pop(context)
              // when a row is tapped. A second pop (e.g. rootNavigator: true) would pop
              // the route under the dialog (e.g. settings) and cause "popped the last page".
            },
            favorite: favorite,
            currencyFilter: currencyFilter,
            showFlag: true,
            showSearchField: true,
            showCurrencyName: true,
            showCurrencyCode: true,
          ),
        ),
      ),
    );
  }
}
