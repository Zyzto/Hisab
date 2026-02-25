import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/widgets/expandable_section.dart';
import '../widget_test_helpers.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('ExpandableSection shows title and when initiallyExpanded true shows child', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: const MaterialApp(
          home: Scaffold(
            body: ExpandableSection(
              title: 'Details',
              initiallyExpanded: true,
              child: Text('Child content'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Child content'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
  });

  testWidgets('ExpandableSection initiallyExpanded false hides child', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: const MaterialApp(
          home: Scaffold(
            body: ExpandableSection(
              title: 'Section',
              initiallyExpanded: false,
              child: Text('Hidden'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Section'), findsOneWidget);
    expect(find.text('Hidden'), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });

  testWidgets('ExpandableSection tap toggles expand/collapse', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: const MaterialApp(
          home: Scaffold(
            body: ExpandableSection(
              title: 'Toggle',
              initiallyExpanded: false,
              child: Text('Content'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Content'), findsNothing);
    await tester.tap(find.text('Toggle'));
    await tester.pumpAndSettle();
    expect(find.text('Content'), findsOneWidget);
    await tester.tap(find.text('Toggle'));
    await tester.pumpAndSettle();
    expect(find.text('Content'), findsNothing);
  });

  testWidgets('ExpandableSection shows trailingSummary when provided', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: const MaterialApp(
          home: Scaffold(
            body: ExpandableSection(
              title: 'Summary',
              trailingSummary: '3 items',
              initiallyExpanded: false,
              child: SizedBox(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);
  });

  testWidgets('ExpandableSection with empty trailingSummary shows only title', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: const MaterialApp(
          home: Scaffold(
            body: ExpandableSection(
              title: 'Only Title',
              trailingSummary: '',
              initiallyExpanded: false,
              child: SizedBox(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Only Title'), findsOneWidget);
    expect(find.byType(ExpandableSection), findsOneWidget);
  });

  testWidgets('ExpandableSection renders with Arabic locale', (tester) async {
    await pumpApp(
      tester,
      child: const ExpandableSection(
        title: 'تفاصيل',
        initiallyExpanded: true,
        child: Text('Content'),
      ),
      locale: const Locale('ar'),
    );
    expect(find.text('تفاصيل'), findsOneWidget);
    expect(find.text('Content'), findsOneWidget);
  });
}
