import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/expenses/widgets/expense_title_section.dart';

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

  testWidgets('ExpenseTitleSection shows title label and tag icon', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
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
              onPickReceipt: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.label_outlined), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    expect(find.byType(ExpenseTitleSection), findsOneWidget);
  });
}
