import 'package:flutter/material.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

final accountSection = const SettingSection(
  key: 'account',
  titleKey: 'account',
  icon: Icons.person,
  order: -1,
  initiallyExpanded: true,
);

/// Merged from old General + Appearance sections.
final appearanceSection = const SettingSection(
  key: 'appearance',
  titleKey: 'appearance',
  icon: Icons.palette,
  order: 0,
  initiallyExpanded: true,
);

/// Merged from old Data + Backup sections.
final dataBackupSection = const SettingSection(
  key: 'data_backup',
  titleKey: 'data_backup',
  icon: Icons.storage,
  order: 1,
);

final receiptAiSection = const SettingSection(
  key: 'receipt_ai',
  titleKey: 'receipt_ai_section',
  icon: Icons.receipt_long,
  order: 2,
);

/// Renamed from old Logging section.
final privacySection = const SettingSection(
  key: 'privacy',
  titleKey: 'privacy',
  icon: Icons.shield_outlined,
  order: 3,
);

/// When true, send anonymous usage data to telemetry endpoint. No-op if endpoint is empty.
final telemetryEnabledSettingDef = const BoolSetting(
  'telemetry_enabled',
  defaultValue: true,
  titleKey: 'telemetry_enabled',
  icon: Icons.analytics,
  section: 'privacy',
  order: 0,
);

/// When true, push notifications are active (FCM token registered).
/// When false, the token is unregistered and no push notifications are received.
final notificationsEnabledSettingDef = const BoolSetting(
  'notifications_enabled',
  defaultValue: true,
  titleKey: 'notifications_enabled',
  icon: Icons.notifications_outlined,
  section: 'privacy',
  order: 1,
);

final advancedSection = const SettingSection(
  key: 'advanced',
  titleKey: 'advanced',
  icon: Icons.build,
  order: 4,
);

final aboutSection = const SettingSection(
  key: 'about',
  titleKey: 'about',
  icon: Icons.info,
  order: 5,
);

/// When true, after taking a screenshot the app prompts to send feedback.
final promptFeedbackOnScreenshotSettingDef = const BoolSetting(
  'prompt_feedback_on_screenshot',
  defaultValue: true,
  titleKey: 'prompt_feedback_on_screenshot',
  icon: Icons.screenshot_monitor_outlined,
  section: 'about',
  order: 0,
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
  section: 'appearance',
  order: 0,
);

final themeColorSettingDef = const ColorSetting(
  'theme_color',
  defaultValue: 0xFF2E7D32,
  titleKey: 'select_theme_color',
  icon: Icons.palette,
  section: 'appearance',
  order: 1,
);

final languageSettingDef = const EnumSetting(
  'language',
  defaultValue: 'en',
  titleKey: 'language',
  options: ['en', 'ar'],
  optionLabels: {'en': 'English', 'ar': 'العربية'},
  icon: Icons.language,
  section: 'appearance',
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
  order: 3,
);

/// When true, user has completed first-launch onboarding.
final onboardingCompletedSettingDef = const BoolSetting(
  'onboarding_completed',
  defaultValue: false,
  titleKey: 'onboarding_completed',
  icon: Icons.check_circle_outline,
  section: 'appearance',
  order: -1, // Internal, not shown in settings UI
);

/// When true, user selected Online and tapped Complete; OAuth redirect in progress (web).
/// Cleared by main.dart when the app reloads after redirect.
final onboardingOnlinePendingSettingDef = const BoolSetting(
  'onboarding_online_pending',
  defaultValue: false,
  titleKey: 'onboarding_online_pending',
  icon: Icons.pending,
  section: 'appearance',
  order: -2, // Internal, not shown in settings UI
);

/// When true, user switched to online in settings; OAuth redirect in progress (web).
/// Cleared by main.dart when the app reloads after redirect.
final settingsOnlinePendingSettingDef = const BoolSetting(
  'settings_online_pending',
  defaultValue: false,
  titleKey: 'settings_online_pending',
  icon: Icons.pending,
  section: 'appearance',
  order: -3, // Internal, not shown in settings UI
);

/// Pending invite token from deep link; cleared when user reaches invite page or completes accept.
/// Persists across onboarding and OAuth redirects.
final pendingInviteTokenSettingDef = const StringSetting(
  'pending_invite_token',
  defaultValue: '',
  titleKey: 'pending_invite_token',
  icon: Icons.link,
  section: 'appearance',
  order: -4, // Internal, not shown in settings UI
);

/// When true, app uses only local storage (PowerSync SQLite). When false, syncs with Supabase.
final localOnlySettingDef = const BoolSetting(
  'local_only',
  defaultValue: true,
  titleKey: 'local_only',
  icon: Icons.storage,
  section: 'data_backup',
  order: 0,
);

/// When true, run OCR on receipt images (and optionally AI). When false, only attach the picture.
final receiptOcrEnabledSettingDef = const BoolSetting(
  'receipt_ocr_enabled',
  defaultValue: false,
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
  accountSection,
  appearanceSection,
  dataBackupSection,
  receiptAiSection,
  privacySection,
  advancedSection,
  aboutSection,
];

/// User's custom favourite currencies for the currency picker.
/// Stored as comma-separated ISO 4217 codes, e.g. "SAR,JPY,EUR".
/// Empty string means use the default list from CurrencyHelpers.
final favoriteCurrenciesSettingDef = const StringSetting(
  'favorite_currencies',
  defaultValue: '',
  titleKey: 'favorite_currencies',
  icon: Icons.star_outline,
  section: 'appearance',
  order: 4,
);

final allSettings = <SettingDefinition>[
  onboardingCompletedSettingDef,
  onboardingOnlinePendingSettingDef,
  settingsOnlinePendingSettingDef,
  pendingInviteTokenSettingDef,
  themeModeSettingDef,
  themeColorSettingDef,
  languageSettingDef,
  fontSizeScaleSettingDef,
  favoriteCurrenciesSettingDef,
  localOnlySettingDef,
  receiptOcrEnabledSettingDef,
  receiptAiEnabledSettingDef,
  receiptAiProviderSettingDef,
  geminiApiKeySettingDef,
  openaiApiKeySettingDef,
  telemetryEnabledSettingDef,
  notificationsEnabledSettingDef,
  promptFeedbackOnScreenshotSettingDef,
];

SettingsRegistry createHisabSettingsRegistry() {
  return SettingsRegistry.withSettings(
    sections: allSections,
    settings: allSettings,
  );
}
