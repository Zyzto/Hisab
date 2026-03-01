import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:hisab/app.dart';
import 'package:hisab/core/constants/supabase_config.dart';
import 'package:hisab/core/debug/integration_test_mode.dart';
import 'package:hisab/core/database/database_providers.dart';
import 'package:hisab/core/database/powersync_schema.dart' as ps;
import 'package:hisab/features/settings/providers/settings_framework_providers.dart';
import 'package:hisab/features/settings/settings_definitions.dart';

import 'test_db_path.dart';

const testUserAEmail = 'test-a@hisab.test';
const testUserBEmail = 'test-b@hisab.test';
const testPassword = 'TestPass123!';

/// Initializes the app for online integration tests.
///
/// Unlike [runIntegrationTestApp], this:
/// - Initializes Supabase with local project URL + anon key
/// - Does NOT set localOnlySettingDef to true (online mode)
/// - Optionally signs in with a test user and skips onboarding
///
/// Requires `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_ANON_KEY=...`.
///
/// Returns `true` on success, `false` if init failed.
Future<bool> runOnlineTestApp({
  bool skipOnboarding = true,
  String? signInEmail,
  String? signInPassword,
}) async {
  if (!supabaseConfigAvailable) {
    return false;
  }

  try {
    await EasyLocalization.ensureInitialized();
  } catch (_) {
    return false;
  }
  EasyLocalization.logger.enableBuildModes = [];

  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  } catch (_) {
    // Already initialized (e.g. re-run in same process) – ignore
  }

  if (signInEmail != null && signInPassword != null) {
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: signInEmail,
        password: signInPassword,
      );
    } catch (e) {
      // Sign-in failure is not necessarily fatal for the bootstrap
      debugPrint('Online bootstrap sign-in failed: $e');
    }
  }

  SettingsProviders? settingsProviders;
  try {
    settingsProviders = await initializeHisabSettings();
  } catch (_) {
    return false;
  }

  if (settingsProviders != null) {
    settingsProviders.controller.set(localOnlySettingDef, false);
    if (skipOnboarding) {
      settingsProviders.controller.set(onboardingCompletedSettingDef, true);
    } else {
      settingsProviders.controller.set(onboardingCompletedSettingDef, false);
    }
  }

  PowerSyncDatabase db;
  try {
    final dbPath = await integrationTestDbPath();
    db = PowerSyncDatabase(schema: ps.schema, path: dbPath);
    await db.initialize();
  } catch (_) {
    return false;
  }

  final startLocale = settingsProviders != null
      ? Locale(settingsProviders.controller.get(languageSettingDef))
      : const Locale('en');

  isIntegrationTestMode = true;
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: startLocale,
      saveLocale: false,
      child: ProviderScope(
        overrides: [
          powerSyncDatabaseProvider.overrideWithValue(db),
          if (settingsProviders != null) ...[
            settingsControllerProvider.overrideWithValue(
              settingsProviders.controller,
            ),
            settingsSearchIndexProvider.overrideWithValue(
              settingsProviders.searchIndex,
            ),
            settingsProvidersProvider.overrideWithValue(settingsProviders),
            hisabSettingsProvidersProvider.overrideWithValue(settingsProviders),
          ],
        ],
        child: const App(),
      ),
    ),
  );

  return true;
}

/// Sign out the current user. Safe to call when no one is signed in.
Future<void> signOutCurrentUser() async {
  try {
    await Supabase.instance.client.auth.signOut();
  } catch (_) {}
}

/// Sign in with the given credentials. Returns true on success.
Future<bool> signInAs(String email, String password) async {
  try {
    await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return true;
  } catch (_) {
    return false;
  }
}
