import 'package:characters/characters.dart';
import 'package:flutter/painting.dart';
import 'package:intl/intl.dart' show Bidi;

/// Unicode FSI (U+2068) / PDI (U+2069): isolate user-generated content inside
/// mixed-direction strings (e.g. `"$title – $amount"`, translated templates).
///
/// Display-only — never persist the result (DB titles/names must stay raw).
String isolateBidi(String text) => '\u2068$text\u2069';

/// Strip bidi isolates for equality / test helpers.
String unwrapBidiIsolates(String text) =>
    text.replaceAll('\u2068', '').replaceAll('\u2069', '');

/// Base direction for standalone UGC so truncation ellipsis follows the
/// content's script, not only the ambient UI locale.
///
/// Returns null when [text] has no strong directional characters (inherit).
TextDirection? resolveUserTextDirection(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  // Neutral-only (digits, punctuation, emoji) → inherit ambient direction.
  if (!_hasStrongDirectional(trimmed)) return null;
  return Bidi.detectRtlDirectionality(trimmed)
      ? TextDirection.rtl
      : TextDirection.ltr;
}

/// Align UGC to the ambient UI start edge (right in RTL, left in LTR).
///
/// Content [TextDirection] still controls glyph order / ellipsis; this only
/// picks which side of the box the line sits on — so Latin names stay next to
/// leading avatars in Arabic UI instead of jumping to the far edge.
TextAlign resolveUiStartTextAlign(TextDirection uiDirection) {
  return uiDirection == TextDirection.rtl ? TextAlign.right : TextAlign.left;
}

bool _hasStrongDirectional(String text) {
  for (final unit in text.runes) {
    // Arabic, Hebrew, and other RTL blocks commonly used in Hisab UGC.
    if (unit >= 0x0590 && unit <= 0x08FF) return true;
    if (unit >= 0xFB1D && unit <= 0xFDFF) return true;
    if (unit >= 0xFE70 && unit <= 0xFEFF) return true;
    // Latin / Cyrillic / Greek / CJK count as strong LTR for detection.
    if (unit >= 0x0041 && unit <= 0x005A) return true;
    if (unit >= 0x0061 && unit <= 0x007A) return true;
    if (unit >= 0x00C0 && unit <= 0x024F) return true;
    if (unit >= 0x0400 && unit <= 0x04FF) return true;
    if (unit >= 0x3040 && unit <= 0x30FF) return true;
    if (unit >= 0x4E00 && unit <= 0x9FFF) return true;
    if (unit >= 0xAC00 && unit <= 0xD7AF) return true;
  }
  return false;
}

/// Grapheme-safe hard elide (emoji / ZWJ / flags stay intact). Prefer layout
/// [TextOverflow.ellipsis] when width-based clipping is enough; use this when
/// a character budget is required (toasts, push bodies, app-bar soft caps).
String elideGraphemes(
  String text, {
  required int maxGraphemes,
  String ellipsis = '…',
  bool trimInput = true,
}) {
  assert(maxGraphemes >= 0);
  final source = trimInput ? text.trim() : text;
  if (source.isEmpty || maxGraphemes == 0) {
    return maxGraphemes == 0 && source.isNotEmpty ? ellipsis : source;
  }
  final ch = Characters(source);
  if (ch.length <= maxGraphemes) return source;
  return '${ch.take(maxGraphemes).string}$ellipsis';
}

/// Grapheme-safe clamp without ellipsis (display budgets).
String clampGraphemes(
  String text, {
  required int maxGraphemes,
  bool trimInput = true,
}) {
  assert(maxGraphemes >= 0);
  final source = trimInput ? text.trim() : text;
  if (source.isEmpty || maxGraphemes == 0) {
    return maxGraphemes == 0 ? '' : source;
  }
  final ch = Characters(source);
  if (ch.length <= maxGraphemes) return source;
  return ch.take(maxGraphemes).string;
}

/// Clamp by Unicode code points to align with Postgres `length()` / `char_length()`.
/// Prefer this over UTF-16 [String.substring] for DB CHECK caps (names, titles).
String clampCodePoints(
  String text, {
  required int maxCodePoints,
  bool trimInput = true,
}) {
  assert(maxCodePoints >= 0);
  final source = trimInput ? text.trim() : text;
  if (source.isEmpty || maxCodePoints == 0) {
    return maxCodePoints == 0 ? '' : source;
  }
  final runes = source.runes;
  if (runes.length <= maxCodePoints) return source;
  return String.fromCharCodes(runes.take(maxCodePoints));
}
