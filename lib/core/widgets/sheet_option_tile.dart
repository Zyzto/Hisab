import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

import '../theme/accent_style.dart';
import 'user_text.dart';

/// Bordered ink row for sheet action/picker lists (flat-panel language).
class SheetOptionTile extends StatelessWidget {
  const SheetOptionTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.destructive = false,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final bool destructive;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final subtle = context.subtleAccents;
    final titleColor = destructive
        ? cs.error
        : (enabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.38));
    final subtitleColor = destructive
        ? cs.error.withValues(alpha: 0.8)
        : cs.onSurfaceVariant;

    return SafaehOptionTile(
      title: UserText(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: titleColor,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle != null && subtitle!.isNotEmpty
          ? UserText(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(color: subtitleColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      leading: leading,
      trailing: trailing,
      onTap: onTap,
      selected: selected,
      destructive: destructive,
      enabled: enabled,
      selectedFill: AccentSurfaces.emphasizedFill(cs, subtle: subtle),
      selectedBorder: AccentSurfaces.emphasizedBorder(cs, subtle: subtle),
    );
  }
}

/// Vertical list of [SheetOptionTile]s with consistent gaps.
class SheetOptionList extends SafaehOptionList {
  const SheetOptionList({
    super.key,
    required super.children,
    super.padding,
    super.spacing,
  });
}
