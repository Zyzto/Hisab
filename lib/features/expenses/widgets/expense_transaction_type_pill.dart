import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../domain/domain.dart';

/// Segmented pill for expense / income / transfer selection.
class ExpenseTransactionTypePill extends StatelessWidget {
  final TransactionType value;
  final ValueChanged<TransactionType> onChanged;

  const ExpenseTransactionTypePill({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _SegmentChip(
            theme: theme,
            label: 'expenses'.tr(),
            selected: value == TransactionType.expense,
            onTap: () => onChanged(TransactionType.expense),
          ),
          _SegmentChip(
            theme: theme,
            label: 'income'.tr(),
            selected: value == TransactionType.income,
            onTap: () => onChanged(TransactionType.income),
          ),
          _SegmentChip(
            theme: theme,
            label: 'transfer'.tr(),
            selected: value == TransactionType.transfer,
            onTap: () => onChanged(TransactionType.transfer),
          ),
        ],
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  final ThemeData theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentChip({
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? theme.colorScheme.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
