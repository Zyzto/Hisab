import 'dart:async';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/motion/app_motion.dart';
import '../../../core/platform/network_image_decode.dart';
import '../../../core/platform/ui_perf.dart';
import '../../../core/theme/accent_style.dart';
import '../../../core/theme/theme_config.dart';
import 'onboarding_ambient.dart';
import 'onboarding_shared.dart';

class OnboardingWelcomePage extends StatefulWidget {
  const OnboardingWelcomePage({super.key});

  /// Logical size of the app mark in the hero card.
  static const double heroLogoSize = 76;

  @override
  State<OnboardingWelcomePage> createState() => _OnboardingWelcomePageState();
}

class _OnboardingWelcomePageState extends State<OnboardingWelcomePage>
    with TickerProviderStateMixin {
  static const _features = <_FeatureSpec>[
    _FeatureSpec(
      icon: Icons.group_outlined,
      titleKey: 'onboarding_groups',
      subtitleKey: 'onboarding_groups_desc',
    ),
    _FeatureSpec(
      icon: Icons.person_outline,
      titleKey: 'onboarding_participants',
      subtitleKey: 'onboarding_participants_desc',
    ),
    _FeatureSpec(
      icon: Icons.receipt_long_outlined,
      titleKey: 'onboarding_expenses',
      subtitleKey: 'onboarding_expenses_desc',
    ),
    _FeatureSpec(
      icon: Icons.label_outlined,
      titleKey: 'onboarding_categories',
      subtitleKey: 'onboarding_categories_desc',
    ),
    _FeatureSpec(
      icon: Icons.account_balance_wallet_outlined,
      titleKey: 'onboarding_balance',
      subtitleKey: 'onboarding_balance_desc',
    ),
    _FeatureSpec(
      icon: Icons.swap_horiz,
      titleKey: 'onboarding_settle_up',
      subtitleKey: 'onboarding_settle_up_desc',
    ),
    _FeatureSpec(
      icon: Icons.person_outline,
      titleKey: 'onboarding_personal',
      subtitleKey: 'onboarding_personal_desc',
      optional: true,
    ),
  ];

  static const _staggerMs = 50;
  AnimationController? _heroController;
  CurvedAnimation? _heroFade;
  late final List<AnimationController> _featureControllers;
  late final List<Animation<double>> _featureAnimations;
  final List<Timer> _staggerTimers = [];
  late final bool _fadeOnly;

  @override
  void initState() {
    super.initState();
    _fadeOnly = UiPerf.preferFadeOnlyPageTransitions;
    if (_fadeOnly) {
      // No stagger controllers on iOS web — static content only.
      _featureControllers = <AnimationController>[];
      _featureAnimations = List<Animation<double>>.filled(
        _features.length,
        const AlwaysStoppedAnimation<double>(1),
      );
      return;
    }

    _heroController = AnimationController(vsync: this, duration: AppMotion.page);
    _heroFade = CurvedAnimation(
      parent: _heroController!,
      curve: AppMotion.enterCurve,
    );
    _featureControllers = List.generate(
      _features.length,
      (_) => AnimationController(vsync: this, duration: AppMotion.page),
    );
    _featureAnimations = [
      for (final c in _featureControllers)
        CurvedAnimation(parent: c, curve: AppMotion.enterCurve),
    ];

    _heroController!.forward();
    for (var i = 0; i < _featureControllers.length; i++) {
      final index = i;
      _staggerTimers.add(
        Timer(Duration(milliseconds: _staggerMs * index), () {
          if (!mounted) return;
          _featureControllers[index].forward();
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final t in _staggerTimers) {
      t.cancel();
    }
    _staggerTimers.clear();
    _heroFade?.dispose();
    _heroController?.dispose();
    for (final a in _featureAnimations) {
      if (a is CurvedAnimation) a.dispose();
    }
    for (final c in _featureControllers) {
      c.dispose();
    }
    super.dispose();
  }

  static const double heroLogoSize = OnboardingWelcomePage.heroLogoSize;

  Widget _buildHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtle = context.subtleAccents;
    final decode = NetworkImageDecode.cacheSize(
      context,
      logicalWidth: heroLogoSize,
      logicalHeight: heroLogoSize,
    );
    const logoRadius = 20.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: ThemeConfig.spacingS),
      child: Material(
        color: onboardingOpaqueFill(
          colorScheme,
          AccentSurfaces.emphasizedFill(colorScheme, subtle: subtle),
        ),
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AccentSurfaces.emphasizedBorder(
                colorScheme,
                subtle: subtle,
              ).withValues(alpha: 0.55),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                OnboardingBreathing(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(logoRadius),
                    child: Image.asset(
                      'assets/Hisab.png',
                      width: heroLogoSize,
                      height: heroLogoSize,
                      fit: BoxFit.cover,
                      cacheWidth: decode.width,
                      cacheHeight: decode.height,
                      errorBuilder: (_, error, stackTrace) => Container(
                        width: heroLogoSize,
                        height: heroLogoSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.55,
                          ),
                          borderRadius: BorderRadius.circular(logoRadius),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          color: colorScheme.onPrimaryContainer,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: ThemeConfig.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'app_name'.tr(),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'onboarding_what_is_hisab'.tr(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hero = _buildHeroCard(context);
    final animatedHero = (_fadeOnly || _heroFade == null)
        ? hero
        : FadeTransition(opacity: _heroFade!, child: hero);
    return onboardingPageBodyWithFixedTitle(
      context,
      contentAlignment: Alignment.topCenter,
      title: OnboardingStepEnter(
        slidePx: 12,
        child: OnboardingTitleBlock(title: 'onboarding_welcome'.tr()),
      ),
      // Hero + section label stay put; only the feature list scrolls.
      pinnedBelowTitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          animatedHero,
          const SizedBox(height: ThemeConfig.spacingM),
          OnboardingSectionLabel('onboarding_how_it_works'.tr()),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _features.length; i++)
            _StaggeredFeatureRow(
              animation: _featureAnimations[i],
              fadeOnly: _fadeOnly,
              spec: _features[i],
              iconPhase: i * 0.13,
            ),
        ],
      ),
    );
  }
}

class _FeatureSpec {
  const _FeatureSpec({
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
    this.optional = false,
  });

  final IconData icon;
  final String titleKey;
  final String subtitleKey;
  final bool optional;
}

class _StaggeredFeatureRow extends StatelessWidget {
  const _StaggeredFeatureRow({
    required this.animation,
    required this.fadeOnly,
    required this.spec,
    required this.iconPhase,
  });

  final Animation<double> animation;
  final bool fadeOnly;
  final _FeatureSpec spec;
  final double iconPhase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOptional = spec.optional;
    final iconChip = Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isOptional
            ? colorScheme.surfaceContainerHighest
            : onboardingOpaqueFill(
                colorScheme,
                colorScheme.primaryContainer.withValues(alpha: 0.55),
              ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        spec.icon,
        size: 22,
        color: isOptional
            ? colorScheme.onSurfaceVariant
            : colorScheme.onPrimaryContainer,
      ),
    );
    final card = Padding(
      padding: const EdgeInsets.only(bottom: ThemeConfig.spacingS),
      child: Material(
        color: isOptional
            ? onboardingOpaqueFill(
                colorScheme,
                colorScheme.surfaceContainerLow.withValues(alpha: 0.72),
              )
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(
                alpha: isOptional ? 0.28 : 0.38,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OnboardingIconPulse(phase: iconPhase, child: iconChip),
                const SizedBox(width: ThemeConfig.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.titleKey.tr(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                          color: isOptional
                              ? colorScheme.onSurfaceVariant
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        spec.subtitleKey.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isOptional
                              ? colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.85,
                                )
                              : colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // iOS web / finished stagger: skip Opacity saveLayer.
    if (fadeOnly || animation.isCompleted) return card;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final v = animation.value;
        Widget result = child!;
        if (!fadeOnly) {
          result = Transform.translate(
            offset: Offset(0, (1 - v) * 16),
            child: result,
          );
        }
        return Opacity(opacity: v, child: result);
      },
      child: card,
    );
  }
}
