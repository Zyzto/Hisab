import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final styleIndex = ref.watch(experimentStyleIndexProvider);
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

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(barRadius),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(destinations.length, (index) {
            final destination = destinations[index];
            final isSelected = index == selectedIndex;
            final color = isSelected ? active : inactive;

            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onDestinationSelected(index);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 44,
                      minWidth: 44,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected
                                ? destination.selectedIcon
                                : destination.icon,
                            color: color,
                            size: iconSize,
                          ),
                          if (destination.label != null) ...[
                            const SizedBox(height: 4),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: theme.textTheme.labelSmall!.copyWith(
                                color: color,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              child: Text(destination.label!),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
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
