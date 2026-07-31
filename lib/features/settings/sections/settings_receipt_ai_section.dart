import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';

import '../../../core/widgets/sheet_helpers.dart';
import '../settings_definitions.dart';
import '../providers/settings_framework_providers.dart';
import '../widgets/setting_tile_helper.dart';

/// Callback to show the API key dialog. Called when user taps a Gemini/OpenAI key tile.
typedef ShowApiKeyDialogCallback =
    Future<void> Function({
      required BuildContext context,
      required WidgetRef ref,
      required String titleKey,
      required String currentValue,
      required StringSetting settingDef,
    });

/// Returns the list of tiles for the Receipt AI section.
List<Widget> buildReceiptAiSectionTiles(
  BuildContext context,
  WidgetRef ref,
  SettingsProviders settings,
  ShowApiKeyDialogCallback showApiKeyDialog, {
  SettingAnchorRegistry? anchors,
}) {
  Widget wrap(String key, Widget tile) => anchors?.wrap(key, tile) ?? tile;
  return [
    buildBoolSettingTile(
      ref,
      settings,
      receiptOcrEnabledSettingDef,
      anchors: anchors,
    ),
    buildBoolSettingTile(
      ref,
      settings,
      receiptAiEnabledSettingDef,
      anchors: anchors,
    ),
    wrap(
      receiptAiProviderSettingDef.key,
      _receiptAiProviderTile(context, ref, settings),
    ),
    if (ref.watch(settings.provider(receiptAiProviderSettingDef)) == 'gemini' ||
        ref.watch(geminiApiKeyProvider).isNotEmpty)
      wrap(
        geminiApiKeySettingDef.key,
        ListTile(
          leading: const Icon(Icons.key),
          title: Text('gemini_api_key'.tr()),
          subtitle: Text(
            ref.watch(geminiApiKeyProvider).isEmpty
                ? 'receipt_ai_key_not_set'.tr()
                : 'receipt_ai_key_set'.tr(),
          ),
          onTap: () => showApiKeyDialog(
            context: context,
            ref: ref,
            titleKey: 'gemini_api_key',
            currentValue: ref.read(geminiApiKeyProvider),
            settingDef: geminiApiKeySettingDef,
          ),
        ),
      ),
    if (ref.watch(settings.provider(receiptAiProviderSettingDef)) == 'openai' ||
        ref.watch(openaiApiKeyProvider).isNotEmpty)
      wrap(
        openaiApiKeySettingDef.key,
        ListTile(
          leading: const Icon(Icons.key),
          title: Text('openai_api_key'.tr()),
          subtitle: Text(
            ref.watch(openaiApiKeyProvider).isEmpty
                ? 'receipt_ai_key_not_set'.tr()
                : 'receipt_ai_key_set'.tr(),
          ),
          onTap: () => showApiKeyDialog(
            context: context,
            ref: ref,
            titleKey: 'openai_api_key',
            currentValue: ref.read(openaiApiKeyProvider),
            settingDef: openaiApiKeySettingDef,
          ),
        ),
      ),
  ];
}

const _receiptAiProviderOptions = ['none', 'gemini', 'openai'];
const _receiptAiProviderLabelKeys = {
  'none': 'receipt_ai_provider_none',
  'gemini': 'receipt_ai_provider_gemini',
  'openai': 'receipt_ai_provider_openai',
};

Widget _receiptAiProviderTile(
  BuildContext context,
  WidgetRef ref,
  SettingsProviders settings,
) {
  final value = ref.watch(settings.provider(receiptAiProviderSettingDef));
  final labelKey = _receiptAiProviderLabelKeys[value] ?? value;
  return ListTile(
    leading: Icon(receiptAiProviderSettingDef.icon),
    title: Text('receipt_ai_provider'.tr()),
    subtitle: Text(labelKey.tr()),
    onTap: () async {
      final chosen = await showOptionPickerSheet<String>(
        context,
        title: 'receipt_ai_provider'.tr(),
        centerInFullViewport: false,
        selected: value,
        options: [
          for (final option in _receiptAiProviderOptions)
            SheetPickerOption(
              value: option,
              label: (_receiptAiProviderLabelKeys[option] ?? option).tr(),
            ),
        ],
      );
      if (chosen != null && context.mounted) {
        ref
            .read(settings.provider(receiptAiProviderSettingDef).notifier)
            .set(chosen);
        Log.info('Setting changed: ${receiptAiProviderSettingDef.key}=$chosen');
      }
    },
  );
}
