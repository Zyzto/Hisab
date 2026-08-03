import 'dart:typed_data';

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

bool _looksLikeJpeg(Uint8List bytes) {
  return bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF;
}
