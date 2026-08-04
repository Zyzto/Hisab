import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../core/motion/app_motion.dart';
import 'receipt_camera_controller.dart';
import 'receipt_camera_mock_preview.dart';
import 'receipt_camera_session.dart';
import 'receipt_camera_types.dart';

typedef ReceiptCameraPop = void Function(ReceiptCameraResult? result);

/// Live receipt camera UI: preview, guide, filmstrip, review, controls.
class ReceiptCameraViewer extends StatefulWidget {
  const ReceiptCameraViewer({
    super.key,
    required this.maxRemaining,
    required this.scanAfter,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onPop,
    this.controller,
    this.session,
    this.mockPreview = false,
    this.onBindCloseRequest,
  });

  final int maxRemaining;
  final bool scanAfter;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ReceiptCameraPop onPop;

  /// Injectable for tests; when null a real [ReceiptCameraController] is created.
  final ReceiptCameraController? controller;

  /// Injectable for tests (e.g. pre-seeded filmstrip).
  final ReceiptCameraSession? session;

  /// Debug: animated mock feed instead of device camera.
  final bool mockPreview;

  /// Host registers dismiss (barrier / drag) so discard confirm still runs.
  final ValueChanged<Future<void> Function()>? onBindCloseRequest;

  @override
  State<ReceiptCameraViewer> createState() => _ReceiptCameraViewerState();
}

class _ReceiptCameraViewerState extends State<ReceiptCameraViewer>
    with WidgetsBindingObserver {
  late final ReceiptCameraController _controller;
  late final bool _ownsController;
  late final ReceiptCameraSession _session;

  PageController? _pageController;
  bool _flashVisible = false;
  bool _shutterPressed = false;
  bool _capturing = false;
  bool _shakeShutter = false;
  bool _guideVisible = false;
  double _pinchStartZoom = 1;

  Duration get _motion {
    if (!mounted) return AppMotion.page;
    return MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.page;
  }

  Duration get _modalMotion {
    if (!mounted) return AppMotion.modal;
    return MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.modal;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ?? ReceiptCameraController(mock: widget.mockPreview);
    _session =
        widget.session ??
        ReceiptCameraSession(maxRemaining: widget.maxRemaining);
    _controller.addListener(_onControllerChanged);
    widget.onBindCloseRequest?.call(_requestClose);
    if (_session.isReviewing) {
      _pageController = PageController(initialPage: _session.viewingIndex!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.initialize(context);
    });
  }

  void _ensurePageController(int index) {
    final existing = _pageController;
    if (existing == null) {
      _pageController = PageController(initialPage: index);
      return;
    }
    if (existing.hasClients) {
      if (existing.page?.round() != index) {
        existing.jumpToPage(index);
      }
      return;
    }
    existing.dispose();
    _pageController = PageController(initialPage: index);
  }

  void _disposePageController() {
    _pageController?.dispose();
    _pageController = null;
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (widget.scanAfter && _controller.isReady && !_guideVisible) {
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (mounted && widget.scanAfter && _controller.isReady) {
          setState(() => _guideVisible = true);
        }
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    _disposePageController();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (mounted) _controller.resume(context);
    }
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    if (!_session.hasCaptures) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('receipt_camera_discard_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('receipt_camera_discard_action'.tr()),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _requestClose() async {
    if (!await _confirmDiscardIfNeeded()) return;
    if (!mounted) return;
    widget.onPop(null);
  }

  Future<void> _requestGallery() async {
    if (!await _confirmDiscardIfNeeded()) return;
    if (!mounted) return;
    widget.onPop(
      ReceiptCameraResult(
        images: const [],
        scanAfter: widget.scanAfter,
        openGallery: true,
      ),
    );
  }

  void _submit() {
    widget.onPop(
      ReceiptCameraResult(
        images: _session.takeAll(),
        scanAfter: widget.scanAfter,
      ),
    );
  }

  void _playShutterCue() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    setState(() => _flashVisible = true);
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 45), () {
        if (mounted) setState(() => _flashVisible = false);
      }),
    );
  }

  Future<void> _onShutter() async {
    if (_capturing || !_session.canCapture || !_controller.isReady) {
      if (_session.atMax) {
        setState(() => _shakeShutter = true);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (mounted) setState(() => _shakeShutter = false);
      }
      return;
    }

    _capturing = true;
    setState(() => _shutterPressed = true);
    _playShutterCue();

    final file = await _controller.takePicture();
    if (!mounted) {
      _capturing = false;
      return;
    }
    setState(() => _shutterPressed = false);
    _capturing = false;

    if (file == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('receipt_scan_error'.tr(args: ['capture']))),
      );
      return;
    }
    setState(() {
      _session.addCapture(file);
      _ensurePageController(_session.viewingIndex!);
    });
  }

  void _addMore() {
    setState(() {
      _session.returnToCamera();
      _disposePageController();
    });
  }

  void _retakeCurrent() {
    setState(() {
      _session.retakeCurrent();
      _disposePageController();
    });
  }

  void _openStripItem(int index) {
    setState(() {
      _session.openStripItem(index);
      _ensurePageController(index);
    });
  }

  void _removeStripItem(int index) {
    setState(() {
      _session.removeStripItem(index);
      final v = _session.viewingIndex;
      if (v == null) {
        _disposePageController();
      } else {
        _ensurePageController(v);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _requestClose();
      },
      child: Material(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBody(theme, cs),
            if (_flashVisible)
              const IgnorePointer(
                child: ColoredBox(color: Color(0x66FFFFFF)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme cs) {
    return AnimatedSwitcher(
      duration: _motion,
      switchInCurve: AppMotion.enterCurve,
      switchOutCurve: AppMotion.exitCurve,
      transitionBuilder: (child, anim) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: AppMotion.enterCurve,
          reverseCurve: AppMotion.exitCurve,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: AppMotion.dialogStartScale,
              end: 1,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_controller.status),
        child: switch (_controller.status) {
          ReceiptCameraStatus.loading => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          ReceiptCameraStatus.permissionDenied => _PermissionState(
            onOpenSettings: _controller.openSettings,
            onClose: _requestClose,
            onGallery: _requestGallery,
          ),
          ReceiptCameraStatus.noCamera ||
          ReceiptCameraStatus.error => _EmptyState(
            message: _controller.status == ReceiptCameraStatus.error
                ? (_controller.errorMessage ?? 'receipt_camera_no_camera'.tr())
                : 'receipt_camera_no_camera'.tr(),
            onClose: _requestClose,
            onGallery: _requestGallery,
          ),
          ReceiptCameraStatus.ready => _buildReady(theme, cs),
        },
      ),
    );
  }

  Widget _buildReady(ThemeData theme, ColorScheme cs) {
    final reviewing = _session.isReviewing;
    final viewingIndex = _session.viewingIndex;

    final Widget livePreview;
    if (_controller.isMock) {
      livePreview = ReceiptCameraMockPreview(
        torchOn: _controller.torchOn,
        zoom: _controller.zoom,
        paused: _controller.mockPaused,
      );
    } else if (_controller.camera != null) {
      livePreview = _CameraPreviewBox(
        controller: _controller.camera!,
        mirror: _controller.lensDirection == CameraLensDirection.front,
      );
    } else {
      livePreview = const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Column(
      children: [
        _TopBar(
          expanded: widget.expanded,
          // Handle bar already clears the status bar when expanded.
          padTopSafeArea: false,
          torchSupported: _controller.torchSupported,
          torchOn: _controller.torchOn,
          canSwitchLens: _controller.canSwitchLens,
          lensDirection: _controller.lensDirection,
          onClose: _requestClose,
          onToggleExpanded: widget.onToggleExpanded,
          onGallery: _requestGallery,
          onTorch: () => _controller.setTorch(!_controller.torchOn),
          onSwitchLens: () => _controller.switchLens(),
          motion: _modalMotion,
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!reviewing)
                GestureDetector(
                  onScaleStart: _controller.zoomSupported
                      ? (_) => _pinchStartZoom = _controller.zoom
                      : null,
                  onScaleUpdate: _controller.zoomSupported
                      ? (d) => _controller.setZoom(_pinchStartZoom * d.scale)
                      : null,
                  child: livePreview,
                ),
              if (reviewing && _pageController != null)
                PageView.builder(
                  controller: _pageController,
                  itemCount: _session.captures.length,
                  onPageChanged: (i) {
                    setState(() => _session.setViewingIndex(i));
                  },
                  itemBuilder: (context, i) {
                    return _XFileImage(
                      file: _session.captures[i],
                      fit: BoxFit.contain,
                    );
                  },
                ),
              if (widget.scanAfter && !reviewing)
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _guideVisible ? 1 : 0,
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 220),
                    curve: AppMotion.enterCurve,
                    child: AnimatedScale(
                      scale: _guideVisible ? 1 : 0.96,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      curve: AppMotion.enterCurve,
                      child: const _FramingGuide(),
                    ),
                  ),
                ),
              if (widget.scanAfter &&
                  !reviewing &&
                  !_session.hintDismissed)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 16,
                  child: AnimatedOpacity(
                    opacity: _guideVisible ? 1 : 0,
                    duration: _motion,
                    child: Text(
                      'receipt_camera_hint'.tr(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        shadows: const [
                          Shadow(blurRadius: 8, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _Filmstrip(
          captures: _session.captures,
          selectedIndex: viewingIndex,
          motion: _motion,
          onTap: _openStripItem,
          onRemove: _removeStripItem,
        ),
        if (reviewing)
          _ReviewBar(
            canAddMore: !_session.atMax,
            onRetake: _retakeCurrent,
            onAddMore: _addMore,
            onSubmit: _submit,
          )
        else
          _BottomControls(
            canCapture: _session.canCapture && _controller.isReady,
            atMax: _session.atMax,
            hasCaptures: _session.hasCaptures,
            shutterPressed: _shutterPressed,
            shake: _shakeShutter,
            motion: _motion,
            onShutter: _onShutter,
            onSubmit: _session.hasCaptures ? _submit : null,
          ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.expanded,
    required this.padTopSafeArea,
    required this.torchSupported,
    required this.torchOn,
    required this.canSwitchLens,
    required this.lensDirection,
    required this.onClose,
    required this.onToggleExpanded,
    required this.onGallery,
    required this.onTorch,
    required this.onSwitchLens,
    required this.motion,
  });

  final bool expanded;
  final bool padTopSafeArea;
  final bool torchSupported;
  final bool torchOn;
  final bool canSwitchLens;
  final CameraLensDirection lensDirection;
  final VoidCallback onClose;
  final VoidCallback onToggleExpanded;
  final VoidCallback onGallery;
  final VoidCallback onTorch;
  final VoidCallback onSwitchLens;
  final Duration motion;

  @override
  Widget build(BuildContext context) {
    final bg = Colors.black.withValues(alpha: 0.45);
    final bar = Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          IconButton(
            tooltip: 'gallery'.tr(),
            onPressed: onGallery,
            icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
          ),
          const Spacer(),
          if (canSwitchLens)
            IconButton(
              tooltip: lensDirection == CameraLensDirection.front
                  ? 'receipt_camera_lens_rear'.tr()
                  : 'receipt_camera_lens_front'.tr(),
              onPressed: onSwitchLens,
              icon: AnimatedSwitcher(
                duration: motion == Duration.zero
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
                child: Icon(
                  Icons.cameraswitch_outlined,
                  key: ValueKey(lensDirection),
                  color: Colors.white,
                ),
              ),
            ),
          if (torchSupported)
            IconButton(
              tooltip: 'receipt_camera_torch'.tr(),
              onPressed: onTorch,
              icon: AnimatedSwitcher(
                duration: motion == Duration.zero
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
                child: Icon(
                  torchOn ? Icons.flash_on : Icons.flash_off,
                  key: ValueKey(torchOn),
                  color: torchOn ? Colors.amber : Colors.white,
                ),
              ),
            ),
          IconButton(
            tooltip: expanded
                ? 'receipt_camera_collapse'.tr()
                : 'receipt_camera_expand'.tr(),
            onPressed: onToggleExpanded,
            icon: AnimatedSwitcher(
              duration: motion,
              child: Icon(
                expanded ? Icons.close_fullscreen : Icons.open_in_full,
                key: ValueKey(expanded),
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    return SafeArea(top: padTopSafeArea, bottom: false, child: bar);
  }
}

class _CameraPreviewBox extends StatelessWidget {
  const _CameraPreviewBox({required this.controller, this.mirror = false});

  final CameraController controller;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    final size = controller.value.previewSize;
    Widget preview;
    if (size == null) {
      preview = CameraPreview(controller);
    } else {
      // Preview size is landscape-oriented from the plugin; rotate for portrait UI.
      preview = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.height,
          height: size.width,
          child: CameraPreview(controller),
        ),
      );
    }
    if (mirror) {
      preview = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scaleByDouble(-1, 1, 1, 1),
        child: preview,
      );
    }
    return ClipRect(child: preview);
  }
}

class _FramingGuide extends StatelessWidget {
  const _FramingGuide();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GuidePainter(
        color: Colors.white.withValues(alpha: 0.85),
        dim: Colors.black.withValues(alpha: 0.35),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _GuidePainter extends CustomPainter {
  _GuidePainter({required this.color, required this.dim});

  final Color color;
  final Color dim;

  @override
  void paint(Canvas canvas, Size size) {
    // Receipt-ish portrait frame ~3:5 inside the preview.
    final targetW = size.width * 0.72;
    final targetH = targetW * (5 / 3);
    final h = math.min(targetH, size.height * 0.78);
    final w = h * (3 / 5);
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: w,
      height: h,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    final dimPath = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(dimPath, Paint()..color = dim);

    final border = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    const dash = 8.0;
    const gap = 6.0;
    _drawDashedRRect(canvas, rrect, border, dash, gap);
  }

  void _drawDashedRRect(
    Canvas canvas,
    RRect rrect,
    Paint paint,
    double dash,
    double gap,
  ) {
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GuidePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dim != dim;
}

class _ReviewBar extends StatelessWidget {
  const _ReviewBar({
    required this.canAddMore,
    required this.onRetake,
    required this.onAddMore,
    required this.onSubmit,
  });

  final bool canAddMore;
  final VoidCallback onRetake;
  final VoidCallback onAddMore;
  final VoidCallback onSubmit;

  static const double _btnH = 52;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final outline = OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white70),
      minimumSize: const Size(0, _btnH),
      maximumSize: const Size(double.infinity, _btnH),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
    return Material(
      color: Colors.black,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomInset),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: OutlinedButton(
                onPressed: onRetake,
                style: outline,
                child: Text('receipt_camera_retake'.tr()),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'receipt_camera_add_more'.tr(),
              child: SizedBox(
                width: _btnH,
                height: _btnH,
                child: OutlinedButton(
                  onPressed: canAddMore ? onAddMore : null,
                  style: outline.copyWith(
                    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                    minimumSize: const WidgetStatePropertyAll(
                      Size(_btnH, _btnH),
                    ),
                    maximumSize: const WidgetStatePropertyAll(
                      Size(_btnH, _btnH),
                    ),
                  ),
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 22,
                    color: canAddMore ? Colors.white : Colors.white38,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: FilledButton(
                onPressed: onSubmit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, _btnH),
                  maximumSize: const Size(double.infinity, _btnH),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text('submit'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Filmstrip extends StatelessWidget {
  const _Filmstrip({
    required this.captures,
    required this.selectedIndex,
    required this.motion,
    required this.onTap,
    required this.onRemove,
  });

  final List<XFile> captures;
  final int? selectedIndex;
  final Duration motion;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: motion,
      curve: AppMotion.enterCurve,
      alignment: Alignment.topCenter,
      child: captures.isEmpty
          ? const SizedBox(height: 8)
          : SizedBox(
              height: 88,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: captures.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final file = captures[i];
                  final selected = selectedIndex == i;
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: motion,
                    curve: AppMotion.enterCurve,
                    builder: (context, t, child) {
                      return Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset((1 - t) * 24, 0),
                          child: child,
                        ),
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedContainer(
                          duration: motion,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? cs.primary
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: Material(
                            borderRadius: BorderRadius.circular(10),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => onTap(i),
                              child: _XFileImage(
                                file: file,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: IconButton(
                            iconSize: 16,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => onRemove(i),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.canCapture,
    required this.atMax,
    required this.hasCaptures,
    required this.shutterPressed,
    required this.shake,
    required this.motion,
    required this.onShutter,
    required this.onSubmit,
  });

  final bool canCapture;
  final bool atMax;
  final bool hasCaptures;
  final bool shutterPressed;
  final bool shake;
  final Duration motion;
  final VoidCallback onShutter;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          children: [
            const SizedBox(width: 88),
            Expanded(
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: shake ? 1 : 0),
                  duration: const Duration(milliseconds: 200),
                  builder: (context, t, child) {
                    final dx = math.sin(t * math.pi * 4) * 6 * (1 - t);
                    return Transform.translate(
                      offset: Offset(dx, 0),
                      child: child,
                    );
                  },
                  child: AnimatedScale(
                    scale: shutterPressed ? 0.92 : 1,
                    duration: motion == Duration.zero
                        ? Duration.zero
                        : const Duration(milliseconds: 120),
                    child: AnimatedOpacity(
                      opacity: canCapture || atMax ? 1 : 0.45,
                      duration: motion,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onShutter,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(
                                  alpha: atMax && !canCapture ? 0.4 : 1,
                                ),
                                width: 4,
                              ),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(
                                  alpha: canCapture ? 1 : 0.35,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 88,
              child: AnimatedOpacity(
                opacity: hasCaptures ? 1 : 0,
                duration: motion,
                child: FilledButton(
                  onPressed: onSubmit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Text(
                    'submit'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionState extends StatelessWidget {
  const _PermissionState({
    required this.onOpenSettings,
    required this.onClose,
    required this.onGallery,
  });

  final Future<void> Function() onOpenSettings;
  final VoidCallback onClose;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return _EmptyState(
      message: 'receipt_camera_permission_body'.tr(),
      onClose: onClose,
      onGallery: onGallery,
      extra: TextButton.icon(
        onPressed: () => onOpenSettings(),
        icon: const Icon(Icons.settings, color: Colors.white),
        label: Text(
          'permission_open_settings'.tr(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    required this.onClose,
    required this.onGallery,
    this.extra,
  });

  final String message;
  final VoidCallback onClose;
  final VoidCallback onGallery;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            const Spacer(),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 24),
            if (extra != null) ...[extra!, const SizedBox(height: 12)],
            FilledButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text('gallery'.tr()),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// Loads an [XFile] via bytes (works for mock captures and native paths).
class _XFileImage extends StatefulWidget {
  const _XFileImage({
    required this.file,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final XFile file;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  State<_XFileImage> createState() => _XFileImageState();
}

class _XFileImageState extends State<_XFileImage> {
  late final Future<Uint8List> _bytes = widget.file.readAsBytes();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snap) {
        if (!snap.hasData) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return Image.memory(
          snap.data!,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          gaplessPlayback: true,
        );
      },
    );
  }
}
