import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/build_env.dart';
import 'package:hisab/core/widgets/test_build_marker.dart';

void main() {
  test('branding key matches the compile-time environment', () {
    expect(
      appNameTranslationKey,
      isStagingBuild ? 'test_app_name' : 'app_name',
    );
  });

  testWidgets('test marker is only rendered for staging builds', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 100,
          height: 100,
          child: TestBuildMarker(child: SizedBox.expand()),
        ),
      ),
    );

    final marker = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color == const Color(0xFFFFC107),
    );

    expect(marker, isStagingBuild ? findsOneWidget : findsNothing);
  });
}
