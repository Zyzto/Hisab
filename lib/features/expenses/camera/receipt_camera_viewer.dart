import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/motion/app_motion.dart';
import 'gallery_latest_thumb.dart';
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
    this.galleryThumb,
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

  /// Seed for the gallery button thumbnail (e.g. last expense photo).
  final Uint8List? galleryThumb;

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
  Uint8List? _galleryThumbBytes;
  final GlobalKey<_SamsungZoomBarState> _zoomBarKey =
      GlobalKey<_SamsungZoomBarState>();

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
    // Seed until device gallery latest arrives (Samsung-style roll thumb).
    _galleryThumbBytes = widget.galleryThumb;
    _controller.addListener(_onControllerChanged);
    widget.onBindCloseRequest?.call(_requestClose);
    if (_session.isReviewing) {
      _pageController = PageController(initialPage: _session.viewingIndex!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.initialize(context);
      unawaited(_loadDeviceGalleryThumb());
    });
  }

  Future<void> _loadDeviceGalleryThumb() async {
    final bytes = await fetchLatestGalleryThumb();
    if (!mounted || bytes == null || bytes.isEmpty) return;
    setState(() => _galleryThumbBytes = bytes);
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

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _syncOrientationFromView();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncOrientationFromView();
  }

  void _syncOrientationFromView() {
    if (!mounted) return;
    // Hardware camera already streams deviceOrientation; mock needs the view.
    if (!_controller.isMock && _controller.camera != null) return;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    _controller.setDeviceOrientation(
      landscape
          ? DeviceOrientation.landscapeLeft
          : DeviceOrientation.portraitUp,
    );
  }

  DeviceOrientation get _sensorOrientation => _controller.deviceOrientation;

  bool get _isLandscapeOrientation {
    final o = _sensorOrientation;
    return o == DeviceOrientation.landscapeLeft ||
        o == DeviceOrientation.landscapeRight;
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
              const IgnorePointer(child: ColoredBox(color: Color(0x66FFFFFF))),
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
    final orientation = _sensorOrientation;
    final landscape = _isLandscapeOrientation;

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
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final captureDock = reviewing
        ? _ReviewBar(
            canAddMore: !_session.atMax,
            onRetake: _retakeCurrent,
            onAddMore: _addMore,
            onSubmit: _submit,
            orientation: orientation,
          )
        : _CaptureDock(
            orientation: orientation,
            canCapture: _session.canCapture && _controller.isReady,
            atMax: _session.atMax,
            shutterPressed: _shutterPressed,
            shake: _shakeShutter,
            motion: _motion,
            galleryThumbBytes: _galleryThumbBytes,
            canSwitchLens: _controller.canSwitchLens,
            onGallery: _requestGallery,
            onShutter: _onShutter,
            onSwitchLens: () => _controller.switchLens(),
            zoomBar: _controller.lensStops.isEmpty
                ? const SizedBox.shrink()
                : _SamsungZoomBar(
                    key: _zoomBarKey,
                    stops: _controller.lensStops,
                    zoom: _controller.zoom,
                    minZoom: _controller.minZoom,
                    maxZoom: _controller.maxZoom,
                    activeStopIndex: _controller.activeLensStopIndex,
                    zoomSupported: _controller.zoomSupported,
                    orientation: orientation,
                    onSelectStop: _controller.setZoom,
                    onZoom: _controller.setZoom,
                  ),
          );

    // Full-bleed preview; chrome docks to the sensor edge (Samsung landscape).
    return Stack(
      fit: StackFit.expand,
      children: [
        if (!reviewing)
          Positioned.fill(
            child: GestureDetector(
              onScaleStart: _controller.zoomSupported
                  ? (_) {
                      _pinchStartZoom = _controller.zoom;
                      _zoomBarKey.currentState?.openRuler();
                    }
                  : null,
              onScaleUpdate: _controller.zoomSupported
                  ? (d) {
                      _zoomBarKey.currentState?.openRuler();
                      _controller.setZoom(_pinchStartZoom * d.scale);
                    }
                  : null,
              child: livePreview,
            ),
          )
        else if (_pageController != null)
          Positioned.fill(
            child: PageView.builder(
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
          ),
        if (widget.scanAfter && !reviewing)
          Positioned.fill(
            child: IgnorePointer(
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
                  child: _FramingGuide(landscape: landscape),
                ),
              ),
            ),
          ),
        if (widget.scanAfter && !reviewing && !_session.hintDismissed)
          _SensorEdge(
            orientation: orientation,
            edge: _ChromeEdge.hint,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: _Upright(
                orientation: orientation,
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
            ),
          ),
        _SensorEdge(
          orientation: orientation,
          edge: _ChromeEdge.tools,
          child: _TopBar(
            expanded: widget.expanded,
            onClose: _requestClose,
            onToggleExpanded: widget.onToggleExpanded,
            onSubmit: !reviewing && _session.hasCaptures ? _submit : null,
            torchSupported: !reviewing && _controller.torchSupported,
            torchOn: _controller.torchOn,
            onTorch: () => _controller.setTorch(!_controller.torchOn),
            orientation: orientation,
            motion: _modalMotion,
          ),
        ),
        if (_session.hasCaptures)
          _SensorEdge(
            orientation: orientation,
            edge: _ChromeEdge.filmstrip,
            child: _Filmstrip(
              captures: _session.captures,
              selectedIndex: viewingIndex,
              motion: _motion,
              orientation: orientation,
              onTap: _openStripItem,
              onRemove: _removeStripItem,
            ),
          ),
        _SensorEdge(
          orientation: orientation,
          edge: _ChromeEdge.capture,
          child: captureDock,
        ),
      ],
    );
  }
}

/// Where chrome sits on the portrait-locked canvas for a sensor orientation.
///
/// Activity stays portrait; sensor landscape docks to the short physical edge
/// (bottom ≈ physical right for [DeviceOrientation.landscapeLeft]).
enum _ChromeEdge { tools, capture, filmstrip, hint }

class _SensorEdge extends StatelessWidget {
  const _SensorEdge({
    required this.orientation,
    required this.edge,
    required this.child,
  });

  final DeviceOrientation orientation;
  final _ChromeEdge edge;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Map sensor → dock side on the portrait-locked canvas.
    // Do not offset tools by MediaQuery.padding.top: the host already places
    // SheetHandleBar (with SafeArea) above this viewer — pad.top left a gap.
    final useTop =
        orientation == DeviceOrientation.portraitDown ||
        orientation == DeviceOrientation.landscapeRight;
    final useBottom = !useTop;

    return switch (edge) {
      _ChromeEdge.tools =>
        useTop
            ? Positioned(left: 0, right: 0, bottom: 0, child: child)
            : Positioned(left: 0, right: 0, top: 0, child: child),
      _ChromeEdge.capture =>
        useBottom
            ? Positioned(left: 0, right: 0, bottom: 0, child: child)
            : Positioned(left: 0, right: 0, top: 0, child: child),
      _ChromeEdge.filmstrip =>
        useBottom
            ? Positioned(left: 0, right: 0, bottom: 168, child: child)
            : Positioned(left: 0, right: 0, top: 168, child: child),
      _ChromeEdge.hint =>
        useBottom
            ? Positioned(left: 0, right: 0, bottom: 200, child: child)
            : Positioned(left: 0, right: 0, top: 200, child: child),
    };
  }
}

/// Keeps [child] gravity-upright from sensor orientation (shortest turn).
class _Upright extends StatelessWidget {
  const _Upright({required this.orientation, required this.child});

  final DeviceOrientation orientation;
  final Widget child;

  static double _radians(DeviceOrientation o) => switch (o) {
    DeviceOrientation.portraitUp => 0,
    DeviceOrientation.landscapeRight => math.pi / 2,
    DeviceOrientation.portraitDown => math.pi,
    DeviceOrientation.landscapeLeft => -math.pi / 2,
  };

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedRotation(
      // turns in [-0.25, 0.5] so landscapeLeft does not spin the long way.
      turns: _radians(orientation) / (2 * math.pi),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 180),
      curve: AppMotion.enterCurve,
      child: child,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.expanded,
    required this.onClose,
    required this.onToggleExpanded,
    required this.onSubmit,
    required this.torchSupported,
    required this.torchOn,
    required this.onTorch,
    required this.orientation,
    required this.motion,
  });

  final bool expanded;
  final VoidCallback onClose;
  final VoidCallback onToggleExpanded;
  final VoidCallback? onSubmit;
  final bool torchSupported;
  final bool torchOn;
  final VoidCallback onTorch;
  final DeviceOrientation orientation;
  final Duration motion;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              _Upright(
                orientation: orientation,
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              const Spacer(),
              if (torchSupported)
                _Upright(
                  orientation: orientation,
                  child: IconButton(
                    tooltip: 'receipt_camera_torch'.tr(),
                    onPressed: onTorch,
                    icon: Icon(
                      torchOn ? Icons.flash_on : Icons.flash_off,
                      color: torchOn ? _kZoomAccent : Colors.white,
                    ),
                  ),
                ),
              if (onSubmit != null)
                _Upright(
                  orientation: orientation,
                  child: TextButton(
                    onPressed: onSubmit,
                    child: Text(
                      'submit'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              _Upright(
                orientation: orientation,
                child: IconButton(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const Color _kZoomAccent = Color(0xFFFFCC00);
const Color _kZoomPill = Color(0xCC1A1A1A);
const Color _kZoomSelectedChip = Color(0xFFD0D0D0);

/// Collapsed pill: `.6` / `1x` / `2` / `3`. Expanded row: no `x` except readout.
String _formatZoomPreset(double z, {required bool collapsedSelected}) {
  if (z < 1) {
    final tenth = (z * 10).round();
    return '.${tenth.clamp(1, 9)}';
  }
  if ((z - 1).abs() < 0.05) return collapsedSelected ? '1x' : '1';
  if ((z - z.roundToDouble()).abs() < 0.05) return '${z.round()}';
  return z.toStringAsFixed(1);
}

String _formatZoomReadout(double z) {
  final v = z < 10 ? z.toStringAsFixed(1) : z.toStringAsFixed(0);
  return '$v x';
}

/// Finger drag → zoom. Uses octaves so 0.6×→30× stays usable (linear px/×
/// crawls at high zoom). ~[pxPerOctave] px doubles/halves the ratio.
double _zoomAfterHorizontalDrag({
  required double zoom,
  required double deltaDx,
  required double minZoom,
  required double maxZoom,
  double pxPerOctave = _ZoomRuler.pxPerOctave,
}) {
  final lo = math.max(minZoom, 0.01);
  final hi = math.max(maxZoom, lo + 0.01);
  // Drag right → lower zoom (matches ticks sliding under the needle).
  final next = zoom * math.pow(2.0, -deltaDx / pxPerOctave);
  return next.clamp(lo, hi).toDouble();
}

/// Primary lenses shown in the collapsed pill (Samsung: .6 / 1x / 2 / 3).
List<double> _primaryZoomStops(List<double> stops) {
  if (stops.length <= 4) return stops;
  final preferred = <double>[];
  void takeNear(double target) {
    double? best;
    for (final s in stops) {
      if ((s - target).abs() > 0.15) continue;
      if (best == null || (s - target).abs() < (best - target).abs()) {
        best = s;
      }
    }
    if (best != null && preferred.every((p) => (p - best!).abs() > 0.08)) {
      preferred.add(best);
    }
  }

  takeNear(stops.first);
  takeNear(1);
  takeNear(2);
  takeNear(3);
  if (preferred.length < 4) {
    for (final s in stops) {
      if (preferred.length >= 4) break;
      if (preferred.every((p) => (p - s).abs() > 0.08)) preferred.add(s);
    }
  }
  preferred.sort();
  return preferred;
}

/// Samsung Camera zoom: collapsed pill → fine ruler + preset row.
class _SamsungZoomBar extends StatefulWidget {
  const _SamsungZoomBar({
    super.key,
    required this.stops,
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
    required this.activeStopIndex,
    required this.zoomSupported,
    required this.orientation,
    required this.onSelectStop,
    required this.onZoom,
  });

  final List<double> stops;
  final double zoom;
  final double minZoom;
  final double maxZoom;
  final int activeStopIndex;
  final bool zoomSupported;
  final DeviceOrientation orientation;
  final ValueChanged<double> onSelectStop;
  final ValueChanged<double> onZoom;

  @override
  State<_SamsungZoomBar> createState() => _SamsungZoomBarState();
}

class _SamsungZoomBarState extends State<_SamsungZoomBar> {
  bool _rulerOpen = false;
  Timer? _autoClose;

  void openRuler() {
    if (!widget.zoomSupported) return;
    _autoClose?.cancel();
    if (!_rulerOpen) setState(() => _rulerOpen = true);
    _scheduleAutoClose();
  }

  void closeRuler() {
    _autoClose?.cancel();
    if (_rulerOpen) setState(() => _rulerOpen = false);
  }

  void _scheduleAutoClose() {
    _autoClose?.cancel();
    _autoClose = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) closeRuler();
    });
  }

  void _onZoomInteraction(double value) {
    openRuler();
    widget.onZoom(value);
  }

  int _activeIndexIn(List<double> stops) {
    if (stops.isEmpty) return 0;
    var idx = 0;
    for (var i = 0; i < stops.length; i++) {
      if (widget.zoom + 0.05 >= stops[i]) idx = i;
    }
    return idx;
  }

  @override
  void didUpdateWidget(covariant _SamsungZoomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_rulerOpen && (oldWidget.zoom - widget.zoom).abs() > 0.001) {
      _scheduleAutoClose();
    }
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 220);
    final primary = _primaryZoomStops(widget.stops);
    final presetStops = _rulerOpen ? widget.stops : primary;
    final activeInRow = _activeIndexIn(presetStops);

    // Whole zoom cluster uprights with the phone (pill reads vertical in landscape).
    return _Upright(
      orientation: widget.orientation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: duration,
            curve: AppMotion.enterCurve,
            alignment: Alignment.bottomCenter,
            child: !_rulerOpen
                ? const SizedBox.shrink()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatZoomReadout(widget.zoom),
                        style: const TextStyle(
                          color: _kZoomAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black54),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 280,
                        child: _ZoomRuler(
                          zoom: widget.zoom,
                          minZoom: widget.minZoom,
                          maxZoom: widget.maxZoom,
                          onZoom: _onZoomInteraction,
                          onClose: closeRuler,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Collapsed only: drag opens the ruler. When open, the ruler owns
            // zoom drag and the chip row scrolls — don't steal those gestures.
            onHorizontalDragStart: widget.zoomSupported && !_rulerOpen
                ? (_) => openRuler()
                : null,
            onHorizontalDragUpdate: widget.zoomSupported && !_rulerOpen
                ? (details) {
                    _onZoomInteraction(
                      _zoomAfterHorizontalDrag(
                        zoom: widget.zoom,
                        deltaDx: details.delta.dx,
                        minZoom: widget.minZoom,
                        maxZoom: widget.maxZoom,
                      ),
                    );
                  }
                : null,
            child: AnimatedContainer(
              duration: duration,
              curve: AppMotion.enterCurve,
              padding: EdgeInsets.symmetric(
                horizontal: _rulerOpen ? 10 : 8,
                vertical: _rulerOpen ? 4 : 6,
              ),
              decoration: _rulerOpen
                  ? null
                  : BoxDecoration(
                      color: _kZoomPill,
                      borderRadius: BorderRadius.circular(28),
                    ),
              child: _rulerOpen
                  ? SizedBox(
                      width: 280,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < presetStops.length; i++) ...[
                              if (i > 0) const SizedBox(width: 28),
                              _SamsungZoomPreset(
                                label: _formatZoomPreset(
                                  presetStops[i],
                                  collapsedSelected: false,
                                ),
                                selected: i == activeInRow,
                                expanded: true,
                                onTap: () {
                                  final stop = presetStops[i];
                                  final wasActive = i == activeInRow;
                                  widget.onSelectStop(stop);
                                  if (wasActive ||
                                      (widget.zoom - stop).abs() < 0.12) {
                                    openRuler();
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < presetStops.length; i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          _SamsungZoomPreset(
                            label: _formatZoomPreset(
                              presetStops[i],
                              collapsedSelected: i == activeInRow,
                            ),
                            selected: i == activeInRow,
                            expanded: false,
                            onTap: () {
                              final stop = presetStops[i];
                              final wasActive = i == activeInRow;
                              widget.onSelectStop(stop);
                              if (wasActive ||
                                  (widget.zoom - stop).abs() < 0.12) {
                                openRuler();
                              }
                            },
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SamsungZoomPreset extends StatelessWidget {
  const _SamsungZoomPreset({
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    // Collapsed: light-grey chip + dark text (native). Expanded: plain labels.
    final bg = !expanded && selected ? _kZoomSelectedChip : Colors.transparent;
    final color = !expanded && selected
        ? Colors.black87
        : (expanded && selected ? _kZoomAccent : Colors.white);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: reduce ? Duration.zero : const Duration(milliseconds: 160),
        curve: AppMotion.enterCurve,
        width: expanded ? null : 40,
        height: expanded ? 28 : 40,
        padding: expanded
            ? const EdgeInsets.symmetric(horizontal: 8)
            : EdgeInsets.zero,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: selected ? 15 : 14,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
            shadows: (!expanded && selected)
                ? null
                : const [Shadow(blurRadius: 4, color: Colors.black54)],
          ),
        ),
      ),
    );
  }
}

/// Horizontal tick ruler with fixed yellow center needle (Samsung fine zoom).
class _ZoomRuler extends StatelessWidget {
  const _ZoomRuler({
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoom,
    required this.onClose,
  });

  final double zoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onZoom;
  final VoidCallback onClose;

  /// Pixels to double (or halve) zoom — log dial, same feel from 1× to 30×.
  static const double pxPerOctave = 40;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kZoomPill,
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  onZoom(
                    _zoomAfterHorizontalDrag(
                      zoom: zoom,
                      deltaDx: details.delta.dx,
                      minZoom: minZoom,
                      maxZoom: maxZoom,
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(28),
                  ),
                  child: CustomPaint(
                    painter: _ZoomRulerPainter(
                      zoom: zoom.clamp(minZoom, maxZoom),
                      minZoom: minZoom,
                      maxZoom: maxZoom,
                      pxPerOctave: pxPerOctave,
                      accent: _kZoomAccent,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: onClose,
              iconSize: 18,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: Icon(
                Icons.close,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomRulerPainter extends CustomPainter {
  _ZoomRulerPainter({
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
    required this.pxPerOctave,
    required this.accent,
  });

  final double zoom;
  final double minZoom;
  final double maxZoom;
  final double pxPerOctave;
  final Color accent;

  double _xFor(double z, double midX) {
    return midX + math.log(z / zoom) / math.ln2 * pxPerOctave;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final midX = size.width / 2;
    final midY = size.height / 2;
    final lo = math.max(minZoom, 0.01);
    final hi = math.max(maxZoom, lo + 0.01);

    // Visible window in log space (± a bit past the edges).
    final octavesVisible = (midX + 8) / pxPerOctave;
    final zStart = (zoom / math.pow(2.0, octavesVisible)).clamp(lo, hi);
    final zEnd = (zoom * math.pow(2.0, octavesVisible)).clamp(lo, hi);

    // Even log subdivisions keep tick density stable across 0.6×…30×.
    final logStart = math.log(zStart);
    final logEnd = math.log(zEnd);
    final logStep = math.ln2 / 10; // 10 minors per octave
    final first = (logStart / logStep).floor() * logStep;
    for (var lg = first; lg <= logEnd + 1e-9; lg += logStep) {
      final z = math.exp(lg);
      if (z < lo - 1e-6 || z > hi + 1e-6) continue;
      final x = _xFor(z, midX);
      if (x < -2 || x > size.width + 2) continue;
      // Majors on power-of-two ratios (…0.5 / 1 / 2 / 4 / 8 / 16…).
      final log2z = lg / math.ln2;
      final isMajor = (log2z - log2z.roundToDouble()).abs() < 0.04;
      final h = isMajor ? 18.0 : 14.0;
      final tickPaint = Paint()
        ..color = Colors.white.withValues(alpha: isMajor ? 0.95 : 0.7)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(x, midY - h / 2),
        Offset(x, midY + h / 2),
        tickPaint,
      );
    }

    final needle = Paint()
      ..color = accent
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(midX, 6), Offset(midX, size.height - 6), needle);
  }

  @override
  bool shouldRepaint(covariant _ZoomRulerPainter oldDelegate) =>
      oldDelegate.zoom != zoom ||
      oldDelegate.minZoom != minZoom ||
      oldDelegate.maxZoom != maxZoom ||
      oldDelegate.pxPerOctave != pxPerOctave ||
      oldDelegate.accent != accent;
}

class _RoundCamButton extends StatelessWidget {
  const _RoundCamButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFF2A2A2A),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: 52, height: 52, child: Center(child: child)),
        ),
      ),
    );
  }
}

class _CameraPreviewBox extends StatelessWidget {
  const _CameraPreviewBox({required this.controller, this.mirror = false});

  final CameraController controller;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CameraValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (!value.isInitialized || value.previewSize == null) {
          return const ColoredBox(color: Colors.black);
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final landscape = _isLandscapeDeviceOrientation(
              value.lockedCaptureOrientation ?? value.deviceOrientation,
            );
            // CameraPreview already rotates for Android; match its aspect.
            final previewAspect = landscape
                ? value.aspectRatio
                : 1 / value.aspectRatio;
            final box = constraints.biggest;
            late final double w;
            late final double h;
            if (box.aspectRatio > previewAspect) {
              w = box.width;
              h = w / previewAspect;
            } else {
              h = box.height;
              w = h * previewAspect;
            }
            Widget preview = SizedBox(
              width: w,
              height: h,
              child: CameraPreview(controller),
            );
            if (mirror) {
              preview = Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..scaleByDouble(-1, 1, 1, 1),
                child: preview,
              );
            }
            return ClipRect(
              child: OverflowBox(
                alignment: Alignment.center,
                maxWidth: w,
                maxHeight: h,
                child: preview,
              ),
            );
          },
        );
      },
    );
  }
}

bool _isLandscapeDeviceOrientation(DeviceOrientation o) =>
    o == DeviceOrientation.landscapeLeft ||
    o == DeviceOrientation.landscapeRight;

class _FramingGuide extends StatelessWidget {
  const _FramingGuide({required this.landscape});

  final bool landscape;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GuidePainter(
        color: Colors.white.withValues(alpha: 0.85),
        dim: Colors.black.withValues(alpha: 0.35),
        landscape: landscape,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _GuidePainter extends CustomPainter {
  _GuidePainter({
    required this.color,
    required this.dim,
    required this.landscape,
  });

  final Color color;
  final Color dim;
  final bool landscape;

  @override
  void paint(Canvas canvas, Size size) {
    // Receipt frame: tall in portrait, wide in landscape.
    final double w;
    final double h;
    if (landscape) {
      final targetH = size.height * 0.72;
      final targetW = targetH * (5 / 3);
      w = math.min(targetW, size.width * 0.86);
      h = w * (3 / 5);
    } else {
      final targetW = size.width * 0.72;
      final targetH = targetW * (5 / 3);
      h = math.min(targetH, size.height * 0.78);
      w = h * (3 / 5);
    }
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
      oldDelegate.color != color ||
      oldDelegate.dim != dim ||
      oldDelegate.landscape != landscape;
}

class _ReviewBar extends StatelessWidget {
  const _ReviewBar({
    required this.canAddMore,
    required this.onRetake,
    required this.onAddMore,
    required this.onSubmit,
    required this.orientation,
  });

  final bool canAddMore;
  final VoidCallback onRetake;
  final VoidCallback onAddMore;
  final VoidCallback onSubmit;
  final DeviceOrientation orientation;

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
      color: Colors.black.withValues(alpha: 0.85),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomInset),
        child: _Upright(
          orientation: orientation,
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
      ),
    );
  }
}

class _Filmstrip extends StatelessWidget {
  const _Filmstrip({
    required this.captures,
    required this.selectedIndex,
    required this.motion,
    required this.orientation,
    required this.onTap,
    required this.onRemove,
  });

  final List<XFile> captures;
  final int? selectedIndex;
  final Duration motion;
  final DeviceOrientation orientation;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (captures.isEmpty) return const SizedBox.shrink();
    return _Upright(
      orientation: orientation,
      child: SizedBox(
        height: 88,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        color: selected ? cs.primary : Colors.transparent,
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

/// Shutter rail + zoom: docks to the sensor edge; controls stay upright.
class _CaptureDock extends StatelessWidget {
  const _CaptureDock({
    required this.orientation,
    required this.canCapture,
    required this.atMax,
    required this.shutterPressed,
    required this.shake,
    required this.motion,
    required this.galleryThumbBytes,
    required this.canSwitchLens,
    required this.onGallery,
    required this.onShutter,
    required this.onSwitchLens,
    required this.zoomBar,
  });

  final DeviceOrientation orientation;
  final bool canCapture;
  final bool atMax;
  final bool shutterPressed;
  final bool shake;
  final Duration motion;
  final Uint8List? galleryThumbBytes;
  final bool canSwitchLens;
  final VoidCallback onGallery;
  final VoidCallback onShutter;
  final VoidCallback onSwitchLens;
  final Widget zoomBar;

  static const double _sideSlot = 72;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final shutter = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: shake ? 1 : 0),
      duration: const Duration(milliseconds: 200),
      builder: (context, t, child) {
        final dx = math.sin(t * math.pi * 4) * 6 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
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
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(
                    alpha: canCapture ? 1 : (atMax ? 0.35 : 0.45),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Native order along the thumb edge: gallery · shutter · flip
    final rail = Row(
      children: [
        SizedBox(
          width: _sideSlot,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _Upright(
              orientation: orientation,
              child: _GalleryThumbButton(
                bytes: galleryThumbBytes,
                onPressed: onGallery,
              ),
            ),
          ),
        ),
        Expanded(child: Center(child: shutter)),
        SizedBox(
          width: _sideSlot,
          child: Align(
            alignment: Alignment.centerRight,
            child: canSwitchLens
                ? _Upright(
                    orientation: orientation,
                    child: _RoundCamButton(
                      tooltip: 'receipt_camera_lens_front'.tr(),
                      onPressed: onSwitchLens,
                      child: const Icon(
                        Icons.cameraswitch_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  )
                : const SizedBox(width: 52, height: 52),
          ),
        ),
      ],
    );

    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: Padding(
        padding: EdgeInsets.fromLTRB(28, 10, 28, 16 + bottomPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [zoomBar, const SizedBox(height: 12), rail],
        ),
      ),
    );
  }
}

class _GalleryThumbButton extends StatelessWidget {
  const _GalleryThumbButton({required this.bytes, required this.onPressed});

  final Uint8List? bytes;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'gallery'.tr(),
      child: Material(
        color: const Color(0xFF2A2A2A),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 52,
            height: 52,
            child: bytes == null
                ? const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white,
                    size: 24,
                  )
                : Image.memory(
                    bytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.photo_library_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
          ),
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
