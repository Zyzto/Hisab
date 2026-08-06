import 'package:flutter/material.dart';

import '../../../core/platform/ui_perf.dart';
import '../../../core/theme/theme_config.dart';
import '../../../core/widgets/wizard_step_enter.dart';
import 'onboarding_ambient.dart';
import 'onboarding_celestial.dart';

/// Alias for call sites that still import [OnboardingStepEnter] from this file.
typedef OnboardingStepEnter = WizardStepEnter;

/// Flattens a translucent theme fill onto the scaffold surface.
///
/// Onboarding paints over the live meadow, so a fill like
/// `primaryContainer.withValues(alpha: 0.35)` would let sky and grass show
/// through the card and wreck the contrast of the text sitting on it.
Color onboardingOpaqueFill(ColorScheme colorScheme, Color fill) {
  return Color.alphaBlend(fill, colorScheme.surface);
}

/// Soft glass panel for footnotes / privacy that still need a wash.
///
/// Titles sit bare on the meadow — see [onboardingSkyInk].
class OnboardingPlaque extends StatelessWidget {
  const OnboardingPlaque({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Compact variant for footnotes.
  const OnboardingPlaque.compact({super.key, required this.child})
    : padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      radius = 14;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dark = colorScheme.brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: dark ? 0.78 : 0.84),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(
            alpha: dark ? 0.22 : 0.28,
          ),
        ),
        boxShadow: UiPerf.preferCheapShadows
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.28 : 0.07),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: child,
    );
  }
}

/// Whether the meadow behind titles is the dark (night) wallpaper.
///
/// Matches [OnboardingSkyBackdrop]: night when the theme is dark.
bool onboardingSkyIsNight(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// Translucent ink for type painted straight onto the sky band.
///
/// Night → soft white. Day → deep green-black. Soft halo keeps either
/// readable when the sun/motes wash the sky.
Color onboardingSkyInkForBrightness(
  Brightness brightness, {
  double alpha = 0.94,
}) {
  final night = brightness == Brightness.dark;
  final base = night ? Colors.white : const Color(0xFF0E1A14);
  return base.withValues(alpha: alpha);
}

Color onboardingSkyInk(BuildContext context, {double alpha = 0.94}) =>
    onboardingSkyInkForBrightness(Theme.of(context).brightness, alpha: alpha);

/// Wide, heavily faded halo opposite the ink — a soft wash, not a hard rim.
List<Shadow> onboardingSkyTextShadowsForBrightness(Brightness brightness) {
  final night = brightness == Brightness.dark;
  final wash = night ? Colors.black : Colors.white;
  return [
    // Tight core: barely there, just keeps letter edges from vanishing.
    Shadow(
      color: wash.withValues(alpha: night ? 0.22 : 0.28),
      blurRadius: 18,
      offset: const Offset(0, 1),
    ),
    // Mid bloom.
    Shadow(color: wash.withValues(alpha: night ? 0.12 : 0.16), blurRadius: 40),
    // Far, very faded glow.
    Shadow(color: wash.withValues(alpha: night ? 0.06 : 0.08), blurRadius: 72),
  ];
}

List<Shadow> onboardingSkyTextShadows(BuildContext context) =>
    onboardingSkyTextShadowsForBrightness(Theme.of(context).brightness);

/// Shared title + optional supporting line for every onboarding step.
///
/// No plaque — sits on the sky with adaptive translucent ink.
class OnboardingTitleBlock extends StatelessWidget {
  const OnboardingTitleBlock({super.key, required this.title, this.subtitle});

  final String title;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = onboardingSkyInk(context);
    final muted = onboardingSkyInk(context, alpha: 0.78);
    final shadows = onboardingSkyTextShadows(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            height: 1.15,
            color: ink,
            shadows: shadows,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: ThemeConfig.spacingS),
          DefaultTextStyle(
            style: (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
              color: muted,
              height: 1.45,
              shadows: shadows,
            ),
            child: subtitle!,
          ),
        ],
      ],
    );
  }
}

/// Soft section label painted on the meadow (no card).
class OnboardingSectionLabel extends StatelessWidget {
  const OnboardingSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = onboardingSkyInk(context);
    final shadows = onboardingSkyTextShadows(context);
    final bar = onboardingSkyIsNight(context)
        ? Colors.white.withValues(alpha: 0.85)
        : Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: bar,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [BoxShadow(color: shadows.first.color, blurRadius: 8)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              color: ink,
              shadows: shadows,
            ),
          ),
        ),
      ],
    );
  }
}

/// Soft wash above the footer chrome where step content peeks through.
///
/// Painted by the shell footer and marked non-hit-testable so the list can
/// still scroll underneath.
const double kOnboardingFooterFadeExtension = 96;

/// Footer chrome height (dots + nav + hint), excluding safe inset and the
/// fade extension above it.
const double kOnboardingFooterChromeHeight = 152;

/// Bottom inset so scroll content can clear the interactive footer chrome
/// (safe area included). Content is intentionally allowed under the soft
/// fade extension so the next rows peek through.
double onboardingFooterContentInset(BuildContext context) {
  return kOnboardingFooterChromeHeight + MediaQuery.paddingOf(context).bottom;
}

/// Onboarding body with title (+ optional pinned header) fixed, content
/// scrolling only when it overflows.
///
/// Copy starts just below the sun/moon disc (see
/// [OnboardingCelestial.contentStartY]). Title and [pinnedBelowTitle] stay
/// put; only [content] scrolls. Extra bottom padding clears the overlaid
/// footer chrome.
///
/// [contentAlignment] defaults to center; use [Alignment.topCenter] when
/// short content should stay at the top of the scroll band.
Widget onboardingPageBodyWithFixedTitle(
  BuildContext context, {
  required Widget title,
  required Widget content,
  Widget? pinnedBelowTitle,
  AlignmentGeometry contentAlignment = Alignment.center,
}) {
  const padding = ThemeConfig.spacingM;
  const titleContentGap = ThemeConfig.spacingL;
  final footerInset = onboardingFooterContentInset(context);
  final media = MediaQuery.of(context);
  // Celestial is painted in full-screen coords; this body already sits under
  // the top safe inset, so subtract that (+ our top padding) from the spacer.
  final belowCelestial =
      (OnboardingCelestial.contentStartY(media.size) -
              media.padding.top -
              padding +
              ThemeConfig.spacingS)
          .clamp(0.0, media.size.height);
  return Padding(
    padding: const EdgeInsets.fromLTRB(padding, padding, padding, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: belowCelestial),
        title,
        if (pinnedBelowTitle != null) ...[
          const SizedBox(height: titleContentGap),
          pinnedBelowTitle,
        ],
        const SizedBox(height: titleContentGap),
        Expanded(
          child: LayoutBuilder(
            builder: (context, scrollConstraints) {
              final minBody = scrollConstraints.maxHeight.isFinite
                  ? (scrollConstraints.maxHeight - footerInset).clamp(
                      0.0,
                      scrollConstraints.maxHeight,
                    )
                  : 0.0;
              return SingleChildScrollView(
                padding: EdgeInsets.only(bottom: footerInset + padding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minBody),
                  child: Align(alignment: contentAlignment, child: content),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
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
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: usePrimaryContainer
            ? onboardingOpaqueFill(
                colorScheme,
                colorScheme.primaryContainer.withValues(alpha: 0.55),
              )
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: OnboardingIconPulse(
        phase: icon.codePoint % 17 / 17,
        child: Icon(
          icon,
          size: 22,
          color: usePrimaryContainer
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Soft list row for onboarding preferences / permissions.
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

  static const double _radius = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          leading,
          const SizedBox(width: ThemeConfig.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 4),
                DefaultTextStyle(
                  style: (theme.textTheme.bodySmall ?? const TextStyle())
                      .copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                  child: subtitle,
                ),
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.38),
        ),
      ),
      child: content,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: ThemeConfig.spacingS),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(_radius),
        clipBehavior: Clip.antiAlias,
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
