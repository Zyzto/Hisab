import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

import 'layout_breakpoints.dart';

/// Wraps [child] so that on tablet-or-wider screens it is centered and
/// constrained to [LayoutBreakpoints.contentMaxWidth]. On narrow screens
/// [child] is returned unchanged.
///
/// Band metrics stay in Hisab: they compensate for the sibling shell rail so
/// the column aligns with the app bar. Other apps should use
/// [SafaehContentBand], which centers from incoming constraints only.
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
  final Widget? aside;
  final double asideMinGutter;
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
        return SafaehEndAsideLayout(
          leftOffset: leftOffset,
          bandWidth: bandWidth,
          aside: aside,
          endFree: LayoutBreakpoints.endGutterWidth(context, contentAreaWidth),
          isRtl: Directionality.of(context) == TextDirection.rtl,
          asideMinGutter: asideMinGutter,
          asideWidth: asideWidth,
          child: child,
        );
      },
    );
  }
}
