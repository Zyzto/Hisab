import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:langchain_core/chat_models.dart';
import 'package:langchain_core/prompts.dart';
import 'package:langchain_google/langchain_google.dart';
import 'package:langchain_openai/langchain_openai.dart';

/// Cache key for LLM clients: (provider, apiKey) -> model. Reused across calls.
final _llmClientCache = <String, dynamic>{};

String _cacheKey(String provider, String apiKey) => '$provider:$apiKey';

/// Extraction prompt sent to the LLM for receipt parsing.
const String _receiptExtractionPrompt = '''
Extract the Vendor, Date, and Total from this receipt image.
Return ONLY a JSON object with keys: vendor, date, total.
- vendor: string (store or business name)
- date: string in ISO format (YYYY-MM-DD)
- total: number (total amount, no currency symbol)
Do not include markdown code fences or any text outside the JSON.
''';

/// Calls the configured LLM (Gemini or OpenAI) with the receipt image and
/// returns the raw response string (expected to be JSON).
///
/// [provider] must be `gemini` or `openai`.
/// [apiKey] must be non-empty for the chosen provider.
/// Throws on network/API errors or invalid key so the caller can fallback.
Future<String> extractReceiptFromImage(
  Uint8List imageBytes,
  String provider,
  String apiKey,
) async {
  if (apiKey.trim().isEmpty) {
    throw ArgumentError('API key is required for provider: $provider');
  }

  final base64Image = base64Encode(imageBytes);
  final content = ChatMessageContent.multiModal([
    ChatMessageContent.text(_receiptExtractionPrompt),
    ChatMessageContent.image(data: base64Image, mimeType: 'image/jpeg'),
  ]);
  final message = ChatMessage.human(content);
  final prompt = PromptValue.chat([message]);

  if (provider == 'gemini') {
    final key = _cacheKey(provider, apiKey);
    var chatModel = _llmClientCache[key] as ChatGoogleGenerativeAI?;
    chatModel ??= ChatGoogleGenerativeAI(
      apiKey: apiKey,
      defaultOptions: const ChatGoogleGenerativeAIOptions(
        model: 'gemini-2.0-flash',
        temperature: 0,
      ),
    );
    _llmClientCache[key] = chatModel;
    Log.debug('Receipt LLM: invoking Gemini gemini-2.0-flash');
    try {
      final result = await chatModel.invoke(prompt);
      return result.outputAsString.trim();
    } catch (e, st) {
      Log.error('Receipt LLM Gemini invoke failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  if (provider == 'openai') {
    final key = _cacheKey(provider, apiKey);
    var chatModel = _llmClientCache[key] as ChatOpenAI?;
    chatModel ??= ChatOpenAI(
      apiKey: apiKey,
      defaultOptions: const ChatOpenAIOptions(
        model: 'gpt-4o-mini',
        temperature: 0,
      ),
    );
    _llmClientCache[key] = chatModel;
    Log.debug('Receipt LLM: invoking OpenAI gpt-4o-mini');
    try {
      final result = await chatModel.invoke(prompt);
      return result.outputAsString.trim();
    } catch (e, st) {
      Log.error('Receipt LLM OpenAI invoke failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  throw ArgumentError('Unsupported receipt AI provider: $provider');
}
