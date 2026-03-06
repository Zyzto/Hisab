import 'package:flutter/material.dart';

import '../../../core/theme/theme_config.dart';

/// Shared scroll + padding wrapper for all onboarding page bodies.
/// Keeps title at top and content vertically balanced in the viewport.
/// Horizontal sizing is handled by the parent onboarding shell via
/// `ConstrainedContent` so onboarding matches main-page sizing.
Widget onboardingPageBody(BuildContext context, Widget child) {
  const padding = ThemeConfig.spacingM;
  return LayoutBuilder(
    builder: (context, constraints) {
      final minHeight = constraints.maxHeight - 2 * padding;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(padding),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Center(child: child),
        ),
      );
    },
  );
}

/// For pages 2, 3, 4: screen in three thirds — top third ends at title/desc,
/// bottom two thirds are the content area (content can use both, centered when short).
/// [contentAlignment] defaults to center; use [Alignment.topCenter] so content stays
/// at top (e.g. Connect page: toggle remains in place when info/warning boxes show).
Widget onboardingPageBodyWithFixedTitle(
  BuildContext context, {
  required Widget title,
  required Widget content,
  AlignmentGeometry contentAlignment = Alignment.center,
}) {
  const padding = ThemeConfig.spacingM;
  return LayoutBuilder(
    builder: (context, constraints) {
      const titleContentGap = ThemeConfig.spacingXL;
      final viewportHeight = constraints.maxHeight - 2 * padding;
      final topThirdHeight = viewportHeight / 3;
      final contentAreaHeight = viewportHeight * 2 / 3 - titleContentGap;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(padding),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: viewportHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: topThirdHeight,
                child: Center(
                  child: Align(alignment: Alignment.bottomLeft, child: title),
                ),
              ),
              const SizedBox(height: titleContentGap),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: contentAreaHeight),
                child: Align(alignment: contentAlignment, child: content),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Icon container used in onboarding list cards (pages 2 and 3).
class OnboardingListCardIcon extends StatelessWidget {
  const OnboardingListCardIcon({
    super.key,
    required this.icon,
    this.usePrimaryContainer = true,
  });

  final IconData icon;
  final bool usePrimaryContainer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(ThemeConfig.spacingS),
      decoration: BoxDecoration(
        color: usePrimaryContainer
            ? colorScheme.primaryContainer.withValues(alpha: 0.5)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(ThemeConfig.radiusM),
      ),
      child: Icon(
        icon,
        size: 24,
        color: usePrimaryContainer
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Shared list row style for onboarding pages 2 and 3: Card with icon container,
/// title, subtitle, and optional trailing. Uses ThemeConfig for consistency.
class OnboardingListCard extends StatelessWidget {
  const OnboardingListCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final Widget subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.all(ThemeConfig.spacingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          leading,
          const SizedBox(width: ThemeConfig.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: ThemeConfig.spacingXS),
                subtitle,
              ],
            ),
          ),
          ...([trailing].whereType<Widget>()),
        ],
      ),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: ThemeConfig.spacingS),
      elevation: ThemeConfig.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeConfig.cardBorderRadius),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(ThemeConfig.cardBorderRadius),
              child: content,
            )
          : content,
    );
  }
}
