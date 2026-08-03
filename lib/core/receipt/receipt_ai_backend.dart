import 'dart:typed_data';

import 'receipt_llm_service.dart';

/// Abstraction for cloud / managed receipt AI backends.
abstract class ReceiptAiBackend {
  Future<String> extractRawJson(
    Uint8List imageBytes, {
    String? ocrText,
    String? imagePath,
  });
}

/// User-supplied Gemini API key (device-only).
class ByoGeminiReceiptAiBackend implements ReceiptAiBackend {
  final String apiKey;

  ByoGeminiReceiptAiBackend(this.apiKey);

  @override
  Future<String> extractRawJson(
    Uint8List imageBytes, {
    String? ocrText,
    String? imagePath,
  }) {
    return extractReceiptFromImage(imageBytes, 'gemini', apiKey);
  }
}

/// User-supplied OpenAI API key (device-only).
class ByoOpenaiReceiptAiBackend implements ReceiptAiBackend {
  final String apiKey;

  ByoOpenaiReceiptAiBackend(this.apiKey);

  @override
  Future<String> extractRawJson(
    Uint8List imageBytes, {
    String? ocrText,
    String? imagePath,
  }) {
    return extractReceiptFromImage(imageBytes, 'openai', apiKey);
  }
}

/// Reserved for a future Hisab-managed cloud provider.
class HisabReceiptAiBackend implements ReceiptAiBackend {
  @override
  Future<String> extractRawJson(
    Uint8List imageBytes, {
    String? ocrText,
    String? imagePath,
  }) {
    throw UnsupportedError('Hisab cloud receipt AI is not available yet');
  }
}

/// Resolve BYO / Hisab backend from settings provider id.
ReceiptAiBackend? receiptAiBackendForProvider(
  String provider,
  String geminiKey,
  String openaiKey,
) {
  switch (provider) {
    case 'gemini':
      if (geminiKey.trim().isEmpty) return null;
      return ByoGeminiReceiptAiBackend(geminiKey.trim());
    case 'openai':
      if (openaiKey.trim().isEmpty) return null;
      return ByoOpenaiReceiptAiBackend(openaiKey.trim());
    case 'hisab':
      return HisabReceiptAiBackend();
    default:
      return null;
  }
}
