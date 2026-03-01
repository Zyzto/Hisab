import 'package:flutter/material.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

import '../../core/theme/flex_theme_builder.dart'
    show defaultThemeSchemeId, flexSchemeOptionIds;

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

/// Toggles that change app behavior (e.g. expense form mode).
final functionalSection = const SettingSection(
  key: 'functional',
  titleKey: 'functional_settings',
  icon: Icons.tune,
  order: 1,
  initiallyExpanded: true,
);

/// Merged from old Data + Backup sections.
final dataBackupSection = const SettingSection(
  key: 'data_backup',
  titleKey: 'data_backup',
  icon: Icons.storage,
  order: 2,
);

final receiptAiSection = const SettingSection(
  key: 'receipt_ai',
  titleKey: 'receipt_ai_section',
  icon: Icons.receipt_long,
  order: 3,
);

/// Renamed from old Logging section.
final privacySection = const SettingSection(
  key: 'privacy',
  titleKey: 'privacy',
  icon: Icons.shield_outlined,
  order: 4,
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
  section: 'appearance',
  order: 0,
);

/// Color scheme: predefined FlexScheme or "custom" (then [theme_color] is used).
final themeSchemeSettingDef = const EnumSetting(
  'theme_scheme',
  defaultValue: defaultThemeSchemeId,
  titleKey: 'color_scheme',
  options: flexSchemeOptionIds,
  optionLabels: {
    'green': 'theme_scheme_green',
    'blue': 'theme_scheme_blue',
    'tealM3': 'theme_scheme_teal',
    'indigo': 'theme_scheme_indigo',
    'mandyRed': 'theme_scheme_mandyRed',
    'red': 'theme_scheme_red',
    'purpleBrown': 'theme_scheme_purpleBrown',
    'deepPurple': 'theme_scheme_deepPurple',
    'amber': 'theme_scheme_amber',
    'custom': 'theme_scheme_custom',
  },
  icon: Icons.palette_outlined,
  section: 'appearance',
  order: 1,
);

final themeColorSettingDef = const ColorSetting(
  'theme_color',
  defaultValue: 0xFF2E7D32,
  titleKey: 'select_theme_color',
  icon: Icons.palette,
  section: 'appearance',
  order: 2,
);

final languageSettingDef = const EnumSetting(
  'language',
  defaultValue: 'en',
  titleKey: 'language',
  options: ['en', 'ar'],
  optionLabels: {'en': 'English', 'ar': 'العربية'},
  icon: Icons.language,
  section: 'appearance',
  order: 3,
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
  order: 4,
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

/// Last route path when app went to background; used to restore after process kill (e.g. returning from camera).
/// Cleared on resume; non-empty on cold start means we were likely killed.
final lastRoutePathSettingDef = const StringSetting(
  'last_route_path',
  defaultValue: '',
  titleKey: 'last_route_path',
  icon: Icons.route,
  section: 'appearance',
  order: -5, // Internal, not shown in settings UI
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

/// When non-empty, stores the user id at the time the user switched to local-only from online.
/// Used to skip migration when switching back to online with the same user (data already on server).
final localDataFromOnlineUserIdSettingDef = const StringSetting(
  'local_data_from_online_user_id',
  defaultValue: '',
  titleKey: 'local_data_from_online_user_id',
  icon: Icons.storage,
  section: 'data_backup',
  order: -1, // Internal, not shown in settings UI
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

// --- Home list (home page groups/personal order and display) ---

final homeListSection = const SettingSection(
  key: 'home_list',
  titleKey: 'home_list_options',
  icon: Icons.view_list,
  order: 0,
  initiallyExpanded: true,
);

/// Sections: separate (Personal + Groups) or combined list. Default list with Personal + Groups.
final homeListDisplaySettingDef = const EnumSetting(
  'home_list_display',
  defaultValue: 'list_separate',
  titleKey: 'home_list_display',
  options: ['list_separate', 'list_combined'],
  optionLabels: {
    'list_separate': 'home_list_display_list_separate',
    'list_combined': 'home_list_display_list_combined',
  },
  icon: Icons.view_list,
  section: 'home_list',
  order: 0,
);

/// Sort for unpinned items: created_at, updated_at, or custom (drag order).
final homeListSortSettingDef = const EnumSetting(
  'home_list_sort',
  defaultValue: 'updated_at',
  titleKey: 'home_list_sort',
  options: ['created_at', 'updated_at', 'custom'],
  optionLabels: {
    'created_at': 'home_list_sort_created',
    'updated_at': 'home_list_sort_updated',
    'custom': 'home_list_sort_custom',
  },
  icon: Icons.sort,
  section: 'home_list',
  order: 1,
);

/// Comma-separated group IDs; order when sort is custom; also order among pinned when sort not applied to pinned.
final homeListCustomOrderSettingDef = const StringSetting(
  'home_list_custom_order',
  defaultValue: '',
  titleKey: 'home_list_custom_order',
  icon: Icons.drag_indicator,
  section: 'home_list',
  order: 2,
);

/// Comma-separated group IDs that stay at top (unless apply sort to pinned is on).
final homeListPinnedIdsSettingDef = const StringSetting(
  'home_list_pinned_ids',
  defaultValue: '',
  titleKey: 'home_list_pinned_ids',
  icon: Icons.push_pin,
  section: 'home_list',
  order: 3,
);

/// When true, show creation date on the left of each group/personal card.
final homeListShowCreatedAtSettingDef = const BoolSetting(
  'home_list_show_created_at',
  defaultValue: false,
  titleKey: 'home_list_show_created_at',
  icon: Icons.calendar_today,
  section: 'home_list',
  order: 4,
);

final allSections = [
  accountSection,
  appearanceSection,
  functionalSection,
  homeListSection,
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
  order: 5,
);

/// Optional single currency to show as secondary amount below main amounts (group detail, expense detail).
/// Stored as one ISO 4217 code; empty string means do not show secondary line.
final displayCurrencySettingDef = const StringSetting(
  'display_currency',
  defaultValue: '',
  titleKey: 'display_currency',
  icon: Icons.visibility_outlined,
  section: 'appearance',
  order: 6,
);

/// When true, show times in 24-hour format (e.g. 14:30). When false, use 12-hour AM/PM.
final use24HourFormatSettingDef = const BoolSetting(
  'use_24_hour_format',
  defaultValue: false,
  titleKey: 'use_24_hour_format',
  icon: Icons.schedule,
  section: 'appearance',
  order: 7,
);

/// When true, expense form shows full options (Expense / Income / Transfer pill).
/// When false (default), only expense addition is shown; pill is hidden.
final expenseFormFullFeaturesSettingDef = const BoolSetting(
  'expense_form_full_features',
  defaultValue: false,
  titleKey: 'expense_form_full_features',
  icon: Icons.receipt_long_outlined,
  section: 'functional',
  order: 0,
);

/// When true, the description section in the expense form starts expanded.
final expenseFormExpandDescriptionSettingDef = const BoolSetting(
  'expense_form_expand_description',
  defaultValue: false,
  titleKey: 'expense_form_expand_description',
  icon: Icons.text_fields,
  section: 'functional',
  order: 1,
);

/// When true, the bill breakdown section in the expense form starts expanded.
final expenseFormExpandBillBreakdownSettingDef = const BoolSetting(
  'expense_form_expand_bill_breakdown',
  defaultValue: false,
  titleKey: 'expense_form_expand_bill_breakdown',
  icon: Icons.receipt_long,
  section: 'functional',
  order: 2,
);

final allSettings = <SettingDefinition>[
  onboardingCompletedSettingDef,
  onboardingOnlinePendingSettingDef,
  settingsOnlinePendingSettingDef,
  pendingInviteTokenSettingDef,
  lastRoutePathSettingDef,
  themeModeSettingDef,
  themeSchemeSettingDef,
  themeColorSettingDef,
  languageSettingDef,
  fontSizeScaleSettingDef,
  favoriteCurrenciesSettingDef,
  displayCurrencySettingDef,
  use24HourFormatSettingDef,
  expenseFormFullFeaturesSettingDef,
  expenseFormExpandDescriptionSettingDef,
  expenseFormExpandBillBreakdownSettingDef,
  localOnlySettingDef,
  localDataFromOnlineUserIdSettingDef,
  receiptOcrEnabledSettingDef,
  receiptAiEnabledSettingDef,
  receiptAiProviderSettingDef,
  geminiApiKeySettingDef,
  openaiApiKeySettingDef,
  telemetryEnabledSettingDef,
  notificationsEnabledSettingDef,
  homeListDisplaySettingDef,
  homeListSortSettingDef,
  homeListCustomOrderSettingDef,
  homeListPinnedIdsSettingDef,
  homeListShowCreatedAtSettingDef,
];

SettingsRegistry createHisabSettingsRegistry() {
  return SettingsRegistry.withSettings(
    sections: allSections,
    settings: allSettings,
  );
}
