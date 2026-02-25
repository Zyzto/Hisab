import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/widgets/back_button_keyboard_dismiss.dart';

import '../widget_test_helpers.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('BackButtonKeyboardDismiss builds and displays child', (tester) async {
    await pumpApp(
      tester,
      child: const BackButtonKeyboardDismiss(
        child: Text('child'),
      ),
    );
    expect(find.text('child'), findsOneWidget);
  });

  testWidgets('BackButtonKeyboardDismiss displays complex child', (tester) async {
    await pumpApp(
      tester,
      child: const BackButtonKeyboardDismiss(
        child: Scaffold(
          body: Center(child: Text('Page content')),
        ),
      ),
    );
    expect(find.text('Page content'), findsOneWidget);
  });
}
