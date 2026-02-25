import 'package:flutter/material.dart';

/// Central theme configuration for the Hisab app.
class ThemeConfig {
  ThemeConfig._();

  static const double spacingUnit = 8.0;
  static const double spacingXS = spacingUnit * 0.5;
  static const double spacingS = spacingUnit;
  static const double spacingM = spacingUnit * 2;
  static const double spacingL = spacingUnit * 3;
  static const double spacingXL = spacingUnit * 4;
  static const double spacingXXL = spacingUnit * 6;

  static const double radiusS = 4.0;
  static const double radiusM = 8.0;
  static const double radiusL = 12.0;
  static const double radiusXL = 16.0;
  static const double radiusXXL = 24.0;

  static const double elevationNone = 0.0;
  static const double elevationLow = 1.0;
  static const double elevationMedium = 2.0;
  static const double elevationHigh = 4.0;
  static const double elevationVeryHigh = 8.0;

  static const double cardElevation = elevationNone;
  static const double cardBorderRadius = radiusL;

  static const double inputBorderRadius = radiusL;
  static const double inputFocusedBorderWidth = 2.0;
  static const double inputDefaultBorderWidth = 1.0;

  static const double dividerThickness = 1.0;
  static const double dividerSpacing = 1.0;

  static const double textScaleSmall = 0.85;
  static const double textScaleNormal = 1.0;
  static const double textScaleLarge = 1.15;
  static const double textScaleExtraLarge = 1.3;

  static const Color defaultSeedColor = Color(0xFF2E7D32);
  static const Color fallbackSeedColor = Colors.deepPurple;

  static const Color lightSurface = Colors.white;
  static const Color lightSurfaceContainerHighest = Color(0xFFF5F5F5);
  static const Color lightOnSurface = Color(0xFF212121);
  static const Color lightOnSurfaceVariant = Color(0xFF616161);
  static const Color lightOutline = Color(0xFFBDBDBD);
  static const Color lightOutlineVariant = Color(0xFFE0E0E0);
  static const Color lightError = Color(0xFFC62828);
  static const Color lightDivider = Color(0xFFE0E0E0);
  static const Color lightIcon = Color(0xFF424242);

  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceContainerHighest = Color(0xFF2D2D2D);
  static const Color darkOnSurface = Color(0xFFE0E0E0);
  static const Color darkOnSurfaceVariant = Color(0xFFBDBDBD);
  static const Color darkOutline = Color(0xFF5A5A5A);
  static const Color darkOutlineVariant = Color(0xFF4A4A4A);
  static const Color darkError = Color(0xFFE57373);
  static const Color darkDivider = Color(0xFF4A4A4A);
  static const Color darkIcon = Color(0xFFBDBDBD);

  static const Color amoledSurface = Color(0xFF000000);
  static const Color amoledSurfaceContainerHighest = Color(0xFF1A1A1A);
  static const Color amoledOnSurface = Color(0xFFFFFFFF);
  static const Color amoledOnSurfaceVariant = Color(0xFFE0E0E0);
  static const Color amoledOutline = Color(0xFF404040);
  static const Color amoledOutlineVariant = Color(0xFF2A2A2A);
  static const Color amoledError = Color(0xFFEF5350);
  static const Color amoledDivider = Color(0xFF2A2A2A);
  static const Color amoledIcon = Color(0xFFFFFFFF);

  static const Duration animationShort = Duration(milliseconds: 150);
  static const Duration animationMedium = Duration(milliseconds: 250);
  static const Duration animationLong = Duration(milliseconds: 350);

  static const double appBarElevation = elevationNone;
  static const bool appBarCenterTitle = true;

  static double getTextScaleFactor(String? fontSizeScale) {
    switch (fontSizeScale) {
      case 'small':
        return textScaleSmall;
      case 'normal':
        return textScaleNormal;
      case 'large':
        return textScaleLarge;
      case 'extra_large':
        return textScaleExtraLarge;
      default:
        return textScaleNormal;
    }
  }

  static double spacing(double multiplier) => spacingUnit * multiplier;
}
