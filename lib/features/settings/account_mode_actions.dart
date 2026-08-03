import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/sign_in_sheet.dart';
import '../../core/constants/supabase_config.dart';
import '../../core/database/database_providers.dart';
import '../../core/layout/responsive_sheet.dart';
import '../../core/services/migration_service.dart';
import '../../core/widgets/sheet_helpers.dart';
import '../../core/widgets/toast.dart';
import 'settings_definitions.dart';
import 'widgets/migration_progress_sheet.dart';

/// Shared account / online-mode actions used by Profile and Settings.
class AccountModeActions {
  AccountModeActions._();

  static String initials(String? name, String? email) {
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

  static String providerLabel(dynamic user) {
    if (user == null) return '';
    final provider = user.appMetadata['provider'] as String?;
    return switch (provider) {
      'google' => 'Google',
      'github' => 'GitHub',
      'email' => 'account_provider_email'.tr(),
      _ => provider ?? '',
    };
  }

  static Future<void> handleSignOut(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) async {
    final confirmed = await showConfirmSheet(
      context,
      title: 'sign_out_confirm_title'.tr(),
      content: 'sign_out_confirm_body'.tr(),
      confirmLabel: 'sign_out'.tr(),
      centerInFullViewport: false,
    );
    if (confirmed != true || !context.mounted) return;
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) {
      ref
          .read(settings.provider(localDataFromOnlineUserIdSettingDef).notifier)
          .set(currentUser.id);
      Log.info(
        'Setting changed: ${localDataFromOnlineUserIdSettingDef.key}=${currentUser.id}',
      );
    }
    ref.read(settings.provider(localOnlySettingDef).notifier).set(true);
    Log.info('Setting changed: ${localOnlySettingDef.key}=true');
    try {
      await ref.read(authServiceProvider).signOut();
    } catch (e, st) {
      Log.warning('Sign-out failed', error: e, stackTrace: st);
    }
    if (!context.mounted) return;
    context.showToast('signed_out_message'.tr());
  }

  static Future<void> handleLocalOnlyChanged(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
    bool v,
  ) async {
    if (v == true) {
      if (!context.mounted) return;
      final confirmed = await showConfirmSheet(
        context,
        title: 'local_only_confirm_title'.tr(),
        content: 'local_only_confirm_body'.tr(),
        confirmLabel: 'local_only'.tr(),
        centerInFullViewport: false,
      );
      if (confirmed != true || !context.mounted) return;
      ref.read(settings.provider(localOnlySettingDef).notifier).set(true);
      ref
          .read(settings.provider(settingsOnlinePendingSettingDef).notifier)
          .set(false);
      Log.info(
        'Setting changed: ${localOnlySettingDef.key}=true, '
        '${settingsOnlinePendingSettingDef.key}=false',
      );
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        ref
            .read(
              settings.provider(localDataFromOnlineUserIdSettingDef).notifier,
            )
            .set(currentUser.id);
        Log.info(
          'Setting changed: ${localDataFromOnlineUserIdSettingDef.key}=${currentUser.id}',
        );
      }
      return;
    }

    if (!supabaseConfigAvailable) return;

    final authService = ref.read(authServiceProvider);
    if (authService.isAuthenticated) {
      ref.read(settings.provider(localOnlySettingDef).notifier).set(false);
      ref
          .read(settings.provider(localDataFromOnlineUserIdSettingDef).notifier)
          .set('');
      Log.info(
        'Setting changed: ${localOnlySettingDef.key}=false, '
        '${localDataFromOnlineUserIdSettingDef.key}=(cleared)',
      );
      await ref.read(dataSyncServiceProvider.notifier).syncNow();
      return;
    }

    if (!context.mounted) return;
    final result = await showSignInSheet(context, ref);
    switch (result) {
      case SignInResult.success:
        if (!context.mounted) return;
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
            'Setting changed: ${localOnlySettingDef.key}=false, '
            '${localDataFromOnlineUserIdSettingDef.key}=(cleared)',
          );
          Log.info(
            'Switched to online (data was from server, skipping migration)',
          );
          await ref.read(dataSyncServiceProvider.notifier).syncNow();
          if (context.mounted) {
            context.showSuccess('switched_to_online_syncing'.tr());
          }
          return;
        }
        await runMigration(context, ref, settings);
      case SignInResult.pendingRedirect:
      case SignInResult.pendingEmailLink:
        ref
            .read(settings.provider(settingsOnlinePendingSettingDef).notifier)
            .set(true);
        Log.info(
          'Setting changed: ${settingsOnlinePendingSettingDef.key}=true '
          '(${result.name})',
        );
      case SignInResult.cancelled:
        break;
    }
  }

  static Future<void> runMigration(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) async {
    final client = supabaseClientIfConfigured;
    if (client == null) return;
    final db = ref.read(powerSyncDatabaseProvider);
    final migrationService = MigrationService(db, client);

    final hasData = await migrationService.hasLocalData();
    if (!hasData) {
      ref.read(settings.provider(localOnlySettingDef).notifier).set(false);
      ref
          .read(settings.provider(localDataFromOnlineUserIdSettingDef).notifier)
          .set('');
      Log.info(
        'Setting changed: ${localOnlySettingDef.key}=false, '
        '${localDataFromOnlineUserIdSettingDef.key}=(cleared)',
      );
      Log.info('Switched to online mode (no data to migrate)');
      await ref.read(dataSyncServiceProvider.notifier).syncNow();
      return;
    }

    if (!context.mounted) return;

    final migrationResult = await showResponsiveSheet<MigrationResult>(
      context: context,
      title: 'migration_title'.tr(),
      barrierDismissible: true,
      maxHeight: MediaQuery.of(context).size.height * 0.5,
      isScrollControlled: true,
      centerInFullViewport: false,
      child: MigrationProgressSheet(migrationService: migrationService),
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
        Log.info(
          'Setting changed: ${localOnlySettingDef.key}=false, '
          '${localDataFromOnlineUserIdSettingDef.key}=(cleared)',
        );
        Log.info('Switched to online mode after migration');
        await ref.read(dataSyncServiceProvider.notifier).syncNow();
        if (!context.mounted) return;
        context.showSuccess('migration_success'.tr());
      case MigrationResult.failed:
      case null:
        if (context.mounted) context.showError('migration_failed'.tr());
    }
  }
}
