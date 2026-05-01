import 'dart:math' as math;

import '../domain/scanner_pattern.dart';

/// Result of parsing a notification body for transaction data.
class ParseResult {
  final int? amountCents;
  final String? currencyCode;
  final String? cardLastFour;
  final String? merchantName;
  final DateTime? transactionDate;
  final double confidence;
  final String? matchedPatternId;

  const ParseResult({
    this.amountCents,
    this.currencyCode,
    this.cardLastFour,
    this.merchantName,
    this.transactionDate,
    this.confidence = 0.0,
    this.matchedPatternId,
  });
}

// ignore: avoid_classes_with_only_static_members
/// Extracts transaction fields from notification text using regex patterns.
class TransactionParser {
  TransactionParser._();

  static const _currencySymbols = <String, String>{
    r'$': 'USD',
    '\u20AC': 'EUR', // €
    '\u00A3': 'GBP', // £
    '\u00A5': 'JPY', // ¥
    '\u20B9': 'INR', // ₹
    '\u20A9': 'KRW', // ₩
    '\u20BA': 'TRY', // ₺
    '\u20BD': 'RUB', // ₽
    '\u20B4': 'UAH', // ₴
    '\u20A6': 'NGN', // ₦
    '\u20A8': 'PKR', // ₨
    '\u20B1': 'PHP', // ₱
    '\u0631.\u0633': 'SAR', // ر.س
    '\u0631.\u0639': 'OMR', // ر.ع
    '\u062F.\u0625': 'AED', // د.إ
    '\u062F.\u0643': 'KWD', // د.ك
    '\u062F.\u0628': 'BHD', // د.ب
    '\u0631.\u0642': 'QAR', // ر.ق
    '\u062C.\u0645': 'EGP', // ج.م
    'R': 'ZAR',
    'RM': 'MYR',
    'Rp': 'IDR',
    'kr': 'SEK',
    'CHF': 'CHF',
  };

  static final _isoCodes = RegExp(
    r'\b(USD|EUR|GBP|JPY|INR|SAR|AED|KWD|BHD|OMR|QAR|EGP|TRY|CHF|CAD|AUD|NZD|SGD|HKD|MYR|IDR|PHP|THB|KRW|ZAR|BRL|MXN|PLN|CZK|HUF|SEK|NOK|DKK|NGN|KES|MAD|TND|IQD|LBP|YER|JOD|PKR|BDT|RUB|UAH)\b',
  );

  static final _amountPatterns = <RegExp>[
    RegExp(r'(\d{1,3}(?:,\d{3})*\.\d{1,2})'),
    RegExp(r'(\d{1,3}(?:\.\d{3})*,\d{1,2})'),
    RegExp(r'(\d+\.\d{1,2})'),
    RegExp(r'(\d+,\d{1,2})'),
    RegExp(r'(\d{2,})'),
  ];

  static final _cardPatterns = <RegExp>[
    RegExp(r'(?:card|ending)\s*(?:in\s+|ending\s+|\*+)?\s*(\d{4})', caseSensitive: false),
    RegExp(r'\*{1,}(\d{4})'),
    RegExp(r'x{1,4}(\d{4})', caseSensitive: false),
    RegExp(r'(?:ending|ends|last)\s+(\d{4})', caseSensitive: false),
  ];

  static final _merchantPatterns = <RegExp>[
    RegExp(r'(?:at|from|to)\s+([A-Za-z][A-Za-z\s&'
        r"'\-.]{1,40}?)(?:\s+on\s|\s*[,.]|\s*$)",
        caseSensitive: false),
    RegExp(r'(?:paid|purchase|payment|spent|debit)\s+(?:at|to|for)\s+([A-Za-z][A-Za-z\s&'
        r"'\-.]{1,40})",
        caseSensitive: false),
  ];

  static final _refundKeywords = RegExp(
    r'refund|credit|reversed|reversal|cashback',
    caseSensitive: false,
  );

  static final _skipKeywords = RegExp(
    r'\bOTP\b|verification|one.time.password|security code',
    caseSensitive: false,
  );

  /// Parse a notification body and extract transaction fields.
  static ParseResult parse(
    String body, {
    String fallbackCurrency = 'SAR',
    List<ScannerPattern> customPatterns = const [],
    DateTime? notificationDate,
  }) {
    if (_skipKeywords.hasMatch(body)) {
      return const ParseResult(confidence: 0.0);
    }

    for (final pattern in customPatterns.where((p) => p.enabled)) {
      final result = _tryPattern(body, pattern, notificationDate);
      if (result != null && result.amountCents != null) return result;
    }

    return _genericParse(body, fallbackCurrency, notificationDate);
  }

  static ParseResult? _tryPattern(
    String body,
    ScannerPattern pattern,
    DateTime? notificationDate,
  ) {
    try {
      final amountMatch = RegExp(pattern.amountRegex).firstMatch(body);
      if (amountMatch == null) return null;

      final amountCents = _parseAmountToCents(
        amountMatch.group(1) ?? amountMatch.group(0)!,
      );
      if (amountCents == null || amountCents <= 0) return null;

      String? currency;
      if (pattern.currencyRegex != null) {
        currency = RegExp(pattern.currencyRegex!).firstMatch(body)?.group(1);
      }

      String? card;
      if (pattern.cardRegex != null) {
        card = RegExp(pattern.cardRegex!).firstMatch(body)?.group(1);
      }

      String? merchant;
      if (pattern.merchantRegex != null) {
        merchant = RegExp(pattern.merchantRegex!)
            .firstMatch(body)
            ?.group(1)
            ?.trim();
      }

      DateTime? date;
      if (pattern.dateRegex != null) {
        date = _tryParseDate(
          RegExp(pattern.dateRegex!).firstMatch(body)?.group(0),
          pattern.dateFormat,
        );
      }

      double conf = 0.35;
      if (currency != null) conf += 0.20;
      if (merchant != null) conf += 0.15;
      if (card != null) conf += 0.15;
      if (date != null) conf += 0.10;
      conf += 0.05;

      return ParseResult(
        amountCents: amountCents,
        currencyCode: currency,
        cardLastFour: card,
        merchantName: merchant,
        transactionDate: date ?? notificationDate,
        confidence: math.min(conf, 1.0),
        matchedPatternId: pattern.id,
      );
    } catch (_) {
      return null;
    }
  }

  static ParseResult _genericParse(
    String body,
    String fallbackCurrency,
    DateTime? notificationDate,
  ) {
    final amountCents = _extractAmount(body);
    final currency = _extractCurrency(body) ?? fallbackCurrency;
    final card = _extractCard(body);
    final merchant = _extractMerchant(body);
    final isRefund = _refundKeywords.hasMatch(body);

    double conf = 0.0;
    if (amountCents != null && amountCents > 0) conf += 0.35;
    if (currency != fallbackCurrency) conf += 0.20;
    if (merchant != null) conf += 0.15;
    if (card != null) conf += 0.15;

    final effectiveAmount =
        (amountCents != null && isRefund) ? -amountCents : amountCents;

    return ParseResult(
      amountCents: effectiveAmount,
      currencyCode: currency,
      cardLastFour: card,
      merchantName: merchant,
      transactionDate: notificationDate,
      confidence: math.min(conf, 1.0),
    );
  }

  static int? _extractAmount(String body) {
    for (final pattern in _amountPatterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final cents = _parseAmountToCents(match.group(1) ?? match.group(0)!);
        if (cents != null && cents > 0) return cents;
      }
    }
    return null;
  }

  static String? _extractCurrency(String body) {
    final isoMatch = _isoCodes.firstMatch(body);
    if (isoMatch != null) return isoMatch.group(1);

    final sortedSymbols = _currencySymbols.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final symbol in sortedSymbols) {
      if (body.contains(symbol)) return _currencySymbols[symbol];
    }
    return null;
  }

  static String? _extractCard(String body) {
    for (final pattern in _cardPatterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final digits = match.group(1);
        if (digits != null && digits.length == 4) return digits;
      }
    }
    return null;
  }

  static String? _extractMerchant(String body) {
    for (final pattern in _merchantPatterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        final raw = match.group(1)?.trim();
        if (raw != null && raw.length >= 2 && raw.length <= 50) return raw;
      }
    }
    return null;
  }

  static const _arabicDigits = <String, String>{
    '\u0660': '0', '\u0661': '1', '\u0662': '2', '\u0663': '3', '\u0664': '4',
    '\u0665': '5', '\u0666': '6', '\u0667': '7', '\u0668': '8', '\u0669': '9',
    '\u066B': '.', '\u066C': ',',
  };

  static int? _parseAmountToCents(String raw) {
    var s = raw;
    for (final entry in _arabicDigits.entries) {
      s = s.replaceAll(entry.key, entry.value);
    }
    s = s.replaceAll(RegExp(r'[^\d.,]'), '');
    if (s.isEmpty) return null;

    final lastComma = s.lastIndexOf(',');
    final lastDot = s.lastIndexOf('.');

    double? value;
    if (lastComma > lastDot) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
      value = double.tryParse(s);
    } else if (lastDot > lastComma) {
      s = s.replaceAll(',', '');
      value = double.tryParse(s);
    } else {
      s = s.replaceAll(',', '');
      value = double.tryParse(s);
    }

    if (value == null || value <= 0) return null;
    return (value * 100).round();
  }

  static DateTime? _tryParseDate(String? raw, String? format) {
    if (raw == null || raw.isEmpty) return null;
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;

    final parts = raw.split(RegExp(r'[/\-.]'));
    if (parts.length >= 2) {
      final now = DateTime.now();
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = parts.length > 2 ? int.tryParse(parts[2]) : null;
      if (a != null && b != null) {
        final year = c ?? now.year;
        if (a > 12 && b <= 12) return DateTime(year, b, a);
        if (b > 12 && a <= 12) return DateTime(year, a, b);
        return DateTime(year, a, b);
      }
    }
    return null;
  }
}
