import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/route_paths.dart';
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

    return onboardingPageBodyWithFixedTitle(
      context,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'onboarding_connect'.tr(),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: ThemeConfig.spacingS),
          Text(
            'onboarding_offline_desc'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
      contentAlignment: Alignment.topCenter,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onlineAvailable) ...[
            SegmentedButton<bool>(
              style: ButtonStyle(
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(
                    vertical: ThemeConfig.spacingM,
                    horizontal: ThemeConfig.spacingS,
                  ),
                ),
              ),
              segments: [
                ButtonSegment(
                  value: true,
                  label: Text('onboarding_offline'.tr()),
                  icon: const Icon(Icons.storage_outlined),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('onboarding_online'.tr()),
                  icon: const Icon(Icons.cloud_outlined),
                ),
              ],
              selected: {isLocalOnly},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  ref
                      .read(settings.provider(localOnlySettingDef).notifier)
                      .set(selection.first);
                  Log.info(
                    'Setting changed: ${localOnlySettingDef.key}=${selection.first}',
                  );
                }
              },
            ),
            if (!isLocalOnly) ...[
              const SizedBox(height: ThemeConfig.spacingM),
              Container(
                padding: const EdgeInsets.all(ThemeConfig.spacingM),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(ThemeConfig.radiusM),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: ThemeConfig.spacingM),
                    Expanded(
                      child: Text(
                        'onboarding_online_requires_sign_in'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ThemeConfig.spacingS),
              Container(
                padding: const EdgeInsets.all(ThemeConfig.spacingM),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(ThemeConfig.radiusM),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: ThemeConfig.spacingM),
                    Expanded(
                      child: Text(
                        'onboarding_online_disclaimer'.tr(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.all(ThemeConfig.spacingM),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(ThemeConfig.spacingS),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(ThemeConfig.radiusM),
                    ),
                    child: Icon(
                      Icons.cloud_off_outlined,
                      size: 24,
                      color: colorScheme.onSurfaceVariant,
                    ),
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
          GestureDetector(
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
        ],
      ),
    );
  }
}
