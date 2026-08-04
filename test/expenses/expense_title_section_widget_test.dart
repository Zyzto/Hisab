import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/expenses/widgets/category_affordance_chip.dart';
import 'package:hisab/features/expenses/widgets/expense_title_section.dart';
import 'package:hisab/features/settings/providers/settings_framework_providers.dart';

void main() {
  late TextEditingController controller;

  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  setUp(() {
    controller = TextEditingController(text: 'Dinner');
  });

  tearDown(() {
    controller.dispose();
  });

  testWidgets('ExpenseTitleSection keeps category and camera inside the field', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          extraAnimationsEnabledProvider.overrideWith((ref) => false),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: const [Locale('en')],
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: MaterialApp(
            home: Scaffold(
              body: ExpenseTitleSection(
                controller: controller,
                selectedTag: null,
                customTags: const [],
                onTagPicker: () {},
                onPickImage: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ExpenseTitleSection), findsOneWidget);
    expect(find.byType(CategoryAffordanceChip), findsOneWidget);
    expect(find.byIcon(Icons.label_outlined), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.suffixIcon, isNotNull);
    // Widget-test EasyLocalization harness falls back to keys.
    expect(field.decoration?.hintText, 'title_hint');
  });
}
