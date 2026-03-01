import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../settings_definitions.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_user_profile.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../core/theme/flex_theme_builder.dart' show defaultThemeSchemeId;

part 'settings_framework_providers.g.dart';

/// App-owned provider for [SettingsProviders]. Override in main with the result of [initializeHisabSettings].
/// Use this in UI (e.g. settings page) to avoid depending on the framework's provider symbol.
@riverpod
SettingsProviders? hisabSettingsProviders(Ref ref) => null;

/// Maps legacy theme_color (int) to theme_scheme id for migration.
String themeSchemeFromLegacyColor(int themeColorValue) {
  switch (themeColorValue) {
    case 0xFF2E7D32:
      return 'green';
    case 0xFF1565C0:
      return 'blue';
    case 0xFF00897B:
      return 'tealM3';
    case 0xFF6A1B9A:
      return 'deepPurple';
    case 0xFFC62828:
      return 'red';
    case 0xFFE65100:
      return 'amber';
    default:
      return 'custom';
  }
}

/// One-time migration: derive theme_scheme from theme_color when upgrading.
Future<void> runThemeSchemeMigration(SettingsProviders settings) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('theme_scheme_migrated') == true) return;
    final themeColor =
        settings.controller.get(themeColorSettingDef) as int? ?? 0xFF2E7D32;
    final scheme = themeSchemeFromLegacyColor(themeColor);
    settings.controller.set(themeSchemeSettingDef, scheme);
    await prefs.setBool('theme_scheme_migrated', true);
  } catch (e, stackTrace) {
    Log.warning(
      'theme_scheme migration failed',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

/// One-time migration: fix invalid "teal" scheme id to "tealM3" (FlexScheme enum name).
Future<void> runThemeSchemeTealMigration(SettingsProviders settings) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('theme_scheme_teal_fixed') == true) return;
    final current = settings.controller.get(themeSchemeSettingDef) as String?;
    if (current == 'teal') {
      settings.controller.set(themeSchemeSettingDef, 'tealM3');
    }
    await prefs.setBool('theme_scheme_teal_fixed', true);
  } catch (e, stackTrace) {
    Log.warning(
      'theme_scheme teal migration failed',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

Future<SettingsProviders?> initializeHisabSettings() async {
  try {
    final registry = createHisabSettingsRegistry();
    final storage = SharedPreferencesStorage();
    final providers = await initializeSettings(registry: registry, storage: storage);
    // ignore: unnecessary_null_comparison -- initializeSettings may return null on failure
    if (providers != null) {
      await runThemeSchemeMigration(providers);
      await runThemeSchemeTealMigration(providers);
    }
    return providers;
  } catch (e, stackTrace) {
    Log.warning(
      'Settings init failed, using defaults',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
}

@riverpod
bool onboardingCompleted(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return false;
    return ref.watch(settings.provider(onboardingCompletedSettingDef));
  } catch (e, stackTrace) {
    Log.warning(
      'onboardingCompleted read failed, defaulting to false',
      error: e,
      stackTrace: stackTrace,
    );
    return false;
  }
}

@riverpod
bool localOnly(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return true;
    return ref.watch(settings.provider(localOnlySettingDef));
  } catch (e, stackTrace) {
    Log.warning(
      'localOnly read failed, defaulting to true',
      error: e,
      stackTrace: stackTrace,
    );
    return true;
  }
}

/// When true, app uses only local storage. When config is missing, effectively true.
@riverpod
bool effectiveLocalOnly(Ref ref) {
  final local = ref.watch(localOnlyProvider);
  return local || !supabaseConfigAvailable;
}

@riverpod
bool receiptOcrEnabled(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return false;
    return ref.watch(settings.provider(receiptOcrEnabledSettingDef));
  } catch (e, stackTrace) {
    Log.warning(
      'receiptOcrEnabled read failed, defaulting to false',
      error: e,
      stackTrace: stackTrace,
    );
    return false;
  }
}

@riverpod
bool receiptAiEnabled(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return false;
    return ref.watch(settings.provider(receiptAiEnabledSettingDef));
  } catch (e, stackTrace) {
    Log.warning(
      'receiptAiEnabled read failed, defaulting to false',
      error: e,
      stackTrace: stackTrace,
    );
    return false;
  }
}

@riverpod
String receiptAiProvider(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return 'none';
    return ref.watch(settings.provider(receiptAiProviderSettingDef));
  } catch (e, stackTrace) {
    Log.warning(
      'receiptAiProvider read failed, defaulting to none',
      error: e,
      stackTrace: stackTrace,
    );
    return 'none';
  }
}

@riverpod
String geminiApiKey(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return '';
    return ref.watch(settings.provider(geminiApiKeySettingDef));
  } catch (e, stackTrace) {
    Log.warning(
      'geminiApiKey read failed, defaulting to empty',
      error: e,
      stackTrace: stackTrace,
    );
    return '';
  }
}

@riverpod
String openaiApiKey(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return '';
    return ref.watch(settings.provider(openaiApiKeySettingDef));
  } catch (e, stackTrace) {
    Log.warning(
      'openaiApiKey read failed, defaulting to empty',
      error: e,
      stackTrace: stackTrace,
    );
    return '';
  }
}

@riverpod
String themeMode(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return 'system';
    return ref.watch(settings.provider(themeModeSettingDef));
  } catch (e, stackTrace) {
    Log.warning(
      'themeMode read failed, defaulting to system',
      error: e,
      stackTrace: stackTrace,
    );
    return 'system';
  }
}

@riverpod
String themeScheme(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return defaultThemeSchemeId;
    return ref.watch(settings.provider(themeSchemeSettingDef));
  } catch (e, stackTrace) {
    Log.warning(
      'themeScheme read failed, defaulting to green',
      error: e,
      stackTrace: stackTrace,
    );
    return defaultThemeSchemeId;
  }
}

@riverpod
int themeColor(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return 0xFF2E7D32;
    return ref.watch(settings.provider(themeColorSettingDef));
  } catch (e, stackTrace) {
    Log.warning(
      'themeColor read failed, defaulting to green',
      error: e,
      stackTrace: stackTrace,
    );
    return 0xFF2E7D32;
  }
}

@riverpod
String language(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return 'en';
    return ref.watch(settings.provider(languageSettingDef));
  } catch (e, stackTrace) {
    Log.warning(
      'language read failed, defaulting to en',
      error: e,
      stackTrace: stackTrace,
    );
    return 'en';
  }
}

@riverpod
String favoriteCurrencies(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return '';
    return ref.watch(settings.provider(favoriteCurrenciesSettingDef));
  } catch (e, stackTrace) {
    Log.warning(
      'favoriteCurrencies read failed, defaulting to empty',
      error: e,
      stackTrace: stackTrace,
    );
    return '';
  }
}

@riverpod
String displayCurrency(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return '';
    return ref.watch(settings.provider(displayCurrencySettingDef)).trim();
  } catch (e, stackTrace) {
    Log.warning(
      'displayCurrency read failed, defaulting to empty',
      error: e,
      stackTrace: stackTrace,
    );
    return '';
  }
}

@riverpod
String fontSizeScale(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return 'normal';
    return ref.watch(settings.provider(fontSizeScaleSettingDef));
  } catch (e, stackTrace) {
    Log.warning(
      'fontSizeScale read failed, defaulting to normal',
      error: e,
      stackTrace: stackTrace,
    );
    return 'normal';
  }
}

@riverpod
bool use24HourFormat(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return false;
    return ref.watch(settings.provider(use24HourFormatSettingDef));
  } catch (e, stackTrace) {
    Log.warning(
      'use24HourFormat read failed, defaulting to false',
      error: e,
      stackTrace: stackTrace,
    );
    return false;
  }
}

@riverpod
Future<AuthUserProfile?> authUserProfile(Ref ref) async {
  final localOnly = ref.watch(effectiveLocalOnlyProvider);
  if (localOnly) return null;
  // Watch auth state changes so the profile updates reactively when the
  // user signs in, signs out, or the session is restored after a page reload.
  ref.watch(authStateChangesProvider);
  return ref.watch(authServiceProvider).getUserProfile();
}

@riverpod
bool telemetryEnabled(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return true;
    return ref.watch(settings.provider(telemetryEnabledSettingDef));
  } catch (e, stackTrace) {
    Log.warning(
      'telemetryEnabled read failed, defaulting to true',
      error: e,
      stackTrace: stackTrace,
    );
    return true;
  }
}

@riverpod
bool notificationsEnabled(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return true;
    return ref.watch(settings.provider(notificationsEnabledSettingDef));
  } catch (e, stackTrace) {
    Log.warning(
      'notificationsEnabled read failed, defaulting to true',
      error: e,
      stackTrace: stackTrace,
    );
    return true;
  }
}

@riverpod
bool expenseFormFullFeatures(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return false;
    return ref.watch(settings.provider(expenseFormFullFeaturesSettingDef));
  } catch (e, stackTrace) {
    Log.warning(
      'expenseFormFullFeatures read failed, defaulting to false',
      error: e,
      stackTrace: stackTrace,
    );
    return false;
  }
}

@riverpod
bool expenseFormExpandDescription(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return false;
    return ref.watch(
      settings.provider(expenseFormExpandDescriptionSettingDef),
    );
  } catch (e, stackTrace) {
    Log.warning(
      'expenseFormExpandDescription read failed, defaulting to false',
      error: e,
      stackTrace: stackTrace,
    );
    return false;
  }
}

@riverpod
bool expenseFormExpandBillBreakdown(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return false;
    return ref.watch(
      settings.provider(expenseFormExpandBillBreakdownSettingDef),
    );
  } catch (e, stackTrace) {
    Log.warning(
      'expenseFormExpandBillBreakdown read failed, defaulting to false',
      error: e,
      stackTrace: stackTrace,
    );
    return false;
  }
}

// --- Home list (home page) ---

@riverpod
String homeListDisplay(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return 'list_separate';
    final v = ref.watch(settings.provider(homeListDisplaySettingDef));
    // Migrate legacy values
    if (v == 'separate') return 'list_separate';
    if (v == 'combined') return 'list_combined';
    return v;
  } catch (e, stackTrace) {
    Log.warning(
      'homeListDisplay read failed, defaulting to list_separate',
      error: e,
      stackTrace: stackTrace,
    );
    return 'list_separate';
  }
}

@riverpod
String homeListSort(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return 'updated_at';
    return ref.watch(settings.provider(homeListSortSettingDef));
  } catch (e, stackTrace) {
    Log.warning(
      'homeListSort read failed, defaulting to updated_at',
      error: e,
      stackTrace: stackTrace,
    );
    return 'updated_at';
  }
}

@riverpod
String homeListCustomOrder(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return '';
    return ref.watch(settings.provider(homeListCustomOrderSettingDef));
  } catch (e, stackTrace) {
    Log.warning(
      'homeListCustomOrder read failed, defaulting to empty',
      error: e,
      stackTrace: stackTrace,
    );
    return '';
  }
}

@riverpod
String homeListPinnedIds(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return '';
    return ref.watch(settings.provider(homeListPinnedIdsSettingDef));
  } catch (e, stackTrace) {
    Log.warning(
      'homeListPinnedIds read failed, defaulting to empty',
      error: e,
      stackTrace: stackTrace,
    );
    return '';
  }
}

@riverpod
bool homeListShowCreatedAt(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return false;
    return ref.watch(settings.provider(homeListShowCreatedAtSettingDef));
  } catch (e, stackTrace) {
    Log.warning(
      'homeListShowCreatedAt read failed, defaulting to false',
      error: e,
      stackTrace: stackTrace,
    );
    return false;
  }
}
