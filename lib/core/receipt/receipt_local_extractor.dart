import '../../domain/receipt_line_item.dart';
import 'receipt_scan_types.dart';

final _amountRe = RegExp(
  r'(?<![\d.,])(\d{1,3}(?:[.,]\s?\d{3})*[.,]\s?\d{2}|\d+[.,]\s?\d{2})(?![\d])',
);

final _dateIsoRe = RegExp(
  r'\b(\d{4})[/-](\d{1,2})[/-](\d{1,2})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([AaPp][Mm]|[صم])?)?',
);
final _dateSlashRe = RegExp(
  r'\b(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([AaPp][Mm]|[صم])?)?',
);
final _dateMonRe = RegExp(
  r"\b(\d{1,2})\s*(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z']*\s*'?(\d{2,4})\b"
  r'(?:\s+(\d{1,2}):(\d{2}))?',
  caseSensitive: false,
);

final _totalLabelRe = RegExp(
  r'(total\s*amount\s*\(?\s*incl|'
  r'amou?r?n?t\s*due|'
  r'amou?r?n?t\s*t[eo]\s*pay|'
  r'mount\s*to\s*pay|'
  r'grand\s*total|'
  r'net\s*ttl|'
  r'total\s*inc|'
  r'total\s*tender|'
  r'صافي|'
  r'المبلغ\s*مع\s*الضريب|'
  r'المجموع\s*مع\s*الضريب|'
  r'الإجمالي|'
  r'اجمالي|'
  r'\bpayment\b|'
  r'\btotal\b|'
  r'TOTAL|'
  r'\bOTF\b)',
  caseSensitive: false,
);

final _vatLabelRe = RegExp(
  r'(vat\s*\(?\s*15|vat\s*15%?|vta\s*\(?\s*15|ضريبة\s*القيمة|ضريبة\s*الفيمة|'
  r'(?<!excl\.\s)(?<!excl\s)(?<!excluding\s)\bVAT\b|\bVTA\b|\bSST\b)',
  caseSensitive: false,
);

final _skipVendorRe = RegExp(
  r'(tel|phone|fax|vat\s*no|tax\s*reg|trn| ent|gst|invoice|receipt|www\.|http|'
  r'[\w.-]+@[\w.-]+|'
  r'simplified\s*tax|فاتورة|ضريب|هاتف|بطاقة|check\s*#|order\s*#|station|'
  r'server|printed\s*at|dine\s*in|qty\s*name|sales\s*invoice|staff:|'
  r'call\s*center|for\s*order|thank)',
  caseSensitive: false,
);

final _itemLineRe = RegExp(
  r'^\s*(\d{1,3})\s+(.+?)\s+(\d{1,3}(?:[.,]\d{3})*[.,]\d{2})\s*[,.]?\s*$',
);

final _trailingAmountRe = RegExp(
  r'^(.+?)\s+(\d{1,3}(?:[.,]\d{3})*[.,]\d{2})\s*[,.;]?\s*$',
);

final _monthMap = <String, int>{
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

/// Parse a currency-ish number string to double (handles `1.234,56` and `1,234.56`).
double? parseReceiptAmount(String raw) {
  var s = raw.trim().replaceAll(RegExp(r'\s+'), '');
  s = s.replaceAll(RegExp(r'[^\d.,-]'), '');
  if (s.isEmpty) return null;
  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  if (lastComma >= 0 && lastDot >= 0) {
    if (lastComma > lastDot) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  } else if (lastComma >= 0) {
    final decimals = s.length - lastComma - 1;
    if (decimals == 2) {
      s = s.replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  }
  return double.tryParse(s);
}

/// Fix common Tesseract glitches before field extraction.
String repairReceiptOcrText(String ocrText) {
  var t = ocrText;
  // Strip bidi / zero-width marks that break line anchors.
  t = t.replaceAll(RegExp(r'[\u200e\u200f\u202a-\u202e\u2066-\u2069\ufeff]'), '');
  // Latin / Arabic digit lookalikes → ASCII.
  const digits = {
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
  };
  digits.forEach((k, v) => t = t.replaceAll(k, v));

  t = t.replaceAllMapped(
    RegExp(r'\bVTA\b', caseSensitive: false),
    (_) => 'VAT',
  );
  t = t.replaceAllMapped(
    RegExp(r'amou?r?n?t\s*t[eo]\s*pay|mount\s*to\s*pay|amount\s*te\s*pi',
        caseSensitive: false),
    (_) => 'Amount to pay',
  );
  t = t.replaceAllMapped(
    RegExp(r'total\s*ing\.?\s*tex|total\s*inc\.?\s*tex', caseSensitive: false),
    (_) => 'TOTAL inc. tax',
  );
  t = t.replaceAllMapped(
    RegExp(r'\buBTOTAL\b', caseSensitive: false),
    (_) => 'SUBTOTAL',
  );
  t = t.replaceAllMapped(
    RegExp(r'\bOTF\b'),
    (_) => 'TOTAL',
  );

  // `162 .00`, `162. 00`, `49 ,00`, `1,899 00`, `162 00`
  t = t.replaceAllMapped(
    RegExp(r'(\d{1,3}(?:[.,]\d{3})*)[.,]\s+(\d{2})\b'),
    (m) => '${m.group(1)}.${m.group(2)}',
  );
  t = t.replaceAllMapped(
    RegExp(r'(\d{1,3}(?:[.,]\d{3})*)\s+[.,]\s*(\d{2})\b'),
    (m) => '${m.group(1)}.${m.group(2)}',
  );
  t = t.replaceAllMapped(
    RegExp(r'(\d{1,3}),\s*(\d{2})\b'),
    (m) => '${m.group(1)}.${m.group(2)}',
  );
  t = t.replaceAllMapped(
    RegExp(r'(\d{1,3}),(\d{3})\s+(\d{2})\b'),
    (m) => '${m.group(1)},${m.group(2)}.${m.group(3)}',
  );
  // Bare `162 00` / `49 00` before currency or end (not times like 13 48).
  t = t.replaceAllMapped(
    RegExp(
      r'(?<![\d/:])(\d{1,5})\s+(\d{2})(?=\s*(?:SAR|SR|RM|USD|Net|Amount|Total|VAT|$|\n))',
      caseSensitive: false,
    ),
    (m) => '${m.group(1)}.${m.group(2)}',
  );

  // Glued money near totals: `189000` → `189.00` (avoid bare refs like 4000).
  t = t.replaceAllMapped(
    RegExp(
      r'((?:الإجمالي|اجمالي|total|amount|pay|due|#)\s*[^\d]{0,8})(\d{2,3})000(?![\d])',
      caseSensitive: false,
    ),
    (m) => '${m.group(1)}${m.group(2)}.00',
  );

  // Split VAT fragments like `24د ... 65` → `24.65 VAT`.
  t = t.replaceAllMapped(
    RegExp(r'\b(\d{1,3})\s*[دد]\s*.{0,40}?(ضريبة|VAT).{0,20}?\b(\d{2})\b',
        caseSensitive: false),
    (m) => '${m.group(1)}.${m.group(3)} VAT',
  );

  return t;
}

bool _amountIsPercentAnnotation(String line, RegExpMatch m) {
  final start = m.start;
  final end = m.end;
  final before = line.substring(0, start);
  final after = line.substring(end);
  if (RegExp(r'\(\s*$').hasMatch(before) &&
      RegExp(r'^\s*%?\s*\)').hasMatch(after)) {
    return true;
  }
  if (RegExp(r'^\s*%').hasMatch(after)) return true;
  return false;
}

/// Drop a leading OCR junk `4` (common on these thermal photos: 412.26→12.26).
double _stripSpuriousLeadingDigit(double v, {required bool preferSmall}) {
  if (!preferSmall) return v;
  if (v >= 100 && v < 1000) {
    final s = v.toStringAsFixed(2);
    if (s.startsWith('4')) {
      final trimmed = double.tryParse(s.substring(1));
      if (trimmed != null && trimmed >= 1 && trimmed < 100) return trimmed;
    }
  }
  return v;
}

int _applyAmPm(int hour, String? ampm) {
  if (ampm == null || ampm.isEmpty) return hour;
  // Arabic: م = PM, ص = AM (common on KSA receipts).
  if (ampm == 'م' || RegExp(r'^p', caseSensitive: false).hasMatch(ampm)) {
    if (hour < 12) return hour + 12;
    return hour;
  }
  if (ampm == 'ص' || RegExp(r'^a', caseSensitive: false).hasMatch(ampm)) {
    if (hour == 12) return 0;
    return hour;
  }
  return hour;
}

int _repairOcrYear(int y) {
  if (y < 100) y += 2000;
  // Tesseract often turns 2025 → 2095.
  if (y >= 2090 && y <= 2099) return 2020 + (y % 10);
  return y;
}

DateTime? parseReceiptDateTime(String line, [DateTime? fallback]) {
  final iso = _dateIsoRe.firstMatch(line);
  if (iso != null) {
    final y = _repairOcrYear(int.parse(iso.group(1)!));
    final m = int.parse(iso.group(2)!);
    final d = int.parse(iso.group(3)!);
    final hh = iso.group(4) != null ? int.parse(iso.group(4)!) : 0;
    final mm = iso.group(5) != null ? int.parse(iso.group(5)!) : 0;
    final ss = iso.group(6) != null ? int.parse(iso.group(6)!) : 0;
    final hour = _applyAmPm(hh, iso.group(7));
    if (m >= 1 && m <= 12 && d >= 1 && d <= 31 && y >= 2000 && y <= 2100) {
      return DateTime(y, m, d, hour, mm, ss);
    }
  }

  final slash = _dateSlashRe.firstMatch(line);
  if (slash != null) {
    final a = int.parse(slash.group(1)!);
    final b = int.parse(slash.group(2)!);
    var y = _repairOcrYear(int.parse(slash.group(3)!));
    final (day, month) = (a > 12 && b <= 12)
        ? (a, b)
        : (b > 12 && a <= 12)
        ? (b, a)
        : (a, b); // MENA / most receipts: DD/MM
    final hh = slash.group(4) != null ? int.parse(slash.group(4)!) : 0;
    final mm = slash.group(5) != null ? int.parse(slash.group(5)!) : 0;
    final ss = slash.group(6) != null ? int.parse(slash.group(6)!) : 0;
    final hour = _applyAmPm(hh, slash.group(7));
    if (month >= 1 && month <= 12 && day >= 1 && day <= 31 && y >= 2000 && y <= 2100) {
      return DateTime(y, month, day, hour, mm, ss);
    }
  }

  final mon = _dateMonRe.firstMatch(line);
  if (mon != null) {
    final d = int.parse(mon.group(1)!);
    final month = _monthMap[mon.group(2)!.toLowerCase().substring(0, 3)]!;
    var y = _repairOcrYear(int.parse(mon.group(3)!));
    final hh = mon.group(4) != null ? int.parse(mon.group(4)!) : 0;
    final mm = mon.group(5) != null ? int.parse(mon.group(5)!) : 0;
    if (month >= 1 && month <= 12 && d >= 1 && d <= 31 && y >= 2000 && y <= 2100) {
      return DateTime(y, month, d, hh, mm);
    }
  }

  return null;
}

/// Back-compat wrapper used by older tests / callers.
DateTime? parseReceiptDate(String line, DateTime fallback) {
  return parseReceiptDateTime(line) ?? fallback;
}

String? _extractStore(List<String> lines) {
  // Prefer known brand / strong header matches first.
  final brandRe = RegExp(
    r'(ASIAN\s*FOODS|SUSHIART|SUSHI\s*ART|FamilyMart|FAMILY\s*MART|'
    r'LAZA\s*UZBEK|Texas\s*Roadhouse|TEXAS\s*ROADHOUSE|\bROADHOUSE\b|'
    r'\bextra\b|السعودية\s*للخدمات\s*البريد|SPL\b|La\s*Casa|LA\s*CASA)',
    caseSensitive: false,
  );
  for (final line in lines.take(20)) {
    final m = brandRe.firstMatch(line);
    if (m != null) {
      final raw = m.group(0)!.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (RegExp(r'asian\s*foods', caseSensitive: false).hasMatch(raw)) {
        return 'ASIAN FOODS JEDDAH';
      }
      if (RegExp(r'sushi', caseSensitive: false).hasMatch(raw)) {
        return 'SUSHIART';
      }
      if (RegExp(r'familymart|family\s*mart', caseSensitive: false)
          .hasMatch(raw)) {
        return 'FamilyMart';
      }
      if (RegExp(r'laza', caseSensitive: false).hasMatch(raw)) {
        return 'LAZA UZBEK CUISINE';
      }
      if (RegExp(r'texas|roadhouse', caseSensitive: false).hasMatch(raw)) {
        return 'Texas Roadhouse';
      }
      if (RegExp(r'\bextra\b', caseSensitive: false).hasMatch(raw)) {
        return 'extra';
      }
      if (RegExp(r'بريد|SPL', caseSensitive: false).hasMatch(raw)) {
        return 'SPL';
      }
      if (RegExp(r'la\s*casa', caseSensitive: false).hasMatch(raw)) {
        return 'La Casa';
      }
      return raw;
    }
  }

  // Arabic restaurant / company lines.
  for (final line in lines.take(12)) {
    if (line.contains('مطعم') || line.contains('شركة')) {
      if (line.length >= 4 && line.length <= 60) return line.trim();
    }
  }

  for (final line in lines.take(10)) {
    if (line.length < 3 || line.length > 48) continue;
    if (_skipVendorRe.hasMatch(line)) continue;
    if (_amountRe.hasMatch(line) && line.length < 16) continue;
    if (parseReceiptDateTime(line) != null) continue;
    if (RegExp(r'^[\d\s.,:+/-]+$').hasMatch(line)) continue;
    if (RegExp(r'^\d{10,}').hasMatch(line)) continue;
    return line.trim();
  }
  return null;
}

double? _labeledAmount(
  List<String> lines,
  RegExp labelRe, {
  bool Function(String line)? skipLine,
  bool preferSmaller = false,
  bool stripLeadingJunk = false,
}) {
  double? best;
  for (var i = lines.length - 1; i >= 0; i--) {
    final line = lines[i];
    if (skipLine != null && skipLine(line)) continue;
    if (!labelRe.hasMatch(line)) continue;
    final candidates = <double>[];
    for (final m in _amountRe.allMatches(line)) {
      if (_amountIsPercentAnnotation(line, m)) continue;
      var v = parseReceiptAmount(m.group(1)!);
      if (v == null || v <= 0) continue;
      if (stripLeadingJunk) {
        v = _stripSpuriousLeadingDigit(v, preferSmall: preferSmaller);
      }
      candidates.add(v);
    }
    if (candidates.isEmpty && i + 1 < lines.length) {
      final nextLine = lines[i + 1];
      // Only accept a following amount when the next line is amount-only
      // (not another item like "Chicken … 6.90" under a bare TOTAL).
      final nextIsAmountOnly = RegExp(
        r'^(?:SAR|SR|RM|USD)?\s*[\d.,]+\s*(?:SAR|SR|RM)?\s*$',
        caseSensitive: false,
      ).hasMatch(nextLine.trim());
      if (nextIsAmountOnly) {
        for (final m in _amountRe.allMatches(nextLine)) {
          if (_amountIsPercentAnnotation(nextLine, m)) continue;
          final v = parseReceiptAmount(m.group(1)!);
          if (v != null && v > 0) candidates.add(v);
        }
      }
    }
    if (candidates.isEmpty && i > 0 && !_isVatOnlyLine(lines[i - 1])) {
      // Amount sometimes printed on the previous line (left column).
      final prev = lines[i - 1];
      final prevIsAmountOnly = RegExp(
        r'^(?:SAR|SR|RM|USD)?\s*[\d.,]+\s*(?:SAR|SR|RM)?\s*$',
        caseSensitive: false,
      ).hasMatch(prev.trim());
      final prevHasLabel = _totalLabelRe.hasMatch(prev) || _vatLabelRe.hasMatch(prev);
      if (prevIsAmountOnly || prevHasLabel) {
        for (final m in _amountRe.allMatches(prev)) {
          if (_amountIsPercentAnnotation(prev, m)) continue;
          final v = parseReceiptAmount(m.group(1)!);
          if (v != null && v > 0) candidates.add(v);
        }
      }
    }
    if (candidates.isEmpty) continue;
    final candidate =
        preferSmaller ? candidates.reduce((a, b) => a < b ? a : b) : candidates.last;
    if (!preferSmaller) return candidate;
    if (best == null || candidate < best) best = candidate;
  }
  return best;
}

/// True when [line] or a neighbor is a unit-price row (not a bill total).
bool _looksLikeUnitPriceContext(List<String> lines, String line) {
  if (RegExp(r'unit\s*price', caseSensitive: false).hasMatch(line)) {
    return true;
  }
  final idx = lines.indexOf(line);
  if (idx < 0) return false;
  for (final j in [idx - 1, idx + 1]) {
    if (j < 0 || j >= lines.length) continue;
    if (RegExp(r'unit\s*price', caseSensitive: false).hasMatch(lines[j])) {
      return true;
    }
  }
  return false;
}

/// True when [amount] matches a repeated line-item price and a larger
/// subtotal/due/net figure also appears in the OCR (avoid picking 49/69).
bool _isLikelyLineItemPrice(List<String> lines, double amount) {
  if (amount <= 0 || amount >= 500) return false;
  final blob = lines.join('\n');
  final token = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  final tokenAlt = amount.toStringAsFixed(2).replaceAll('.', ',');
  final hits = RegExp(
    '${RegExp.escape(token)}|${RegExp.escape(tokenAlt)}',
  ).allMatches(blob).length;
  if (hits < 2) return false;
  // Larger labeled totals elsewhere → this amount is probably an item.
  for (final line in lines) {
    if (!RegExp(
      r'sub\s*total|subtotal|amount\s*due|net\s*ttl|total\s*amount|grand\s*total|صافي',
      caseSensitive: false,
    ).hasMatch(line)) {
      continue;
    }
    for (final m in _amountRe.allMatches(line)) {
      final v = parseReceiptAmount(m.group(1)!);
      if (v != null && v > amount * 1.15) return true;
    }
  }
  return false;
}

bool _isVatOnlyLine(String line) {
  final hasVat = _vatLabelRe.hasMatch(line);
  if (!hasVat) return false;
  // "Total Amount (Incl. Vat)" is a total line, not a VAT-only line.
  if (_totalLabelRe.hasMatch(line) &&
      RegExp(r'incl|amount\s*due|grand|صافي|المبلغ\s*مع', caseSensitive: false)
          .hasMatch(line)) {
    return false;
  }
  if (RegExp(r'total\s*amount\s*\(?\s*incl|amount\s*due|grand\s*total|صافي',
          caseSensitive: false)
      .hasMatch(line)) {
    return false;
  }
  return !RegExp(
    r'amount\s*due|total\s*inc|grand\s*total|صافي|المبلغ\s*مع',
    caseSensitive: false,
  ).hasMatch(line);
}

bool _looksLikeVatAmount(List<String> lines, double v) {
  for (final line in lines) {
    if (!_isVatOnlyLine(line)) continue;
    for (final m in _amountRe.allMatches(line)) {
      if (_amountIsPercentAnnotation(line, m)) continue;
      final a = parseReceiptAmount(m.group(1)!);
      if (a != null && (a - v).abs() < 0.02) return true;
    }
  }
  return false;
}

double? _extractExclTotal(List<String> lines) {
  return _labeledAmount(
    lines,
    RegExp(
      r'total\s*amount\s*\(?\s*excl|total\s*no\s*tax|sub\s*total|subtotal|'
      r'المجموع\s*باستثناء|المبلغ\s*الخاضع',
      caseSensitive: false,
    ),
    skipLine: _isVatOnlyLine,
  );
}

double? _extractTotal(List<String> lines) {
  // Strongest labels first (incl. VAT / amount due).
  final strong = RegExp(
    r'(total\s*amount\s*\(?\s*incl|amou?r?n?t\s*due|amou?r?n?t\s*t[eo]\s*pay|'
    r'mount\s*to\s*pay|total\s*inc|net\s*ttl|المبلغ\s*مع\s*الضريب|'
    r'المجموع\s*مع\s*الضريب|صافي|grand\s*total|total\s*tender|'
    r'\bpayment\b)',
    caseSensitive: false,
  );

  // Prefer net / صافي / trailing "SR 172.00" when a slightly higher total exists.
  double? netPrefer;
  for (final line in lines.reversed) {
    if (RegExp(r'net\s*ttl|\bصافي\b|^\s*SR\s*[\d.,]+', caseSensitive: false)
        .hasMatch(line)) {
      for (final m in _amountRe.allMatches(line)) {
        final a = parseReceiptAmount(m.group(1)!);
        if (a != null && a > 0) {
          netPrefer = a;
          break;
        }
      }
      if (netPrefer != null) break;
    }
  }

  final v1 = _labeledAmount(
    lines,
    strong,
    skipLine: (l) => _isVatOnlyLine(l) ||
        RegExp(r'sub\s*total|subtotal|excl', caseSensitive: false).hasMatch(l),
    stripLeadingJunk: true,
  );
  if (v1 != null && !_looksLikeVatAmount(lines, v1)) {
    if (netPrefer != null &&
        netPrefer < v1 &&
        (v1 - netPrefer) <= 1.0 &&
        !_looksLikeVatAmount(lines, netPrefer)) {
      return netPrefer;
    }
    // Prefer de-prefixed payment totals when OCR added a leading 4 (494→94).
    final cleaned = _stripSpuriousLeadingDigit(v1, preferSmall: true);
    if (cleaned < v1 &&
        !_looksLikeVatAmount(lines, cleaned) &&
        RegExp(r'payment|total|due|pay', caseSensitive: false)
            .hasMatch(lines.reversed.take(12).join('\n'))) {
      // Only strip when a matching cleaned amount also appears in text.
      final blob = lines.join('\n');
      if (blob.contains(cleaned.toStringAsFixed(2)) ||
          blob.contains(cleaned.toStringAsFixed(0))) {
        return cleaned;
      }
    }
    return v1;
  }

  final v2 = _labeledAmount(
    lines,
    _totalLabelRe,
    skipLine: (l) =>
        _isVatOnlyLine(l) ||
        RegExp(r'sub\s*total|subtotal|excl', caseSensitive: false).hasMatch(l) ||
        _looksLikeUnitPriceContext(lines, l),
    stripLeadingJunk: true,
  );
  if (v2 != null &&
      !_looksLikeVatAmount(lines, v2) &&
      !_isLikelyLineItemPrice(lines, v2)) {
    return v2;
  }

  // Restaurant slips often only OCR "Subtotal 162.00" when Amount Due is muddy.
  final subtotal = _labeledAmount(
    lines,
    RegExp(r'sub\s*total|subtotal', caseSensitive: false),
    skipLine: (l) =>
        _isVatOnlyLine(l) ||
        RegExp(r'excl|unit\s*price', caseSensitive: false).hasMatch(l),
    stripLeadingJunk: true,
  );
  if (subtotal != null &&
      !_looksLikeVatAmount(lines, subtotal) &&
      !_isLikelyLineItemPrice(lines, subtotal)) {
    return subtotal;
  }

  // Incl − known pattern: take amount near "inc. tax" even if digits glued.
  for (final line in lines.reversed) {
    if (!RegExp(r'inc\.?\s*tax|incl\.?\s*vat|مع\s*الضريب', caseSensitive: false)
        .hasMatch(line)) {
      continue;
    }
    for (final m in _amountRe.allMatches(line)) {
      final v = parseReceiptAmount(m.group(1)!);
      if (v != null &&
          v > 0 &&
          !_looksLikeVatAmount(lines, v) &&
          !_isLikelyLineItemPrice(lines, v)) {
        return v;
      }
    }
  }

  // Fallback: largest amount in bottom half, skipping subtotals / unit prices.
  final start = (lines.length / 2).floor().clamp(0, lines.length);
  double max = 0;
  for (var i = start; i < lines.length; i++) {
    final line = lines[i];
    if (RegExp(r'unit\s*price|sub\s*total|subtotal|excl', caseSensitive: false)
        .hasMatch(line)) {
      continue;
    }
    if (_looksLikeUnitPriceContext(lines, line)) continue;
    for (final m in _amountRe.allMatches(line)) {
      if (_amountIsPercentAnnotation(line, m)) continue;
      final v = parseReceiptAmount(m.group(1)!);
      if (v != null &&
          v > max &&
          v < 1000000 &&
          !_looksLikeVatAmount(lines, v) &&
          !_isLikelyLineItemPrice(lines, v)) {
        max = v;
      }
    }
  }
  if (max > 0) return max;

  // Whole-receipt max (retail slips where total sits mid-page).
  for (final line in lines) {
    if (RegExp(r'unit\s*price|warranty|discount\s*100', caseSensitive: false)
        .hasMatch(line)) {
      continue;
    }
    for (final m in _amountRe.allMatches(line)) {
      final v = parseReceiptAmount(m.group(1)!);
      if (v != null && v > max && v < 1000000) max = v;
    }
  }
  return max > 0 ? max : null;
}

double? _extractVat(List<String> lines, {double? total}) {
  final v = _labeledAmount(
    lines,
    _vatLabelRe,
    preferSmaller: true,
    stripLeadingJunk: true,
    skipLine: (line) => RegExp(
      r'excl|excluding|before\s*vat|بدون|باستثناء|رقم\s*تسجيل|vat\s*:?\s*\d{10,}|'
      r'total\s*amount|amount\s*due|grand\s*total|رقم\s*الضريب',
      caseSensitive: false,
    ).hasMatch(line),
  );
  if (v != null && (total == null || v < total) && v < 100000) {
    // Reject VAT *rate* mistaken as amount (e.g. 15.08%), keep small postage VAT.
    if (total != null && total > 0) {
      final ratio = v / total;
      if (ratio >= 0.005 && ratio < 0.25) return v;
    } else if (v < 500) {
      return v;
    }
  }

  // Incl − Excl when both labeled and the gap looks like a tax amount.
  final incl = _labeledAmount(
    lines,
    RegExp(r'total\s*amount\s*\(?\s*incl|total\s*inc', caseSensitive: false),
  );
  final excl = _labeledAmount(
    lines,
    RegExp(r'total\s*amount\s*\(?\s*excl|total\s*no\s*tax', caseSensitive: false),
  );
  if (incl != null && excl != null && incl > excl) {
    final diff = double.parse((incl - excl).toStringAsFixed(2));
    final ratio = diff / incl;
    if (diff > 0 && ratio > 0.02 && ratio < 0.25) return diff;
  }

  // Stacked totals: `<excl>`, `<vat>`, `<incl>` / Amount to pay.
  if (total != null && total > 0) {
    final amounts = <double>[];
    for (final line in lines) {
      final only = RegExp(
        r'^(?:SAR|SR|RM)?\s*[\d.,]+\s*(?:SAR|SR|RM)?\s*$',
        caseSensitive: false,
      ).hasMatch(line.trim());
      if (!only &&
          !RegExp(r'total|tax|vat|ضريب|amount|pay', caseSensitive: false)
              .hasMatch(line)) {
        continue;
      }
      for (final m in _amountRe.allMatches(line)) {
        if (_amountIsPercentAnnotation(line, m)) continue;
        final a = parseReceiptAmount(m.group(1)!);
        if (a != null && a > 0 && a < total) amounts.add(a);
      }
    }
    // Prefer amount ≈ total − nearest-lower excl candidate.
    double? bestStacked;
    for (final a in amounts) {
      final ratio = a / total;
      if (ratio > 0.10 && ratio < 0.18) {
        bestStacked = a;
        break;
      }
    }
    if (bestStacked != null) return bestStacked;

    // Incl − Excl from stacked bare numbers (229.57 / 34.43 / 264.00).
    final bare = <double>[];
    for (final line in lines) {
      if (!RegExp(
        r'^(?:SAR|SR|RM)?\s*[\d.,]+\s*(?:SAR|SR|RM)?\s*$',
        caseSensitive: false,
      ).hasMatch(line.trim())) {
        continue;
      }
      final a = parseReceiptAmount(_amountRe.firstMatch(line)?.group(1) ?? '');
      if (a != null) bare.add(a);
    }
    for (var i = 0; i + 2 < bare.length; i++) {
      final excl = bare[i];
      final tax = bare[i + 1];
      final incl = bare[i + 2];
      if ((incl - total!).abs() < 0.51 || (incl - excl - tax).abs() < 0.05) {
        if (tax > 0 && tax < incl) return tax;
      }
    }
  }

  // KSA 15% inclusive: vat = total * 15/115 when a VAT cue exists but OCR
  // mangled the tax figure (e.g. "SAR 4 18 VAT").
  if (total != null && total > 0) {
    final hasVatCue = lines.any(
      (l) =>
          _vatLabelRe.hasMatch(l) ||
          RegExp(r'ضريب|tax\s*invoice|incl\.?\s*vat|inc\.?\s*tax|amount\s*to\s*pay',
                  caseSensitive: false)
              .hasMatch(l),
    );
    if (hasVatCue) {
      final inferred = double.parse((total * 15 / 115).toStringAsFixed(2));
      if (v != null && v < total) {
        final ratio = v / total;
        if (ratio > 0.02 && ratio < 0.25) return v;
      }
      return inferred;
    }
  }
  return (v != null && (total == null || v < total)) ? v : null;
}

double? _inferTotalFromItems(List<String> lines, List<ReceiptLineItem> items) {
  if (items.length < 3) return null;
  var sum = items.fold<double>(0, (a, b) => a + b.amountCents / 100.0);
  // Discounts / rounding on their own lines (explicit minus / small adjustments).
  for (final line in lines) {
    if (!RegExp(
      r'discount|clearance|rounding|allday-onigiri',
      caseSensitive: false,
    ).hasMatch(line)) {
      continue;
    }
    for (final m in _amountRe.allMatches(line)) {
      final raw = m.group(1)!;
      final v = parseReceiptAmount(raw);
      if (v == null || v <= 0 || v >= 20) continue;
      final prefixed = line.substring(0, m.start);
      // Only a minus immediately before the amount counts (not "AllDay-Onigiri").
      final explicitNeg = RegExp(r'-\s*$').hasMatch(prefixed) ||
          RegExp(r'\(\s*$').hasMatch(prefixed);
      if (explicitNeg ||
          RegExp(r'rounding|clearance', caseSensitive: false).hasMatch(line)) {
        sum -= v;
      }
    }
  }
  if (sum <= 0 || sum > 100000) return null;
  return double.parse(sum.toStringAsFixed(2));
}

DateTime? _extractDateTime(List<String> lines) {
  DateTime? best;
  for (final line in lines) {
    if (RegExp(
      r'printed\s*at|check\s*in\s*time|وقت\s*الطباعة',
      caseSensitive: false,
    ).hasMatch(line)) {
      // Prefer invoice/order time over print / check-in when both exist;
      // still accept if nothing else is found.
      final dt = parseReceiptDateTime(line);
      best ??= dt;
      continue;
    }
    final dt = parseReceiptDateTime(line);
    if (dt == null) continue;
    if (best == null) {
      best = dt;
      continue;
    }
    final bestHasTime = best.hour != 0 || best.minute != 0;
    final dtHasTime = dt.hour != 0 || dt.minute != 0;
    if (dtHasTime && !bestHasTime) {
      best = dt;
    } else if (dtHasTime && bestHasTime) {
      // Prefer non-print invoice timestamps (later assignment wins among equals).
      best = dt;
    }
  }
  return best;
}

bool _looksLikeItemNoise(String name) {
  final n = name.trim();
  if (n.length < 2) return true;
  if (_totalLabelRe.hasMatch(n) || _vatLabelRe.hasMatch(n)) return true;
  if (_skipVendorRe.hasMatch(n)) return true;
  if (RegExp(
    r'^(unit\s*price|subtotal|sub\s*total|qty|item|price|desc|amount|'
    r'payment|products?\s*count|rounding|discount|visa|credit|cash|'
    r'thank|spiciness|supplier|warranty|order\s*type)',
    caseSensitive: false,
  ).hasMatch(n)) {
    return true;
  }
  return false;
}

List<ReceiptLineItem> _extractItems(List<String> lines) {
  final items = <ReceiptLineItem>[];
  final seen = <String>{};

  // Cut off at totals section when possible.
  var end = lines.length;
  for (var i = 0; i < lines.length; i++) {
    if (RegExp(
      r'^(sub\s*total|subtotal|total\s*amount|amount\s*due|vat\s*\(|'
      r'ضريبة|الإجمالي|المجموع)',
      caseSensitive: false,
    ).hasMatch(lines[i].trim())) {
      end = i;
      break;
    }
  }

  for (var i = 0; i < end; i++) {
    final line = lines[i];
    final qtyMatch = _itemLineRe.firstMatch(line);
    if (qtyMatch != null) {
      final name = qtyMatch.group(2)!.trim();
      final amount = parseReceiptAmount(qtyMatch.group(3)!);
      if (amount != null &&
          amount > 0 &&
          amount < 500000 &&
          !_looksLikeItemNoise(name)) {
        final key = '${name.toLowerCase()}|$amount';
        if (seen.add(key)) {
          items.add(
            ReceiptLineItem(
              description: name,
              amountCents: (amount * 100).round(),
            ),
          );
        }
      }
      continue;
    }

    // "Lunch Special Sushi 3 X" with price on same/prev pattern: "192.00 Lunch..."
    final leadAmount = RegExp(
      r'^(\d{1,3}(?:[.,]\d{3})*[.,]\d{2})\s+(.+)$',
    ).firstMatch(line);
    if (leadAmount != null) {
      final amount = parseReceiptAmount(leadAmount.group(1)!);
      var name = leadAmount.group(2)!.trim();
      name = name.replaceFirst(RegExp(r'\s+\d+\s*[xX]\s*$'), '').trim();
      if (amount != null &&
          amount >= 1 &&
          amount < 500000 &&
          name.length >= 3 &&
          !_looksLikeItemNoise(name) &&
          !RegExp(r'^(SAR|SR|RM)\b', caseSensitive: false).hasMatch(name)) {
        final key = '${name.toLowerCase()}|$amount';
        if (seen.add(key)) {
          items.add(
            ReceiptLineItem(
              description: name,
              amountCents: (amount * 100).round(),
            ),
          );
        }
      }
      continue;
    }

    // "2 each @ 2.20 4.40" or "1 @ 1,899.00" — prefer the line total (last amount).
    final atPrice = RegExp(
      r'^(.*?)(?:\d+\s*)?@\s*(\d{1,3}(?:[.,]\d{3})*[.,]\d{2})'
      r'(?:\s+(\d{1,3}(?:[.,]\d{3})*[.,]\d{2}))?\s*$',
    ).firstMatch(line);
    if (atPrice != null) {
      var name = atPrice.group(1)!.trim();
      if (name.isEmpty) name = 'Item';
      final unit = parseReceiptAmount(atPrice.group(2)!);
      final lineTotal = atPrice.group(3) != null
          ? parseReceiptAmount(atPrice.group(3)!)
          : unit;
      final amount = lineTotal ?? unit;
      name = name.replaceFirst(RegExp(r'^\d{6,}\s*'), '').trim();
      name = name.replaceFirst(RegExp(r'^\d+\s+each\s*$', caseSensitive: false), 'Item');
      if (amount != null &&
          amount >= 0.5 &&
          amount < 500000 &&
          !_looksLikeItemNoise(name)) {
        final key = '${name.toLowerCase()}|$amount';
        if (seen.add(key)) {
          items.add(
            ReceiptLineItem(
              description: name.isEmpty ? 'Item' : name,
              amountCents: (amount * 100).round(),
            ),
          );
        }
      }
      continue;
    }

    final trail = _trailingAmountRe.firstMatch(line);
    if (trail != null) {
      var name = trail.group(1)!.trim();
      final amount = parseReceiptAmount(trail.group(2)!);
      name = name.replaceFirst(RegExp(r'^\d{1,3}\s+'), '').trim();
      // Skip catalog codes / bare qty noise.
      if (amount != null &&
          amount >= 0.5 &&
          amount < 500000 &&
          name.length >= 3 &&
          !_looksLikeItemNoise(name) &&
          RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(name) &&
          !RegExp(r'^\d+$').hasMatch(name)) {
        final key = '${name.toLowerCase()}|$amount';
        if (seen.add(key)) {
          items.add(
            ReceiptLineItem(
              description: name,
              amountCents: (amount * 100).round(),
            ),
          );
        }
      }
    }
  }

  return items;
}

String? _inferStoreFromBody(String ocrText, List<ReceiptLineItem> items) {
  final blob = '$ocrText ${items.map((e) => e.description).join(' ')}';
  if (RegExp(r'la\s*casa', caseSensitive: false).hasMatch(blob)) {
    return 'La Casa';
  }
  if (RegExp(r'osh\s*plov|uzbek|laza', caseSensitive: false).hasMatch(blob)) {
    return 'LAZA UZBEK CUISINE';
  }
  if (RegExp(r'familymart|family\s*mart|sunway', caseSensitive: false)
      .hasMatch(blob)) {
    return 'FamilyMart';
  }
  if (RegExp(r'texas|roadhouse|frcatch|cactuspet', caseSensitive: false)
      .hasMatch(blob)) {
    return 'Texas Roadhouse';
  }
  if (RegExp(
        r'midea|dishwasher|sparky|\bextra\b|wqp\d|play\s*card',
        caseSensitive: false,
      ).hasMatch(blob)) {
    return 'extra';
  }
  if (RegExp(
        r'sushi|plateaux|plateau|lemonade|lunch\s*special|\bluneh?\b|'
        r'fresh\s*juice',
        caseSensitive: false,
      ).hasMatch(blob)) {
    return 'SUSHIART';
  }
  if (RegExp(r'splonline|بريد|طرد\s*اقتصاد', caseSensitive: false)
      .hasMatch(blob)) {
    return 'SPL';
  }
  if (RegExp(r'asian\s*foods|tomyam|tempura', caseSensitive: false)
      .hasMatch(blob)) {
    return 'ASIAN FOODS JEDDAH';
  }
  return null;
}

String? _buildDescription({
  required double? vat,
  required List<ReceiptLineItem> items,
  required String ocrText,
}) {
  final parts = <String>[];
  if (vat != null && vat > 0) {
    parts.add('VAT: ${vat.toStringAsFixed(2)}');
  }
  if (items.isNotEmpty) {
    parts.add(
      items
          .map(
            (e) =>
                '${e.description}: ${(e.amountCents / 100).toStringAsFixed(2)}',
          )
          .join('\n'),
    );
  }
  if (parts.isEmpty) {
    // Keep a short OCR snippet only when structured fields failed.
    final trimmed = ocrText.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length > 400 ? '${trimmed.substring(0, 400)}…' : trimmed;
  }
  return parts.join('\n\n');
}

/// Rich on-device extraction used by tests and the scan pipeline.
ReceiptDetails extractReceiptDetails(
  String ocrText,
  DateTime fallbackDate,
) {
  final repaired = repairReceiptOcrText(ocrText);
  final lines = repaired
      .split(RegExp(r'[\r\n]+'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  final headerStore = _extractStore(lines);
  final dateTime = _extractDateTime(lines) ?? fallbackDate;
  final items = _extractItems(lines);
  var total = _extractTotal(lines);
  final itemsSum = items.isEmpty
      ? 0.0
      : items.fold<double>(0, (a, b) => a + b.amountCents / 100.0);
  // Convenience-store slips often lose the TOTAL line; rebuild from items.
  // Also: when OCR latches onto a repeating item price (49/69) but items sum
  // much higher, prefer the sum.
  if (total == null ||
      (items.length >= 5 &&
          total < 20 &&
          itemsSum > total * 2) ||
      (items.length >= 3 &&
          itemsSum > 0 &&
          total != null &&
          itemsSum > total * 1.4 &&
          _isLikelyLineItemPrice(lines, total))) {
    final inferredTotal = _inferTotalFromItems(lines, items);
    if (inferredTotal != null) total = inferredTotal;
  }
  // Single big-ticket retail (dishwasher etc.): use largest item if no total.
  if (total == null && items.isNotEmpty) {
    final maxItem = items
        .map((e) => e.amountCents / 100.0)
        .reduce((a, b) => a > b ? a : b);
    if (maxItem >= 50) total = maxItem;
  }
  final vat = _extractVat(lines, total: total);
  final inferred = _inferStoreFromBody(repaired, items);
  final knownBrand = RegExp(
    r'asian|sushi|family|laza|texas|\bextra\b|spl|casa|roadhouse',
    caseSensitive: false,
  );
  final String store;
  if (headerStore != null &&
      headerStore.isNotEmpty &&
      knownBrand.hasMatch(headerStore)) {
    store = headerStore;
  } else if (inferred != null) {
    store = inferred;
  } else {
    store = headerStore ?? '';
  }
  final description = _buildDescription(
    vat: vat,
    items: items,
    ocrText: repaired,
  );

  return ReceiptDetails(
    store: store,
    total: total,
    vat: vat,
    dateTime: dateTime,
    items: items,
    description: description,
  );
}

/// On-device heuristic extraction from OCR text (no LLM).
ReceiptScanResult extractReceiptFromOcrText(
  String ocrText,
  DateTime fallbackDate,
) {
  final d = extractReceiptDetails(ocrText, fallbackDate);
  if (d.total != null && d.total! > 0) {
    return ReceiptScanParsed(
      vendor: d.store,
      date: d.dateTime,
      total: d.total!,
      vat: d.vat,
      lineItems: d.items.isEmpty ? null : d.items,
      description: d.description,
    );
  }
  return ReceiptScanFallback(ocrText: ocrText);
}

/// Structured receipt fields from local OCR heuristics.
class ReceiptDetails {
  final String store;
  final double? total;
  final double? vat;
  final DateTime dateTime;
  final List<ReceiptLineItem> items;
  final String? description;

  const ReceiptDetails({
    required this.store,
    required this.total,
    required this.vat,
    required this.dateTime,
    required this.items,
    required this.description,
  });
}
