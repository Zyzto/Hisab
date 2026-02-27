import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

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
}) {
  return [
    ActionSettingsTile(
      leading: const Icon(Icons.replay),
      title: Text('return_to_onboarding'.tr()),
      subtitle: Text('return_to_onboarding_description'.tr()),
      onTap: onReturnToOnboarding,
    ),
    ActionSettingsTile(
      leading: const Icon(Icons.description),
      title: Text('view_logs'.tr()),
      onTap: onViewLogs,
    ),
    ActionSettingsTile(
      leading: const Icon(Icons.restore),
      title: Text('reset_all_settings'.tr()),
      subtitle: Text('reset_all_settings_description'.tr()),
      onTap: onResetAllSettings,
    ),
    ActionSettingsTile(
      leading: const Icon(Icons.phone_android),
      title: Text('delete_local_data'.tr()),
      subtitle: Text('delete_local_data_description'.tr()),
      onTap: onDeleteLocalData,
    ),
    if (supabaseAvailable && isSignedIn)
      ActionSettingsTile(
        leading: const Icon(Icons.cloud),
        title: Text('delete_cloud_data'.tr()),
        subtitle: Text('delete_cloud_data_description'.tr()),
        onTap: onDeleteCloudData,
      )
    else
      ActionSettingsTile(
        leading: const Icon(Icons.cloud),
        title: Text('delete_cloud_data'.tr()),
        subtitle: Text('delete_cloud_data_sign_in_required'.tr()),
        onTap: null,
      ),
  ];
}
