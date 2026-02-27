import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../settings_definitions.dart';
import '../providers/settings_framework_providers.dart';
import '../widgets/setting_tile_helper.dart';

/// Callback to show the API key dialog. Called when user taps a Gemini/OpenAI key tile.
typedef ShowApiKeyDialogCallback = Future<void> Function({
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
  ShowApiKeyDialogCallback showApiKeyDialog,
) {
  return [
    buildBoolSettingTile(
      ref,
      settings,
      receiptOcrEnabledSettingDef,
      titleKey: 'receipt_ocr_enabled',
      subtitleKey: 'receipt_ocr_enabled_description',
    ),
    buildBoolSettingTile(
      ref,
      settings,
      receiptAiEnabledSettingDef,
      titleKey: 'receipt_ai_enabled',
      subtitleKey: 'receipt_ai_enabled_description',
    ),
    _receiptAiProviderTile(context, ref, settings),
    if (ref.watch(settings.provider(receiptAiProviderSettingDef)) == 'gemini' ||
        ref.watch(geminiApiKeyProvider).isNotEmpty)
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
    if (ref.watch(settings.provider(receiptAiProviderSettingDef)) == 'openai' ||
        ref.watch(openaiApiKeyProvider).isNotEmpty)
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
      final chosen = await showResponsiveSheet<String>(
        context: context,
        title: 'receipt_ai_provider'.tr(),
        maxHeight: MediaQuery.of(context).size.height * 0.75,
        isScrollControlled: true,
        child: Builder(
          builder: (ctx) => SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).padding.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!LayoutBreakpoints.isTabletOrWider(context))
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'receipt_ai_provider'.tr(),
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                    ..._receiptAiProviderOptions.map((option) {
                      final optionLabelKey =
                          _receiptAiProviderLabelKeys[option] ?? option;
                      return ListTile(
                        title: Text(optionLabelKey.tr()),
                        onTap: () => Navigator.of(ctx).pop(option),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      if (chosen != null && context.mounted) {
        ref
            .read(settings.provider(receiptAiProviderSettingDef).notifier)
            .set(chosen);
      }
    },
  );
}
