import 'package:flutter/material.dart';

import '../utils/user_text.dart';

/// Displays user-generated text (expense titles, names, notes) with a content-
/// based [textDirection] so truncation / ellipsis follow the script order
/// (Arabic/Hebrew vs Latin/CJK) rather than only the UI locale.
///
/// Does not embed bidi isolates in [data] so widget tests can still use
/// `find.text(...)`. For UGC inside larger composed strings, wrap with
/// [isolateBidi] instead.
class UserText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool softWrap;
  final TextWidthBasis? textWidthBasis;
  final StrutStyle? strutStyle;
  final String? semanticsLabel;

  /// Optional grapheme budget before layout ellipsis (e.g. app bar soft cap).
  final int? maxGraphemes;

  const UserText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap = true,
    this.textWidthBasis,
    this.strutStyle,
    this.semanticsLabel,
    this.maxGraphemes,
  });

  @override
  Widget build(BuildContext context) {
    final display = maxGraphemes != null
        ? elideGraphemes(data, maxGraphemes: maxGraphemes!)
        : data;
    return Text(
      display,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      softWrap: softWrap,
      textWidthBasis: textWidthBasis,
      strutStyle: strutStyle,
      semanticsLabel: semanticsLabel ?? data,
      textDirection: resolveUserTextDirection(display),
    );
  }
}
