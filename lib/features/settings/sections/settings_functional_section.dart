import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

import '../settings_definitions.dart';
import '../widgets/setting_tile_helper.dart';

/// Returns the list of tiles for the Functional section (expense form toggles).
List<Widget> buildFunctionalSectionTiles(
  BuildContext context,
  WidgetRef ref,
  SettingsProviders settings,
) {
  return [
    buildBoolSettingTile(
      ref,
      settings,
      expenseFormFullFeaturesSettingDef,
      titleKey: 'expense_form_full_features',
      subtitleKey: 'expense_form_full_features_description',
    ),
    buildBoolSettingTile(
      ref,
      settings,
      expenseFormExpandDescriptionSettingDef,
      titleKey: 'expense_form_expand_description',
      subtitleKey: 'expense_form_expand_description_setting',
    ),
    buildBoolSettingTile(
      ref,
      settings,
      expenseFormExpandBillBreakdownSettingDef,
      titleKey: 'expense_form_expand_bill_breakdown',
      subtitleKey: 'expense_form_expand_bill_breakdown_setting',
    ),
  ];
}
