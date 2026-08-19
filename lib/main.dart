import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hisab_backend/hisab_backend.dart';
import 'package:hisab_cloud/hisab_cloud.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase, Schema;

import 'core/auth/auth_flow_policy.dart';
import 'core/auth/auth_pending_finalize.dart';
import 'core/auth/oauth_callback_state.dart';
import 'core/auth/oauth_web_url.dart';
import 'core/constants/firebase_config.dart';
import 'core/database/database_providers.dart';
import 'core/debug/marionette_binding.dart';
import 'core/log_web.dart';
import 'core/navigation/decorative_route.dart';
import 'core/database/delete_db_file.dart';
import 'core/image_picker_init.dart';
import 'core/database/powersync_schema.dart' as ps;
import 'core/services/notification_service.dart';
import 'core/settings/initial_language.dart';
import 'core/settings/providers/settings_framework_providers.dart';
import 'core/settings/settings_definitions.dart';
import 'app.dart';

/// Web accessibility semantics are expensive on iOS Safari.
/// Keep disabled by default and allow explicit opt-in per build.
const bool enableWebSemantics = bool.fromEnvironment(
  'ENABLE_WEB_SEMANTICS',
  defaultValue: false,
);

void main() {
  // Default is false: context.push (group, expense, …) would not update the
  // browser address bar. Hisab relies on push for stack navigation on web.
  if (kIsWeb) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
  }

  runZonedGuarded(
    () async {
      void setupErrorHandlers() {
        FlutterError.onError = (FlutterErrorDetails details) {
          final msg = details.exception.toString();
          if (kIsWeb &&
              (msg.contains('EngineFlutterView') && msg.contains('disposed'))) {
            Log.debug(
              'Suppressed known web error: render on disposed view (e.g. after hot restart)',
            );
            return;
          }
          FlutterError.presentError(details);
          // Include a short stack in the message so logcat (which often omits
          // the stackTrace field) still shows the overflowing widget tree.
          final stack = details.stack;
          final stackHint = stack == null
              ? ''
              : '\n${stack.toString().split('\n').take(12).join('\n')}';
          LoggingService.severe(
            'Flutter framework error: ${details.exception}$stackHint',
            component: 'CrashHandler',
            error: details.exception,
            stackTrace: details.stack,
          );
        };
        PlatformDispatcher.instance.onError = (error, stack) {
          if (kIsWeb &&
              error is TypeError &&
              error.toString().contains('LegacyJavaScriptObject') &&
              error.toString().contains('UpdateNotification')) {
            return true;
          }
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
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return Material(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      details.exceptionAsString(),
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        };
      }

      Future<void> runRestOfMain() async {
        // Clear pathname/hash hybrids (e.g. `/settings#/groups/...`) before
        // GoRouter binds so address-bar updates work again on web.
        if (kIsWeb) sanitizeHashStrategyBrowserUrl();

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
          Log.info(
            'main: EasyLocalization skipped (timeout), using fallback locale',
          );
        }

        // Use Android Photo Picker for gallery (no READ_MEDIA_IMAGES required).
        initImagePicker();

        final settingsProviders = await initializeHisabSettings();
        if (settingsProviders != null) {
          Log.info('main: Settings framework initialized');
        } else {
          Log.warning(
            'main: Settings framework init returned null, using defaults',
          );
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
        // Cloud backend (present only in a build that bundles one)
        // --------------------------------------------------------------------------
        Log.info('main: Registering cloud backend...');
        await registerHisabCloud();
        final backend = cloudBackend;
        if (backend != null) {
          // Capture before initialize(): detectSessionInUri consumes `?code=`.
          final fromAuthCallback = kIsWeb && _currentUriIsAuthCallback();
          await backend.initialize();
          Log.info('main: Cloud backend initialized');

          if (kIsWeb) {
            await _finalizeWebOAuthReturn();
          }

          if (settingsProviders != null) {
            final hasSession = backend.auth.isAuthenticated;

            // Pending OAuth / magic-link redirects (web reload or cold start).
            finalizePendingOnlineAuth(
              controller: settingsProviders.controller,
              hasSession: hasSession,
              fromAuthCallback: fromAuthCallback,
              clearWhenNoSession: true,
            );

            // If previously online but no session on startup, do NOT force
            // local-only. On web, the session may recover asynchronously after
            // a token refresh. Forcing local-only permanently overwrites the
            // user's preference and requires them to manually switch back.
            // Instead, keep the online preference — the DataSyncService already
            // handles "online but not authenticated" by pausing sync, and the
            // account UI shows a re-authenticate prompt.
            final localOnly = settingsProviders.controller.get(
              localOnlySettingDef,
            );
            if (!localOnly && !hasSession) {
              Log.info(
                'Online mode active but no session yet — '
                'user can re-authenticate from settings',
              );
            }
          }
        } else {
          Log.info('main: No cloud backend — running in local-only mode');
        }

        // --------------------------------------------------------------------------
        // Firebase (for push notifications — only when a backend is present)
        // --------------------------------------------------------------------------
        if (cloudAvailable) {
          try {
            Log.info('main: Initializing Firebase...');
            if (kIsWeb) {
              final options = firebaseOptionsForWeb;
              if (options != null) {
                await Firebase.initializeApp(options: options);
                firebaseInitialized = true;
                FirebaseMessaging.onBackgroundMessage(
                  firebaseMessagingBackgroundHandler,
                );
                Log.info('main: Firebase initialized');
              } else {
                Log.info(
                  'main: Firebase web options missing (push notifications disabled on web)',
                );
              }
            } else {
              await Firebase.initializeApp();
              firebaseInitialized = true;
              FirebaseMessaging.onBackgroundMessage(
                firebaseMessagingBackgroundHandler,
              );
              Log.info('main: Firebase initialized');
            }
          } catch (e, st) {
            Log.warning(
              'main: Firebase init failed (push notifications disabled)',
              error: e,
              stackTrace: st,
            );
          }
        }

        // --------------------------------------------------------------------------
        // Run app — EasyLocalization stays mounted (no key change) to avoid
        // setState-after-dispose from its async asset loading. We sync locale
        // by calling setLocale when languageProvider changes (_LocaleSync).
        //
        // Language: follow the device language on first launch (en/ar). Once the
        // user picks a language (or we seed from the platform), that stored value
        // wins until they change it or reset settings.
        // --------------------------------------------------------------------------
        if (settingsProviders != null && easyLocalizationReady) {
          await seedLanguageFromPlatformIfUnset(settingsProviders.controller);
        }
        final startLocale = easyLocalizationReady && settingsProviders != null
            ? Locale(settingsProviders.controller.get(languageSettingDef))
            : Locale(
                resolveInitialLanguageCode(
                  platformLanguageCode: readPlatformUiLanguageCode(),
                ),
              );

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
          Log.info('main: Web semantics enabled via ENABLE_WEB_SEMANTICS=true');
        } else if (kIsWeb) {
          Log.info(
            'main: Web semantics disabled by default (set ENABLE_WEB_SEMANTICS=true to enable)',
          );
        }
      }

      if (kIsWeb) {
        await runZoned(
          () async {
            ensureHisabWidgetsBinding();
            initWebLogCapture();
            setupErrorHandlers();
            await runRestOfMain();
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
        setupErrorHandlers();
        await runRestOfMain();
      }
    },
    (error, stack) {
      if (kIsWeb &&
          error is TypeError &&
          error.toString().contains('LegacyJavaScriptObject') &&
          error.toString().contains('UpdateNotification')) {
        return;
      }
      // Log stack for NoSuchMethodError / dart_rti so we can trace web-only failures.
      if (error is NoSuchMethodError ||
          (error.toString().contains('dart_rti') ||
              error.toString().contains('non-function'))) {
        Log.error(
          'Zone error (see stack trace for location)',
          error: error,
          stackTrace: stack,
        );
      }
      PlatformDispatcher.instance.onError?.call(error, stack);
    },
  );
}

bool _currentUriIsAuthCallback() {
  final uri = currentWebLocationUri();
  return uri != null && uriLooksLikeAuthCallback(uri);
}

/// Happy path: the backend already exchanged `?code=` during `initialize()` and
/// set a session — this only cleans the URL (idempotent) and returns.
///
/// Failure path (e.g. flaky iOS Firefox): if auth params remain and there is
/// still no session, ask the backend to retry once with a timeout, surface a
/// toast, then clear the URL so a refresh does not reuse a spent code.
Future<void> _finalizeWebOAuthReturn() async {
  final uri = currentWebLocationUri();
  if (uri == null) return;

  if (!uriLooksLikeAuthCallback(uri)) return;

  final auth = cloudBackend?.auth;
  if (auth == null) return;

  if (auth.isAuthenticated) {
    clearWebAuthCallbackParams();
    return;
  }

  Log.info('main: Stock auth recovery left no session; retrying once (web)');
  try {
    await auth.completeWebRedirect().timeout(const Duration(seconds: 20));
    if (auth.isAuthenticated) {
      Log.info('main: Auth callback session recovered on retry');
    } else {
      Log.warning('main: Auth callback retry finished without a session');
      pendingWebOAuthCallbackError = 'auth_oauth_callback_failed';
    }
  } on TimeoutException catch (e, st) {
    // .timeout does not cancel the request; only toast if still signed out.
    if (auth.isAuthenticated) {
      Log.info('main: Auth callback session arrived after retry timeout');
    } else {
      Log.warning(
        'main: Auth callback session retry timed out',
        error: e,
        stackTrace: st,
      );
      pendingWebOAuthCallbackError = 'auth_oauth_timeout';
    }
  } catch (e, st) {
    if (auth.isAuthenticated) return;
    Log.warning(
      'main: Auth callback session retry failed',
      error: e,
      stackTrace: st,
    );
    pendingWebOAuthCallbackError = 'auth_oauth_callback_failed';
  } finally {
    clearWebAuthCallbackParams();
  }
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
    String languageCode;
    try {
      languageCode = ref.watch(languageProvider);
    } catch (e, st) {
      Log.warning(
        '_LocaleSync: languageProvider read failed',
        error: e,
        stackTrace: st,
      );
      languageCode = 'en';
    }
    if (context.locale.languageCode != languageCode) {
      final locale = Locale(languageCode);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        try {
          context.setLocale(locale);
        } catch (e, st) {
          Log.warning(
            '_LocaleSync: setLocale failed',
            error: e,
            stackTrace: st,
          );
        }
      });
    }
    return child;
  }
}
