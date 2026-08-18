import 'package:flutter/material.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

import '../theme/flex_theme_builder.dart'
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
  initiallyExpanded: true,
);

final receiptAiSection = const SettingSection(
  key: 'receipt_ai',
  titleKey: 'receipt_ai_section',
  icon: Icons.receipt_long,
  order: 3,
  initiallyExpanded: true,
);

/// Renamed from old Logging section.
final privacySection = const SettingSection(
  key: 'privacy',
  titleKey: 'privacy',
  icon: Icons.shield_outlined,
  order: 4,
  initiallyExpanded: true,
);

/// When true, send anonymous usage data to telemetry endpoint. No-op if endpoint is empty.
final telemetryEnabledSettingDef = const BoolSetting(
  'telemetry_enabled',
  defaultValue: true,
  titleKey: 'telemetry_enabled',
  subtitleKey: 'telemetry_enabled_description',
  icon: Icons.analytics,
  section: 'privacy',
  order: 0,
  searchTerms: {
    'en': ['analytics', 'usage', 'tracking'],
    // تحليلات = usage-tracking synonym; product Analytics tab is الإحصاءات.
    'ar': ['تحليلات', 'تتبع', 'إحصاءات'],
  },
);

/// When true, push notifications are active (FCM token registered).
/// When false, the token is unregistered and no push notifications are received.
final notificationsEnabledSettingDef = const BoolSetting(
  'notifications_enabled',
  defaultValue: true,
  titleKey: 'notifications_enabled',
  subtitleKey: 'notifications_enabled_description',
  icon: Icons.notifications_outlined,
  section: 'privacy',
  order: 1,
  searchTerms: {
    'en': ['push', 'fcm', 'alerts'],
    'ar': ['إشعارات', 'تنبيهات'],
  },
);

/// When true, prompt to report an issue after an OS screenshot (iOS / Android 14+).
final screenshotReportPromptEnabledSettingDef = const BoolSetting(
  'screenshot_report_prompt_enabled',
  defaultValue: false,
  titleKey: 'screenshot_report_prompt_enabled',
  subtitleKey: 'screenshot_report_prompt_enabled_description',
  icon: Icons.screenshot_outlined,
  section: 'privacy',
  order: 2,
  searchTerms: {
    'en': ['screenshot', 'bug', 'report', 'feedback'],
    'ar': ['لقطة', 'بلاغ', 'ملاحظات'],
  },
);

final advancedSection = const SettingSection(
  key: 'advanced',
  titleKey: 'advanced',
  icon: Icons.build,
  order: 5,
  initiallyExpanded: true,
);

final aboutSection = const SettingSection(
  key: 'about',
  titleKey: 'about',
  icon: Icons.info,
  order: 6,
  initiallyExpanded: true,
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
  searchTerms: {
    'en': ['dark', 'light', 'mode', 'amoled', 'appearance'],
    'ar': ['داكن', 'فاتح', 'سمة', 'مظهر'],
  },
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
  searchTerms: {
    'en': ['color', 'palette', 'scheme'],
    'ar': ['لون', 'ألوان'],
  },
);

final themeColorSettingDef = const ColorSetting(
  'theme_color',
  defaultValue: 0xFF2E7D32,
  titleKey: 'select_theme_color',
  icon: Icons.palette,
  section: 'appearance',
  order: 2,
  searchTerms: {
    'en': ['custom color', 'accent'],
    'ar': ['لون مخصص'],
  },
);

final languageSettingDef = const EnumSetting(
  'language',
  defaultValue: 'en',
  titleKey: 'language',
  options: ['en', 'ar'],
  optionLabels: {'en': 'language_name_en', 'ar': 'language_name_ar'},
  icon: Icons.language,
  section: 'appearance',
  order: 3,
  searchTerms: {
    'en': ['locale', 'english', 'arabic', 'translation'],
    'ar': ['لغة', 'إنجليزي', 'عربي', 'ترجمة'],
  },
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
  searchTerms: {
    'en': ['text size', 'typography', 'accessibility'],
    'ar': ['حجم الخط', 'نص'],
  },
);

/// When true, user has completed first-launch onboarding.
final onboardingCompletedSettingDef = const BoolSetting(
  'onboarding_completed',
  defaultValue: false,
  titleKey: 'onboarding_completed',
  icon: Icons.check_circle_outline,
  section: 'appearance',
  order: -1,
  visible: false,
);

/// When true, user selected Online and tapped Complete; OAuth redirect in progress (web).
/// Cleared by main.dart when the app reloads after redirect.
final onboardingOnlinePendingSettingDef = const BoolSetting(
  'onboarding_online_pending',
  defaultValue: false,
  titleKey: 'onboarding_online_pending',
  icon: Icons.pending,
  section: 'appearance',
  order: -2,
  visible: false,
);

/// When true, user switched to online in settings; OAuth redirect in progress (web).
/// Cleared by main.dart when the app reloads after redirect.
final settingsOnlinePendingSettingDef = const BoolSetting(
  'settings_online_pending',
  defaultValue: false,
  titleKey: 'settings_online_pending',
  icon: Icons.pending,
  section: 'appearance',
  order: -3,
  visible: false,
);

/// Pending invite token from deep link; cleared when user reaches invite page or completes accept.
/// Persists across onboarding and OAuth redirects.
final pendingInviteTokenSettingDef = const StringSetting(
  'pending_invite_token',
  defaultValue: '',
  titleKey: 'pending_invite_token',
  icon: Icons.link,
  section: 'appearance',
  order: -4,
  visible: false,
);

/// When true, after login/register the invite page should auto-accept and open the group
/// (view+join flow). Cleared after accept attempt.
final pendingInviteAutoJoinSettingDef = const BoolSetting(
  'pending_invite_auto_join',
  defaultValue: false,
  titleKey: 'pending_invite_auto_join',
  icon: Icons.group_add,
  section: 'appearance',
  order: -5,
  visible: false,
);

/// Last route path when app went to background; used to restore after process kill (e.g. returning from camera).
/// Cleared on resume; non-empty on cold start means we were likely killed.
final lastRoutePathSettingDef = const StringSetting(
  'last_route_path',
  defaultValue: '',
  titleKey: 'last_route_path',
  icon: Icons.route,
  section: 'appearance',
  order: -5,
  visible: false,
);

/// In-flight camera/gallery pick (`attach` / `scan`). Survives process death
/// and blocks clearing [lastRoutePathSettingDef] during camera resume flicker.
final pendingImagePickModeSettingDef = const StringSetting(
  'pending_image_pick_mode',
  defaultValue: '',
  titleKey: 'pending_image_pick_mode',
  icon: Icons.document_scanner_outlined,
  section: 'appearance',
  order: -6,
  visible: false,
);

abstract final class PendingImagePickMode {
  static const attach = 'attach';
  static const scan = 'scan';
}

/// When true, app uses only local storage (PowerSync SQLite). When false, syncs with Supabase.
final localOnlySettingDef = const BoolSetting(
  'local_only',
  defaultValue: true,
  titleKey: 'local_only',
  subtitleKey: 'local_only_description',
  icon: Icons.storage,
  section: 'data_backup',
  order: 0,
  searchTerms: {
    'en': ['offline', 'online', 'sync', 'cloud'],
    'ar': ['محلي', 'مزامنة', 'سحابة'],
  },
);

/// When non-empty, stores the user id at the time the user switched to local-only from online.
/// Used to skip migration when switching back to online with the same user (data already on server).
final localDataFromOnlineUserIdSettingDef = const StringSetting(
  'local_data_from_online_user_id',
  defaultValue: '',
  titleKey: 'local_data_from_online_user_id',
  icon: Icons.storage,
  section: 'data_backup',
  order: -1,
  visible: false,
);

/// Receipt scan mode: off | local | nano | cloud.
final receiptScanModeSettingDef = const EnumSetting(
  'receipt_scan_mode',
  defaultValue: 'off',
  titleKey: 'receipt_scan_mode',
  options: ['off', 'local', 'nano', 'cloud'],
  optionLabels: {
    'off': 'receipt_scan_mode_off',
    'local': 'receipt_scan_mode_local',
    'nano': 'receipt_scan_mode_nano',
    'cloud': 'receipt_scan_mode_cloud',
  },
  icon: Icons.document_scanner,
  section: 'receipt_ai',
  order: 0,
  searchTerms: {
    'en': ['ocr', 'scan', 'receipt', 'nano', 'local', 'cloud', 'ai'],
    'ar': ['مسح', 'إيصال', 'ذكاء'],
  },
);

/// Which cloud LLM provider to use when mode is cloud.
final receiptAiProviderSettingDef = const EnumSetting(
  'receipt_ai_provider',
  defaultValue: 'gemini',
  titleKey: 'receipt_ai_provider',
  options: ['gemini', 'openai', 'hisab'],
  optionLabels: {
    'gemini': 'receipt_ai_provider_gemini',
    'openai': 'receipt_ai_provider_openai',
    'hisab': 'receipt_ai_provider_hisab',
  },
  icon: Icons.cloud,
  section: 'receipt_ai',
  order: 1,
  searchTerms: {
    'en': ['ai', 'llm', 'gemini', 'openai', 'hisab'],
    'ar': ['ذكاء', 'اصطناعي'],
  },
);

/// Gemini API key (Google AI for Developers). Used when provider is gemini.
final geminiApiKeySettingDef = const StringSetting(
  'gemini_api_key',
  defaultValue: '',
  titleKey: 'gemini_api_key',
  icon: Icons.key,
  section: 'receipt_ai',
  order: 2,
  searchTerms: {
    'en': ['api key', 'google'],
    'ar': ['مفتاح'],
  },
);

/// OpenAI API key. Used when provider is openai.
final openaiApiKeySettingDef = const StringSetting(
  'openai_api_key',
  defaultValue: '',
  titleKey: 'openai_api_key',
  icon: Icons.key,
  section: 'receipt_ai',
  order: 3,
  searchTerms: {
    'en': ['api key', 'chatgpt'],
    'ar': ['مفتاح'],
  },
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
  visible: false,
);

/// Comma-separated group IDs that stay at top (unless apply sort to pinned is on).
final homeListPinnedIdsSettingDef = const StringSetting(
  'home_list_pinned_ids',
  defaultValue: '',
  titleKey: 'home_list_pinned_ids',
  icon: Icons.push_pin,
  section: 'home_list',
  order: 3,
  visible: false,
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

/// Transaction scanner section (personal budget auto-import from notifications).
final scannerSection = const SettingSection(
  key: 'scanner',
  titleKey: 'scanner_section',
  icon: Icons.document_scanner_outlined,
  order: 3,
  initiallyExpanded: true,
);

/// Master toggle for the notification transaction scanner. Disabled by default.
final scannerEnabledSettingDef = const BoolSetting(
  'scanner_enabled',
  defaultValue: false,
  titleKey: 'scanner_enabled',
  icon: Icons.notifications_active_outlined,
  section: 'scanner',
  order: 0,
  searchTerms: {
    'en': ['notification listener', 'bank', 'sms'],
    'ar': ['ماسح', 'إشعارات بنكية'],
  },
);

/// When true, capture GPS location at notification time. Disabled by default.
final scannerLocationEnabledSettingDef = const BoolSetting(
  'scanner_location_enabled',
  defaultValue: false,
  titleKey: 'scanner_location_enabled',
  icon: Icons.location_on_outlined,
  section: 'scanner',
  order: 1,
);

/// Show a local notification when a transaction is captured.
final scannerNotifyOnCaptureSettingDef = const BoolSetting(
  'scanner_notify_on_capture',
  defaultValue: true,
  titleKey: 'scanner_notify_on_capture',
  icon: Icons.notification_add_outlined,
  section: 'scanner',
  order: 2,
);

final allSections = [
  accountSection,
  appearanceSection,
  functionalSection,
  homeListSection,
  dataBackupSection,
  receiptAiSection,
  scannerSection,
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
  searchTerms: {
    'en': ['currency', 'currencies', 'favorites'],
    'ar': ['عملة', 'عملات', 'مفضلة'],
  },
);

/// Optional single currency to show as secondary amount below main amounts (group detail, expense detail).
/// Stored as one ISO 4217 code; empty string means do not show secondary line.
final displayCurrencySettingDef = const StringSetting(
  'display_currency',
  defaultValue: '',
  titleKey: 'display_currency',
  subtitleKey: 'display_currency_hint',
  icon: Icons.visibility_outlined,
  section: 'appearance',
  order: 6,
  searchTerms: {
    'en': ['secondary currency', 'conversion'],
    'ar': ['عملة العرض'],
  },
);

/// When true, show times in 24-hour format (e.g. 14:30). When false, use 12-hour AM/PM.
final use24HourFormatSettingDef = const BoolSetting(
  'use_24_hour_format',
  defaultValue: false,
  titleKey: 'use_24_hour_format',
  subtitleKey: 'use_24_hour_format_description',
  icon: Icons.schedule,
  section: 'appearance',
  order: 7,
  searchTerms: {
    'en': ['time', 'clock', 'am', 'pm', '24h'],
    'ar': ['وقت', 'ساعة'],
  },
);

/// When true, tone down decorative accent fills in cards/headers.
final subtleAccentsSettingDef = const BoolSetting(
  'subtle_accents',
  defaultValue: false,
  titleKey: 'subtle_accents',
  subtitleKey: 'subtle_accents_description',
  icon: Icons.tonality,
  section: 'appearance',
  order: 8,
);

/// When true, playful FAB extras (leaf burst, plant blooms, delayed navigation).
/// Turn off for a calmer UI. Platform reduced-motion (iOS web) still wins.
final extraAnimationsEnabledSettingDef = const BoolSetting(
  'extra_animations_enabled',
  defaultValue: true,
  titleKey: 'extra_animations_enabled',
  subtitleKey: 'extra_animations_enabled_description',
  icon: Icons.animation,
  section: 'appearance',
  order: 9,
  searchTerms: {
    'en': ['animation', 'motion', 'fab', 'leaves', 'flowers', 'playful'],
    'ar': ['حركة', 'رسوم', 'تأثيرات'],
  },
);

/// When true, expense form shows full options (Expense / Income / Transfer pill).
/// When false (default), only expense addition is shown; pill is hidden.
final expenseFormFullFeaturesSettingDef = const BoolSetting(
  'expense_form_full_features',
  defaultValue: false,
  titleKey: 'expense_form_full_features',
  subtitleKey: 'expense_form_full_features_description',
  icon: Icons.receipt_long_outlined,
  section: 'functional',
  order: 0,
);

/// When true, the description section in the expense form starts expanded.
final expenseFormExpandDescriptionSettingDef = const BoolSetting(
  'expense_form_expand_description',
  defaultValue: false,
  titleKey: 'expense_form_expand_description',
  subtitleKey: 'expense_form_expand_description_setting',
  icon: Icons.text_fields,
  section: 'functional',
  order: 1,
);

/// When true, the bill breakdown section in the expense form starts expanded.
final expenseFormExpandBillBreakdownSettingDef = const BoolSetting(
  'expense_form_expand_bill_breakdown',
  defaultValue: false,
  titleKey: 'expense_form_expand_bill_breakdown',
  subtitleKey: 'expense_form_expand_bill_breakdown_setting',
  icon: Icons.receipt_long,
  section: 'functional',
  order: 2,
);

// --- Searchable action / navigation rows (non-persisted) ---

final actionOpenProfileSettingDef = const ActionSetting(
  'action_open_profile',
  titleKey: 'profile',
  subtitleKey: 'profile_settings_link_subtitle',
  icon: Icons.person_outline,
  section: 'account',
  order: 0,
  searchTerms: {
    'en': ['account', 'avatar', 'name'],
    'ar': ['حساب', 'ملف'],
  },
);

final actionExportDataSettingDef = const ActionSetting(
  'action_export_data',
  titleKey: 'export_data',
  icon: Icons.upload_file,
  section: 'data_backup',
  order: 1,
  searchTerms: {
    'en': ['backup', 'download', 'json', 'csv', 'zip', 'html', 'export'],
    'ar': ['تصدير', 'نسخ', 'zip', 'csv'],
  },
);

final actionImportDataSettingDef = const ActionSetting(
  'action_import_data',
  titleKey: 'import_data',
  subtitleKey: 'import_data_subtitle',
  icon: Icons.download,
  section: 'data_backup',
  order: 2,
  searchTerms: {
    'en': ['restore', 'upload', 'json', 'zip', 'backup', 'import'],
    'ar': ['استيراد', 'استعادة', 'zip'],
  },
);

final actionPrivacyPolicySettingDef = const ActionSetting(
  'action_privacy_policy',
  titleKey: 'privacy_policy',
  icon: Icons.policy_outlined,
  section: 'privacy',
  order: 2,
  searchTerms: {
    'en': ['legal', 'gdpr', 'policy'],
    'ar': ['سياسة', 'خصوصية'],
  },
);

final actionReturnToOnboardingSettingDef = const ActionSetting(
  'action_return_to_onboarding',
  titleKey: 'return_to_onboarding',
  subtitleKey: 'return_to_onboarding_description',
  icon: Icons.replay,
  section: 'advanced',
  order: 0,
  searchTerms: {
    'en': ['onboarding', 'welcome', 'setup'],
    'ar': ['إعداد', 'ترحيب'],
  },
);

final actionViewLogsSettingDef = const ActionSetting(
  'action_view_logs',
  titleKey: 'view_logs',
  icon: Icons.description,
  section: 'advanced',
  order: 1,
  searchTerms: {
    'en': ['debug', 'logs', 'diagnostics'],
    'ar': ['سجلات'],
  },
);

final actionResetAllSettingsSettingDef = const ActionSetting(
  'action_reset_all_settings',
  titleKey: 'reset_all_settings',
  subtitleKey: 'reset_all_settings_description',
  icon: Icons.restore,
  section: 'advanced',
  order: 2,
  searchTerms: {
    'en': ['defaults', 'reset', 'clear settings'],
    'ar': ['إعادة تعيين'],
  },
);

final actionDeleteLocalDataSettingDef = const ActionSetting(
  'action_delete_local_data',
  titleKey: 'delete_local_data',
  subtitleKey: 'delete_local_data_description',
  icon: Icons.phone_android,
  section: 'advanced',
  order: 3,
  searchTerms: {
    'en': ['wipe', 'erase', 'clear data'],
    'ar': ['حذف', 'مسح البيانات'],
  },
);

final actionDeleteCloudDataSettingDef = const ActionSetting(
  'action_delete_cloud_data',
  titleKey: 'delete_cloud_data',
  subtitleKey: 'delete_cloud_data_description',
  icon: Icons.cloud,
  section: 'advanced',
  order: 4,
  searchTerms: {
    'en': ['wipe', 'erase', 'server', 'account deletion'],
    'ar': ['حذف سحابة', 'خادم'],
  },
);

final actionSendFeedbackSettingDef = const ActionSetting(
  'action_send_feedback',
  titleKey: 'send_feedback',
  icon: Icons.feedback_outlined,
  section: 'about',
  order: 1,
  searchTerms: {
    'en': ['bug', 'report', 'contact'],
    'ar': ['ملاحظات', 'بلاغ'],
  },
);

final actionLicensesSettingDef = const ActionSetting(
  'action_licenses',
  titleKey: 'licenses',
  icon: Icons.article_outlined,
  section: 'about',
  order: 2,
  searchTerms: {
    'en': ['oss', 'open source', 'legal'],
    'ar': ['تراخيص'],
  },
);

// The AGPL obliges the hosted web app to offer its source to the people using
// it, so this tile is a licence requirement rather than a nicety.
final actionSourceCodeSettingDef = const ActionSetting(
  'action_source_code',
  titleKey: 'source_code',
  subtitleKey: 'source_code_description',
  icon: Icons.code_outlined,
  section: 'about',
  order: 3,
  searchTerms: {
    'en': ['source', 'github', 'agpl', 'open source', 'repository'],
    'ar': ['المصدر', 'الشيفرة', 'مفتوح'],
  },
);

final actionAboutMeSettingDef = const ActionSetting(
  'action_about_me',
  titleKey: 'about_me',
  subtitleKey: 'about_me_description',
  icon: Icons.person_search_outlined,
  section: 'about',
  order: 4,
  searchTerms: {
    'en': ['developer', 'author', 'github'],
    'ar': ['مطور'],
  },
);

final actionDonateSettingDef = const ActionSetting(
  'action_donate',
  titleKey: 'donate',
  subtitleKey: 'donate_description',
  icon: Icons.favorite_outline,
  section: 'about',
  order: 5,
  searchTerms: {
    'en': ['sponsor', 'support', 'github'],
    'ar': ['تبرع', 'دعم'],
  },
);

final actionVersionSettingDef = const ActionSetting(
  'action_version',
  titleKey: 'version',
  icon: Icons.info_outline,
  section: 'about',
  order: 0,
  searchTerms: {
    'en': ['update', 'release', 'build'],
    'ar': ['إصدار', 'تحديث'],
  },
);

final actionScannerHubSettingDef = const ActionSetting(
  'action_scanner_hub',
  titleKey: 'scanner_section',
  icon: Icons.document_scanner_outlined,
  section: 'scanner',
  order: 10,
  searchTerms: {
    'en': ['transaction scanner', 'hub'],
    'ar': ['ماسح المعاملات'],
  },
);

final allSettings = <SettingDefinition>[
  onboardingCompletedSettingDef,
  onboardingOnlinePendingSettingDef,
  settingsOnlinePendingSettingDef,
  pendingInviteTokenSettingDef,
  pendingInviteAutoJoinSettingDef,
  lastRoutePathSettingDef,
  pendingImagePickModeSettingDef,
  themeModeSettingDef,
  themeSchemeSettingDef,
  themeColorSettingDef,
  languageSettingDef,
  fontSizeScaleSettingDef,
  favoriteCurrenciesSettingDef,
  displayCurrencySettingDef,
  use24HourFormatSettingDef,
  subtleAccentsSettingDef,
  extraAnimationsEnabledSettingDef,
  expenseFormFullFeaturesSettingDef,
  expenseFormExpandDescriptionSettingDef,
  expenseFormExpandBillBreakdownSettingDef,
  localOnlySettingDef,
  localDataFromOnlineUserIdSettingDef,
  receiptScanModeSettingDef,
  receiptAiProviderSettingDef,
  geminiApiKeySettingDef,
  openaiApiKeySettingDef,
  scannerEnabledSettingDef,
  scannerLocationEnabledSettingDef,
  scannerNotifyOnCaptureSettingDef,
  telemetryEnabledSettingDef,
  notificationsEnabledSettingDef,
  screenshotReportPromptEnabledSettingDef,
  homeListDisplaySettingDef,
  homeListSortSettingDef,
  homeListCustomOrderSettingDef,
  homeListPinnedIdsSettingDef,
  homeListShowCreatedAtSettingDef,
  actionOpenProfileSettingDef,
  actionExportDataSettingDef,
  actionImportDataSettingDef,
  actionPrivacyPolicySettingDef,
  actionReturnToOnboardingSettingDef,
  actionViewLogsSettingDef,
  actionResetAllSettingsSettingDef,
  actionDeleteLocalDataSettingDef,
  actionDeleteCloudDataSettingDef,
  actionSendFeedbackSettingDef,
  actionLicensesSettingDef,
  actionSourceCodeSettingDef,
  actionAboutMeSettingDef,
  actionDonateSettingDef,
  actionVersionSettingDef,
  actionScannerHubSettingDef,
];

/// Sections shown on the Settings page (excludes home_list, edited from Home).
const settingsPageSectionKeys = <String>{
  'account',
  'appearance',
  'functional',
  'data_backup',
  'receipt_ai',
  'scanner',
  'privacy',
  'advanced',
  'about',
};

SettingsRegistry createHisabSettingsRegistry() {
  return SettingsRegistry.withSettings(
    sections: allSections,
    settings: allSettings,
  );
}
