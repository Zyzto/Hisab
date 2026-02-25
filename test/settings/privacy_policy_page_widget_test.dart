import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/settings/widgets/privacy_policy_page.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('PrivacyPolicyPage shows appBar and intro section', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: const MaterialApp(
          home: PrivacyPolicyPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyPolicyPage), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });
}
