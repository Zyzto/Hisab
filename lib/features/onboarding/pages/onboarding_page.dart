import 'dart:async';

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
import '../../../core/widgets/toast.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../core/layout/constrained_content.dart';
import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/theme/theme_config.dart';
import '../../settings/providers/settings_framework_providers.dart';
import '../../settings/settings_definitions.dart';
import '../widgets/onboarding_connect_page.dart';
import '../widgets/onboarding_permissions_page.dart';
import '../widgets/onboarding_preferences_page.dart';
import '../widgets/onboarding_welcome_page.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key, this.forceBusyForTest = false});

  final bool forceBusyForTest;

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _languagePulseController;

  static const List<Locale> _supportedLocales = [Locale('en'), Locale('ar')];
  static const List<String> _hintLanguageInLocales = [
    'You can change language from here',
    'تقدر تغيّر اللغة من هنا',
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

  static const int _lastPageIndex = 3;
  int _currentPage = 0;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _isCompleting = widget.forceBusyForTest;
    _pageController = PageController(initialPage: 0);
    _languagePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _languagePulseStopTimer = Timer(const Duration(milliseconds: 6000), () {
      if (mounted) {
        _languagePulseController.stop();
        setState(() => _languagePulseStopped = true);
      }
    });
    _languageTapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _hintTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(() {
          _hintLocaleIndex =
              (_hintLocaleIndex + 1) % _hintLanguageInLocales.length;
        });
      }
    });
    _themeDemoTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (mounted && _themeDemoRunning) {
        setState(() {
          _themeDemoIndex = (_themeDemoIndex + 1) % _themeDemoOrder.length;
        });
      }
    });
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
    final notification =
        await PermissionService.isNotificationPermissionGranted();
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

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    final onlineAvailable = supabaseConfigAvailable;

    if (settings == null) {
      return Scaffold(body: Center(child: Text('settings_unavailable'.tr())));
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: AbsorbPointer(
              absorbing: _isCompleting,
              child: ConstrainedContent(
                child: Column(
                  children: [
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: _isCompleting
                            ? const NeverScrollableScrollPhysics()
                            : null,
                        onPageChanged: (i) {
                          setState(() {
                            _currentPage = i;
                            if (i == 2 && _permissionStatusFuture == null) {
                              _permissionStatusFuture = _loadPermissionStatus();
                            }
                          });
                        },
                        children: [
                          const RepaintBoundary(child: OnboardingWelcomePage()),
                          const RepaintBoundary(
                            child: OnboardingPreferencesPage(),
                          ),
                          RepaintBoundary(
                            child: OnboardingPermissionsPage(
                              settings: settings,
                              onlineAvailable: onlineAvailable,
                              cameraGranted: _cameraGranted,
                              notificationGranted: _notificationGranted,
                              permissionStatusFuture: _permissionStatusFuture,
                              onRequestCamera: () async {
                                final result =
                                    await PermissionService.requestCameraPermission(
                                      context,
                                    );
                                if (mounted) {
                                  setState(() => _cameraGranted = result);
                                }
                              },
                              onRequestNotification: () async {
                                final result =
                                    await PermissionService.requestNotificationPermission(
                                      context,
                                    );
                                if (mounted) {
                                  setState(() => _notificationGranted = result);
                                }
                              },
                            ),
                          ),
                          RepaintBoundary(
                            child: OnboardingConnectPage(
                              settings: settings,
                              onlineAvailable: onlineAvailable,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildPageIndicator(context),
                    _buildNavigationBar(context, colorScheme, settings),
                  ],
                ),
              ),
            ),
          ),
          if (_isCompleting)
            Positioned.fill(
              child: ColoredBox(
                color: colorScheme.scrim.withValues(alpha: 0.24),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ThemeConfig.spacingL,
                      vertical: ThemeConfig.spacingM,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(ThemeConfig.radiusM),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: ThemeConfig.spacingM),
                        Text(
                          'services_status_loading'.tr(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
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
            duration: ThemeConfig.animationShort,
            margin: const EdgeInsets.symmetric(
              horizontal: ThemeConfig.spacingXS,
            ),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ThemeConfig.radiusS),
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
                onTap: _isCompleting
                    ? null
                    : () async {
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
                                    bottom:
                                        MediaQuery.of(ctx).padding.bottom +
                                        ThemeConfig.spacingM,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!LayoutBreakpoints.isTabletOrWider(
                                        context,
                                      ))
                                        Padding(
                                          padding: const EdgeInsets.all(
                                            ThemeConfig.spacingM,
                                          ),
                                          child: Text(
                                            'language'.tr(),
                                            style: Theme.of(
                                              ctx,
                                            ).textTheme.titleMedium,
                                          ),
                                        ),
                                      ..._supportedLocales.map(
                                        (locale) => ListTile(
                                          title: Text(
                                            _localeDisplayName(locale),
                                          ),
                                          onTap: () =>
                                              Navigator.of(ctx).pop(locale),
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
                              .read(
                                settings.provider(languageSettingDef).notifier,
                              )
                              .set(chosen.languageCode);
                          Log.info(
                            'Setting changed: ${languageSettingDef.key}=${chosen.languageCode}',
                          );
                        }
                      },
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(ThemeConfig.spacingS),
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

  static const Color _themeLightBg = Color(0xFFF5E6C8);
  static const Color _themeDarkBg = Color(0xFF37474F);
  static const Color _themeAmoledBg = Color(0xFF000000);
  static const Color _themeLightIcon = Color(0xFF5D4037);
  static const Color _themeDarkIcon = Color(0xFFECEFF1);

  static IconData _themeIcon(String theme) {
    switch (theme) {
      case 'system':
        return Icons.motion_photos_auto;
      case 'light':
        return Icons.light_mode;
      case 'dark':
        return Icons.dark_mode;
      case 'amoled':
        return Symbols.ev_shadow;
      default:
        return Icons.brightness_auto;
    }
  }

  Widget _buildThemeButton(
    BuildContext context,
    WidgetRef ref,
    SettingsProviders settings,
  ) {
    final currentTheme = ref.watch(settings.provider(themeModeSettingDef));
    final colorScheme = Theme.of(context).colorScheme;
    final displayTheme = _themeDemoRunning
        ? _themeDemoOrder[_themeDemoIndex]
        : currentTheme;
    final tooltip = '${'theme'.tr()}: ${currentTheme.tr()}';
    final iconColor = displayTheme == 'light'
        ? _themeLightIcon
        : (displayTheme == 'system' ? colorScheme.onSurface : _themeDarkIcon);
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
              onTap: _isCompleting
                  ? null
                  : () {
                      if (_themeDemoRunning) {
                        _themeDemoTimer?.cancel();
                        _themeDemoTimer = null;
                        setState(() => _themeDemoRunning = false);
                      }
                      const order = ['light', 'dark', 'system', 'amoled'];
                      final idx = order.indexOf(currentTheme);
                      final next = order[(idx + 1) % order.length];
                      ref
                          .read(settings.provider(themeModeSettingDef).notifier)
                          .set(next);
                      Log.info(
                        'Setting changed: ${themeModeSettingDef.key}=$next',
                      );
                    },
              customBorder: const CircleBorder(),
              child: AnimatedContainer(
                duration: ThemeConfig.animationLong,
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(ThemeConfig.spacingS),
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
                  duration: ThemeConfig.animationLong,
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
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
                              onPressed: _isCompleting
                                  ? null
                                  : () {
                                      _pageController.previousPage(
                                        duration: ThemeConfig.animationMedium,
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
                              onPressed: _isCompleting
                                  ? null
                                  : () {
                                      _pageController.nextPage(
                                        duration: ThemeConfig.animationMedium,
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
                              onPressed: _isCompleting
                                  ? null
                                  : () async => await _completeOnboarding(
                                      ref,
                                      settings,
                                    ),
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
              duration: ThemeConfig.animationMedium,
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

  Future<void> _completeOnboarding(
    WidgetRef ref,
    SettingsProviders settings,
  ) async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    final isLocalOnly = ref.read(settings.provider(localOnlySettingDef));
    final onlineAvailable = supabaseConfigAvailable;

    try {
      if (!isLocalOnly && onlineAvailable) {
        final authService = ref.read(authServiceProvider);
        if (!authService.isAuthenticated) {
          if (!mounted) return;
          final result = await showSignInSheet(context, ref);
          switch (result) {
            case SignInResult.success:
              await ref.read(dataSyncServiceProvider.notifier).syncNow();
              break;
            case SignInResult.pendingRedirect:
              ref
                  .read(
                    settings
                        .provider(onboardingOnlinePendingSettingDef)
                        .notifier,
                  )
                  .set(true);
              Log.info(
                'Setting changed: ${onboardingOnlinePendingSettingDef.key}=true',
              );
              return;
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
      Log.info('Setting changed: ${onboardingCompletedSettingDef.key}=true');
      if (!mounted) return;
      final pendingToken = ref.read(
        settings.provider(pendingInviteTokenSettingDef),
      );
      if (pendingToken.isNotEmpty) {
        ref
            .read(settings.provider(pendingInviteTokenSettingDef).notifier)
            .set('');
        Log.info(
          'Setting changed: ${pendingInviteTokenSettingDef.key}=(cleared)',
        );
        context.go(RoutePaths.inviteAccept(pendingToken));
      } else {
        context.go(RoutePaths.home);
      }
    } finally {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
    }
  }
}
