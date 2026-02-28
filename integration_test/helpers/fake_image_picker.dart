import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Fake [ImagePickerPlatform] for integration tests.
///
/// Returns a programmatically generated 10x10 red PNG for every pick request,
/// bypassing the real camera / gallery system dialogs.
class FakeImagePickerPlatform extends ImagePickerPlatform
    with MockPlatformInterfaceMixin {
  int pickCount = 0;
  late final Uint8List _testPngBytes;

  /// Generate the test image bytes. Must be called once before use.
  Future<void> init() async {
    _testPngBytes = await _generateTestPng();
  }

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    pickCount++;
    return XFile.fromData(
      _testPngBytes,
      mimeType: 'image/png',
      path: 'fake_image_$pickCount.png',
    );
  }

  @override
  Future<XFile?> getImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
  }) async {
    pickCount++;
    return XFile.fromData(
      _testPngBytes,
      mimeType: 'image/png',
      path: 'fake_image_$pickCount.png',
    );
  }

  static Future<Uint8List> _generateTestPng() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 10, 10));
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 10, 10),
      Paint()..color = const Color(0xFFFF0000),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(10, 10);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}

/// Installs the fake image picker globally. Call once per test group.
Future<FakeImagePickerPlatform> installFakeImagePicker() async {
  final fake = FakeImagePickerPlatform();
  await fake.init();
  ImagePickerPlatform.instance = fake;
  return fake;
}
