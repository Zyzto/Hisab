import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/utils/form_validators.dart';
import '../../../domain/domain.dart';
import 'category_affordance_chip.dart';

/// Title input with category tag and optional add-photo / scan-receipt actions
/// inline in the field trailing row.
class ExpenseTitleSection extends StatelessWidget {
  final TextEditingController controller;
  final String? selectedTag;
  final List<ExpenseTag> customTags;
  final VoidCallback onTagPicker;
  final VoidCallback? onPickImage;
  final VoidCallback? onScanReceipt;
  final String? Function(String?)? validator;

  const ExpenseTitleSection({
    super.key,
    required this.controller,
    required this.selectedTag,
    required this.customTags,
    required this.onTagPicker,
    this.onPickImage,
    this.onScanReceipt,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'title'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'title_hint'.tr(),
            filled: true,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsetsDirectional.only(
              start: 16,
              end: 4,
              top: 12,
              bottom: 12,
            ),
            counterText: '',
            // Default Material suffix min size is 48×48 and causes big gaps.
            suffixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            suffixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CategoryAffordanceChip(
                    selectedTag: selectedTag,
                    customTags: customTags,
                    onTap: onTagPicker,
                  ),
                  if (onPickImage != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      iconSize: 20,
                      icon: Icon(Icons.camera_alt_outlined, color: iconColor),
                      onPressed: onPickImage,
                      tooltip: 'add_photos'.tr(),
                    ),
                  if (onScanReceipt != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      iconSize: 20,
                      icon: Icon(
                        Icons.document_scanner_outlined,
                        color: iconColor,
                      ),
                      onPressed: onScanReceipt,
                      tooltip: 'scan_receipt'.tr(),
                    ),
                ],
              ),
            ),
          ),
          maxLength: FormValidators.expenseTitleMax,
          validator: validator ?? FormValidators.expenseTitle,
        ),
      ],
    );
  }
}
