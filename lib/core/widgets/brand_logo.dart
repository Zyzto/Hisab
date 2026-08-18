import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Third-party brand marks used on the OAuth buttons.
enum BrandMark { google, github }

/// Renders an identity provider's official mark.
///
/// Google's mark keeps its four brand colours in every theme — recolouring it
/// breaks Google's branding terms. GitHub's mark is monochrome, so it is tinted
/// to [ColorScheme.onSurface] to stay legible on both light and dark surfaces.
class BrandLogo extends StatelessWidget {
  const BrandLogo(this.mark, {super.key, this.size = 20});

  const BrandLogo.google({super.key, this.size = 20}) : mark = BrandMark.google;

  const BrandLogo.github({super.key, this.size = 20}) : mark = BrandMark.github;

  final BrandMark mark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = switch (mark) {
      BrandMark.google => 'assets/icons/google.svg',
      BrandMark.github => 'assets/icons/github.svg',
    };
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: mark == BrandMark.github
          ? ColorFilter.mode(
              Theme.of(context).colorScheme.onSurface,
              BlendMode.srcIn,
            )
          : null,
      // Brand names are not translated, so the mark carries the label.
      excludeFromSemantics: true,
    );
  }
}
