import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/debug/crash_error_panel.dart';

void main() {
  testWidgets('builds Icon without a Directionality ancestor', (tester) async {
    await tester.pumpWidget(const CrashErrorPanel(message: 'boom'));

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('boom'), findsOneWidget);
  });
}
