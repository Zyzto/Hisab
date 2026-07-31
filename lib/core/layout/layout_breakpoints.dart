import 'package:flutter/material.dart';

/// Central breakpoints and helpers for responsive layout (web desktop, tablet).
/// Use width-based checks only; mobile layout is unchanged below [breakpointTablet].
class LayoutBreakpoints {
  LayoutBreakpoints._();

  /// Width at which to show tablet layouts (temporary shell drawer, constrained content).
  static const double breakpointTablet = 600.0;

  /// Width for larger desktop layout (permanent sidenav, wider content cap).
  static const double breakpointDesktop = 840.0;

  /// Max content width when on tablet-sized or wider screens.
  static const double contentMaxWidthTablet = 600.0;

  /// Max content width when on desktop-sized or wider screens.
  static const double contentMaxWidthDesktop = 720.0;

  /// Max width for responsive sheets shown as dialogs on wide screens.
  static const double sheetDialogMaxWidth = 560.0;

  /// Width of the permanent shell sidenav on desktop (MUI-style drawer width).
  static const double shellNavWidth = 240.0;

  /// Collapsed (icons-only) permanent sidenav width on desktop.
  static const double shellNavWidthCompact = 72.0;

  /// Alias for [shellNavWidth] (historical name used by sheet centering).
  static const double navigationRailWidth = shellNavWidth;

  /// Former compact rail width; mid band no longer reserves space (temporary drawer).
  @Deprecated(
    'Use shellNavWidthCompact for desktop collapse; mid band reserves 0.',
  )
  static const double navigationRailWidthCompact = shellNavWidthCompact;

  /// Duration for shell sidenav width morph (mid↔desktop, expand/collapse).
  static const Duration shellNavMorphDuration = Duration(milliseconds: 280);

  /// Returns the reserved shell nav width for layout / dialog centering.
  ///
  /// Prefer [ShellNavLayout.reservedWidth] when set by the shell (tracks
  /// collapse). Fallback: full width on desktop, **0** below desktop.
  static double navigationRailWidthFor(BuildContext context) {
    return shellNavWidthFor(context);
  }

  /// Same as [navigationRailWidthFor].
  static double shellNavWidthFor(BuildContext context) {
    // Imported lazily via callback in responsive_sheet to avoid cycles;
    // callers that need live width should read ShellNavLayout.reservedWidth.
    return isDesktopOrWider(context) ? shellNavWidth : 0.0;
  }

  /// True when width >= [breakpointTablet] (tablet layouts, sheet-as-dialog, etc.).
  static bool isTabletOrWider(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= breakpointTablet;
  }

  /// True when width >= [breakpointDesktop] (permanent sidenav).
  static bool isDesktopOrWider(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= breakpointDesktop;
  }

  /// Tablet band between mobile and desktop: hamburger + temporary drawer.
  static bool isMidBand(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= breakpointTablet && w < breakpointDesktop;
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
  ///
  /// [leftOffset] is a **physical** left inset within the content area (rail
  /// sibling), chosen so the band is centered in the full viewport. Callers
  /// must apply it with physical-left layout (e.g. [Positioned.left] or a Row
  /// forced to [TextDirection.ltr]), not a direction-flipping Row.
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
    // Scaffold Row puts the sidenav at start: left in LTR, right in RTL.
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final contentAreaLeftInViewport = isRtl ? 0.0 : effectiveRailWidth;
    final desiredBandLeftInViewport = (viewportWidth - maxW) / 2;
    var leftOffset =
        (desiredBandLeftInViewport - contentAreaLeftInViewport).clamp(
          0.0,
          double.infinity,
        );
    if (leftOffset > contentAreaWidth) leftOffset = 0.0;
    final bandWidth = (contentAreaWidth - leftOffset).clamp(0.0, maxW);
    return (leftOffset, bandWidth);
  }

  /// Free width on the **end** side of the content band (right in LTR, left in
  /// RTL). Used for rails such as [ConstrainedContent.aside].
  static double endGutterWidth(BuildContext context, double contentAreaWidth) {
    final (leftOffset, bandWidth) = contentBandMetrics(
      context,
      contentAreaWidth,
    );
    final rightFree = (contentAreaWidth - leftOffset - bandWidth).clamp(
      0.0,
      double.infinity,
    );
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return isRtl ? leftOffset : rightFree;
  }

  /// Whether there is enough end-gutter space for a content aside rail.
  static bool canShowContentAside(
    BuildContext context,
    double contentAreaWidth, {
    double asideMinGutter = 176,
  }) {
    if (!isTabletOrWider(context)) return false;
    return endGutterWidth(context, contentAreaWidth) >= asideMinGutter + 8;
  }
}
