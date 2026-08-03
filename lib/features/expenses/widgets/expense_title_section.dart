import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/utils/form_validators.dart';
import '../../../domain/domain.dart';
import '../category_icons.dart';
import '../constants/expense_form_constants.dart';

/// Title input with category tag and optional add-photo / scan-receipt actions.
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
    final preset = selectedTag != null
        ? presetExpenseTags.where((p) => p.id == selectedTag).firstOrNull
        : null;
    final customTag = selectedTag != null
        ? customTags.where((t) => t.id == selectedTag).firstOrNull
        : null;
    final tagLabel = preset != null
        ? 'category_${preset.id}'.tr()
        : (customTag != null ? customTag.label : selectedTag);
    final tagIcon = preset != null
        ? preset.icon
        : (customTag != null
              ? (selectableExpenseIcons[customTag.iconName] ??
                    Icons.label_outlined)
              : Icons.label_outlined);

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
            hintText: 'title'.tr(),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            counterText: '',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    tagIcon,
                    color: selectedTag != null
                        ? chromeForExpenseTag(
                            selectedTag,
                            brightness: theme.brightness,
                            surface: theme.colorScheme.surface,
                          ).onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onTagPicker,
                  tooltip: tagLabel ?? 'category'.tr(),
                ),
                if (onPickImage != null)
                  IconButton(
                    icon: Icon(
                      Icons.camera_alt_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: onPickImage,
                    tooltip: 'add_photos'.tr(),
                  ),
                if (onScanReceipt != null)
                  IconButton(
                    icon: Icon(
                      Icons.document_scanner_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: onScanReceipt,
                    tooltip: 'scan_receipt'.tr(),
                  ),
              ],
            ),
          ),
          maxLength: FormValidators.expenseTitleMax,
          validator: validator ?? FormValidators.expenseTitle,
        ),
      ],
    );
  }
}
