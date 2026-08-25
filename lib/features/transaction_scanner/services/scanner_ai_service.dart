import 'dart:convert';

import 'package:flutter_logging_service/flutter_logging_service.dart';

import '../../../core/receipt/receipt_llm_service.dart';
import '../../../core/receipt/receipt_nano_service.dart';
import '../domain/field_span.dart';
import 'transaction_parser.dart';

const String scannerExtractionPrompt = '''
Extract a payment notification into JSON.
Return ONLY a JSON object with keys:
- merchant: string or null (seller / store)
- place: string or null (city, branch, mall)
- amount: number (positive, major units)
- currency: string ISO code or null
- date: string ISO datetime or date or null
- category: one of food, groceries, transport, shopping, entertainment, bills, health, personal, coffee, travel, subscriptions, education, gifts, or null
- income: boolean (true if refund/credit)
Do not include markdown code fences or any text outside the JSON.
''';

class ScannerAiFields {
  final String? merchant;
  final String? place;
  final int? amountCents;
  final String? currency;
  final DateTime? date;
  final String? category;
  final bool income;

  const ScannerAiFields({
    this.merchant,
    this.place,
    this.amountCents,
    this.currency,
    this.date,
    this.category,
    this.income = false,
  });
}

/// Optional Nano / cloud assist for notification fields. Never throws.
Future<ScannerAiFields?> classifyNotification({
  required String body,
  required String mode,
  String? provider,
  String? apiKey,
}) async {
  if (mode == 'off' || body.trim().isEmpty) return null;
  try {
    if (mode == 'nano') {
      final status = await checkNanoStatus();
      if (status != NanoFeatureStatus.available) return null;
      final raw = await extractReceiptJsonWithNano(
        ocrText: '$scannerExtractionPrompt\n\nNotification:\n$body',
      );
      return _parseAiJson(raw);
    }
    if (mode == 'cloud') {
      final p = provider?.trim() ?? '';
      final key = apiKey?.trim() ?? '';
      if (key.isEmpty || (p != 'gemini' && p != 'openai')) return null;
      final raw = await extractReceiptTextOnly(
        '$scannerExtractionPrompt\n\nNotification:\n$body',
        p,
        key,
      );
      return _parseAiJson(raw);
    }
  } catch (e, st) {
    Log.debug('Scanner AI classify failed: $e');
    Log.debug('$st');
  }
  return null;
}

ScannerAiFields? _parseAiJson(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  var text = raw.trim();
  if (text.startsWith('```')) {
    text = text.replaceAll(RegExp(r'^```(?:json)?'), '').replaceAll('```', '');
    text = text.trim();
  }
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    final map = jsonDecode(text.substring(start, end + 1));
    if (map is! Map) return null;
    final amount = map['amount'];
    int? cents;
    if (amount is num) {
      cents = (amount * 100).round().abs();
    } else if (amount is String) {
      final parsed = double.tryParse(amount.replaceAll(',', ''));
      if (parsed != null) cents = (parsed * 100).round().abs();
    }
    DateTime? date;
    final dateRaw = map['date']?.toString();
    if (dateRaw != null && dateRaw.isNotEmpty) {
      date = DateTime.tryParse(dateRaw);
    }
    final income = map['income'] == true;
    return ScannerAiFields(
      merchant: _str(map['merchant']),
      place: _str(map['place']),
      amountCents: cents == null ? null : (income ? -cents : cents),
      currency: _str(map['currency'])?.toUpperCase(),
      date: date,
      category: _str(map['category']),
      income: income,
    );
  } catch (_) {
    return null;
  }
}

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty || s == 'null' ? null : s;
}

ParseResult mergeAiIntoParse(ParseResult base, ScannerAiFields ai) {
  final amount = base.amountCents ?? ai.amountCents;
  if (amount == null || amount == 0) return base;
  return ParseResult(
    amountCents: amount,
    currencyCode: base.currencyCode ?? ai.currency,
    cardLastFour: base.cardLastFour,
    merchantName: base.merchantName ?? ai.merchant,
    placeName: base.placeName ?? ai.place,
    transactionDate: base.transactionDate ?? ai.date,
    confidence: (base.confidence + 0.1).clamp(0.0, 1.0),
    matchedPatternId: base.matchedPatternId,
    fieldSpans: base.fieldSpans,
    skipReason: ParseSkipReason.none,
    suggestedCategory: ai.category ?? base.suggestedCategory,
  );
}

/// Used when teaching from AI-only fields (no spans).
List<FieldSpan> spansFromValues(String body, ParseResult result) {
  final spans = [...result.fieldSpans];
  void add(FieldRole role, String? value) {
    if (value == null || value.isEmpty) return;
    if (spans.any((s) => s.role == role)) return;
    final i = body.toLowerCase().indexOf(value.toLowerCase());
    if (i < 0) return;
    spans.add(FieldSpan(role: role, start: i, end: i + value.length));
  }

  if (result.amountCents != null) {
    add(FieldRole.amount, (result.amountCents!.abs() / 100).toStringAsFixed(2));
  }
  add(FieldRole.currency, result.currencyCode);
  add(FieldRole.merchant, result.merchantName);
  add(FieldRole.place, result.placeName);
  add(FieldRole.card, result.cardLastFour);
  return spans;
}
