import 'dart:math' as math;

import '../domain/field_span.dart';
import '../domain/scanner_pattern.dart';

/// Why a notification was not turned into a draft.
enum ParseSkipReason { none, otp, noAmount }

/// Result of parsing a notification body for transaction data.
class ParseResult {
  final int? amountCents;
  final String? currencyCode;
  final String? cardLastFour;
  final String? merchantName;
  final String? placeName;
  final DateTime? transactionDate;
  final double confidence;
  final String? matchedPatternId;
  final List<FieldSpan> fieldSpans;
  final ParseSkipReason skipReason;
  final String? suggestedCategory;

  const ParseResult({
    this.amountCents,
    this.currencyCode,
    this.cardLastFour,
    this.merchantName,
    this.placeName,
    this.transactionDate,
    this.confidence = 0.0,
    this.matchedPatternId,
    this.fieldSpans = const [],
    this.skipReason = ParseSkipReason.none,
    this.suggestedCategory,
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
    RegExp(
      r'(?:card|ending)\s*(?:in\s+|ending\s+|\*+)?\s*(\d{4})',
      caseSensitive: false,
    ),
    RegExp(r'\*{1,}(\d{4})'),
    RegExp(r'x{1,4}(\d{4})', caseSensitive: false),
    RegExp(r'(?:ending|ends|last)\s+(\d{4})', caseSensitive: false),
  ];

  static final _merchantPatterns = <RegExp>[
    RegExp(
      r'(?:at|from|to)\s+([A-Za-z][A-Za-z\s&'
      r"'\-.]{1,40}?)(?:\s+on\s|\s+in\s|\s*[,.]|\s*$)",
      caseSensitive: false,
    ),
    RegExp(
      r'(?:paid|purchase|payment|spent|debit)\s+(?:at|to|for)\s+([A-Za-z][A-Za-z\s&'
      r"'\-.]{1,40})",
      caseSensitive: false,
    ),
    RegExp(
      r'(?:\u0639\u0646\u062F|\u0644\u062F\u0649|\u0641\u064A)\s+([^\s\d]{2,40})',
    ),
  ];

  static final _placePatterns = <RegExp>[
    RegExp(
      r'(?:in|at)\s+([A-Z][A-Za-z][A-Za-z\s]{1,28}?)(?:\s+on\s|\s*[,.]|\s*$)',
    ),
    RegExp(r'(?:\u0641\u064A)\s+([^\s\d]{2,30})'),
  ];

  static final _refundKeywords = RegExp(
    r'refund|credit|reversed|reversal|cashback',
    caseSensitive: false,
  );

  static final _skipKeywords = RegExp(
    r'\bOTP\b|verification|one.time.password|security code',
    caseSensitive: false,
  );

  /// Public amount parser used by the annotator when a span includes symbols.
  static int? parseAmountToCents(String raw) => _parseAmountToCents(raw);

  /// Public currency parser for a highlighted snippet (`SAR`, `ر.س`, `$`).
  static String? extractCurrencyCode(String raw) => _extractCurrency(raw);

  /// Parse a notification body and extract transaction fields.
  static ParseResult parse(
    String body, {
    String fallbackCurrency = 'SAR',
    List<ScannerPattern> customPatterns = const [],
    DateTime? notificationDate,
    String? senderPackage,
  }) {
    if (_skipKeywords.hasMatch(body)) {
      return const ParseResult(
        confidence: 0.0,
        skipReason: ParseSkipReason.otp,
      );
    }

    for (final pattern in customPatterns.where((p) => p.enabled)) {
      if (!_senderMatches(pattern.senderMatch, senderPackage)) continue;
      final result = _tryPattern(body, pattern, notificationDate);
      if (result != null && result.amountCents != null) return result;
    }

    return _genericParse(body, fallbackCurrency, notificationDate);
  }

  static bool _senderMatches(String senderMatch, String? packageName) {
    if (senderMatch.isEmpty || senderMatch == '*') return true;
    if (packageName == null || packageName.isEmpty) return true;
    return packageName == senderMatch || packageName.contains(senderMatch);
  }

  static FieldSpan _spanForMatch(Match match, FieldRole role) {
    final full = match.group(0);
    final captured = match.groupCount >= 1 ? match.group(1) : null;
    if (full != null && captured != null && captured.isNotEmpty) {
      final offset = full.indexOf(captured);
      if (offset >= 0) {
        return FieldSpan(
          role: role,
          start: match.start + offset,
          end: match.start + offset + captured.length,
        );
      }
    }
    return FieldSpan(role: role, start: match.start, end: match.end);
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
      Match? currencyMatch;
      if (pattern.currencyRegex != null) {
        currencyMatch = RegExp(pattern.currencyRegex!).firstMatch(body);
        currency = currencyMatch?.group(1);
      }

      String? card;
      Match? cardMatch;
      if (pattern.cardRegex != null) {
        cardMatch = RegExp(pattern.cardRegex!).firstMatch(body);
        card = cardMatch?.group(1);
      }

      String? merchant;
      Match? merchantMatch;
      if (pattern.merchantRegex != null) {
        merchantMatch = RegExp(pattern.merchantRegex!).firstMatch(body);
        merchant = merchantMatch?.group(1)?.trim();
      }

      DateTime? date;
      Match? dateMatch;
      if (pattern.dateRegex != null) {
        dateMatch = RegExp(pattern.dateRegex!).firstMatch(body);
        date = _tryParseDate(dateMatch?.group(0), pattern.dateFormat);
      }

      final place = _extractPlace(body, merchant: merchant);

      double conf = 0.35;
      if (currency != null) conf += 0.20;
      if (merchant != null) conf += 0.15;
      if (card != null) conf += 0.15;
      if (date != null) conf += 0.10;
      if (place != null) conf += 0.05;
      conf += 0.05;

      final spans = <FieldSpan>[
        _spanForMatch(amountMatch, FieldRole.amount),
        if (currencyMatch != null)
          _spanForMatch(currencyMatch, FieldRole.currency),
        if (merchantMatch != null)
          _spanForMatch(merchantMatch, FieldRole.merchant),
        if (cardMatch != null) _spanForMatch(cardMatch, FieldRole.card),
        if (dateMatch != null) _spanForMatch(dateMatch, FieldRole.date),
        ..._placeSpans(body, place),
      ];

      return ParseResult(
        amountCents: amountCents,
        currencyCode: currency,
        cardLastFour: card,
        merchantName: merchant,
        placeName: place,
        transactionDate: date ?? notificationDate,
        confidence: math.min(conf, 1.0),
        matchedPatternId: pattern.id,
        fieldSpans: spans,
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
    final amountMatch = _firstAmountMatch(body);
    final amountCents = amountMatch == null
        ? null
        : _parseAmountToCents(amountMatch.group(1) ?? amountMatch.group(0)!);
    final currencyMatch = _isoCodes.firstMatch(body);
    var currency = currencyMatch?.group(1);
    if (currency == null) {
      currency = _extractCurrency(body) ?? fallbackCurrency;
    }
    final cardMatch = _firstCardMatch(body);
    final card = cardMatch?.group(1);
    final merchantMatch = _firstMerchantMatch(body);
    final merchant = merchantMatch?.group(1)?.trim();
    final place = _extractPlace(body, merchant: merchant);
    final isRefund = _refundKeywords.hasMatch(body);

    if (amountCents == null || amountCents <= 0) {
      return ParseResult(
        currencyCode: currency,
        merchantName: merchant,
        placeName: place,
        transactionDate: notificationDate,
        skipReason: ParseSkipReason.noAmount,
      );
    }

    double conf = 0.35;
    if (currency != fallbackCurrency) conf += 0.20;
    if (merchant != null) conf += 0.15;
    if (card != null) conf += 0.15;
    if (place != null) conf += 0.05;

    final effectiveAmount = isRefund ? -amountCents : amountCents;

    final spans = <FieldSpan>[
      if (amountMatch != null) _spanForMatch(amountMatch, FieldRole.amount),
      if (currencyMatch != null)
        _spanForMatch(currencyMatch, FieldRole.currency),
      if (merchantMatch != null)
        _spanForMatch(merchantMatch, FieldRole.merchant),
      if (cardMatch != null) _spanForMatch(cardMatch, FieldRole.card),
      ..._placeSpans(body, place),
    ];

    return ParseResult(
      amountCents: effectiveAmount,
      currencyCode: currency,
      cardLastFour: card,
      merchantName: merchant,
      placeName: place,
      transactionDate: notificationDate,
      confidence: math.min(conf, 1.0),
      fieldSpans: spans,
    );
  }

  static Match? _firstAmountMatch(String body) {
    for (final pattern in _amountPatterns) {
      final match = pattern.firstMatch(body);
      if (match == null) continue;
      final cents = _parseAmountToCents(match.group(1) ?? match.group(0)!);
      if (cents != null && cents > 0) return match;
    }
    return null;
  }

  static Match? _firstCardMatch(String body) {
    for (final pattern in _cardPatterns) {
      final match = pattern.firstMatch(body);
      final digits = match?.group(1);
      if (digits != null && digits.length == 4) return match;
    }
    return null;
  }

  static Match? _firstMerchantMatch(String body) {
    for (final pattern in _merchantPatterns) {
      final match = pattern.firstMatch(body);
      final raw = match?.group(1)?.trim();
      if (raw != null && raw.length >= 2 && raw.length <= 50) return match;
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

  static String? _extractPlace(String body, {String? merchant}) {
    for (final pattern in _placePatterns) {
      final match = pattern.firstMatch(body);
      final raw = match?.group(1)?.trim();
      if (raw == null || raw.length < 2) continue;
      if (merchant != null && raw.toLowerCase() == merchant.toLowerCase()) {
        continue;
      }
      return raw;
    }
    return null;
  }

  static List<FieldSpan> _placeSpans(String body, String? place) {
    if (place == null || place.isEmpty) return const [];
    final index = body.toLowerCase().indexOf(place.toLowerCase());
    if (index < 0) return const [];
    return [
      FieldSpan(role: FieldRole.place, start: index, end: index + place.length),
    ];
  }

  static const _arabicDigits = <String, String>{
    '\u0660': '0',
    '\u0661': '1',
    '\u0662': '2',
    '\u0663': '3',
    '\u0664': '4',
    '\u0665': '5',
    '\u0666': '6',
    '\u0667': '7',
    '\u0668': '8',
    '\u0669': '9',
    '\u066B': '.',
    '\u066C': ',',
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
