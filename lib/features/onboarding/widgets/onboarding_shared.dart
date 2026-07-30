import 'package:flutter/material.dart';

import '../../../core/motion/app_motion.dart';
import '../../../core/platform/ui_perf.dart';
import '../../../core/theme/accent_style.dart';
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
                  child: Align(
                    alignment: AlignmentDirectional.bottomStart,
                    child: title,
                  ),
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

/// One-shot fade (+ optional slide-up) when a step body first mounts.
///
/// On iOS web (`UiPerf.preferFadeOnlyPageTransitions`), uses fade only.
class OnboardingStepEnter extends StatefulWidget {
  const OnboardingStepEnter({
    super.key,
    required this.child,
    this.slidePx = 20,
  });

  final Widget child;
  final double slidePx;

  @override
  State<OnboardingStepEnter> createState() => _OnboardingStepEnterState();
}

class _OnboardingStepEnterState extends State<OnboardingStepEnter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _t;

  @override
  void initState() {
    super.initState();
    // iOS web: skip enter motion entirely (Opacity + slide is expensive).
    if (UiPerf.preferFadeOnlyPageTransitions) {
      _controller = AnimationController(vsync: this, value: 1);
      _t = CurvedAnimation(parent: _controller, curve: AppMotion.enterCurve);
      return;
    }
    _controller = AnimationController(vsync: this, duration: AppMotion.page);
    _t = CurvedAnimation(parent: _controller, curve: AppMotion.enterCurve);
    _controller.forward();
  }

  @override
  void dispose() {
    _t.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (UiPerf.preferFadeOnlyPageTransitions || _controller.isCompleted) {
      return widget.child;
    }
    final fadeOnly = UiPerf.preferFadeOnlyPageTransitions;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        final v = _t.value;
        Widget result = child!;
        if (!fadeOnly) {
          result = Transform.translate(
            offset: Offset(0, (1 - v) * widget.slidePx),
            child: result,
          );
        }
        return Opacity(opacity: v, child: result);
      },
      child: widget.child,
    );
  }
}

/// Icon container used in onboarding list cards.
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
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: usePrimaryContainer
            ? colorScheme.primaryContainer.withValues(alpha: 0.55)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(ThemeConfig.radiusM),
      ),
      child: Icon(
        icon,
        size: 22,
        color: usePrimaryContainer
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Flat-panel list row for onboarding preferences / permissions.
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

  static const double _radius = 14;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          if (trailing != null) ...[
            const SizedBox(width: ThemeConfig.spacingXS),
            // flex:0 + loose: intrinsic width, but capped so AR/large font can't overflow.
            Flexible(
              flex: 0,
              fit: FlexFit.loose,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: trailing!,
              ),
            ),
          ],
        ],
      ),
    );

    final panel = Ink(
      decoration: AccentSurfaces.flatPanel(colorScheme, radius: _radius),
      child: content,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: ThemeConfig.spacingS),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(_radius),
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(_radius),
                child: panel,
              )
            : panel,
      ),
    );
  }
}
