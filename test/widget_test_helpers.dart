import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Supported locales for tests (matches app: en, ar).
const List<Locale> testSupportedLocales = [Locale('en'), Locale('ar')];

/// Pumps [child] inside EasyLocalization and MaterialApp.
/// [locale] defaults to English; use [Locale('ar')] to test Arabic/RTL.
/// Calls [pumpWidget] and, when [pumpAndSettle] is true, [pumpAndSettle].
/// For widgets that depend on Riverpod providers, build ProviderScope +
/// EasyLocalization + MaterialApp inline with overrides (see
/// balance_list_widget_test.dart, sync_status_chip_widget_test.dart).
Future<void> pumpApp(
  WidgetTester tester, {
  required Widget child,
  Locale locale = const Locale('en'),
  bool pumpAndSettle = true,
}) async {
  await tester.pumpWidget(
    EasyLocalization(
      path: 'assets/translations',
      supportedLocales: testSupportedLocales,
      fallbackLocale: const Locale('en'),
      startLocale: locale,
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    ),
  );
  if (pumpAndSettle) {
    await tester.pumpAndSettle();
  }
}
