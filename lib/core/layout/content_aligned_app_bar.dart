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
    this.leadingWidth,
    required this.title,
    this.actions,
    this.centerTitle = true,
  });

  final double contentAreaWidth;
  final Widget? leading;

  /// Horizontal space reserved for [leading] when computing title insets.
  /// Defaults to [kToolbarHeight] when [leading] is non-null.
  final double? leadingWidth;

  final Widget title;
  final List<Widget>? actions;

  /// When true (default), the title is centered in the content band with
  /// symmetric insets. When false, the title is start-aligned (LTR/RTL) and
  /// can use the full space between leading and actions before truncating.
  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarTheme = theme.appBarTheme;
    final (leftOffset, bandWidth) = LayoutBreakpoints.contentBandMetrics(
      context,
      contentAreaWidth,
    );

    final titleStyle =
        (appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge)?.copyWith(
          color: appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,
        ) ??
        (theme.textTheme.titleLarge ?? theme.textTheme.bodyLarge!);

    final leadingReservedWidth = leading != null
        ? (leadingWidth ?? kToolbarHeight)
        : 0.0;
    final actionsReservedWidth =
        (actions?.length ?? 0) * kToolbarHeight.toDouble();
    const titleButtonGap = 8.0;

    final double titleStartInset;
    final double titleEndInset;
    if (centerTitle) {
      // Symmetric insets keep the title centered despite leading/actions skew.
      final symmetricInset =
          (leadingReservedWidth > actionsReservedWidth
                  ? leadingReservedWidth
                  : actionsReservedWidth) +
              titleButtonGap;
      final inset = symmetricInset.clamp(0.0, bandWidth / 2).toDouble();
      titleStartInset = inset;
      titleEndInset = inset;
    } else {
      titleStartInset = leadingReservedWidth + titleButtonGap;
      titleEndInset = actionsReservedWidth + titleButtonGap;
    }

    // Keep toolbar controls off the screen edges (esp. next to a nav rail).
    const edgePadding = 12.0;

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
              // Fill the toolbar height so leading/actions center with the title.
              // A bare Row is only as tall as its icons and would sit at the
              // Stack's default top alignment (looks "pushed up" on group pages).
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (leading != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: edgePadding,
                        ),
                        child: leading,
                      )
                    else
                      const SizedBox.shrink(),
                    const Spacer(),
                    if (actions != null && actions!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: edgePadding,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: actions!,
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                left: leftOffset,
                top: 0,
                bottom: 0,
                width: bandWidth,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: titleStartInset,
                    end: titleEndInset,
                  ),
                  child: DefaultTextStyle(
                    style: titleStyle,
                    // Do not scale titles down (hurts readability on phones).
                    // Titles get the band max width; use ellipsis / elision in
                    // the title widget.
                    child: centerTitle
                        ? Center(child: title)
                        : Align(
                            alignment: AlignmentDirectional.centerStart,
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
