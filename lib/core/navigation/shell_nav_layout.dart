import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Live reserved width of the permanent shell sidenav (0 / compact / full).
///
/// Updated by [MainScaffold]; read by sheet centering so dialogs track collapse.
class ShellNavLayout {
  ShellNavLayout._();

  static final ValueNotifier<double> reservedWidth = ValueNotifier<double>(0);

  static const String desktopNavCollapsedKey = 'shell_desktop_nav_collapsed';

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
