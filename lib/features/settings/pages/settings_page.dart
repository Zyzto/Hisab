import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import '../settings_definitions.dart';
import '../providers/settings_framework_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const List<Locale> _supportedLocales = [Locale('en'), Locale('ar')];

  static String _localeDisplayName(Locale locale, BuildContext context) {
    switch (locale.languageCode) {
      case 'ar':
        return 'العربية';
      case 'en':
      default:
        return 'English';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localOnly = ref.watch(localOnlyProvider);
    final receiptOcrEnabled = ref.watch(receiptOcrEnabledProvider);
    final receiptAiEnabled = ref.watch(receiptAiEnabledProvider);
    final receiptAiProvider = ref.watch(receiptAiProviderProvider);
    final geminiApiKey = ref.watch(geminiApiKeyProvider);
    final openaiApiKey = ref.watch(openaiApiKeyProvider);
    final currentLocale = context.locale;

    return Scaffold(
      appBar: AppBar(title: Text('settings'.tr())),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text('language'.tr()),
            subtitle: Text(_localeDisplayName(currentLocale, context)),
            onTap: () async {
              final chosen = await showModalBottomSheet<Locale>(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'language'.tr(),
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                      ..._supportedLocales.map(
                        (locale) => ListTile(
                          title: Text(_localeDisplayName(locale, ctx)),
                          onTap: () => Navigator.of(ctx).pop(locale),
                        ),
                      ),
                    ],
                  ),
                ),
              );
              if (chosen != null && context.mounted) {
                await context.setLocale(chosen);
              }
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.storage),
            title: Text('local_only'.tr()),
            subtitle: Text('local_only_description'.tr()),
            value: localOnly,
            onChanged: (value) {
              try {
                final settings = ref.read(hisabSettingsProvidersProvider);
                if (settings != null) {
                  ref
                      .read(settings.provider(localOnlySettingDef).notifier)
                      .set(value);
                }
              } catch (e) {
                Log.warning('Failed to set local_only', error: e);
              }
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'receipt_ai_section'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.document_scanner),
            title: Text('receipt_ocr_enabled'.tr()),
            subtitle: Text('receipt_ocr_enabled_description'.tr()),
            value: receiptOcrEnabled,
            onChanged: (value) {
              try {
                final settings = ref.read(hisabSettingsProvidersProvider);
                if (settings != null) {
                  ref
                      .read(settings.provider(receiptOcrEnabledSettingDef).notifier)
                      .set(value);
                }
              } catch (e) {
                Log.warning('Failed to set receipt_ocr_enabled', error: e);
              }
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome),
            title: Text('receipt_ai_enabled'.tr()),
            subtitle: Text('receipt_ai_enabled_description'.tr()),
            value: receiptAiEnabled,
            onChanged: (value) {
              try {
                final settings = ref.read(hisabSettingsProvidersProvider);
                if (settings != null) {
                  ref
                      .read(settings.provider(receiptAiEnabledSettingDef).notifier)
                      .set(value);
                }
              } catch (e) {
                Log.warning('Failed to set receipt_ai_enabled', error: e);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud),
            title: Text('receipt_ai_provider'.tr()),
            subtitle: Text(_providerLabel(receiptAiProvider)),
            onTap: () async {
              final chosen = await showModalBottomSheet<String>(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'receipt_ai_provider'.tr(),
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                      ListTile(
                        title: Text('receipt_ai_provider_none'.tr()),
                        onTap: () => Navigator.pop(ctx, 'none'),
                      ),
                      ListTile(
                        title: Text('receipt_ai_provider_gemini'.tr()),
                        onTap: () => Navigator.pop(ctx, 'gemini'),
                      ),
                      ListTile(
                        title: Text('receipt_ai_provider_openai'.tr()),
                        onTap: () => Navigator.pop(ctx, 'openai'),
                      ),
                    ],
                  ),
                ),
              );
              if (chosen != null && context.mounted) {
                try {
                  final settings = ref.read(hisabSettingsProvidersProvider);
                  if (settings != null) {
                    ref
                        .read(settings.provider(receiptAiProviderSettingDef).notifier)
                        .set(chosen);
                  }
                } catch (e) {
                  Log.warning('Failed to set receipt_ai_provider', error: e);
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.key),
            title: Text('gemini_api_key'.tr()),
            subtitle: Text(
              geminiApiKey.isEmpty
                  ? 'receipt_ai_key_not_set'.tr()
                  : 'receipt_ai_key_set'.tr(),
            ),
            onTap: () => _showApiKeyDialog(
              context: context,
              ref: ref,
              titleKey: 'gemini_api_key',
              currentValue: geminiApiKey,
              settingDef: geminiApiKeySettingDef,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.key),
            title: Text('openai_api_key'.tr()),
            subtitle: Text(
              openaiApiKey.isEmpty
                  ? 'receipt_ai_key_not_set'.tr()
                  : 'receipt_ai_key_set'.tr(),
            ),
            onTap: () => _showApiKeyDialog(
              context: context,
              ref: ref,
              titleKey: 'openai_api_key',
              currentValue: openaiApiKey,
              settingDef: openaiApiKeySettingDef,
            ),
          ),
        ],
      ),
    );
  }

  static String _providerLabel(String value) {
    switch (value) {
      case 'gemini':
        return 'receipt_ai_provider_gemini'.tr();
      case 'openai':
        return 'receipt_ai_provider_openai'.tr();
      default:
        return 'receipt_ai_provider_none'.tr();
    }
  }

  static Future<void> _showApiKeyDialog({
    required BuildContext context,
    required WidgetRef ref,
    required String titleKey,
    required String currentValue,
    required StringSetting settingDef,
  }) async {
    final controller = TextEditingController(text: currentValue);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titleKey.tr()),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'receipt_ai_key_hint'.tr(),
            border: const OutlineInputBorder(),
          ),
          maxLines: 1,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('done'.tr()),
          ),
        ],
      ),
    );
    if (result == true && context.mounted) {
      try {
        final settings = ref.read(hisabSettingsProvidersProvider);
        if (settings != null) {
          ref
              .read(settings.provider(settingDef).notifier)
              .set(controller.text.trim());
        }
      } catch (e) {
        Log.warning('Failed to set API key', error: e);
      }
    }
  }
}
