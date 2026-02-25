import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/groups/widgets/group_card.dart';
import '../widget_test_helpers.dart';

void main() {
  final now = DateTime(2025, 1, 15);
  late Group testGroup;

  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  setUp(() {
    testGroup = Group(
      id: 'g1',
      name: 'Test Trip',
      currencyCode: 'USD',
      createdAt: now,
      updatedAt: now,
      isPersonal: false,
    );
  });

  testWidgets('GroupCard renders group name and currency', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: GroupCard(group: testGroup),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Test Trip'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
  });

  testWidgets('GroupCard shows createdDateLabel when provided', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: GroupCard(
              group: testGroup,
              createdDateLabel: 'Jan 15',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jan 15'), findsOneWidget);
    expect(find.text('Test Trip'), findsOneWidget);
  });

  testWidgets('GroupCard shows pin icon when onPinToggle provided', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: GroupCard(
              group: testGroup,
              onPinToggle: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
  });

  testWidgets('GroupCard onTap is called when tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: GroupCard(
              group: testGroup,
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(GroupCard));
    await tester.pumpAndSettle();
    expect(tapped, true);
  });

  testWidgets('GroupCard onLongPress is called when long-pressed', (tester) async {
    var longPressed = false;
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: GroupCard(
              group: testGroup,
              onLongPress: () => longPressed = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.byType(GroupCard));
    await tester.pumpAndSettle();
    expect(longPressed, true);
  });

  testWidgets('GroupCard isSelected shows card', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: GroupCard(
              group: testGroup,
              isSelected: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GroupCard), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('GroupCard renders with Arabic locale', (tester) async {
    await pumpApp(
      tester,
      child: GroupCard(group: testGroup),
      locale: const Locale('ar'),
    );
    expect(find.text('Test Trip'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    expect(find.byType(GroupCard), findsOneWidget);
  });

  testWidgets('GroupCard with empty name still builds', (tester) async {
    final emptyNameGroup = Group(
      id: 'g2',
      name: '',
      currencyCode: 'EUR',
      createdAt: now,
      updatedAt: now,
      isPersonal: false,
    );
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: GroupCard(group: emptyNameGroup),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GroupCard), findsOneWidget);
    expect(find.text('EUR'), findsOneWidget);
  });

  testWidgets('GroupCard personal group shows card', (tester) async {
    final personalGroup = Group(
      id: 'g3',
      name: 'My list',
      currencyCode: 'USD',
      createdAt: now,
      updatedAt: now,
      isPersonal: true,
    );
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: GroupCard(group: personalGroup),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('My list'), findsOneWidget);
    expect(find.byType(GroupCard), findsOneWidget);
  });

  testWidgets('GroupCard isPinned with onPinToggle shows filled pin icon after tap', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: GroupCard(
              group: testGroup,
              isPinned: true,
              onPinToggle: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.push_pin), findsOneWidget);
  });
}
