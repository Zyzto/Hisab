import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

import '../settings_definitions.dart';

/// Returns the list of tiles for the Data & Backup section.
List<Widget> buildDataBackupSectionTiles(
  BuildContext context,
  WidgetRef ref,
  SettingsProviders settings, {
  required Widget localOnlyTile,
  required VoidCallback onExport,
  required VoidCallback onImport,
  SettingAnchorRegistry? anchors,
}) {
  Widget wrap(ActionSetting def, Widget tile) =>
      anchors?.wrap(def.key, tile) ?? tile;

  return [
    localOnlyTile,
    wrap(
      actionExportDataSettingDef,
      ActionSettingsTile(
        leading: Icon(actionExportDataSettingDef.icon),
        title: Text(actionExportDataSettingDef.titleKey.tr()),
        onTap: onExport,
      ),
    ),
    wrap(
      actionImportDataSettingDef,
      ActionSettingsTile(
        leading: Icon(actionImportDataSettingDef.icon),
        title: Text(actionImportDataSettingDef.titleKey.tr()),
        subtitle: Text(actionImportDataSettingDef.subtitleKey!.tr()),
        onTap: onImport,
      ),
    ),
  ];
}
