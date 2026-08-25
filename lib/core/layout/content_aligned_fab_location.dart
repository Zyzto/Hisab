import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

import 'layout_breakpoints.dart';

/// Positions the scaffold FAB beside the content band on wide layouts
/// (same gutter idea as [ConstrainedContent.aside] / profile page index).
///
/// On narrow screens, or when the end gutter is too tight, falls back to
/// [narrowFallback] (default [FloatingActionButtonLocation.endFloat]).
///
/// Placement follows text direction: end of the content band (right in LTR,
/// left in RTL), matching [FloatingActionButtonLocation.endFloat].
class ContentAlignedFabLocation extends SafaehContentAlignedFabLocation {
  ContentAlignedFabLocation._({
    required super.leftOffset,
    required super.bandWidth,
    required super.textDirection,
  });

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
    if (endFree < SafaehContentAlignedFabLocation.minGutterForAlign) {
      return narrowFallback;
    }
    return ContentAlignedFabLocation._(
      leftOffset: leftOffset,
      bandWidth: bandWidth,
      textDirection: textDirection,
    );
  }

  // Scaffold restarts the FAB move (scale/rotate) animation when
  // `floatingActionButtonLocation != oldLocation`. Without value equality,
  // a fresh instance from [of] on every rebuild (list options, selection,
  // hold-to-reorder parent rebuilds) makes the FAB pulse in place.
  @override
  bool operator ==(Object other) {
    return other is ContentAlignedFabLocation &&
        other.leftOffset == leftOffset &&
        other.bandWidth == bandWidth &&
        other.textDirection == textDirection;
  }

  @override
  int get hashCode => Object.hash(leftOffset, bandWidth, textDirection);

  @override
  String toString() =>
      'ContentAlignedFabLocation(left: $leftOffset, band: $bandWidth, '
      'dir: $textDirection)';
}
