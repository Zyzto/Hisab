import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/expense_form_constants.dart';

/// Amount input with currency selector.
class ExpenseAmountSection extends StatelessWidget {
  final TextEditingController controller;
  final String currencyCode;
  final String? Function(String?)? validator;

  const ExpenseAmountSection({
    super.key,
    required this.controller,
    required this.currencyCode,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            Container(
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
                  Text(currencyCode, style: theme.textTheme.titleMedium),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
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
                validator: validator ??
                    (v) {
                      if (v == null || v.trim().isEmpty) return 'required'.tr();
                      if (double.tryParse(v) == null) return 'invalid_number'.tr();
                      return null;
                    },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
