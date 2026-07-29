import 'package:flutter/material.dart';

import 'layout_breakpoints.dart';

/// Positions the scaffold FAB beside the content band on wide layouts
/// (same gutter idea as [ConstrainedContent.aside] / profile page index).
///
/// On narrow screens, or when the end gutter is too tight, falls back to
/// [narrowFallback] (default [FloatingActionButtonLocation.endFloat]).
///
/// Placement follows text direction: end of the content band (right in LTR,
/// left in RTL), matching [FloatingActionButtonLocation.endFloat].
class ContentAlignedFabLocation extends FloatingActionButtonLocation {
  ContentAlignedFabLocation._({
    required this.leftOffset,
    required this.bandWidth,
    required this.textDirection,
  });

  final double leftOffset;
  final double bandWidth;
  final TextDirection textDirection;

  static const double _margin = 16;
  static const double _minGutterForAlign = 88;

  /// Resolve a location from the scaffold's content-area width.
  ///
  /// Pass the same [contentAreaWidth] used for [ContentAlignedAppBar] /
  /// [ConstrainedContent] (typically `LayoutBuilder` max width around the
  /// scaffold).
  static FloatingActionButtonLocation of(
    BuildContext context, {
    required double contentAreaWidth,
    FloatingActionButtonLocation narrowFallback =
        FloatingActionButtonLocation.endFloat,
  }) {
    if (!LayoutBreakpoints.isTabletOrWider(context)) {
      return narrowFallback;
    }
    final (leftOffset, bandWidth) = LayoutBreakpoints.contentBandMetrics(
      context,
      contentAreaWidth,
    );
    final textDirection = Directionality.of(context);
    // Free space on the *end* side of the band (FAB sits there).
    final endFree = textDirection == TextDirection.rtl
        ? leftOffset
        : (contentAreaWidth - leftOffset - bandWidth).clamp(
            0.0,
            double.infinity,
          );
    if (endFree < _minGutterForAlign) {
      return narrowFallback;
    }
    return ContentAlignedFabLocation._(
      leftOffset: leftOffset,
      bandWidth: bandWidth,
      textDirection: textDirection,
    );
  }

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final fabSize = geometry.floatingActionButtonSize;
    final scaffoldSize = geometry.scaffoldSize;

    // Match [FloatingActionButtonLocation.endFloat] vertical placement.
    final y = geometry.contentBottom - _margin - fabSize.height;

    if (textDirection == TextDirection.rtl) {
      final safeLeft = geometry.minInsets.left;
      var x = leftOffset - _margin - fabSize.width;
      final minX = safeLeft + _margin;
      if (x < minX) x = minX;
      if (x < 0) x = 0;
      return Offset(x, y);
    }

    final safeRight = geometry.minInsets.right;
    final contentRight = leftOffset + bandWidth;
    var x = contentRight + _margin;
    final maxX = scaffoldSize.width - _margin - fabSize.width - safeRight;
    if (x > maxX) x = maxX;
    if (x < 0) x = 0;

    return Offset(x, y);
  }

  @override
  String toString() =>
      'ContentAlignedFabLocation(left: $leftOffset, band: $bandWidth, '
      'dir: $textDirection)';
}
