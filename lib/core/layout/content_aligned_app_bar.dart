import 'package:flutter/material.dart';
import 'layout_breakpoints.dart';

/// An app bar that places [title] in the same horizontal band as body content
/// wrapped in [ConstrainedContent], so the title aligns with the content below.
///
/// Wrap the scaffold in [LayoutBuilder] and pass [LayoutBuilder]'s
/// `constraints.maxWidth` as [contentAreaWidth] so the band matches the body.
class ContentAlignedAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ContentAlignedAppBar({
    super.key,
    required this.contentAreaWidth,
    this.leading,
    required this.title,
    this.actions,
  });

  final double contentAreaWidth;
  final Widget? leading;
  final Widget title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarTheme = theme.appBarTheme;
    final (leftOffset, bandWidth) =
        LayoutBreakpoints.contentBandMetrics(context, contentAreaWidth);

    final titleStyle = (appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge)
            ?.copyWith(
                  color: appBarTheme.foregroundColor ??
                      theme.colorScheme.onSurface,
                ) ??
        (theme.textTheme.titleLarge ?? theme.textTheme.bodyLarge!);

    return Material(
      color: appBarTheme.backgroundColor ?? theme.colorScheme.surface,
      elevation: appBarTheme.elevation ?? 0,
      surfaceTintColor: appBarTheme.surfaceTintColor,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  leading ?? const SizedBox.shrink(),
                  const Spacer(),
                  ...(actions ?? []),
                ],
              ),
              Positioned(
                left: leftOffset,
                top: 0,
                bottom: 0,
                width: bandWidth,
                child: Center(
                  child: DefaultTextStyle(
                    style: titleStyle,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: title,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
