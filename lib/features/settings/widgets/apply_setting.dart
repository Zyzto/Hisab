import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

/// Persist a setting and log failures. Prefer this over fire-and-forget `.set()`.
Future<bool> applySetting<T>(
  WidgetRef ref,
  SettingsProviders settings,
  SettingDefinition<T> setting,
  T value,
) async {
  try {
    final ok = await ref.read(settings.provider(setting).notifier).set(value);
    if (ok) {
      Log.info('Setting changed: ${setting.key}=$value');
    } else {
      Log.warning('Setting rejected: ${setting.key}=$value');
    }
    return ok;
  } catch (e, st) {
    Log.warning(
      'Setting update failed: ${setting.key}',
      error: e,
      stackTrace: st,
    );
    return false;
  }
}
