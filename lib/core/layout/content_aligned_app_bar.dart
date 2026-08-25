import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

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
    final (leftOffset, bandWidth) = LayoutBreakpoints.contentBandMetrics(
      context,
      contentAreaWidth,
    );

    return SafaehContentAlignedAppBar(
      leftOffset: leftOffset,
      bandWidth: bandWidth,
      leading: leading,
      leadingWidth: leadingWidth,
      title: title,
      actions: actions,
      centerTitle: centerTitle,
    );
  }
}
