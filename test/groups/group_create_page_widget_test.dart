import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisab/features/groups/pages/group_create_page.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('group creation first step has no framework rendering errors', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/groups/create',
      routes: [
        GoRoute(
          path: '/groups/create',
          builder: (context, state) => const GroupCreatePage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: const [Locale('en'), Locale('ar')],
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
