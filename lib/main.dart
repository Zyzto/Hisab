import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase, Schema;

import 'app.dart';
import 'core/database/database_providers.dart';
import 'core/debug/crash_error_panel.dart';
import 'core/debug/marionette_binding.dart';
import 'core/image_picker_init.dart';
import 'core/log_web.dart';
import 'core/navigation/decorative_route.dart';
import 'core/database/powersync_schema.dart' as ps;
import 'core/settings/initial_language.dart';
import 'core/settings/providers/settings_framework_providers.dart';
import 'core/settings/settings_definitions.dart';

/// Web accessibility semantics are expensive on iOS Safari.
/// Keep disabled by default and allow explicit opt-in per build.
const bool enableWebSemantics = bool.fromEnvironment(
  'ENABLE_WEB_SEMANTICS',
  defaultValue: false,
);

void main() {
  if (kIsWeb) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
  }

  runZonedGuarded(
    () async {
      _installErrorHandlers();

      Future<void> runAppBootstrap() async {
        if (kIsWeb) sanitizeHashStrategyBrowserUrl();

        await LoggingService.init(
          const LoggingConfig(
            appName: 'Hisab',
            logFileName: 'hisab.log',
            crashLogFileName: 'hisab_crashes.log',
          ),
        );
        Log.info('main: logging initialized');

        var localizationReady = false;
        try {
          await EasyLocalization.ensureInitialized().timeout(
            const Duration(seconds: 15),
          );
          localizationReady = true;
        } on TimeoutException catch (error) {
          Log.warning(
            'main: localization initialization timed out',
            error: error,
          );
        }
        EasyLocalization.logger.enableBuildModes = [];

        initImagePicker();
        final settingsProviders = await initializeHisabSettings();

        final dbPath = kIsWeb
            ? 'hisab.db'
            : join((await getApplicationDocumentsDirectory()).path, 'hisab.db');
        final db = await _initializePowerSyncDatabase(ps.schema, dbPath);
        Log.info('main: local database initialized');

        if (settingsProviders != null) {
          await seedLanguageFromPlatformIfUnset(settingsProviders.controller);
        }
        final startLocale = localizationReady && settingsProviders != null
            ? Locale(settingsProviders.controller.get(languageSettingDef))
            : Locale(
                resolveInitialLanguageCode(
                  platformLanguageCode: readPlatformUiLanguageCode(),
                ),
              );

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
                  settingsProvidersProvider.overrideWithValue(
                    settingsProviders,
                  ),
                  hisabSettingsProvidersProvider.overrideWithValue(
                    settingsProviders,
                  ),
                ],
              ],
              child: const _LocaleSync(child: App()),
            ),
          ),
        );

        if (kIsWeb && enableWebSemantics) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            SemanticsBinding.instance.ensureSemantics();
          });
        }
      }

      if (kIsWeb) {
        await runZoned(
          () async {
            ensureHisabWidgetsBinding();
            initWebLogCapture();
            await runAppBootstrap();
          },
          zoneSpecification: ZoneSpecification(
            print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
              capturePrintLine(line);
              parent.print(zone, line);
            },
          ),
        );
      } else {
        ensureHisabWidgetsBinding();
        await runAppBootstrap();
      }
    },
    (error, stack) {
      LoggingService.severe(
        'Uncaught async error: $error',
        component: 'CrashHandler',
        error: error,
        stackTrace: stack,
      );
    },
  );
}

void _installErrorHandlers() {
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
    LoggingService.severe(
      'Uncaught platform error: $error',
      component: 'CrashHandler',
      error: error,
      stackTrace: stack,
    );
    return true;
  };
  ErrorWidget.builder = (details) =>
      CrashErrorPanel(message: details.exceptionAsString());
}

/// Initialize the local database without deleting an existing database on
/// schema failure. Local records are user data and must remain recoverable.
Future<PowerSyncDatabase> _initializePowerSyncDatabase(
  Schema schema,
  String dbPath,
) async {
  final db = PowerSyncDatabase(schema: schema, path: dbPath);
  await db.initialize();
  return db;
}

class _LocaleSync extends ConsumerWidget {
  const _LocaleSync({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageCode = ref.watch(languageProvider);
    if (context.locale.languageCode != languageCode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.setLocale(Locale(languageCode));
      });
    }
    return child;
  }
}
