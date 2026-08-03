import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';

import '../../domain/receipt_line_item.dart';
import '../utils/user_text.dart';
import 'receipt_scan_cancel.dart';

/// Result of processing a receipt image. Either parsed (vendor, date, total)
/// or fallback (ocrText, receiptImagePath).
sealed class ReceiptScanResult {}

class ReceiptScanParsed extends ReceiptScanResult {
  final String vendor;
  final DateTime date;
  final double total;
  final double? vat;
  final List<ReceiptLineItem>? lineItems;
  final String? description;

  ReceiptScanParsed({
    required this.vendor,
    required this.date,
    required this.total,
    this.vat,
    this.lineItems,
    this.description,
  });
}

class ReceiptScanFallback extends ReceiptScanResult {
  final String ocrText;
  final String? receiptImagePath;

  ReceiptScanFallback({required this.ocrText, this.receiptImagePath});
}

/// Parse LLM JSON response (vendor/store, date, total, optional vat/items).
({String vendor, DateTime date, double total, double? vat, List<ReceiptLineItem>? lineItems, String? description})?
    parseReceiptJson(
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
    final vendor = (map['vendor'] as String?)?.trim() ??
        (map['store'] as String?)?.trim() ??
        '';
    final dateStr = (map['date'] as String?)?.trim() ??
        (map['datetime'] as String?)?.trim();
    var date = fallbackDate;
    if (dateStr != null && dateStr.isNotEmpty) {
      final parsed = DateTime.tryParse(dateStr);
      if (parsed != null) date = parsed;
    }
    final totalVal = map['total'] ?? map['price'];
    var total = 0.0;
    if (totalVal is num) {
      total = totalVal.toDouble();
    } else if (totalVal is String) {
      total = double.tryParse(totalVal.trim()) ?? 0;
    }
    double? vat;
    final vatVal = map['vat'];
    if (vatVal is num) {
      vat = vatVal.toDouble();
    } else if (vatVal is String) {
      vat = double.tryParse(vatVal.trim());
    }
    List<ReceiptLineItem>? lineItems;
    final itemsRaw = map['items'];
    if (itemsRaw is List) {
      lineItems = itemsRaw.map((e) {
        if (e is Map<String, dynamic>) {
          final desc =
              (e['description'] as String?) ?? (e['name'] as String?) ?? '';
          final amt = e['amount'] ?? e['price'];
          var amount = 0.0;
          if (amt is num) {
            amount = amt.toDouble();
          } else if (amt is String) {
            amount = double.tryParse(amt) ?? 0;
          }
          return ReceiptLineItem(
            description: desc,
            amountCents: (amount * 100).round(),
          );
        }
        return const ReceiptLineItem(description: '', amountCents: 0);
      }).where((e) => e.description.isNotEmpty || e.amountCents > 0).toList();
      if (lineItems.isEmpty) lineItems = null;
    }
    final description = (map['description'] as String?)?.trim();
    return (
      vendor: vendor,
      date: date,
      total: total,
      vat: vat,
      lineItems: lineItems,
      description: description,
    );
  } catch (_) {
    return null;
  }
}

/// Short error message for user-facing display.
String shortReceiptErrorMessage(Object? e) {
  if (e == null) return 'unknown_error'.tr();
  if (e is ReceiptScanCancelledException) {
    return 'receipt_scan_cancelled'.tr();
  }
  if (e is TimeoutException) {
    return 'receipt_scan_timeout'.tr();
  }
  final s = e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), '').trim();
  final firstLine = s.split(RegExp(r'[\n\r]')).first.trim();
  return elideGraphemes(firstLine, maxGraphemes: 120, ellipsis: '...');
}
