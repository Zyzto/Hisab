import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

import '../settings_definitions.dart';

/// Returns the list of tiles for the Advanced section.
List<Widget> buildAdvancedSectionTiles(
  BuildContext context,
  WidgetRef ref,
  SettingsProviders settings, {
  required VoidCallback onReturnToOnboarding,
  required VoidCallback onViewLogs,
  required VoidCallback onResetAllSettings,
  required VoidCallback onDeleteLocalData,
  required VoidCallback? onDeleteCloudData,
  required bool supabaseAvailable,
  required bool isSignedIn,
  SettingAnchorRegistry? anchors,
}) {
  Widget wrap(ActionSetting def, Widget tile) =>
      anchors?.wrap(def.key, tile) ?? tile;

  return [
    wrap(
      actionReturnToOnboardingSettingDef,
      ActionSettingsTile(
        leading: Icon(actionReturnToOnboardingSettingDef.icon),
        title: Text(actionReturnToOnboardingSettingDef.titleKey.tr()),
        subtitle: Text(actionReturnToOnboardingSettingDef.subtitleKey!.tr()),
        onTap: onReturnToOnboarding,
      ),
    ),
    wrap(
      actionViewLogsSettingDef,
      ActionSettingsTile(
        leading: Icon(actionViewLogsSettingDef.icon),
        title: Text(actionViewLogsSettingDef.titleKey.tr()),
        onTap: onViewLogs,
      ),
    ),
    wrap(
      actionResetAllSettingsSettingDef,
      ActionSettingsTile(
        leading: Icon(actionResetAllSettingsSettingDef.icon),
        title: Text(actionResetAllSettingsSettingDef.titleKey.tr()),
        subtitle: Text(actionResetAllSettingsSettingDef.subtitleKey!.tr()),
        onTap: onResetAllSettings,
      ),
    ),
    wrap(
      actionDeleteLocalDataSettingDef,
      ActionSettingsTile(
        leading: Icon(actionDeleteLocalDataSettingDef.icon),
        title: Text(actionDeleteLocalDataSettingDef.titleKey.tr()),
        subtitle: Text(actionDeleteLocalDataSettingDef.subtitleKey!.tr()),
        onTap: onDeleteLocalData,
      ),
    ),
    if (supabaseAvailable && isSignedIn)
      wrap(
        actionDeleteCloudDataSettingDef,
        ActionSettingsTile(
          leading: Icon(actionDeleteCloudDataSettingDef.icon),
          title: Text(actionDeleteCloudDataSettingDef.titleKey.tr()),
          subtitle: Text(actionDeleteCloudDataSettingDef.subtitleKey!.tr()),
          onTap: onDeleteCloudData,
        ),
      )
    else
      wrap(
        actionDeleteCloudDataSettingDef,
        ActionSettingsTile(
          leading: Icon(actionDeleteCloudDataSettingDef.icon),
          title: Text(actionDeleteCloudDataSettingDef.titleKey.tr()),
          subtitle: Text('delete_cloud_data_sign_in_required'.tr()),
          onTap: null,
        ),
      ),
  ];
}
