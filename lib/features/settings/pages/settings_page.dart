import 'dart:async';
import 'dart:convert';
import 'package:currency_picker/currency_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:feedback/feedback.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/sign_in_sheet.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/update/update_check_providers.dart';
import '../../../core/services/migration_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/delete_my_data_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/currency_helpers.dart';
import '../settings_definitions.dart';
import '../providers/settings_framework_providers.dart';
import '../backup_helper.dart';
import '../feedback_handler.dart';
import '../widgets/logs_viewer_dialog.dart';
import '../widgets/edit_profile_sheet.dart';
import '../../../core/auth/predefined_avatars.dart';
import '../../../core/widgets/sync_status_icon.dart';
import '../../../core/widgets/toast.dart';
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
        appBar: AppBar(
          leading: const SyncStatusChip(),
          title: Text('settings'.tr()),
        ),
        body: Center(child: Text('settings_unavailable'.tr())),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const SyncStatusChip(),
        title: Text('settings'.tr()),
      ),
      body: ListView(
        children: [
          _buildAccountSection(context, ref, settings),
          // Appearance: merged General + old Appearance
          _buildSection(context, ref, settings, appearanceSection, [
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
            EnumSettingsTile.fromSetting(
              setting: fontSizeScaleSettingDef,
              title: 'font_size'.tr(),
              value: ref.watch(settings.provider(fontSizeScaleSettingDef)),
              labelBuilder: (v) => v.tr(),
              onChanged: (v) => ref
                  .read(settings.provider(fontSizeScaleSettingDef).notifier)
                  .set(v),
            ),
            _favoriteCurrenciesTile(context, ref, settings),
          ]),
          // Functional: behavior toggles (expense form mode, etc.)
          _buildSection(context, ref, settings, functionalSection, [
            SwitchSettingsTile.fromSetting(
              setting: expenseFormFullFeaturesSettingDef,
              title: 'expense_form_full_features'.tr(),
              subtitle: 'expense_form_full_features_description'.tr(),
              value: ref.watch(
                settings.provider(expenseFormFullFeaturesSettingDef),
              ),
              onChanged: (v) => ref
                  .read(
                    settings
                        .provider(expenseFormFullFeaturesSettingDef)
                        .notifier,
                  )
                  .set(v),
            ),
            SwitchSettingsTile.fromSetting(
              setting: expenseFormExpandDescriptionSettingDef,
              title: 'expense_form_expand_description'.tr(),
              subtitle: 'expense_form_expand_description_setting'.tr(),
              value: ref.watch(
                settings.provider(expenseFormExpandDescriptionSettingDef),
              ),
              onChanged: (v) => ref
                  .read(
                    settings
                        .provider(expenseFormExpandDescriptionSettingDef)
                        .notifier,
                  )
                  .set(v),
            ),
            SwitchSettingsTile.fromSetting(
              setting: expenseFormExpandBillBreakdownSettingDef,
              title: 'expense_form_expand_bill_breakdown'.tr(),
              subtitle: 'expense_form_expand_bill_breakdown_setting'.tr(),
              value: ref.watch(
                settings.provider(
                  expenseFormExpandBillBreakdownSettingDef,
                ),
              ),
              onChanged: (v) => ref
                  .read(
                    settings
                        .provider(
                          expenseFormExpandBillBreakdownSettingDef,
                        )
                        .notifier,
                  )
                  .set(v),
            ),
          ]),
          // Data & Backup: merged Data + old Backup
          _buildSection(context, ref, settings, dataBackupSection, [
            _buildLocalOnlyTile(context, ref, settings),
            ActionSettingsTile(
              leading: const Icon(Icons.upload_file),
              title: Text('export_data'.tr()),
              onTap: () => _exportData(context, ref),
            ),
            ActionSettingsTile(
              leading: const Icon(Icons.download),
              title: Text('import_data'.tr()),
              subtitle: Text('import_data_subtitle'.tr()),
              onTap: () => _importData(context, ref),
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
            if (ref.watch(settings.provider(receiptAiProviderSettingDef)) ==
                    'gemini' ||
                ref.watch(geminiApiKeyProvider).isNotEmpty)
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
            if (ref.watch(settings.provider(receiptAiProviderSettingDef)) ==
                    'openai' ||
                ref.watch(openaiApiKeyProvider).isNotEmpty)
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
          // Privacy: renamed from Logging
          _buildSection(context, ref, settings, privacySection, [
            NavigationSettingsTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text('privacy_policy'.tr()),
              onTap: () => context.push(RoutePaths.privacyPolicy),
            ),
            SwitchSettingsTile.fromSetting(
              setting: telemetryEnabledSettingDef,
              title: 'telemetry_enabled'.tr(),
              subtitle: 'telemetry_enabled_description'.tr(),
              value: ref.watch(settings.provider(telemetryEnabledSettingDef)),
              onChanged: (v) => ref
                  .read(settings.provider(telemetryEnabledSettingDef).notifier)
                  .set(v),
            ),
            if (!ref.watch(effectiveLocalOnlyProvider))
              SwitchSettingsTile.fromSetting(
                setting: notificationsEnabledSettingDef,
                title: 'notifications_enabled'.tr(),
                subtitle: 'notifications_enabled_description'.tr(),
                value: ref.watch(
                  settings.provider(notificationsEnabledSettingDef),
                ),
                onChanged: (v) async {
                  final notifier = ref.read(
                    settings.provider(notificationsEnabledSettingDef).notifier,
                  );
                  if (v) {
                    final ok = await ref
                        .read(notificationServiceProvider.notifier)
                        .initialize(context);
                    notifier.set(ok);
                    if (!ok && context.mounted) {
                      context.showToast('notifications_unavailable'.tr());
                    }
                  } else {
                    ref
                        .read(notificationServiceProvider.notifier)
                        .unregisterToken();
                    notifier.set(false);
                  }
                },
              ),
          ]),
          _buildSection(context, ref, settings, advancedSection, [
            ActionSettingsTile(
              leading: const Icon(Icons.replay),
              title: Text('return_to_onboarding'.tr()),
              subtitle: Text('return_to_onboarding_description'.tr()),
              onTap: () => _resetToOnboarding(context, ref, settings),
            ),
            ActionSettingsTile(
              leading: const Icon(Icons.description),
              title: Text('view_logs'.tr()),
              onTap: () => _showLogsDialog(context),
            ),
            ActionSettingsTile(
              leading: const Icon(Icons.restore),
              title: Text('reset_all_settings'.tr()),
              subtitle: Text('reset_all_settings_description'.tr()),
              onTap: () => _resetAllSettings(context, ref, settings),
            ),
            ActionSettingsTile(
              leading: const Icon(Icons.phone_android),
              title: Text('delete_local_data'.tr()),
              subtitle: Text('delete_local_data_description'.tr()),
              onTap: () => _showDeleteLocalData(context, ref),
            ),
            if (supabaseConfigAvailable && ref.watch(currentUserProvider) != null)
              ActionSettingsTile(
                leading: const Icon(Icons.cloud),
                title: Text('delete_cloud_data'.tr()),
                subtitle: Text('delete_cloud_data_description'.tr()),
                onTap: () => _showDeleteCloudData(context, ref),
              )
            else
              ActionSettingsTile(
                leading: const Icon(Icons.cloud),
                title: Text('delete_cloud_data'.tr()),
                subtitle: Text('delete_cloud_data_sign_in_required'.tr()),
                onTap: null,
              ),
          ]),
          _buildAboutSection(context, ref, settings),
        ],
      ),
    );
  }

  Widget _buildAccountSection(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final onlineAvailable = supabaseConfigAvailable;
    final localOnly = ref.watch(effectiveLocalOnlyProvider);

    return _buildSection(context, ref, settings, accountSection, [
      if (!onlineAvailable)
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.cloud_off,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          title: Text('account'.tr()),
          subtitle: Text('onboarding_online_unavailable'.tr()),
        )
      else if (localOnly)
        ..._buildLocalModeTiles(context, ref, settings)
      else
        ..._buildOnlineAccountTiles(context, ref, settings),
    ]);
  }

  List<Widget> _buildLocalModeTiles(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return [
      ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(Icons.smartphone, color: colorScheme.onPrimaryContainer),
        ),
        title: Text(
          'local_only'.tr(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text('account_local_mode_description'.tr()),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: FilledButton.icon(
          onPressed: () =>
              _handleLocalOnlyChanged(context, ref, settings, false),
          icon: const Icon(Icons.cloud_upload_outlined),
          label: Text('switch_to_online'.tr()),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ),
    ];
  }

  List<Widget> _buildOnlineAccountTiles(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final profileAsync = ref.watch(authUserProfileProvider);
    final user = ref.watch(currentUserProvider);
    final syncStatus = ref.watch(syncStatusForDisplayProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.errorContainer,
                child: Icon(
                  Icons.person_off,
                  color: colorScheme.onErrorContainer,
                ),
              ),
              title: Text('account'.tr()),
              subtitle: Text('account_not_signed_in'.tr()),
              trailing: FilledButton(
                onPressed: () =>
                    _handleLocalOnlyChanged(context, ref, settings, false),
                child: Text('sign_in'.tr()),
              ),
            ),
          ];
        }

        final initials = _getInitials(profile.name, profile.email);
        final provider = _getProviderLabel(user);
        final emoji = avatarEmoji(profile.avatarId);

        return [
          // User info card (tappable to edit profile)
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: emoji != null
                  ? Text(emoji, style: const TextStyle(fontSize: 24))
                  : Text(
                      initials,
                      style: textTheme.titleSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            title: Text(
              profile.name ?? profile.email ?? profile.sub,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: profile.email != null ? Text(profile.email!) : null,
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => showEditProfileSheet(context, ref, profile),
          ),
          // Sync status & provider
          _buildAccountSyncTile(context, syncStatus, provider),
          // Sign out
          ActionSettingsTile(
            leading: const Icon(Icons.logout),
            title: Text('sign_out'.tr()),
            onTap: () => _handleSignOut(context, ref, settings),
          ),
        ];
      },
      loading: () => [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: colorScheme.surfaceContainerHighest,
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          title: const Text('…'),
        ),
      ],
      error: (_, _) => [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: colorScheme.errorContainer,
            child: Icon(
              Icons.error_outline,
              color: colorScheme.onErrorContainer,
            ),
          ),
          title: Text('account'.tr()),
          subtitle: Text('account_not_signed_in'.tr()),
          trailing: FilledButton(
            onPressed: () =>
                _handleLocalOnlyChanged(context, ref, settings, false),
            child: Text('sign_in'.tr()),
          ),
        ),
      ],
    );
  }

  static Widget _buildAccountSyncTile(
    BuildContext context,
    SyncStatus status,
    String provider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, color, label) = switch (status) {
      SyncStatus.connected => (
        Icons.cloud_done_outlined,
        colorScheme.primary,
        'sync_connected'.tr(),
      ),
      SyncStatus.syncing => (
        Icons.sync,
        colorScheme.tertiary,
        'sync_syncing'.tr(),
      ),
      SyncStatus.offline => (
        Icons.cloud_off_outlined,
        colorScheme.error,
        'sync_offline'.tr(),
      ),
      SyncStatus.syncFailed => (
        Icons.cloud_off_outlined,
        colorScheme.error,
        'sync_failed'.tr(),
      ),
      SyncStatus.localOnly => (
        Icons.storage,
        colorScheme.onSurfaceVariant,
        'local_only'.tr(),
      ),
    };

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      subtitle: provider.isNotEmpty
          ? Text('account_signed_in_via'.tr(namedArgs: {'provider': provider}))
          : null,
      trailing: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  static String _getInitials(String? name, String? email) {
    if (name != null && name.isNotEmpty) {
      final parts = name.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return name[0].toUpperCase();
    }
    if (email != null && email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return '?';
  }

  static String _getProviderLabel(User? user) {
    if (user == null) return '';
    final provider = user.appMetadata['provider'] as String?;
    return switch (provider) {
      'google' => 'Google',
      'github' => 'GitHub',
      'email' => 'account_provider_email'.tr(),
      _ => provider ?? '',
    };
  }

  static Future<void> _handleSignOut(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('sign_out_confirm_title'.tr()),
        content: Text('sign_out_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('sign_out'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    ref.read(settings.provider(localOnlySettingDef).notifier).set(true);
    try {
      await ref.read(authServiceProvider).signOut();
    } catch (e, st) {
      Log.warning('Sign-out failed', error: e, stackTrace: st);
    }
    if (!context.mounted) return;
    context.showToast('signed_out_message'.tr());
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

  static Future<void> _resetToOnboarding(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('return_to_onboarding'.tr()),
        content: Text('return_to_onboarding_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('return_to_onboarding'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ref
          .read(settings.provider(onboardingCompletedSettingDef).notifier)
          .set(false);
      if (context.mounted) {
        context.go(RoutePaths.onboarding);
      }
    }
  }

  static Future<void> _resetAllSettings(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('reset_all_settings'.tr()),
        content: Text('reset_all_settings_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('reset_all_settings'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await settings.controller.resetAll();
    if (!context.mounted) return;
    // _LocaleSync handles locale sync automatically via languageProvider
    context.showSuccess('reset_all_settings_done'.tr());
  }

  static Future<void> _showDeleteLocalData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final counts = await _getLocalDataCounts(ref);
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteLocalDataDialogContent(
        groups: counts.groups,
        participants: counts.participants,
        expenses: counts.expenses,
        expenseTags: counts.expenseTags,
        groupInvites: counts.groupInvites,
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        final db = ref.read(powerSyncDatabaseProvider);
        await db.execute('DELETE FROM expenses');
        await db.execute('DELETE FROM expense_tags');
        await db.execute('DELETE FROM participants');
        await db.execute('DELETE FROM group_members');
        await db.execute('DELETE FROM group_invites');
        await db.execute('DELETE FROM groups');
        await db.execute('DELETE FROM pending_writes');
        Log.info('Local data deleted');
        if (context.mounted) {
          final settings = ref.read(hisabSettingsProvidersProvider);
          if (settings != null) {
            ref
                .read(settings.provider(onboardingCompletedSettingDef).notifier)
                .set(false);
          }
          context.showSuccess('delete_local_data_done'.tr());
          context.go(RoutePaths.onboarding);
        }
      } catch (e, st) {
        Log.warning('Delete local data failed', error: e, stackTrace: st);
        if (context.mounted) {
          context.showError('delete_local_data_failed'.tr());
        }
      }
    }
  }

  static Future<({int groups, int participants, int expenses, int expenseTags, int groupInvites})> _getLocalDataCounts(WidgetRef ref) async {
    final db = ref.read(powerSyncDatabaseProvider);
    final groupRows = await db.getAll('SELECT COUNT(*) as cnt FROM groups');
    final participantRows = await db.getAll('SELECT COUNT(*) as cnt FROM participants');
    final expenseRows = await db.getAll('SELECT COUNT(*) as cnt FROM expenses');
    final tagRows = await db.getAll('SELECT COUNT(*) as cnt FROM expense_tags');
    final inviteRows = await db.getAll('SELECT COUNT(*) as cnt FROM group_invites');
    int fromFirst(List<dynamic> rows) {
      if (rows.isEmpty) return 0;
      final r = rows.first;
      if (r is Map) {
        final v = r['cnt'];
        if (v == null) return 0;
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse(v.toString()) ?? 0;
      }
      return 0;
    }
    return (
      groups: fromFirst(groupRows),
      participants: fromFirst(participantRows),
      expenses: fromFirst(expenseRows),
      expenseTags: fromFirst(tagRows),
      groupInvites: fromFirst(inviteRows),
    );
  }

  static Future<void> _showDeleteCloudData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final preview = await ref.read(deleteMyDataServiceProvider).getDeleteMyDataPreview();
      if (!context.mounted) return;
      final result = await showDialog<bool?>(
        context: context,
        builder: (ctx) => _DeleteCloudDataDialogContent(preview: preview),
      );
      // result: null = cancel, true = alsoDeleteLocal, false = cloud only
      if (result == null || !context.mounted) return;
      final alsoDeleteLocal = result;
      await ref.read(deleteMyDataServiceProvider).deleteMyData();
      if (!context.mounted) return;
      await ref.read(authServiceProvider).signOut();
      if (!context.mounted) return;
      if (alsoDeleteLocal) {
        final db = ref.read(powerSyncDatabaseProvider);
        await db.execute('DELETE FROM expenses');
        await db.execute('DELETE FROM expense_tags');
        await db.execute('DELETE FROM participants');
        await db.execute('DELETE FROM group_members');
        await db.execute('DELETE FROM group_invites');
        await db.execute('DELETE FROM groups');
        await db.execute('DELETE FROM pending_writes');
        final settings = ref.read(hisabSettingsProvidersProvider);
        if (settings != null) {
          ref
              .read(settings.provider(onboardingCompletedSettingDef).notifier)
              .set(false);
        }
        if (context.mounted) {
          context.showSuccess('delete_local_data_done'.tr());
          context.go(RoutePaths.onboarding);
        }
      } else if (context.mounted) {
        context.showSuccess('delete_cloud_data_done'.tr());
      }
    } catch (e, st) {
      Log.warning('Delete cloud data failed', error: e, stackTrace: st);
      if (context.mounted) {
        context.showError('delete_cloud_data_failed'.tr());
      }
    }
  }

  Future<void> _handleLocalOnlyChanged(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
    bool v,
  ) async {
    // Switching to local: show confirm then set.
    if (v == true) {
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('local_only_confirm_title'.tr()),
          content: Text('local_only_confirm_body'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('local_only'.tr()),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      ref.read(settings.provider(localOnlySettingDef).notifier).set(true);
      ref
          .read(settings.provider(settingsOnlinePendingSettingDef).notifier)
          .set(false);
      return;
    }

    // Switching to online: need auth.
    if (!supabaseConfigAvailable) return;

    // Check if already signed in.
    final authService = ref.read(authServiceProvider);
    if (authService.isAuthenticated) {
      ref.read(settings.provider(localOnlySettingDef).notifier).set(false);
      return;
    }

    // Show sign-in sheet
    if (!context.mounted) return;
    final result = await showSignInSheet(context, ref);
    switch (result) {
      case SignInResult.success:
        if (!context.mounted) return;
        // Migrate local data to Supabase before switching
        await _runMigration(context, ref, settings);
      case SignInResult.pendingRedirect:
        // OAuth redirect on web — set pending flag, page will reload
        ref
            .read(settings.provider(settingsOnlinePendingSettingDef).notifier)
            .set(true);
        Log.info('Settings OAuth redirect pending (web)');
      case SignInResult.cancelled:
        // User cancelled, keep localOnly as-is
        break;
    }
  }

  static Future<void> _runMigration(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) async {
    final db = ref.read(powerSyncDatabaseProvider);
    final migrationService = MigrationService(db, Supabase.instance.client);

    // Check if there is data to migrate
    final hasData = await migrationService.hasLocalData();
    if (!hasData) {
      // No data — just switch to online
      ref.read(settings.provider(localOnlySettingDef).notifier).set(false);
      Log.info('Switched to online mode (no data to migrate)');
      return;
    }

    if (!context.mounted) return;

    // Show migration progress dialog
    final migrationResult = await showDialog<MigrationResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          _MigrationProgressDialog(migrationService: migrationService),
    );

    if (!context.mounted) return;
    switch (migrationResult) {
      case MigrationResult.success:
      case MigrationResult.noData:
        ref.read(settings.provider(localOnlySettingDef).notifier).set(false);
        Log.info('Switched to online mode after migration');
        context.showSuccess('migration_success'.tr());
      case MigrationResult.failed:
      case null:
        context.showError('migration_failed'.tr());
    }
  }

  Widget _buildLocalOnlyTile(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final onlineAvailable = supabaseConfigAvailable;
    final value = ref.watch(settings.provider(localOnlySettingDef));
    String subtitle = 'local_only_description'.tr();
    if (!onlineAvailable) {
      subtitle = '$subtitle\n${'onboarding_online_unavailable'.tr()}';
    }
    return SwitchSettingsTile.fromSetting(
      setting: localOnlySettingDef,
      title: 'local_only'.tr(),
      subtitle: subtitle,
      value: value,
      onChanged: (v) => _handleLocalOnlyChanged(context, ref, settings, v),
      enabled: onlineAvailable,
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
          isScrollControlled: true,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          builder: (ctx) => SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).padding.bottom + 16,
                ),
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
            ),
          ),
        );
        if (chosen != null && context.mounted) {
          final langCode = chosen.languageCode;
          await ref
              .read(settings.provider(languageSettingDef).notifier)
              .set(langCode);
          // _LocaleSync will call setLocale when it sees provider != context.locale
        }
      },
    );
  }

  Widget _favoriteCurrenciesTile(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final stored = ref.watch(settings.provider(favoriteCurrenciesSettingDef));
    final effective = CurrencyHelpers.getEffectiveFavorites(stored);
    final isCustom = stored.trim().isNotEmpty;

    // Build short labels: "🇸🇦 SAR, 🇯🇵 JPY, ..."
    final labels = effective
        .map((code) {
          final c = CurrencyHelpers.fromCode(code);
          return c != null ? CurrencyHelpers.shortLabel(c) : code;
        })
        .join(', ');

    return ListTile(
      leading: const Icon(Icons.star_outline),
      title: Text('favorite_currencies'.tr()),
      subtitle: Text(
        isCustom ? labels : '${'default'.tr()}: $labels',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isCustom
          ? IconButton(
              icon: const Icon(Icons.restore),
              tooltip: 'reset_to_default'.tr(),
              onPressed: () {
                ref
                    .read(
                      settings.provider(favoriteCurrenciesSettingDef).notifier,
                    )
                    .set('');
              },
            )
          : null,
      onTap: () => _showFavoriteCurrenciesEditor(context, ref, settings),
    );
  }

  void _showFavoriteCurrenciesEditor(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final stored = ref.read(settings.provider(favoriteCurrenciesSettingDef));
    final current = List<String>.from(
      CurrencyHelpers.getEffectiveFavorites(stored),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      builder: (ctx) => _FavoriteCurrenciesSheet(
        initial: current,
        onSave: (updated) {
          final encoded = CurrencyHelpers.encodeFavorites(updated);
          ref
              .read(settings.provider(favoriteCurrenciesSettingDef).notifier)
              .set(encoded);
        },
      ),
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
            return NavigationSettingsTile(
              leading: const Icon(Icons.info_outline),
              title: Text('version'.tr()),
              subtitle: Text(version),
              onTap: () {
                final trigger = ref.read(updateCheckTriggerProvider).callback;
                if (trigger != null) {
                  if (context.mounted) {
                    context.showToast('checking_for_updates'.tr());
                  }
                  trigger(context);
                }
              },
            );
          },
        ),
        NavigationSettingsTile(
          leading: const Icon(Icons.feedback_outlined),
          title: Text('send_feedback'.tr()),
          onTap: () {
            if (!context.mounted) return;
            // Reset controller so sheet can open again after being dismissed (e.g. if user navigated away without submitting).
            BetterFeedback.of(context).hide();
            BetterFeedback.of(context).show(
              (UserFeedback feedback) =>
                  handleFeedback(context, feedback: feedback),
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
        NavigationSettingsTile(
          leading: const Icon(Icons.favorite_outline),
          title: Text('donate'.tr()),
          subtitle: Text('donate_description'.tr()),
          onTap: () => _openDonateLink(context),
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
    final scaffoldContext = context;
    await showDialog(
      context: context,
      builder: (ctx) => LogsViewerDialog(
        content: content,
        onCopy: () async {
          await Clipboard.setData(ClipboardData(text: content));
          if (scaffoldContext.mounted) {
            scaffoldContext.showSuccess('logs_copied'.tr());
          }
        },
        onClear: () async {
          final confirmed = await showDialog<bool>(
            context: ctx,
            builder: (c) => AlertDialog(
              title: Text('clear_logs'.tr()),
              content: Text('clear_logs_confirm'.tr()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: Text('cancel'.tr()),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: Text('clear_logs'.tr()),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            try {
              await LoggingService.clearLogs();
              if (ctx.mounted) Navigator.pop(ctx);
              if (scaffoldContext.mounted) {
                scaffoldContext.showSuccess('logs_cleared'.tr());
              }
            } catch (e) {
              if (scaffoldContext.mounted) {
                scaffoldContext.showToast('logs_not_available'.tr());
              }
            }
          }
        },
        onReportIssue: () => _handleReportIssue(ctx, scaffoldContext, content),
        onClose: () => Navigator.pop(ctx),
      ),
    );
  }

  static Future<void> _handleReportIssue(
    BuildContext dialogContext,
    BuildContext scaffoldContext,
    String logsContent,
  ) async {
    String description = '';
    if (reportIssueUrl.isNotEmpty) {
      final controller = TextEditingController();
      final result = await showDialog<String?>(
        context: dialogContext,
        builder: (c) => AlertDialog(
          title: Text('report_issue'.tr()),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'report_issue_description_hint'.tr(),
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, null),
              child: Text('cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, controller.text.trim()),
              child: Text('done'.tr()),
            ),
          ],
        ),
      );
      if (result == null) return;
      description = result;
    }
    try {
      final formatted = await LoggingService.formatLogsForGitHub(description);
      await Clipboard.setData(ClipboardData(text: formatted));
      if (reportIssueUrl.isNotEmpty) {
        await launchUrl(Uri.parse(reportIssueUrl));
      }
      if (scaffoldContext.mounted) {
        scaffoldContext.showSuccess(
          reportIssueUrl.isEmpty
              ? 'logs_copied_paste'.tr()
              : 'logs_copied'.tr(),
        );
      }
    } catch (e) {
      if (scaffoldContext.mounted) {
        scaffoldContext.showToast('logs_not_available'.tr());
      }
    }
  }

  static Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    try {
      final data = await exportDataToJson(
        groupRepo: ref.read(groupRepositoryProvider),
        participantRepo: ref.read(participantRepositoryProvider),
        expenseRepo: ref.read(expenseRepositoryProvider),
        tagRepo: ref.read(tagRepositoryProvider),
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
          context.showSuccess('export_success'.tr());
        } else {
          context.showToast('export_cancelled'.tr());
        }
      }
    } catch (e, st) {
      Log.warning('Backup export failed', error: e, stackTrace: st);
      if (context.mounted) {
        context.showError('export_failed'.tr());
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
        context.showError('import_failed'.tr());
        return;
      }
      final jsonString = utf8.decode(bytes);
      final parseResult = parseBackupJson(jsonString);
      if (parseResult.data == null) {
        if (context.mounted) {
          final message = parseResult.errorMessageKey?.tr() ?? 'import_invalid_file'.tr();
          context.showError(message);
        }
        return;
      }
      final backup = parseResult.data!;
      final groupRepo = ref.read(groupRepositoryProvider);
      final participantRepo = ref.read(participantRepositoryProvider);
      final expenseRepo = ref.read(expenseRepositoryProvider);
      final tagRepo = ref.read(tagRepositoryProvider);
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
      for (final oldId in backup.localArchivedGroupIds) {
        final newId = idMap[oldId];
        if (newId != null) {
          await groupRepo.setLocalArchived(newId);
        }
      }
      Log.info('Backup import completed');
      if (context.mounted) {
        context.showSuccess('import_success'.tr());
      }
    } catch (e, st) {
      Log.warning('Backup import failed', error: e, stackTrace: st);
      if (context.mounted) {
        context.showError('import_failed'.tr());
      }
    }
  }

  static void _showLicenses(BuildContext context) {
    showLicensePage(context: context, applicationName: 'Hisab');
  }

  static const String _donateUrl = 'https://github.com/Zyzto';

  static Future<void> _openDonateLink(BuildContext context) async {
    final uri = Uri.parse(_donateUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        context.showToast('donate'.tr());
      }
    }
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

// =============================================================================
// Migration Progress Dialog
// =============================================================================

class _MigrationProgressDialog extends StatefulWidget {
  final MigrationService migrationService;
  const _MigrationProgressDialog({required this.migrationService});

  @override
  State<_MigrationProgressDialog> createState() =>
      _MigrationProgressDialogState();
}

class _MigrationProgressDialogState extends State<_MigrationProgressDialog> {
  int _completed = 0;
  int _total = 1;

  @override
  void initState() {
    super.initState();
    _runMigration();
  }

  Future<void> _runMigration() async {
    final result = await widget.migrationService.migrateLocalToOnline(
      onProgress: (completed, total) {
        if (mounted) {
          setState(() {
            _completed = completed;
            _total = total;
          });
        }
      },
    );
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total > 0 ? _completed / _total : 0.0;
    return AlertDialog(
      title: Text('migration_title'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('migration_uploading'.tr()),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 8),
          Text('$_completed / $_total'),
        ],
      ),
    );
  }
}

// =============================================================================
// Favorite Currencies Editor Sheet
// =============================================================================

class _FavoriteCurrenciesSheet extends StatefulWidget {
  final List<String> initial;
  final ValueChanged<List<String>> onSave;

  const _FavoriteCurrenciesSheet({required this.initial, required this.onSave});

  @override
  State<_FavoriteCurrenciesSheet> createState() =>
      _FavoriteCurrenciesSheetState();
}

class _FavoriteCurrenciesSheetState extends State<_FavoriteCurrenciesSheet> {
  late List<String> _codes;

  @override
  void initState() {
    super.initState();
    _codes = List<String>.from(widget.initial);
  }

  void _addCurrency() {
    CurrencyHelpers.showPicker(
      context: context,
      onSelect: (currency) {
        if (!_codes.contains(currency.code)) {
          setState(() => _codes.add(currency.code));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'favorite_currencies'.tr(),
                    style: textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'add_currency'.tr(),
                  onPressed: _addCurrency,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'favorite_currencies_hint'.tr(),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // List
          if (_codes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'favorite_currencies_empty'.tr(),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ReorderableListView.builder(
                itemCount: _codes.length,
                shrinkWrap: true,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _codes.removeAt(oldIndex);
                    _codes.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final code = _codes[index];
                  final currency = CurrencyHelpers.fromCode(code);
                  final flag = currency != null
                      ? CurrencyUtils.currencyToEmoji(currency)
                      : '';
                  final name = currency?.name ?? code;

                  return ListTile(
                    key: ValueKey(code),
                    leading: Text(flag, style: const TextStyle(fontSize: 24)),
                    title: Text('$code - $name'),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: colorScheme.error,
                      ),
                      onPressed: () {
                        setState(() => _codes.removeAt(index));
                      },
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          // Actions
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('cancel'.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      widget.onSave(_codes);
                      Navigator.pop(context);
                    },
                    child: Text('done'.tr()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteLocalDataDialogContent extends StatefulWidget {
  const _DeleteLocalDataDialogContent({
    required this.groups,
    required this.participants,
    required this.expenses,
    required this.expenseTags,
    required this.groupInvites,
  });

  final int groups;
  final int participants;
  final int expenses;
  final int expenseTags;
  final int groupInvites;

  @override
  State<_DeleteLocalDataDialogContent> createState() =>
      _DeleteLocalDataDialogContentState();
}

class _DeleteLocalDataDialogContentState
    extends State<_DeleteLocalDataDialogContent> {
  int _secondsLeft = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _secondsLeft <= 0;
    final summary = 'delete_local_data_summary'.tr(namedArgs: {
      'groups': '${widget.groups}',
      'participants': '${widget.participants}',
      'expenses': '${widget.expenses}',
    });
    return AlertDialog(
      title: Text('delete_local_data'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary),
            const SizedBox(height: 16),
            Text(
              canConfirm
                  ? 'delete_confirm_ready'.tr()
                  : 'delete_confirm_countdown'.tr(namedArgs: {
                      'seconds': '$_secondsLeft',
                    }),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('cancel'.tr()),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: canConfirm ? () => Navigator.pop(context, true) : null,
          child: Text('delete_local_data_confirm_label'.tr()),
        ),
      ],
    );
  }
}

class _DeleteCloudDataDialogContent extends StatefulWidget {
  const _DeleteCloudDataDialogContent({required this.preview});

  final DeleteMyDataPreview preview;

  @override
  State<_DeleteCloudDataDialogContent> createState() =>
      _DeleteCloudDataDialogContentState();
}

class _DeleteCloudDataDialogContentState
    extends State<_DeleteCloudDataDialogContent> {
  int _secondsLeft = 30;
  bool _alsoDeleteLocal = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _secondsLeft <= 0;
    final p = widget.preview;
    final summary = 'delete_cloud_data_summary'.tr(namedArgs: {
      'ownerGroups': '${p.groupsWhereOwner}',
      'memberships': '${p.groupMemberships}',
      'tokens': '${p.deviceTokensCount}',
      'invites': '${p.inviteUsagesCount}',
    });
    return AlertDialog(
      title: Text('delete_cloud_data'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary),
            if (p.soleMemberGroupCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                'delete_cloud_data_sole_member_warning'.tr(namedArgs: {
                  'count': '${p.soleMemberGroupCount}',
                }),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _alsoDeleteLocal,
              onChanged: (v) => setState(() => _alsoDeleteLocal = v ?? false),
              title: Text('also_delete_local_data_option'.tr()),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            Text(
              canConfirm
                  ? 'delete_confirm_ready'.tr()
                  : 'delete_confirm_countdown'.tr(namedArgs: {
                      'seconds': '$_secondsLeft',
                    }),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text('cancel'.tr()),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: canConfirm
              ? () => Navigator.pop(context, _alsoDeleteLocal)
              : null,
          child: Text('delete_cloud_data_confirm_label'.tr()),
        ),
      ],
    );
  }
}
