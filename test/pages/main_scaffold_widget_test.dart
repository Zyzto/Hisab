// ignore_for_file: prefer_const_constructors

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisab/core/navigation/main_scaffold.dart';
import 'package:hisab/core/navigation/route_paths.dart';
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

  Future<void> pumpRouterApp(
    WidgetTester tester, {
    required GoRouter router,
  }) async {
    // Use narrow viewport so MainScaffold shows bottom nav (not rail).
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(() => tester.view.resetPhysicalSize());
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
    await tester.pump();
  }

  testWidgets('MainScaffold renders without error', (tester) async {
    final router = _buildRouter(RoutePaths.home);
    await pumpRouterApp(tester, router: router);
    expect(find.byType(MainScaffold), findsOneWidget);
    // Advance time so any timers (e.g. SyncStatusChip collapse) can complete before teardown
    await tester.pump(const Duration(seconds: 3));
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
