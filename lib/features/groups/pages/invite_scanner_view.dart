import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:safaeh/safaeh.dart';

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
    if (!MediaQuery.disableAnimationsOf(context) && !_scanLine.isAnimating) {
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
        await HapticFeedback.mediumImpact();
        if (!mounted) return;
        setState(() {
          _successFlash = true;
          _scanLine.stop();
        });
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
            _ScanPhase.permissionDenied => SafaehQrMessageBody(
              onClose: widget.onClose,
              message: Text(
                'scan_invite_permission_body'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white),
              ),
              action: FilledButton.icon(
                onPressed: openAppSettings,
                icon: const Icon(Icons.settings),
                label: Text('permission_open_settings'.tr()),
              ),
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
        RepaintBoundary(
          child: MobileScanner(
            controller: widget.controller,
            onDetect: widget.onDetect,
            errorBuilder: (context, error) {
              _reportError(error);
              return SafaehQrMessageBody(
                safeArea: false,
                padding: const EdgeInsets.fromLTRB(32, 72, 32, 32),
                icon: Icons.error_outline,
                iconColor: Theme.of(context).colorScheme.error,
                message: Text(
                  _errorMessage ?? _inviteScannerErrorMessage(error),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.white),
                ),
              );
            },
          ),
        ),
        if (!_hasError)
          SafaehQrScannerOverlay(
            scanLine: widget.scanLine,
            success: widget.successFlash,
            expanded: widget.expanded,
            onClose: widget.onClose,
            onToggleExpanded: widget.onToggleExpanded,
            motion: widget.motion,
            expandTooltip: 'receipt_camera_expand'.tr(),
            collapseTooltip: 'receipt_camera_collapse'.tr(),
            title: _title(context),
            torch: _TorchButton(
              controller: widget.controller,
              onToggleTorch: widget.onToggleTorch,
              motion: widget.motion,
            ),
            hint: Material(
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ),
          )
        else
          SafaehQrTopBar(
            expanded: widget.expanded,
            onClose: widget.onClose,
            onToggleExpanded: widget.onToggleExpanded,
            motion: widget.motion,
            expandTooltip: 'receipt_camera_expand'.tr(),
            collapseTooltip: 'receipt_camera_collapse'.tr(),
            title: _title(context),
          ),
      ],
    );
  }

  Widget _title(BuildContext context) {
    return Text(
      'scan_invite_title'.tr(),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
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
