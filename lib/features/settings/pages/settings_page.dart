import 'dart:async';
import 'dart:convert';
import 'package:currency_picker/currency_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
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
import '../../../core/log_web.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/layout/content_aligned_app_bar.dart';
import '../../../core/layout/constrained_content.dart';
import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/update/update_check_providers.dart';
import '../../../core/services/migration_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/delete_my_data_service.dart';
import '../../../core/services/github_user_client.dart';
import '../../../core/utils/currency_helpers.dart';
import '../settings_definitions.dart';
import '../providers/settings_framework_providers.dart';
import '../backup_helper.dart';
import '../feedback_handler.dart';
import '../widgets/logs_viewer_dialog.dart';
import '../../../core/theme/flex_theme_builder.dart'
    show flexSchemeOptionIds, primaryColorForSchemeId;
import '../widgets/change_password_sheet.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/setting_tile_helper.dart';
import '../sections/settings_functional_section.dart';
import '../sections/settings_privacy_section.dart';
import '../sections/settings_advanced_section.dart';
import '../sections/settings_data_backup_section.dart';
import '../sections/settings_receipt_ai_section.dart';
import '../../../core/auth/predefined_avatars.dart';
import '../../../core/widgets/sheet_helpers.dart';
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
      return LayoutBuilder(
        builder: (context, layoutConstraints) {
          return Scaffold(
            appBar: ContentAlignedAppBar(
              contentAreaWidth: layoutConstraints.maxWidth,
              leading: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: SyncStatusChip(),
              ),
              title: Text('settings'.tr()),
            ),
            body: Center(child: Text('settings_unavailable'.tr())),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, layoutConstraints) {
        return Scaffold(
          appBar: ContentAlignedAppBar(
            contentAreaWidth: layoutConstraints.maxWidth,
            leading: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: SyncStatusChip(),
            ),
            title: Text('settings'.tr()),
          ),
          body: ConstrainedContent(
        child: ListView(
          key: const PageStorageKey<String>('settings_list'),
          children: [
            _buildAccountSection(context, ref, settings),
            // Appearance: merged General + old Appearance
            _buildSection(context, ref, settings, appearanceSection, [
              _languageTile(context, ref, settings),
              _themeModeTile(context, ref, settings),
              _themeSchemeTile(context, ref, settings),
              _fontSizeTile(context, ref, settings),
              _favoriteCurrenciesTile(context, ref, settings),
              _displayCurrencyTile(context, ref, settings),
              buildBoolSettingTile(
                ref,
                settings,
                use24HourFormatSettingDef,
                titleKey: 'use_24_hour_format',
                subtitleKey: 'use_24_hour_format_description',
              ),
            ]),
            // Functional: behavior toggles (expense form mode, etc.)
            _buildSection(
              context,
              ref,
              settings,
              functionalSection,
              buildFunctionalSectionTiles(context, ref, settings),
            ),
            // Data & Backup: merged Data + old Backup
            _buildSection(
              context,
              ref,
              settings,
              dataBackupSection,
              buildDataBackupSectionTiles(
                context,
                ref,
                settings,
                localOnlyTile: _buildLocalOnlyTile(context, ref, settings),
                onExport: () => _exportData(context, ref),
                onImport: () => _importData(context, ref),
              ),
            ),
            _buildSection(
              context,
              ref,
              settings,
              receiptAiSection,
              buildReceiptAiSectionTiles(
                context,
                ref,
                settings,
                ({
                  required BuildContext context,
                  required WidgetRef ref,
                  required String titleKey,
                  required String currentValue,
                  required StringSetting settingDef,
                }) => _showApiKeyDialog(
                  context: context,
                  ref: ref,
                  titleKey: titleKey,
                  currentValue: currentValue,
                  settingDef: settingDef,
                ),
              ),
            ),
            // Privacy: renamed from Logging
            _buildSection(
              context,
              ref,
              settings,
              privacySection,
              buildPrivacySectionTiles(context, ref, settings),
            ),
            _buildSection(
              context,
              ref,
              settings,
              advancedSection,
              buildAdvancedSectionTiles(
                context,
                ref,
                settings,
                onReturnToOnboarding: () =>
                    _resetToOnboarding(context, ref, settings),
                onViewLogs: () => _showLogsDialog(context),
                onResetAllSettings: () =>
                    _resetAllSettings(context, ref, settings),
                onDeleteLocalData: () => _showDeleteLocalData(context, ref),
                onDeleteCloudData: () => _showDeleteCloudData(context, ref),
                supabaseAvailable: supabaseConfigAvailable,
                isSignedIn: ref.watch(currentUserProvider) != null,
              ),
            ),
            _buildAboutSection(context, ref, settings),
          ],
        ),
      ),
    );
      },
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
          // Change password (email/password users only)
          if (user != null &&
              (user.appMetadata['provider'] as String?) == 'email') ...[
            ActionSettingsTile(
              leading: const Icon(Icons.lock_outline),
              title: Text('change_password'.tr()),
              onTap: () => showChangePasswordSheet(context, ref),
            ),
          ],
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
    final confirmed = await showConfirmSheet(
      context,
      title: 'sign_out_confirm_title'.tr(),
      content: 'sign_out_confirm_body'.tr(),
      confirmLabel: 'sign_out'.tr(),
    );
    if (confirmed != true || !context.mounted) return;
    // Record current user so we can skip migration when they sign back in (same flow as online→local→online)
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) {
      ref
          .read(settings.provider(localDataFromOnlineUserIdSettingDef).notifier)
          .set(currentUser.id);
    }
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
    final confirmed = await showConfirmSheet(
      context,
      title: 'return_to_onboarding'.tr(),
      content: 'return_to_onboarding_confirm'.tr(),
      confirmLabel: 'return_to_onboarding'.tr(),
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
    final confirmed = await showConfirmSheet(
      context,
      title: 'reset_all_settings'.tr(),
      content: 'reset_all_settings_confirm'.tr(),
      confirmLabel: 'reset_all_settings'.tr(),
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
    final confirmed = await showResponsiveSheet<bool>(
      context: context,
      title: 'delete_local_data'.tr(),
      maxHeight: MediaQuery.of(context).size.height * 0.75,
      isScrollControlled: true,
      child: _DeleteLocalDataDialogContent(
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

  static Future<
    ({
      int groups,
      int participants,
      int expenses,
      int expenseTags,
      int groupInvites,
    })
  >
  _getLocalDataCounts(WidgetRef ref) async {
    final db = ref.read(powerSyncDatabaseProvider);
    final groupRows = await db.getAll('SELECT COUNT(*) as cnt FROM groups');
    final participantRows = await db.getAll(
      'SELECT COUNT(*) as cnt FROM participants',
    );
    final expenseRows = await db.getAll('SELECT COUNT(*) as cnt FROM expenses');
    final tagRows = await db.getAll('SELECT COUNT(*) as cnt FROM expense_tags');
    final inviteRows = await db.getAll(
      'SELECT COUNT(*) as cnt FROM group_invites',
    );
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
      final preview = await ref
          .read(deleteMyDataServiceProvider)
          .getDeleteMyDataPreview();
      if (!context.mounted) return;
      final result = await showResponsiveSheet<bool?>(
        context: context,
        title: 'delete_cloud_data'.tr(),
        maxHeight: MediaQuery.of(context).size.height * 0.75,
        isScrollControlled: true,
        child: _DeleteCloudDataDialogContent(preview: preview),
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
      final confirmed = await showConfirmSheet(
        context,
        title: 'local_only_confirm_title'.tr(),
        content: 'local_only_confirm_body'.tr(),
        confirmLabel: 'local_only'.tr(),
      );
      if (confirmed != true || !context.mounted) return;
      ref.read(settings.provider(localOnlySettingDef).notifier).set(true);
      ref
          .read(settings.provider(settingsOnlinePendingSettingDef).notifier)
          .set(false);
      // Record that local data was from online so we can skip migration when switching back with same user
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        ref
            .read(
              settings.provider(localDataFromOnlineUserIdSettingDef).notifier,
            )
            .set(currentUser.id);
      }
      return;
    }

    // Switching to online: need auth.
    if (!supabaseConfigAvailable) return;

    // Check if already signed in.
    final authService = ref.read(authServiceProvider);
    if (authService.isAuthenticated) {
      ref.read(settings.provider(localOnlySettingDef).notifier).set(false);
      ref
          .read(settings.provider(localDataFromOnlineUserIdSettingDef).notifier)
          .set('');
      await ref.read(dataSyncServiceProvider.notifier).syncNow();
      return;
    }

    // Show sign-in sheet
    if (!context.mounted) return;
    final result = await showSignInSheet(context, ref);
    switch (result) {
      case SignInResult.success:
        if (!context.mounted) return;
        // Skip migration if local data was from server (online → local → online, same user)
        final fromOnlineUserId = ref.read(
          settings.provider(localDataFromOnlineUserIdSettingDef),
        );
        final currentUser = ref.read(currentUserProvider);
        if (fromOnlineUserId.isNotEmpty &&
            currentUser != null &&
            fromOnlineUserId == currentUser.id) {
          ref.read(settings.provider(localOnlySettingDef).notifier).set(false);
          ref
              .read(
                settings.provider(localDataFromOnlineUserIdSettingDef).notifier,
              )
              .set('');
          Log.info(
            'Switched to online (data was from server, skipping migration)',
          );
          await ref.read(dataSyncServiceProvider.notifier).syncNow();
          if (context.mounted) {
            context.showSuccess('switched_to_online_syncing'.tr());
          }
          return;
        }
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
    final client = supabaseClientIfConfigured;
    if (client == null) return;
    final db = ref.read(powerSyncDatabaseProvider);
    final migrationService = MigrationService(db, client);

    // Check if there is data to migrate
    final hasData = await migrationService.hasLocalData();
    if (!hasData) {
      // No data — just switch to online
      ref.read(settings.provider(localOnlySettingDef).notifier).set(false);
      ref
          .read(settings.provider(localDataFromOnlineUserIdSettingDef).notifier)
          .set('');
      Log.info('Switched to online mode (no data to migrate)');
      await ref.read(dataSyncServiceProvider.notifier).syncNow();
      return;
    }

    if (!context.mounted) return;

    // Show migration progress sheet
    final migrationResult = await showResponsiveSheet<MigrationResult>(
      context: context,
      title: 'migration_title'.tr(),
      barrierDismissible: true,
      maxHeight: MediaQuery.of(context).size.height * 0.5,
      isScrollControlled: true,
      child: _MigrationProgressDialog(migrationService: migrationService),
    );

    if (!context.mounted) return;
    switch (migrationResult) {
      case MigrationResult.success:
      case MigrationResult.noData:
        ref.read(settings.provider(localOnlySettingDef).notifier).set(false);
        ref
            .read(
              settings.provider(localDataFromOnlineUserIdSettingDef).notifier,
            )
            .set('');
        Log.info('Switched to online mode after migration');
        await ref.read(dataSyncServiceProvider.notifier).syncNow();
        if (!context.mounted) return;
        context.showSuccess('migration_success'.tr());
        break;
      case MigrationResult.failed:
      case null:
        if (context.mounted) context.showError('migration_failed'.tr());
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
        final chosen = await showResponsiveSheet<Locale>(
          context: context,
          title: 'language'.tr(),
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

  static const _themeModeOptions = ['system', 'light', 'dark', 'amoled'];

  Widget _themeModeTile(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final value = ref.watch(settings.provider(themeModeSettingDef));
    return ListTile(
      leading: Icon(themeModeSettingDef.icon),
      title: Text('theme'.tr()),
      subtitle: Text(value.tr()),
      onTap: () async {
        final chosen = await showResponsiveSheet<String>(
          context: context,
          title: 'theme'.tr(),
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
                            'theme'.tr(),
                            style: Theme.of(ctx).textTheme.titleMedium,
                          ),
                        ),
                      ..._themeModeOptions.map(
                        (option) => ListTile(
                          title: Text(option.tr()),
                          onTap: () => Navigator.of(ctx).pop(option),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        if (chosen != null && context.mounted) {
          ref.read(settings.provider(themeModeSettingDef).notifier).set(chosen);
        }
      },
    );
  }

  /// Preset theme colors for "Custom" scheme: (value as int, label key for .tr()).
  static const _themeColorPresets = [
    (0xFF2E7D32, 'green'),
    (0xFF1565C0, 'blue'),
    (0xFF00897B, 'teal'),
    (0xFF6A1B9A, 'purple'),
    (0xFFC62828, 'red'),
    (0xFFE65100, 'orange'),
  ];

  Widget _themeSchemeTile(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final schemeValue = ref.watch(settings.provider(themeSchemeSettingDef));
    final themeColorValue = ref.watch(settings.provider(themeColorSettingDef));
    final currentLabel = 'theme_scheme_$schemeValue'.tr();
    final displayColor = schemeValue == 'custom'
        ? Color(themeColorValue)
        : primaryColorForSchemeId(schemeValue);
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: displayColor != Colors.transparent
              ? displayColor
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1.5,
          ),
        ),
        child: displayColor == Colors.transparent
            ? Icon(themeSchemeSettingDef.icon, size: 22)
            : null,
      ),
      title: Text('color_scheme'.tr()),
      subtitle: Text(currentLabel),
      onTap: () async {
        final chosenScheme = await showResponsiveSheet<String>(
          context: context,
          title: 'color_scheme'.tr(),
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
                            'color_scheme'.tr(),
                            style: Theme.of(ctx).textTheme.titleMedium,
                          ),
                        ),
                      ...flexSchemeOptionIds.map(
                        (schemeId) {
                          final chipColor = schemeId == 'custom'
                              ? Color(themeColorValue)
                              : primaryColorForSchemeId(schemeId);
                          return ListTile(
                            leading: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: chipColor != Colors.transparent
                                    ? chipColor
                                    : Theme.of(ctx)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(ctx).colorScheme.outline,
                                ),
                              ),
                            ),
                            title: Text('theme_scheme_$schemeId'.tr()),
                            onTap: () => Navigator.of(ctx).pop(schemeId),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        if (chosenScheme != null && context.mounted) {
          ref
              .read(settings.provider(themeSchemeSettingDef).notifier)
              .set(chosenScheme);
          if (chosenScheme == 'custom') {
            final chosenColor = await showResponsiveSheet<int>(
              context: context,
              title: 'select_theme_color'.tr(),
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
                                'select_theme_color'.tr(),
                                style: Theme.of(ctx).textTheme.titleMedium,
                              ),
                            ),
                          ..._themeColorPresets.map(
                            (preset) => ListTile(
                              leading: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Color(preset.$1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(ctx).colorScheme.outline,
                                  ),
                                ),
                              ),
                              title: Text(preset.$2.tr()),
                              onTap: () => Navigator.of(ctx).pop(preset.$1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            if (chosenColor != null && context.mounted) {
              ref
                  .read(settings.provider(themeColorSettingDef).notifier)
                  .set(chosenColor);
            }
          }
        }
      },
    );
  }

  static const _fontSizeOptions = ['small', 'normal', 'large', 'extra_large'];

  Widget _fontSizeTile(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final value = ref.watch(settings.provider(fontSizeScaleSettingDef));
    return ListTile(
      leading: Icon(fontSizeScaleSettingDef.icon),
      title: Text('font_size'.tr()),
      subtitle: Text(value.tr()),
      onTap: () async {
        final chosen = await showResponsiveSheet<String>(
          context: context,
          title: 'font_size'.tr(),
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
                            'font_size'.tr(),
                            style: Theme.of(ctx).textTheme.titleMedium,
                          ),
                        ),
                      ..._fontSizeOptions.map(
                        (option) => ListTile(
                          title: Text(option.tr()),
                          onTap: () => Navigator.of(ctx).pop(option),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        if (chosen != null && context.mounted) {
          ref
              .read(settings.provider(fontSizeScaleSettingDef).notifier)
              .set(chosen);
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

  Widget _displayCurrencyTile(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final stored = ref.watch(settings.provider(displayCurrencySettingDef)).trim();
    final label = stored.isEmpty
        ? 'display_currency_none'.tr()
        : (CurrencyHelpers.fromCode(stored) != null
            ? CurrencyHelpers.shortLabel(CurrencyHelpers.fromCode(stored)!)
            : stored);

    return ListTile(
      leading: const Icon(Icons.visibility_outlined),
      title: Text('display_currency'.tr()),
      subtitle: Text(
        'display_currency_hint'.tr(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (stored.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (stored.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'display_currency_none'.tr(),
              onPressed: () {
                ref
                    .read(settings.provider(displayCurrencySettingDef).notifier)
                    .set('');
              },
            ),
        ],
      ),
      onTap: () => _showDisplayCurrencyPicker(context, ref, settings),
    );
  }

  void _showDisplayCurrencyPicker(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final favorites = CurrencyHelpers.getEffectiveFavorites(
      ref.read(favoriteCurrenciesProvider),
    );
    CurrencyHelpers.showPicker(
      context: context,
      centerInFullViewport: false,
      favorite: favorites,
      onSelect: (currency) {
        ref
            .read(settings.provider(displayCurrencySettingDef).notifier)
            .set(currency.code);
      },
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

    showResponsiveSheet<void>(
      context: context,
      title: 'favorite_currencies'.tr(),
      maxHeight: MediaQuery.of(context).size.height * 0.75,
      isScrollControlled: true,
      child: _FavoriteCurrenciesSheet(
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
            final isWeb = kIsWeb;
            return NavigationSettingsTile(
              leading: const Icon(Icons.info_outline),
              title: Text('version'.tr()),
              subtitle: Text(version),
              onTap: isWeb
                  ? null
                  : () {
                      final trigger =
                          ref.read(updateCheckTriggerProvider).callback;
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
          subtitle: Text('about_me_description'.tr()),
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
    final value = await showTextInputSheet(
      context,
      title: titleKey.tr(),
      hint: 'receipt_ai_key_hint'.tr(),
      initialValue: currentValue,
      obscureText: true,
    );
    if (value != null && context.mounted) {
      try {
        final settings = ref.read(hisabSettingsProvidersProvider);
        if (settings != null) {
          ref.read(settings.provider(settingDef).notifier).set(value);
        }
      } catch (e) {
        Log.warning('Failed to set API key', error: e);
      }
    }
  }

  static Future<void> _showLogsDialog(BuildContext context) async {
    Log.debug('Opening logs dialog');
    String content;
    if (kIsWeb) {
      content = getWebLogContent();
      if (content.isEmpty) {
        content = 'logs_web_empty'.tr();
      }
    } else {
      try {
        content = await LoggingService.getLogContent(maxLines: 500);
      } catch (e) {
        content = 'logs_not_available'.tr();
      }
    }
    if (!context.mounted) return;
    final scaffoldContext = context;
    await showResponsiveSheet<void>(
      context: context,
      title: 'view_logs'.tr(),
      maxWidth: 600,
      maxHeight: 700,
      centerInFullViewport: false,
      barrierDismissible: false,
      child: Builder(
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).padding.bottom + 16,
          ),
          child: LogsViewerDialog(
            content: content,
            onCopy: () async {
              await Clipboard.setData(ClipboardData(text: content));
              if (scaffoldContext.mounted) {
                scaffoldContext.showSuccess('logs_copied'.tr());
              }
            },
            onClear: () async {
              final confirmed = await showConfirmSheet(
                ctx,
                title: 'clear_logs'.tr(),
                content: 'clear_logs_confirm'.tr(),
                confirmLabel: 'clear_logs'.tr(),
              );
              if (confirmed == true) {
                if (kIsWeb) {
                  clearWebLogContent();
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (scaffoldContext.mounted) {
                    scaffoldContext.showSuccess('logs_cleared'.tr());
                  }
                } else {
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
              }
            },
            onReportIssue: () =>
                _handleReportIssue(ctx, scaffoldContext, content),
            onClose: () => Navigator.pop(ctx),
          ),
        ),
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
      final result = await showTextInputSheet(
        dialogContext,
        title: 'report_issue'.tr(),
        hint: 'report_issue_description_hint'.tr(),
        maxLines: 3,
      );
      if (result == null) return;
      description = result;
    }
    try {
      final String formatted = kIsWeb
          ? '**Description**\n$description\n\n**Logs**\n$logsContent'
          : await LoggingService.formatLogsForGitHub(description);
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
    final confirmed = await showConfirmSheet(
      context,
      title: 'import_data'.tr(),
      content: 'import_confirm'.tr(),
      confirmLabel: 'import_data'.tr(),
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
          final message =
              parseResult.errorMessageKey?.tr() ?? 'import_invalid_file'.tr();
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
        final newId = await groupRepo.create(
          g.name,
          g.currencyCode,
          icon: g.icon,
          color: g.color,
          isPersonal: g.isPersonal,
          budgetAmountCents: g.budgetAmountCents,
        );
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
            receiptImagePaths: e.receiptImagePaths,
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
    showLicensePage(context: context, applicationName: 'app_name'.tr());
  }

  static Future<void> _openDonateLink(BuildContext context) async {
    final uri = Uri.parse(githubDonateUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        context.showToast('donate'.tr());
      }
    }
  }

  static void _showAboutMe(BuildContext context) {
    showResponsiveSheet<void>(
      context: context,
      title: 'about_me'.tr(),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!LayoutBreakpoints.isTabletOrWider(context))
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'about_me'.tr(),
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _AboutMeDialogContent(
                      profileUrl: githubDeveloperProfileUrl,
                      username: githubDeveloperUsername,
                    ),
                  ),
                  if (!LayoutBreakpoints.isTabletOrWider(context)) ...[
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('done'.tr()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// About me dialog content (developer info from GitHub)
// =============================================================================

class _AboutMeDialogContent extends StatefulWidget {
  const _AboutMeDialogContent({
    required this.profileUrl,
    required this.username,
  });

  final String profileUrl;
  final String username;

  @override
  State<_AboutMeDialogContent> createState() => _AboutMeDialogContentState();
}

class _AboutMeDialogContentState extends State<_AboutMeDialogContent> {
  GitHubUserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final p = await fetchGitHubUser(widget.username);
      if (mounted) {
        setState(() {
          _profile = p;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final profile = _profile;
    final displayName = profile?.displayName ?? widget.username;
    final avatarUrl = profile?.avatarUrl;
    final bio = profile?.bio;
    final location = profile?.location;
    final blog = profile?.blog;
    final linkUrl = profile?.htmlUrl ?? widget.profileUrl;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (avatarUrl != null && avatarUrl.isNotEmpty)
          ClipOval(
            child: Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              width: 80,
              height: 80,
              errorBuilder: (_, _, _) => Container(
                width: 80,
                height: 80,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.person,
                  size: 40,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          CircleAvatar(
            radius: 40,
            child: Icon(
              Icons.person,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'about_me_summary'.tr(),
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        if (bio != null && bio.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            bio.trim(),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
        if (location != null && location.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            location.trim(),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        if (blog != null && blog.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            blog.trim(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () async {
            final uri = Uri.parse(linkUrl);
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {}
          },
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text('view_profile'.tr()),
        ),
      ],
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
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!LayoutBreakpoints.isTabletOrWider(context))
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'migration_title'.tr(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('migration_uploading'.tr()),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text('$_completed / $_total'),
                ],
              ),
            ),
          ],
        ),
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
      centerInFullViewport: false,
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
          // Header
          if (!LayoutBreakpoints.isTabletOrWider(context))
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
          if (LayoutBreakpoints.isTabletOrWider(context))
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
                if (!LayoutBreakpoints.isTabletOrWider(context)) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('cancel'.tr()),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      if (!listEquals(_codes, widget.initial)) {
                        widget.onSave(_codes);
                      }
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
    final summary = 'delete_local_data_summary'.tr(
      namedArgs: {
        'groups': '${widget.groups}',
        'participants': '${widget.participants}',
        'expenses': '${widget.expenses}',
      },
    );
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!LayoutBreakpoints.isTabletOrWider(context))
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'delete_local_data'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary),
                    const SizedBox(height: 16),
                    Text(
                      canConfirm
                          ? 'delete_confirm_ready'.tr()
                          : 'delete_confirm_countdown'.tr(
                              namedArgs: {'seconds': '$_secondsLeft'},
                            ),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!LayoutBreakpoints.isTabletOrWider(context))
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('cancel'.tr()),
                      ),
                    if (!LayoutBreakpoints.isTabletOrWider(context))
                      const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: canConfirm
                          ? () => Navigator.pop(context, true)
                          : null,
                      child: Text('delete_local_data_confirm_label'.tr()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
    final summary = 'delete_cloud_data_summary'.tr(
      namedArgs: {
        'ownerGroups': '${p.groupsWhereOwner}',
        'memberships': '${p.groupMemberships}',
        'tokens': '${p.deviceTokensCount}',
        'invites': '${p.inviteUsagesCount}',
      },
    );
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!LayoutBreakpoints.isTabletOrWider(context))
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'delete_cloud_data'.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary),
                    if (p.soleMemberGroupCount > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'delete_cloud_data_sole_member_warning'.tr(
                          namedArgs: {'count': '${p.soleMemberGroupCount}'},
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: _alsoDeleteLocal,
                      onChanged: (v) =>
                          setState(() => _alsoDeleteLocal = v ?? false),
                      title: Text('also_delete_local_data_option'.tr()),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      canConfirm
                          ? 'delete_confirm_ready'.tr()
                          : 'delete_confirm_countdown'.tr(
                              namedArgs: {'seconds': '$_secondsLeft'},
                            ),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!LayoutBreakpoints.isTabletOrWider(context))
                      TextButton(
                        onPressed: () => Navigator.pop(context, null),
                        child: Text('cancel'.tr()),
                      ),
                    if (!LayoutBreakpoints.isTabletOrWider(context))
                      const SizedBox(width: 8),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
