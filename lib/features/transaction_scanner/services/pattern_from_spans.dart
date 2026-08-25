import '../domain/field_span.dart';
import '../domain/scanner_pattern.dart';

/// Builds a [ScannerPattern] from user-labeled spans on a sample body.
ScannerPattern? patternFromSpans({
  required String id,
  required String name,
  required String senderMatch,
  required String body,
  required List<FieldSpan> spans,
  required DateTime createdAt,
}) {
  String? captureFor(FieldRole role) {
    final span = spans.where((s) => s.role == role).firstOrNull;
    if (span == null) return null;
    if (span.start < 0 || span.end > body.length || span.end <= span.start) {
      return null;
    }
    final text = body.substring(span.start, span.end);
    if (text.trim().isEmpty) return null;
    return _contextRegex(
      body,
      span.start,
      genericCapture: _genericCapture(role),
    );
  }

  final amount = captureFor(FieldRole.amount);
  if (amount == null) return null;

  return ScannerPattern(
    id: id,
    name: name,
    senderMatch: senderMatch,
    amountRegex: amount,
    currencyRegex: captureFor(FieldRole.currency),
    cardRegex: captureFor(FieldRole.card),
    merchantRegex: captureFor(FieldRole.merchant),
    dateRegex: captureFor(FieldRole.date),
    createdAt: createdAt,
  );
}

/// Generic captures so a taught sample matches later notifications.
String _genericCapture(FieldRole role) {
  switch (role) {
    case FieldRole.amount:
      return r'(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})|\d+[.,]\d{1,2}|\d{2,})';
    case FieldRole.currency:
      return r'([A-Z]{3}|\u0631\.\u0633|\u0631\u064A\u0627\u0644|\u062F\.\u0625|\$|\u20AC|\u00A3)';
    case FieldRole.merchant:
    case FieldRole.place:
      return r'([^\s,.]{2,40})';
    case FieldRole.card:
      return r'(\d{4})';
    case FieldRole.date:
      return r'(\d{1,4}[/\-.]\d{1,2}(?:[/\-.]\d{1,4})?)';
    case FieldRole.ignore:
      return r'(.+?)';
  }
}

String _contextRegex(
  String body,
  int start, {
  required String genericCapture,
}) {
  final prefixStart = start > 16 ? start - 16 : 0;
  final prefix = body.substring(prefixStart, start);
  if (prefix.trim().isEmpty) return genericCapture;
  final escapedPrefix = prefix
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .map(RegExp.escape)
      .join(r'\s+');
  if (escapedPrefix.isEmpty) return genericCapture;
  return '$escapedPrefix\\s*$genericCapture';
}
