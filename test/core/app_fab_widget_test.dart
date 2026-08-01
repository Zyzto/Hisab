import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/widgets/app_fab.dart';
import 'package:hisab/core/widgets/app_fab_nature.dart';
import 'package:hisab/features/settings/providers/settings_framework_providers.dart';

Widget _wrap(Widget child, {bool extraAnimations = true}) {
  return ProviderScope(
    overrides: [
      extraAnimationsEnabledProvider.overrideWithValue(extraAnimations),
    ],
    child: MaterialApp(home: Scaffold(floatingActionButton: child)),
  );
}

void main() {
  setUp(() {
    AppFab.enableAmbientNature = false;
  });

  tearDown(() {
    AppFab.enableAmbientNature = false;
  });

  testWidgets('AppFab shows icon and invokes onPressed after delay', (
    tester,
  ) async {
    var pressed = 0;
    await tester.pumpWidget(
      _wrap(
        AppFab(
          icon: Icons.add,
          onPressed: () => pressed++,
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.add), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(pressed, 0);
    await tester.pump(const Duration(milliseconds: 400));
    expect(pressed, 1);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('AppFab with extras off invokes onPressed immediately', (
    tester,
  ) async {
    var pressed = 0;
    await tester.pumpWidget(
      _wrap(
        AppFab(
          icon: Icons.add,
          onPressed: () => pressed++,
        ),
        extraAnimations: false,
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(pressed, 1);
    await tester.pumpAndSettle();
  });

  testWidgets('AppFab invokes onLongPress', (tester) async {
    var longPressed = 0;
    await tester.pumpWidget(
      _wrap(
        AppFab(
          icon: Icons.add,
          onPressed: () {},
          onLongPress: () => longPressed++,
        ),
      ),
    );
    await tester.pump();
    await tester.longPress(find.byIcon(Icons.add));
    await tester.pump();
    expect(longPressed, 1);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('AppFab shows label when set', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AppFab(
          icon: Icons.person_add,
          label: 'Add participant',
          onPressed: () {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.person_add), findsOneWidget);
    expect(find.text('Add participant'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('AppFab paints nature layer after press when extras on', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        AppFab(
          icon: Icons.add,
          onPressed: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  test('generateAppFabLeaves returns several leaves', () {
    final leaves = generateAppFabLeaves(math.Random(1));
    expect(leaves.length, inInclusiveRange(5, 7));
    expect(leaves.first.size, greaterThan(0));
  });
}
