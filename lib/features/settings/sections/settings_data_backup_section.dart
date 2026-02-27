import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

/// Returns the list of tiles for the Data & Backup section.
List<Widget> buildDataBackupSectionTiles(
  BuildContext context,
  WidgetRef ref,
  SettingsProviders settings, {
  required Widget localOnlyTile,
  required VoidCallback onExport,
  required VoidCallback onImport,
}) {
  return [
    localOnlyTile,
    ActionSettingsTile(
      leading: const Icon(Icons.upload_file),
      title: Text('export_data'.tr()),
      onTap: onExport,
    ),
    ActionSettingsTile(
      leading: const Icon(Icons.download),
      title: Text('import_data'.tr()),
      subtitle: Text('import_data_subtitle'.tr()),
      onTap: onImport,
    ),
  ];
}
