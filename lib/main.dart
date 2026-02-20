import 'dart:async';
import 'dart:ui' as ui;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase, Schema;
import 'package:pwa_install/pwa_install.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_config.dart';
import 'core/database/database_providers.dart';
import 'core/database/delete_db_file.dart';
import 'core/image_picker_init.dart';
import 'core/database/powersync_schema.dart' as ps;
import 'core/services/notification_service.dart';
import 'features/settings/providers/settings_framework_providers.dart';
import 'features/settings/settings_definitions.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // PWA install prompt (web only)
  if (kIsWeb) {
    PWAInstall().setup(installCallback: () {
      debugPrint('PWA installed!');
    });
  }

  // Log framework and async errors before logging service is ready
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    LoggingService.severe(
      'Flutter framework error: ${details.exception}',
      component: 'CrashHandler',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    // Known web issue: PowerSync/sqlite3_web can emit LegacyJavaScriptObject
    // in internal streams where Dart expects UpdateNotification. We use
    // polling instead of watch() on web, but the SDK may still create
    // internal listeners. Suppress this specific error from surfacing.
    if (kIsWeb &&
        error is TypeError &&
        error.toString().contains('LegacyJavaScriptObject') &&
        error.toString().contains('UpdateNotification')) {
      Log.debug(
        'Suppressed known web stream type error (PowerSync/sqlite3_web): $error',
      );
      return true;
    }
    // Firebase not initialized: native plugins may fire async events even
    // after Firebase.initializeApp() failed. The root failure is already
    // logged as a warning; suppress the cascading [core/no-app] noise.
    if (error.toString().contains('[core/no-app]')) {
      Log.debug(
        'Suppressed Firebase [core/no-app] (Firebase not initialized)',
      );
      return true;
    }
    LoggingService.severe(
      'Uncaught async error: $error',
      component: 'CrashHandler',
      error: error,
      stackTrace: stack,
    );
    return true;
  };

  await LoggingService.init(
    const LoggingConfig(
      appName: 'Hisab',
      logFileName: 'hisab.log',
      crashLogFileName: 'hisab_crashes.log',
    ),
  );
  Log.info('main: LoggingService initialized');

  // Timeout to avoid release hang if asset loading never completes (e.g. release bundle)
  bool easyLocalizationReady = false;
  const easyLocalizationTimeout = Duration(seconds: 15);
  try {
    await EasyLocalization.ensureInitialized().timeout(
      easyLocalizationTimeout,
      onTimeout: () {
        throw TimeoutException(
          'EasyLocalization.ensureInitialized()',
          easyLocalizationTimeout,
        );
      },
    );
    easyLocalizationReady = true;
  } on TimeoutException catch (e) {
    Log.warning(
      'main: EasyLocalization.ensureInitialized() timed out after ${e.duration?.inSeconds ?? 15}s, using fallback locale',
    );
  }
  // Reduce console noise from easy_localization [DEBUG] / [INFO] messages
  EasyLocalization.logger.enableBuildModes = [];
  if (easyLocalizationReady) {
    Log.info('main: EasyLocalization initialized');
  } else {
    Log.info('main: EasyLocalization skipped (timeout), using fallback locale');
  }

  // Use Android Photo Picker for gallery (no READ_MEDIA_IMAGES required).
  initImagePicker();

  final settingsProviders = await initializeHisabSettings();
  if (settingsProviders != null) {
    Log.info('main: Settings framework initialized');
  } else {
    Log.warning('main: Settings framework init returned null, using defaults');
  }

  // --------------------------------------------------------------------------
  // Local SQLite database (always initialized — works offline)
  // --------------------------------------------------------------------------
  Log.info('main: Opening PowerSync database...');
  final dbPath = kIsWeb
      ? 'hisab.db'
      : join((await getApplicationDocumentsDirectory()).path, 'hisab.db');
  final db = await _initializePowerSyncDatabase(ps.schema, dbPath);
  Log.info('main: PowerSync database initialized (local SQLite)');

  // --------------------------------------------------------------------------
  // Supabase (ONLY if configured via --dart-define)
  // --------------------------------------------------------------------------
  if (supabaseConfigAvailable) {
    Log.info('main: Initializing Supabase...');
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    Log.info('main: Supabase client initialized');

    if (settingsProviders != null) {
      final session = Supabase.instance.client.auth.currentSession;

      // Handle pending OAuth redirects (web only — page reloaded after redirect)
      final onboardingPending = settingsProviders.controller.get(
        onboardingOnlinePendingSettingDef,
      );
      final settingsPending = settingsProviders.controller.get(
        settingsOnlinePendingSettingDef,
      );

      if (onboardingPending && session != null) {
        // OAuth completed after onboarding redirect
        settingsProviders.controller.set(
          onboardingOnlinePendingSettingDef,
          false,
        );
        settingsProviders.controller.set(localOnlySettingDef, false);
        settingsProviders.controller.set(onboardingCompletedSettingDef, true);
        Log.info('Completed pending onboarding OAuth redirect');
      } else if (onboardingPending && session == null) {
        // OAuth was started but failed/cancelled
        settingsProviders.controller.set(
          onboardingOnlinePendingSettingDef,
          false,
        );
        Log.info('Cleared failed onboarding OAuth redirect');
      }

      if (settingsPending && session != null) {
        // OAuth completed after settings redirect
        settingsProviders.controller.set(
          settingsOnlinePendingSettingDef,
          false,
        );
        settingsProviders.controller.set(localOnlySettingDef, false);
        Log.info('Completed pending settings OAuth redirect');
      } else if (settingsPending && session == null) {
        // OAuth was started but failed/cancelled
        settingsProviders.controller.set(
          settingsOnlinePendingSettingDef,
          false,
        );
        Log.info('Cleared failed settings OAuth redirect');
      }

      // If previously online but no session on startup, do NOT force
      // local-only. On web, the session may recover asynchronously after
      // a token refresh. Forcing local-only permanently overwrites the
      // user's preference and requires them to manually switch back.
      // Instead, keep the online preference — the DataSyncService already
      // handles "online but not authenticated" by pausing sync, and the
      // account UI shows a re-authenticate prompt.
      final localOnly = settingsProviders.controller.get(localOnlySettingDef);
      if (!localOnly && session == null) {
        Log.info(
          'Online mode active but no session yet — '
          'user can re-authenticate from settings',
        );
      }
    }
  } else {
    Log.info('main: Supabase not configured — running in local-only mode');
  }

  // --------------------------------------------------------------------------
  // Firebase (for push notifications — only if Supabase is configured)
  // --------------------------------------------------------------------------
  if (supabaseConfigAvailable) {
    try {
      Log.info('main: Initializing Firebase...');
      await Firebase.initializeApp();
      firebaseInitialized = true;
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
      Log.info('main: Firebase initialized');
    } catch (e, st) {
      Log.warning('main: Firebase init failed (push notifications disabled)',
          error: e, stackTrace: st);
    }
  }

  // --------------------------------------------------------------------------
  // Run app — EasyLocalization stays mounted (no key change) to avoid
  // setState-after-dispose from its async asset loading. We sync locale
  // by calling setLocale when languageProvider changes (_LocaleSync).
  // First initial language (onboarding, default): system locale if supported, else English.
  // --------------------------------------------------------------------------
  if (settingsProviders != null &&
      easyLocalizationReady &&
      !settingsProviders.controller.get(onboardingCompletedSettingDef) &&
      settingsProviders.controller.get(languageSettingDef) == 'en') {
    final resolved = ui.PlatformDispatcher.instance
        .computePlatformResolvedLocale(const [
      Locale('en'),
      Locale('ar'),
    ]);
    if (resolved != null) {
      settingsProviders.controller.set(languageSettingDef, resolved.languageCode);
    }
  }
  final startLocale = easyLocalizationReady && settingsProviders != null
      ? Locale(settingsProviders.controller.get(languageSettingDef))
      : const Locale('en');

  Log.info('main: Starting app (runApp)');
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
        child: const _LocaleSync(child: App()),
      ),
    ),
  );
}

/// Initialize PowerSync DB. On failure (e.g. schema mismatch from upgrade),
/// deletes the DB file and retries once when not on web (schema recovery).
Future<PowerSyncDatabase> _initializePowerSyncDatabase(
  Schema schema,
  String dbPath,
) async {
  var db = PowerSyncDatabase(schema: schema, path: dbPath);
  try {
    await db.initialize();
    return db;
  } catch (e, st) {
    Log.warning(
      'main: PowerSync db.initialize() failed (will retry after DB reset)',
      error: e,
      stackTrace: st,
    );
    if (!kIsWeb) {
      try {
        await deleteDbFile(dbPath);
        Log.info('main: Deleted existing DB file for schema recovery');
        db = PowerSyncDatabase(schema: schema, path: dbPath);
        await db.initialize();
        return db;
      } catch (e2, st2) {
        Log.error(
          'main: PowerSync re-initialization after DB delete failed',
          error: e2,
          stackTrace: st2,
        );
        rethrow;
      }
    } else {
      rethrow;
    }
  }
}

/// Keeps Easy Localization's locale in sync with [languageProvider].
/// Single place that calls setLocale to avoid RTL/LTR flicker and double updates.
class _LocaleSync extends ConsumerWidget {
  const _LocaleSync({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageCode = ref.watch(languageProvider);
    if (context.locale.languageCode != languageCode) {
      final locale = Locale(languageCode);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.setLocale(locale);
      });
    }
    return child;
  }
}
