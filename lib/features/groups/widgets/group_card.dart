import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../domain/domain.dart';
import '../utils/group_icon_utils.dart';

class GroupCard extends StatelessWidget {
  final Group group;
  final VoidCallback? onTap;

  /// When non-null, show creation date on the left (e.g. short date string).
  final String? createdDateLabel;

  /// When true, show pinned styling (e.g. accent). When [onPinToggle] is non-null, show pin icon.
  final bool isPinned;

  /// When non-null, show a trailing pin icon to toggle pin state.
  final VoidCallback? onPinToggle;

  /// When non-null, long-press selects the item (e.g. for app bar context menu). Pin icon is hidden.
  final VoidCallback? onLongPress;

  /// When true, card is in selection mode and highlighted.
  final bool isSelected;

  const GroupCard({
    super.key,
    required this.group,
    this.onTap,
    this.createdDateLabel,
    this.isPinned = false,
    this.onPinToggle,
    this.onLongPress,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupColor =
        group.color != null ? Color(group.color!) : theme.colorScheme.primary;
    final iconData = groupIconFromKey(group.icon);

    return Semantics(
      label: group.name,
      hint: (group.isPersonal ? 'open_list' : 'open_group').tr(),
      button: true,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                )
              : isPinned
                  ? BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      width: 1,
                    )
                  : BorderSide.none,
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap?.call();
          },
          onLongPress: onLongPress != null
              ? () {
                  HapticFeedback.mediumImpact();
                  onLongPress!();
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (createdDateLabel != null) ...[
                  SizedBox(
                    width: 44,
                    child: Text(
                      createdDateLabel!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                CircleAvatar(
                  radius: 22,
                  backgroundColor: groupColor,
                  child: iconData != null
                      ? Icon(iconData, color: Colors.white, size: 22)
                      : Text(
                          group.name.isNotEmpty
                              ? group.name[0].toUpperCase()
                              : '?',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        group.currencyCode,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onPinToggle != null)
                  IconButton(
                    icon: Icon(
                      isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: isPinned
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onPinToggle!();
                    },
                    tooltip: isPinned ? 'unpin'.tr() : 'pin'.tr(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
