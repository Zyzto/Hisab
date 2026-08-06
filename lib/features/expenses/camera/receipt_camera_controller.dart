import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/services/permission_service.dart';
import 'camera_lenses.dart';
import 'receipt_camera_mock_preview.dart';

/// High-level camera readiness for the receipt viewer.
enum ReceiptCameraStatus { loading, permissionDenied, noCamera, ready, error }

/// Owns a [CameraController] for receipt capture (torch, lens flip, lifecycle).
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
  List<CameraDescription> _cameras = const [];
  CameraLensDirection _lensDirection = CameraLensDirection.back;
  ReceiptCameraStatus _status = ReceiptCameraStatus.loading;
  String? _errorMessage;
  bool _torchOn = false;
  bool _torchSupported = false;
  double _minZoom = 1;
  double _maxZoom = 1;
  double _zoom = 1;
  DeviceOrientation _deviceOrientation = DeviceOrientation.portraitUp;
  bool _disposed = false;
  bool _testMode = false;
  final bool _mockMode;
  bool _mockPaused = false;
  bool _switching = false;

  /// Widest front camera (by Camera2 HFOV); used with no wide/0.9 chip.
  CameraDescription? _widestFrontDesc;

  ReceiptCameraStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get torchOn => _torchOn;
  bool get torchSupported => _torchSupported;

  /// Rear zoom only — front uses the widest lens with no zoom UI.
  bool get zoomSupported =>
      _lensDirection == CameraLensDirection.back && _maxZoom > _minZoom + 0.01;
  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;
  double get zoom => _zoom;
  DeviceOrientation get deviceOrientation => _deviceOrientation;

  /// Discrete zoom presets for the active camera.
  ///
  /// Range from [CameraController.getMinZoomLevel] / [getMaxZoomLevel]
  /// (Android CameraX `ZoomState`, iOS `maxAvailableVideoZoomFactor`).
  /// Front: no stops (widest lens only).
  List<double> get lensStops {
    if (_lensDirection == CameraLensDirection.front) return const [];

    final stops = <double>[];
    void add(double v) {
      if (stops.every((s) => (s - v).abs() > 0.08)) stops.add(v);
    }

    final min = _minZoom;
    final max = _maxZoom;
    if (max <= min + 0.01) return [min];

    // Rear: ultrawide chip available, but launch defaults to 1×.
    if (min < 0.95) add(min);
    for (final candidate in const [1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 30.0]) {
      if (candidate >= min - 0.05 && candidate <= max + 0.05) add(candidate);
    }
    if (stops.isNotEmpty && max >= 40 && (max - stops.last).abs() > 0.5) {
      add(max.roundToDouble());
    }
    return stops;
  }

  /// Index of the lens chip that “owns” the current continuous [zoom].
  int get activeLensStopIndex {
    final stops = lensStops;
    if (stops.isEmpty) return 0;
    var idx = 0;
    for (var i = 0; i < stops.length; i++) {
      if (_zoom + 0.05 >= stops[i]) idx = i;
    }
    return idx;
  }

  CameraController? get camera => _camera;
  bool get isMock => _mockMode;
  bool get mockPaused => _mockPaused;
  CameraLensDirection get lensDirection => _lensDirection;
  bool get canSwitchLens {
    if (_mockMode) return true;
    if (_cameras.length < 2) return false;
    final hasBack = _cameras.any(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    final hasFront = _cameras.any(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    return hasBack && hasFront;
  }

  bool get isReady =>
      _status == ReceiptCameraStatus.ready &&
      !_switching &&
      (_mockMode || (_camera != null && _camera!.value.isInitialized));

  /// Request permission, pick camera, initialize preview.
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
      _lensDirection = CameraLensDirection.back;
      _torchSupported = true;
      _torchOn = false;
      _minZoom = 0.6;
      _maxZoom = 30;
      _zoom = 1;
      _deviceOrientation = DeviceOrientation.portraitUp;
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
      _cameras = await availableCameras();
      if (_disposed) return;
      if (_cameras.isEmpty) {
        _status = ReceiptCameraStatus.noCamera;
        notifyListeners();
        return;
      }
      await _pickWidestFront();
      if (_disposed) return;

      final opened = await _openLens(_lensDirection, retryOnFailure: true);
      if (_disposed) return;
      if (!opened) {
        _status = ReceiptCameraStatus.error;
        _errorMessage ??= 'receipt_camera_no_camera';
        notifyListeners();
        return;
      }

      _status = ReceiptCameraStatus.ready;
      notifyListeners();
    } catch (e, stack) {
      Log.warning(
        'ReceiptCameraController init failed',
        error: e,
        stackTrace: stack,
      );
      _errorMessage = e.toString();
      _status = ReceiptCameraStatus.error;
      notifyListeners();
    }
  }

  CameraDescription? _descriptionFor(CameraLensDirection lens) {
    if (lens == CameraLensDirection.front) {
      return _widestFrontDesc ?? _firstCamera(CameraLensDirection.front);
    }
    return _firstCamera(lens) ?? (_cameras.isEmpty ? null : _cameras.first);
  }

  CameraDescription? _firstCamera(CameraLensDirection lens) {
    for (final c in _cameras) {
      if (c.lensDirection == lens) return c;
    }
    return null;
  }

  /// Prefer the front camera with the largest Camera2 horizontal FOV.
  Future<void> _pickWidestFront() async {
    _widestFrontDesc = null;
    final flutterFront = _cameras
        .where((c) => c.lensDirection == CameraLensDirection.front)
        .toList();
    if (flutterFront.isEmpty) return;

    final catalog = await fetchCameraLenses();
    if (_disposed) return;

    final byId = {for (final info in catalog) info.id: info};
    CameraDescription? best;
    var bestHfov = -1.0;
    for (final desc in flutterFront) {
      final hfov = byId[desc.name]?.hfovDeg ?? 0;
      if (hfov > bestHfov) {
        bestHfov = hfov;
        best = desc;
      }
    }
    _widestFrontDesc = best ?? flutterFront.first;
  }

  /// Opens [lens]. Retries once — Android often fails the first cold start.
  Future<bool> _openLens(
    CameraLensDirection lens, {
    required bool retryOnFailure,
  }) async {
    final description = _descriptionFor(lens);
    if (description == null) return false;

    Future<bool> attempt() async {
      await _detachCamera();

      // Medium keeps shutter snappy; high is enough fallback for OCR quality.
      final presets = <ResolutionPreset>[
        ResolutionPreset.medium,
        ResolutionPreset.high,
      ];

      Object? lastError;
      for (final preset in presets) {
        CameraController? controller;
        try {
          controller = CameraController(
            description,
            preset,
            enableAudio: false,
            imageFormatGroup: ImageFormatGroup.jpeg,
          );
          await controller.initialize();
          if (_disposed) {
            await controller.dispose();
            return false;
          }
          _attachCamera(controller);
          _lensDirection = description.lensDirection;
          await _configureAfterOpen();
          return true;
        } catch (e) {
          lastError = e;
          Log.warning('Camera open failed ($preset)', error: e);
          try {
            await controller?.dispose();
          } catch (disposeError, st) {
            Log.debug(
              'Camera dispose after open failure',
              error: disposeError,
              stackTrace: st,
            );
          }
          _camera = null;
        }
      }
      _errorMessage = lastError?.toString();
      return false;
    }

    if (await attempt()) return true;
    if (!retryOnFailure || _disposed) return false;
    // Brief pause lets the platform camera service finish releasing.
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (_disposed) return false;
    return attempt();
  }

  void _attachCamera(CameraController controller) {
    _camera = controller;
    controller.addListener(_onCameraValueChanged);
    _deviceOrientation = controller.value.deviceOrientation;
  }

  Future<void> _detachCamera() async {
    final previous = _camera;
    _camera = null;
    if (previous == null) return;
    previous.removeListener(_onCameraValueChanged);
    try {
      await previous.dispose();
    } catch (e, st) {
      Log.debug('Previous camera dispose failed', error: e, stackTrace: st);
    }
  }

  void _onCameraValueChanged() {
    if (_disposed) return;
    final cam = _camera;
    if (cam == null) return;
    final next = cam.value.deviceOrientation;
    if (next != _deviceOrientation) {
      _deviceOrientation = next;
      unawaited(_lockCaptureTo(_deviceOrientation));
      notifyListeners();
    }
  }

  Future<void> _lockCaptureTo(DeviceOrientation orientation) async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    try {
      // Explicit lock so stills match the physical phone even with OS rotation lock.
      await cam.lockCaptureOrientation(orientation);
    } catch (e, st) {
      Log.warning('lockCaptureOrientation failed', error: e, stackTrace: st);
    }
  }

  Future<void> _configureAfterOpen() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;

    try {
      _minZoom = await cam.getMinZoomLevel();
      _maxZoom = await cam.getMaxZoomLevel();
    } catch (e, st) {
      Log.debug('Zoom range probe failed', error: e, stackTrace: st);
      _minZoom = 1;
      _maxZoom = 1;
    }
    // Front + rear both open at 1× (rear ultrawide stays available as a chip).
    _zoom = 1.0.clamp(_minZoom, _maxZoom);
    try {
      await cam.setZoomLevel(_zoom);
    } catch (e, st) {
      Log.debug('Initial setZoomLevel failed', error: e, stackTrace: st);
    }

    _deviceOrientation = cam.value.deviceOrientation;
    await _lockCaptureTo(_deviceOrientation);

    // Never probe torch with on→off (that is what made the LED fire on open in
    // release). Only touch flash mode if the session did not start as off.
    _torchOn = false;
    _torchSupported = _lensDirection == CameraLensDirection.back;
    try {
      if (cam.value.flashMode != FlashMode.off) {
        await cam.setFlashMode(FlashMode.off);
      }
    } catch (e, st) {
      // Leave torch control available; first user toggle will disable on failure.
      Log.debug('Torch support probe failed', error: e, stackTrace: st);
    }
  }

  /// Sync mock / UI orientation when the host reports a turn (no hardware).
  void setDeviceOrientation(DeviceOrientation orientation) {
    if (_deviceOrientation == orientation) return;
    _deviceOrientation = orientation;
    unawaited(_lockCaptureTo(orientation));
    notifyListeners();
  }

  /// Flip between rear and front cameras.
  Future<void> switchLens() async {
    if (_disposed || _switching || !canSwitchLens) return;

    if (_mockMode) {
      _lensDirection = _lensDirection == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      _torchSupported = _lensDirection == CameraLensDirection.back;
      _torchOn = false;
      if (_lensDirection == CameraLensDirection.front) {
        _minZoom = 1;
        _maxZoom = 2;
        _zoom = 1;
      } else {
        _minZoom = 0.6;
        _maxZoom = 30;
        _zoom = 1;
      }
      notifyListeners();
      return;
    }

    final next = _lensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    _switching = true;
    _torchOn = false;
    notifyListeners();

    try {
      final ok = await _openLens(next, retryOnFailure: true);
      if (_disposed) return;
      if (!ok) {
        // Fall back to the previous lens if flip failed.
        await _openLens(_lensDirection, retryOnFailure: true);
      }
    } finally {
      _switching = false;
      if (!_disposed) {
        _status = _camera != null
            ? ReceiptCameraStatus.ready
            : ReceiptCameraStatus.error;
        notifyListeners();
      }
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
    } catch (e, st) {
      Log.warning('Torch failed', error: e, stackTrace: st);
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
    } catch (e, st) {
      Log.warning('Zoom failed', error: e, stackTrace: st);
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
      // Re-assert just before capture — orientation events can race the shutter.
      await _lockCaptureTo(cam.value.deviceOrientation);
      if (_disposed || !cam.value.isInitialized || cam.value.isTakingPicture) {
        return null;
      }
      return await cam.takePicture();
    } catch (e, stack) {
      Log.warning('takePicture failed', error: e, stackTrace: stack);
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
    } catch (e, st) {
      Log.warning('pausePreview failed', error: e, stackTrace: st);
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
    } catch (e, st) {
      Log.warning('resumePreview failed', error: e, stackTrace: st);
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
    if (cam != null) {
      cam.removeListener(_onCameraValueChanged);
      cam.dispose();
    }
    super.dispose();
  }
}
