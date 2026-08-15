import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

import 'settings_definitions.dart';

/// Supported UI language codes (keep in sync with EasyLocalization locales).
const List<String> kSupportedLanguageCodes = ['en', 'ar'];

/// Supported [Locale]s for [PlatformDispatcher.computePlatformResolvedLocale].
const List<Locale> kSupportedUiLocales = [Locale('en'), Locale('ar')];

/// Picks the initial language when the user has not stored a preference yet.
///
/// Prefer [platformLanguageCode] when it is supported; otherwise English.
String resolveInitialLanguageCode({
  required String? platformLanguageCode,
  List<String> supported = kSupportedLanguageCodes,
  String fallback = 'en',
}) {
  final code = platformLanguageCode?.toLowerCase();
  if (code != null && supported.contains(code)) return code;
  return fallback;
}

/// Platform UI language for Hisab (`en` / `ar`), or null if unsupported.
///
/// Uses [PlatformDispatcher.computePlatformResolvedLocale] first, then the
/// raw device locale language code.
String? readPlatformUiLanguageCode([PlatformDispatcher? dispatcher]) {
  final d = dispatcher ?? PlatformDispatcher.instance;
  final resolved = d.computePlatformResolvedLocale(kSupportedUiLocales);
  if (resolved != null &&
      kSupportedLanguageCodes.contains(resolved.languageCode)) {
    return resolved.languageCode;
  }
  final raw = d.locale.languageCode.toLowerCase();
  if (kSupportedLanguageCodes.contains(raw)) return raw;
  return null;
}

/// Persist device language when the user has never chosen one.
///
/// Returns the language code now in effect (`en` / `ar`).
Future<String> seedLanguageFromPlatformIfUnset(
  SettingsController controller, {
  String? Function()? platformLanguageCodeReader,
}) async {
  if (controller.hasValue(languageSettingDef)) {
    return controller.get(languageSettingDef);
  }
  final code = resolveInitialLanguageCode(
    platformLanguageCode:
        (platformLanguageCodeReader ?? readPlatformUiLanguageCode)(),
  );
  await controller.set(languageSettingDef, code);
  Log.info('Setting changed: ${languageSettingDef.key}=$code (platform)');
  return code;
}
