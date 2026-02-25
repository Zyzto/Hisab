import 'package:flutter/material.dart';
import 'theme_config.dart';
import 'theme_extensions.dart';

/// Central theme factory for the Hisab app (Material 3).
class AppTheme {
  AppTheme._();

  static ThemeData _buildThemeData<T extends ThemeExtension<T>>({
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required Color dividerColor,
    required Color outlineColor,
    required Color errorColor,
    required Color iconColor,
    required T extension,
    required Color primarySeed,
  }) {
    return ThemeData(
      useMaterial3: true,
      textTheme: textTheme,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: ThemeConfig.appBarCenterTitle,
        elevation: ThemeConfig.appBarElevation,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: ThemeConfig.cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeConfig.cardBorderRadius),
        ),
        color: colorScheme.surface,
      ),
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: ThemeConfig.dividerThickness,
        space: ThemeConfig.dividerSpacing,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeConfig.inputBorderRadius),
          borderSide: BorderSide(
            color: outlineColor,
            width: ThemeConfig.inputDefaultBorderWidth,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeConfig.inputBorderRadius),
          borderSide: BorderSide(
            color: outlineColor,
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
            color: errorColor,
            width: ThemeConfig.inputDefaultBorderWidth,
          ),
        ),
      ),
      iconTheme: IconThemeData(color: iconColor),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(color: colorScheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeConfig.radiusM),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      extensions: [extension],
    );
  }

  static TextTheme _scaleTextTheme(
    TextTheme baseTextTheme,
    double scaleFactor,
  ) {
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

  static ThemeData lightTheme({Color? seedColor, String? fontSizeScale}) {
    final baseSeedColor = seedColor ?? ThemeConfig.defaultSeedColor;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: baseSeedColor,
      brightness: Brightness.light,
    ).copyWith(
      surface: ThemeConfig.lightSurface,
      surfaceContainerHighest: ThemeConfig.lightSurfaceContainerHighest,
      onSurface: ThemeConfig.lightOnSurface,
      onSurfaceVariant: ThemeConfig.lightOnSurfaceVariant,
      outline: ThemeConfig.lightOutline,
      outlineVariant: ThemeConfig.lightOutlineVariant,
      primary: baseSeedColor,
      onPrimary: Colors.white,
      secondary: baseSeedColor.withValues(alpha: 0.8),
      onSecondary: Colors.white,
      error: ThemeConfig.lightError,
      onError: Colors.white,
    );
    final textScaleFactor = ThemeConfig.getTextScaleFactor(fontSizeScale);
    final textTheme = _scaleTextTheme(
      ThemeData.light().textTheme,
      textScaleFactor,
    );
    return _buildThemeData(
      colorScheme: colorScheme,
      textTheme: textTheme,
      dividerColor: ThemeConfig.lightDivider,
      outlineColor: ThemeConfig.lightOutline,
      errorColor: ThemeConfig.lightError,
      iconColor: ThemeConfig.lightIcon,
      extension: AppThemeExtension.light,
      primarySeed: baseSeedColor,
    );
  }

  static ThemeData darkTheme({Color? seedColor, String? fontSizeScale}) {
    final baseSeedColor = seedColor ?? ThemeConfig.defaultSeedColor;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: baseSeedColor,
      brightness: Brightness.dark,
    ).copyWith(
      surface: ThemeConfig.darkSurface,
      surfaceContainerHighest: ThemeConfig.darkSurfaceContainerHighest,
      onSurface: ThemeConfig.darkOnSurface,
      onSurfaceVariant: ThemeConfig.darkOnSurfaceVariant,
      outline: ThemeConfig.darkOutline,
      outlineVariant: ThemeConfig.darkOutlineVariant,
      primary: baseSeedColor,
      onPrimary: Colors.white,
      secondary: baseSeedColor.withValues(alpha: 0.8),
      onSecondary: Colors.white,
      error: ThemeConfig.darkError,
      onError: Colors.white,
    );
    final textScaleFactor = ThemeConfig.getTextScaleFactor(fontSizeScale);
    final textTheme = _scaleTextTheme(
      ThemeData.dark().textTheme,
      textScaleFactor,
    );
    return _buildThemeData(
      colorScheme: colorScheme,
      textTheme: textTheme,
      dividerColor: ThemeConfig.darkDivider,
      outlineColor: ThemeConfig.darkOutline,
      errorColor: ThemeConfig.darkError,
      iconColor: ThemeConfig.darkIcon,
      extension: AppThemeExtension.dark,
      primarySeed: baseSeedColor,
    );
  }

  static ThemeData amoledTheme({Color? seedColor, String? fontSizeScale}) {
    final baseSeedColor = seedColor ?? ThemeConfig.defaultSeedColor;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: baseSeedColor,
      brightness: Brightness.dark,
    ).copyWith(
      surface: ThemeConfig.amoledSurface,
      surfaceContainerHighest: ThemeConfig.amoledSurfaceContainerHighest,
      onSurface: ThemeConfig.amoledOnSurface,
      onSurfaceVariant: ThemeConfig.amoledOnSurfaceVariant,
      outline: ThemeConfig.amoledOutline,
      outlineVariant: ThemeConfig.amoledOutlineVariant,
      primary: baseSeedColor,
      onPrimary: Colors.white,
      secondary: baseSeedColor.withValues(alpha: 0.8),
      onSecondary: Colors.white,
      error: ThemeConfig.amoledError,
      onError: Colors.white,
    );
    final textScaleFactor = ThemeConfig.getTextScaleFactor(fontSizeScale);
    final textTheme = _scaleTextTheme(
      ThemeData.dark().textTheme,
      textScaleFactor,
    );
    return _buildThemeData(
      colorScheme: colorScheme,
      textTheme: textTheme,
      dividerColor: ThemeConfig.amoledDivider,
      outlineColor: ThemeConfig.amoledOutline,
      errorColor: ThemeConfig.amoledError,
      iconColor: ThemeConfig.amoledIcon,
      extension: AppThemeExtension.dark,
      primarySeed: baseSeedColor,
    );
  }
}
