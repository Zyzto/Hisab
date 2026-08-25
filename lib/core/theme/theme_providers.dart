import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'accent_style.dart';
import 'experiment_styles.dart';
import 'flex_theme_builder.dart';
import '../debug/debug_menu.dart';
import '../settings/providers/settings_framework_providers.dart';

part 'theme_providers.g.dart';

/// Experiment: cycle through 6 app styles (Default + 5 Material 3). In memory only.
/// Active only when [showDebugMenuProvider] is true (debug / Hisab Debug).
final experimentStyleIndexProvider = StateProvider<int>((ref) => 0);

/// When true, [MaterialApp] skips the implicit theme tween so a circular
/// reveal can switch palettes in one frame.
final suppressThemeLerpProvider = StateProvider<bool>((ref) => false);

/// Effective style index: always 0 outside debug / Hisab Debug builds.
final effectiveExperimentStyleIndexProvider = Provider<int>((ref) {
  if (!ref.watch(showDebugMenuProvider)) return 0;
  return ref.watch(experimentStyleIndexProvider);
});

const _experimentStyleKeys = [
  'theme_style_default',
  'theme_style_finance_professional',
  'theme_style_playful_bubble',
  'theme_style_elevated_surface',
  'theme_style_tech_utility',
  'theme_style_editorial_list',
];

/// Returns the localized display name for the experiment style at [index].
String experimentStyleNameAt(int index) {
  if (index < 0 || index >= _experimentStyleKeys.length) {
    return 'theme_style_default'.tr();
  }
  return _experimentStyleKeys[index].tr();
}

/// Holds both light and dark themes. Built once per theme-setting change.
class AppThemes {
  final ThemeData light;
  final ThemeData dark;

  const AppThemes({required this.light, required this.dark});
}

/// Theme data provider. Rebuilds when themeMode, themeScheme, themeColor,
/// fontSizeScale, subtleAccents, or experiment style index change.
@riverpod
AppThemes appThemes(Ref ref) {
  final experimentIndex = ref.watch(effectiveExperimentStyleIndexProvider);
  final themeModeValue = ref.watch(themeModeProvider);
  final themeSchemeValue = ref.watch(themeSchemeProvider);
  final themeColorValue = ref.watch(themeColorProvider);
  final fontSizeScaleValue = ref.watch(fontSizeScaleProvider);
  final subtleAccentsValue = ref.watch(subtleAccentsProvider);

  // Index 0 = Default: use FlexColorScheme-based theme from settings.
  if (experimentIndex == 0) {
    final lightTheme = withAccentStyle(
      FlexThemeBuilder.light(
        themeScheme: themeSchemeValue,
        themeColorValue: themeColorValue,
        fontSizeScale: fontSizeScaleValue,
        alwaysShowScrollbars: kIsWeb,
      ),
      subtleAccents: subtleAccentsValue,
    );
    final darkTheme = withAccentStyle(
      FlexThemeBuilder.dark(
        themeScheme: themeSchemeValue,
        themeColorValue: themeColorValue,
        fontSizeScale: fontSizeScaleValue,
        alwaysShowScrollbars: kIsWeb,
        amoled: themeModeValue == 'amoled',
      ),
      subtleAccents: subtleAccentsValue,
    );
    return AppThemes(light: lightTheme, dark: darkTheme);
  }

  // Indices 1..5: per-style Material 3 themes.
  final result = ExperimentStyles.buildThemes(
    styleIndex: experimentIndex,
    themeMode: themeModeValue,
    fontSizeScale: fontSizeScaleValue,
  );
  return AppThemes(
    light: withAccentStyle(result.light, subtleAccents: subtleAccentsValue),
    dark: withAccentStyle(result.dark, subtleAccents: subtleAccentsValue),
  );
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
