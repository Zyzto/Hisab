import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:integration_test/integration_test.dart';
import 'package:powersync/powersync.dart';

import 'package:hisab/app.dart';
import 'package:hisab/core/database/database_providers.dart';
import 'package:hisab/core/debug/integration_test_mode.dart';
import 'package:hisab/core/database/powersync_schema.dart' as ps;
import 'package:hisab/features/settings/providers/settings_framework_providers.dart';
import 'package:hisab/features/settings/settings_definitions.dart';

import 'test_db_path.dart';

String? _lastBootstrapFailureReason;

/// Last bootstrap failure reason captured by [runIntegrationTestApp].
/// Null means the last bootstrap attempt succeeded.
String? get lastBootstrapFailureReason => _lastBootstrapFailureReason;

/// Record a bootstrap error into [IntegrationTestWidgetsFlutterBinding.reportData]
/// so the test_driver can print it (debugPrint is invisible on web).
void _recordBootstrapError(String error) {
  _lastBootstrapFailureReason = error;
  debugPrint(error);
  try {
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    binding.reportData ??= <String, dynamic>{};
    final log = (binding.reportData!['stage_log'] as List<dynamic>?) ?? [];
    log.add('[bootstrap] ERROR: $error');
    binding.reportData!['stage_log'] = log;
    binding.reportData!['last_stage'] = '[bootstrap] ERROR: $error';
    binding.reportData!['bootstrap_error'] = error;
  } catch (_) {}
}

/// Initializes the app for integration tests: EasyLocalization, temp PowerSync
/// DB, and settings (local-only mode, optionally skip onboarding).
///
/// Does not initialize Supabase, Firebase, or LoggingService.
///
/// Returns `true` if the app was started successfully, `false` if PowerSync
/// or settings init failed (e.g. PowerSync binary unavailable).
///
/// Set [skipOnboarding] to `false` to exercise the onboarding flow.
Future<bool> runIntegrationTestApp({bool skipOnboarding = true}) async {
  _lastBootstrapFailureReason = null;
  try {
    await EasyLocalization.ensureInitialized();
  } catch (e, st) {
    _recordBootstrapError('EasyLocalization init failed: $e\n$st');
    return false;
  }
  EasyLocalization.logger.enableBuildModes = [];

  SettingsProviders? settingsProviders;
  try {
    settingsProviders = await initializeHisabSettings();
  } catch (e, st) {
    _recordBootstrapError('Settings init failed: $e\n$st');
    return false;
  }

  if (settingsProviders != null) {
    if (skipOnboarding) {
      settingsProviders.controller.set(onboardingCompletedSettingDef, true);
    } else {
      settingsProviders.controller.set(onboardingCompletedSettingDef, false);
    }
    settingsProviders.controller.set(localOnlySettingDef, true);
    settingsProviders.controller.set(languageSettingDef, 'en');
  }

  PowerSyncDatabase db;
  String? dbPath;
  try {
    dbPath = await integrationTestDbPath();
    db = PowerSyncDatabase(schema: ps.schema, path: dbPath);
    await db.initialize();
  } catch (e, st) {
    _recordBootstrapError(
      'PowerSync init failed (path: ${dbPath ?? "unknown"}): $e\n$st',
    );
    return false;
  }

  final startLocale = settingsProviders != null
      ? Locale(settingsProviders.controller.get(languageSettingDef))
      : const Locale('en');

  isIntegrationTestMode = true;
  final appWidget = EasyLocalization(
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
  );

  // Android benefits from a small delayed re-mount between tests to avoid
  // duplicate key races while overlays are tearing down. Web can mount
  // immediately; delaying there can cause bootstrap races under flutter drive.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        runApp(appWidget);
      });
    });
  } else {
    runApp(appWidget);
  }

  return true;
}
