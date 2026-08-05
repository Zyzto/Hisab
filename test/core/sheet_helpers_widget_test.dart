import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:hisab/core/layout/responsive_sheet.dart';
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

  testWidgets(
    'showOptionPickerSheet supports subtitle, disabled, and header',
    (tester) async {
      setPhoneViewport(tester);
      String? chosen;
      await tester.pumpWidget(
        buildApp(
          onOpen: (ctx) async {
            chosen = await showOptionPickerSheet<String>(
              ctx,
              title: 'Import',
              header: const Text('Preview counts'),
              options: const [
                SheetPickerOption(
                  value: 'add',
                  label: 'Add copies',
                  subtitle: 'Keeps existing data',
                ),
                SheetPickerOption(
                  value: 'replace',
                  label: 'Replace',
                  subtitle: 'Requires offline mode',
                  enabled: false,
                ),
              ],
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Preview counts'), findsOneWidget);
      expect(find.text('Keeps existing data'), findsOneWidget);
      expect(find.text('Requires offline mode'), findsOneWidget);

      final disabled = tester.widget<SheetOptionTile>(
        find.widgetWithText(SheetOptionTile, 'Replace'),
      );
      expect(disabled.enabled, isFalse);

      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(chosen, isNull);
      expect(find.byType(SheetOptionTile), findsNWidgets(2));

      await tester.tap(find.text('Add copies'));
      await tester.pumpAndSettle();
      expect(chosen, 'add');
    },
  );

  testWidgets('text input sheet lifts above keyboard viewInsets', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      buildApp(
        onOpen: (ctx) => showTextInputSheet(ctx, title: 'Tag name'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final panel = find.byKey(const ValueKey('responsive_sheet_panel'));
    expect(panel, findsOneWidget);
    final beforeBottom = tester.getBottomLeft(panel).dy;

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    final afterBottom = tester.getBottomLeft(panel).dy;
    expect(afterBottom, lessThan(beforeBottom));
    expect(afterBottom, closeTo(beforeBottom - 300, 1));
    // Field stays in the visible band above the IME.
    expect(tester.getBottomLeft(find.byType(TextField)).dy, lessThan(500));
  });

  testWidgets('tablet text sheet stays above keyboard viewInsets', (tester) async {
    setTabletViewport(tester);
    await tester.pumpWidget(
      buildApp(
        onOpen: (ctx) => showTextInputSheet(ctx, title: 'Tag name'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final panel = find.byKey(const ValueKey('responsive_sheet_panel'));
    final beforeBottom = tester.getBottomLeft(panel).dy;

    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    final afterBottom = tester.getBottomLeft(panel).dy;
    expect(afterBottom, lessThan(beforeBottom));
    expect(afterBottom, lessThanOrEqualTo(800 - 280 + 0.5));
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('confirm sheet without fields still lays out with viewInsets', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      buildApp(
        onOpen: (ctx) => showConfirmSheet(
          ctx,
          title: 'Confirm',
          content: 'No fields here',
          confirmLabel: 'OK',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    expect(find.text('No fields here'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.byKey(const ValueKey('responsive_sheet_panel'))).dy,
      closeTo(500, 1),
    );
  });

  testWidgets('keyboard dismiss does not replay modal height animation', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      buildApp(
        onOpen: (ctx) => showTextInputSheet(ctx, title: 'Tag name'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final panel = find.byKey(const ValueKey('responsive_sheet_panel'));
    final restingBottom = tester.getBottomLeft(panel).dy;

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump(); // one frame — IME pad must apply immediately
    expect(tester.getBottomLeft(panel).dy, closeTo(restingBottom - 300, 1));

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump(); // one frame — must already be back, not mid 320ms morph
    expect(tester.getBottomLeft(panel).dy, closeTo(restingBottom, 1));
  });

  testWidgets('home-indicator inset does not jump when keyboard opens', (
    tester,
  ) async {
    setPhoneViewport(tester);
    // Simulate gesture-nav inset collapsing into viewInsets on IME show.
    tester.view.padding = const FakeViewPadding(bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      buildApp(
        onOpen: (ctx) => showTextInputSheet(ctx, title: 'Tag name'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final panel = find.byKey(const ValueKey('responsive_sheet_panel'));
    final beforeBottom = tester.getBottomLeft(panel).dy;
    final beforeHeight = tester.getSize(panel).height;

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    tester.view.padding = FakeViewPadding.zero; // consumed while IME visible
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();

    final afterBottom = tester.getBottomLeft(panel).dy;
    final afterHeight = tester.getSize(panel).height;
    // With IME up, bottom SafeArea turns off so the sheet sits on the
    // keyboard (no home-indicator gap). Lift = keyboard − prior safe inset.
    expect(afterBottom, closeTo(beforeBottom - 300 + 34, 1));
    // Short sheet height must stay stable (no nested safe-area jump).
    expect(afterHeight, closeTo(beforeHeight, 1));
  });

  testWidgets('IME inset tracked frame-by-frame without modal lag', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      buildApp(
        onOpen: (ctx) => showTextInputSheet(ctx, title: 'Tag name'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final panel = find.byKey(const ValueKey('responsive_sheet_panel'));
    final restingBottom = tester.getBottomLeft(panel).dy;

    addTearDown(tester.view.resetViewInsets);
    for (final inset in [60.0, 150.0, 280.0, 150.0, 0.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump();
      expect(
        tester.getBottomLeft(panel).dy,
        closeTo(restingBottom - inset, 1),
        reason: 'panel must track IME inset=$inset on the same frame',
      );
    }
  });

  testWidgets('default-maxHeight sheet does not animate height with IME', (
    tester,
  ) async {
    setPhoneViewport(tester);
    // Mirrors sign-in / edit-profile: no caller maxHeight (uses size*0.92).
    await tester.pumpWidget(
      buildApp(
        onOpen: (ctx) => showResponsiveSheet<void>(
          context: ctx,
          title: 'Sign in',
          child: buildSheetShell(
            ctx,
            title: 'Sign in',
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: List<Widget>.generate(
                12,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    decoration: InputDecoration(labelText: 'Field $i'),
                  ),
                ),
              ),
            ),
            actions: [
              FilledButton(onPressed: () {}, child: const Text('Done')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final panel = find.byKey(const ValueKey('responsive_sheet_panel'));
    final restingBottom = tester.getBottomLeft(panel).dy;

    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(tester.getBottomLeft(panel).dy, closeTo(restingBottom - 320, 1));

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    expect(tester.getBottomLeft(panel).dy, closeTo(restingBottom, 1));
    // Still settled after modal duration — no late height morph.
    await tester.pump(const Duration(milliseconds: 320));
    expect(tester.getBottomLeft(panel).dy, closeTo(restingBottom, 1));
  });
}
