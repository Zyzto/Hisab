import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab/core/widgets/async_value_builder.dart';
import '../widget_test_helpers.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('AsyncValueBuilder data renders content', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: AsyncValueBuilder<String>(
              value: const AsyncValue.data('hello'),
              data: (context, v) => Text(v),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('AsyncValueBuilder loading shows CircularProgressIndicator', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: AsyncValueBuilder<String>(
              value: const AsyncValue.loading(),
              data: (context, v) => Text(v),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AsyncValueBuilder error shows error UI', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: AsyncValueBuilder<String>(
              value: AsyncValue.error(Exception('fail'), StackTrace.current),
              data: (context, v) => Text(v),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('fail'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('AsyncValueBuilder empty with empty builder renders empty', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: AsyncValueBuilder<String?>(
              value: const AsyncValue.data(null),
              data: (context, v) => Text(v ?? ''),
              empty: (context) => const Text('empty'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('empty'), findsOneWidget);
  });

  testWidgets('AsyncValueBuilder data with empty string uses data builder', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: AsyncValueBuilder<String>(
              value: const AsyncValue.data(''),
              data: (context, v) => Text(v.isEmpty ? 'blank' : v),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('blank'), findsOneWidget);
  });

  testWidgets('AsyncValueBuilder error shows error UI with Arabic locale', (tester) async {
    await pumpApp(
      tester,
      child: AsyncValueBuilder<String>(
        value: AsyncValue.error(Exception('fail'), StackTrace.current),
        data: (context, v) => Text(v),
      ),
      locale: const Locale('ar'),
    );
    expect(find.textContaining('fail'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });
}
