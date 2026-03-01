import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_config.dart';
import 'theme_extensions.dart';

/// Curated [FlexScheme] enum names shown in settings, plus "custom".
/// Order and selection can be changed here.
const List<String> flexSchemeOptionIds = [
  'green',
  'blue',
  'tealM3',
  'indigo',
  'mandyRed',
  'red',
  'purpleBrown',
  'deepPurple',
  'amber',
  'custom',
];

/// Default theme scheme (closest to legacy default green 0xFF2E7D32).
const String defaultThemeSchemeId = 'green';

/// Primary color for a scheme id (for settings preview chips). Returns transparent for "custom".
Color primaryColorForSchemeId(String schemeId) {
  if (schemeId == 'custom') return Colors.transparent;
  try {
    final scheme = FlexScheme.values.byName(schemeId);
    return FlexThemeData.light(scheme: scheme).colorScheme.primary;
  } catch (_) {
    return Colors.grey;
  }
}

/// Builds light and dark [ThemeData] using FlexColorScheme.
/// Supports predefined [FlexScheme] by name or custom seed color.
class FlexThemeBuilder {
  FlexThemeBuilder._();

  static TextTheme _scaleTextTheme(TextTheme baseTextTheme, double scaleFactor) {
    return TextTheme(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontSize: (baseTextTheme.displayLarge?.fontSize ?? 57) * scaleFactor,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontSize: (baseTextTheme.displayMedium?.fontSize ?? 45) * scaleFactor,
      ),
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        fontSize: (baseTextTheme.displaySmall?.fontSize ?? 36) * scaleFactor,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontSize: (baseTextTheme.headlineLarge?.fontSize ?? 32) * scaleFactor,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontSize: (baseTextTheme.headlineMedium?.fontSize ?? 28) * scaleFactor,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontSize: (baseTextTheme.headlineSmall?.fontSize ?? 24) * scaleFactor,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontSize: (baseTextTheme.titleLarge?.fontSize ?? 22) * scaleFactor,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontSize: (baseTextTheme.titleMedium?.fontSize ?? 16) * scaleFactor,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontSize: (baseTextTheme.titleSmall?.fontSize ?? 14) * scaleFactor,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontSize: (baseTextTheme.bodyLarge?.fontSize ?? 16) * scaleFactor,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontSize: (baseTextTheme.bodyMedium?.fontSize ?? 14) * scaleFactor,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontSize: (baseTextTheme.bodySmall?.fontSize ?? 12) * scaleFactor,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontSize: (baseTextTheme.labelLarge?.fontSize ?? 14) * scaleFactor,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontSize: (baseTextTheme.labelMedium?.fontSize ?? 12) * scaleFactor,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontSize: (baseTextTheme.labelSmall?.fontSize ?? 11) * scaleFactor,
      ),
    );
  }

  static ThemeData _applyAppOverrides(
    ThemeData theme,
    Brightness brightness, {
    required bool alwaysShowScrollbars,
    required double scaleFactor,
  }) {
    // Override light surfaces to match previous app look (white / light grey).
    final colorScheme = brightness == Brightness.light
        ? theme.colorScheme.copyWith(
            surface: ThemeConfig.lightSurface,
            surfaceContainerHighest: ThemeConfig.lightSurfaceContainerHighest,
            onSurface: ThemeConfig.lightOnSurface,
            onSurfaceVariant: ThemeConfig.lightOnSurfaceVariant,
            outline: ThemeConfig.lightOutline,
            outlineVariant: ThemeConfig.lightOutlineVariant,
          )
        : theme.colorScheme;
    final primarySeed = colorScheme.primary;
    final exts = List<ThemeExtension<dynamic>>.from(
      theme.extensions.values.where((e) => e is! AppThemeExtension),
    );
    exts.add(
      brightness == Brightness.light ? AppThemeExtension.light : AppThemeExtension.dark,
    );
    return theme.copyWith(
      colorScheme: colorScheme,
      extensions: exts,
      textTheme: _scaleTextTheme(
        GoogleFonts.cairoTextTheme(theme.textTheme),
        scaleFactor,
      ),
      scrollbarTheme: alwaysShowScrollbars
          ? ScrollbarThemeData(
              thumbVisibility: WidgetStateProperty.all(true),
              trackVisibility: WidgetStateProperty.all(true),
            )
          : theme.scrollbarTheme,
      appBarTheme: AppBarTheme(
        centerTitle: ThemeConfig.appBarCenterTitle,
        elevation: ThemeConfig.appBarElevation,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: ThemeConfig.elevationNone,
        shadowColor: colorScheme.brightness == Brightness.dark
            ? Colors.black.withValues(alpha: 0.45)
            : colorScheme.shadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeConfig.cardBorderRadius),
          side: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        color: colorScheme.surfaceContainerHighest,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: ThemeConfig.dividerThickness,
        space: ThemeConfig.dividerSpacing,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeConfig.inputBorderRadius),
          borderSide: BorderSide(
            color: colorScheme.outline,
            width: ThemeConfig.inputDefaultBorderWidth,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeConfig.inputBorderRadius),
          borderSide: BorderSide(
            color: colorScheme.outline,
            width: ThemeConfig.inputDefaultBorderWidth,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeConfig.inputBorderRadius),
          borderSide: BorderSide(
            color: primarySeed,
            width: ThemeConfig.inputFocusedBorderWidth,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeConfig.inputBorderRadius),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: ThemeConfig.inputDefaultBorderWidth,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(color: colorScheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeConfig.radiusM),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Builds light theme. [themeScheme] is a [FlexScheme] enum name or "custom".
  /// When "custom", [themeColorValue] is used as seed (int, e.g. 0xFF2E7D32).
  static ThemeData light({
    required String themeScheme,
    required int themeColorValue,
    String? fontSizeScale,
    bool alwaysShowScrollbars = false,
  }) {
    final scaleFactor = ThemeConfig.getTextScaleFactor(fontSizeScale);
    final ThemeData baseTheme;
    if (themeScheme == 'custom') {
      final seedColor = Color(themeColorValue);
      baseTheme = FlexThemeData.light(
        colors: FlexSchemeColor.from(primary: seedColor),
        keyColors: FlexKeyColors(keyPrimary: seedColor),
      );
    } else {
      final scheme = FlexScheme.values.byName(themeScheme);
      baseTheme = FlexThemeData.light(scheme: scheme);
    }
    return _applyAppOverrides(
      baseTheme,
      Brightness.light,
      alwaysShowScrollbars: alwaysShowScrollbars,
      scaleFactor: scaleFactor,
    );
  }

  /// Builds dark theme. [amoled] when true uses pure black surfaces.
  static ThemeData dark({
    required String themeScheme,
    required int themeColorValue,
    String? fontSizeScale,
    bool alwaysShowScrollbars = false,
    bool amoled = false,
  }) {
    final scaleFactor = ThemeConfig.getTextScaleFactor(fontSizeScale);
    final ThemeData baseTheme;
    if (themeScheme == 'custom') {
      final seedColor = Color(themeColorValue);
      baseTheme = FlexThemeData.dark(
        colors: FlexSchemeColor.from(primary: seedColor),
        keyColors: FlexKeyColors(keyPrimary: seedColor),
        darkIsTrueBlack: amoled,
      );
    } else {
      final scheme = FlexScheme.values.byName(themeScheme);
      baseTheme = FlexThemeData.dark(
        scheme: scheme,
        darkIsTrueBlack: amoled,
      );
    }
    return _applyAppOverrides(
      baseTheme,
      Brightness.dark,
      alwaysShowScrollbars: alwaysShowScrollbars,
      scaleFactor: scaleFactor,
    );
  }
}
