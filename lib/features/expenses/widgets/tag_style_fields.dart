import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../category_icons.dart';

/// Icon + color pickers for create/edit custom category sheets.
class TagStyleFields extends StatelessWidget {
  const TagStyleFields({
    super.key,
    required this.selectedIconName,
    required this.selectedColorHex,
    required this.onIconSelected,
    required this.onColorSelected,
  });

  final String selectedIconName;
  final String selectedColorHex;
  final ValueChanged<String> onIconSelected;
  final ValueChanged<String> onColorSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor =
        parseTagColorHex(selectedColorHex) ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('choose_color'.tr(), style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final hex in selectableTagColorHexes)
              Builder(
                builder: (context) {
                  final color = parseTagColorHex(hex)!;
                  final selected =
                      selectedColorHex.toUpperCase() == hex.toUpperCase();
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: hex,
                    child: InkWell(
                      onTap: () => onColorSelected(hex),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.outline
                                    .withValues(alpha: 0.35),
                            width: selected ? 2.5 : 1,
                          ),
                        ),
                        child: selected
                            ? Icon(
                                Icons.check,
                                size: 18,
                                color: contrastingForeground(color),
                              )
                            : null,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('choose_icon'.tr(), style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: selectableCategoryIcons.entries.map((e) {
            final selected = selectedIconName == e.key;
            return Semantics(
              button: true,
              selected: selected,
              label: e.key.replaceAll('_', ' '),
              child: InkWell(
                onTap: () => onIconSelected(e.key),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: selected
                        ? selectedColor
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? selectedColor
                          : theme.colorScheme.outline.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    e.value,
                    size: 28,
                    color: selected
                        ? contrastingForeground(selectedColor)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
