import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';

import 'layout_breakpoints.dart';
import '../navigation/route_paths.dart';

/// Corner radius used for the responsive-sheet dialog and its top bar.
const double _kSheetDialogRadius = 28.0;

/// Returns rail width when dialog should be centered in content area (shell routes only).
/// Returns 0 when [centerInFullViewport] is true or when path is outside shell (groups, invite, etc.).
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
      path == RoutePaths.archivedGroups ||
      path == RoutePaths.settings ||
      path.startsWith('${RoutePaths.settings}/');
  return isShellRoute ? LayoutBreakpoints.navigationRailWidthFor(context) : 0.0;
}

/// Shows [child] as a bottom sheet on narrow screens and as a centered dialog
/// on tablet-or-wider screens (so it doesn't stretch on desktop/tablet).
///
/// When the navigation rail is visible (home or settings route), the dialog is
/// centered in the content area to the right of the rail; otherwise it is
/// centered in the full screen.
///
/// Returns the same value as [showModalBottomSheet] / [showDialog] (e.g. when
/// the user taps outside or closes, returns null unless the child pops with a value).
///
/// Tapping/clicking outside the modal (on the barrier) closes it on all platforms
/// (mobile and desktop web), unless [barrierDismissible] is false.
///
/// When [title] is non-null and non-empty, it is shown in a distinct top bar
/// on tablet-or-wider (dialog) mode; on narrow screens the child typically
/// includes the title in its body.
Future<T?> showResponsiveSheet<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  double? maxWidth,
  double? maxHeight,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  bool showDragHandle = true,
  ShapeBorder? sheetShape,
  /// When true (default), tapping/clicking the barrier closes the modal. Same behavior on mobile and desktop.
  bool barrierDismissible = true,
  /// When true (default), never add rail padding (center in full viewport). When false, center in content area (e.g. next to rail on shell routes).
  bool centerInFullViewport = true,
}) async {
  if (LayoutBreakpoints.isTabletOrWider(context)) {
    final pathWhenOpened = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    final railWidth = _railWidthForDialog(
      path: pathWhenOpened,
      centerInFullViewport: centerInFullViewport,
      context: context,
    );

    return showDialog<T>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: barrierDismissible,
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        final theme = Theme.of(ctx);
        final effectiveMaxHeight = maxHeight ?? size.height * 0.85;
        const topBarHeight = 56.0;
        final showTitle = title != null && title.isNotEmpty;
        const topBarContentPadding = 12.0;
        final dialogBody = Center(
          child: Dialog(
            insetPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_kSheetDialogRadius),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth ?? LayoutBreakpoints.sheetDialogMaxWidth,
                maxHeight: effectiveMaxHeight,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_kSheetDialogRadius),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Distinct top bar: same shape as dialog (rounded top), title, close
                    Container(
                      height: topBarHeight,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(_kSheetDialogRadius),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (showTitle)
                            Expanded(
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.only(start: 16),
                                  child: Text(
                                    title,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          // Use InkWell instead of IconButton so the close control is not
                          // focusable; otherwise the focus manager can steal focus from
                          // sheet content (e.g. password fields) during applyFocusChangesIfNeeded.
                          Tooltip(
                            message: MaterialLocalizations.of(ctx).closeButtonTooltip,
                            child: Material(
                              type: MaterialType.button,
                              color: Colors.transparent,
                              child: InkWell(
                                canRequestFocus: false,
                                onTap: () =>
                                    Navigator.of(ctx, rootNavigator: true).pop(null),
                                customBorder: const CircleBorder(),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(
                                    Icons.close,
                                    size: 24,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        top: topBarContentPadding,
                        bottom: MediaQuery.viewInsetsOf(ctx).bottom,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: effectiveMaxHeight -
                              topBarHeight -
                              topBarContentPadding,
                        ),
                        child: FocusScope(
                          autofocus: false,
                          child: child,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        // Use LayoutBuilder to get the actual constraints from the overlay so we
        // fill the available space and center within it (fixes off-center on web
        // when overlay size differs from MediaQuery viewport). Our root is
        // full-size, so we add an explicit barrier: a full-screen GestureDetector
        // that pops when tapped (so click-outside closes the dialog). Without this,
        // the full-size content would absorb all taps and the route's barrier never
        // receives them.
        final viewportWidth = size.width;
        final viewportHeight = size.height;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (barrierDismissible)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    final navigator = Navigator.of(ctx, rootNavigator: true);
                    if (navigator.canPop()) navigator.pop(null);
                  },
                  child: const SizedBox.expand(),
                ),
              ),
            LayoutBuilder(
              builder: (ctx, constraints) {
                final cw = constraints.maxWidth.isFinite
                    ? (railWidth > 0
                        ? constraints.maxWidth - railWidth
                        : (constraints.maxWidth < viewportWidth
                            ? constraints.maxWidth
                            : viewportWidth))
                    : viewportWidth - railWidth;
                final ch = constraints.maxHeight.isFinite
                    ? (constraints.maxHeight < viewportHeight
                        ? constraints.maxHeight
                        : viewportHeight)
                    : viewportHeight;
                final centeringWrapper = SizedBox(
                  width: cw,
                  height: ch,
                  child: dialogBody,
                );
                if (railWidth > 0) {
                  return Padding(
                    padding: EdgeInsetsDirectional.only(start: railWidth),
                    child: centeringWrapper,
                  );
                }
                return centeringWrapper;
              },
            ),
          ],
        );
      },
    );
  }

  // On mobile web, showModalBottomSheet's barrier often does not receive
  // pointer events, so use a custom overlay with an explicit barrier (same
  // pattern as tablet+ dialog) so tap-outside reliably dismisses.
  if (kIsWeb) {
    return _showWebBottomSheet<T>(
      context: context,
      child: child,
      barrierDismissible: barrierDismissible,
      showDragHandle: showDragHandle,
      sheetShape: sheetShape,
      useSafeArea: useSafeArea,
      maxHeight: maxHeight,
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    showDragHandle: showDragHandle,
    isDismissible: barrierDismissible,
    shape: sheetShape ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
    builder: (ctx) {
      final viewInsetsBottom = MediaQuery.viewInsetsOf(ctx).bottom;
      final paddedChild = Padding(
        padding: EdgeInsets.only(bottom: viewInsetsBottom),
        child: child,
      );
      return barrierDismissible
          ? TapRegion(
              onTapOutside: (_) {
                final navigator = Navigator.of(ctx);
                if (navigator.canPop()) navigator.pop();
              },
              child: paddedChild,
            )
          : paddedChild;
    },
  );
}

Future<T?> _showWebBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  required bool barrierDismissible,
  required bool showDragHandle,
  ShapeBorder? sheetShape,
  bool useSafeArea = true,
  double? maxHeight,
}) async {
  final theme = Theme.of(context);
  final size = MediaQuery.sizeOf(context);
  final effectiveMaxHeight = maxHeight ?? size.height * 0.85;
  final shape = sheetShape ??
      const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      );

  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: barrierDismissible,
    barrierColor: theme.colorScheme.scrim.withValues(alpha: 0.32),
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (barrierDismissible)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  final navigator = Navigator.of(ctx, rootNavigator: true);
                  if (navigator.canPop()) navigator.pop(null);
                },
                child: const SizedBox.expand(),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: theme.colorScheme.surface,
              shape: shape,
              child: SafeArea(
                top: false,
                bottom: useSafeArea,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: effectiveMaxHeight),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showDragHandle)
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 8),
                          child: Center(
                            child: Container(
                              width: 32,
                              height: 4,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: effectiveMaxHeight - (showDragHandle ? 24.0 : 0) - 24,
                        ),
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
                          ),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: child,
      );
    },
  );
}

/// Shows a dialog that is centered in the content area on tablet when the
/// navigation rail is visible (home or settings), otherwise centered in the
/// full screen. Use for dialogs that must stay as dialog (e.g. full-screen
/// receipt image) but should not overlap the rail on tablet.
///
/// Tapping/clicking outside the dialog (on the barrier) closes it when
/// [barrierDismissible] is true (default), same as on mobile.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  /// When true (default), center in full viewport (no rail padding). When false, center in content area (e.g. next to rail on shell routes).
  bool centerInFullViewport = true,
}) async {
  if (LayoutBreakpoints.isTabletOrWider(context)) {
    final pathWhenOpened = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    final railWidth = _railWidthForDialog(
      path: pathWhenOpened,
      centerInFullViewport: centerInFullViewport,
      context: context,
    );

    return showDialog<T>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      builder: (ctx) {
        final content = Center(child: builder(ctx));
        final size = MediaQuery.sizeOf(ctx);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (barrierDismissible)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    final navigator = Navigator.of(ctx, rootNavigator: true);
                    if (navigator.canPop()) navigator.pop(null);
                  },
                  child: const SizedBox.expand(),
                ),
              ),
            LayoutBuilder(
              builder: (ctx, constraints) {
                final cw = constraints.maxWidth.isFinite
                    ? (railWidth > 0
                        ? constraints.maxWidth - railWidth
                        : constraints.maxWidth)
                    : size.width - railWidth;
                final ch = constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : size.height;
                final wrapper = SizedBox(width: cw, height: ch, child: content);
                if (railWidth > 0) {
                  return Padding(
                    padding: EdgeInsetsDirectional.only(start: railWidth),
                    child: wrapper,
                  );
                }
                return wrapper;
              },
            ),
          ],
        );
      },
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    builder: builder,
  );
}
