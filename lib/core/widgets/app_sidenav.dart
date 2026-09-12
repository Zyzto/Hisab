import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../layout/layout_breakpoints.dart';

/// Local-only shell navigation.
class AppSidenav extends StatelessWidget {
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
  final bool asDrawer;
  final bool collapsed;
  final VoidCallback? onToggleCompact;

  static const _items = [
    (icon: Icons.group_outlined, selected: Icons.group, label: 'groups'),
    (
      icon: Icons.settings_outlined,
      selected: Icons.settings,
      label: 'settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = collapsed
        ? LayoutBreakpoints.shellNavWidthCompact
        : LayoutBreakpoints.shellNavWidth;
    return Material(
      key: asDrawer ? null : const ValueKey('shell_nav_rail'),
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        child: SizedBox(
          width: asDrawer ? LayoutBreakpoints.shellNavWidth : width,
          child: Column(
            children: [
              const SizedBox(height: 20),
              if (!collapsed || asDrawer)
                Text(
                  'app_name'.tr(),
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                )
              else
                const Icon(Icons.account_balance_wallet_outlined),
              const SizedBox(height: 20),
              for (var index = 0; index < _items.length; index++)
                if (collapsed && !asDrawer)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: IconButton(
                      key: ValueKey(
                        index == 0 ? 'shell_nav_groups' : 'shell_nav_settings',
                      ),
                      tooltip: _items[index].label.tr(),
                      onPressed: () => onDestinationSelected(index),
                      icon: Icon(
                        selectedIndex == index
                            ? _items[index].selected
                            : _items[index].icon,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ListTile(
                      key: ValueKey(
                        index == 0 ? 'shell_nav_groups' : 'shell_nav_settings',
                      ),
                      dense: true,
                      selected: selectedIndex == index,
                      leading: Icon(
                        selectedIndex == index
                            ? _items[index].selected
                            : _items[index].icon,
                      ),
                      title: Text(_items[index].label.tr()),
                      onTap: () => onDestinationSelected(index),
                    ),
                  ),
              const Spacer(),
              if (onToggleCompact != null && !asDrawer)
                IconButton(
                  key: ValueKey(
                    collapsed ? 'shell_nav_expand' : 'shell_nav_collapse',
                  ),
                  tooltip: collapsed
                      ? 'shell_nav_expand'.tr()
                      : 'shell_nav_collapse'.tr(),
                  onPressed: onToggleCompact,
                  icon: Icon(
                    collapsed ? Icons.chevron_right : Icons.chevron_left,
                  ),
                ),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    snapshot.hasData ? 'v${snapshot.data!.version}' : '',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
