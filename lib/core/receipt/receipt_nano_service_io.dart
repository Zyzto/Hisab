import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:google_mlkit_genai_prompt/google_mlkit_genai_prompt.dart';

import 'receipt_llm_service.dart';
import 'receipt_nano_types.dart';

export 'receipt_nano_types.dart';

Prompt? _prompt;

Prompt _ensurePrompt() => _prompt ??= Prompt();

bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

/// Map ML Kit status index → [NanoFeatureStatus].
///
/// `FeatureStatus` is not exported from `google_mlkit_genai_prompt` (only
/// [Prompt] is). Both enums share the same order:
/// unavailable, downloadable, downloading, available.
NanoFeatureStatus _mapStatusIndex(int index) {
  if (index < 0 || index >= NanoFeatureStatus.values.length) {
    return NanoFeatureStatus.unavailable;
  }
  return NanoFeatureStatus.values[index];
}

/// Check Gemini Nano / AI Core availability (Android only).
Future<NanoFeatureStatus> checkNanoStatus() async {
  if (!_isAndroid) return NanoFeatureStatus.unavailable;
  try {
    final status = await _ensurePrompt().checkFeatureStatus();
    return _mapStatusIndex(status.index);
  } catch (e, st) {
    Log.debug('Nano checkFeatureStatus failed: $e');
    Log.debug('$st');
    return NanoFeatureStatus.unavailable;
  }
}

/// Download Nano feature when downloadable.
Future<void> downloadNanoFeature({void Function()? onCompleted}) async {
  if (!_isAndroid) {
    onCompleted?.call();
    return;
  }
  try {
    await _ensurePrompt().downloadFeature(onDownloadCompleted: onCompleted);
    onCompleted?.call();
  } catch (e, st) {
    Log.error('Nano downloadFeature failed', error: e, stackTrace: st);
    rethrow;
  }
}

/// Extract receipt JSON via Nano. Prefers OCR text; else multimodal file path.
Future<String?> extractReceiptJsonWithNano({
  String? ocrText,
  String? imagePath,
}) async {
  if (!_isAndroid) return null;
  final status = await checkNanoStatus();
  if (status != NanoFeatureStatus.available) return null;

  final prompt = _ensurePrompt();
  final text = (ocrText != null && ocrText.trim().isNotEmpty)
      ? '$receiptExtractionPrompt\n\nOCR text:\n${ocrText.trim()}'
      : receiptExtractionPrompt;

  try {
    if (ocrText != null && ocrText.trim().isNotEmpty) {
      Log.debug('Receipt Nano: OCR-text inference');
      return (await prompt.runInference(text)).trim();
    }
    if (imagePath != null && imagePath.isNotEmpty) {
      Log.debug('Receipt Nano: multimodal inference');
      return (await prompt.runInference(
        text,
        imageData: {'type': 'file', 'path': imagePath},
      )).trim();
    }
    return null;
  } catch (e, st) {
    Log.debug('Receipt Nano inference failed: $e');
    Log.debug('$st');
    return null;
  }
}
