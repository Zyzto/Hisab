import 'package:flutter/material.dart';

import '../navigation/shell_drawer_scope.dart';

/// Hamburger that opens the shell temporary drawer.
///
/// Returns [SizedBox.shrink] when the shell drawer is permanent (pinned) or
/// when no [ShellDrawerScope] is available.
class ShellMenuButton extends StatelessWidget {
  const ShellMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = ShellDrawerScope.maybeOf(context);
    if (scope == null || !scope.showMenuButton) {
      return const SizedBox.shrink();
    }

    return IconButton(
      key: const ValueKey('shell_menu_button'),
      focusNode: scope.menuButtonFocusNode,
      icon: const Icon(Icons.menu),
      tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      onPressed: scope.openDrawer,
    );
  }
}

/// Shell leading: menu when temporary drawer mode, otherwise [fallback].
///
/// On phone / pinned desktop returns [fallback] (typically [SyncStatusChip]).
class ShellAppBarLeading extends StatelessWidget {
  const ShellAppBarLeading({super.key, required this.fallback});

  final Widget fallback;

  /// Width to pass as [ContentAlignedAppBar.leadingWidth].
  static double widthFor(BuildContext context) => kToolbarHeight;

  /// Whether the sync chip should sit in actions (temporary drawer mode).
  static bool syncInActions(BuildContext context) {
    final scope = ShellDrawerScope.maybeOf(context);
    return scope != null && scope.showMenuButton;
  }

  @override
  Widget build(BuildContext context) {
    if (syncInActions(context)) {
      return const ShellMenuButton();
    }
    return fallback;
  }
}
