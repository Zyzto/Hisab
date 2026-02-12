import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../domain/domain.dart';
import '../constants/expense_form_constants.dart';

/// Bill breakdown: list of line items (description + amount) with add/remove.
class ExpenseBillBreakdownSection extends StatelessWidget {
  final List<ReceiptLineItem> lineItems;
  final List<({TextEditingController desc, TextEditingController amount})>
  lineItemControllers;
  final VoidCallback onAddItem;
  final void Function(int index) onRemoveItem;
  final void Function(int index, String description, int amountCents)
  onItemChanged;

  const ExpenseBillBreakdownSection({
    super.key,
    required this.lineItems,
    required this.lineItemControllers,
    required this.onAddItem,
    required this.onRemoveItem,
    required this.onItemChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'bill_breakdown'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onAddItem,
              icon: const Icon(Icons.add, size: 20),
              label: Text('add_item'.tr()),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...(lineItems.isEmpty
            ? [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'bill_breakdown_hint'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ]
            : List.generate(lineItems.length, (i) {
                final descCtrl = lineItemControllers[i].desc;
                final amountCtrl = lineItemControllers[i].amount;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: descCtrl,
                          decoration: InputDecoration(
                            hintText: 'item_description'.tr(),
                            isDense: true,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          onChanged: (v) {
                            final cents =
                                ((double.tryParse(amountCtrl.text) ?? 0) * 100)
                                    .round();
                            onItemChanged(i, v.trim(), cents);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          controller: amountCtrl,
                          decoration: const InputDecoration(
                            hintText: '0',
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [decimalOnlyFormatter],
                          onChanged: (v) {
                            final cents = ((double.tryParse(v) ?? 0) * 100)
                                .round();
                            onItemChanged(i, descCtrl.text.trim(), cents);
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: theme.colorScheme.error,
                        ),
                        onPressed: () => onRemoveItem(i),
                      ),
                    ],
                  ),
                );
              })),
      ],
    );
  }
}
