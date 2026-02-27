import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds a [SwitchSettingsTile] for a [BoolSetting] with the standard
/// watch/read pattern. Use this to reduce repetition when the only behavior
/// is to set the setting value.
///
/// For custom behavior (e.g. notifications tile that calls a service),
/// pass [onChanged]. When [onChanged] is non-null, it is called instead of
/// the default notifier.set(v).
Widget buildBoolSettingTile(
  WidgetRef ref,
  SettingsProviders settings,
  BoolSetting settingDef, {
  String? titleKey,
  String? subtitleKey,
  ValueChanged<bool>? onChanged,
  bool enabled = true,
}) {
  final title = (titleKey ?? settingDef.titleKey).tr();
  final subtitle = subtitleKey?.tr();
  return SwitchSettingsTile.fromSetting(
    setting: settingDef,
    title: title,
    subtitle: subtitle,
    value: ref.watch(settings.provider(settingDef)),
    onChanged: onChanged ??
        (v) => ref.read(settings.provider(settingDef).notifier).set(v),
    enabled: enabled,
  );
}
