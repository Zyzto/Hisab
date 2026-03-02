import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/theme/theme_config.dart';
import 'onboarding_shared.dart';

class OnboardingWelcomePage extends StatelessWidget {
  const OnboardingWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return onboardingPageBody(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: ThemeConfig.spacingS),
          Text(
            'onboarding_welcome'.tr(),
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: ThemeConfig.spacingS),
          Text(
            'onboarding_what_is_hisab'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: ThemeConfig.spacingM),
          Text(
            'onboarding_how_it_works'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ThemeConfig.spacingM),
          _OnboardingFeatureCard(
            icon: Icons.group_outlined,
            title: 'onboarding_groups'.tr(),
            subtitle: 'onboarding_groups_desc'.tr(),
          ),
          _OnboardingFeatureCard(
            icon: Icons.person_outline,
            title: 'onboarding_participants'.tr(),
            subtitle: 'onboarding_participants_desc'.tr(),
          ),
          _OnboardingFeatureCard(
            icon: Icons.receipt_long_outlined,
            title: 'onboarding_expenses'.tr(),
            subtitle: 'onboarding_expenses_desc'.tr(),
          ),
          _OnboardingFeatureCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'onboarding_balance'.tr(),
            subtitle: 'onboarding_balance_desc'.tr(),
          ),
          _OnboardingFeatureCard(
            icon: Icons.swap_horiz,
            title: 'onboarding_settle_up'.tr(),
            subtitle: 'onboarding_settle_up_desc'.tr(),
          ),
          _OnboardingFeatureCard(
            icon: Icons.person_outline,
            title: 'onboarding_personal'.tr(),
            subtitle: 'onboarding_personal_desc'.tr(),
            optional: true,
          ),
        ],
      ),
    );
  }
}

class _OnboardingFeatureCard extends StatelessWidget {
  const _OnboardingFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.optional = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOptional = optional;
    return Card(
      margin: const EdgeInsets.only(bottom: ThemeConfig.spacingS),
      elevation: ThemeConfig.cardElevation,
      color: isOptional
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeConfig.cardBorderRadius),
        side: BorderSide(
          color: isOptional
              ? colorScheme.outline.withValues(alpha: 0.15)
              : colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ThemeConfig.spacingM),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(ThemeConfig.spacingS),
              decoration: BoxDecoration(
                color: isOptional
                    ? colorScheme.surfaceContainerHighest
                    : colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(ThemeConfig.radiusM),
              ),
              child: Icon(
                icon,
                size: 24,
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
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isOptional
                          ? colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                  const SizedBox(height: ThemeConfig.spacingXS),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isOptional
                          ? colorScheme.onSurfaceVariant.withValues(alpha: 0.85)
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
    );
  }
}
