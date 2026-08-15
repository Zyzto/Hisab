import 'dart:typed_data' show Uint8List;

import 'package:hisab_backend/hisab_backend.dart';

/// Upload failure is non-fatal; the issue body still includes fallback text.
Future<String?> uploadFeedbackScreenshot(Uint8List pngBytes) async {
  final files = cloudBackend?.files;
  if (files == null || pngBytes.isEmpty) return null;
  return files.uploadFeedbackScreenshot(pngBytes);
}
