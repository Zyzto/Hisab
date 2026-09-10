import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../layout/layout_breakpoints.dart';

/// Live reserved width of the permanent shell sidenav (0 / compact / full).
///
/// Updated by [MainScaffold]; read by sheet centering so dialogs track collapse.
class ShellNavLayout {
  ShellNavLayout._();

  /// Extra scroll clearance for the mobile floating nav. The nav is rendered
  /// above the page content, so lists need enough trailing space to scroll
  /// their last row clear of it. The system gesture inset is added at runtime.
  static const double mobileBottomNavClearance =
      SafaehBottomNavMetrics.defaultContentClearance;

  /// Smaller visual offset for controls that sit above the floating nav. It
  /// clears the bar without applying the extra scroll room needed by lists.
  static const double mobileBottomNavOverlayClearance =
      SafaehBottomNavMetrics.defaultVisualClearance;

  static final ValueNotifier<double> reservedWidth = ValueNotifier<double>(0);
  static bool mobileBottomNavVisible = false;

  static const String desktopNavCollapsedKey = 'shell_desktop_nav_collapsed';

  /// Returns the trailing list inset needed when the mobile floating nav is
  /// present. Wide layouts use a docked/temporary sidenav instead. The nav is
  /// hidden while the IME is visible, so keyboard-focused content can use the
  /// full available viewport without reserving space for chrome that is not
  /// shown.
  static double bottomNavListInset(BuildContext context) {
    if (LayoutBreakpoints.isTabletOrWider(context)) {
      return 0.0;
    }
    return _metrics(context).contentInsetWithSafeArea;
  }

  /// Returns the visual offset needed for a floating control above the mobile
  /// bottom nav. The offset disappears while the IME hides that nav.
  static double bottomNavOverlayInset(BuildContext context) {
    if (LayoutBreakpoints.isTabletOrWider(context)) {
      return 0.0;
    }
    return _metrics(context).visualInsetWithSafeArea;
  }

  /// Extra visual clearance for global overlays such as toasts. This is kept
  /// outside the route tree because the feedback host lives above the app's
  /// navigator, while the mobile nav itself lives inside [MainScaffold].
  static double feedbackBottomInset(BuildContext context) {
    if (!mobileBottomNavVisible) return 0.0;
    return SafaehBottomNavMetrics.fromContext(
      context,
      visible: true,
      hideWhenKeyboardVisible: true,
    ).visualInset;
  }

  static SafaehBottomNavMetrics _metrics(BuildContext context) {
    return SafaehBottomNavScope.maybeOf(context) ??
        SafaehBottomNavMetrics.fromContext(context);
  }

  /// Last desktop collapse preference (survives mid-band resize + restarts).
  static Future<bool> loadDesktopNavCollapsed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(desktopNavCollapsedKey) ?? false;
  }

  static Future<void> saveDesktopNavCollapsed(bool collapsed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(desktopNavCollapsedKey, collapsed);
  }
}
