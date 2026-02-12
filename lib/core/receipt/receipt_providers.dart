import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Reusable TextRecognizer for receipt OCR. Cached per provider lifetime.
/// Returns null on web (ML Kit not supported). Automatically disposed when provider is disposed.
final textRecognizerProvider = Provider<TextRecognizer?>((ref) {
  if (kIsWeb) return null;
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  ref.onDispose(() => recognizer.close());
  return recognizer;
});
