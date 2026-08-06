import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/motion/app_motion.dart';
import '../../../core/navigation/invite_link_handler.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/navigation/route_transition_ready.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/widgets/toast.dart';

/// Invite QR scanner body (preview, frame, torch, permission) for sheet or page.
class InviteScannerView extends StatefulWidget {
  const InviteScannerView({
    super.key,
    required this.onClose,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final VoidCallback onClose;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  State<InviteScannerView> createState() => _InviteScannerViewState();
}

enum _ScanPhase { loading, permissionDenied, ready }

class _InviteScannerViewState extends State<InviteScannerView>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  _ScanPhase _phase = _ScanPhase.loading;
  bool _handled = false;
  bool _successFlash = false;
  DateTime? _lastInvalidToast;
  MobileScannerController? _controller;
  late final AnimationController _scanLine;
  VoidCallback? _cancelArmHardware;
  bool _hardwareStarted = false;

  Duration get _motion {
    if (!mounted) return AppMotion.page;
    return MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.page;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanLine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Sheet roll and GoRouter fade+slide both expose ModalRoute.animation.
      if (MediaQuery.disableAnimationsOf(context)) {
        _startHardware();
        return;
      }
      _cancelArmHardware = armWhenAnimationReady(
        context: context,
        action: () {
          if (!mounted) return;
          _startHardware();
        },
      );
    });
  }

  void _startHardware() {
    if (_hardwareStarted) return;
    _hardwareStarted = true;
    if (!_scanLine.isAnimating) {
      _scanLine.repeat(reverse: true);
    }
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    if (kIsWeb) {
      _attachController();
      if (!mounted) return;
      setState(() => _phase = _ScanPhase.ready);
      return;
    }

    final status = await Permission.camera.status;
    if (!mounted) return;
    if (status.isPermanentlyDenied) {
      setState(() => _phase = _ScanPhase.permissionDenied);
      return;
    }
    if (!status.isGranted && !status.isLimited) {
      final granted = await PermissionService.requestCameraPermission(context);
      if (!mounted) return;
      if (!granted) {
        setState(() => _phase = _ScanPhase.permissionDenied);
        return;
      }
    }

    _attachController();
    if (!mounted) return;
    setState(() => _phase = _ScanPhase.ready);
  }

  void _attachController() {
    _controller?.dispose();
    _controller = MobileScannerController(
      facing: CameraFacing.back,
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 250,
    );
  }

  @override
  void dispose() {
    _cancelArmHardware?.call();
    WidgetsBinding.instance.removeObserver(this);
    _scanLine.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || _phase != _ScanPhase.ready || _handled) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(c.pause());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_resumeAfterForeground());
    }
  }

  Future<void> _resumeAfterForeground() async {
    if (!kIsWeb) {
      final granted = await PermissionService.isCameraPermissionGranted();
      if (!mounted) return;
      if (!granted) {
        await _controller?.stop();
        setState(() => _phase = _ScanPhase.permissionDenied);
        return;
      }
    }
    final c = _controller;
    if (c == null) return;
    try {
      await c.start();
    } catch (e) {
      Log.debug('Invite scanner start failed', error: e);
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled || !mounted) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      final uri = Uri.tryParse(raw);
      final token = extractInviteTokenFromUri(uri);
      if (token != null) {
        _handled = true;
        HapticFeedback.mediumImpact();
        setState(() => _successFlash = true);
        await Future<void>.delayed(
          MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
        );
        await _controller?.stop();
        if (!mounted) return;
        // Capture router before closing the modal (which disposes this view).
        final router = GoRouter.of(context);
        widget.onClose();
        router.go(RoutePaths.inviteAccept(token));
        return;
      }
    }
    final now = DateTime.now();
    if (_lastInvalidToast == null ||
        now.difference(_lastInvalidToast!) > const Duration(seconds: 2)) {
      _lastInvalidToast = now;
      if (capture.barcodes.any((b) => (b.rawValue ?? '').isNotEmpty)) {
        context.showToast('scan_invite_invalid'.tr());
      }
    }
  }

  Future<void> _toggleTorch() async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.toggleTorch();
    } catch (e) {
      Log.debug('Invite scanner torch toggle failed', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: AnimatedSwitcher(
        duration: _motion,
        switchInCurve: AppMotion.enterCurve,
        switchOutCurve: AppMotion.exitCurve,
        child: KeyedSubtree(
          key: ValueKey(_phase),
          child: switch (_phase) {
            _ScanPhase.loading => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            _ScanPhase.permissionDenied => _PermissionBody(
              onClose: widget.onClose,
              onOpenSettings: openAppSettings,
            ),
            _ScanPhase.ready => _ScannerBody(
              controller: _controller!,
              scanLine: _scanLine,
              successFlash: _successFlash,
              expanded: widget.expanded,
              onClose: widget.onClose,
              onToggleExpanded: widget.onToggleExpanded,
              onDetect: _onDetect,
              onToggleTorch: _toggleTorch,
              motion: _motion,
            ),
          },
        ),
      ),
    );
  }
}

String _inviteScannerErrorMessage(MobileScannerException error) {
  final raw = error.errorDetails?.message ?? '';
  final lower = raw.toLowerCase();
  if (kIsWeb ||
      lower.contains('browser') ||
      lower.contains('not support') ||
      error.errorCode == MobileScannerErrorCode.unsupported) {
    return 'scan_invite_camera_unavailable'.tr();
  }
  if (raw.isNotEmpty) return raw;
  return 'scan_invite_camera_unavailable'.tr();
}

class _ScannerBody extends StatefulWidget {
  const _ScannerBody({
    required this.controller,
    required this.scanLine,
    required this.successFlash,
    required this.expanded,
    required this.onClose,
    required this.onToggleExpanded,
    required this.onDetect,
    required this.onToggleTorch,
    required this.motion,
  });

  final MobileScannerController controller;
  final Animation<double> scanLine;
  final bool successFlash;
  final bool expanded;
  final VoidCallback onClose;
  final VoidCallback onToggleExpanded;
  final void Function(BarcodeCapture) onDetect;
  final VoidCallback onToggleTorch;
  final Duration motion;

  @override
  State<_ScannerBody> createState() => _ScannerBodyState();
}

class _ScannerBodyState extends State<_ScannerBody> {
  /// Set from [MobileScanner.errorBuilder] after the frame — never rebuild the
  /// body from [MobileScannerController] notifications during [MobileScanner]
  /// build (that hits Flutter's `!_dirty` assert).
  bool _hasError = false;
  String? _errorMessage;

  void _reportError(MobileScannerException error) {
    final message = _inviteScannerErrorMessage(error);
    if (_hasError && _errorMessage == message) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = message;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: widget.controller,
          onDetect: widget.onDetect,
          errorBuilder: (context, error) {
            _reportError(error);
            return _ErrorBody(
              message: _errorMessage ?? _inviteScannerErrorMessage(error),
            );
          },
        ),
        if (!_hasError) ...[
          IgnorePointer(
            child: AnimatedBuilder(
              animation: widget.scanLine,
              builder: (context, _) {
                return CustomPaint(
                  painter: _QrFramePainter(
                    scanT: widget.scanLine.value,
                    success: widget.successFlash,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
          if (widget.successFlash)
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: widget.successFlash ? 0.35 : 0,
                duration: widget.motion == Duration.zero
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                child: const ColoredBox(color: Color(0xFF43A047)),
              ),
            ),
        ],
        // Handle already clears the status bar — don't double-pad (that left a
        // gap above the top bar). Stretch the bar edge-to-edge.
        Column(
          children: [
            _TopBar(
              controller: widget.controller,
              expanded: widget.expanded,
              onClose: widget.onClose,
              onToggleExpanded: widget.onToggleExpanded,
              onToggleTorch: widget.onToggleTorch,
              motion: widget.motion,
              showTorch: !_hasError,
            ),
            const Spacer(),
            if (!_hasError)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: AnimatedOpacity(
                    opacity: widget.successFlash ? 0 : 1,
                    duration: widget.motion,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: Text(
                          'scan_invite_hint'.tr(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.expanded,
    required this.onClose,
    required this.onToggleExpanded,
    required this.onToggleTorch,
    required this.motion,
    this.showTorch = true,
  });

  final MobileScannerController controller;
  final bool expanded;
  final VoidCallback onClose;
  final VoidCallback onToggleExpanded;
  final VoidCallback onToggleTorch;
  final Duration motion;
  final bool showTorch;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
              Expanded(
                child: Text(
                  'scan_invite_title'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (showTorch)
                _TorchButton(
                  controller: controller,
                  onToggleTorch: onToggleTorch,
                  motion: motion,
                )
              else
                const SizedBox(width: 48),
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
        ),
      ),
    );
  }
}

/// Torch control that rebuilds after the frame when the scanner controller
/// notifies — avoids `!_dirty` if [MobileScanner] updates mid-build.
class _TorchButton extends StatefulWidget {
  const _TorchButton({
    required this.controller,
    required this.onToggleTorch,
    required this.motion,
  });

  final MobileScannerController controller;
  final VoidCallback onToggleTorch;
  final Duration motion;

  @override
  State<_TorchButton> createState() => _TorchButtonState();
}

class _TorchButtonState extends State<_TorchButton> {
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _TorchButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final torch = widget.controller.value.torchState;
    if (torch == TorchState.unavailable) {
      return const SizedBox.shrink();
    }
    final on = torch == TorchState.on;
    return IconButton(
      tooltip: 'scan_invite_torch'.tr(),
      onPressed: widget.onToggleTorch,
      icon: AnimatedSwitcher(
        duration: widget.motion == Duration.zero
            ? Duration.zero
            : const Duration(milliseconds: 150),
        child: Icon(
          on ? Icons.flash_on : Icons.flash_off,
          key: ValueKey(on),
          color: on ? Colors.amber : Colors.white,
        ),
      ),
    );
  }
}

class _PermissionBody extends StatelessWidget {
  const _PermissionBody({required this.onClose, required this.onOpenSettings});

  final VoidCallback onClose;
  final Future<bool> Function() onOpenSettings;

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
            Icon(
              Icons.qr_code_scanner,
              size: 64,
              color: Colors.white.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 20),
            Text(
              'scan_invite_permission_body'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => onOpenSettings(),
              icon: const Icon(Icons.settings),
              label: Text('permission_open_settings'.tr()),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    // Close lives in [_TopBar] only — avoid a second X over the chrome.
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 72, 32, 32),
      child: Column(
        children: [
          const Spacer(),
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.white),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _QrFramePainter extends CustomPainter {
  _QrFramePainter({required this.scanT, required this.success});

  final double scanT;
  final bool success;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height) * 0.68;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 12),
      width: side,
      height: side,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));

    final dim = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.55));

    final accent = success ? const Color(0xFF66BB6A) : Colors.white;
    final cornerPaint = Paint()
      ..color = accent.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    void corner(Offset o, double sx, double sy) {
      canvas.drawLine(o, o + Offset(len * sx, 0), cornerPaint);
      canvas.drawLine(o, o + Offset(0, len * sy), cornerPaint);
    }

    corner(rect.topLeft, 1, 1);
    corner(rect.topRight, -1, 1);
    corner(rect.bottomLeft, 1, -1);
    corner(rect.bottomRight, -1, -1);

    if (!success) {
      final y = rect.top + 8 + (rect.height - 16) * scanT;
      final line = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.85),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(rect.left, y - 1, rect.width, 2));
      canvas.drawRect(
        Rect.fromLTWH(rect.left + 10, y, rect.width - 20, 2),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _QrFramePainter oldDelegate) =>
      oldDelegate.scanT != scanT || oldDelegate.success != success;
}
