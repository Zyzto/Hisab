// ignore_for_file: prefer_const_constructors

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisab/core/navigation/main_scaffold.dart';
import 'package:hisab/core/navigation/route_paths.dart';
import 'package:hisab/core/navigation/shell_nav_layout.dart';
import 'package:hisab/core/widgets/app_sidenav.dart';
import 'package:hisab/core/widgets/floating_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

GoRouter _buildRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: RoutePaths.home,
        builder: (context, state) => MainScaffold(
          selectedIndex: 0,
          location: state.uri.path,
          child: const Center(child: Text('Home child')),
        ),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (context, state) => MainScaffold(
          selectedIndex: 1,
          location: state.uri.path,
          child: const Center(child: Text('Settings child')),
        ),
      ),
      GoRoute(
        path: '${RoutePaths.homeModeBase}/:mode',
        builder: (context, state) => MainScaffold(
          selectedIndex: 0,
          location: state.uri.path,
          child: const Center(child: Text('Home mode child')),
        ),
      ),
      GoRoute(
        path: RoutePaths.archivedGroups,
        builder: (context, state) => MainScaffold(
          selectedIndex: 0,
          location: state.uri.path,
          child: const Center(child: Text('Archived child')),
        ),
      ),
    ],
  );
}

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpRouterApp(
    WidgetTester tester, {
    required GoRouter router,
    Size size = const Size(400, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: const [Locale('en')],
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: ToastificationWrapper(
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('MainScaffold renders without error', (tester) async {
    final router = _buildRouter(RoutePaths.home);
    await pumpRouterApp(tester, router: router);
    expect(find.byType(MainScaffold), findsOneWidget);
    // Advance time so any timers (e.g. SyncStatusChip collapse) can complete before teardown
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Phone shows floating bottom nav', (tester) async {
    final router = _buildRouter(RoutePaths.home);
    await pumpRouterApp(tester, router: router, size: const Size(400, 800));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(FloatingNavBar), findsOneWidget);
    expect(find.byType(AppSidenav), findsNothing);
    expect(find.byKey(const ValueKey('shell_menu_button')), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Mid band shows hamburger and opens temporary drawer', (
    tester,
  ) async {
    final router = _buildRouter(RoutePaths.home);
    await pumpRouterApp(tester, router: router, size: const Size(700, 800));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(FloatingNavBar), findsNothing);
    expect(find.byType(AppSidenav), findsNothing);
    expect(find.byType(Drawer), findsNothing);
    expect(find.byKey(const ValueKey('shell_menu_button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('shell_menu_button')));
    await tester.pumpAndSettle();

    expect(find.byType(AppSidenav), findsOneWidget);
    expect(find.byType(Drawer), findsOneWidget);
    expect(find.byIcon(Icons.group), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Desktop shows permanent drawer without menu button', (
    tester,
  ) async {
    final router = _buildRouter(RoutePaths.home);
    await pumpRouterApp(tester, router: router, size: const Size(1000, 800));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(FloatingNavBar), findsNothing);
    expect(find.byType(AppSidenav), findsOneWidget);
    expect(find.byType(Drawer), findsOneWidget);
    expect(find.byKey(const ValueKey('shell_menu_button')), findsNothing);
    expect(find.byIcon(Icons.group), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byKey(const ValueKey('shell_nav_collapse')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Desktop sidenav collapses to icons-only and stays docked', (
    tester,
  ) async {
    final router = _buildRouter(RoutePaths.home);
    await pumpRouterApp(tester, router: router, size: const Size(1000, 800));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byKey(const ValueKey('shell_nav_collapse')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('shell_menu_button')), findsNothing);
    expect(find.byKey(const ValueKey('shell_nav_expand')), findsOneWidget);
    expect(find.byKey(const ValueKey('shell_nav_collapse')), findsNothing);
    expect(find.byType(AppSidenav), findsOneWidget);
    expect(find.byType(Drawer), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Desktop sidenav collapse preference is restored', (tester) async {
    SharedPreferences.setMockInitialValues({
      ShellNavLayout.desktopNavCollapsedKey: true,
    });
    final router = _buildRouter(RoutePaths.home);
    await pumpRouterApp(tester, router: router, size: const Size(1000, 800));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('shell_nav_expand')), findsOneWidget);
    expect(find.byKey(const ValueKey('shell_nav_collapse')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Back on settings navigates to home', (tester) async {
    final router = _buildRouter(RoutePaths.settings);
    await pumpRouterApp(tester, router: router);

    expect(router.routerDelegate.currentConfiguration.uri.path, RoutePaths.settings);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, RoutePaths.home);
  });

  testWidgets('Back on /home mode path shows home back behavior', (tester) async {
    final router = _buildRouter('${RoutePaths.homeModeBase}/combined');
    await pumpRouterApp(tester, router: router);

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '${RoutePaths.homeModeBase}/combined',
    );

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '${RoutePaths.homeModeBase}/combined',
    );
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Back on home shows warning toast', (tester) async {
    final router = _buildRouter(RoutePaths.home);
    await pumpRouterApp(tester, router: router);

    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.binding.handlePopRoute();
    await tester.pump();

    final popCalls = calls.where((call) => call.method == 'SystemNavigator.pop');
    expect(popCalls.length, 0);
    expect(router.routerDelegate.currentConfiguration.uri.path, RoutePaths.home);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Double back on home requests app exit', (tester) async {
    final router = _buildRouter(RoutePaths.home);
    await pumpRouterApp(tester, router: router);

    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();

    final popCalls = calls.where((call) => call.method == 'SystemNavigator.pop');
    expect(popCalls.length, 1);
    await tester.pump(const Duration(seconds: 5));
  });
}
