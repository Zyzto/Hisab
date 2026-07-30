import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';

import '../utils/user_text.dart';

/// Result of processing a receipt image. Either parsed (vendor, date, total)
/// or fallback (ocrText, receiptImagePath).
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

/// Parse LLM JSON response (vendor, date, total). Strips markdown code fences.
({String vendor, DateTime date, double total})? parseReceiptJson(
  String raw,
  DateTime fallbackDate,
) {
  var s = raw.trim();
  final codeBlock = RegExp(r'^```(?:json)?\s*\n?([\s\S]*?)\n?```\s*$');
  final match = codeBlock.firstMatch(s);
  if (match != null) s = match.group(1)?.trim() ?? s;
  try {
    final map = jsonDecode(s) as Map<String, dynamic>?;
    if (map == null) return null;
    final vendor = (map['vendor'] as String?)?.trim() ?? '';
    final dateStr = (map['date'] as String?)?.trim();
    var date = fallbackDate;
    if (dateStr != null && dateStr.isNotEmpty) {
      final parsed = DateTime.tryParse(dateStr);
      if (parsed != null) date = parsed;
    }
    final totalVal = map['total'];
    var total = 0.0;
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
  if (e == null) return 'unknown_error'.tr();
  final s = e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), '').trim();
  final firstLine = s.split(RegExp(r'[\n\r]')).first.trim();
  return elideGraphemes(firstLine, maxGraphemes: 120, ellipsis: '...');
}
