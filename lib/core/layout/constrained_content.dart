import 'package:flutter/material.dart';
import 'layout_breakpoints.dart';

/// Wraps [child] so that on tablet-or-wider screens it is centered and
/// constrained to [LayoutBreakpoints.contentMaxWidth]. On narrow screens
/// [child] is returned unchanged.
class ConstrainedContent extends StatelessWidget {
  const ConstrainedContent({super.key, required this.child});

  final Widget child;

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
            const Expanded(child: SizedBox.shrink()),
          ],
        );
      },
    );
  }
}
