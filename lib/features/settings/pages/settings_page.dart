import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../settings_definitions.dart';
import '../providers/settings_framework_providers.dart';
import '../backup_helper.dart';
import '../../../core/database/providers/dao_providers.dart';
import '../../../core/repository/local_repository.dart';
import '../../../domain/domain.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final Map<String, bool> _sectionExpanded = {};

  static const List<Locale> _supportedLocales = [Locale('en'), Locale('ar')];

  static String _localeDisplayName(Locale locale) {
    switch (locale.languageCode) {
      case 'ar':
        return 'العربية';
      case 'en':
      default:
        return 'English';
    }
  }

  bool _isExpanded(SettingSection section) {
    return _sectionExpanded[section.key] ?? section.initiallyExpanded;
  }

  void _onExpansionChanged(String key, bool expanded) {
    setState(() => _sectionExpanded[key] = expanded);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) {
      return Scaffold(
        appBar: AppBar(title: Text('settings'.tr())),
        body: Center(child: Text('settings_unavailable'.tr())),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('settings'.tr())),
      body: ListView(
        children: [
          _buildSection(context, ref, settings, generalSection, [
            _languageTile(context, ref, settings),
            EnumSettingsTile.fromSetting(
              setting: themeModeSettingDef,
              title: 'theme'.tr(),
              value: ref.watch(settings.provider(themeModeSettingDef)),
              labelBuilder: (v) => v.tr(),
              onChanged: (v) => ref
                  .read(settings.provider(themeModeSettingDef).notifier)
                  .set(v),
            ),
            ColorSettingsTile.fromSetting(
              setting: themeColorSettingDef,
              title: 'select_theme_color'.tr(),
              value: ref.watch(settings.provider(themeColorSettingDef)),
              onChanged: (v) => ref
                  .read(settings.provider(themeColorSettingDef).notifier)
                  .set(v),
            ),
          ]),
          _buildSection(context, ref, settings, appearanceSection, [
            EnumSettingsTile.fromSetting(
              setting: fontSizeScaleSettingDef,
              title: 'font_size'.tr(),
              value: ref.watch(settings.provider(fontSizeScaleSettingDef)),
              labelBuilder: (v) => v.tr(),
              onChanged: (v) => ref
                  .read(settings.provider(fontSizeScaleSettingDef).notifier)
                  .set(v),
            ),
          ]),
          _buildSection(context, ref, settings, dataSection, [
            SwitchSettingsTile.fromSetting(
              setting: localOnlySettingDef,
              title: 'local_only'.tr(),
              subtitle: 'local_only_description'.tr(),
              value: ref.watch(settings.provider(localOnlySettingDef)),
              onChanged: (v) => ref
                  .read(settings.provider(localOnlySettingDef).notifier)
                  .set(v),
            ),
          ]),
          _buildSection(context, ref, settings, receiptAiSection, [
            SwitchSettingsTile.fromSetting(
              setting: receiptOcrEnabledSettingDef,
              title: 'receipt_ocr_enabled'.tr(),
              subtitle: 'receipt_ocr_enabled_description'.tr(),
              value: ref.watch(settings.provider(receiptOcrEnabledSettingDef)),
              onChanged: (v) => ref
                  .read(settings.provider(receiptOcrEnabledSettingDef).notifier)
                  .set(v),
            ),
            SwitchSettingsTile.fromSetting(
              setting: receiptAiEnabledSettingDef,
              title: 'receipt_ai_enabled'.tr(),
              subtitle: 'receipt_ai_enabled_description'.tr(),
              value: ref.watch(settings.provider(receiptAiEnabledSettingDef)),
              onChanged: (v) => ref
                  .read(settings.provider(receiptAiEnabledSettingDef).notifier)
                  .set(v),
            ),
            EnumSettingsTile.fromSetting(
              setting: receiptAiProviderSettingDef,
              title: 'receipt_ai_provider'.tr(),
              value: ref.watch(settings.provider(receiptAiProviderSettingDef)),
              labelBuilder: (v) => v.tr(),
              onChanged: (v) => ref
                  .read(settings.provider(receiptAiProviderSettingDef).notifier)
                  .set(v),
            ),
            ListTile(
              leading: const Icon(Icons.key),
              title: Text('gemini_api_key'.tr()),
              subtitle: Text(
                ref.watch(geminiApiKeyProvider).isEmpty
                    ? 'receipt_ai_key_not_set'.tr()
                    : 'receipt_ai_key_set'.tr(),
              ),
              onTap: () => _showApiKeyDialog(
                context: context,
                ref: ref,
                titleKey: 'gemini_api_key',
                currentValue: ref.read(geminiApiKeyProvider),
                settingDef: geminiApiKeySettingDef,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.key),
              title: Text('openai_api_key'.tr()),
              subtitle: Text(
                ref.watch(openaiApiKeyProvider).isEmpty
                    ? 'receipt_ai_key_not_set'.tr()
                    : 'receipt_ai_key_set'.tr(),
              ),
              onTap: () => _showApiKeyDialog(
                context: context,
                ref: ref,
                titleKey: 'openai_api_key',
                currentValue: ref.read(openaiApiKeyProvider),
                settingDef: openaiApiKeySettingDef,
              ),
            ),
          ]),
          _buildSection(context, ref, settings, loggingSection, [
            ActionSettingsTile(
              leading: const Icon(Icons.description),
              title: Text('view_logs'.tr()),
              onTap: () => _showLogsDialog(context),
            ),
          ]),
          _buildSection(context, ref, settings, backupSection, [
            ActionSettingsTile(
              leading: const Icon(Icons.upload_file),
              title: Text('export_data'.tr()),
              onTap: () => _exportData(context, ref),
            ),
            ActionSettingsTile(
              leading: const Icon(Icons.download),
              title: Text('import_data'.tr()),
              onTap: () => _importData(context, ref),
            ),
          ]),
          _buildAboutSection(context, ref, settings),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
    SettingSection section,
    List<Widget> children,
  ) {
    final isExpanded = _isExpanded(section);
    final title = section.titleKey.tr();
    final icon = section.icon ?? Icons.settings;
    return CardSettingsSection(
      title: title,
      icon: icon,
      sectionId: section.key,
      isExpanded: isExpanded,
      onExpansionChanged: (expanded) =>
          _onExpansionChanged(section.key, expanded),
      isLandscape: false,
      children: children,
    );
  }

  Widget _languageTile(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final currentLang = ref.watch(settings.provider(languageSettingDef));
    return ListTile(
      leading: Icon(languageSettingDef.icon),
      title: Text('language'.tr()),
      subtitle: Text(
        currentLang == 'ar'
            ? _localeDisplayName(const Locale('ar'))
            : _localeDisplayName(const Locale('en')),
      ),
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
                    title: Text(_localeDisplayName(locale)),
                    onTap: () => Navigator.of(ctx).pop(locale),
                  ),
                ),
              ],
            ),
          ),
        );
        if (chosen != null && context.mounted) {
          final langCode = chosen.languageCode;
          ref
              .read(settings.provider(languageSettingDef).notifier)
              .set(langCode);
          await context.setLocale(chosen);
        }
      },
    );
  }

  Widget _buildAboutSection(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    return CardSettingsSection(
      title: 'about'.tr(),
      icon: aboutSection.icon ?? Icons.info,
      sectionId: aboutSection.key,
      isExpanded: _isExpanded(aboutSection),
      onExpansionChanged: (expanded) =>
          _onExpansionChanged(aboutSection.key, expanded),
      isLandscape: false,
      children: [
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final version = snapshot.hasData
                ? '${snapshot.data!.appName} ${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                : '—';
            return InfoSettingsTile(
              title: Text('version'.tr()),
              value: Text(version),
            );
          },
        ),
        NavigationSettingsTile(
          leading: const Icon(Icons.info_outline),
          title: Text('licenses'.tr()),
          onTap: () => _showLicenses(context),
        ),
        NavigationSettingsTile(
          leading: const Icon(Icons.person_outline),
          title: Text('about_me'.tr()),
          onTap: () => _showAboutMe(context),
        ),
      ],
    );
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

  static Future<void> _showLogsDialog(BuildContext context) async {
    Log.debug('Opening logs dialog');
    String content;
    try {
      content = await LoggingService.getLogContent(maxLines: 500);
    } catch (e) {
      content = 'logs_not_available'.tr();
    }
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('view_logs'.tr()),
        content: SizedBox(
          width: double.maxFinite,
          child: SelectableText(content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('done'.tr()),
          ),
        ],
      ),
    );
  }

  static Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    try {
      final groupDao = ref.read(groupDaoProvider);
      final participantDao = ref.read(participantDaoProvider);
      final expenseDao = ref.read(expenseDaoProvider);
      final expenseTagDao = ref.read(expenseTagDaoProvider);
      final data = await exportLocalDataToJson(
        groupDao: groupDao,
        participantDao: participantDao,
        expenseDao: expenseDao,
        expenseTagDao: expenseTagDao,
      );
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'export_data'.tr(),
        fileName:
            'hisab_backup_${DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(utf8.encode(jsonString)),
      );
      if (context.mounted) {
        if (result != null && result.isNotEmpty) {
          Log.info('Backup exported to $result');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('export_success'.tr())));
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('export_cancelled'.tr())));
        }
      }
    } catch (e, st) {
      Log.warning('Backup export failed', error: e, stackTrace: st);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('export_failed'.tr())));
      }
    }
  }

  static Future<void> _importData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('import_data'.tr()),
        content: Text('import_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('import_data'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !context.mounted) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('import_failed'.tr())));
        return;
      }
      final jsonString = utf8.decode(bytes);
      final backup = parseBackupJson(jsonString);
      if (backup == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('import_invalid_file'.tr())));
        }
        return;
      }
      final groupDao = ref.read(groupDaoProvider);
      final participantDao = ref.read(participantDaoProvider);
      final expenseDao = ref.read(expenseDaoProvider);
      final expenseTagDao = ref.read(expenseTagDaoProvider);
      final groupRepo = LocalGroupRepository(groupDao);
      final participantRepo = LocalParticipantRepository(participantDao);
      final expenseRepo = LocalExpenseRepository(expenseDao);
      final tagRepo = LocalTagRepository(expenseTagDao);
      final idMap = <String, String>{};
      for (final g in backup.groups) {
        final newId = await groupRepo.create(g.name, g.currencyCode);
        idMap[g.id] = newId;
      }
      final participantIds = <String, String>{};
      for (final g in backup.groups) {
        final newGroupId = idMap[g.id]!;
        final oldParticipants = backup.participants
            .where((e) => e.groupId == g.id)
            .toList();
        for (final p in oldParticipants) {
          final newId = await participantRepo.create(
            newGroupId,
            p.name,
            p.order,
          );
          participantIds[p.id] = newId;
        }
      }
      for (final e in backup.expenses) {
        final newGroupId = idMap[e.groupId];
        final newPayerId = participantIds[e.payerParticipantId];
        if (newGroupId != null && newPayerId != null) {
          final toId = e.toParticipantId != null
              ? participantIds[e.toParticipantId!]
              : null;
          final expense = Expense(
            id: '',
            groupId: newGroupId,
            payerParticipantId: newPayerId,
            amountCents: e.amountCents,
            currencyCode: e.currencyCode,
            title: e.title,
            description: e.description,
            date: e.date,
            splitType: e.splitType,
            splitShares: e.splitShares,
            createdAt: e.createdAt,
            updatedAt: e.updatedAt,
            transactionType: e.transactionType,
            toParticipantId: toId,
            tag: e.tag,
            lineItems: e.lineItems,
            receiptImagePath: e.receiptImagePath,
          );
          await expenseRepo.create(expense);
        }
      }
      for (final t in backup.expenseTags) {
        final newGroupId = idMap[t.groupId];
        if (newGroupId != null) {
          await tagRepo.create(newGroupId, t.label, t.iconName);
        }
      }
      Log.info('Backup import completed');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('import_success'.tr())));
      }
    } catch (e, st) {
      Log.warning('Backup import failed', error: e, stackTrace: st);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('import_failed'.tr())));
      }
    }
  }

  static void _showLicenses(BuildContext context) {
    showLicensePage(context: context, applicationName: 'Hisab');
  }

  static void _showAboutMe(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('about_me'.tr()),
        content: const SingleChildScrollView(
          child: Text(
            'Hisab is a group expense splitting app. '
            'Settle up with friends and family.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('done'.tr()),
          ),
        ],
      ),
    );
  }
}
