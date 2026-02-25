import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'theme_config.dart';

/// Light and dark themes for an experiment style. Convert to [AppThemes] in theme_providers.
class ExperimentThemesResult {
  const ExperimentThemesResult({required this.light, required this.dark});
  final ThemeData light;
  final ThemeData dark;
}

/// Builds ThemeData for experiment styles 1..5 (Material 3 specs).
/// Index 0 (Default) is handled in theme_providers with existing app theme.
class ExperimentStyles {
  ExperimentStyles._();

  static const _seedColors = [
    Color(0xFF1A237E), // 1 Finance Professional – Navy
    Color(0xFF00897B), // 2 Playful Bubble – Teal
    Color(0xFF5C6BC0), // 3 Elevated Surface – pastel-ish
    Color(0xFF00E676), // 4 Tech Utility – Neon Lime accent (scheme uses this as seed)
    Color(0xFF6D4C41), // 5 Editorial List – Brown / earth
  ];

  /// Returns light and dark (or amoled) themes for the given experiment style index (1..5).
  static ExperimentThemesResult buildThemes({
    required int styleIndex,
    required String themeMode,
    required String? fontSizeScale,
  }) {
    if (styleIndex < 1 || styleIndex > 5) {
      return ExperimentThemesResult(
        light: AppTheme.lightTheme(fontSizeScale: fontSizeScale),
        dark: themeMode == 'amoled'
            ? AppTheme.amoledTheme(fontSizeScale: fontSizeScale)
            : AppTheme.darkTheme(fontSizeScale: fontSizeScale),
      );
    }

    final seedColor = _seedColors[styleIndex - 1];
    final scale = ThemeConfig.getTextScaleFactor(fontSizeScale);

    final lightTheme = _buildStyleTheme(
      styleIndex: styleIndex,
      brightness: Brightness.light,
      seedColor: seedColor,
      scale: scale,
    );
    final darkTheme = themeMode == 'amoled'
        ? _buildStyleTheme(
            styleIndex: styleIndex,
            brightness: Brightness.dark,
            seedColor: seedColor,
            scale: scale,
            amoled: true,
          )
        : _buildStyleTheme(
            styleIndex: styleIndex,
            brightness: Brightness.dark,
            seedColor: seedColor,
            scale: scale,
          );

    return ExperimentThemesResult(light: lightTheme, dark: darkTheme);
  }

  static ThemeData _buildStyleTheme({
    required int styleIndex,
    required Brightness brightness,
    required Color seedColor,
    required double scale,
    bool amoled = false,
  }) {
    final base = brightness == Brightness.light
        ? AppTheme.lightTheme(seedColor: seedColor, fontSizeScale: null)
        : amoled
            ? AppTheme.amoledTheme(seedColor: seedColor, fontSizeScale: null)
            : AppTheme.darkTheme(seedColor: seedColor, fontSizeScale: null);

    final textTheme = _textThemeForStyle(styleIndex, brightness);
    final scaledTextTheme = _scaleTextTheme(textTheme, scale);

    CardThemeData cardTheme = base.cardTheme;
    switch (styleIndex) {
      case 1: // Finance Professional: outlined, radius 8–12
        cardTheme = base.cardTheme.copyWith(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: base.colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          elevation: 0,
          color: Colors.transparent,
        );
        break;
      case 2: // Playful Bubble: filled, radius 24–28
        cardTheme = base.cardTheme.copyWith(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: BorderSide.none,
          ),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        );
        break;
      case 3: // Elevated Surface: elevation 2–3, radius 16
        cardTheme = base.cardTheme.copyWith(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide.none,
          ),
          elevation: 3,
          surfaceTintColor: Colors.transparent,
        );
        break;
      case 4: // Tech Utility: radius 4, dark card
        cardTheme = base.cardTheme.copyWith(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide.none,
          ),
          elevation: 0,
          color: base.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
        );
        break;
      case 5: // Editorial List: radius 0 or 4
        cardTheme = base.cardTheme.copyWith(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide.none,
          ),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        );
        break;
    }

    return base.copyWith(
      textTheme: scaledTextTheme,
      cardTheme: cardTheme,
    );
  }

  static TextTheme _textThemeForStyle(int styleIndex, Brightness brightness) {
    final base = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;
    switch (styleIndex) {
      case 1:
        return GoogleFonts.tajawalTextTheme(base);
      case 2:
        return GoogleFonts.almaraiTextTheme(base);
      case 3:
        return GoogleFonts.cairoTextTheme(base);
      case 4:
        return GoogleFonts.changaTextTheme(base);
      case 5:
        return GoogleFonts.amiriTextTheme(base);
      default:
        return GoogleFonts.cairoTextTheme(base);
    }
  }

  static TextTheme _scaleTextTheme(TextTheme base, double scale) {
    return TextTheme(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: (base.displayLarge?.fontSize ?? 57) * scale,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: (base.displayMedium?.fontSize ?? 45) * scale,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: (base.displaySmall?.fontSize ?? 36) * scale,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: (base.headlineLarge?.fontSize ?? 32) * scale,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: (base.headlineMedium?.fontSize ?? 28) * scale,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: (base.headlineSmall?.fontSize ?? 24) * scale,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: (base.titleLarge?.fontSize ?? 22) * scale,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: (base.titleMedium?.fontSize ?? 16) * scale,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: (base.titleSmall?.fontSize ?? 14) * scale,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: (base.bodyLarge?.fontSize ?? 16) * scale,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: (base.bodyMedium?.fontSize ?? 14) * scale,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: (base.bodySmall?.fontSize ?? 12) * scale,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: (base.labelLarge?.fontSize ?? 14) * scale,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: (base.labelMedium?.fontSize ?? 12) * scale,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: (base.labelSmall?.fontSize ?? 11) * scale,
      ),
    );
  }
}
