import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Max dimension for receipt photos stored / uploaded (stream-friendly).
const int kReceiptImageMaxDimension = 1280;

/// JPEG quality for stored / uploaded receipt photos.
const int kReceiptImageQuality = 72;

/// Max preferred upload bytes after compression.
const int _kReceiptPreferredMaxBytes = 350 * 1024;

/// Max dimension for on-device OCR. Tesseract collapses on 1280px/q72 phone
/// JPEGs; keep more pixels for edges (totals, VAT, store names).
const int kReceiptOcrMaxDimension = 2400;

/// JPEG quality for OCR temp files (still smaller than camera originals).
const int kReceiptOcrQuality = 90;

/// Compresses image bytes to JPEG for upload / gallery thumbnails.
/// Resizes so no side exceeds [kReceiptImageMaxDimension].
/// Returns null on failure (e.g. unsupported format on web).
Future<Uint8List?> compressReceiptImage(Uint8List imageBytes) async {
  try {
    var result = await FlutterImageCompress.compressWithList(
      imageBytes,
      minWidth: kReceiptImageMaxDimension,
      minHeight: kReceiptImageMaxDimension,
      quality: kReceiptImageQuality,
      format: CompressFormat.jpeg,
    );
    if (result.length > _kReceiptPreferredMaxBytes) {
      result = await FlutterImageCompress.compressWithList(
        result,
        minWidth: kReceiptImageMaxDimension,
        minHeight: kReceiptImageMaxDimension,
        quality: 62,
        format: CompressFormat.jpeg,
      );
    }
    return result;
  } catch (_) {
    return null;
  }
}

/// Light resize for OCR only — prefer fidelity over size.
///
/// Skips work when the input is already a modest JPEG under ~1.8MB.
Future<Uint8List?> compressReceiptImageForOcr(Uint8List imageBytes) async {
  try {
    // Camera HEIC/PNG dumps can be huge; always normalize to JPEG for Tess.
    if (imageBytes.length < 1800 * 1024 && _looksLikeJpeg(imageBytes)) {
      // Still re-encode so EXIF orientation is applied by the compressor.
    }
    final result = await FlutterImageCompress.compressWithList(
      imageBytes,
      minWidth: kReceiptOcrMaxDimension,
      minHeight: kReceiptOcrMaxDimension,
      quality: kReceiptOcrQuality,
      format: CompressFormat.jpeg,
      keepExif: false,
      autoCorrectionAngle: true,
    );
    return result.isEmpty ? null : result;
  } catch (_) {
    return null;
  }
}

/// Rotates image bytes by [degrees] (90 / 180 / 270) and re-encodes as JPEG.
///
/// Native uses [FlutterImageCompress] (honors [rotate]). Web's compressor
/// ignores rotate, so we fall back to a codec/canvas path there.
Future<Uint8List?> rotateReceiptImage(Uint8List imageBytes, int degrees) async {
  final normalized = ((degrees % 360) + 360) % 360;
  if (normalized == 0) return imageBytes;

  if (!kIsWeb) {
    try {
      final result = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: kReceiptImageMaxDimension,
        minHeight: kReceiptImageMaxDimension,
        quality: kReceiptImageQuality,
        rotate: normalized,
        format: CompressFormat.jpeg,
        autoCorrectionAngle: false,
        keepExif: false,
      );
      if (result.isNotEmpty) return result;
    } catch (_) {}
  }

  return _rotateWithCodec(imageBytes, normalized);
}

Future<Uint8List?> _rotateWithCodec(Uint8List bytes, int degrees) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final src = frame.image;
    final swap = degrees == 90 || degrees == 270;
    final outW = swap ? src.height : src.width;
    final outH = swap ? src.width : src.height;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.translate(outW / 2, outH / 2);
    canvas.rotate(degrees * math.pi / 180);
    canvas.translate(-src.width / 2, -src.height / 2);
    canvas.drawImage(src, ui.Offset.zero, ui.Paint());

    final picture = recorder.endRecording();
    final out = await picture.toImage(outW, outH);
    src.dispose();
    final byteData = await out.toByteData(format: ui.ImageByteFormat.png);
    out.dispose();
    picture.dispose();
    if (byteData == null) return null;

    final png = byteData.buffer.asUint8List();
    return await compressReceiptImage(png) ?? png;
  } catch (_) {
    return null;
  }
}

bool _looksLikeJpeg(Uint8List bytes) {
  return bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF;
}
