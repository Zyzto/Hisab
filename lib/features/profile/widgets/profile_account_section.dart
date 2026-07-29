import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/widgets/participant_avatar.dart';
import '../../settings/account_mode_actions.dart';
import '../../settings/providers/settings_framework_providers.dart';
import '../../settings/widgets/change_password_sheet.dart';
import '../../settings/widgets/edit_profile_sheet.dart';

/// Account header + actions for the profile page (moved from Settings).
class ProfileAccountSection extends ConsumerWidget {
  const ProfileAccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return const SizedBox.shrink();

    final onlineAvailable = supabaseConfigAvailable;
    final localOnly = ref.watch(effectiveLocalOnlyProvider);

    if (!onlineAvailable) {
      return ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.cloud_off,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text('account'.tr()),
        subtitle: Text('onboarding_online_unavailable'.tr()),
      );
    }

    if (localOnly) {
      return Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.smartphone,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
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
              onPressed: () => AccountModeActions.handleLocalOnlyChanged(
                context,
                ref,
                settings,
                false,
              ),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text('switch_to_online'.tr()),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      );
    }

    final profileAsync = ref.watch(authUserProfileProvider);
    final user = ref.watch(currentUserProvider);
    final syncStatus = ref.watch(syncStatusForDisplayProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return ListTile(
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
              onPressed: () => AccountModeActions.handleLocalOnlyChanged(
                context,
                ref,
                settings,
                false,
              ),
              child: Text('sign_in'.tr()),
            ),
          );
        }

        final provider = AccountModeActions.providerLabel(user);
        final displayName = profile.name ?? profile.email ?? profile.sub;
        final initials = AccountModeActions.initials(
          profile.name,
          profile.email,
        );

        return Column(
          children: [
            ListTile(
              leading: ParticipantAvatar(
                name: displayName,
                avatarId: profile.avatarId,
                initials: initials,
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                textStyle: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              title: Text(
                displayName,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: profile.email != null ? Text(profile.email!) : null,
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => showEditProfileSheet(context, ref, profile),
            ),
            _SyncTile(status: syncStatus, provider: provider),
            if (user != null &&
                (user.appMetadata['provider'] as String?) == 'email')
              ActionSettingsTile(
                leading: const Icon(Icons.lock_outline),
                title: Text('change_password'.tr()),
                onTap: () => showChangePasswordSheet(context, ref),
              ),
            ActionSettingsTile(
              leading: const Icon(Icons.logout),
              title: Text('sign_out'.tr()),
              onTap: () =>
                  AccountModeActions.handleSignOut(context, ref, settings),
            ),
          ],
        );
      },
      loading: () => ListTile(
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
      error: (_, _) => ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.errorContainer,
          child: Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
        ),
        title: Text('account'.tr()),
        subtitle: Text('account_not_signed_in'.tr()),
        trailing: FilledButton(
          onPressed: () => AccountModeActions.handleLocalOnlyChanged(
            context,
            ref,
            settings,
            false,
          ),
          child: Text('sign_in'.tr()),
        ),
      ),
    );
  }
}

class _SyncTile extends StatelessWidget {
  const _SyncTile({required this.status, required this.provider});

  final SyncStatus status;
  final String provider;

  @override
  Widget build(BuildContext context) {
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
}
