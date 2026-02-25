// ignore_for_file: prefer_const_constructors

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab/features/home/pages/home_page.dart';
import 'package:hisab/features/home/providers/home_list_provider.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('HomePage shows app bar and empty list', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderedGroupsForHomeProvider.overrideWith(
            (ref) => AsyncValue.data(const []),
          ),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: const [Locale('en')],
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(
            home: Scaffold(body: HomePage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byIcon(Icons.add), findsWidgets);
  });
}
