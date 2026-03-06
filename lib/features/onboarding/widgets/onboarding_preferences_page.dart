import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';

import '../../../core/layout/responsive_sheet.dart';
import '../../../core/theme/theme_config.dart';
import '../../../core/theme/flex_theme_builder.dart'
    show flexSchemeOptionIds, primaryColorForSchemeId;
import '../../../core/utils/currency_helpers.dart';
import '../../settings/providers/settings_framework_providers.dart';
import '../../settings/settings_definitions.dart';
import 'onboarding_shared.dart';

/// Predefined theme schemes only (no custom) for simpler onboarding.
final _onboardingThemeSchemeIds = flexSchemeOptionIds
    .where((id) => id != 'custom')
    .toList();

const List<String> _fontSizeOptions = [
  'small',
  'normal',
  'large',
  'extra_large',
];

class OnboardingPreferencesPage extends ConsumerWidget {
  const OnboardingPreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    if (settings == null) {
      return const SizedBox.shrink();
    }
    return onboardingPageBodyWithFixedTitle(
      context,
      contentAlignment: Alignment.topCenter,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'onboarding_preferences'.tr(),
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: ThemeConfig.spacingS),
          Text(
            'onboarding_preferences_desc'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _buildPreferencesTiles(context, ref, settings),
      ),
    );
  }
}

List<Widget> _buildPreferencesTiles(
  BuildContext context,
  WidgetRef ref,
  SettingsProviders settings,
) {
  final colorScheme = Theme.of(context).colorScheme;
  final displayCurrency = ref
      .watch(settings.provider(displayCurrencySettingDef))
      .trim();
  final displayCurrencyLabel = displayCurrency.isEmpty
      ? 'display_currency_none'.tr()
      : (CurrencyHelpers.fromCode(displayCurrency) != null
            ? CurrencyHelpers.shortLabel(
                CurrencyHelpers.fromCode(displayCurrency)!,
              )
            : displayCurrency);
  final use24h = ref.watch(settings.provider(use24HourFormatSettingDef));
  final fontSize = ref.watch(settings.provider(fontSizeScaleSettingDef));
  final themeScheme = ref.watch(settings.provider(themeSchemeSettingDef));

  return [
    OnboardingListCard(
      leading: const OnboardingListCardIcon(icon: Icons.visibility_outlined),
      title: 'display_currency'.tr(),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'display_currency_hint'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
          const SizedBox(height: ThemeConfig.spacingXS),
          Text(
            displayCurrencyLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      trailing: displayCurrency.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'display_currency_none'.tr(),
              onPressed: () {
                ref
                    .read(settings.provider(displayCurrencySettingDef).notifier)
                    .set('');
                Log.info(
                  'Setting changed: ${displayCurrencySettingDef.key}=(none)',
                );
              },
            )
          : null,
      onTap: () {
        CurrencyHelpers.showPicker(
          context: context,
          centerInFullViewport: true,
          favorite: CurrencyHelpers.getEffectiveFavorites(''),
          onSelect: (currency) {
            ref
                .read(settings.provider(displayCurrencySettingDef).notifier)
                .set(currency.code);
            Log.info(
              'Setting changed: ${displayCurrencySettingDef.key}=${currency.code}',
            );
          },
        );
      },
    ),
    OnboardingListCard(
      leading: const OnboardingListCardIcon(icon: Icons.schedule),
      title: 'use_24_hour_format'.tr(),
      subtitle: Text(
        'use_24_hour_format_description'.tr(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          height: 1.3,
        ),
      ),
      trailing: Switch(
        value: use24h,
        onChanged: (v) {
          ref
              .read(settings.provider(use24HourFormatSettingDef).notifier)
              .set(v);
          Log.info('Setting changed: ${use24HourFormatSettingDef.key}=$v');
        },
      ),
    ),
    OnboardingListCard(
      leading: OnboardingListCardIcon(
        icon: fontSizeScaleSettingDef.icon ?? Icons.text_fields,
      ),
      title: 'font_size'.tr(),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'font_size_description'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
          const SizedBox(height: ThemeConfig.spacingXS),
          Text(
            fontSize.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      onTap: () {
        showResponsiveSheet<String>(
          context: context,
          title: 'font_size'.tr(),
          maxHeight: MediaQuery.of(context).size.height * 0.75,
          isScrollControlled: true,
          centerInFullViewport: true,
          child: Builder(
            builder: (ctx) => SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        MediaQuery.of(ctx).padding.bottom +
                        ThemeConfig.spacingM,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _fontSizeOptions
                        .map(
                          (option) => ListTile(
                            title: Text(option.tr()),
                            onTap: () => Navigator.of(ctx).pop(option),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ).then((chosen) {
          if (chosen != null && context.mounted) {
            ref
                .read(settings.provider(fontSizeScaleSettingDef).notifier)
                .set(chosen);
            Log.info('Setting changed: ${fontSizeScaleSettingDef.key}=$chosen');
          }
        });
      },
    ),
    OnboardingListCard(
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primaryColorForSchemeId(themeScheme) != Colors.transparent
              ? primaryColorForSchemeId(themeScheme)
              : colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(
            color: colorScheme.outline,
            width: ThemeConfig.inputDefaultBorderWidth,
          ),
        ),
        child: primaryColorForSchemeId(themeScheme) == Colors.transparent
            ? Icon(themeSchemeSettingDef.icon, size: 22)
            : null,
      ),
      title: 'color_scheme'.tr(),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'color_scheme_description'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
          const SizedBox(height: ThemeConfig.spacingXS),
          Text(
            'theme_scheme_$themeScheme'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      onTap: () {
        showResponsiveSheet<String>(
          context: context,
          title: 'color_scheme'.tr(),
          maxHeight: MediaQuery.of(context).size.height * 0.75,
          isScrollControlled: true,
          centerInFullViewport: true,
          child: Builder(
            builder: (ctx) => SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        MediaQuery.of(ctx).padding.bottom +
                        ThemeConfig.spacingM,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _onboardingThemeSchemeIds.map((schemeId) {
                      final chipColor = primaryColorForSchemeId(schemeId);
                      return ListTile(
                        leading: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: chipColor != Colors.transparent
                                ? chipColor
                                : Theme.of(
                                    ctx,
                                  ).colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(ctx).colorScheme.outline,
                            ),
                          ),
                        ),
                        title: Text('theme_scheme_$schemeId'.tr()),
                        onTap: () => Navigator.of(ctx).pop(schemeId),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ).then((chosen) {
          if (chosen != null && context.mounted) {
            ref
                .read(settings.provider(themeSchemeSettingDef).notifier)
                .set(chosen);
            Log.info('Setting changed: ${themeSchemeSettingDef.key}=$chosen');
          }
        });
      },
    ),
  ];
}
