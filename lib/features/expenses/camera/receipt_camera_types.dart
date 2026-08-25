import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safaeh/safaeh.dart';

/// Result of [showReceiptCamera].
class ReceiptCameraResult {
  const ReceiptCameraResult({
    required this.images,
    required this.scanAfter,
    this.openGallery = false,
  });

  final List<XFile> images;
  final bool scanAfter;

  /// When true, the form should open the gallery picker instead.
  final bool openGallery;
}

/// Compact sheet fraction of screen height (within 60–70% band).
const double kReceiptCameraCompactHeightFraction =
    kSafaehCameraCompactHeightFraction;

/// Orientations restored after the receipt camera releases its portrait lock.
const List<DeviceOrientation> kReceiptCameraRestoredOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];
