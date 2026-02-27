import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:path/path.dart' as path;
import 'package:powersync/powersync.dart';

import 'package:hisab/app.dart';
import 'package:hisab/core/database/database_providers.dart';
import 'package:hisab/core/database/powersync_schema.dart' as ps;
import 'package:hisab/features/settings/providers/settings_framework_providers.dart';
import 'package:hisab/features/settings/settings_definitions.dart';

/// Initializes the app for integration tests: binding, EasyLocalization,
/// temp PowerSync DB, and settings (onboarding completed, local-only).
/// Does not initialize Supabase, Firebase, or LoggingService.
///
/// Returns [true] if the app was started successfully, [false] if PowerSync
/// or settings init failed (e.g. PowerSync binary unavailable); tests can skip.
Future<bool> runIntegrationTestApp() async {
  try {
    await EasyLocalization.ensureInitialized();
  } catch (_) {
    return false;
  }
  EasyLocalization.logger.enableBuildModes = [];

  SettingsProviders? settingsProviders;
  try {
    settingsProviders = await initializeHisabSettings();
  } catch (_) {
    return false;
  }

  // Ensure we land on home (skip onboarding) and use local-only mode.
  if (settingsProviders != null) {
    settingsProviders.controller.set(onboardingCompletedSettingDef, true);
    settingsProviders.controller.set(localOnlySettingDef, true);
  }

  PowerSyncDatabase db;
  try {
    final dbPath = path.join(
      Directory.systemTemp.path,
      'hisab_integration_${DateTime.now().millisecondsSinceEpoch}.db',
    );
    db = PowerSyncDatabase(schema: ps.schema, path: dbPath);
    await db.initialize();
  } catch (_) {
    return false;
  }

  final startLocale =
      settingsProviders != null
          ? Locale(settingsProviders.controller.get(languageSettingDef))
          : const Locale('en');

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
