import 'package:flutter/material.dart';

/// Pre-formatted money string with forced LTR so number/currency order stays
/// stable inside RTL UI shells.
///
/// Prefer this over a bare [Text] for [CurrencyFormatter] output. This file
/// must not import `easy_localization` (intl's [TextDirection] would shadow
/// Flutter's and break `.ltr`).
class AmountText extends StatelessWidget {
  const AmountText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
  });

  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      softWrap: softWrap,
      textDirection: TextDirection.ltr,
    );
  }
}
