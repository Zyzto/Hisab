import 'package:flutter/material.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

final generalSection = const SettingSection(
  key: 'general',
  titleKey: 'general',
  icon: Icons.settings,
  order: 0,
  initiallyExpanded: true,
);

final appearanceSection = const SettingSection(
  key: 'appearance',
  titleKey: 'appearance',
  icon: Icons.palette,
  order: 1,
);

final dataSection = const SettingSection(
  key: 'data',
  titleKey: 'data',
  icon: Icons.storage,
  order: 2,
);

final themeModeSettingDef = const EnumSetting(
  'theme_mode',
  defaultValue: 'system',
  titleKey: 'theme',
  options: ['system', 'light', 'dark', 'amoled'],
  optionLabels: {
    'system': 'system',
    'light': 'light',
    'dark': 'dark',
    'amoled': 'amoled',
  },
  icon: Icons.dark_mode,
  section: 'general',
  order: 0,
);

final themeColorSettingDef = const ColorSetting(
  'theme_color',
  defaultValue: 0xFF2E7D32,
  titleKey: 'select_theme_color',
  icon: Icons.palette,
  section: 'general',
  order: 1,
);

final languageSettingDef = const EnumSetting(
  'language',
  defaultValue: 'en',
  titleKey: 'language',
  options: ['en', 'ar'],
  optionLabels: {'en': 'English', 'ar': 'العربية'},
  icon: Icons.language,
  section: 'general',
  order: 2,
);

final fontSizeScaleSettingDef = const EnumSetting(
  'font_size_scale',
  defaultValue: 'normal',
  titleKey: 'font_size',
  options: ['small', 'normal', 'large', 'extra_large'],
  optionLabels: {
    'small': 'small',
    'normal': 'normal',
    'large': 'large',
    'extra_large': 'extra_large',
  },
  icon: Icons.text_fields,
  section: 'appearance',
  order: 0,
);

/// When true, app uses only local storage (Drift). When false, uses Convex.
final localOnlySettingDef = const BoolSetting(
  'local_only',
  defaultValue: true,
  titleKey: 'local_only',
  icon: Icons.storage,
  section: 'data',
  order: 0,
);

final allSections = [generalSection, appearanceSection, dataSection];

final allSettings = <SettingDefinition>[
  themeModeSettingDef,
  themeColorSettingDef,
  languageSettingDef,
  fontSizeScaleSettingDef,
  localOnlySettingDef,
];

SettingsRegistry createHisabSettingsRegistry() {
  return SettingsRegistry.withSettings(
    sections: allSections,
    settings: allSettings,
  );
}
