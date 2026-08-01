import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';

import '../../../core/motion/app_motion.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/platform/ui_perf.dart';
import '../../../core/theme/accent_style.dart';
import '../../../core/theme/theme_config.dart';
import '../../settings/settings_definitions.dart';
import 'onboarding_shared.dart';

class OnboardingConnectPage extends ConsumerWidget {
  const OnboardingConnectPage({
    super.key,
    required this.settings,
    required this.onlineAvailable,
  });

  final SettingsProviders settings;
  final bool onlineAvailable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLocalOnly = ref.watch(settings.provider(localOnlySettingDef));
    final colorScheme = Theme.of(context).colorScheme;
    final subtle = context.subtleAccents;
    // When cloud isn't configured, only offline is available — don't show online copy.
    final modeDesc = !onlineAvailable || isLocalOnly
        ? 'onboarding_offline_desc'.tr()
        : 'onboarding_online_desc'.tr();

    return onboardingPageBodyWithFixedTitle(
      context,
      title: OnboardingStepEnter(
        slidePx: 12,
        child: OnboardingTitleBlock(
          title: 'onboarding_connect'.tr(),
          subtitle: _ModeDescSwitcher(modeDesc: modeDesc),
        ),
      ),
      contentAlignment: Alignment.topCenter,
      content: OnboardingStepEnter(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (onlineAvailable) ...[
              _ModeTile(
                selected: isLocalOnly,
                icon: Icons.storage_outlined,
                title: 'onboarding_offline'.tr(),
                subtitle: 'onboarding_offline_desc'.tr(),
                onTap: () {
                  if (isLocalOnly) return;
                  ref
                      .read(settings.provider(localOnlySettingDef).notifier)
                      .set(true);
                  Log.info(
                    'Setting changed: ${localOnlySettingDef.key}=true',
                  );
                },
              ),
              _ModeTile(
                selected: !isLocalOnly,
                icon: Icons.cloud_outlined,
                title: 'onboarding_online'.tr(),
                subtitle: 'onboarding_online_desc'.tr(),
                onTap: () {
                  if (!isLocalOnly) return;
                  ref
                      .read(settings.provider(localOnlySettingDef).notifier)
                      .set(false);
                  Log.info(
                    'Setting changed: ${localOnlySettingDef.key}=false',
                  );
                },
              ),
              _OnlineDetailsReveal(
                visible: !isLocalOnly,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: ThemeConfig.spacingS),
                    _InfoPanel(
                      icon: Icons.info_outline_rounded,
                      message: 'onboarding_online_requires_sign_in'.tr(),
                      fill: onboardingOpaqueFill(
                        colorScheme,
                        AccentSurfaces.emphasizedFill(
                          colorScheme,
                          subtle: subtle,
                        ),
                      ),
                      border: AccentSurfaces.emphasizedBorder(
                        colorScheme,
                        subtle: subtle,
                      ),
                      iconColor: colorScheme.primary,
                      textColor: colorScheme.onSurface,
                    ),
                    const SizedBox(height: ThemeConfig.spacingS),
                    _InfoPanel(
                      icon: Icons.warning_amber_rounded,
                      message: 'onboarding_online_disclaimer'.tr(),
                      fill: onboardingOpaqueFill(
                        colorScheme,
                        colorScheme.errorContainer.withValues(alpha: 0.45),
                      ),
                      border: colorScheme.error.withValues(alpha: 0.22),
                      iconColor: colorScheme.onErrorContainer,
                      textColor: colorScheme.onErrorContainer,
                      bodySmall: true,
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(ThemeConfig.spacingM),
                decoration: AccentSurfaces.flatPanel(colorScheme),
                child: Row(
                  children: [
                    const OnboardingListCardIcon(
                      icon: Icons.cloud_off_outlined,
                      usePrimaryContainer: false,
                    ),
                    const SizedBox(width: ThemeConfig.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'onboarding_online'.tr(),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: ThemeConfig.spacingXS),
                          Text(
                            'onboarding_online_unavailable'.tr(),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: ThemeConfig.spacingL),
            OnboardingPlaque.compact(
              child: GestureDetector(
                onTap: () => context.push(RoutePaths.privacyPolicy),
                child: Text.rich(
                  TextSpan(
                    text: 'onboarding_privacy_agree_prefix'.tr(),
                    children: [
                      TextSpan(
                        text: 'privacy_policy'.tr(),
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Crossfade (+ light slide) for the Connect page supporting line.
class _ModeDescSwitcher extends StatelessWidget {
  const _ModeDescSwitcher({required this.modeDesc});

  final String modeDesc;

  @override
  Widget build(BuildContext context) {
    final fadeOnly = UiPerf.preferFadeOnlyPageTransitions;
    final anim =
        UiPerf.preferInstantShellTabs ? Duration.zero : AppMotion.page;
    return AnimatedSize(
      duration: anim,
      curve: AppMotion.enterCurve,
      alignment: AlignmentDirectional.topStart,
      child: AnimatedSwitcher(
        duration: anim,
        switchInCurve: AppMotion.enterCurve,
        switchOutCurve: AppMotion.exitCurve,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: AlignmentDirectional.topStart,
            children: <Widget>[
              ...previousChildren,
              ?currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final faded = FadeTransition(opacity: animation, child: child);
          if (fadeOnly) return faded;
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.12),
              end: Offset.zero,
            ).animate(animation),
            child: faded,
          );
        },
        child: Text(
          modeDesc,
          key: ValueKey<String>(modeDesc),
          // Inherit the sky ink + halo from [OnboardingTitleBlock].
          style: DefaultTextStyle.of(context).style,
        ),
      ),
    );
  }
}

/// Expands/collapses the online sign-in + disclaimer block.
class _OnlineDetailsReveal extends StatelessWidget {
  const _OnlineDetailsReveal({
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fadeOnly = UiPerf.preferFadeOnlyPageTransitions;
    final anim =
        UiPerf.preferInstantShellTabs ? Duration.zero : AppMotion.page;
    return AnimatedSize(
      duration: anim,
      curve: AppMotion.enterCurve,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: anim,
        switchInCurve: AppMotion.enterCurve,
        switchOutCurve: AppMotion.exitCurve,
        transitionBuilder: (widget, animation) {
          final faded = FadeTransition(opacity: animation, child: widget);
          if (fadeOnly) return faded;
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.06),
              end: Offset.zero,
            ).animate(animation),
            child: faded,
          );
        },
        child: visible
            ? KeyedSubtree(key: const ValueKey('online-details'), child: child)
            : const SizedBox(
                key: ValueKey('online-details-empty'),
                width: double.infinity,
              ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtle = context.subtleAccents;
    final fill = selected
        ? onboardingOpaqueFill(
            colorScheme,
            AccentSurfaces.emphasizedFill(colorScheme, subtle: subtle),
          )
        : colorScheme.surfaceContainerLow;
    final border = selected
        ? AccentSurfaces.emphasizedBorder(colorScheme, subtle: subtle)
        : colorScheme.outlineVariant.withValues(alpha: 0.45);
    final iconWell = selected
        ? colorScheme.primaryContainer.withValues(alpha: 0.55)
        : colorScheme.surfaceContainerHighest;
    final iconColor = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    final anim = UiPerf.preferInstantShellTabs ? Duration.zero : AppMotion.page;
    final checkAnim =
        UiPerf.preferInstantShellTabs ? Duration.zero : AppMotion.shellTab;

    return Padding(
      padding: const EdgeInsets.only(bottom: ThemeConfig.spacingS),
      child: AnimatedContainer(
        duration: anim,
        curve: AppMotion.enterCurve,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: border,
            width: selected ? 1.75 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: anim,
                    curve: AppMotion.enterCurve,
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: iconWell,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 24, color: iconColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: selected
                        ? Icon(
                            Icons.check_circle,
                            color: colorScheme.primary,
                            size: 22,
                          )
                        : AnimatedOpacity(
                            opacity: 0,
                            duration: checkAnim,
                            child: Icon(
                              Icons.check_circle,
                              color: colorScheme.primary,
                              size: 22,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.message,
    required this.fill,
    required this.border,
    required this.iconColor,
    required this.textColor,
    this.bodySmall = false,
  });

  final IconData icon;
  final String message;
  final Color fill;
  final Color border;
  final Color iconColor;
  final Color textColor;
  final bool bodySmall;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ThemeConfig.spacingM),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: ThemeConfig.spacingM),
          Expanded(
            child: Text(
              message,
              style: (bodySmall
                      ? Theme.of(context).textTheme.bodySmall
                      : Theme.of(context).textTheme.bodyMedium)
                  ?.copyWith(
                    color: textColor,
                    fontWeight: bodySmall ? null : FontWeight.w500,
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
