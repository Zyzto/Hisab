import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_config.dart';
import '../../../core/theme/theme_providers.dart';
import '../../../domain/domain.dart';
import '../utils/group_icon_utils.dart';

class GroupCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final styleIndex = ref.watch(experimentStyleIndexProvider);
    final groupColor =
        group.color != null ? Color(group.color!) : theme.colorScheme.primary;
    final iconData = groupIconFromKey(group.icon);

    final leadingWidget = _buildLeadingForStyle(
      context: context,
      styleIndex: styleIndex,
      theme: theme,
      groupColor: groupColor,
      iconData: iconData,
      groupName: group.name,
    );

    return Semantics(
      label: group.name,
      hint: (group.isPersonal ? 'open_list' : 'open_group').tr(),
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
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
                    : BorderSide(
                        color: theme.colorScheme.outlineVariant,
                        width: 1,
                      ),
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
            borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
            child: _buildListContent(theme: theme, leadingWidget: leadingWidget),
          ),
        ),
      ),
    );
  }

  Widget _buildListContent({
    required ThemeData theme,
    required Widget leadingWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
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
          leadingWidget,
          const SizedBox(width: 14),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final hasBoundedHeight = constraints.maxHeight.isFinite;
                if (hasBoundedHeight) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            group.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: (theme.textTheme.titleMedium?.fontSize ?? 16) * (18 / 16),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: Text(
                            group.currencyCode,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: (theme.textTheme.titleMedium?.fontSize ?? 16) * (18 / 16),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.currencyCode,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
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
    );
  }

  /// Per-experiment-style leading widget: icon or avatar.
  static Widget _buildLeadingForStyle({
    required BuildContext context,
    required int styleIndex,
    required ThemeData theme,
    required Color groupColor,
    required IconData? iconData,
    required String groupName,
  }) {
    final fgOnGroup = ThemeConfig.foregroundOnBackground(groupColor);
    final defaultAvatar = CircleAvatar(
      radius: 22,
      backgroundColor: groupColor,
      child: iconData != null
          ? Icon(iconData, color: fgOnGroup, size: 22)
          : Text(
              groupName.isNotEmpty ? groupName[0].toUpperCase() : '?',
              style: theme.textTheme.titleMedium?.copyWith(
                color: fgOnGroup,
                fontWeight: FontWeight.w600,
              ),
            ),
    );

    switch (styleIndex) {
      case 0:
        return defaultAvatar;
      case 1:
        // Finance Professional: filled icon in rounded square container
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: groupColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: iconData != null
              ? Icon(iconData, color: fgOnGroup, size: 22)
              : Center(
                  child: Text(
                    groupName.isNotEmpty ? groupName[0].toUpperCase() : '?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: fgOnGroup,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        );
      case 2:
        // Playful Bubble: large two-tone icon, no container; initials match with large colored letter
        return iconData != null
            ? Icon(iconData, color: groupColor, size: 28)
            : Text(
                groupName.isNotEmpty ? groupName[0].toUpperCase() : '?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: groupColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              );
      case 3:
        // Elevated Surface: circle avatar (pastel-ish from theme)
        return defaultAvatar;
      case 4:
        // Tech Utility: outlined icon, no container; initials match with onSurface text, no circle
        return iconData != null
            ? Icon(
                iconData,
                color: theme.colorScheme.onSurface,
                size: 22,
              )
            : Text(
                groupName.isNotEmpty ? groupName[0].toUpperCase() : '?',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 22,
                ),
              );
      case 5:
        // Editorial List: very large icon (48–56px)
        return iconData != null
            ? Icon(iconData, color: groupColor, size: 48)
            : SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Text(
                    groupName.isNotEmpty ? groupName[0].toUpperCase() : '?',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: groupColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
      default:
        return defaultAvatar;
    }
  }
}
