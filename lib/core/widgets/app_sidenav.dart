import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:safaeh/safaeh.dart';

import '../auth/auth_providers.dart';
import '../layout/layout_breakpoints.dart';
import '../motion/app_motion.dart';
import '../navigation/route_paths.dart';
import '../platform/ui_perf.dart';
import '../settings/providers/settings_framework_providers.dart';
import 'participant_avatar.dart';
import 'user_text.dart';

/// Shell navigation: the same labeled tiles in a temporary [Drawer] (mid) or a
/// clipping rail (desktop). Collapse hides labels; compact tiles center the
/// icon (Safaeh 0.2) so a profile plate still fits.
class AppSidenav extends ConsumerWidget {
  const AppSidenav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onProfileSelected,
    this.asDrawer = false,
    this.collapsed = false,
    this.onToggleCompact,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Profile is a push (back stack), not a shell tab.
  final VoidCallback onProfileSelected;

  /// Temporary [Scaffold.drawer] mode (mid band) — full labels, no collapse.
  final bool asDrawer;

  /// Desktop rail is clipped to compact width. Toggle affordance / tooltips only.
  final bool collapsed;

  /// Desktop expand/collapse; null hides the control (mid temporary drawer).
  final VoidCallback? onToggleCompact;

  static const _destinations =
      <({IconData icon, IconData selectedIcon, String labelKey, String key})>[
        (
          icon: Icons.group_outlined,
          selectedIcon: Icons.group,
          labelKey: 'groups',
          key: 'shell_nav_groups',
        ),
        (
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          labelKey: 'settings',
          key: 'shell_nav_settings',
        ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    context.locale;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final chrome = (fill: cs.surfaceContainerLow, onFill: cs.onSurface);

    final profile = ref.watch(authUserProfileProvider).asData?.value;
    final user = ref.watch(currentUserProvider);
    final signedIn = user != null;
    final displayName =
        profile?.name ??
        profile?.email ??
        user?.email ??
        (signedIn ? 'account'.tr() : 'sign_in'.tr());
    final onProfile =
        GoRouter.maybeOf(
          context,
        )?.routerDelegate.currentConfiguration.uri.path ==
        RoutePaths.profile;

    return SafaehSidenav(
      title: 'app_name'.tr(),
      asDrawer: asDrawer,
      collapsed: collapsed,
      onToggleCompact: onToggleCompact,
      expandTooltip: 'shell_nav_expand'.tr(),
      collapseTooltip: 'shell_nav_collapse'.tr(),
      compactWidth: LayoutBreakpoints.shellNavWidthCompact,
      expandedWidth: LayoutBreakpoints.shellNavWidth,
      duration: UiPerf.preferReducedChromeMotion
          ? Duration.zero
          : AppMotion.shellNav,
      railKey: const ValueKey('shell_nav_rail'),
      expandKey: const ValueKey('shell_nav_expand'),
      collapseKey: const ValueKey('shell_nav_collapse'),
      selectedIndex: selectedIndex,
      onDestinationSelected: (i) {
        HapticFeedback.lightImpact();
        onDestinationSelected(i);
      },
      destinations: [
        for (final dest in _destinations)
          SafaehSidenavDestination(
            label: dest.labelKey.tr(),
            icon: dest.icon,
            selectedIcon: dest.selectedIcon,
            tileKey: ValueKey(dest.key),
          ),
      ],
      profile: SafaehSidenavProfile(
        tileKey: const ValueKey('shell_nav_profile'),
        label: displayName,
        subtitle:
            signedIn && profile?.email != null && profile?.email != displayName
            ? profile!.email
            : (!signedIn ? 'sign_in'.tr() : null),
        selected: onProfile,
        leading: ParticipantAvatar(
          name: displayName,
          avatarId: profile?.avatarId,
          radius: 12,
          backgroundColor: onProfile
              ? chrome.fill.withValues(alpha: 0.18)
              : chrome.onFill.withValues(alpha: 0.18),
          foregroundColor: onProfile ? chrome.fill : chrome.onFill,
        ),
        trailing: Icon(
          signedIn ? Icons.chevron_right : Icons.login,
          size: 22,
          color: onProfile ? chrome.fill : chrome.onFill,
        ),
        labelBuilder: (data, style) => UserText(
          data,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
        onTap: onProfileSelected,
      ),
      footer: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox(height: 8);
          return Text(
            'v${snapshot.data!.version}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: chrome.onFill.withValues(alpha: 0.35),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          );
        },
      ),
    );
  }
}
