import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hisab/core/repository/group_invite_repository.dart';
import 'package:hisab/core/repository/repository_providers.dart';
import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/groups/widgets/create_invite_sheet.dart';

import '../widget_test_helpers.dart';

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  late FakeGroupInviteRepository fakeInviteRepo;

  setUp(() {
    fakeInviteRepo = FakeGroupInviteRepository();
  });

  /// Use a large viewport so the sheet content does not overflow (Column in sheet has no scroll).
  Future<void> setLargeViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<void> openCreateInviteSheet(WidgetTester tester) async {
    await setLargeViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupInviteRepositoryProvider.overrideWithValue(fakeInviteRepo),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: testSupportedLocales,
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => FilledButton(
                  onPressed: () async {
                    await showCreateInviteSheet(context, ref, 'test-group-id');
                  },
                  child: const Text('Open sheet'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
  }

  testWidgets('CreateInviteSheet is visible and shows create invite title and role', (tester) async {
    await openCreateInviteSheet(tester);

    expect(find.byIcon(Icons.add_link), findsOneWidget);
    expect(find.byIcon(Icons.label_outline), findsOneWidget);
  });

  testWidgets('CreateInviteSheet shows create button', (tester) async {
    await openCreateInviteSheet(tester);

    expect(find.byIcon(Icons.add_link), findsOneWidget);
  });

  testWidgets('CreateInviteSheet in Arabic shows key content', (tester) async {
    await setLargeViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupInviteRepositoryProvider.overrideWithValue(fakeInviteRepo),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: testSupportedLocales,
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('ar'),
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => FilledButton(
                  onPressed: () async {
                    await showCreateInviteSheet(context, ref, 'test-group-id');
                  },
                  child: const Text('Open sheet'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add_link), findsOneWidget);
  });
}

/// Minimal fake for [IGroupInviteRepository] so the sheet builds and Create returns a token.
class FakeGroupInviteRepository implements IGroupInviteRepository {
  @override
  Future<({GroupInvite invite, Group group})?> getByToken(String token) async =>
      null;

  @override
  Future<({String id, String token})> createInvite(
    String groupId, {
    String? inviteeEmail,
    String? role,
    String? label,
    int? maxUses,
    Duration? expiresIn,
  }) async =>
      (id: 'fake-invite-id', token: 'fake-token');

  @override
  Future<String> accept(String token, {String? newParticipantName}) async =>
      'group-id';

  @override
  Future<List<GroupInvite>> listByGroup(String groupId) async => [];

  @override
  Stream<List<GroupInvite>> watchByGroup(String groupId) =>
      Stream.value([]);

  @override
  Future<void> revoke(String inviteId) async {}

  @override
  Future<void> toggleActive(String inviteId, bool active) async {}

  @override
  Future<List<InviteUsage>> listUsages(String inviteId) async => [];

  @override
  Stream<List<InviteUsage>> watchUsages(String inviteId) =>
      Stream.value([]);
}
