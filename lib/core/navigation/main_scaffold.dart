import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/settings/pages/settings_page.dart';
import '../widgets/connection_banner.dart';
import '../widgets/floating_nav_bar.dart';
import '../widgets/pwa_install_banner.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('press_back_again_to_exit'.tr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Access context.locale to register as a dependent of EasyLocalization's
    // InheritedWidget. This ensures the nav bar labels rebuild when locale changes.
    // Without this, .tr() uses the global singleton but the widget never rebuilds.
    context.locale;

    final showNavBar = _shouldShowNavBar();
    final isHome = widget.location == RoutePaths.home;

    Widget scaffold = Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: showNavBar ? 100 : 0),
            child: _buildMainContent(),
          ),
          // Connection banner — slides down when offline, auto-dismisses on reconnect
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ConnectionBanner(),
          ),
          // PWA install banner — only on home tab for mobile web users
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
                  return Text(
                    'v${snapshot.data!.version}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.15),
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

    if (isHome) {
      scaffold = PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _onBackPressed(context);
        },
        child: scaffold,
      );
    }

    return scaffold;
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
