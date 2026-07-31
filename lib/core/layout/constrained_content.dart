import 'package:flutter/material.dart';
import 'layout_breakpoints.dart';

/// Wraps [child] so that on tablet-or-wider screens it is centered and
/// constrained to [LayoutBreakpoints.contentMaxWidth]. On narrow screens
/// [child] is returned unchanged.
///
/// When [aside] is provided and the **end** gutter is wide enough, [aside] is
/// placed immediately beside the main content band (does not shrink the reading
/// column). End = right in LTR, left in RTL.
class ConstrainedContent extends StatelessWidget {
  const ConstrainedContent({
    super.key,
    required this.child,
    this.aside,
    this.asideMinGutter = 176,
    this.asideWidth = 200,
  });

  final Widget child;

  /// Optional trailing rail (e.g. "On this page") shown flush beside content
  /// when there is enough unused space on the end side of the content band.
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
        final isRtl = Directionality.of(context) == TextDirection.rtl;
        final endFree = LayoutBreakpoints.endGutterWidth(
          context,
          contentAreaWidth,
        );
        final showAside =
            aside != null && endFree >= asideMinGutter + 8;
        final asideW = showAside
            ? asideWidth.clamp(0.0, endFree)
            : 0.0;

        Widget asideRail() => SizedBox(
              width: asideW,
              child: Align(
                alignment: Alignment.topCenter,
                child: aside,
              ),
            );

        // Force LTR so [leftOffset] stays a physical-left inset and matches
        // [ContentAlignedAppBar] (which uses Positioned.left). A plain Row
        // would flip in RTL and shift the body away from the title.
        //
        // Keep [aside] flush against the content band on the end side:
        // LTR: [lead][content][aside][trail]
        // RTL: [lead][aside][content][trail]  (aside immediately before content)
        return Row(
          textDirection: TextDirection.ltr,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: isRtl && showAside
                  ? (leftOffset - asideW).clamp(0.0, double.infinity)
                  : leftOffset,
            ),
            if (isRtl && showAside) asideRail(),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bandWidth),
              child: child,
            ),
            if (!isRtl && showAside) asideRail(),
            const Expanded(child: SizedBox.shrink()),
          ],
        );
      },
    );
  }
}
