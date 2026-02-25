import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/widgets/pwa_install_banner.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('PwaInstallBanner pumps without error', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        path: 'assets/translations',
        supportedLocales: const [Locale('en')],
        fallbackLocale: const Locale('en'),
        startLocale: const Locale('en'),
        child: const MaterialApp(
          home: Scaffold(
            body: PwaInstallBanner(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PwaInstallBanner), findsOneWidget);
    // On non-web or when not visible, banner returns SizedBox.shrink
  });
}
