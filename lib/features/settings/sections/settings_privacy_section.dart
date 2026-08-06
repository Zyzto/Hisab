import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/route_paths.dart';
import '../../../core/platform/screenshot_report_support.dart';
import '../../../core/pwa/pwa_capabilities.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/toast.dart';
import 'package:hisab/core/settings/settings_definitions.dart';
import 'package:hisab/core/settings/providers/settings_framework_providers.dart';
import '../widgets/setting_tile_helper.dart';

/// Returns the list of tiles for the Privacy section.
List<Widget> buildPrivacySectionTiles(
  BuildContext context,
  WidgetRef ref,
  SettingsProviders settings, {
  SettingAnchorRegistry? anchors,
}) {
  final localOnly = ref.watch(effectiveLocalOnlyProvider);
  return [
    anchors?.wrap(
          actionPrivacyPolicySettingDef.key,
          ListTile(
            leading: Icon(actionPrivacyPolicySettingDef.icon),
            title: Text(actionPrivacyPolicySettingDef.titleKey.tr()),
            onTap: () => context.push(RoutePaths.privacyPolicy),
          ),
        ) ??
        ListTile(
          leading: Icon(actionPrivacyPolicySettingDef.icon),
          title: Text(actionPrivacyPolicySettingDef.titleKey.tr()),
          onTap: () => context.push(RoutePaths.privacyPolicy),
        ),
    buildBoolSettingTile(
      ref,
      settings,
      telemetryEnabledSettingDef,
      anchors: anchors,
    ),
    if (!localOnly)
      buildBoolSettingTile(
        ref,
        settings,
        notificationsEnabledSettingDef,
        subtitleKey:
            kIsWeb &&
                pwaNotificationSupport == PwaNotificationSupport.needsInstall
            ? 'onboarding_permission_notifications_needs_install'
            : null,
        anchors: anchors,
        onChanged: (v) async {
          final notifier = ref.read(
            settings.provider(notificationsEnabledSettingDef).notifier,
          );
          if (v) {
            final needsInstall =
                kIsWeb &&
                pwaNotificationSupport == PwaNotificationSupport.needsInstall;
            final ok = await ref
                .read(notificationServiceProvider.notifier)
                .initialize(context);
            notifier.set(ok);
            Log.info(
              'Setting changed: ${notificationsEnabledSettingDef.key}=$ok',
            );
            // needsInstall already shows an install guidance sheet.
            if (!ok && context.mounted && !needsInstall) {
              context.showToast('notifications_unavailable'.tr());
            }
          } else {
            ref.read(notificationServiceProvider.notifier).unregisterToken();
            notifier.set(false);
            Log.info(
              'Setting changed: ${notificationsEnabledSettingDef.key}=false',
            );
          }
        },
      ),
    if (supportsScreenshotReportPrompt)
      buildBoolSettingTile(
        ref,
        settings,
        screenshotReportPromptEnabledSettingDef,
        anchors: anchors,
      ),
  ];
}
