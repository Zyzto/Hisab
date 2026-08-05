import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import '../layout/layout_breakpoints.dart';
import '../navigation/route_paths.dart';
import '../theme/accent_style.dart';
import '../../features/settings/providers/settings_framework_providers.dart';
import 'participant_avatar.dart';
import 'user_text.dart';

/// Shell navigation body hosted inside a [Drawer] (temporary mid or permanent
/// desktop). Desktop layout is always full width with a fixed 72px icon column
/// so the shell can clip to icons-only without reflow.
class AppSidenav extends ConsumerWidget {
  const AppSidenav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.asDrawer = false,
    this.collapsed = false,
    this.onToggleCompact,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Temporary [Scaffold.drawer] mode (mid band) — full labels, no rail clip.
  final bool asDrawer;

  /// Desktop rail is clipped to compact width. Toggle affordance / tooltips only.
  final bool collapsed;

  /// Desktop expand/collapse; null hides the control (mid temporary drawer).
  final VoidCallback? onToggleCompact;

  static const _destinations =
      <({IconData icon, IconData selectedIcon, String labelKey})>[
        (
          icon: Icons.group_outlined,
          selectedIcon: Icons.group,
          labelKey: 'groups',
        ),
        (
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          labelKey: 'settings',
        ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final subtle = context.subtleAccents;
    final width = asDrawer
        ? math.min(
            LayoutBreakpoints.shellNavWidth,
            MediaQuery.sizeOf(context).width * 0.85,
          )
        : LayoutBreakpoints.shellNavWidth;

    final profile = ref.watch(authUserProfileProvider).asData?.value;
    final user = ref.watch(currentUserProvider);
    final signedIn = user != null;
    final displayName = profile?.name ??
        profile?.email ??
        user?.email ??
        (signedIn ? 'account'.tr() : 'sign_in'.tr());

    return Material(
      color: cs.surfaceContainerLow,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: width,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                asDrawer: asDrawer,
                collapsed: collapsed,
                onToggleCompact: asDrawer ? null : onToggleCompact,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: asDrawer ? 12 : 0),
                child: Column(
                  children: [
                    for (var i = 0; i < _destinations.length; i++) ...[
                      if (i > 0) const SizedBox(height: 6),
                      _SidenavDestTile(
                        asDrawer: asDrawer,
                        collapsed: collapsed,
                        label: _destinations[i].labelKey.tr(),
                        selected: selectedIndex == i,
                        icon: selectedIndex == i
                            ? _destinations[i].selectedIcon
                            : _destinations[i].icon,
                        subtle: subtle,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onDestinationSelected(i);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  asDrawer ? 12 : 0,
                  8,
                  asDrawer ? 12 : 0,
                  4,
                ),
                child: _UserBlock(
                  asDrawer: asDrawer,
                  collapsed: collapsed,
                  signedIn: signedIn,
                  displayName: displayName,
                  email: profile?.email ?? user?.email,
                  avatarId: profile?.avatarId,
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final rootScaffold = Scaffold.maybeOf(context);
                    if (rootScaffold?.isDrawerOpen ?? false) {
                      rootScaffold!.closeDrawer();
                      await Future<void>.delayed(
                        const Duration(milliseconds: 50),
                      );
                    }
                    if (!context.mounted) return;
                    // Profile owns account CTAs (sign-in / local→online).
                    context.push(RoutePaths.profile);
                  },
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: asDrawer
                      ? 16
                      : LayoutBreakpoints.shellNavWidthCompact,
                  end: 16,
                  top: 4,
                  bottom: 12,
                ),
                child: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox(height: 8);
                    return Text(
                      'v${snapshot.data!.version}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.35),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.asDrawer,
    required this.collapsed,
    this.onToggleCompact,
  });

  final bool asDrawer;
  final bool collapsed;
  final VoidCallback? onToggleCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Text(
      'app_name'.tr(),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    );

    if (asDrawer || onToggleCompact == null) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 12, 8),
        child: title,
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 8, bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: LayoutBreakpoints.shellNavWidthCompact,
            child: IconButton(
              key: ValueKey(
                collapsed ? 'shell_nav_expand' : 'shell_nav_collapse',
              ),
              tooltip: collapsed
                  ? 'shell_nav_expand'.tr()
                  : 'shell_nav_collapse'.tr(),
              onPressed: onToggleCompact,
              icon: Icon(
                // matchTextDirection mirrors chevron_left toward the rail edge in RTL.
                collapsed ? Icons.menu : Icons.chevron_left,
              ),
            ),
          ),
          Expanded(child: title),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _SidenavDestTile extends StatelessWidget {
  const _SidenavDestTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.asDrawer,
    required this.collapsed,
    required this.subtle,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool asDrawer;
  final bool collapsed;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fg = selected ? cs.primary : cs.onSurfaceVariant;

    final labelText = Text(
      label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall?.copyWith(
        color: selected ? cs.onSurface : cs.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );

    if (asDrawer) {
      return Material(
        color: selected
            ? AccentSurfaces.emphasizedFill(cs, subtle: subtle)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          canRequestFocus: false,
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AccentSurfaces.emphasizedBorder(cs, subtle: subtle)
                    : cs.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 24, color: fg),
                    const SizedBox(width: 14),
                    Expanded(child: labelText),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Permanent rail: selection chrome lives only in the 72px icon column with
    // inset padding so collapsed clip never lets the pill spill past the rail.
    const iconCol = LayoutBreakpoints.shellNavWidthCompact;
    const inset = 8.0;
    final iconTile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: inset, vertical: 2),
      child: Material(
        color: selected
            ? AccentSurfaces.emphasizedFill(cs, subtle: subtle)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          canRequestFocus: false,
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AccentSurfaces.emphasizedBorder(cs, subtle: subtle)
                    : cs.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: SizedBox(
              height: 48,
              width: iconCol - inset * 2,
              child: Center(child: Icon(icon, size: 24, color: fg)),
            ),
          ),
        ),
      ),
    );

    final row = Row(
      children: [
        SizedBox(width: iconCol, child: iconTile),
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: labelText,
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (collapsed) return Tooltip(message: label, child: row);
    return row;
  }
}

class _UserBlock extends StatelessWidget {
  const _UserBlock({
    required this.asDrawer,
    required this.collapsed,
    required this.signedIn,
    required this.displayName,
    required this.onTap,
    this.email,
    this.avatarId,
  });

  final bool asDrawer;
  final bool collapsed;
  final bool signedIn;
  final String displayName;
  final String? email;
  final String? avatarId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final avatar = ParticipantAvatar(
      name: displayName,
      avatarId: avatarId,
      radius: 20,
      backgroundColor: cs.primaryContainer,
      foregroundColor: cs.onPrimaryContainer,
    );

    final textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        UserText(
          displayName,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (signedIn && email != null && email != displayName)
          UserText(
            email!,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          )
        else if (!signedIn)
          Text(
            'sign_in'.tr(),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );

    if (asDrawer) {
      return Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  avatar,
                  const SizedBox(width: 14),
                  Expanded(child: textColumn),
                  Icon(
                    signedIn ? Icons.chevron_right : Icons.login,
                    size: 22,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    const iconCol = LayoutBreakpoints.shellNavWidthCompact;
    const inset = 8.0;
    final avatarTile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: inset, vertical: 4),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 56,
            width: iconCol - inset * 2,
            child: Center(child: avatar),
          ),
        ),
      ),
    );

    final row = Row(
      children: [
        SizedBox(width: iconCol, child: avatarTile),
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: textColumn,
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (collapsed) return Tooltip(message: displayName, child: row);
    return row;
  }
}
