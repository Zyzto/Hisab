import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/settings/pages/settings_page.dart';
import '../layout/layout_breakpoints.dart';
import '../widgets/connection_banner.dart';
import '../widgets/floating_nav_bar.dart';
import '../widgets/pwa_install_banner.dart';
import '../widgets/toast.dart';
import 'route_paths.dart';

class MainScaffold extends ConsumerStatefulWidget {
  final int selectedIndex;
  final String location;
  final Widget child;

  const MainScaffold({
    super.key,
    required this.selectedIndex,
    required this.location,
    required this.child,
  });

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;
  final _homePage = const HomePage();
  final _settingsPage = const SettingsPage();
  DateTime? _lastBackPressAt;
  static const _doubleBackExitWindow = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
    BackButtonInterceptor.add(_onBackInterceptor, context: context);
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_onBackInterceptor);
    super.dispose();
  }

  bool _onBackInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    if (info.ifRouteChanged(context)) return false;
    // Use the actual top route from GoRouter so we only intercept when the user
    // is really on home/settings, not when they are on group/expense (pushed on top).
    final currentPath = GoRouter.of(
      context,
    ).routerDelegate.currentConfiguration.uri.path;
    final isAtSettings =
        currentPath == RoutePaths.settings ||
        currentPath.startsWith('${RoutePaths.settings}/');
    final isAtHome = currentPath == RoutePaths.home;
    if (isAtSettings) {
      context.go(RoutePaths.home);
      return true;
    }
    if (isAtHome) {
      _onBackPressed(context);
      return true;
    }
    return false;
  }

  @override
  void didUpdateWidget(MainScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _currentIndex = widget.selectedIndex;
    }
  }

  bool _shouldShowNavBar() {
    return widget.location == RoutePaths.home ||
        widget.location == RoutePaths.settings;
  }

  void _onBackPressed(BuildContext context) {
    final now = DateTime.now();
    if (_lastBackPressAt != null &&
        now.difference(_lastBackPressAt!) < _doubleBackExitWindow) {
      SystemNavigator.pop();
      return;
    }
    setState(() => _lastBackPressAt = now);
    context.showToast('press_back_again_to_exit'.tr());
  }

  @override
  Widget build(BuildContext context) {
    // Access context.locale to register as a dependent of EasyLocalization's
    // InheritedWidget. This ensures the nav bar labels rebuild when locale changes.
    // Without this, .tr() uses the global singleton but the widget never rebuilds.
    context.locale;

    final showNavBar = _shouldShowNavBar();
    final useRail = LayoutBreakpoints.isTabletOrWider(context) && showNavBar;

    if (useRail) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: LayoutBreakpoints.isDesktopOrWider(context),
              minExtendedWidth: LayoutBreakpoints.navigationRailWidth,
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.group_outlined, size: 28),
                  selectedIcon: const Icon(Icons.group, size: 28),
                  label: Text('groups'.tr()),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.settings_outlined, size: 28),
                  selectedIcon: const Icon(Icons.settings, size: 28),
                  label: Text('settings'.tr()),
                ),
              ],
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: (index) {
                HapticFeedback.lightImpact();
                switch (index) {
                  case 0:
                    context.go(RoutePaths.home);
                    break;
                  case 1:
                    context.go(RoutePaths.settings);
                    break;
                }
              },
            ),
            // Main body: content area to the right of the rail (not full screen).
            // Any centering of content should be relative to this area.
            Expanded(
              child: Stack(
                children: [
                  _buildMainContent(),
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ConnectionBanner(),
                  ),
                  if (_currentIndex == 0)
                    const Positioned(
                      left: 16,
                      right: 16,
                      bottom: 24,
                      child: PwaInstallBanner(),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final theme = Theme.of(context);
                        return Text(
                          'v${snapshot.data!.version}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.15),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: showNavBar ? 100 : 0),
            child: _buildMainContent(),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ConnectionBanner(),
          ),
          if (showNavBar && _currentIndex == 0)
            const Positioned(
              left: 16,
              right: 16,
              bottom: 120,
              child: PwaInstallBanner(),
            ),
          if (showNavBar)
            Positioned(
              left: 0,
              right: 0,
              bottom: 85,
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final theme = Theme.of(context);
                  return Text(
                    'v${snapshot.data!.version}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  );
                },
              ),
            ),
          if (showNavBar)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: FloatingNavBar(
                selectedIndex: widget.selectedIndex,
                onDestinationSelected: (index) {
                  HapticFeedback.lightImpact();
                  switch (index) {
                    case 0:
                      context.go(RoutePaths.home);
                      break;
                    case 1:
                      context.go(RoutePaths.settings);
                      break;
                  }
                },
                destinations: [
                  FloatingNavDestination(
                    icon: Icons.group_outlined,
                    selectedIcon: Icons.group,
                    label: 'groups'.tr(),
                  ),
                  FloatingNavDestination(
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    label: 'settings'.tr(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final isMainPage =
        widget.location == RoutePaths.home ||
        widget.location == RoutePaths.settings;

    if (isMainPage) {
      return IndexedStack(
        index: _currentIndex,
        children: [_homePage, _settingsPage],
      );
    }
    return widget.child;
  }
}
