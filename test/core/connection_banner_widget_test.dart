import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab/core/services/connectivity_service.dart';
import 'package:hisab/core/widgets/connection_banner.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('ConnectionBanner when connected is hidden', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncStatusForDisplayProvider.overrideWithValue(SyncStatus.connected),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: const [Locale('en')],
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(
            home: Scaffold(body: ConnectionBanner()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionBanner), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
  });

  testWidgets('ConnectionBanner when offline from start builds without error', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncStatusForDisplayProvider.overrideWithValue(SyncStatus.offline),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: const [Locale('en')],
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(
            home: Scaffold(body: ConnectionBanner()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionBanner), findsOneWidget);
  });
}
