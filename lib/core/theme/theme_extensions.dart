import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'theme_config.dart';

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final double spacingXS;
  final double spacingS;
  final double spacingM;
  final double spacingL;
  final double spacingXL;
  final double spacingXXL;
  final double radiusS;
  final double radiusM;
  final double radiusL;
  final double radiusXL;
  final double radiusXXL;
  final Duration animationShort;
  final Duration animationMedium;
  final Duration animationLong;

  const AppThemeExtension({
    required this.spacingXS,
    required this.spacingS,
    required this.spacingM,
    required this.spacingL,
    required this.spacingXL,
    required this.spacingXXL,
    required this.radiusS,
    required this.radiusM,
    required this.radiusL,
    required this.radiusXL,
    required this.radiusXXL,
    required this.animationShort,
    required this.animationMedium,
    required this.animationLong,
  });

  static const AppThemeExtension light = AppThemeExtension(
    spacingXS: ThemeConfig.spacingXS,
    spacingS: ThemeConfig.spacingS,
    spacingM: ThemeConfig.spacingM,
    spacingL: ThemeConfig.spacingL,
    spacingXL: ThemeConfig.spacingXL,
    spacingXXL: ThemeConfig.spacingXXL,
    radiusS: ThemeConfig.radiusS,
    radiusM: ThemeConfig.radiusM,
    radiusL: ThemeConfig.radiusL,
    radiusXL: ThemeConfig.radiusXL,
    radiusXXL: ThemeConfig.radiusXXL,
    animationShort: ThemeConfig.animationShort,
    animationMedium: ThemeConfig.animationMedium,
    animationLong: ThemeConfig.animationLong,
  );

  static const AppThemeExtension dark = AppThemeExtension(
    spacingXS: ThemeConfig.spacingXS,
    spacingS: ThemeConfig.spacingS,
    spacingM: ThemeConfig.spacingM,
    spacingL: ThemeConfig.spacingL,
    spacingXL: ThemeConfig.spacingXL,
    spacingXXL: ThemeConfig.spacingXXL,
    radiusS: ThemeConfig.radiusS,
    radiusM: ThemeConfig.radiusM,
    radiusL: ThemeConfig.radiusL,
    radiusXL: ThemeConfig.radiusXL,
    radiusXXL: ThemeConfig.radiusXXL,
    animationShort: ThemeConfig.animationShort,
    animationMedium: ThemeConfig.animationMedium,
    animationLong: ThemeConfig.animationLong,
  );

  @override
  AppThemeExtension copyWith({
    double? spacingXS,
    double? spacingS,
    double? spacingM,
    double? spacingL,
    double? spacingXL,
    double? spacingXXL,
    double? radiusS,
    double? radiusM,
    double? radiusL,
    double? radiusXL,
    double? radiusXXL,
    Duration? animationShort,
    Duration? animationMedium,
    Duration? animationLong,
  }) {
    return AppThemeExtension(
      spacingXS: spacingXS ?? this.spacingXS,
      spacingS: spacingS ?? this.spacingS,
      spacingM: spacingM ?? this.spacingM,
      spacingL: spacingL ?? this.spacingL,
      spacingXL: spacingXL ?? this.spacingXL,
      spacingXXL: spacingXXL ?? this.spacingXXL,
      radiusS: radiusS ?? this.radiusS,
      radiusM: radiusM ?? this.radiusM,
      radiusL: radiusL ?? this.radiusL,
      radiusXL: radiusXL ?? this.radiusXL,
      radiusXXL: radiusXXL ?? this.radiusXXL,
      animationShort: animationShort ?? this.animationShort,
      animationMedium: animationMedium ?? this.animationMedium,
      animationLong: animationLong ?? this.animationLong,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      spacingXS: lerpDouble(spacingXS, other.spacingXS, t) ?? spacingXS,
      spacingS: lerpDouble(spacingS, other.spacingS, t) ?? spacingS,
      spacingM: lerpDouble(spacingM, other.spacingM, t) ?? spacingM,
      spacingL: lerpDouble(spacingL, other.spacingL, t) ?? spacingL,
      spacingXL: lerpDouble(spacingXL, other.spacingXL, t) ?? spacingXL,
      spacingXXL: lerpDouble(spacingXXL, other.spacingXXL, t) ?? spacingXXL,
      radiusS: lerpDouble(radiusS, other.radiusS, t) ?? radiusS,
      radiusM: lerpDouble(radiusM, other.radiusM, t) ?? radiusM,
      radiusL: lerpDouble(radiusL, other.radiusL, t) ?? radiusL,
      radiusXL: lerpDouble(radiusXL, other.radiusXL, t) ?? radiusXL,
      radiusXXL: lerpDouble(radiusXXL, other.radiusXXL, t) ?? radiusXXL,
      animationShort: Duration(
        milliseconds:
            lerpDouble(
              animationShort.inMilliseconds.toDouble(),
              other.animationShort.inMilliseconds.toDouble(),
              t,
            )?.toInt() ??
            animationShort.inMilliseconds,
      ),
      animationMedium: Duration(
        milliseconds:
            lerpDouble(
              animationMedium.inMilliseconds.toDouble(),
              other.animationMedium.inMilliseconds.toDouble(),
              t,
            )?.toInt() ??
            animationMedium.inMilliseconds,
      ),
      animationLong: Duration(
        milliseconds:
            lerpDouble(
              animationLong.inMilliseconds.toDouble(),
              other.animationLong.inMilliseconds.toDouble(),
              t,
            )?.toInt() ??
            animationLong.inMilliseconds,
      ),
    );
  }
}

extension AppThemeExtensionContext on BuildContext {
  AppThemeExtension? get appTheme =>
      Theme.of(this).extension<AppThemeExtension>();
}
