import 'package:flutter/material.dart';

/// The Hisab app mark.
///
/// Onboarding and the invite QR each reached for `assets/Hisab.png` with their
/// own rounding. Keeping the radius proportional here means the mark reads the
/// same whether it is 40px in a sheet header or 76px on the welcome screen.
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.26),
      child: Image.asset(
        'assets/Hisab.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        // The app name is always spelled out beside the mark, so announcing it
        // again would just repeat the heading.
        excludeFromSemantics: true,
      ),
    );
  }
}
