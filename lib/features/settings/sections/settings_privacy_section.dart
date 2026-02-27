import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/route_paths.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/toast.dart';
import '../settings_definitions.dart';
import '../providers/settings_framework_providers.dart';
import '../widgets/setting_tile_helper.dart';

/// Returns the list of tiles for the Privacy section.
List<Widget> buildPrivacySectionTiles(
  BuildContext context,
  WidgetRef ref,
  SettingsProviders settings,
) {
  final localOnly = ref.watch(effectiveLocalOnlyProvider);
  return [
    ListTile(
      leading: const Icon(Icons.privacy_tip_outlined),
      title: Text('privacy_policy'.tr()),
      onTap: () => context.push(RoutePaths.privacyPolicy),
    ),
    buildBoolSettingTile(
      ref,
      settings,
      telemetryEnabledSettingDef,
      titleKey: 'telemetry_enabled',
      subtitleKey: 'telemetry_enabled_description',
    ),
    if (!localOnly)
      buildBoolSettingTile(
        ref,
        settings,
        notificationsEnabledSettingDef,
        titleKey: 'notifications_enabled',
        subtitleKey: 'notifications_enabled_description',
        onChanged: (v) async {
          final notifier =
              ref.read(settings.provider(notificationsEnabledSettingDef).notifier);
          if (v) {
            final ok =
                await ref.read(notificationServiceProvider.notifier).initialize(context);
            notifier.set(ok);
            if (!ok && context.mounted) {
              context.showToast('notifications_unavailable'.tr());
            }
          } else {
            ref.read(notificationServiceProvider.notifier).unregisterToken();
            notifier.set(false);
          }
        },
      ),
  ];
}
