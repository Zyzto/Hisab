import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'receipt_llm_service.dart';
import 'receipt_providers.dart';
import 'receipt_storage.dart';
import 'receipt_temp_file.dart';
import '../../features/settings/providers/settings_framework_providers.dart';

/// Result of processing a receipt image. Either parsed (vendor, date, total) or fallback (ocrText, receiptImagePath).
sealed class ReceiptScanResult {}

class ReceiptScanParsed extends ReceiptScanResult {
  final String vendor;
  final DateTime date;
  final double total;

  ReceiptScanParsed({
    required this.vendor,
    required this.date,
    required this.total,
  });
}

class ReceiptScanFallback extends ReceiptScanResult {
  final String ocrText;
  final String? receiptImagePath;

  ReceiptScanFallback({required this.ocrText, this.receiptImagePath});
}

/// Parse LLM JSON response (vendor, date, total). Strips markdown code fences. Returns null on failure.
({String vendor, DateTime date, double total})? parseReceiptJson(
  String raw,
  DateTime fallbackDate,
) {
  String s = raw.trim();
  final codeBlock = RegExp(r'^```(?:json)?\s*\n?([\s\S]*?)\n?```\s*$');
  final match = codeBlock.firstMatch(s);
  if (match != null) s = match.group(1)?.trim() ?? s;
  try {
    final map = jsonDecode(s) as Map<String, dynamic>?;
    if (map == null) return null;
    final vendor = (map['vendor'] as String?)?.trim() ?? '';
    final dateStr = (map['date'] as String?)?.trim();
    DateTime date = fallbackDate;
    if (dateStr != null && dateStr.isNotEmpty) {
      final parsed = DateTime.tryParse(dateStr);
      if (parsed != null) date = parsed;
    }
    final totalVal = map['total'];
    double total = 0;
    if (totalVal is num) {
      total = totalVal.toDouble();
    } else if (totalVal is String) {
      total = double.tryParse(totalVal.trim()) ?? 0;
    }
    return (vendor: vendor, date: date, total: total);
  } catch (_) {
    return null;
  }
}

/// Short error message for user-facing display.
String shortReceiptErrorMessage(Object? e) {
  if (e == null) return 'Unknown error';
  final s = e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), '').trim();
  final firstLine = s.split(RegExp(r'[\n\r]')).first.trim();
  return firstLine.length > 120
      ? '${firstLine.substring(0, 117)}...'
      : firstLine;
}

/// Process a receipt image file: OCR, LLM extraction. Returns null if web or OCR returns empty.
/// Caller provides the XFile (from image picker). Caller handles UI (SnackBar, etc).
Future<ReceiptScanResult?> processReceiptFile(
  XFile file,
  WidgetRef ref,
  DateTime fallbackDate,
) async {
  if (kIsWeb) return null;

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
          vendor: parsed.vendor.isNotEmpty ? parsed.vendor : 'Receipt',
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

/// Process receipt from in-memory bytes (e.g. a photo already in the form). Mobile only; returns null on web.
Future<ReceiptScanResult?> processReceiptBytes(
  Uint8List bytes,
  WidgetRef ref,
  DateTime fallbackDate,
) async {
  if (kIsWeb) return null;
  final path = await writeReceiptBytesToTempFile(bytes);
  if (path == null) return null;
  return processReceiptFile(XFile(path), ref, fallbackDate);
}
