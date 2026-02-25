import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'app_theme.dart';
import 'experiment_styles.dart';
import '../../features/settings/providers/settings_framework_providers.dart';

part 'theme_providers.g.dart';

/// Experiment: cycle through 6 app styles (Default + 5 Material 3). In memory only.
final experimentStyleIndexProvider = StateProvider<int>((ref) => 0);

const _experimentStyleNames = [
  'Default',
  'Finance Professional',
  'Playful Bubble',
  'Elevated Surface',
  'Tech Utility',
  'Editorial List',
];

/// Returns the display name for the experiment style at [index]. Used in AppBar subtitle and toast.
String experimentStyleNameAt(int index) {
  if (index < 0 || index >= _experimentStyleNames.length) return 'Default';
  return _experimentStyleNames[index];
}

/// Holds both light and dark themes. Built once per theme-setting change.
class AppThemes {
  final ThemeData light;
  final ThemeData dark;

  const AppThemes({required this.light, required this.dark});
}

/// Theme data provider. Rebuilds when themeMode, themeColor, fontSizeScale, or experiment style index change.
@riverpod
AppThemes appThemes(Ref ref) {
  final experimentIndex = ref.watch(experimentStyleIndexProvider);
  final themeModeValue = ref.watch(themeModeProvider);
  final themeColorValue = ref.watch(themeColorProvider);
  final fontSizeScaleValue = ref.watch(fontSizeScaleProvider);

  final themeColor = Color(themeColorValue);
  final fontSizeScale = fontSizeScaleValue;

  // Index 0 = Default: use existing app theme from settings.
  if (experimentIndex == 0) {
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
  }

  // Indices 1..5: per-style Material 3 themes.
  final result = ExperimentStyles.buildThemes(
    styleIndex: experimentIndex,
    themeMode: themeModeValue,
    fontSizeScale: fontSizeScaleValue,
  );
  return AppThemes(light: result.light, dark: result.dark);
}

/// ThemeMode for MaterialApp. Separate so locale changes don't trigger theme rebuild.
@riverpod
ThemeMode appThemeMode(Ref ref) {
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
}
