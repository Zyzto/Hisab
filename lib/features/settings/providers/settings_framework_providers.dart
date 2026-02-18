import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import '../settings_definitions.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_user_profile.dart';
import '../../../core/constants/supabase_config.dart';

part 'settings_framework_providers.g.dart';

/// App-owned provider for [SettingsProviders]. Override in main with the result of [initializeHisabSettings].
/// Use this in UI (e.g. settings page) to avoid depending on the framework's provider symbol.
@riverpod
SettingsProviders? hisabSettingsProviders(Ref ref) => null;

Future<SettingsProviders?> initializeHisabSettings() async {
  try {
    final registry = createHisabSettingsRegistry();
    final storage = SharedPreferencesStorage();
    return await initializeSettings(registry: registry, storage: storage);
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

