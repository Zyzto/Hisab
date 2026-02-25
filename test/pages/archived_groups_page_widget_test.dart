import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab/features/groups/providers/groups_provider.dart';
import 'package:hisab/features/home/pages/archived_groups_page.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('ArchivedGroupsPage shows app bar and empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          archivedGroupsProvider.overrideWith((ref) => Stream.value([])),
          locallyArchivedGroupsProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: const [Locale('en')],
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(
            home: Scaffold(body: ArchivedGroupsPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ArchivedGroupsPage), findsOneWidget);
    expect(find.byIcon(Icons.archive_outlined), findsOneWidget);
  });
}
