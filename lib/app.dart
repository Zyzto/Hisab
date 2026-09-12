import 'dart:async';
import 'dart:ui' as ui;

import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safaeh/safaeh.dart';

import 'core/build_env.dart';
import 'core/celebration/celebration_host.dart';
import 'core/debug/debug_menu.dart';
import 'core/debug/integration_test_mode.dart';
import 'core/layout/layout_breakpoints.dart';
import 'core/motion/app_motion.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/app_scroll_behavior.dart';
import 'core/theme/theme_providers.dart';
import 'core/widgets/back_button_keyboard_dismiss.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  bool _debugFabVisible = true;
  bool _debugMenuOpen = false;
  GlobalKey<NavigatorState>? _debugMenuNavigatorKey;
  Offset? _debugFabPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BackButtonInterceptor.add(
      _handleDebugMenuBack,
      zIndex: 100,
      name: 'hisab_debug_menu',
    );
    _scheduleStartupKeyboardDismiss();
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_handleDebugMenuBack);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _handleDebugMenuBack(bool stopDefaultButtonEvent, RouteInfo info) {
    if (!_debugMenuOpen) return false;
    final navigator = _debugMenuNavigatorKey?.currentState;
    if (navigator == null) return true;
    navigator.pop();
    return true;
  }

  void _openDebugMenu(GlobalKey<NavigatorState> navigatorKey) {
    if (!mounted) return;
    setState(() {
      _debugFabVisible = false;
      _debugMenuOpen = true;
      _debugMenuNavigatorKey = navigatorKey;
    });
  }

  void _closeDebugMenu() {
    if (!mounted) return;
    setState(() {
      _debugFabVisible = true;
      _debugMenuOpen = false;
      _debugMenuNavigatorKey = null;
    });
  }

  void _moveDebugFab(Offset delta, Size viewport, bool isRtl) {
    const fabExtent = 40.0;
    const edgeMargin = 8.0;
    final defaultPosition = Offset(
      isRtl ? viewport.width - edgeMargin - fabExtent : edgeMargin,
      viewport.height - 96 - fabExtent,
    );
    final current = _debugFabPosition ?? defaultPosition;
    final maxLeft = (viewport.width - fabExtent - edgeMargin).clamp(
      edgeMargin,
      double.infinity,
    );
    final maxTop = (viewport.height - fabExtent - edgeMargin).clamp(
      edgeMargin,
      double.infinity,
    );
    final next = Offset(
      (current.dx + delta.dx).clamp(edgeMargin, maxLeft).toDouble(),
      (current.dy + delta.dy).clamp(edgeMargin, maxTop).toDouble(),
    );
    if (next != current) setState(() => _debugFabPosition = next);
  }

  void _scheduleStartupKeyboardDismiss() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _dismissKeyboard();
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _dismissKeyboard();
      });
    });
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
  }

  @override
  void reassemble() {
    super.reassemble();
    _dismissKeyboard();
  }

  Widget _buildDebugFab({
    required BuildContext context,
    required GoRouter router,
    required bool isDebug,
    required bool isRtl,
  }) {
    if (!isDebug || isIntegrationTestMode || !_debugFabVisible) {
      return const SizedBox.shrink();
    }
    const fabExtent = 40.0;
    const edgeMargin = 8.0;
    final viewport = MediaQuery.sizeOf(context);
    final maxLeft = (viewport.width - fabExtent - edgeMargin)
        .clamp(edgeMargin, double.infinity)
        .toDouble();
    final maxTop = (viewport.height - fabExtent - edgeMargin)
        .clamp(edgeMargin, double.infinity)
        .toDouble();
    final defaultPosition = Offset(
      isRtl ? viewport.width - edgeMargin - fabExtent : edgeMargin,
      viewport.height - 96 - fabExtent,
    );
    final position = _debugFabPosition ?? defaultPosition;
    return Positioned(
      left: position.dx.clamp(edgeMargin, maxLeft).toDouble(),
      top: position.dy.clamp(edgeMargin, maxTop).toDouble(),
      child: DebugMenuFab(
        navigatorKey: router.routerDelegate.navigatorKey,
        localeContext: context,
        onBeforeOpen: () => _openDebugMenu(router.routerDelegate.navigatorKey),
        whenSheetClosed: _closeDebugMenu,
        onDragDelta: (delta) => _moveDebugFab(delta, viewport, isRtl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themes = ref.watch(appThemesProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final suppressThemeLerp = ref.watch(suppressThemeLerpProvider);

    return SafaehTheme(
      data: const SafaehThemeData(
        tabletBreakpoint: LayoutBreakpoints.breakpointTablet,
        dialogMaxWidth: LayoutBreakpoints.sheetDialogMaxWidth,
        motion: AppMotion.modal,
        enterCurve: AppMotion.enterCurve,
        compactNavWidth: LayoutBreakpoints.shellNavWidthCompact,
        expandedNavWidth: LayoutBreakpoints.shellNavWidth,
        navMotion: AppMotion.shellNav,
        sheetRoll: AppMotion.sheetRoll,
        sheetRollEnter: AppMotion.sheetRollEnter,
        exitCurve: AppMotion.exitCurve,
        contentMaxWidth: LayoutBreakpoints.contentMaxWidthTablet,
        floatingAppearance: SafaehFloatingAppearance(
          style: SafaehFloatingSurfaceStyle.glass,
        ),
      ),
      child: CelebrationHost(
        child: MaterialApp.router(
          title: appNameTranslationKey.tr(),
          debugShowCheckedModeBanner: false,
          scrollBehavior: AppScrollBehavior(),
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          builder: (context, child) {
            final isRtl = context.locale.languageCode == 'ar';
            final isDebug = ref.watch(showDebugMenuProvider);
            final content = BackButtonKeyboardDismiss(
              child: GestureDetector(
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                behavior: HitTestBehavior.deferToChild,
                child: Directionality(
                  textDirection: isRtl
                      ? ui.TextDirection.rtl
                      : ui.TextDirection.ltr,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
            return Stack(
              children: [
                Positioned.fill(child: content),
                _buildDebugFab(
                  context: context,
                  router: router,
                  isDebug: isDebug,
                  isRtl: isRtl,
                ),
              ],
            );
          },
          theme: themes.light,
          darkTheme: themes.dark,
          themeMode: themeMode,
          themeAnimationDuration: suppressThemeLerp
              ? Duration.zero
              : kThemeAnimationDuration,
          routerConfig: router,
        ),
      ),
    );
  }
}
