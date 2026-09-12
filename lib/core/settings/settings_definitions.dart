import 'package:flutter/material.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

import '../theme/flex_theme_builder.dart'
    show defaultThemeSchemeId, flexSchemeOptionIds;

// Settings are deliberately local-only. The definitions in this file are
// storage/UI preferences for the local-only application.
final appearanceSection = const SettingSection(
  key: 'appearance',
  titleKey: 'appearance',
  icon: Icons.palette,
  order: 0,
  initiallyExpanded: true,
);

final functionalSection = const SettingSection(
  key: 'functional',
  titleKey: 'functional_settings',
  icon: Icons.tune,
  order: 1,
  initiallyExpanded: true,
);

final homeListSection = const SettingSection(
  key: 'home_list',
  titleKey: 'home_list_options',
  icon: Icons.view_list,
  order: 2,
  initiallyExpanded: true,
);

final dataBackupSection = const SettingSection(
  key: 'data_backup',
  titleKey: 'data_backup',
  icon: Icons.storage,
  order: 3,
  initiallyExpanded: true,
);

final scannerSection = const SettingSection(
  key: 'scanner',
  titleKey: 'scanner_section',
  icon: Icons.document_scanner_outlined,
  order: 4,
  initiallyExpanded: true,
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
);

final favoriteCurrenciesSettingDef = const StringSetting(
  'favorite_currencies',
  defaultValue: '',
  titleKey: 'favorite_currencies',
  icon: Icons.star_outline,
  section: 'appearance',
  order: 5,
);

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

final use24HourFormatSettingDef = const BoolSetting(
  'use_24_hour_format',
  defaultValue: false,
  titleKey: 'use_24_hour_format',
  subtitleKey: 'use_24_hour_format_description',
  icon: Icons.schedule,
  section: 'appearance',
  order: 7,
);

final subtleAccentsSettingDef = const BoolSetting(
  'subtle_accents',
  defaultValue: false,
  titleKey: 'subtle_accents',
  subtitleKey: 'subtle_accents_description',
  icon: Icons.tonality,
  section: 'appearance',
  order: 8,
);

final extraAnimationsEnabledSettingDef = const BoolSetting(
  'extra_animations_enabled',
  defaultValue: true,
  titleKey: 'extra_animations_enabled',
  subtitleKey: 'extra_animations_enabled_description',
  icon: Icons.animation,
  section: 'appearance',
  order: 9,
);

final onboardingCompletedSettingDef = const BoolSetting(
  'onboarding_completed',
  defaultValue: false,
  titleKey: 'onboarding_completed',
  icon: Icons.check_circle_outline,
  section: 'appearance',
  order: -1,
  visible: false,
);

final lastRoutePathSettingDef = const StringSetting(
  'last_route_path',
  defaultValue: '',
  titleKey: 'last_route_path',
  icon: Icons.route,
  section: 'appearance',
  order: -2,
  visible: false,
);

final pendingImagePickModeSettingDef = const StringSetting(
  'pending_image_pick_mode',
  defaultValue: '',
  titleKey: 'pending_image_pick_mode',
  icon: Icons.document_scanner_outlined,
  section: 'appearance',
  order: -3,
  visible: false,
);

abstract final class PendingImagePickMode {
  static const attach = 'attach';
  static const scan = 'scan';
}

final receiptScanModeSettingDef = const EnumSetting(
  'receipt_scan_mode',
  defaultValue: 'off',
  titleKey: 'receipt_scan_mode',
  options: ['off', 'local'],
  optionLabels: {
    'off': 'receipt_scan_mode_off',
    'local': 'receipt_scan_mode_local',
  },
  icon: Icons.document_scanner,
  section: 'scanner',
  order: 6,
  searchTerms: {
    'en': ['ocr', 'scan', 'receipt', 'local'],
    'ar': ['مسح', 'إيصال'],
  },
);

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

final homeListCustomOrderSettingDef = const StringSetting(
  'home_list_custom_order',
  defaultValue: '',
  titleKey: 'home_list_custom_order',
  icon: Icons.drag_indicator,
  section: 'home_list',
  order: 2,
  visible: false,
);

final homeListPinnedIdsSettingDef = const StringSetting(
  'home_list_pinned_ids',
  defaultValue: '',
  titleKey: 'home_list_pinned_ids',
  icon: Icons.push_pin,
  section: 'home_list',
  order: 3,
  visible: false,
);

final homeListShowCreatedAtSettingDef = const BoolSetting(
  'home_list_show_created_at',
  defaultValue: false,
  titleKey: 'home_list_show_created_at',
  icon: Icons.calendar_today,
  section: 'home_list',
  order: 4,
);

final scannerEnabledSettingDef = const BoolSetting(
  'scanner_enabled',
  defaultValue: false,
  titleKey: 'scanner_enabled',
  icon: Icons.notifications_active_outlined,
  section: 'scanner',
  order: 0,
);

final scannerLocationEnabledSettingDef = const BoolSetting(
  'scanner_location_enabled',
  defaultValue: false,
  titleKey: 'scanner_location_enabled',
  icon: Icons.location_on_outlined,
  section: 'scanner',
  order: 1,
  visible: false,
);

final scannerNotifyOnCaptureSettingDef = const BoolSetting(
  'scanner_notify_on_capture',
  defaultValue: true,
  titleKey: 'scanner_notify_on_capture',
  icon: Icons.notification_add_outlined,
  section: 'scanner',
  order: 2,
  visible: false,
);

final scannerDefaultGroupIdSettingDef = const StringSetting(
  'scanner_default_group_id',
  defaultValue: '',
  titleKey: 'scanner_default_group',
  icon: Icons.group_outlined,
  section: 'scanner',
  order: 3,
  visible: false,
);

final scannerCategorizeEnabledSettingDef = const BoolSetting(
  'scanner_categorize_enabled',
  defaultValue: true,
  titleKey: 'scanner_categorize_enabled',
  subtitleKey: 'scanner_categorize_enabled_subtitle',
  icon: Icons.category_outlined,
  section: 'scanner',
  order: 4,
);

final scannerSetupCompletedSettingDef = const BoolSetting(
  'scanner_setup_completed',
  defaultValue: false,
  titleKey: 'scanner_setup_completed',
  icon: Icons.flag_outlined,
  section: 'scanner',
  order: -1,
  visible: false,
);

final expenseFormFullFeaturesSettingDef = const BoolSetting(
  'expense_form_full_features',
  defaultValue: false,
  titleKey: 'expense_form_full_features',
  subtitleKey: 'expense_form_full_features_description',
  icon: Icons.receipt_long_outlined,
  section: 'functional',
  order: 0,
);

final expenseFormExpandDescriptionSettingDef = const BoolSetting(
  'expense_form_expand_description',
  defaultValue: false,
  titleKey: 'expense_form_expand_description',
  subtitleKey: 'expense_form_expand_description_setting',
  icon: Icons.text_fields,
  section: 'functional',
  order: 1,
);

final expenseFormExpandBillBreakdownSettingDef = const BoolSetting(
  'expense_form_expand_bill_breakdown',
  defaultValue: false,
  titleKey: 'expense_form_expand_bill_breakdown',
  subtitleKey: 'expense_form_expand_bill_breakdown_setting',
  icon: Icons.receipt_long,
  section: 'functional',
  order: 2,
);

final actionExportDataSettingDef = const ActionSetting(
  'action_export_data',
  titleKey: 'export_data',
  icon: Icons.upload_file,
  section: 'data_backup',
  order: 0,
  searchTerms: {
    'en': ['backup', 'download', 'export'],
    'ar': ['تصدير', 'نسخ'],
  },
);

final actionImportDataSettingDef = const ActionSetting(
  'action_import_data',
  titleKey: 'import_data',
  subtitleKey: 'import_data_subtitle',
  icon: Icons.download,
  section: 'data_backup',
  order: 1,
  searchTerms: {
    'en': ['restore', 'upload', 'import'],
    'ar': ['استيراد', 'استعادة'],
  },
);

final actionPrivacyPolicySettingDef = const ActionSetting(
  'action_privacy_policy',
  titleKey: 'privacy_policy',
  icon: Icons.policy_outlined,
  section: 'about',
  order: 0,
  searchTerms: {
    'en': ['legal', 'policy'],
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
);

final actionViewLogsSettingDef = const ActionSetting(
  'action_view_logs',
  titleKey: 'view_logs',
  icon: Icons.description,
  section: 'advanced',
  order: 1,
);

final actionResetAllSettingsSettingDef = const ActionSetting(
  'action_reset_all_settings',
  titleKey: 'reset_all_settings',
  subtitleKey: 'reset_all_settings_description',
  icon: Icons.restore,
  section: 'advanced',
  order: 2,
);

final actionDeleteLocalDataSettingDef = const ActionSetting(
  'action_delete_local_data',
  titleKey: 'delete_local_data',
  subtitleKey: 'delete_local_data_description',
  icon: Icons.phone_android,
  section: 'advanced',
  order: 3,
);

final actionLicensesSettingDef = const ActionSetting(
  'action_licenses',
  titleKey: 'licenses',
  icon: Icons.article_outlined,
  section: 'about',
  order: 1,
);

final actionVersionSettingDef = const ActionSetting(
  'action_version',
  titleKey: 'version',
  icon: Icons.info_outline,
  section: 'about',
  order: 2,
);

final actionScannerHubSettingDef = const ActionSetting(
  'action_scanner_hub',
  titleKey: 'scanner_section',
  icon: Icons.document_scanner_outlined,
  section: 'scanner',
  order: 10,
);

final allSections = <SettingSection>[
  appearanceSection,
  functionalSection,
  homeListSection,
  dataBackupSection,
  scannerSection,
  advancedSection,
  aboutSection,
];

final allSettings = <SettingDefinition>[
  onboardingCompletedSettingDef,
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
  receiptScanModeSettingDef,
  homeListDisplaySettingDef,
  homeListSortSettingDef,
  homeListCustomOrderSettingDef,
  homeListPinnedIdsSettingDef,
  homeListShowCreatedAtSettingDef,
  scannerEnabledSettingDef,
  scannerLocationEnabledSettingDef,
  scannerNotifyOnCaptureSettingDef,
  scannerDefaultGroupIdSettingDef,
  scannerCategorizeEnabledSettingDef,
  scannerSetupCompletedSettingDef,
  actionExportDataSettingDef,
  actionImportDataSettingDef,
  actionPrivacyPolicySettingDef,
  actionReturnToOnboardingSettingDef,
  actionViewLogsSettingDef,
  actionResetAllSettingsSettingDef,
  actionDeleteLocalDataSettingDef,
  actionLicensesSettingDef,
  actionVersionSettingDef,
  actionScannerHubSettingDef,
];

const settingsPageSectionKeys = <String>{
  'appearance',
  'functional',
  'data_backup',
  'scanner',
  'advanced',
  'about',
};

SettingsRegistry createHisabSettingsRegistry() {
  return SettingsRegistry.withSettings(
    sections: allSections,
    settings: allSettings,
  );
}
