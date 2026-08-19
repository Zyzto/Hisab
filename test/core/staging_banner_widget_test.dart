import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/widgets/staging_banner.dart';

void main() {
  testWidgets('staging wrap paints a TEST banner', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: wrapWithStagingBanner(
          enabled: true,
          child: const Text('body'),
        ),
      ),
    );
    final banner = tester.widget<Banner>(find.byType(Banner));
    expect(banner.message, 'TEST');
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('disabled wrap is a pass-through', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: wrapWithStagingBanner(enabled: false, child: const Text('body')),
      ),
    );
    expect(find.byType(Banner), findsNothing);
    expect(find.text('body'), findsOneWidget);
  });
}
