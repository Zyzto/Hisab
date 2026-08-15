import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hisab_backend/hisab_backend.dart';
import '../settings/providers/settings_framework_providers.dart';
import '../settings/settings_definitions.dart';
import 'invite_nav_redirect.dart';
import 'last_route_restore.dart';

/// Force online mode for invite flows when Supabase is configured.
/// Call from post-frame callbacks or button handlers — never during build.
void prepareInviteOnlineMode(WidgetRef ref) {
  if (!cloudAvailable) return;
  final settings = ref.read(hisabSettingsProvidersProvider);
  if (settings == null) return;
  final localOnly = ref.read(settings.provider(localOnlySettingDef));
  if (!localOnly) return;
  ref.read(settings.provider(localOnlySettingDef).notifier).set(false);
  Log.info('Setting changed: ${localOnlySettingDef.key}=false (invite online)');
}

/// Persist pending invite + auto-join and force online for Join/Accept.
/// Call from post-frame callbacks or button handlers — never during build.
void prepareInviteJoinPending(WidgetRef ref, String token) {
  prepareInviteOnlineMode(ref);
  if (token.isEmpty) return;
  final settings = ref.read(hisabSettingsProvidersProvider);
  if (settings == null) return;
  ref.read(settings.provider(pendingInviteTokenSettingDef).notifier).set(token);
  ref
      .read(settings.provider(pendingInviteAutoJoinSettingDef).notifier)
      .set(true);
  Log.info(
    'Setting changed: ${pendingInviteTokenSettingDef.key}=(set), '
    '${pendingInviteAutoJoinSettingDef.key}=true (invite join)',
  );
}

/// Mark onboarding complete so leaving `/invite/*` does not bounce to onboarding.
/// Call only after auth success (or immediately before navigating to a group).
void markInviteOnboardingDone(WidgetRef ref) {
  final settings = ref.read(hisabSettingsProvidersProvider);
  if (settings == null) return;
  final done = ref.read(settings.provider(onboardingCompletedSettingDef));
  if (done) return;
  ref.read(settings.provider(onboardingCompletedSettingDef).notifier).set(true);
  Log.info(
    'Setting changed: ${onboardingCompletedSettingDef.key}=true (invite auth)',
  );
}

/// Persist invite token so OAuth/reload can recover (without forcing auto-join).
void persistPendingInviteToken(WidgetRef ref, String token) {
  if (token.isEmpty) return;
  final settings = ref.read(hisabSettingsProvidersProvider);
  if (settings == null) return;
  final current = ref.read(settings.provider(pendingInviteTokenSettingDef));
  if (current == token) return;
  ref.read(settings.provider(pendingInviteTokenSettingDef).notifier).set(token);
  Log.info(
    'Setting changed: ${pendingInviteTokenSettingDef.key}=(persisted from invite page)',
  );
}

/// Clear pending invite + auto-join and any invite last-route restore path.
/// Call on every terminal invite outcome before navigating away.
void clearInviteFlowState(WidgetRef ref) {
  final settings = ref.read(hisabSettingsProvidersProvider);
  if (settings == null) return;
  final token = ref.read(settings.provider(pendingInviteTokenSettingDef));
  if (token.isNotEmpty) {
    ref.read(settings.provider(pendingInviteTokenSettingDef).notifier).set('');
    Log.info(
      'Setting changed: ${pendingInviteTokenSettingDef.key}=(cleared terminal)',
    );
  }
  final autoJoin = ref.read(settings.provider(pendingInviteAutoJoinSettingDef));
  if (autoJoin) {
    ref
        .read(settings.provider(pendingInviteAutoJoinSettingDef).notifier)
        .set(false);
    Log.info(
      'Setting changed: ${pendingInviteAutoJoinSettingDef.key}=false (terminal)',
    );
  }
  final lastPath = ref.read(settings.provider(lastRoutePathSettingDef));
  if (isInviteRoutePath(lastPath)) {
    clearLastRoutePath(ref);
  }
}
