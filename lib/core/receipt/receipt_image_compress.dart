import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Max dimension for receipt photos (stream-friendly, ~200KB target).
const int kReceiptImageMaxDimension = 1920;

/// JPEG quality for receipt photos (balance size vs clarity).
const int kReceiptImageQuality = 85;

/// Compresses image bytes to JPEG for upload (client-side, no Supabase Transformation).
/// Resizes so no side exceeds [kReceiptImageMaxDimension], quality [kReceiptImageQuality].
/// Returns null on failure (e.g. unsupported format on web).
Future<Uint8List?> compressReceiptImage(Uint8List imageBytes) async {
  try {
    final result = await FlutterImageCompress.compressWithList(
      imageBytes,
      minWidth: kReceiptImageMaxDimension,
      minHeight: kReceiptImageMaxDimension,
      quality: kReceiptImageQuality,
      format: CompressFormat.jpeg,
    );
    return result;
  } catch (_) {
    return null;
  }
}
