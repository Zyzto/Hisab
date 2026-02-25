import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab/core/services/connectivity_service.dart';
import 'package:hisab/core/widgets/sync_status_icon.dart';
import '../widget_test_helpers.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('SyncStatusChip when localOnly is not visible', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncStatusForDisplayProvider.overrideWithValue(SyncStatus.localOnly),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: const [Locale('en')],
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(
            home: Scaffold(body: SyncStatusChip()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SyncStatusChip), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_outlined), findsNothing);
  });

  testWidgets('SyncStatusChip when connected is visible with icon', (tester) async {
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
            home: Scaffold(body: SyncStatusChip()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SyncStatusChip), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
  });

  testWidgets('SyncStatusChip when syncing is visible', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncStatusForDisplayProvider.overrideWithValue(SyncStatus.syncing),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: const [Locale('en')],
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(
            home: Scaffold(body: SyncStatusChip()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(SyncStatusChip), findsOneWidget);
  });

  testWidgets('SyncStatusChip when offline is visible with Arabic locale', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncStatusForDisplayProvider.overrideWithValue(SyncStatus.offline),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: testSupportedLocales,
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('ar'),
          child: const MaterialApp(
            home: Scaffold(body: SyncStatusChip()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SyncStatusChip), findsOneWidget);
  });
}
