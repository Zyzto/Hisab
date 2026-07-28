import 'package:flutter/material.dart';

import '../theme/accent_style.dart';

/// Accent-bar section title used across lists, forms, and group tabs.
class GroupSectionHeader extends StatelessWidget {
  final String label;
  final Widget? trailing;
  final Color? barColor;
  final Color? labelColor;

  const GroupSectionHeader({
    super.key,
    required this.label,
    this.trailing,
    this.barColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedBar =
        barColor ??
        AccentSurfaces.sectionBar(
          theme.colorScheme,
          subtle: context.subtleAccents,
        );
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: resolvedBar,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: labelColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
