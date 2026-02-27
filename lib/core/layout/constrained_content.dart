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
        return Row(
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
