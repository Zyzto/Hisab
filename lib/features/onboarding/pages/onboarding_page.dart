import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/sign_in_sheet.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/theme/theme_config.dart';
import '../../../core/utils/currency_helpers.dart';
import '../../../core/theme/flex_theme_builder.dart'
    show flexSchemeOptionIds, primaryColorForSchemeId;
import '../../settings/providers/settings_framework_providers.dart';
import '../../settings/settings_definitions.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _languagePulseController;

  static const List<Locale> _supportedLocales = [Locale('en'), Locale('ar')];
  /// Same hint for language switcher, in each supported locale (order matches _supportedLocales).
  static const List<String> _hintLanguageInLocales = [
    'You can change language from here', // en
    'تقدر تغيّر اللغة من هنا', // ar
  ];
  static const List<String> _themeDemoOrder = [
    'light',
    'dark',
    'system',
    'amoled',
  ];

  bool? _cameraGranted;
  bool? _notificationGranted;
  Future<({bool camera, bool notification})>? _permissionStatusFuture;

  int _hintLocaleIndex = 0;
  int _themeDemoIndex = 0;
  bool _themeDemoRunning = true;
  bool _languagePulseStopped = false;
  late final AnimationController _languageTapController;
  Timer? _hintTimer;
  Timer? _themeDemoTimer;
  Timer? _languagePulseStopTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _languagePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    // Stop pulse after 3 cycles (~6s) to avoid continuous 60fps AnimatedBuilder rebuilds
    _languagePulseStopTimer = Timer(
      const Duration(milliseconds: 6000),
      () {
        if (mounted) {
          _languagePulseController.stop();
          setState(() => _languagePulseStopped = true);
        }
      },
    );
    _languageTapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _hintTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) {
        if (mounted) {
          setState(() {
            _hintLocaleIndex =
                (_hintLocaleIndex + 1) % _hintLanguageInLocales.length;
          });
        }
      },
    );
    _themeDemoTimer = Timer.periodic(
      const Duration(milliseconds: 2500),
      (_) {
        if (mounted && _themeDemoRunning) {
          setState(() {
            _themeDemoIndex =
                (_themeDemoIndex + 1) % _themeDemoOrder.length;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _languagePulseStopTimer?.cancel();
    _languagePulseController.dispose();
    _languageTapController.dispose();
    _hintTimer?.cancel();
    _themeDemoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<({bool camera, bool notification})> _loadPermissionStatus() async {
    final camera = await PermissionService.isCameraPermissionGranted();
    final notification = await PermissionService.isNotificationPermissionGranted();
    return (camera: camera, notification: notification);
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
                onPageChanged: (i) {
                  setState(() {
                    _currentPage = i;
                    if (i == 2 && _permissionStatusFuture == null) {
                      _permissionStatusFuture = _loadPermissionStatus();
                    }
                  });
                },
                children: [
                  _buildPage1(context, ref, settings),
                  _buildPreferencesPage(context, ref, settings),
                  _buildPermissionsPage(context, ref, settings, onlineAvailable),
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
        children: List.generate(4, (index) {
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
    final tooltip =
        '${'language'.tr()}: ${currentLang == 'ar' ? _localeDisplayName(const Locale('ar')) : _localeDisplayName(const Locale('en'))}';
    return Semantics(
      button: true,
      label: tooltip,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _languagePulseController,
          _languageTapController,
        ]),
        builder: (context, child) {
          double scale = 1.0;
          if (_languageTapController.isAnimating) {
            final t = _languageTapController.value;
            scale = 1.0 - 0.16 * (0.5 - 0.5 * (2 * t - 1).abs());
          } else if (!_languagePulseStopped) {
            final t = _languagePulseController.value;
            scale = 1.0 + 0.12 * (0.5 - 0.5 * (2 * t - 1).abs());
          }
          return Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Material(
              color: colorScheme.surfaceContainerHighest,
              shape: const CircleBorder(),
              child: InkWell(
              onTap: () async {
                if (!_languagePulseStopped) {
                  _languagePulseStopped = true;
                  _languagePulseController.stop();
                }
                _languageTapController.forward(from: 0);
          final chosen = await showResponsiveSheet<Locale>(
            context: context,
            title: 'language'.tr(),
            maxHeight: MediaQuery.of(context).size.height * 0.75,
            isScrollControlled: true,
            centerInFullViewport: true,
            child: Builder(
              builder: (ctx) => SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(ctx).padding.bottom + 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!LayoutBreakpoints.isTabletOrWider(context))
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
            ),
          );
          if (chosen != null && context.mounted) {
            await ref
                .read(settings.provider(languageSettingDef).notifier)
                .set(chosen.languageCode);
            // _LocaleSync will call setLocale when it sees provider != context.locale
          }
        },
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.language,
                    color: colorScheme.onSurface,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Background colors for theme mode morphing (light, dark, system gradient, amoled).
  static const Color _themeLightBg = Color(0xFFF5E6C8);
  static const Color _themeDarkBg = Color(0xFF37474F);
  static const Color _themeAmoledBg = Color(0xFF000000);
  static const Color _themeLightIcon = Color(0xFF5D4037);
  static const Color _themeDarkIcon = Color(0xFFECEFF1);

  Widget _buildThemeButton(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final currentTheme = ref.watch(settings.provider(themeModeSettingDef));
    final colorScheme = Theme.of(context).colorScheme;
    final displayTheme =
        _themeDemoRunning ? _themeDemoOrder[_themeDemoIndex] : currentTheme;
    final tooltip = '${'theme'.tr()}: ${currentTheme.tr()}';
    final iconColor = displayTheme == 'light'
        ? _themeLightIcon
        : (displayTheme == 'system'
            ? colorScheme.onSurface
            : _themeDarkIcon);
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (_themeDemoRunning) {
                  _themeDemoTimer?.cancel();
                  _themeDemoTimer = null;
                  setState(() => _themeDemoRunning = false);
                }
                const order = ['light', 'dark', 'system', 'amoled'];
                final idx = order.indexOf(currentTheme);
                final next = order[(idx + 1) % order.length];
                ref.read(settings.provider(themeModeSettingDef).notifier).set(next);
              },
              customBorder: const CircleBorder(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: displayTheme == 'system'
                    ? colorScheme.surfaceContainerHighest
                    : (displayTheme == 'light'
                        ? _themeLightBg
                        : displayTheme == 'amoled'
                            ? _themeAmoledBg
                            : _themeDarkBg),
                ),
                child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.6, end: 1.0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutBack,
                        ),
                      ),
                      child: child,
                    ),
                  );
                },
                child: Icon(
                  _themeIcon(displayTheme),
                  key: ValueKey<String>(displayTheme),
                  color: iconColor,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
      ),
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
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _currentPage > 0
                        ? Semantics(
                            button: true,
                            label: 'onboarding_back'.tr(),
                            child: TextButton.icon(
                              onPressed: () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              icon: const Icon(Icons.arrow_back),
                              label: Text('onboarding_back'.tr()),
                            ),
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
                    child: _currentPage < _lastPageIndex
                        ? Semantics(
                            button: true,
                            label: 'onboarding_next'.tr(),
                            child: FilledButton.icon(
                              onPressed: () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              icon: const Icon(Icons.arrow_forward),
                              label: Text('onboarding_next'.tr()),
                            ),
                          )
                        : Semantics(
                            button: true,
                            label: 'onboarding_complete'.tr(),
                            child: FilledButton.icon(
                              onPressed: () async =>
                                  await _completeOnboarding(ref, settings),
                              icon: const Icon(Icons.check),
                              label: Text('onboarding_complete'.tr()),
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ThemeConfig.spacingS),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _hintLanguageInLocales[_hintLocaleIndex],
                key: ValueKey<int>(_hintLocaleIndex),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
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
                    _buildFeatureCard(
                      context,
                      icon: Icons.person_outline,
                      title: 'onboarding_personal'.tr(),
                      subtitle: 'onboarding_personal_desc'.tr(),
                      optional: true,
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
    bool optional = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOptional = optional;
    return Card(
      margin: const EdgeInsets.only(bottom: ThemeConfig.spacingS),
      elevation: 0,
      color: isOptional
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
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
              padding: const EdgeInsets.all(10),
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

  Widget _buildPreferencesPage(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(ThemeConfig.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: ThemeConfig.spacingL),
              Text(
                'onboarding_preferences'.tr(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: ThemeConfig.spacingS),
              Text(
                'onboarding_preferences_desc'.tr(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: ThemeConfig.spacingXL),
              ..._buildPreferencesTiles(context, ref, settings),
            ],
          ),
        );
      },
    );
  }

  static const int _lastPageIndex = 3;

  Widget _buildPermissionsPage(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
    bool onlineAvailable,
  ) {
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
                      'onboarding_permissions_title'.tr(),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: ThemeConfig.spacingS),
                    Text(
                      'onboarding_permissions_desc'.tr(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: ThemeConfig.spacingXL),
                    FutureBuilder<({bool camera, bool notification})>(
                      future: _permissionStatusFuture,
                      builder: (context, snapshot) {
                        final cameraGranted =
                            _cameraGranted ?? snapshot.data?.camera ?? false;
                        final notificationGranted =
                            _notificationGranted ??
                            snapshot.data?.notification ??
                            false;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!kIsWeb)
                              _buildPermissionRow(
                                context,
                                icon: Icons.camera_alt_outlined,
                                title: 'onboarding_permission_camera'.tr(),
                                subtitle:
                                    'onboarding_permission_camera_desc'.tr(),
                                granted: cameraGranted,
                                onAllow: () async {
                                  final result = await PermissionService
                                      .requestCameraPermission(context);
                                  if (mounted) {
                                    setState(() => _cameraGranted = result);
                                  }
                                },
                              ),
                            _buildPermissionRow(
                              context,
                              icon: Icons.notifications_outlined,
                              title:
                                  'onboarding_permission_notifications'.tr(),
                              subtitle:
                                  'onboarding_permission_notifications_desc'
                                      .tr(),
                              granted: notificationGranted,
                              onAllow: () async {
                                final result = await PermissionService
                                    .requestNotificationPermission(context);
                                if (mounted) {
                                  setState(
                                    () => _notificationGranted = result,
                                  );
                                }
                              },
                            ),
                            if (onlineAvailable)
                              _buildNotificationsAppToggle(
                                context, ref, settings,
                              ),
                            _buildTelemetryToggle(context, ref, settings),
                          ],
                        );
                      },
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

  Widget _buildNotificationsAppToggle(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final enabled = ref.watch(
      settings.provider(notificationsEnabledSettingDef),
    );
    return Padding(
      padding: const EdgeInsets.only(top: ThemeConfig.spacingS),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: SwitchListTile(
          secondary: Icon(
            Icons.notifications_active_outlined,
            size: 24,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          title: Text(
            'notifications_enabled'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          subtitle: Text(
            'notifications_enabled_description'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          value: enabled,
          onChanged: (v) async {
            final notifier = ref.read(
              settings.provider(notificationsEnabledSettingDef).notifier,
            );
            if (v) {
              final ok = await ref
                  .read(notificationServiceProvider.notifier)
                  .initialize(context);
              notifier.set(ok);
              if (!ok && context.mounted) {
                context.showToast('notifications_unavailable'.tr());
              }
            } else {
              ref.read(notificationServiceProvider.notifier).unregisterToken();
              notifier.set(false);
            }
          },
        ),
      ),
    );
  }

  Widget _buildTelemetryToggle(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final enabled = ref.watch(
      settings.provider(telemetryEnabledSettingDef),
    );
    return Padding(
      padding: const EdgeInsets.only(top: ThemeConfig.spacingS),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: SwitchListTile(
          secondary: Icon(
            Icons.analytics_outlined,
            size: 24,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          title: Text(
            'telemetry_enabled'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          subtitle: Text(
            'telemetry_enabled_description'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          value: enabled,
          onChanged: (v) {
            ref
                .read(settings.provider(telemetryEnabledSettingDef).notifier)
                .set(v);
          },
        ),
      ),
    );
  }

  Widget _buildPermissionRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool granted,
    required Future<void> Function() onAllow,
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
          crossAxisAlignment: CrossAxisAlignment.center,
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
            if (granted)
              Semantics(
                label: '$title ${'onboarding_permission_allowed'.tr()}',
                child: FilledButton.tonal(
                  onPressed: null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Text('onboarding_permission_allowed'.tr()),
                    ],
                  ),
                ),
              )
            else
              Semantics(
                label: '$title ${'onboarding_permission_allow'.tr()}',
                child: FilledButton.tonal(
                  onPressed: () async => await onAllow(),
                  child: Text('onboarding_permission_allow'.tr()),
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

  static const List<String> _fontSizeOptions = [
    'small',
    'normal',
    'large',
    'extra_large',
  ];

  /// Predefined theme schemes only (no custom) for simpler onboarding.
  static final _onboardingThemeSchemeIds = flexSchemeOptionIds
      .where((id) => id != 'custom')
      .toList();

  List<Widget> _buildPreferencesTiles(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayCurrency = ref.watch(
      settings.provider(displayCurrencySettingDef),
    ).trim();
    final displayCurrencyLabel = displayCurrency.isEmpty
        ? 'display_currency_none'.tr()
        : (CurrencyHelpers.fromCode(displayCurrency) != null
            ? CurrencyHelpers.shortLabel(
                CurrencyHelpers.fromCode(displayCurrency)!)
            : displayCurrency);
    final use24h = ref.watch(
      settings.provider(use24HourFormatSettingDef),
    );
    final fontSize = ref.watch(
      settings.provider(fontSizeScaleSettingDef),
    );
    final themeScheme = ref.watch(
      settings.provider(themeSchemeSettingDef),
    );

    return [
      ListTile(
            leading: const Icon(Icons.visibility_outlined, size: 24),
            title: Text(
              'display_currency'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
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
                const SizedBox(height: 4),
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
                          .read(
                            settings.provider(displayCurrencySettingDef).notifier,
                          )
                          .set('');
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
                      .read(
                        settings.provider(displayCurrencySettingDef).notifier,
                      )
                      .set(currency.code);
                },
              );
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.schedule, size: 24),
            title: Text(
              'use_24_hour_format'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            subtitle: Text(
              'use_24_hour_format_description'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
            ),
            value: use24h,
            onChanged: (v) {
              ref
                  .read(
                    settings.provider(use24HourFormatSettingDef).notifier,
                  )
                  .set(v);
            },
          ),
          ListTile(
            leading: Icon(fontSizeScaleSettingDef.icon, size: 24),
            title: Text(
              'font_size'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
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
                const SizedBox(height: 4),
                Text(
                  fontSize.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
            onTap: () async {
              final chosen = await showResponsiveSheet<String>(
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
                          bottom: MediaQuery.of(ctx).padding.bottom + 16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _fontSizeOptions
                              .map(
                                (option) => ListTile(
                                  title: Text(option.tr()),
                                  onTap: () =>
                                      Navigator.of(ctx).pop(option),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              if (chosen != null && context.mounted) {
                ref
                    .read(
                      settings.provider(fontSizeScaleSettingDef).notifier,
                    )
                    .set(chosen);
              }
            },
          ),
          ListTile(
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
                  width: 1.5,
                ),
              ),
              child: primaryColorForSchemeId(themeScheme) == Colors.transparent
                  ? Icon(themeSchemeSettingDef.icon, size: 22)
                  : null,
            ),
            title: Text(
              'color_scheme'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
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
                const SizedBox(height: 4),
                Text(
                  'theme_scheme_$themeScheme'.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
            onTap: () async {
              final chosen = await showResponsiveSheet<String>(
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
                          bottom: MediaQuery.of(ctx).padding.bottom + 16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _onboardingThemeSchemeIds
                              .map(
                                (schemeId) {
                                  final chipColor =
                                      primaryColorForSchemeId(schemeId);
                                  return ListTile(
                                    leading: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: chipColor != Colors.transparent
                                            ? chipColor
                                            : Theme.of(ctx)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Theme.of(ctx)
                                              .colorScheme
                                              .outline,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      'theme_scheme_$schemeId'.tr(),
                                    ),
                                    onTap: () =>
                                        Navigator.of(ctx).pop(schemeId),
                                  );
                                },
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              if (chosen != null && context.mounted) {
                ref
                    .read(
                      settings.provider(themeSchemeSettingDef).notifier,
                    )
                    .set(chosen);
              }
            },
          ),
    ];
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
            // Auth completed, trigger sync so data is available when user lands on home
            await ref.read(dataSyncServiceProvider.notifier).syncNow();
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
