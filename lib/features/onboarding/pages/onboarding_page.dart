import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/sign_in_sheet.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/debug/integration_test_mode.dart';
import '../../../core/widgets/toast.dart';
import 'package:hisab_backend/hisab_backend.dart';
import '../../../core/layout/constrained_content.dart';
import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/motion/app_motion.dart';
import '../../../core/navigation/decorative_route.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/platform/ui_perf.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/theme/accent_style.dart';
import '../../../core/theme/theme_config.dart';
import '../../../core/widgets/sheet_helpers.dart';
import 'package:hisab/core/settings/providers/settings_framework_providers.dart';
import 'package:hisab/core/settings/settings_definitions.dart';
import '../widgets/onboarding_connect_page.dart';
import '../widgets/onboarding_permissions_page.dart';
import '../widgets/onboarding_preferences_page.dart';
import '../widgets/onboarding_shared.dart';
import '../widgets/onboarding_sky_backdrop.dart';
import '../widgets/onboarding_welcome_page.dart';

/// Maps an onboarding location path to a step index, or null if unmatched.
@visibleForTesting
int? onboardingStepFromPath(String path) {
  if (path == RoutePaths.onboardingWelcome) return 0;
  if (path == RoutePaths.onboardingPreferences) return 1;
  if (path == RoutePaths.onboardingPermissions) return 2;
  if (path == RoutePaths.onboardingConnect) return 3;
  return null;
}

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({
    super.key,
    this.forceBusyForTest = false,
    this.initialPage = 0,
  });

  final bool forceBusyForTest;
  final int initialPage;

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final PageController _pageController;
  late final AnimationController _languagePulseController;

  static const List<Locale> _supportedLocales = [Locale('en'), Locale('ar')];
  static const List<String> _hintLanguageKeys = [
    'onboarding_language_hint_en',
    'onboarding_language_hint_ar',
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

  String _routeForPage(int page) {
    switch (page) {
      case 1:
        return RoutePaths.onboardingPreferences;
      case 2:
        return RoutePaths.onboardingPermissions;
      case 3:
        return RoutePaths.onboardingConnect;
      case 0:
      default:
        return RoutePaths.onboardingWelcome;
    }
  }

  /// Updates the address bar to match the wizard step without [context.go],
  /// so this [State] (PageView, timers, etc.) is not disposed mid-flow.
  void _syncDecorativeUrlToPage(int page) {
    syncDecorativeRoutePath(context, _routeForPage(page));
  }

  void _ensurePermissionStatusLoaded() {
    if (_currentPage == 2 && _permissionStatusFuture == null) {
      _permissionStatusFuture = _loadPermissionStatus();
    }
  }

  Duration get _pageAnimDuration =>
      UiPerf.preferInstantShellTabs ? Duration.zero : AppMotion.page;

  void _goToPage(int page) {
    if (_pageAnimDuration == Duration.zero) {
      _pageController.jumpToPage(page);
    } else {
      _pageController.animateToPage(
        page,
        duration: _pageAnimDuration,
        curve: AppMotion.enterCurve,
      );
    }
  }

  void _stopChromeDemos() {
    _hintTimer?.cancel();
    _hintTimer = null;
    _themeDemoTimer?.cancel();
    _themeDemoTimer = null;
    _languagePulseStopTimer?.cancel();
    _languagePulseStopTimer = null;
    if (_languagePulseController.isAnimating) {
      _languagePulseController.stop();
    }
    _languagePulseStopped = true;
    _themeDemoRunning = false;
  }

  void _pauseChromeTimers() {
    _hintTimer?.cancel();
    _hintTimer = null;
    _themeDemoTimer?.cancel();
    _themeDemoTimer = null;
    if (_languagePulseController.isAnimating) {
      _languagePulseController.stop();
    }
  }

  void _resumeChromeTimersIfNeeded() {
    if (_isCompleting || UiPerf.preferReducedChromeMotion) return;
    if (!_languagePulseStopped && !_languagePulseController.isAnimating) {
      _languagePulseController.repeat();
    }
    _hintTimer ??= Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && !_isCompleting) {
        setState(() {
          _hintLocaleIndex = (_hintLocaleIndex + 1) % _hintLanguageKeys.length;
        });
      }
    });
    if (_themeDemoRunning) {
      _themeDemoTimer ??= Timer.periodic(const Duration(milliseconds: 2500), (
        _,
      ) {
        if (mounted && _themeDemoRunning && !_isCompleting) {
          setState(() {
            _themeDemoIndex = (_themeDemoIndex + 1) % _themeDemoOrder.length;
          });
        }
      });
    }
  }

  int _resolveInitialPage() {
    final browserPath = webVisibleAppRoutePath();
    if (browserPath != null) {
      final fromPath = onboardingStepFromPath(browserPath);
      if (fromPath != null) return fromPath.clamp(0, _lastPageIndex);
    }
    return widget.initialPage.clamp(0, _lastPageIndex);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isCompleting = widget.forceBusyForTest;
    _currentPage = _resolveInitialPage();
    _pageController = PageController(initialPage: _currentPage);
    // Deep-link / cold start on Permissions never fires [onPageChanged].
    _ensurePermissionStatusLoaded();
    _languagePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _languageTapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    // Integration/widget tests use pumpAndSettle; skip looping chrome/timers.
    // Release web minifies binding type names — prefer [isIntegrationTestMode].
    final underTestBinding =
        isIntegrationTestMode ||
        WidgetsBinding.instance.runtimeType.toString().contains(
          'TestWidgetsFlutterBinding',
        );
    final reduceChrome = UiPerf.preferReducedChromeMotion || underTestBinding;
    if (reduceChrome) {
      _languagePulseStopped = true;
      _themeDemoRunning = false;
    } else {
      _languagePulseController.repeat();
      _languagePulseStopTimer = Timer(const Duration(milliseconds: 6000), () {
        if (mounted) {
          _languagePulseController.stop();
          setState(() => _languagePulseStopped = true);
        }
      });
      _hintTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (mounted && !_isCompleting) {
          setState(() {
            _hintLocaleIndex =
                (_hintLocaleIndex + 1) % _hintLanguageKeys.length;
          });
        }
      });
      _themeDemoTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
        if (mounted && _themeDemoRunning && !_isCompleting) {
          setState(() {
            _themeDemoIndex = (_themeDemoIndex + 1) % _themeDemoOrder.length;
          });
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncDecorativeUrlToPage(_currentPage);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeChromeTimersIfNeeded();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pauseChromeTimers();
    }
  }

  @override
  void didUpdateWidget(covariant OnboardingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPage != widget.initialPage &&
        widget.initialPage != _currentPage) {
      _currentPage = widget.initialPage;
      _ensurePermissionStatusLoaded();
      _pageController.jumpToPage(widget.initialPage);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
        return 'language_name_ar'.tr();
      case 'en':
      default:
        return 'language_name_en'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(hisabSettingsProvidersProvider);
    final onlineAvailable = cloudAvailable;

    if (settings == null) {
      return Scaffold(body: Center(child: Text('settings_unavailable'.tr())));
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      // Keep theme scaffold fill under transparent grass/nav so parent
      // routes can't flash white through the meadow.
      // expand: in widget tests the sky is a zero-size shrink, and every
      // other child is Positioned — without expand the stack collapses to 0.
      body: Stack(
        fit: StackFit.expand,
        children: [
          const OnboardingSkyBackdrop(),
          // Steps fill under the footer so list rows can peek through the
          // soft wash (scroll affordance without a chevron). Column+Expanded
          // keeps [ConstrainedContent]'s tablet Row height-bounded.
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: AbsorbPointer(
                absorbing: _isCompleting,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ConstrainedContent(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: 4,
                          physics: _isCompleting
                              ? const NeverScrollableScrollPhysics()
                              : null,
                          onPageChanged: (i) {
                            setState(() {
                              _currentPage = i;
                              _ensurePermissionStatusLoaded();
                            });
                            _syncDecorativeUrlToPage(i);
                          },
                          itemBuilder: (context, index) {
                            return _KeepAliveOnboardingStep(
                              child: RepaintBoundary(
                                child: switch (index) {
                                  0 => const OnboardingWelcomePage(),
                                  1 => const OnboardingPreferencesPage(),
                                  2 => OnboardingPermissionsPage(
                                    settings: settings,
                                    onlineAvailable: onlineAvailable,
                                    cameraGranted: _cameraGranted,
                                    notificationGranted: _notificationGranted,
                                    permissionStatusFuture:
                                        _permissionStatusFuture,
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
                                        setState(
                                          () => _notificationGranted = result,
                                        );
                                      }
                                    },
                                  ),
                                  _ => OnboardingConnectPage(
                                    settings: settings,
                                    onlineAvailable: onlineAvailable,
                                  ),
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Full-bleed to the physical bottom so the home-indicator gap
          // never shows a clear triangle of meadow under the scrim.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AbsorbPointer(
              absorbing: _isCompleting,
              child: _buildFooter(context, colorScheme, settings),
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
                    decoration: AccentSurfaces.flatPanel(colorScheme),
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

  /// Step dots + nav row, washed over the grass band so their labels stay
  /// readable.
  ///
  /// Layout (bottom → top):
  /// - chrome band + home-indicator inset (hit-testable)
  /// - soft fade extension above it ([kOnboardingFooterFadeExtension]),
  ///   non-hit-testable so the step list can scroll/show through
  ///
  /// The scrim is full-bleed to the screen bottom; chrome stays content-width.
  Widget _buildFooter(
    BuildContext context,
    ColorScheme colorScheme,
    SettingsProviders settings,
  ) {
    final surface = colorScheme.surface;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IgnorePointer(
          child: SizedBox(
            height: kOnboardingFooterFadeExtension,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    surface.withValues(alpha: 0),
                    surface.withValues(alpha: 0.40),
                  ],
                ),
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                surface.withValues(alpha: 0.40),
                surface.withValues(alpha: 0.88),
                surface.withValues(alpha: 0.97),
              ],
              stops: const [0.0, 0.42, 1.0],
            ),
          ),
          child: Padding(
            // Paint under the OS home indicator so no meadow triangle leaks.
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: LayoutBreakpoints.contentMaxWidth(context),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPageIndicator(context),
                    _buildNavigationBar(context, colorScheme, settings),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
            duration: UiPerf.preferInstantShellTabs
                ? Duration.zero
                : ThemeConfig.animationShort,
            curve: AppMotion.enterCurve,
            margin: const EdgeInsets.symmetric(
              horizontal: ThemeConfig.spacingXS,
            ),
            width: isActive ? 28 : 8,
            height: isActive ? 8 : 7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ThemeConfig.radiusS),
              color: isActive
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.7),
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
                        final chosen = await showOptionPickerSheet<Locale>(
                          context,
                          title: 'language'.tr(),
                          selected: context.locale,
                          options: [
                            for (final locale in _supportedLocales)
                              SheetPickerOption(
                                value: locale,
                                label: _localeDisplayName(locale),
                              ),
                          ],
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
        return Icons.contrast;
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
                duration: UiPerf.preferReducedChromeMotion
                    ? Duration.zero
                    : ThemeConfig.animationLong,
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
                  duration: UiPerf.preferReducedChromeMotion
                      ? Duration.zero
                      : ThemeConfig.animationLong,
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        if (UiPerf.preferFadeOnlyPageTransitions) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        }
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
    // Transparent so the meadow parallax shows through under chrome.
    return Container(
      padding: const EdgeInsets.all(ThemeConfig.spacingM),
      color: Colors.transparent,
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
                                  : () => _goToPage(_currentPage - 1),
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
                                  : () => _goToPage(_currentPage + 1),
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
              duration: UiPerf.preferReducedChromeMotion
                  ? Duration.zero
                  : ThemeConfig.animationMedium,
              child: Text(
                _hintLanguageKeys[_hintLocaleIndex].tr(),
                key: ValueKey<int>(_hintLocaleIndex),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                  letterSpacing: 0.1,
                  height: 1.35,
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
    _stopChromeDemos();
    setState(() => _isCompleting = true);

    final onlineAvailable = cloudAvailable;
    var isLocalOnly = ref.read(settings.provider(localOnlySettingDef));
    // Online unavailable: never leave the user in a "online" local_only=false state.
    if (!onlineAvailable && !isLocalOnly) {
      ref.read(settings.provider(localOnlySettingDef).notifier).set(true);
      isLocalOnly = true;
      Log.info('Setting changed: ${localOnlySettingDef.key}=true');
    }

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
            case SignInResult.pendingEmailLink:
              ref
                  .read(
                    settings
                        .provider(onboardingOnlinePendingSettingDef)
                        .notifier,
                  )
                  .set(true);
              Log.info(
                'Setting changed: ${onboardingOnlinePendingSettingDef.key}=true '
                '(${result.name})',
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
        // Keep pending_invite_auto_join so InviteAcceptPage joins then opens group.
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
        _resumeChromeTimersIfNeeded();
      }
    }
  }
}

/// Keeps a visited onboarding step alive after first build (scroll/form state).
class _KeepAliveOnboardingStep extends StatefulWidget {
  const _KeepAliveOnboardingStep({required this.child});

  final Widget child;

  @override
  State<_KeepAliveOnboardingStep> createState() =>
      _KeepAliveOnboardingStepState();
}

class _KeepAliveOnboardingStepState extends State<_KeepAliveOnboardingStep>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
