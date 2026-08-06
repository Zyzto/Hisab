import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

import 'package:hisab/core/settings/settings_definitions.dart';
import '../widgets/setting_tile_helper.dart';

/// Returns the list of tiles for the Functional section (expense form toggles).
List<Widget> buildFunctionalSectionTiles(
  BuildContext context,
  WidgetRef ref,
  SettingsProviders settings, {
  SettingAnchorRegistry? anchors,
}) {
  return [
    buildBoolSettingTile(
      ref,
      settings,
      expenseFormFullFeaturesSettingDef,
      anchors: anchors,
    ),
    buildBoolSettingTile(
      ref,
      settings,
      expenseFormExpandDescriptionSettingDef,
      anchors: anchors,
    ),
    buildBoolSettingTile(
      ref,
      settings,
      expenseFormExpandBillBreakdownSettingDef,
      anchors: anchors,
    ),
  ];
}
