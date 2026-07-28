import 'package:flutter/material.dart';

import '../auth/predefined_avatars.dart';

/// Circle avatar for a participant/profile: emoji from [avatarId], else initials.
class ParticipantAvatar extends StatelessWidget {
  final String name;
  final String? avatarId;

  /// When set, used instead of the first letter of [name] (e.g. two-letter initials).
  final String? initials;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final TextStyle? textStyle;

  const ParticipantAvatar({
    super.key,
    required this.name,
    this.avatarId,
    this.initials,
    this.radius = 22,
    this.backgroundColor,
    this.foregroundColor,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final emoji = avatarEmoji(avatarId);
    final fallback = initials?.trim().isNotEmpty == true
        ? initials!.trim()
        : (name.trim().isNotEmpty
              ? name.trim().characters.first.toUpperCase()
              : '?');
    final bg =
        backgroundColor ??
        colorScheme.secondaryContainer.withValues(alpha: 0.7);
    final fg = foregroundColor ?? colorScheme.onSecondaryContainer;

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: emoji != null
          ? Text(emoji, style: TextStyle(fontSize: radius * 1.05))
          : Text(
              fallback,
              style: (textStyle ?? theme.textTheme.titleMedium)?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
