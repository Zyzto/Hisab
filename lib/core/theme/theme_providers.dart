import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'experiment_styles.dart';
import 'flex_theme_builder.dart';
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

/// Theme data provider. Rebuilds when themeMode, themeScheme, themeColor, fontSizeScale, or experiment style index change.
@riverpod
AppThemes appThemes(Ref ref) {
  final experimentIndex = ref.watch(experimentStyleIndexProvider);
  final themeModeValue = ref.watch(themeModeProvider);
  final themeSchemeValue = ref.watch(themeSchemeProvider);
  final themeColorValue = ref.watch(themeColorProvider);
  final fontSizeScaleValue = ref.watch(fontSizeScaleProvider);

  // Index 0 = Default: use FlexColorScheme-based theme from settings.
  if (experimentIndex == 0) {
    final lightTheme = FlexThemeBuilder.light(
      themeScheme: themeSchemeValue,
      themeColorValue: themeColorValue,
      fontSizeScale: fontSizeScaleValue,
      alwaysShowScrollbars: kIsWeb,
    );
    final darkTheme = FlexThemeBuilder.dark(
      themeScheme: themeSchemeValue,
      themeColorValue: themeColorValue,
      fontSizeScale: fontSizeScaleValue,
      alwaysShowScrollbars: kIsWeb,
      amoled: themeModeValue == 'amoled',
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
