// ignore_for_file: prefer_const_constructors

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisab/core/navigation/main_scaffold.dart';
import 'package:hisab/core/navigation/route_paths.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('MainScaffold renders without error', (tester) async {
    final router = GoRouter(
      initialLocation: RoutePaths.home,
      routes: [
        GoRoute(
          path: RoutePaths.home,
          builder: (context, state) => MainScaffold(
            selectedIndex: 0,
            location: RoutePaths.home,
            child: const Center(child: Text('Child')),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: const [Locale('en')],
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(MainScaffold), findsOneWidget);
    // Advance time so any timers (e.g. SyncStatusChip collapse) can complete before teardown
    await tester.pump(const Duration(seconds: 3));
  });
}
