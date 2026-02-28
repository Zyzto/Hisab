import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/utils/currency_helpers.dart';
import '../../../core/utils/form_validators.dart';
import '../constants/expense_form_constants.dart';

/// Amount input with tappable currency selector and optional exchange rate section.
class ExpenseAmountSection extends StatelessWidget {
  final TextEditingController controller;
  final String currencyCode;
  final String? Function(String?)? validator;
  final VoidCallback? onCurrencyTap;

  /// Group's base currency code (shown in exchange rate section).
  final String? groupCurrencyCode;

  /// Exchange rate controller (editable, e.g. "39.5").
  final TextEditingController? exchangeRateController;

  /// Converted amount in group currency (editable, e.g. "126.58").
  final TextEditingController? baseAmountController;

  /// Whether exchange rate is currently being fetched from API.
  final bool fetchingRate;

  /// Called when the exchange rate field is edited by the user.
  final ValueChanged<String>? onExchangeRateChanged;

  /// Called when the base amount field is edited by the user.
  final ValueChanged<String>? onBaseAmountChanged;

  const ExpenseAmountSection({
    super.key,
    required this.controller,
    required this.currencyCode,
    this.validator,
    this.onCurrencyTap,
    this.groupCurrencyCode,
    this.exchangeRateController,
    this.baseAmountController,
    this.fetchingRate = false,
    this.onExchangeRateChanged,
    this.onBaseAmountChanged,
  });

  bool get _showExchangeRate =>
      groupCurrencyCode != null &&
      groupCurrencyCode != currencyCode &&
      exchangeRateController != null &&
      baseAmountController != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = CurrencyHelpers.fromCode(currencyCode);
    final currencyLabel = currency != null
        ? CurrencyHelpers.shortLabel(currency)
        : currencyCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'amount'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onCurrencyTap,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: AlignmentDirectional.centerStart,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(currencyLabel, style: theme.textTheme.titleMedium),
                    if (onCurrencyTap != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: '0',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [decimalOnlyFormatter],
                validator:
                    validator ??
                    (v) {
                      final requiredErr = FormValidators.required(v);
                      if (requiredErr != null) return requiredErr;
                      if (double.tryParse(v!) == null) {
                        return 'invalid_number'.tr();
                      }
                      return null;
                    },
              ),
            ),
          ],
        ),
        if (_showExchangeRate) ...[
          const SizedBox(height: 16),
          _buildExchangeRateSection(context, theme),
        ],
      ],
    );
  }

  Widget _buildExchangeRateSection(BuildContext context, ThemeData theme) {
    final groupCurrency = CurrencyHelpers.fromCode(groupCurrencyCode!);
    final groupLabel = groupCurrency != null
        ? CurrencyHelpers.shortLabel(groupCurrency)
        : groupCurrencyCode!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exchange rate row
          Row(
            children: [
              Text(
                'exchange_rate'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (fetchingRate)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '1 ${groupCurrencyCode!} =',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: TextFormField(
                  controller: exchangeRateController,
                  decoration: InputDecoration(
                    filled: true,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [decimalOnlyFormatter],
                  onChanged: onExchangeRateChanged,
                ),
              ),
              const SizedBox(width: 8),
              Text(currencyCode, style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 12),
          // Converted amount row
          Text(
            'converted_amount'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(groupLabel, style: theme.textTheme.bodyMedium),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: baseAmountController,
                  decoration: InputDecoration(
                    hintText: '0',
                    filled: true,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [decimalOnlyFormatter],
                  onChanged: onBaseAmountChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
