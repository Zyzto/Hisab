import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'layout_breakpoints.dart';
import '../motion/app_motion.dart';
import '../navigation/route_paths.dart';
import '../navigation/shell_nav_layout.dart';
import '../widgets/user_text.dart';

/// Corner radius for sheet chrome (matches AccentSurfaces.flatPanel).
const double _kSheetDialogRadius = 16.0;

/// Top corner radius for phone bottom sheets.
const double _kSheetBottomRadius = 16.0;

/// Default inset for free-form sheet bodies (not option lists that pad themselves).
///
/// [showResponsiveSheet] does **not** apply this automatically — pass it as
/// [contentPadding], or wrap with `buildSheetShell` from `sheet_helpers.dart`.
/// Skipping both is why custom sheets keep shipping flush to the panel edges.
const EdgeInsets kSheetContentPadding = EdgeInsets.fromLTRB(20, 16, 20, 20);

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
      path.startsWith('${RoutePaths.homeModeBase}/') ||
      path == RoutePaths.archivedGroups ||
      path == RoutePaths.settings ||
      path.startsWith('${RoutePaths.settings}/');
  if (!isShellRoute) return 0.0;
  // Published by MainScaffold (0 mid/archived/mobile; 72/240 desktop).
  return ShellNavLayout.reservedWidth.value;
}

/// Shows [child] as an adaptive modal: centered dialog on tablet+ and a bottom
/// sheet on narrow screens. The same route morphs smoothly when the viewport
/// crosses the tablet breakpoint (e.g. window resize on web/desktop).
///
/// When the navigation rail is visible and [centerInFullViewport] is false,
/// the dialog is centered in the content area to the right of the rail.
///
/// Returns the same value as [showDialog] / [showModalBottomSheet] (null when
/// dismissed unless the child pops with a value).
Future<T?> showResponsiveSheet<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  Widget? tabletTopBarAction,
  double? maxWidth,
  double? maxHeight,
  // Retained for call-site compatibility; height is always content-driven
  // with a max constraint in the adaptive host.
  bool isScrollControlled = true,
  bool useSafeArea = true,
  bool showDragHandle = true,
  ShapeBorder? sheetShape,

  /// When true (default), tapping/clicking the barrier closes the modal.
  bool barrierDismissible = true,

  /// When true (default), never add rail padding (center in full viewport).
  /// When false, center in content area (e.g. next to rail on shell routes).
  bool centerInFullViewport = true,

  /// Inset around [child]. Null (default) means no body inset — callers that
  /// already pad (option lists, [buildSheetShell]) stay unchanged. For free-form
  /// bodies use [kSheetContentPadding] (or [buildSheetShell]).
  EdgeInsetsGeometry? contentPadding,
}) {
  assert(isScrollControlled || !isScrollControlled);

  final theme = Theme.of(context);
  final pathWhenOpened = GoRouter.of(
    context,
  ).routerDelegate.currentConfiguration.uri.path;

  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: theme.colorScheme.scrim.withValues(alpha: 0.32),
    transitionDuration: AppMotion.modal,
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return _AdaptiveSheetHost(
        title: title,
        tabletTopBarAction: tabletTopBarAction,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        useSafeArea: useSafeArea,
        showDragHandle: showDragHandle,
        sheetShape: sheetShape,
        barrierDismissible: barrierDismissible,
        centerInFullViewport: centerInFullViewport,
        pathWhenOpened: pathWhenOpened,
        openAnimation: animation,
        contentPadding: contentPadding,
        child: child,
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      // Entrance is handled inside [_AdaptiveSheetHost] so resize morphs stay
      // independent of the route animation.
      return child;
    },
  );
}

/// Adaptive host that rebuilds on MediaQuery changes and morphs between
/// centered dialog and bottom-sheet layouts.
class _AdaptiveSheetHost extends StatelessWidget {
  const _AdaptiveSheetHost({
    required this.child,
    required this.pathWhenOpened,
    required this.centerInFullViewport,
    required this.barrierDismissible,
    required this.useSafeArea,
    required this.showDragHandle,
    required this.openAnimation,
    this.title,
    this.tabletTopBarAction,
    this.maxWidth,
    this.maxHeight,
    this.sheetShape,
    this.contentPadding,
  });

  final Widget child;
  final String pathWhenOpened;
  final bool centerInFullViewport;
  final bool barrierDismissible;
  final bool useSafeArea;
  final bool showDragHandle;
  final Animation<double> openAnimation;
  final String? title;
  final Widget? tabletTopBarAction;
  final double? maxWidth;
  final double? maxHeight;
  final ShapeBorder? sheetShape;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isWide = size.width >= LayoutBreakpoints.breakpointTablet;
    final railWidth = isWide
        ? _railWidthForDialog(
            path: pathWhenOpened,
            centerInFullViewport: centerInFullViewport,
            context: context,
          )
        : 0.0;

    final availableWidth = math.max(0.0, size.width - railWidth);
    final dialogMaxWidth = maxWidth ?? LayoutBreakpoints.sheetDialogMaxWidth;
    final panelWidth = isWide
        ? math.min(dialogMaxWidth, math.max(0.0, availableWidth - 48))
        : availableWidth;
    // Keep the panel above the IME. Wide (centered) dialogs previously only
    // shrank the body while the panel maxHeight still included keyboard space,
    // which let header+body Columns overflow by ~10–20px in landscape.
    final rawMaxHeight = maxHeight ?? size.height * (isWide ? 0.85 : 0.92);
    final effectiveMaxHeight = math.max(
      0.0,
      rawMaxHeight - viewInsets.bottom,
    );

    final showTitle = title != null && title!.isNotEmpty;
    // Wide dialog header: padded title row (was a flush 56px bar).
    const wideHeaderChromeHeight = 72.0;
    final chromeHeight = isWide
        ? wideHeaderChromeHeight
        : (showDragHandle ? 24.0 : 8.0);
    final bodyMaxHeight = math.max(0.0, effectiveMaxHeight - chromeHeight);

    final BorderRadius radius = isWide
        ? BorderRadius.circular(_kSheetDialogRadius)
        : const BorderRadius.vertical(
            top: Radius.circular(_kSheetBottomRadius),
          );

    final Widget header = isWide
        ? DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 12, 12),
              child: Row(
                children: [
                  if (showTitle)
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(start: 4),
                          child: UserText(
                            title!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (tabletTopBarAction != null) ...[
                    Focus(
                      canRequestFocus: false,
                      skipTraversal: true,
                      descendantsAreFocusable: false,
                      child: tabletTopBarAction!,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Tooltip(
                    message: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    child: Material(
                      type: MaterialType.button,
                      color: Colors.transparent,
                      child: InkWell(
                        canRequestFocus: false,
                        onTap: () {
                          final navigator = Navigator.of(
                            context,
                            rootNavigator: true,
                          );
                          if (navigator.canPop()) navigator.pop(null);
                        },
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            Icons.close,
                            size: 22,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        : showDragHandle
        ? Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          )
        : const SizedBox(height: 8);

    // Custom [sheetShape] replaces the animated box decoration (rare).
    // Cap the whole panel, then let the body take remaining height via
    // [Expanded] so header size drift cannot RenderFlex-overflow the Column.
    // Short sheets still shrink when the parent only passes a max height and
    // the body child is shrink-wrapping (most [buildSheetShell] callers).
    final Widget panelBody = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: effectiveMaxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSize(
            duration: AppMotion.modal,
            curve: AppMotion.enterCurve,
            alignment: Alignment.topCenter,
            child: header,
          ),
          Flexible(
            fit: FlexFit.loose,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: bodyMaxHeight),
              child: FocusScope(
                autofocus: false,
                child: contentPadding != null
                    ? Padding(padding: contentPadding!, child: child)
                    : child,
              ),
            ),
          ),
        ],
      ),
    );

    final Widget panel = sheetShape != null
        ? Material(
            key: const ValueKey('responsive_sheet_panel'),
            color: cs.surfaceContainerLow,
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape: sheetShape,
            child: panelBody,
          )
        : AnimatedContainer(
            key: const ValueKey('responsive_sheet_panel'),
            duration: AppMotion.modal,
            curve: AppMotion.enterCurve,
            width: panelWidth,
            constraints: BoxConstraints(maxHeight: effectiveMaxHeight),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: radius,
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: panelBody,
            ),
          );

    final alignedPanel = AnimatedPadding(
      duration: AppMotion.modal,
      curve: AppMotion.enterCurve,
      padding: isWide
          ? const EdgeInsets.symmetric(horizontal: 24, vertical: 24)
          : EdgeInsets.zero,
      child: AnimatedAlign(
        duration: AppMotion.modal,
        curve: AppMotion.enterCurve,
        alignment: isWide ? Alignment.center : Alignment.bottomCenter,
        child: sheetShape != null
            ? ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: panelWidth,
                  maxHeight: effectiveMaxHeight,
                ),
                child: panel,
              )
            : panel,
      ),
    );

    // Entrance: wide fades/scales in place; narrow eases up slightly.
    final entering = AnimatedBuilder(
      animation: openAnimation,
      builder: (context, child) {
        if (isWide) {
          return AppMotion.buildFadeScaleTransition(
            animation: openAnimation,
            child: child!,
          );
        }
        return AppMotion.buildSlideUpTransition(
          animation: openAnimation,
          child: child!,
        );
      },
      child: alignedPanel,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (barrierDismissible)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                final navigator = Navigator.of(context, rootNavigator: true);
                if (navigator.canPop()) navigator.pop(null);
              },
              child: const SizedBox.expand(),
            ),
          ),
        AnimatedPadding(
          duration: AppMotion.modal,
          curve: AppMotion.enterCurve,
          padding: EdgeInsetsDirectional.only(start: railWidth),
          child: SafeArea(
            top: useSafeArea && isWide,
            bottom: useSafeArea && !isWide,
            left: false,
            right: false,
            child: entering,
          ),
        ),
      ],
    );
  }
}

/// Shows a dialog that is centered in the content area on tablet when the
/// navigation rail is visible (home or settings), otherwise centered in the
/// full screen. Use for dialogs that must stay as dialog (e.g. full-screen
/// image viewer) but should not overlap the rail on tablet.
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

  /// When true (default), fade + scale like wide sheets. Pass false for
  /// fullscreen image viewers (fade only).
  bool fadeScale = true,
}) {
  final theme = Theme.of(context);
  final pathWhenOpened = GoRouter.of(
    context,
  ).routerDelegate.currentConfiguration.uri.path;

  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor:
        barrierColor ?? theme.colorScheme.scrim.withValues(alpha: 0.32),
    transitionDuration: AppMotion.modal,
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return _AdaptiveAppDialogHost(
        builder: builder,
        pathWhenOpened: pathWhenOpened,
        centerInFullViewport: centerInFullViewport,
        barrierDismissible: barrierDismissible,
        fadeScale: fadeScale,
        openAnimation: animation,
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) => child,
  );
}

class _AdaptiveAppDialogHost extends StatelessWidget {
  const _AdaptiveAppDialogHost({
    required this.builder,
    required this.pathWhenOpened,
    required this.centerInFullViewport,
    required this.barrierDismissible,
    required this.fadeScale,
    required this.openAnimation,
  });

  final WidgetBuilder builder;
  final String pathWhenOpened;
  final bool centerInFullViewport;
  final bool barrierDismissible;
  final bool fadeScale;
  final Animation<double> openAnimation;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= LayoutBreakpoints.breakpointTablet;
    final railWidth = isWide
        ? _railWidthForDialog(
            path: pathWhenOpened,
            centerInFullViewport: centerInFullViewport,
            context: context,
          )
        : 0.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (barrierDismissible)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                final navigator = Navigator.of(context, rootNavigator: true);
                if (navigator.canPop()) navigator.pop(null);
              },
              child: const SizedBox.expand(),
            ),
          ),
        AnimatedPadding(
          duration: AppMotion.modal,
          curve: AppMotion.enterCurve,
          padding: EdgeInsetsDirectional.only(start: railWidth),
          child: AnimatedBuilder(
            animation: openAnimation,
            builder: (context, child) {
              if (fadeScale) {
                return AppMotion.buildFadeScaleTransition(
                  animation: openAnimation,
                  child: child!,
                );
              }
              return AppMotion.buildFadeTransition(
                animation: openAnimation,
                child: child!,
              );
            },
            child: Align(
              alignment: Alignment.center,
              child: builder(context),
            ),
          ),
        ),
      ],
    );
  }
}
