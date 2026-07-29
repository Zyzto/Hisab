import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/settings/pages/settings_page.dart';
import '../layout/layout_breakpoints.dart';
import '../motion/app_motion.dart';
import '../widgets/app_sidenav.dart';
import '../widgets/connection_banner.dart';
import '../widgets/floating_nav_bar.dart';
import '../widgets/pwa_install_banner.dart';
import '../widgets/toast.dart';
import 'route_paths.dart';
import 'shell_drawer_scope.dart';
import 'shell_nav_layout.dart';

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
  final GlobalKey<ScaffoldState> _shellScaffoldKey = GlobalKey<ScaffoldState>();
  final FocusNode _menuButtonFocusNode = FocusNode(
    debugLabel: 'shell_menu_button',
  );
  bool _desktopNavCollapsed = false;

  /// When true, tab index change snaps without crossfade (e.g. returning from
  /// profile/archived onto settings so home does not flash through).
  bool _snapTabIndex = false;

  bool _isHomePath(String path) {
    return path == RoutePaths.home ||
        path.startsWith('${RoutePaths.homeModeBase}/');
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
    _restoreDesktopNavCollapsed();
  }

  Future<void> _restoreDesktopNavCollapsed() async {
    final collapsed = await ShellNavLayout.loadDesktopNavCollapsed();
    if (!mounted || collapsed == _desktopNavCollapsed) return;
    setState(() => _desktopNavCollapsed = collapsed);
  }

  @override
  void dispose() {
    _menuButtonFocusNode.dispose();
    // Clear reserved width if this shell goes away.
    if (ShellNavLayout.reservedWidth.value != 0) {
      ShellNavLayout.reservedWidth.value = 0;
    }
    super.dispose();
  }

  void _toggleDesktopNavCollapsed() {
    final next = !_desktopNavCollapsed;
    setState(() => _desktopNavCollapsed = next);
    // Persist so collapse survives route changes, mid-band resize, and restarts.
    unawaited(ShellNavLayout.saveDesktopNavCollapsed(next));
  }

  /// Same [Drawer] body for mid (temporary) and desktop (permanent).
  ///
  /// Permanent uses a square shape so the M3 end-radius does not leave an
  /// opaque "mask" beside the curve; temporary keeps the themed drawer shape.
  Drawer _buildShellDrawer({
    required bool asTemporary,
    bool collapsed = false,
    VoidCallback? onToggleCompact,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Drawer(
      width: LayoutBreakpoints.shellNavWidth,
      backgroundColor: cs.surfaceContainerLow,
      elevation: asTemporary ? null : 0,
      shadowColor: asTemporary ? null : Colors.transparent,
      surfaceTintColor: asTemporary ? null : Colors.transparent,
      shape: asTemporary
          ? null
          : const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: asTemporary
          ? AppSidenav(
              asDrawer: true,
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: _onDestinationSelected,
            )
          : AppSidenav(
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              collapsed: collapsed,
              onToggleCompact: onToggleCompact,
            ),
    );
  }

  bool _isManagedBackPath(String currentPath) {
    final isAtSettings =
        currentPath == RoutePaths.settings ||
        currentPath.startsWith('${RoutePaths.settings}/');
    final isAtArchived = currentPath == RoutePaths.archivedGroups;
    final isAtProfile = currentPath == RoutePaths.profile;
    final isAtHome = _isHomePath(currentPath);
    return isAtSettings || isAtArchived || isAtProfile || isAtHome;
  }

  void _handleManagedBack(String currentPath) {
    final isAtSettings =
        currentPath == RoutePaths.settings ||
        currentPath.startsWith('${RoutePaths.settings}/');
    final isAtArchived = currentPath == RoutePaths.archivedGroups;
    final isAtProfile = currentPath == RoutePaths.profile;
    final isAtHome = _isHomePath(currentPath);
    if (isAtSettings || isAtArchived || isAtProfile) {
      context.go(RoutePaths.home);
      return;
    }
    if (isAtHome) {
      _onBackPressed();
    }
  }

  @override
  void didUpdateWidget(MainScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasMain = _isHomePath(oldWidget.location) ||
        oldWidget.location == RoutePaths.settings;
    final isMain = _isHomePath(widget.location) ||
        widget.location == RoutePaths.settings;
    if (!wasMain && isMain) {
      _snapTabIndex = true;
    }
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _currentIndex = widget.selectedIndex;
    }
  }

  bool _shouldShowNavBar() {
    return _isHomePath(widget.location) ||
        widget.location == RoutePaths.settings;
  }

  void _exitApp() {
    if (kIsWeb) {
      final router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop();
        return;
      }
    }
    SystemNavigator.pop();
  }

  void _onBackPressed() {
    final now = DateTime.now();
    if (_lastBackPressAt != null &&
        now.difference(_lastBackPressAt!) < _doubleBackExitWindow) {
      _exitApp();
      return;
    }
    setState(() => _lastBackPressAt = now);
    context.showToast('press_back_again_to_exit'.tr());
  }

  Widget _wrapWithBackHandler(Widget child) {
    final currentPath = GoRouter.of(
      context,
    ).routerDelegate.currentConfiguration.uri.path;
    final shouldIntercept = _isManagedBackPath(currentPath);
    return PopScope(
      canPop: !shouldIntercept,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final latestPath = GoRouter.of(
          context,
        ).routerDelegate.currentConfiguration.uri.path;
        if (_isManagedBackPath(latestPath)) {
          _handleManagedBack(latestPath);
        }
      },
      child: child,
    );
  }

  void _onDestinationSelected(int index) {
    HapticFeedback.lightImpact();
    final scaffold = _shellScaffoldKey.currentState;
    if (scaffold?.isDrawerOpen ?? false) {
      scaffold!.closeDrawer();
    }
    switch (index) {
      case 0:
        context.go(RoutePaths.home);
        break;
      case 1:
        context.go(RoutePaths.settings);
        break;
    }
  }

  void _syncReservedWidth({
    required bool showNavBar,
    required bool isDesktop,
  }) {
    final next = (showNavBar && isDesktop)
        ? (_desktopNavCollapsed
              ? LayoutBreakpoints.shellNavWidthCompact
              : LayoutBreakpoints.shellNavWidth)
        : 0.0;
    if (ShellNavLayout.reservedWidth.value != next) {
      // Defer notify so we don't setState during build of dependents.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ShellNavLayout.reservedWidth.value != next) {
          ShellNavLayout.reservedWidth.value = next;
        }
      });
    }
  }

  Widget _buildContentStack({required bool showNavBar}) {
    return Stack(
      children: [
        _buildMainContent(),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ConnectionBanner(),
        ),
        if (showNavBar && _currentIndex == 0)
          Positioned(
            left: 16,
            right: 16,
            bottom: LayoutBreakpoints.isTabletOrWider(context) ? 24 : 120,
            child: const PwaInstallBanner(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    context.locale;

    final showNavBar = _shouldShowNavBar();
    final isDesktop = LayoutBreakpoints.isDesktopOrWider(context);
    final isMid = LayoutBreakpoints.isMidBand(context);
    final useWideShell = showNavBar && (isDesktop || isMid);

    _syncReservedWidth(showNavBar: showNavBar, isDesktop: isDesktop);

    if (useWideShell) {
      // Same [Drawer] + [AppSidenav]:
      // - mid → temporary Scaffold.drawer (Material slide)
      // - desktop → permanent side drawer that stays up; collapse = icons-only
      final permanentWidth = isDesktop
          ? (_desktopNavCollapsed
                ? LayoutBreakpoints.shellNavWidthCompact
                : LayoutBreakpoints.shellNavWidth)
          : 0.0;

      final shellBody = Row(
        children: [
          if (isDesktop)
            ClipRect(
              child: AnimatedContainer(
                duration: AppMotion.shellNav,
                curve: Curves.fastOutSlowIn,
                width: permanentWidth,
                child: OverflowBox(
                  alignment: AlignmentDirectional.centerStart,
                  minWidth: LayoutBreakpoints.shellNavWidth,
                  maxWidth: LayoutBreakpoints.shellNavWidth,
                  child: _buildShellDrawer(
                    asTemporary: false,
                    collapsed: _desktopNavCollapsed,
                    onToggleCompact: _toggleDesktopNavCollapsed,
                  ),
                ),
              ),
            ),
          Expanded(
            child: ShellDrawerScope(
              openDrawer: () => _shellScaffoldKey.currentState?.openDrawer(),
              showMenuButton: isMid,
              menuButtonFocusNode: _menuButtonFocusNode,
              child: Scaffold(
                key: _shellScaffoldKey,
                onDrawerChanged: (opened) {
                  if (!opened &&
                      isMid &&
                      _menuButtonFocusNode.canRequestFocus) {
                    _menuButtonFocusNode.requestFocus();
                  }
                },
                drawer: isMid
                    ? _buildShellDrawer(asTemporary: true)
                    : null,
                body: _buildContentStack(showNavBar: showNavBar),
              ),
            ),
          ),
        ],
      );
      return _wrapWithBackHandler(shellBody);
    }

    // Mobile (or shell routes without nav chrome).
    final scaffold = Scaffold(
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
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.15,
                      ),
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
                onDestinationSelected: _onDestinationSelected,
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
    return _wrapWithBackHandler(scaffold);
  }

  Widget _buildMainContent() {
    final isMainPage = _isHomePath(widget.location) ||
        widget.location == RoutePaths.settings;

    final snap = _snapTabIndex;
    if (snap) {
      // Consumed this frame; avoid scheduling setState during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _snapTabIndex) {
          setState(() => _snapTabIndex = false);
        }
      });
    }

    // Always keep home/settings mounted so State survives profile/archived.
    // Tickers stay enabled under Offstage so an in-flight tab crossfade can
    // finish (disabling TickerMode when leaving main stranded _animating).
    final tabStack = _ShellTabCrossfade(
      index: _currentIndex,
      visible: isMainPage,
      snap: snap,
      children: [_homePage, _settingsPage],
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: !isMainPage,
          child: tabStack,
        ),
        if (!isMainPage) widget.child,
      ],
    );
  }
}

/// Crossfades between sibling shell tabs without disposing their State.
///
/// Inactive tabs are [Offstage] after the fade so finders / semantics match
/// [IndexedStack] (skip offstage). During the crossfade both stay onstage.
class _ShellTabCrossfade extends StatefulWidget {
  const _ShellTabCrossfade({
    required this.index,
    required this.visible,
    required this.snap,
    required this.children,
  });

  final int index;
  final bool visible;
  final bool snap;
  final List<Widget> children;

  @override
  State<_ShellTabCrossfade> createState() => _ShellTabCrossfadeState();
}

class _ShellTabCrossfadeState extends State<_ShellTabCrossfade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late int _shownIndex;
  int? _fromIndex;

  @override
  void initState() {
    super.initState();
    _shownIndex = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.shellTab,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _fromIndex = null;
            _shownIndex = widget.index;
            _controller.value = 0;
          });
        }
      });
  }

  @override
  void didUpdateWidget(_ShellTabCrossfade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.snap || !widget.visible) {
      _controller.stop();
      _fromIndex = null;
      _shownIndex = widget.index;
      _controller.value = 0;
      return;
    }
    if (oldWidget.index != widget.index) {
      _fromIndex = _shownIndex;
      _shownIndex = widget.index;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animating = _controller.isAnimating || _fromIndex != null;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              _buildTab(i, animating: animating),
          ],
        );
      },
    );
  }

  Widget _buildTab(int i, {required bool animating}) {
    final isTarget = i == widget.index;
    final isFrom = i == _fromIndex;
    double opacity;
    if (!animating || _fromIndex == null) {
      opacity = isTarget ? 1.0 : 0.0;
    } else if (isTarget) {
      opacity = AppMotion.enterCurve.transform(_controller.value);
    } else if (isFrom) {
      opacity = 1.0 - AppMotion.enterCurve.transform(_controller.value);
    } else {
      opacity = 0.0;
    }

    final show = isTarget || (animating && isFrom);
    return IgnorePointer(
      ignoring: !isTarget,
      child: Offstage(
        offstage: !show,
        child: TickerMode(
          enabled: show,
          child: Opacity(
            opacity: opacity,
            child: widget.children[i],
          ),
        ),
      ),
    );
  }
}
