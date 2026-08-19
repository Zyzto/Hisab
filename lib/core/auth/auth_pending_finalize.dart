import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

import '../settings/settings_definitions.dart';

/// Completes onboarding/settings flows that were interrupted by OAuth or
/// magic-link redirects once a session is available.
///
/// Safe to call from [main] (cold start / web reload) and from an auth-state
/// listener (native warm resume). Idempotent when flags are already clear.
///
/// When [clearWhenNoSession] is true (startup only), pending flags are cleared
/// if there is still no session — treating the redirect as abandoned. Warm
/// resume must pass false so flags survive until the deep-link session arrives.
///
/// [fromAuthCallback] is true when this load started as an OAuth / magic-link
/// return (`?code=`). Web OAuth navigates away before the pending flags can be
/// flushed, so a session on that return must still finish onboarding / online.
void finalizePendingOnlineAuth({
  required SettingsController controller,
  required bool hasSession,
  bool clearWhenNoSession = false,
  bool fromAuthCallback = false,
}) {
  final onboardingPending = controller.get(onboardingOnlinePendingSettingDef);
  final settingsPending = controller.get(settingsOnlinePendingSettingDef);
  final onboardingCompleted = controller.get(onboardingCompletedSettingDef);

  final finishOnboarding =
      hasSession &&
      (onboardingPending || (fromAuthCallback && !onboardingCompleted));
  if (finishOnboarding) {
    controller.set(onboardingOnlinePendingSettingDef, false);
    controller.set(localOnlySettingDef, false);
    controller.set(onboardingCompletedSettingDef, true);
    Log.info(
      'Setting changed: onboarding auth-pending flags cleared, '
      'local_only=false, onboarding_completed=true',
    );
  } else if (onboardingPending && !hasSession && clearWhenNoSession) {
    controller.set(onboardingOnlinePendingSettingDef, false);
    Log.info(
      'Setting changed: ${onboardingOnlinePendingSettingDef.key}=false '
      '(auth callback pending without session)',
    );
  }

  final finishSettingsOnline =
      hasSession && (settingsPending || fromAuthCallback);
  if (finishSettingsOnline) {
    controller.set(settingsOnlinePendingSettingDef, false);
    controller.set(localOnlySettingDef, false);
    Log.info(
      'Setting changed: ${settingsOnlinePendingSettingDef.key}=false, '
      '${localOnlySettingDef.key}=false',
    );
  } else if (settingsPending && !hasSession && clearWhenNoSession) {
    controller.set(settingsOnlinePendingSettingDef, false);
    Log.info(
      'Setting changed: ${settingsOnlinePendingSettingDef.key}=false '
      '(auth callback pending without session)',
    );
  }
}
