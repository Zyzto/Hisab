import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';
import '../../features/settings/providers/settings_framework_providers.dart';

/// Holds both light and dark themes. Built once per theme-setting change.
class AppThemes {
  final ThemeData light;
  final ThemeData dark;

  const AppThemes({required this.light, required this.dark});
}

/// Theme data provider. Rebuilds only when themeMode, themeColor, or fontSizeScale change.
final appThemesProvider = Provider<AppThemes>((ref) {
  final themeModeValue = ref.watch(themeModeProvider);
  final themeColorValue = ref.watch(themeColorProvider);
  final fontSizeScaleValue = ref.watch(fontSizeScaleProvider);

  final themeColor = Color(themeColorValue);
  final fontSizeScale = fontSizeScaleValue;

  final lightTheme = AppTheme.lightTheme(
    seedColor: themeColor,
    fontSizeScale: fontSizeScale,
  );
  final darkTheme = themeModeValue == 'amoled'
      ? AppTheme.amoledTheme(
          seedColor: themeColor,
          fontSizeScale: fontSizeScale,
        )
      : AppTheme.darkTheme(
          seedColor: themeColor,
          fontSizeScale: fontSizeScale,
        );

  return AppThemes(light: lightTheme, dark: darkTheme);
});

/// ThemeMode for MaterialApp. Separate so locale changes don't trigger theme rebuild.
final appThemeModeProvider = Provider<ThemeMode>((ref) {
  final value = ref.watch(themeModeProvider);
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
    case 'amoled':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
});
