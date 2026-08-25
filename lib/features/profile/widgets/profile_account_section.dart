import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/predefined_avatars.dart';
import 'package:hisab_backend/hisab_backend.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/widgets/participant_avatar.dart';
import '../../../core/widgets/user_text.dart';
import '../../settings/account_mode_actions.dart';
import 'package:hisab/core/settings/providers/settings_framework_providers.dart';
import '../../settings/widgets/change_password_sheet.dart';
import '../../settings/widgets/edit_profile_sheet.dart';

/// Account header + actions for the profile page (moved from Settings).
class ProfileAccountSection extends ConsumerWidget {
  const ProfileAccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) return const SizedBox.shrink();

    final onlineAvailable = cloudAvailable;
    final localOnly = ref.watch(effectiveLocalOnlyProvider);

    // Warm avatar emoji glyphs while the profile is visible so the edit
    // sheet does not wait (or flash empty boxes) on first open.
    if (onlineAvailable && !localOnly) {
      unawaited(preloadPredefinedAvatarEmojis());
    }

    if (!onlineAvailable) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ProfileStatusBanner(
          tone: ProfileBannerTone.warning,
          title: Text('account'.tr()),
          message: Text('onboarding_online_unavailable'.tr()),
        ),
      );
    }

    if (localOnly) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ProfileStatusBanner(
          title: Text('local_only'.tr()),
          message: Text('account_local_mode_description'.tr()),
          action: FilledButton.icon(
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
      );
    }

    final profileAsync = ref.watch(authUserProfileProvider);
    final user = ref.watch(currentUserProvider);
    final syncStatus = ref.watch(syncStatusForDisplayProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ProfileStatusBanner(
              tone: ProfileBannerTone.error,
              title: Text('account'.tr()),
              message: Text('account_not_signed_in'.tr()),
              action: FilledButton(
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

        final provider = AccountModeActions.providerLabel(user);
        final canChangePassword = user?.provider == 'email';

        final displayName = profile.name ?? profile.email ?? profile.sub;
        final initials = AccountModeActions.initials(
          profile.name,
          profile.email,
        );
        final theme = Theme.of(context);

        return Column(
          children: [
            ProfileSettingsCard(
              leading: ParticipantAvatar(
                name: displayName,
                avatarId: profile.avatarId,
                initials: initials,
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                textStyle: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              title: UserText(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: profile.email != null
                  ? Text(
                      profile.email!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  : null,
              onTap: () => showEditProfileSheet(context, ref, profile),
              actions: [
                ProfileSettingsAction(
                  icon: Icons.edit_outlined,
                  tooltip: 'edit'.tr(),
                  onPressed: () => showEditProfileSheet(context, ref, profile),
                ),
                if (canChangePassword)
                  ProfileSettingsAction(
                    icon: Icons.lock_outline,
                    tooltip: 'change_password'.tr(),
                    onPressed: () => showChangePasswordSheet(context, ref),
                  ),
              ],
            ),
            _SyncTile(status: syncStatus, provider: provider),
          ],
        );
      },
      loading: () => const ProfilePlaceholder(
        kind: ProfilePlaceholderKind.loading,
        title: Text('…'),
      ),
      error: (_, _) => ProfilePlaceholder(
        kind: ProfilePlaceholderKind.error,
        icon: const Icon(Icons.error_outline),
        title: Text('account'.tr()),
        message: Text('account_not_signed_in'.tr()),
        action: FilledButton(
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
