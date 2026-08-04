import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/services/permission_service.dart';
import 'receipt_camera_mock_preview.dart';

/// High-level camera readiness for the receipt viewer.
enum ReceiptCameraStatus { loading, permissionDenied, noCamera, ready, error }

/// Owns a [CameraController] for receipt capture (back camera, torch, lifecycle).
class ReceiptCameraController extends ChangeNotifier {
  ReceiptCameraController({bool mock = false}) : _mockMode = mock;

  /// Test-only controller that skips hardware init and stays at [initialStatus].
  @visibleForTesting
  ReceiptCameraController.forTest({
    ReceiptCameraStatus initialStatus = ReceiptCameraStatus.noCamera,
    String? errorMessage,
  }) : _testMode = true,
       _mockMode = false,
       _status = initialStatus,
       _errorMessage = errorMessage;

  CameraController? _camera;
  ReceiptCameraStatus _status = ReceiptCameraStatus.loading;
  String? _errorMessage;
  bool _torchOn = false;
  bool _torchSupported = false;
  double _minZoom = 1;
  double _maxZoom = 1;
  double _zoom = 1;
  bool _disposed = false;
  bool _testMode = false;
  final bool _mockMode;
  bool _mockPaused = false;

  ReceiptCameraStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get torchOn => _torchOn;
  bool get torchSupported => _torchSupported;
  bool get zoomSupported => _maxZoom > _minZoom + 0.01;
  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;
  double get zoom => _zoom;
  CameraController? get camera => _camera;
  bool get isMock => _mockMode;
  bool get mockPaused => _mockPaused;
  bool get isReady =>
      _status == ReceiptCameraStatus.ready &&
      (_mockMode || (_camera != null && _camera!.value.isInitialized));

  /// Request permission, pick back camera, initialize preview.
  Future<void> initialize(BuildContext context) async {
    if (_disposed) return;
    if (_testMode) {
      notifyListeners();
      return;
    }

    if (_mockMode) {
      _status = ReceiptCameraStatus.loading;
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (_disposed) return;
      _torchSupported = true;
      _torchOn = false;
      _minZoom = 1;
      _maxZoom = 3;
      _zoom = 1;
      _mockPaused = false;
      _status = ReceiptCameraStatus.ready;
      notifyListeners();
      return;
    }

    _status = ReceiptCameraStatus.loading;
    _errorMessage = null;
    notifyListeners();

    // Avoid stacking PermissionService's Settings sheet on top of our inline
    // denied UI when the user already permanently denied camera.
    final status = await Permission.camera.status;
    if (_disposed || !context.mounted) return;
    if (status.isPermanentlyDenied) {
      _status = ReceiptCameraStatus.permissionDenied;
      notifyListeners();
      return;
    }
    if (!status.isGranted && !status.isLimited) {
      final granted = await PermissionService.requestCameraPermission(context);
      if (_disposed || !context.mounted) return;
      if (!granted) {
        _status = ReceiptCameraStatus.permissionDenied;
        notifyListeners();
        return;
      }
    }

    try {
      final cameras = await availableCameras();
      if (_disposed) return;
      if (cameras.isEmpty) {
        _status = ReceiptCameraStatus.noCamera;
        notifyListeners();
        return;
      }

      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        back,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (_disposed) {
        await controller.dispose();
        return;
      }

      _camera = controller;
      await _probeTorchAndZoom();
      if (_disposed) return;

      _status = ReceiptCameraStatus.ready;
      notifyListeners();
    } catch (e, stack) {
      debugPrint('ReceiptCameraController init failed: $e');
      debugPrintStack(stackTrace: stack);
      _errorMessage = e.toString();
      _status = ReceiptCameraStatus.error;
      notifyListeners();
    }
  }

  Future<void> _probeTorchAndZoom() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;

    try {
      _minZoom = await cam.getMinZoomLevel();
      _maxZoom = await cam.getMaxZoomLevel();
      _zoom = _minZoom;
    } catch (_) {
      _minZoom = 1;
      _maxZoom = 1;
      _zoom = 1;
    }

    _torchSupported = false;
    _torchOn = false;
    try {
      await cam.setFlashMode(FlashMode.off);
      // Some devices throw when torch is unsupported; probe by toggling briefly.
      await cam.setFlashMode(FlashMode.torch);
      await cam.setFlashMode(FlashMode.off);
      _torchSupported = true;
    } catch (_) {
      _torchSupported = false;
      try {
        await cam.setFlashMode(FlashMode.off);
      } catch (_) {}
    }
  }

  Future<void> setTorch(bool on) async {
    if (_mockMode) {
      if (!_torchSupported) return;
      _torchOn = on;
      notifyListeners();
      return;
    }
    final cam = _camera;
    if (!_torchSupported || cam == null || !cam.value.isInitialized) return;
    try {
      await cam.setFlashMode(on ? FlashMode.torch : FlashMode.off);
      _torchOn = on;
      notifyListeners();
    } catch (e) {
      debugPrint('Torch failed: $e');
      _torchSupported = false;
      _torchOn = false;
      notifyListeners();
    }
  }

  Future<void> setZoom(double value) async {
    if (_mockMode) {
      if (!zoomSupported) return;
      _zoom = value.clamp(_minZoom, _maxZoom);
      notifyListeners();
      return;
    }
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized || !zoomSupported) return;
    final clamped = value.clamp(_minZoom, _maxZoom);
    try {
      await cam.setZoomLevel(clamped);
      _zoom = clamped;
      notifyListeners();
    } catch (e) {
      debugPrint('Zoom failed: $e');
    }
  }

  Future<XFile?> takePicture() async {
    if (_mockMode) {
      return ReceiptCameraMockPreview.captureStill(
        torchOn: _torchOn,
        zoom: _zoom,
      );
    }
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized || cam.value.isTakingPicture) {
      return null;
    }
    try {
      // Torch can interfere with still capture on some devices; leave as-is
      // so framing stays lit under dark conditions.
      return await cam.takePicture();
    } catch (e, stack) {
      debugPrint('takePicture failed: $e');
      debugPrintStack(stackTrace: stack);
      return null;
    }
  }

  Future<void> pause() async {
    if (_mockMode) {
      if (_torchOn) await setTorch(false);
      _mockPaused = true;
      notifyListeners();
      return;
    }
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    if (_torchOn) {
      await setTorch(false);
    }
    try {
      await cam.pausePreview();
    } catch (e) {
      debugPrint('pausePreview failed: $e');
    }
  }

  /// Re-check permission and resume preview after app foregrounding.
  Future<void> resume(BuildContext context) async {
    if (_disposed) return;
    if (_mockMode) {
      _mockPaused = false;
      notifyListeners();
      return;
    }
    final stillGranted = await PermissionService.isCameraPermissionGranted();
    if (_disposed || !context.mounted) return;
    if (!stillGranted) {
      final status = await Permission.camera.status;
      if (_disposed) return;
      if (status.isPermanentlyDenied || status.isDenied) {
        await _camera?.dispose();
        _camera = null;
        _status = ReceiptCameraStatus.permissionDenied;
        notifyListeners();
        return;
      }
    }

    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) {
      if (!context.mounted) return;
      await initialize(context);
      return;
    }
    try {
      await cam.resumePreview();
    } catch (e) {
      debugPrint('resumePreview failed: $e');
      if (!context.mounted || _disposed) return;
      await initialize(context);
    }
  }

  Future<void> openSettings() => openAppSettings();

  @override
  void dispose() {
    _disposed = true;
    final cam = _camera;
    _camera = null;
    cam?.dispose();
    super.dispose();
  }
}
