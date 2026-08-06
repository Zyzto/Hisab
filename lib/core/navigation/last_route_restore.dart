import 'package:flutter/scheduler.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/providers/settings_framework_providers.dart';
import '../settings/settings_definitions.dart';
import 'invite_nav_redirect.dart';

/// Persist [path] so a process kill (common when opening the system camera)
/// can restore the user to the same screen on cold start.
void persistLastRoutePath(WidgetRef ref, String path) {
  if (path.isEmpty || path == '/') return;
  // Invites are entry flows — never pin them for camera-kill restore.
  if (isInviteRoutePath(path)) return;
  final settings = ref.read(hisabSettingsProvidersProvider);
  if (settings == null) return;
  final current = ref.read(settings.provider(lastRoutePathSettingDef));
  if (current == path) return;
  ref.read(settings.provider(lastRoutePathSettingDef).notifier).set(path);
  Log.info('Setting changed: ${lastRoutePathSettingDef.key}=$path');
}

/// Clear the camera-kill restore path. Safe to call outside build.
void clearLastRoutePath(WidgetRef ref) {
  final settings = ref.read(hisabSettingsProvidersProvider);
  if (settings == null) return;
  final current = ref.read(settings.provider(lastRoutePathSettingDef));
  if (current.isEmpty) return;
  ref.read(settings.provider(lastRoutePathSettingDef).notifier).set('');
  Log.info('Setting changed: ${lastRoutePathSettingDef.key}=(cleared)');
}

/// Mark an in-flight camera/gallery pick (`attach` / `scan` / `''`).
void setPendingImagePickMode(WidgetRef ref, String mode) {
  final settings = ref.read(hisabSettingsProvidersProvider);
  if (settings == null) return;
  final current = ref.read(settings.provider(pendingImagePickModeSettingDef));
  if (current == mode) return;
  ref
      .read(settings.provider(pendingImagePickModeSettingDef).notifier)
      .set(mode);
}

String readPendingImagePickMode(WidgetRef ref) {
  final settings = ref.read(hisabSettingsProvidersProvider);
  if (settings == null) return '';
  return ref.read(settings.provider(pendingImagePickModeSettingDef));
}

bool hasPendingImagePick(WidgetRef ref) =>
    readPendingImagePickMode(ref).isNotEmpty;

/// Clears pick mode and the pinned restore path after pick completes/cancels.
void clearPendingImagePick(WidgetRef ref) {
  setPendingImagePickMode(ref, '');
  clearLastRoutePath(ref);
}

/// Clear restore settings after the current build/redirect finishes.
/// Writing settings providers inside GoRouter.redirect runs during build and
/// throws, which aborts route restore after a camera process kill.
void scheduleClearLastRouteSettings(
  Ref ref, {
  bool clearPendingInvite = false,
  bool clearLastRoute = false,
  String pendingInviteLog = '(cleared)',
  String lastRouteLog = '(cleared)',
}) {
  if (!clearPendingInvite && !clearLastRoute) return;
  SchedulerBinding.instance.addPostFrameCallback((_) {
    final settings = ref.read(hisabSettingsProvidersProvider);
    if (settings == null) return;
    if (clearPendingInvite) {
      final token = ref.read(settings.provider(pendingInviteTokenSettingDef));
      if (token.isNotEmpty) {
        ref
            .read(settings.provider(pendingInviteTokenSettingDef).notifier)
            .set('');
        Log.info(
          'Setting changed: ${pendingInviteTokenSettingDef.key}=$pendingInviteLog',
        );
      }
    }
    if (clearLastRoute) {
      final last = ref.read(settings.provider(lastRoutePathSettingDef));
      if (last.isNotEmpty) {
        ref.read(settings.provider(lastRoutePathSettingDef).notifier).set('');
        Log.info(
          'Setting changed: ${lastRoutePathSettingDef.key}=$lastRouteLog',
        );
      }
    }
  });
}
