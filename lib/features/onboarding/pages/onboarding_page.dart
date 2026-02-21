import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/sign_in_sheet.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/theme/theme_config.dart';
import '../../settings/providers/settings_framework_providers.dart';
import '../../settings/settings_definitions.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  late final PageController _pageController;

  static const List<Locale> _supportedLocales = [Locale('en'), Locale('ar')];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static String _localeDisplayName(Locale locale) {
    switch (locale.languageCode) {
      case 'ar':
        return 'العربية';
      case 'en':
      default:
        return 'English';
    }
  }

  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    final onlineAvailable = supabaseConfigAvailable;

    if (settings == null) {
      return Scaffold(body: Center(child: Text('settings_unavailable'.tr())));
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildPage1(context, ref, settings),
                  _buildPage2(context, ref, settings, onlineAvailable),
                ],
              ),
            ),
            _buildPageIndicator(context),
            _buildNavigationBar(context, colorScheme, settings),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ThemeConfig.spacingS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(2, (index) {
          final isActive = index == _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: isActive
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLanguageButton(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final currentLang = ref.watch(settings.provider(languageSettingDef));
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.surfaceContainerHighest,
        foregroundColor: colorScheme.onSurface,
      ),
      onPressed: () async {
        final chosen = await showModalBottomSheet<Locale>(
          context: context,
          isScrollControlled: true,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          builder: (ctx) => SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).padding.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'language'.tr(),
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                    ),
                    ..._supportedLocales.map(
                      (locale) => ListTile(
                        title: Text(_localeDisplayName(locale)),
                        onTap: () => Navigator.of(ctx).pop(locale),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        if (chosen != null && context.mounted) {
          await ref
              .read(settings.provider(languageSettingDef).notifier)
              .set(chosen.languageCode);
          // _LocaleSync will call setLocale when it sees provider != context.locale
        }
      },
      icon: const Icon(Icons.language),
      tooltip:
          '${'language'.tr()}: ${currentLang == 'ar' ? _localeDisplayName(const Locale('ar')) : _localeDisplayName(const Locale('en'))}',
    );
  }

  Widget _buildThemeButton(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final currentTheme = ref.watch(settings.provider(themeModeSettingDef));
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.surfaceContainerHighest,
        foregroundColor: colorScheme.onSurface,
      ),
      onPressed: () {
        const order = ['light', 'dark', 'system', 'amoled'];
        final idx = order.indexOf(currentTheme);
        final next = order[(idx + 1) % order.length];
        ref.read(settings.provider(themeModeSettingDef).notifier).set(next);
      },
      icon: Icon(_themeIcon(currentTheme)),
      tooltip: '${'theme'.tr()}: ${currentTheme.tr()}',
    );
  }

  Widget _buildNavigationBar(
    BuildContext context,
    ColorScheme colorScheme,
    SettingsProviders settings,
  ) {
    return Container(
      padding: const EdgeInsets.all(ThemeConfig.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _currentPage > 0
                  ? TextButton.icon(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: Text('onboarding_back'.tr()),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLanguageButton(context, ref, settings),
              const SizedBox(width: ThemeConfig.spacingS),
              _buildThemeButton(context, ref, settings),
            ],
          ),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _currentPage == 0
                  ? FilledButton.icon(
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: Text('onboarding_next'.tr()),
                    )
                  : FilledButton.icon(
                      onPressed: () async =>
                          await _completeOnboarding(ref, settings),
                      icon: const Icon(Icons.check),
                      label: Text('onboarding_complete'.tr()),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage1(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Padding(
                padding: const EdgeInsets.all(ThemeConfig.spacingM),
                child: Column(
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
                    _buildFeatureCard(
                      context,
                      icon: Icons.group_outlined,
                      title: 'onboarding_groups'.tr(),
                      subtitle: 'onboarding_groups_desc'.tr(),
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.person_outline,
                      title: 'onboarding_participants'.tr(),
                      subtitle: 'onboarding_participants_desc'.tr(),
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.receipt_long_outlined,
                      title: 'onboarding_expenses'.tr(),
                      subtitle: 'onboarding_expenses_desc'.tr(),
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'onboarding_balance'.tr(),
                      subtitle: 'onboarding_balance_desc'.tr(),
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.swap_horiz,
                      title: 'onboarding_settle_up'.tr(),
                      subtitle: 'onboarding_settle_up_desc'.tr(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: ThemeConfig.spacingS),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ThemeConfig.spacingM),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(ThemeConfig.radiusM),
              ),
              child: Icon(
                icon,
                size: 24,
                color: colorScheme.onPrimaryContainer,
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
                    ),
                  ),
                  const SizedBox(height: ThemeConfig.spacingXS),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
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

  IconData _themeIcon(String theme) {
    switch (theme) {
      case 'system':
        return Icons.motion_photos_auto; // auto
      case 'light':
        return Icons.light_mode; // sun
      case 'dark':
        return Icons.dark_mode; // moon
      case 'amoled':
        return Symbols.ev_shadow; // AMOLED black
      default:
        return Icons.brightness_auto;
    }
  }

  Widget _buildPage2(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
    bool onlineAvailable,
  ) {
    final isLocalOnly = ref.watch(settings.provider(localOnlySettingDef));
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Padding(
                padding: const EdgeInsets.all(ThemeConfig.spacingM),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: ThemeConfig.spacingL),
                    Text(
                      'onboarding_connect'.tr(),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: ThemeConfig.spacingS),
                    Text(
                      'onboarding_offline_desc'.tr(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: ThemeConfig.spacingXL),
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
                                .read(
                                  settings
                                      .provider(localOnlySettingDef)
                                      .notifier,
                                )
                                .set(selection.first);
                            if (!selection.first) {
                              Log.info(
                                'User selected online mode at onboarding',
                              );
                            }
                          }
                        },
                      ),
                      if (!isLocalOnly) ...[
                        const SizedBox(height: ThemeConfig.spacingM),
                        Container(
                          padding: const EdgeInsets.all(ThemeConfig.spacingM),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(
                              ThemeConfig.radiusM,
                            ),
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
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
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
                            color: colorScheme.errorContainer.withValues(
                              alpha: 0.4,
                            ),
                            borderRadius: BorderRadius.circular(
                              ThemeConfig.radiusM,
                            ),
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
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
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
                          borderRadius: BorderRadius.circular(
                            ThemeConfig.radiusL,
                          ),
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(
                                  ThemeConfig.radiusM,
                                ),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'onboarding_online_unavailable'.tr(),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
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
                      onTap: () =>
                          context.push(RoutePaths.privacyPolicy),
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
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _completeOnboarding(
    WidgetRef ref,
    SettingsProviders settings,
  ) async {
    final isLocalOnly = ref.read(settings.provider(localOnlySettingDef));
    final onlineAvailable = supabaseConfigAvailable;

    if (!isLocalOnly && onlineAvailable) {
      final authService = ref.read(authServiceProvider);
      if (!authService.isAuthenticated) {
        if (!mounted) return;
        final result = await showSignInSheet(context, ref);
        switch (result) {
          case SignInResult.success:
            // Auth completed, continue to finish onboarding
            break;
          case SignInResult.pendingRedirect:
            // OAuth redirect on web — set pending flag, page will reload
            ref
                .read(
                  settings.provider(onboardingOnlinePendingSettingDef).notifier,
                )
                .set(true);
            Log.info('Onboarding OAuth redirect pending (web)');
            return; // Page will reload, main.dart handles completion
          case SignInResult.cancelled:
            if (mounted) {
              context.showToast('onboarding_online_requires_sign_in'.tr());
            }
            return;
        }
      }
    }

    ref
        .read(settings.provider(onboardingCompletedSettingDef).notifier)
        .set(true);
    Log.info('Onboarding completed');
    if (!mounted) return;
    final pendingToken = ref.read(
      settings.provider(pendingInviteTokenSettingDef),
    );
    if (pendingToken.isNotEmpty) {
      ref
          .read(settings.provider(pendingInviteTokenSettingDef).notifier)
          .set('');
      context.go(RoutePaths.inviteAccept(pendingToken));
    } else {
      context.go(RoutePaths.home);
    }
  }
}
