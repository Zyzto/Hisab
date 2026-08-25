import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safaeh/safaeh.dart';

import '../motion/app_motion.dart';
import '../navigation/route_paths.dart';
import '../navigation/shell_nav_layout.dart';
import '../widgets/user_text.dart';

export 'package:safaeh/safaeh.dart'
    show kSheetContentPadding, showSafaeh, SafaehTitleBuilder, SafaehTransition;

double _railWidthForDialog({
  required String path,
  required bool centerInFullViewport,
  required BuildContext context,
}) {
  if (centerInFullViewport) return 0.0;
  final isOutsideShell =
      path.startsWith('/groups') ||
      path.startsWith('/invite') ||
      path.startsWith('/functions/');
  if (isOutsideShell) return 0.0;
  final isShellRoute =
      path == RoutePaths.home ||
      path.startsWith('${RoutePaths.homeModeBase}/') ||
      path == RoutePaths.archivedGroups ||
      path == RoutePaths.settings ||
      path.startsWith('${RoutePaths.settings}/');
  if (!isShellRoute) return 0.0;
  return ShellNavLayout.reservedWidth.value;
}

/// Shows [child] as an adaptive modal: centered dialog on tablet+ and a bottom
/// sheet on narrow screens. Hosted by `package:safaeh`.
Future<T?> showResponsiveSheet<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  Widget? tabletTopBarAction,
  double? maxWidth,
  double? maxHeight,

  /// Unused. Sheets are always content-sized. Kept for existing call sites.
  bool isScrollControlled = true,
  bool useSafeArea = true,
  bool showDragHandle = true,
  bool enableDrag = true,
  ShapeBorder? sheetShape,
  bool barrierDismissible = true,
  bool centerInFullViewport = true,
  EdgeInsetsGeometry? contentPadding,
}) {
  final pathWhenOpened = GoRouter.of(
    context,
  ).routerDelegate.currentConfiguration.uri.path;

  return showSafaeh<T>(
    context: context,
    child: child,
    title: title,
    titleBuilder: title == null || title.isEmpty
        ? null
        : (ctx, style) => UserText(
            title,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
    tabletTopBarAction: tabletTopBarAction,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    useSafeArea: useSafeArea,
    showDragHandle: showDragHandle,
    enableDrag: enableDrag,
    sheetShape: sheetShape,
    barrierDismissible: barrierDismissible,
    contentPadding: contentPadding,
    railWidthOf: (ctx) => _railWidthForDialog(
      path: pathWhenOpened,
      centerInFullViewport: centerInFullViewport,
      context: ctx,
    ),
    fadeScale: ({required animation, required child}) =>
        AppMotion.buildFadeScaleTransition(animation: animation, child: child),
    slideUp: ({required animation, required child}) =>
        AppMotion.buildSlideUpTransition(animation: animation, child: child),
  );
}

/// Shows a dialog that is centered in the content area on tablet when the
/// navigation rail is visible (home or settings), otherwise centered in the
/// full screen.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool centerInFullViewport = true,
  bool fadeScale = true,
}) {
  final pathWhenOpened = GoRouter.of(
    context,
  ).routerDelegate.currentConfiguration.uri.path;

  return showSafaehDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    fadeScale: fadeScale,
    motion: AppMotion.modal,
    enterCurve: AppMotion.enterCurve,
    railWidthOf: (ctx) => _railWidthForDialog(
      path: pathWhenOpened,
      centerInFullViewport: centerInFullViewport,
      context: ctx,
    ),
    transition: fadeScale
        ? ({required animation, required child}) =>
              AppMotion.buildFadeScaleTransition(
                animation: animation,
                child: child,
              )
        : ({required animation, required child}) =>
              AppMotion.buildFadeTransition(animation: animation, child: child),
  );
}
