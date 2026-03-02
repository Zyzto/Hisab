import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/theme/theme_config.dart';
import '../../settings/settings_definitions.dart';
import 'onboarding_shared.dart';

class OnboardingPermissionsPage extends ConsumerWidget {
  const OnboardingPermissionsPage({
    super.key,
    required this.settings,
    required this.onlineAvailable,
    required this.cameraGranted,
    required this.notificationGranted,
    required this.permissionStatusFuture,
    required this.onRequestCamera,
    required this.onRequestNotification,
  });

  final SettingsProviders settings;
  final bool onlineAvailable;
  final bool? cameraGranted;
  final bool? notificationGranted;
  final Future<({bool camera, bool notification})>? permissionStatusFuture;
  final Future<void> Function() onRequestCamera;
  final Future<void> Function() onRequestNotification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return onboardingPageBodyWithFixedTitle(
      context,
      contentAlignment: Alignment.topCenter,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'onboarding_permissions_title'.tr(),
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: ThemeConfig.spacingS),
          Text(
            'onboarding_permissions_desc'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
      content: FutureBuilder<({bool camera, bool notification})>(
        future: permissionStatusFuture,
        builder: (context, snapshot) {
          final cameraGrantedValue =
              cameraGranted ?? snapshot.data?.camera ?? false;
          final notificationGrantedValue =
              notificationGranted ?? snapshot.data?.notification ?? false;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!kIsWeb)
                _buildPermissionRow(
                  context,
                  icon: Icons.camera_alt_outlined,
                  title: 'onboarding_permission_camera'.tr(),
                  subtitle: 'onboarding_permission_camera_desc'.tr(),
                  granted: cameraGrantedValue,
                  onAllow: onRequestCamera,
                ),
              _buildPermissionRow(
                context,
                icon: Icons.notifications_outlined,
                title: 'onboarding_permission_notifications'.tr(),
                subtitle:
                    'onboarding_permission_notifications_desc'.tr(),
                granted: notificationGrantedValue,
                onAllow: onRequestNotification,
              ),
              if (onlineAvailable)
                _NotificationsAppToggle(
                  settings: settings,
                  notificationPermissionGranted: notificationGrantedValue,
                ),
              _TelemetryToggle(settings: settings),
            ],
          );
        },
      ),
    );
  }
}

Widget _buildPermissionRow(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required bool granted,
  required Future<void> Function() onAllow,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return OnboardingListCard(
    leading: OnboardingListCardIcon(icon: icon),
    title: title,
    subtitle: Text(
      subtitle,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        height: 1.3,
      ),
    ),
    trailing: granted
        ? Semantics(
            label: '$title ${'onboarding_permission_allowed'.tr()}',
            child: FilledButton.tonal(
              onPressed: null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle,
                      size: 18, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Text('onboarding_permission_allowed'.tr()),
                ],
              ),
            ),
          )
        : Semantics(
            label: '$title ${'onboarding_permission_allow'.tr()}',
            child: FilledButton.tonal(
              onPressed: () async => await onAllow(),
              child: Text('onboarding_permission_allow'.tr()),
            ),
          ),
  );
}

class _NotificationsAppToggle extends ConsumerWidget {
  const _NotificationsAppToggle({
    required this.settings,
    required this.notificationPermissionGranted,
  });

  final SettingsProviders settings;
  final bool notificationPermissionGranted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      settings.provider(notificationsEnabledSettingDef),
    );
    final toggleEnabled = notificationPermissionGranted;
    return OnboardingListCard(
      leading: const OnboardingListCardIcon(
        icon: Icons.notifications_active_outlined,
        usePrimaryContainer: false,
      ),
      title: 'notifications_enabled'.tr(),
      subtitle: Text(
        'notifications_enabled_description'.tr(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Switch(
        value: toggleEnabled ? enabled : false,
        onChanged: toggleEnabled
            ? (v) async {
                final notifier = ref.read(
                  settings.provider(notificationsEnabledSettingDef).notifier,
                );
                if (v) {
                  final ok = await ref
                      .read(notificationServiceProvider.notifier)
                      .initialize(context);
                  notifier.set(ok);
                  if (!ok && context.mounted) {
                    context.showToast('notifications_unavailable'.tr());
                  }
                } else {
                  ref
                      .read(notificationServiceProvider.notifier)
                      .unregisterToken();
                  notifier.set(false);
                }
              }
            : null,
      ),
    );
  }
}

class _TelemetryToggle extends ConsumerWidget {
  const _TelemetryToggle({required this.settings});

  final SettingsProviders settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      settings.provider(telemetryEnabledSettingDef),
    );
    return OnboardingListCard(
      leading: const OnboardingListCardIcon(
        icon: Icons.analytics_outlined,
        usePrimaryContainer: false,
      ),
      title: 'telemetry_enabled'.tr(),
      subtitle: Text(
        'telemetry_enabled_description'.tr(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Switch(
        value: enabled,
        onChanged: (v) {
          ref
              .read(settings.provider(telemetryEnabledSettingDef).notifier)
              .set(v);
        },
      ),
    );
  }
}
