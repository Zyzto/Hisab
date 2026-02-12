import 'dart:convert';
import 'dart:typed_data';
import 'package:langchain_core/chat_models.dart';
import 'package:langchain_core/prompts.dart';
import 'package:langchain_google/langchain_google.dart';
import 'package:langchain_openai/langchain_openai.dart';

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
    final chatModel = ChatGoogleGenerativeAI(
      apiKey: apiKey,
      defaultOptions: const ChatGoogleGenerativeAIOptions(
        model: 'gemini-2.0-flash',
        temperature: 0,
      ),
    );
    final result = await chatModel.invoke(prompt);
    return result.outputAsString.trim();
  }

  if (provider == 'openai') {
    final chatModel = ChatOpenAI(
      apiKey: apiKey,
      defaultOptions: const ChatOpenAIOptions(
        model: 'gpt-4o-mini',
        temperature: 0,
      ),
    );
    final result = await chatModel.invoke(prompt);
    return result.outputAsString.trim();
  }

  throw ArgumentError('Unsupported receipt AI provider: $provider');
}
