import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:flutter_logging_service/flutter_logging_service.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_user_profile.dart';
import '../../../core/auth/predefined_avatars.dart';
import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/theme/accent_style.dart';
import '../../../core/utils/form_validators.dart';
import '../../groups/providers/groups_provider.dart';
import '../providers/settings_framework_providers.dart';

/// Bottom sheet to edit display name and avatar. Updates Supabase user_metadata.
Future<void> showEditProfileSheet(
  BuildContext context,
  WidgetRef ref,
  AuthUserProfile profile,
) async {
  await showResponsiveSheet<void>(
    context: context,
    title: 'edit_profile'.tr(),
    isScrollControlled: true,
    useSafeArea: true,
    centerInFullViewport: false,
    child: _EditProfileSheet(ref: ref, profile: profile),
  );
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.ref, required this.profile});
  final WidgetRef ref;
  final AuthUserProfile profile;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late TextEditingController _nameController;
  late String _selectedAvatarId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name ?? '');
    _selectedAvatarId = widget.profile.avatarId?.isNotEmpty == true
        ? widget.profile.avatarId!
        : defaultAvatarId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Repository requires a non-empty name; keep avatar sync working without one.
  String _nameForParticipantSync(String typedName) {
    if (typedName.isNotEmpty) return typedName;
    final existing = (widget.profile.name ?? '').trim();
    if (existing.isNotEmpty) return existing;
    final email = (widget.profile.email ?? '').trim();
    if (email.isNotEmpty) {
      final local = email.split('@').first.trim();
      if (local.isNotEmpty) return local;
    }
    final sub = widget.profile.sub.trim();
    if (sub.isNotEmpty) return sub;
    return 'User';
  }

  Future<void> _save() async {
    final newName = _nameController.text.trim();
    // Empty clears display name in auth; non-empty must fit participants.name.
    if (newName.isNotEmpty &&
        FormValidators.participantName(newName) != null) {
      setState(() => _error = 'field_too_long'.tr(
            namedArgs: {'max': '${FormValidators.participantNameMax}'},
          ));
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final authService = ref.read(authServiceProvider);
      await authService.updateProfile(
        name: newName.isEmpty ? null : newName,
        avatarId: _selectedAvatarId,
      );
      // Sync participant names/avatars across groups. Name is required by the
      // repository; fall back so avatar-only edits still propagate.
      final nameForParticipants = _nameForParticipantSync(newName);
      final userId = authService.currentUser?.id;
      if (userId != null) {
        try {
          await ref
              .read(participantRepositoryProvider)
              .updateProfileByUserId(
                userId,
                nameForParticipants,
                avatarId: _selectedAvatarId,
              );
        } catch (e, st) {
          Log.warning(
            'Failed to sync participant profile',
            error: e,
            stackTrace: st,
          );
        }
      }
      // Ensure settings UI refreshes even if auth stream is slow/missed.
      ref.invalidate(authUserProfileProvider);
      ref.invalidate(currentUserProvider);
      // Refresh participant streams so group People / Balance / expense detail
      // pick up the new avatar without waiting for the next poll tick.
      ref.invalidate(participantsByGroupProvider);
      ref.invalidate(activeParticipantsByGroupProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'profile_update_failed'.tr();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!LayoutBreakpoints.isTabletOrWider(context)) ...[
              Text(
                'profile_edit'.tr(),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 20,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            DecoratedBox(
              decoration: AccentSurfaces.flatPanel(colorScheme),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'auth_name'.tr(),
                        hintText: 'auth_name_hint'.tr(),
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: const OutlineInputBorder(),
                        counterText: '',
                        isDense: true,
                      ),
                      maxLength: FormValidators.participantNameMax,
                      textInputAction: TextInputAction.done,
                      enabled: !_saving,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'auth_avatar'.tr(),
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: predefinedAvatars.map((e) {
                        final selected = _selectedAvatarId == e.key;
                        return GestureDetector(
                          onTap: _saving
                              ? null
                              : () =>
                                  setState(() => _selectedAvatarId = e.key),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: selected
                                  ? colorScheme.primaryContainer
                                  : colorScheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? colorScheme.primary
                                    : colorScheme.outline
                                        .withValues(alpha: 0.3),
                                width: selected ? 2.5 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              e.value,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Focus(
              canRequestFocus: false,
              skipTraversal: true,
              descendantsAreFocusable: false,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : Text('done'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
