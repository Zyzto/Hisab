import 'package:flutter/material.dart';

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
    final onTapEnabled = enabled ? onTap : null;
    final titleColor = destructive
        ? cs.error
        : (enabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.38));
    final subtitleColor = destructive
        ? cs.error.withValues(alpha: 0.8)
        : cs.onSurfaceVariant;

    return Material(
      color: selected
          ? AccentSurfaces.emphasizedFill(cs, subtle: subtle)
          : cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        canRequestFocus: false,
        onTap: onTapEnabled,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AccentSurfaces.emphasizedBorder(cs, subtle: subtle)
                  : cs.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                if (leading != null) ...[
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Center(child: leading!),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UserText(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        UserText(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: subtitleColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Vertical list of [SheetOptionTile]s with consistent gaps.
class SheetOptionList extends StatelessWidget {
  const SheetOptionList({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.spacing = 8,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            children[i],
          ],
        ],
      ),
    );
  }
}
