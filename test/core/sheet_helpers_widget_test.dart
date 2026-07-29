import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:hisab/core/widgets/sheet_helpers.dart';
import 'package:hisab/core/widgets/sheet_option_tile.dart';

import '../widget_test_helpers.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  void setPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  void setTabletViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildApp({
    required Future<void> Function(BuildContext context) onOpen,
    Locale locale = const Locale('en'),
  }) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (ctx) => FilledButton(
                onPressed: () => onOpen(ctx),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ],
    );
    return EasyLocalization(
      path: 'assets/translations',
      supportedLocales: testSupportedLocales,
      fallbackLocale: const Locale('en'),
      startLocale: locale,
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('showConfirmSheet phone shows title, content, and confirm', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      buildApp(
        onOpen: (ctx) => showConfirmSheet(
          ctx,
          title: 'Delete item',
          content: 'This cannot be undone.',
          confirmLabel: 'Delete',
          isDestructive: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Delete item'), findsWidgets);
    expect(find.text('This cannot be undone.'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('showConfirmSheet tablet uses Dialog chrome with close', (
    tester,
  ) async {
    setTabletViewport(tester);
    await tester.pumpWidget(
      buildApp(
        onOpen: (ctx) => showConfirmSheet(
          ctx,
          title: 'Confirm action',
          content: 'Proceed?',
          confirmLabel: 'OK',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('responsive_sheet_panel')),
      findsOneWidget,
    );
    expect(find.text('Confirm action'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('Proceed?'), findsOneWidget);
  });

  testWidgets('sheet morphs from centered dialog to bottom on shrink', (
    tester,
  ) async {
    setTabletViewport(tester);
    await tester.pumpWidget(
      buildApp(
        onOpen: (ctx) => showConfirmSheet(
          ctx,
          title: 'Resize me',
          content: 'Morph content',
          confirmLabel: 'OK',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsOneWidget);

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Morph content'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('showOptionPickerSheet uses SheetOptionTile rows', (tester) async {
    setPhoneViewport(tester);
    String? chosen;
    await tester.pumpWidget(
      buildApp(
        onOpen: (ctx) async {
          chosen = await showOptionPickerSheet<String>(
            ctx,
            title: 'Pick one',
            selected: 'a',
            options: const [
              SheetPickerOption(value: 'a', label: 'Option A'),
              SheetPickerOption(value: 'b', label: 'Option B'),
            ],
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(SheetOptionTile), findsNWidgets(2));
    expect(find.text('Option A'), findsOneWidget);
    await tester.tap(find.text('Option B'));
    await tester.pumpAndSettle();
    expect(chosen, 'b');
  });
}
