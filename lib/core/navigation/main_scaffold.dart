import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/settings/pages/settings_page.dart';
import '../widgets/floating_nav_bar.dart';
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

  @override
  Widget build(BuildContext context) {
    final showNavBar = _shouldShowNavBar();

    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: showNavBar ? 100 : 0),
            child: _buildMainContent(),
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
