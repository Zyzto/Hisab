import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
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
String _lastOnlineBootstrapFailureReason = '';

String get lastOnlineBootstrapFailureReason => _lastOnlineBootstrapFailureReason;

void _setOnlineBootstrapFailureReason(String message) {
  _lastOnlineBootstrapFailureReason = message;
  debugPrint('Online bootstrap failed: $message');
}

String _effectiveSupabaseUrlForDevice(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  // Android emulator cannot reach host loopback via 127.0.0.1/localhost.
  if (defaultTargetPlatform == TargetPlatform.android &&
      (uri.host == '127.0.0.1' || uri.host == 'localhost')) {
    return uri.replace(host: '10.0.2.2').toString();
  }
  return url;
}

bool _isInvalidCredentialsError(Object error) {
  if (error is AuthException) {
    final code = error.code?.toLowerCase() ?? '';
    final message = error.message.toLowerCase();
    return code == 'invalid_credentials' ||
        message.contains('invalid login credentials');
  }
  return false;
}

Future<bool> _ensureUserSession(String email, String password) async {
  final auth = Supabase.instance.client.auth;
  try {
    await auth.signInWithPassword(email: email, password: password);
    return true;
  } catch (e) {
    if (!_isInvalidCredentialsError(e)) {
      _setOnlineBootstrapFailureReason('Sign-in failed for $email: $e');
      return false;
    }
  }

  // If the seeded users are missing, create them and sign in.
  try {
    await auth.signUp(email: email, password: password);
  } catch (e) {
    _setOnlineBootstrapFailureReason(
      'Sign-up failed for missing online test user $email: $e',
    );
    return false;
  }

  try {
    await auth.signInWithPassword(email: email, password: password);
    return true;
  } catch (e) {
    _setOnlineBootstrapFailureReason(
      'Sign-in after sign-up failed for $email: $e',
    );
    return false;
  }
}

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
  _lastOnlineBootstrapFailureReason = '';
  if (!supabaseConfigAvailable) {
    _setOnlineBootstrapFailureReason(
      'Missing SUPABASE_URL or SUPABASE_ANON_KEY dart-define values.',
    );
    return false;
  }

  try {
    await EasyLocalization.ensureInitialized();
  } catch (e) {
    _setOnlineBootstrapFailureReason(
      'EasyLocalization init failed: $e',
    );
    return false;
  }
  EasyLocalization.logger.enableBuildModes = [];

  try {
    final effectiveSupabaseUrl = _effectiveSupabaseUrlForDevice(supabaseUrl);
    await Supabase.initialize(
      url: effectiveSupabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } catch (e) {
    // Already initialized (e.g. re-run in same process) – ignore
    final message = '$e'.toLowerCase();
    if (!message.contains('already initialized')) {
      _setOnlineBootstrapFailureReason('Supabase init failed: $e');
      return false;
    }
  }

  if (signInEmail != null && signInPassword != null) {
    final signedIn = await _ensureUserSession(signInEmail, signInPassword);
    if (!signedIn) {
      return false;
    }
  }

  SettingsProviders? settingsProviders;
  try {
    settingsProviders = await initializeHisabSettings();
  } catch (e) {
    _setOnlineBootstrapFailureReason('Settings init failed: $e');
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
  } catch (e) {
    _setOnlineBootstrapFailureReason(
      'PowerSync init failed (db path or native binary issue): $e',
    );
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
  return _ensureUserSession(email, password);
}
