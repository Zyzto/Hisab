import 'package:flutter/material.dart';

import '../build_env.dart';

/// Adds the small test-only marker used in place of a staging ribbon.
///
/// The marker is decorative and uses physical left positioning deliberately:
/// it stays at the upper-left corner even when the app is in Arabic/RTL mode.
class TestBuildMarker extends StatelessWidget {
  const TestBuildMarker({
    super.key,
    required this.child,
    this.dotFraction = .22,
  });

  final Widget child;
  final double dotFraction;

  @override
  Widget build(BuildContext context) {
    if (!isStagingBuild) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        final dotSize = (size * dotFraction).clamp(8.0, 24.0);
        final offset = (size * .05).clamp(1.0, 6.0);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned(
              left: offset,
              top: offset,
              width: dotSize,
              height: dotSize,
              child: ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC107),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
