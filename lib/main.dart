import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:convex_flutter/convex_flutter.dart';
import 'core/auth/auth_service.dart';
import 'core/constants/convex_config.dart';
import 'features/settings/providers/settings_framework_providers.dart';
import 'features/settings/settings_definitions.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress convex_flutter WebConvexClient verbose logs (Ping/Pong, RAW MESSAGE, etc.)
  final oldDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null && message.contains('[WebConvexClient]')) return;
    oldDebugPrint(message, wrapWidth: wrapWidth);
  };

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
    LoggingService.severe(
      'Uncaught async error: $error',
      component: 'CrashHandler',
      error: error,
      stackTrace: stack,
    );
    return true;
  };

  if (!kIsWeb) {
    await LoggingService.init(
      const LoggingConfig(
        appName: 'Hisab',
        logFileName: 'hisab.log',
        crashLogFileName: 'hisab_crashes.log',
      ),
    );
  }

  await EasyLocalization.ensureInitialized();
  // Reduce console noise from easy_localization [DEBUG] / [INFO] messages
  EasyLocalization.logger.enableBuildModes = [];
  Log.debug('Easy Localization initialized');

  if (convexDeploymentUrl.isNotEmpty) {
    try {
      await ConvexClient.initialize(
        // ignore: prefer_const_constructors - deploymentUrl is a variable
        ConvexConfig(deploymentUrl: convexDeploymentUrl, clientId: 'hisab-1.0'),
      );
      Log.debug('Convex client initialized');
    } catch (e, stackTrace) {
      Log.error(
        'Convex client initialization failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  final settingsProviders = await initializeHisabSettings();
  if (settingsProviders != null) {
    Log.debug('Settings framework initialized');

    // Web: process Auth0 redirect callback; if returning from sign-in with pending onboarding, complete it
    if (kIsWeb && auth0ConfigAvailable) {
      final credentials = await auth0OnLoad();
      if (credentials != null) {
        final pending = settingsProviders.controller.get(onboardingOnlinePendingSettingDef);
        if (pending == true) {
          settingsProviders.controller.set(onboardingCompletedSettingDef, true);
          settingsProviders.controller.set(onboardingOnlinePendingSettingDef, false);
          Log.info('Onboarding completed after Auth0 redirect');
        }
      }
    }
  } else {
    Log.warning('Settings framework init returned null, using defaults');
  }

  // Use saved language from settings; we persist via our settings, not EasyLocalization
  final startLocale = settingsProviders != null
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
}
