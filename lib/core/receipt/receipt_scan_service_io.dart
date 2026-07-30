import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/settings/providers/settings_framework_providers.dart';
import 'receipt_llm_service.dart';
import 'receipt_providers.dart';
import 'receipt_scan_types.dart';
import 'receipt_storage.dart';
import 'receipt_temp_file.dart';

export 'receipt_scan_types.dart';

/// Process a receipt image file: OCR + optional LLM extraction (native only).
Future<ReceiptScanResult?> processReceiptFile(
  XFile file,
  WidgetRef ref,
  DateTime fallbackDate,
) async {
  try {
    final ocrEnabled = ref.read(receiptOcrEnabledProvider);
    if (!ocrEnabled) {
      Log.debug('Receipt scan: OCR disabled, attach-only path');
      final storedPath = await copyReceiptToAppStorage(file.path);
      return ReceiptScanFallback(ocrText: '', receiptImagePath: storedPath);
    }

    final inputImage = InputImage.fromFilePath(file.path);
    final recognizer = ref.read(textRecognizerProvider);
    if (recognizer == null) return null;

    final recognized = await recognizer.processImage(inputImage);
    final ocrText = recognized.text.trim();
    if (ocrText.isEmpty) return null;

    final aiEnabled = ref.read(receiptAiEnabledProvider);
    final provider = ref.read(receiptAiProviderProvider);
    final geminiKey = ref.read(geminiApiKeyProvider).trim();
    final openaiKey = ref.read(openaiApiKeyProvider).trim();
    final configured = provider == 'gemini'
        ? geminiKey.isNotEmpty
        : provider == 'openai'
        ? openaiKey.isNotEmpty
        : false;

    if (!aiEnabled || provider == 'none' || !configured) {
      Log.debug('Receipt scan: AI disabled or not configured, OCR text only');
      final storedPath = await copyReceiptToAppStorage(file.path);
      return ReceiptScanFallback(
        ocrText: ocrText,
        receiptImagePath: storedPath,
      );
    }

    final imageBytes = await file.readAsBytes();
    try {
      final responseText = await extractReceiptFromImage(
        imageBytes,
        provider,
        provider == 'gemini' ? geminiKey : openaiKey,
      );
      final parsed = parseReceiptJson(responseText, fallbackDate);
      if (parsed != null) {
        final result = ReceiptScanParsed(
          vendor: parsed.vendor.isNotEmpty
              ? parsed.vendor
              : 'receipt_fallback_vendor'.tr(),
          date: parsed.date,
          total: parsed.total,
        );
        Log.info(
          'Receipt scan parsed: vendor="${result.vendor}" total=${result.total}',
        );
        return result;
      }
      Log.debug('Receipt scan: LLM parse failed, fallback to OCR+attach');
    } catch (e) {
      Log.debug('Receipt scan: LLM failed, fallback to OCR+attach: $e');
    }

    final storedPath = await copyReceiptToAppStorage(file.path);
    return ReceiptScanFallback(ocrText: ocrText, receiptImagePath: storedPath);
  } catch (e, st) {
    Log.error('Receipt scan failed', error: e, stackTrace: st);
    rethrow;
  }
}

/// Process receipt from in-memory bytes (native only).
Future<ReceiptScanResult?> processReceiptBytes(
  Uint8List bytes,
  WidgetRef ref,
  DateTime fallbackDate,
) async {
  final path = await writeReceiptBytesToTempFile(bytes);
  if (path == null) return null;
  return processReceiptFile(XFile(path), ref, fallbackDate);
}
