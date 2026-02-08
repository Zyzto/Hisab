import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import '../settings_definitions.dart';
import '../providers/settings_framework_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const List<Locale> _supportedLocales = [
    Locale('en'),
    Locale('ar'),
  ];

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
                      ..._supportedLocales.map((locale) => ListTile(
                            title: Text(_localeDisplayName(locale, ctx)),
                            onTap: () => Navigator.of(ctx).pop(locale),
                          )),
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
        ],
      ),
    );
  }
}
