import 'dart:async';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/motion/app_motion.dart';
import '../../../core/platform/network_image_decode.dart';
import '../../../core/platform/ui_perf.dart';
import '../../../core/theme/accent_style.dart';
import '../../../core/theme/theme_config.dart';
import '../../../core/widgets/group_section_header.dart';
import 'onboarding_shared.dart';

class OnboardingWelcomePage extends StatefulWidget {
  const OnboardingWelcomePage({super.key});

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

  Widget _buildHeroCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final subtle = context.subtleAccents;
    final decode = NetworkImageDecode.cacheSize(
      context,
      logicalWidth: 48,
      logicalHeight: 48,
    );
    return Container(
      padding: const EdgeInsets.all(ThemeConfig.spacingM),
      decoration: AccentSurfaces.panel(colorScheme, subtle: subtle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/Hisab.png',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              cacheWidth: decode.width,
              cacheHeight: decode.height,
              errorBuilder: (_, error, stackTrace) => Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: ThemeConfig.spacingM),
          Text(
            'onboarding_welcome'.tr(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: ThemeConfig.spacingS),
          Text(
            'onboarding_what_is_hisab'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hero = _buildHeroCard(context);
    return onboardingPageBody(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_fadeOnly || _heroFade == null)
            hero
          else
            FadeTransition(opacity: _heroFade!, child: hero),
          const SizedBox(height: ThemeConfig.spacingL),
          GroupSectionHeader(label: 'onboarding_how_it_works'.tr()),
          const SizedBox(height: ThemeConfig.spacingM),
          for (var i = 0; i < _features.length; i++)
            _StaggeredFeatureRow(
              animation: _featureAnimations[i],
              fadeOnly: _fadeOnly,
              spec: _features[i],
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
  });

  final Animation<double> animation;
  final bool fadeOnly;
  final _FeatureSpec spec;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOptional = spec.optional;
    final card = Padding(
      padding: const EdgeInsets.only(bottom: ThemeConfig.spacingS),
      child: Material(
        color: isOptional
            ? colorScheme.surfaceContainerLow.withValues(alpha: 0.7)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(
                alpha: isOptional ? 0.3 : 0.45,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isOptional
                        ? colorScheme.surfaceContainerHighest
                        : colorScheme.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(ThemeConfig.radiusM),
                  ),
                  child: Icon(
                    spec.icon,
                    size: 22,
                    color: isOptional
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: ThemeConfig.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.titleKey.tr(),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isOptional
                                  ? colorScheme.onSurfaceVariant
                                  : null,
                            ),
                      ),
                      const SizedBox(height: ThemeConfig.spacingXS),
                      Text(
                        spec.subtitleKey.tr(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isOptional
                              ? colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.85,
                                )
                              : colorScheme.onSurfaceVariant,
                          height: 1.3,
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
