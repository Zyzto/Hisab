import 'package:flutter/material.dart';

/// Central breakpoints and helpers for responsive layout (web desktop, tablet).
/// Use width-based checks only; mobile layout is unchanged below [breakpointTablet].
class LayoutBreakpoints {
  LayoutBreakpoints._();

  /// Width at which to show rail navigation and constrain content (tablet).
  static const double breakpointTablet = 600.0;

  /// Width for larger desktop layout (optional; e.g. wider content cap).
  static const double breakpointDesktop = 840.0;

  /// Max content width when on tablet-sized or wider screens.
  static const double contentMaxWidthTablet = 600.0;

  /// Max content width when on desktop-sized or wider screens.
  static const double contentMaxWidthDesktop = 720.0;

  /// Max width for responsive sheets shown as dialogs on wide screens.
  static const double sheetDialogMaxWidth = 560.0;

  /// Width of the navigation rail when extended (used to center dialogs in content area).
  static const double navigationRailWidth = 180.0;

  /// Width of the navigation rail when compact (icons only; Material default).
  static const double navigationRailWidthCompact = 80.0;

  /// Returns the effective navigation rail width for the current context
  /// (extended above [breakpointDesktop], compact between [breakpointTablet] and [breakpointDesktop]).
  static double navigationRailWidthFor(BuildContext context) {
    return isDesktopOrWider(context)
        ? navigationRailWidth
        : navigationRailWidthCompact;
  }

  /// True when width >= [breakpointTablet] (use rail, constrain content, optional sheet-as-dialog).
  static bool isTabletOrWider(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= breakpointTablet;
  }

  /// True when width >= [breakpointDesktop].
  static bool isDesktopOrWider(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= breakpointDesktop;
  }

  /// Returns the max content width to use for the current context.
  static double contentMaxWidth(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= breakpointDesktop
        ? contentMaxWidthDesktop
        : contentMaxWidthTablet;
  }

  /// Returns (leftOffset, contentMaxWidth) so the content band aligns with
  /// [ConstrainedContent]. Use the same [contentAreaWidth] for the app bar
  /// (e.g. from LayoutBuilder around the scaffold) so the title sits in the
  /// same horizontal band as the body. On narrow screens returns (0, contentAreaWidth).
  static (double leftOffset, double contentMaxWidth) contentBandMetrics(
    BuildContext context,
    double contentAreaWidth,
  ) {
    if (!isTabletOrWider(context)) {
      return (0.0, contentAreaWidth);
    }
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final maxW = contentMaxWidth(context);
    final effectiveRailWidth = (viewportWidth - contentAreaWidth) > 5
        ? (viewportWidth - contentAreaWidth)
        : 0.0;
    var leftOffset = (viewportWidth / 2 - maxW / 2 - effectiveRailWidth)
        .clamp(0.0, double.infinity);
    if (leftOffset > contentAreaWidth) leftOffset = 0.0;
    final bandWidth = (contentAreaWidth - leftOffset).clamp(0.0, maxW);
    return (leftOffset, bandWidth);
  }
}
