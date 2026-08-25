import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safaeh/safaeh.dart';

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

  return showSafaehCameraSheet<ReceiptCameraResult>(
    context: context,
    builder: (context, sheet) => _ReceiptCameraBody(
      sheet: sheet,
      maxRemaining: maxRemaining,
      scanAfter: scanAfter,
      mockPreview: mockPreview,
      galleryThumb: galleryThumb,
    ),
  );
}

class _ReceiptCameraBody extends StatefulWidget {
  const _ReceiptCameraBody({
    required this.sheet,
    required this.maxRemaining,
    required this.scanAfter,
    this.mockPreview = false,
    this.galleryThumb,
  });

  final SafaehCameraSheet sheet;
  final int maxRemaining;
  final bool scanAfter;
  final bool mockPreview;
  final Uint8List? galleryThumb;

  @override
  State<_ReceiptCameraBody> createState() => _ReceiptCameraBodyState();
}

class _ReceiptCameraBodyState extends State<_ReceiptCameraBody> {
  bool _viewerReady = false;
  Future<void> Function()? _viewerClose;
  VoidCallback? _cancelArmViewer;

  @override
  void initState() {
    super.initState();
    // Keep Flutter layout portrait; sensor orientation drives chrome + capture.
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    widget.sheet.interceptDismiss = _requestDismiss;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Skip hardware during sheet roll; mount viewer when open settles.
      if (MediaQuery.disableAnimationsOf(context)) {
        setState(() => _viewerReady = true);
        return;
      }
      final animation = widget.sheet.openAnimation;
      if (animation == null) {
        setState(() => _viewerReady = true);
        return;
      }
      _cancelArmViewer = armWhenAnimationReady(
        context: context,
        animation: animation,
        action: () {
          if (!mounted || _viewerReady) return;
          setState(() => _viewerReady = true);
        },
      );
    });
  }

  @override
  void didUpdateWidget(covariant _ReceiptCameraBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.sheet.interceptDismiss = _requestDismiss;
  }

  @override
  void dispose() {
    _cancelArmViewer?.call();
    widget.sheet.interceptDismiss = null;
    SystemChrome.setPreferredOrientations(kReceiptCameraRestoredOrientations);
    super.dispose();
  }

  void _pop(ReceiptCameraResult? result) {
    widget.sheet.pop(result);
  }

  Future<void> _requestDismiss() async {
    final close = _viewerClose;
    if (close != null) {
      await close();
      return;
    }
    _pop(null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_viewerReady) return const ColoredBox(color: Colors.black);
    return ReceiptCameraViewer(
      maxRemaining: widget.maxRemaining,
      scanAfter: widget.scanAfter,
      expanded: widget.sheet.expanded,
      mockPreview: widget.mockPreview,
      galleryThumb: widget.galleryThumb,
      onToggleExpanded: widget.sheet.toggleExpanded,
      onPop: _pop,
      onBindCloseRequest: (fn) => _viewerClose = fn,
    );
  }
}
