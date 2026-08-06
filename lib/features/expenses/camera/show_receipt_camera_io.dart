import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/sheet_handle_drag.dart';
import '../../../core/motion/app_motion.dart';
import '../../../core/navigation/route_transition_ready.dart';
import 'receipt_camera_types.dart';
import 'receipt_camera_viewer.dart';

export 'receipt_camera_types.dart';

/// Opens the inline receipt camera modal (native IO only).
///
/// Compact height defaults to [kReceiptCameraCompactHeightFraction] of the
/// screen; the viewer can toggle to full height without disposing the camera.
///
/// While open, the route is portrait-locked so chrome can follow the *sensor*
/// orientation even when the OS rotation lock is on.
Future<ReceiptCameraResult?> showReceiptCamera(
  BuildContext context, {
  required int maxRemaining,
  required bool scanAfter,
  bool mockPreview = false,
  Uint8List? galleryThumb,
}) {
  if (maxRemaining <= 0) {
    return Future<ReceiptCameraResult?>.value(null);
  }

  return showGeneralDialog<ReceiptCameraResult>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: AppMotion.sheetRoll,
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return _ReceiptCameraHost(
        maxRemaining: maxRemaining,
        scanAfter: scanAfter,
        mockPreview: mockPreview,
        galleryThumb: galleryThumb,
        openAnimation: animation,
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) => child,
  );
}

class _ReceiptCameraHost extends StatefulWidget {
  const _ReceiptCameraHost({
    required this.maxRemaining,
    required this.scanAfter,
    required this.openAnimation,
    this.mockPreview = false,
    this.galleryThumb,
  });

  final int maxRemaining;
  final bool scanAfter;
  final bool mockPreview;
  final Uint8List? galleryThumb;
  final Animation<double> openAnimation;

  @override
  State<_ReceiptCameraHost> createState() => _ReceiptCameraHostState();
}

class _ReceiptCameraHostState extends State<_ReceiptCameraHost> {
  bool _expanded = false;
  bool _viewerReady = false;
  final _drag = SheetHandleDrag();
  Future<void> Function()? _viewerClose;
  VoidCallback? _cancelArmViewer;

  @override
  void initState() {
    super.initState();
    // Keep Flutter layout portrait; sensor orientation drives chrome + capture.
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Skip hardware during sheet roll; mount viewer when open settles.
      if (MediaQuery.disableAnimationsOf(context)) {
        setState(() => _viewerReady = true);
        return;
      }
      _cancelArmViewer = armWhenAnimationReady(
        context: context,
        animation: widget.openAnimation,
        action: () {
          if (!mounted || _viewerReady) return;
          setState(() => _viewerReady = true);
        },
      );
    });
  }

  @override
  void dispose() {
    _cancelArmViewer?.call();
    SystemChrome.setPreferredOrientations(kReceiptCameraRestoredOrientations);
    super.dispose();
  }

  Duration _duration(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppMotion.modal;

  void _pop(ReceiptCameraResult? result) {
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) nav.pop(result);
  }

  Future<void> _requestDismiss() async {
    final close = _viewerClose;
    if (close != null) {
      await close();
      return;
    }
    _pop(null);
  }

  void _onHandleDragEnd(DragEndDetails details) {
    final action = _drag.end(
      expanded: _expanded,
      velocity: details.primaryVelocity ?? 0,
    );
    setState(() {
      switch (action) {
        case SheetHandleDragAction.expand:
          _expanded = true;
        case SheetHandleDragAction.collapse:
          _expanded = false;
        case SheetHandleDragAction.dismiss:
          _requestDismiss();
        case SheetHandleDragAction.none:
          break;
      }
      _drag.reset();
    });
  }

  double _rollProgress() {
    final t = widget.openAnimation.value.clamp(0.0, 1.0);
    final reversing = widget.openAnimation.status == AnimationStatus.reverse;
    final curved = reversing
        ? AppMotion.exitCurve.transform(t)
        : AppMotion.sheetRollEnter.transform(t);
    return curved.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= LayoutBreakpoints.breakpointTablet;
    final duration = _duration(context);
    final scrim = Theme.of(context).colorScheme.scrim.withValues(alpha: 0.45);

    final compactH = size.height * kReceiptCameraCompactHeightFraction;
    final fullH = size.height;
    final panelH = _drag.panelHeight(
      expanded: _expanded,
      compactH: compactH,
      fullH: fullH,
    );

    final radius = _expanded && _drag.offset <= 0
        ? BorderRadius.zero
        : (isWide
              ? BorderRadius.circular(16)
              : const BorderRadius.vertical(top: Radius.circular(16)));

    // Immersive viewer: nearly full width (not the narrow option-sheet dialog).
    final panelWidth = isWide ? size.width - 32 : size.width;

    final panel = SizedBox(
      width: panelWidth,
      height: panelH,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: radius,
          border: _expanded && _drag.offset <= 0
              ? null
              : Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Column(
            children: [
              SheetHandleBar(
                expanded: _expanded,
                duration: duration,
                onVerticalDragUpdate: (details) {
                  setState(
                    () => _drag.update(details.delta.dy, expanded: _expanded),
                  );
                },
                onVerticalDragEnd: _onHandleDragEnd,
                onVerticalDragCancel: () => setState(_drag.reset),
              ),
              Expanded(
                child: _viewerReady
                    ? ReceiptCameraViewer(
                        maxRemaining: widget.maxRemaining,
                        scanAfter: widget.scanAfter,
                        expanded: _expanded,
                        mockPreview: widget.mockPreview,
                        galleryThumb: widget.galleryThumb,
                        onToggleExpanded: () => setState(() {
                          _expanded = !_expanded;
                          _drag.reset();
                        }),
                        onPop: _pop,
                        onBindCloseRequest: (fn) => _viewerClose = fn,
                      )
                    : const ColoredBox(color: Colors.black),
              ),
            ],
          ),
        ),
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: widget.openAnimation,
                builder: (context, child) {
                  final t = widget.openAnimation.value.clamp(0.0, 1.0);
                  final o = Curves.easeInOutCubic.transform(t);
                  return Opacity(opacity: o, child: child);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _requestDismiss,
                  child: ColoredBox(color: scrim),
                ),
              ),
            ),
            AnimatedPadding(
              duration: duration,
              curve: AppMotion.enterCurve,
              padding: isWide && !_expanded
                  ? const EdgeInsets.symmetric(horizontal: 16)
                  : EdgeInsets.zero,
              child: AnimatedBuilder(
                animation: widget.openAnimation,
                builder: (context, child) {
                  final progress = _rollProgress();
                  final revealH = panelH * progress;
                  final rolling =
                      widget.openAnimation.status == AnimationStatus.forward ||
                      widget.openAnimation.status == AnimationStatus.reverse;
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: Transform.translate(
                      offset: Offset(0, _drag.translateY(expanded: _expanded)),
                      child: AnimatedContainer(
                        duration: rolling || _drag.offset != 0
                            ? Duration.zero
                            : duration,
                        curve: AppMotion.enterCurve,
                        width: panelWidth,
                        height: revealH,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            maxHeight: panelH,
                            minHeight: panelH,
                            maxWidth: panelWidth,
                            minWidth: panelWidth,
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: panel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
