import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/utils/form_validators.dart';
import '../../../domain/domain.dart';
import '../constants/expense_form_constants.dart';

/// Title input with category tag button and optional add-photos button.
/// When [onPickReceipt] is null, the camera button is hidden (e.g. when Photos section is visible).
class ExpenseTitleSection extends StatelessWidget {
  final TextEditingController controller;
  final String? selectedTag;
  final List<ExpenseTag> customTags;
  final VoidCallback onTagPicker;
  final VoidCallback? onPickReceipt;
  final String? Function(String?)? validator;

  const ExpenseTitleSection({
    super.key,
    required this.controller,
    required this.selectedTag,
    required this.customTags,
    required this.onTagPicker,
    this.onPickReceipt,
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
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    tagIcon,
                    color: selectedTag != null
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onTagPicker,
                  tooltip: tagLabel ?? 'category'.tr(),
                ),
                if (onPickReceipt != null)
                  IconButton(
                    icon: Icon(
                      Icons.camera_alt_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: onPickReceipt,
                    tooltip: 'add_photos'.tr(),
                  ),
              ],
            ),
          ),
          validator: validator ?? FormValidators.required,
        ),
      ],
    );
  }
}
