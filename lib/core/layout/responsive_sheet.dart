import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'layout_breakpoints.dart';
import 'sheet_handle_drag.dart';
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

  /// When true (default), phone bottom sheets can be dragged down to dismiss.
  /// Ignored on tablet+ (centered dialog). Nested scrollables still scroll;
  /// pull-down wins when they cannot.
  bool enableDrag = true,
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
        enableDrag: enableDrag,
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
    required this.enableDrag,
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
  final bool enableDrag;
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
    // IME is handled only by the outer [Padding] below — do not fold
    // viewInsets into this maxHeight. Putting keyboard-dependent constraints on
    // [AnimatedContainer] made dismiss replay a 320ms "re-open" height morph.
    final effectiveMaxHeight =
        maxHeight ?? size.height * (isWide ? 0.85 : 0.92);

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
            key: const ValueKey('responsive_sheet_drag_handle'),
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

    // Height caps stay on a plain [ConstrainedBox] so IME / size changes never
    // run through [AnimatedContainer]'s modal curve (that looked like a re-open).
    // Width + chrome still morph when crossing the tablet breakpoint.
    final Widget panel = sheetShape != null
        ? Material(
            key: const ValueKey('responsive_sheet_panel'),
            color: cs.surfaceContainerLow,
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape: sheetShape,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: effectiveMaxHeight),
              child: panelBody,
            ),
          )
        : ConstrainedBox(
            constraints: BoxConstraints(maxHeight: effectiveMaxHeight),
            child: AnimatedContainer(
              key: const ValueKey('responsive_sheet_panel'),
              duration: AppMotion.modal,
              curve: AppMotion.enterCurve,
              width: panelWidth,
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: radius,
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(color: Colors.transparent, child: panelBody),
            ),
          );

    Widget sheet = sheetShape != null
        ? ConstrainedBox(
            constraints: BoxConstraints(maxWidth: panelWidth),
            child: panel,
          )
        : panel;
    if (!isWide && enableDrag) {
      sheet = _PhoneSheetDragDismiss(child: sheet);
    }

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
        child: sheet,
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
        // Plain Padding (not AnimatedPadding): MediaQuery.viewInsets already
        // tracks the IME frame-by-frame; a second modal-duration animation
        // would lag the sheet behind the keyboard.
        Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: AnimatedPadding(
            duration: AppMotion.modal,
            curve: AppMotion.enterCurve,
            padding: EdgeInsetsDirectional.only(start: railWidth),
            child: SafeArea(
              top: useSafeArea && isWide,
              // When the IME is up, [Padding] above already clears the keyboard.
              // Keeping viewPadding.bottom would leave a home-indicator gap
              // between the sheet and the keyboard.
              bottom: useSafeArea && !isWide && viewInsets.bottom <= 0,
              left: false,
              right: false,
              child: entering,
            ),
          ),
        ),
      ],
    );
  }
}

/// Phone-only drag-to-dismiss. Uses a thresholded vertical recognizer so nested
/// scrollables still win, matching Material [BottomSheet.enableDrag].
class _PhoneSheetDragDismiss extends StatefulWidget {
  const _PhoneSheetDragDismiss({required this.child});

  final Widget child;

  @override
  State<_PhoneSheetDragDismiss> createState() => _PhoneSheetDragDismissState();
}

class _PhoneSheetDragDismissState extends State<_PhoneSheetDragDismiss>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _dy = ValueNotifier<double>(0);
  late final AnimationController _snap;
  Animation<double>? _snapAnim;

  @override
  void initState() {
    super.initState();
    _snap = AnimationController(vsync: this, duration: AppMotion.modal)
      ..addListener(_onSnapTick);
  }

  void _onSnapTick() {
    final anim = _snapAnim;
    if (anim != null) _dy.value = anim.value;
  }

  @override
  void dispose() {
    _snap.removeListener(_onSnapTick);
    _snap.dispose();
    _dy.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _snap.stop();
    _snapAnim = null;
    final maxDy = MediaQuery.sizeOf(context).height;
    final next = (_dy.value + (details.primaryDelta ?? details.delta.dy)).clamp(
      0.0,
      maxDy,
    );
    if (next != _dy.value) _dy.value = next;
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dy.value >= SheetHandleDrag.dismissDistance ||
        velocity >= SheetHandleDrag.flingVelocity) {
      _tryDismiss();
      return;
    }
    _snapBack();
  }

  void _onDragCancel() {
    if (_dy.value > 0) _snapBack();
  }

  Future<void> _tryDismiss() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final popped = await navigator.maybePop();
    if (!popped && mounted && _dy.value > 0) {
      _snapBack();
    }
  }

  void _snapBack() {
    final begin = _dy.value;
    if (begin == 0) return;
    _snap.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.modal;
    _snapAnim = Tween<double>(
      begin: begin,
      end: 0,
    ).animate(CurvedAnimation(parent: _snap, curve: AppMotion.enterCurve));
    _snap
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      excludeFromSemantics: true,
      gestures: <Type, GestureRecognizerFactory<GestureRecognizer>>{
        VerticalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
              () => VerticalDragGestureRecognizer(debugOwner: this),
              (VerticalDragGestureRecognizer instance) {
                instance
                  ..onUpdate = _onDragUpdate
                  ..onEnd = _onDragEnd
                  ..onCancel = _onDragCancel
                  ..onlyAcceptDragOnThreshold = true;
              },
            ),
      },
      child: ValueListenableBuilder<double>(
        valueListenable: _dy,
        builder: (context, dy, child) {
          return Transform.translate(offset: Offset(0, dy), child: child);
        },
        child: widget.child,
      ),
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
    final viewInsets = MediaQuery.viewInsetsOf(context);
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
        // Match [showResponsiveSheet]: keep dialogs above the IME. Current
        // call sites are image viewers (no fields), but the host must stay
        // safe if a future dialog adds text input.
        Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: AnimatedPadding(
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
        ),
      ],
    );
  }
}
