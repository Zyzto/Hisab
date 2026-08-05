import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:hisab/core/layout/responsive_sheet.dart';
import 'package:hisab/features/expenses/category_icons.dart';
import 'package:hisab/features/expenses/widgets/tag_style_fields.dart';

import '../widget_test_helpers.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  void setPhoneViewport(WidgetTester tester, {Size size = const Size(400, 800)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildApp({
    required Future<void> Function(BuildContext context) onOpen,
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
      startLocale: const Locale('en'),
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<void> openTagEditor(
    WidgetTester tester, {
    String name = '',
    String? nameError,
  }) async {
    final nameController = TextEditingController(text: name);
    addTearDown(nameController.dispose);
    var icon = selectableCategoryIcons.keys.first;
    var color = selectableTagColorHexes.first;

    await tester.pumpWidget(
      buildApp(
        onOpen: (ctx) => showResponsiveSheet<void>(
          context: ctx,
          title: 'Create New Tag',
          maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return TagEditorSheetShell(
                title: 'Create New Tag',
                nameField: TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Tag name',
                    errorText: nameError,
                  ),
                ),
                styleFields: TagStyleFields(
                  showPreview: false,
                  selectedIconName: icon,
                  selectedColorHex: color,
                  onIconSelected: (v) => setSheetState(() => icon = v),
                  onColorSelected: (v) => setSheetState(() => color = v),
                ),
                preview: TagPreviewChip(
                  label: nameController.text,
                  iconName: icon,
                  colorHex: color,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('sticky footer keeps Done visible while icons scroll', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await openTagEditor(tester, name: 'Coffee');

    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Coffee'), findsWidgets);

    // Preview + actions share one footer row; Done is trailing-anchored.
    final previewY = tester.getCenter(find.byType(TagPreviewChip)).dy;
    final doneY = tester.getCenter(find.text('Done')).dy;
    expect((previewY - doneY).abs(), lessThan(24));
    expect(
      tester.getTopLeft(find.text('Done')).dx,
      greaterThan(tester.getTopRight(find.byType(TagPreviewChip)).dx),
    );

    // Scroll the icon grid; footer actions must remain on screen.
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Done'), findsOneWidget);
    expect(tester.getBottomLeft(find.text('Done')).dy, lessThan(800));
  });

  testWidgets('footer actions anchor to end in RTL', (tester) async {
    setPhoneViewport(tester);
    await pumpApp(
      tester,
      locale: const Locale('ar'),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: SizedBox(
          height: 400,
          width: 400,
          child: TagEditorSheetShell(
            title: 'إنشاء وسم',
            nameField: const SizedBox(height: 48),
            styleFields: const SizedBox(height: 80),
            preview: const TagPreviewChip(
              label: 'قهوة',
              iconName: 'coffee',
              colorHex: '#EF4444',
            ),
            actions: [
              TextButton(onPressed: () {}, child: const Text('Cancel')),
              FilledButton(onPressed: () {}, child: const Text('Done')),
            ],
          ),
        ),
      ),
    );

    // In RTL, trailing actions sit to the left of the preview chip.
    expect(
      tester.getTopRight(find.text('Done')).dx,
      lessThan(tester.getTopLeft(find.byType(TagPreviewChip)).dx),
    );
  });

  testWidgets('empty preview falls back to tag_name label', (tester) async {
    setPhoneViewport(tester);
    await openTagEditor(tester);

    // en.json: "tag_name": "Tag name"
    expect(find.text('Tag name'), findsWidgets);
  });

  testWidgets('long preview label does not overflow', (tester) async {
    setPhoneViewport(tester);
    FlutterError.onError = (details) {
      // Fail on overflow / layout exceptions.
      fail(details.exceptionAsString());
    };
    await openTagEditor(
      tester,
      name: 'A very long custom category name that should ellipsize nicely',
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(TagPreviewChip), findsOneWidget);
    expect(
      tester.getSize(find.byType(TagPreviewChip)).width,
      lessThanOrEqualTo(TagPreviewChip.defaultMaxWidth(tester.element(find.byType(TagPreviewChip))) + 0.5),
    );
  });

  testWidgets('short preview chip stays compact', (tester) async {
    setPhoneViewport(tester);
    await openTagEditor(tester, name: 'Hi');
    final chipW = tester.getSize(find.byType(TagPreviewChip)).width;
    // Shrink-wrapped: well under the default max and under half the phone width.
    expect(chipW, lessThan(120));
    expect(chipW, greaterThan(40));
  });

  testWidgets('tight height with IME does not overflow sticky shell', (
    tester,
  ) async {
    setPhoneViewport(tester, size: const Size(400, 640));
    await openTagEditor(tester, name: 'Food', nameError: 'Required');

    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('color tap dismisses focus from name field', (tester) async {
    setPhoneViewport(tester);
    await openTagEditor(tester, name: 'Pets');

    await tester.tap(find.byType(TextField));
    await tester.pump();
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);

    final swatch = find.bySemanticsLabel(selectableTagColorHexes[1]);
    await tester.ensureVisible(swatch);
    await tester.tap(swatch);
    await tester.pumpAndSettle();

    expect(editable.focusNode.hasFocus, isFalse);
  });
}
