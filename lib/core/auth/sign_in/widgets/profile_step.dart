import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../theme/accent_style.dart';
import '../../../widgets/group_section_header.dart';
import '../../predefined_avatars.dart';

/// Second sign-up step: display name and avatar.
///
/// Split out from the credentials so a phone never has to show six inputs and
/// a 36-tile avatar grid at once. Nothing here is required — an empty name
/// lets the backend derive one from the email address.
class ProfileStep extends StatelessWidget {
  const ProfileStep({
    super.key,
    required this.nameController,
    required this.selectedAvatarId,
    required this.onAvatarSelected,
    required this.enabled,
    required this.onSubmit,
  });

  final TextEditingController nameController;
  final String selectedAvatarId;
  final ValueChanged<String> onAvatarSelected;
  final bool enabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'auth_name'.tr(),
            hintText: 'auth_name_hint'.tr(),
            prefixIcon: const Icon(Icons.badge_outlined),
            border: const OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          // This step replaces the form wholesale, so the field the user
          // arrived for should already be live.
          autofocus: true,
          enabled: enabled,
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: 20),
        GroupSectionHeader(label: 'auth_avatar'.tr()),
        const SizedBox(height: 10),
        // Thirty-seven tiles need a frame, or the grid reads as loose confetti
        // sitting on the sheet rather than one field among others.
        DecoratedBox(
          decoration: AccentSurfaces.flatPanel(cs),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final avatar in predefinedAvatars)
                  _AvatarTile(
                    emoji: avatar.value,
                    selected: selectedAvatarId == avatar.key,
                    onTap: enabled ? () => onAvatarSelected(avatar.key) : null,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
        shape: CircleBorder(
          side: BorderSide(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.3),
            width: selected ? 2.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          canRequestFocus: false,
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
        ),
      ),
    );
  }
}
