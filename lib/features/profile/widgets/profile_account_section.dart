import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_user_profile.dart';
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
      return ListTile(
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
        final canChangePassword = user?.provider == 'email';

        return Column(
          children: [
            _AccountProfileTile(
              profile: profile,
              canChangePassword: canChangePassword,
              onEdit: () => showEditProfileSheet(context, ref, profile),
              onChangePassword: () => showChangePasswordSheet(context, ref),
            ),
            _SyncTile(status: syncStatus, provider: provider),
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

/// Account row with flush trailing actions (same pattern as profile expenses).
class _AccountProfileTile extends StatelessWidget {
  const _AccountProfileTile({
    required this.profile,
    required this.canChangePassword,
    required this.onEdit,
    required this.onChangePassword,
  });

  final AuthUserProfile profile;
  final bool canChangePassword;
  final VoidCallback onEdit;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final displayName = profile.name ?? profile.email ?? profile.sub;
    final initials = AccountModeActions.initials(profile.name, profile.email);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onEdit,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        12,
                        12,
                        10,
                        12,
                      ),
                      child: Row(
                        children: [
                          ParticipantAvatar(
                            name: displayName,
                            avatarId: profile.avatarId,
                            initials: initials,
                            backgroundColor: cs.primaryContainer,
                            foregroundColor: cs.onPrimaryContainer,
                            textStyle: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                UserText(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (profile.email != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    profile.email!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _AccountActionButton(
                  tooltip: 'edit'.tr(),
                  icon: Icons.edit_outlined,
                  colorScheme: cs,
                  onPressed: onEdit,
                ),
                if (canChangePassword)
                  _AccountActionButton(
                    tooltip: 'change_password'.tr(),
                    icon: Icons.lock_outline,
                    colorScheme: cs,
                    onPressed: onChangePassword,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountActionButton extends StatelessWidget {
  const _AccountActionButton({
    required this.tooltip,
    required this.icon,
    required this.colorScheme,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final ColorScheme colorScheme;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            child: Center(
              child: Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
            ),
          ),
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
