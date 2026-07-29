import 'package:flutter/material.dart';
import 'layout_breakpoints.dart';

/// Wraps [child] so that on tablet-or-wider screens it is centered and
/// constrained to [LayoutBreakpoints.contentMaxWidth]. On narrow screens
/// [child] is returned unchanged.
///
/// When [aside] is provided and the right gutter is wide enough, [aside] is
/// placed outside the main content band (does not shrink the reading column).
class ConstrainedContent extends StatelessWidget {
  const ConstrainedContent({
    super.key,
    required this.child,
    this.aside,
    this.asideMinGutter = 176,
    this.asideWidth = 200,
  });

  final Widget child;

  /// Optional trailing rail (e.g. "On this page") shown beside content when
  /// there is enough unused space to the right of the content band.
  final Widget? aside;

  /// Minimum free width (after the content band) required to show [aside].
  final double asideMinGutter;

  /// Width reserved for [aside] when shown.
  final double asideWidth;

  @override
  Widget build(BuildContext context) {
    if (!LayoutBreakpoints.isTabletOrWider(context)) {
      return child;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentAreaWidth = constraints.maxWidth;
        final (leftOffset, bandWidth) = LayoutBreakpoints.contentBandMetrics(
          context,
          contentAreaWidth,
        );
        final rightFree = (contentAreaWidth - leftOffset - bandWidth).clamp(
          0.0,
          double.infinity,
        );
        final showAside =
            aside != null && rightFree >= asideMinGutter + 8;

        // Force LTR so [leftOffset] stays a physical-left inset and matches
        // [ContentAlignedAppBar] (which uses Positioned.left). A plain Row
        // would flip in RTL and shift the body away from the title.
        return Row(
          textDirection: TextDirection.ltr,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: leftOffset),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bandWidth),
              child: child,
            ),
            if (showAside)
              SizedBox(
                width: asideWidth.clamp(0.0, rightFree),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: aside,
                ),
              ),
            const Expanded(child: SizedBox.shrink()),
          ],
        );
      },
    );
  }
}
