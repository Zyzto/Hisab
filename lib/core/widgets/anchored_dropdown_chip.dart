import 'package:flutter/material.dart';

/// One row in an [AnchoredDropdownChip] menu.
class AnchoredDropdownOption<T> {
  const AnchoredDropdownOption({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// Tag-styled chip that opens an anchored menu under the button (not a sheet).
class AnchoredDropdownChip<T> extends StatelessWidget {
  const AnchoredDropdownChip({
    super.key,
    required this.icon,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final List<AnchoredDropdownOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  /// When true, chip uses the emphasized (selected-filter) look.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return MenuAnchor(
      // Let the tap reach another chip so it can open in the same gesture.
      consumeOutsideTap: false,
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHigh),
        elevation: const WidgetStatePropertyAll(8),
        shadowColor: WidgetStatePropertyAll(
          cs.shadow.withValues(alpha: 0.28),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        ),
        maximumSize: WidgetStatePropertyAll(
          Size(280, MediaQuery.sizeOf(context).height * 0.45),
        ),
      ),
      alignmentOffset: const Offset(0, 8),
      builder: (context, controller, _) {
        final bg = active
            ? cs.primaryContainer
            : cs.surfaceContainerHighest.withValues(alpha: 0.65);
        final fg = active ? cs.onPrimaryContainer : cs.onSurface;
        final iconColor =
            active ? cs.onPrimaryContainer : cs.onSurfaceVariant;

        return Material(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            child: Container(
              padding: const EdgeInsetsDirectional.only(
                start: 14,
                end: 10,
                top: 10,
                bottom: 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: active
                      ? cs.primary.withValues(alpha: 0.35)
                      : cs.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: iconColor),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: fg,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    controller.isOpen
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: iconColor,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      menuChildren: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          MenuItemButton(
            leadingIcon: options[i].icon == null
                ? null
                : Icon(
                    options[i].icon,
                    size: 20,
                    color: options[i].value == selected
                        ? cs.primary
                        : cs.onSurfaceVariant,
                  ),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (options[i].value == selected) {
                  return cs.primaryContainer.withValues(alpha: 0.65);
                }
                return null;
              }),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            onPressed: () => onSelected(options[i].value),
            child: Text(
              options[i].label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: options[i].value == selected
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: options[i].value == selected
                    ? cs.onPrimaryContainer
                    : null,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
