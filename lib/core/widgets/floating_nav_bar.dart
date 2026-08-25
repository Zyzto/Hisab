import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safaeh/safaeh.dart';
import '../motion/app_motion.dart';
import '../platform/ui_perf.dart';
import '../theme/theme_providers.dart';

class FloatingNavBar extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<FloatingNavDestination> destinations;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? backgroundColor;

  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.activeColor,
    this.inactiveColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final styleIndex = ref.watch(effectiveExperimentStyleIndexProvider);
    final colorScheme = theme.colorScheme;
    final active = activeColor ?? colorScheme.primary;
    final inactive = inactiveColor ?? colorScheme.onSurfaceVariant;
    final background = backgroundColor ?? colorScheme.surfaceContainerHighest;

    // Per-experiment-style bar shape: 0/1/3/4 default; 2 Playful = more rounded; 5 Editorial = rectangular
    final barRadius = styleIndex == 2
        ? 28.0
        : styleIndex == 5
        ? 4.0
        : 24.0;
    final iconSize = styleIndex == 2 ? 28.0 : 24.0;

    // iOS web only: large blur shadows jank on WebKit / older GPUs (e.g. XR).
    final shadows = UiPerf.preferCheapShadows
        ? [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ]
        : [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ];
    final border = UiPerf.preferCheapShadows
        ? Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.7))
        : null;

    final tabAnimDuration = UiPerf.preferInstantShellTabs
        ? Duration.zero
        : AppMotion.shellTab;

    return SafaehFloatingNavBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        HapticFeedback.lightImpact();
        onDestinationSelected(index);
      },
      destinations: [
        for (final destination in destinations)
          SafaehSidenavDestination(
            label: destination.label ?? '',
            icon: destination.icon,
            selectedIcon: destination.selectedIcon,
          ),
      ],
      activeColor: active,
      inactiveColor: inactive,
      backgroundColor: background,
      radius: barRadius,
      iconSize: iconSize,
      shadows: shadows,
      border: border,
      motion: tabAnimDuration,
    );
  }
}

class FloatingNavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String? label;

  const FloatingNavDestination({
    required this.icon,
    required this.selectedIcon,
    this.label,
  });
}
