import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import '../settings_definitions.dart';

part 'settings_framework_providers.g.dart';

/// App-owned provider for [SettingsProviders]. Override in main with the result of [initializeHisabSettings].
/// Use this in UI (e.g. settings page) to avoid depending on the framework's provider symbol.
final hisabSettingsProvidersProvider = Provider<SettingsProviders?>(
  (ref) => null,
);

Future<SettingsProviders?> initializeHisabSettings() async {
  try {
    final registry = createHisabSettingsRegistry();
    final storage = SharedPreferencesStorage();
    return await initializeSettings(registry: registry, storage: storage);
  } catch (e, stackTrace) {
    Log.warning('Settings init failed, using defaults', error: e, stackTrace: stackTrace);
    return null;
  }
}

@riverpod
bool localOnly(Ref ref) {
  try {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return true;
    return ref.watch(settings.provider(localOnlySettingDef));
  } catch (e, stackTrace) {
    Log.warning('localOnly read failed, defaulting to true', error: e, stackTrace: stackTrace);
    return true;
  }
}
