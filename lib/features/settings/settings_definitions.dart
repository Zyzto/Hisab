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

final receiptAiSection = const SettingSection(
  key: 'receipt_ai',
  titleKey: 'receipt_ai_section',
  icon: Icons.receipt_long,
  order: 3,
);

final loggingSection = const SettingSection(
  key: 'logging',
  titleKey: 'logging',
  icon: Icons.description,
  order: 4,
);

/// When true, send anonymous usage data to telemetry endpoint. No-op if endpoint is empty.
final telemetryEnabledSettingDef = const BoolSetting(
  'telemetry_enabled',
  defaultValue: true,
  titleKey: 'telemetry_enabled',
  icon: Icons.analytics,
  section: 'logging',
  order: 0,
);

final backupSection = const SettingSection(
  key: 'backup',
  titleKey: 'backup',
  icon: Icons.backup,
  order: 5,
);

final aboutSection = const SettingSection(
  key: 'about',
  titleKey: 'about',
  icon: Icons.info,
  order: 6,
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

/// When true, run OCR on receipt images (and optionally AI). When false, only attach the picture.
final receiptOcrEnabledSettingDef = const BoolSetting(
  'receipt_ocr_enabled',
  defaultValue: true,
  titleKey: 'receipt_ocr_enabled',
  icon: Icons.document_scanner,
  section: 'receipt_ai',
  order: 0,
);

/// When true, use AI (Gemini/OpenAI) to extract receipt details from scanned image.
final receiptAiEnabledSettingDef = const BoolSetting(
  'receipt_ai_enabled',
  defaultValue: false,
  titleKey: 'receipt_ai_enabled',
  icon: Icons.auto_awesome,
  section: 'receipt_ai',
  order: 1,
);

/// Which LLM provider to use for receipt extraction.
final receiptAiProviderSettingDef = const EnumSetting(
  'receipt_ai_provider',
  defaultValue: 'none',
  titleKey: 'receipt_ai_provider',
  options: ['none', 'gemini', 'openai'],
  optionLabels: {
    'none': 'receipt_ai_provider_none',
    'gemini': 'receipt_ai_provider_gemini',
    'openai': 'receipt_ai_provider_openai',
  },
  icon: Icons.cloud,
  section: 'receipt_ai',
  order: 2,
);

/// Gemini API key (Google AI for Developers). Used when provider is gemini.
final geminiApiKeySettingDef = const StringSetting(
  'gemini_api_key',
  defaultValue: '',
  titleKey: 'gemini_api_key',
  icon: Icons.key,
  section: 'receipt_ai',
  order: 3,
);

/// OpenAI API key. Used when provider is openai.
final openaiApiKeySettingDef = const StringSetting(
  'openai_api_key',
  defaultValue: '',
  titleKey: 'openai_api_key',
  icon: Icons.key,
  section: 'receipt_ai',
  order: 4,
);

final allSections = [
  generalSection,
  appearanceSection,
  dataSection,
  receiptAiSection,
  loggingSection,
  backupSection,
  aboutSection,
];

final allSettings = <SettingDefinition>[
  themeModeSettingDef,
  themeColorSettingDef,
  languageSettingDef,
  fontSizeScaleSettingDef,
  localOnlySettingDef,
  receiptOcrEnabledSettingDef,
  receiptAiEnabledSettingDef,
  receiptAiProviderSettingDef,
  geminiApiKeySettingDef,
  openaiApiKeySettingDef,
  telemetryEnabledSettingDef,
];

SettingsRegistry createHisabSettingsRegistry() {
  return SettingsRegistry.withSettings(
    sections: allSections,
    settings: allSettings,
  );
}
