import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'receipt_providers.g.dart';

/// Reusable TextRecognizer for receipt OCR. Cached per provider lifetime.
/// Returns null on web (ML Kit not supported). Automatically disposed when provider is disposed.
@riverpod
TextRecognizer? textRecognizer(Ref ref) {
  if (kIsWeb) return null;
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  ref.onDispose(() => recognizer.close());
  return recognizer;
}
