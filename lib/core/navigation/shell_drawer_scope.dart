import 'package:flutter/material.dart';

/// Exposes the shell drawer API (and menu focus node) to nested page scaffolds.
///
/// Home/settings own their own [Scaffold], so [Scaffold.of] from a page cannot
/// open the shell drawer. Wrap the shell body with this scope instead.
class ShellDrawerScope extends InheritedWidget {
  const ShellDrawerScope({
    super.key,
    required this.openDrawer,
    required this.showMenuButton,
    this.menuButtonFocusNode,
    required super.child,
  });

  final VoidCallback openDrawer;

  /// True when the shell uses a temporary drawer (mid, or desktop unpinned).
  final bool showMenuButton;

  /// Focus returns here when the temporary drawer closes.
  final FocusNode? menuButtonFocusNode;

  static ShellDrawerScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellDrawerScope>();
  }

  static void open(BuildContext context) {
    maybeOf(context)?.openDrawer();
  }

  @override
  bool updateShouldNotify(ShellDrawerScope oldWidget) {
    return openDrawer != oldWidget.openDrawer ||
        showMenuButton != oldWidget.showMenuButton ||
        menuButtonFocusNode != oldWidget.menuButtonFocusNode;
  }
}
