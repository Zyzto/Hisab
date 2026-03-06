import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hisab/core/constants/supabase_config.dart';
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

  /// Use a narrow viewport so the sheet is shown as bottom sheet (not dialog), avoiding dialog height constraint.
  Future<void> setViewportForSheet(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Widget buildTestApp({Locale locale = const Locale('en')}) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
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
      ],
    );
    return ProviderScope(
      overrides: [
        groupInviteRepositoryProvider.overrideWithValue(fakeInviteRepo),
      ],
      child: EasyLocalization(
        path: 'assets/translations',
        supportedLocales: testSupportedLocales,
        fallbackLocale: const Locale('en'),
        startLocale: locale,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  Future<void> openCreateInviteSheet(WidgetTester tester) async {
    await setViewportForSheet(tester);
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'CreateInviteSheet is visible and shows create invite title and role',
    (tester) async {
      await openCreateInviteSheet(tester);

      expect(find.byIcon(Icons.add_link), findsOneWidget);
      expect(find.byIcon(Icons.label_outline), findsOneWidget);
    },
  );

  testWidgets('CreateInviteSheet shows create button', (tester) async {
    await openCreateInviteSheet(tester);

    expect(find.byIcon(Icons.add_link), findsOneWidget);
  });

  testWidgets('CreateInviteSheet passes selected access mode', (tester) async {
    await openCreateInviteSheet(tester);

    await tester.tap(find.text('Read-only only'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_link).first);
    await tester.pumpAndSettle();

    expect(fakeInviteRepo.lastAccessMode, InviteAccessMode.readonlyOnly);
  }, skip: !supabaseConfigAvailable);

  testWidgets('CreateInviteSheet in Arabic shows key content', (tester) async {
    await setViewportForSheet(tester);
    await tester.pumpWidget(buildTestApp(locale: const Locale('ar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add_link), findsOneWidget);
  });

  testWidgets(
    'Create action closes form sheet and shows offline notice when Supabase is not configured',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();

      final createButtonIcon = find.byIcon(Icons.add_link).first;
      await tester.ensureVisible(createButtonIcon);
      await tester.tap(createButtonIcon);
      await tester.pumpAndSettle();

      expect(fakeInviteRepo.createCalls, 1);
      expect(find.byIcon(Icons.label_outline), findsNothing);
      final hasOnlineNotice = find
          .textContaining('online')
          .evaluate()
          .isNotEmpty;
      expect(hasOnlineNotice, isTrue);
      expect(find.byIcon(Icons.add_link), findsNothing);
    },
    skip: supabaseConfigAvailable,
  );

  testWidgets(
    'Create action opens QR share actions when Supabase is configured',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();

      final createButtonIcon = find.byIcon(Icons.add_link).first;
      await tester.ensureVisible(createButtonIcon);
      await tester.tap(createButtonIcon);
      await tester.pumpAndSettle();

      expect(fakeInviteRepo.createCalls, 1);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.add_link), findsNothing);
    },
    skip: !supabaseConfigAvailable,
  );
}

/// Minimal fake for [IGroupInviteRepository] so the sheet builds and Create returns a token.
class FakeGroupInviteRepository implements IGroupInviteRepository {
  int createCalls = 0;
  InviteAccessMode lastAccessMode = InviteAccessMode.standard;

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
    InviteAccessMode accessMode = InviteAccessMode.standard,
  }) async {
    createCalls += 1;
    lastAccessMode = accessMode;
    return (id: 'fake-invite-id', token: 'fake-token');
  }

  @override
  Future<String> accept(String token, {String? newParticipantName}) async =>
      'group-id';

  @override
  Future<List<GroupInvite>> listByGroup(String groupId) async => [];

  @override
  Stream<List<GroupInvite>> watchByGroup(String groupId) => Stream.value([]);

  @override
  Future<void> revoke(String inviteId) async {}

  @override
  Future<void> toggleActive(String inviteId, bool active) async {}

  @override
  Future<List<InviteUsage>> listUsages(String inviteId) async => [];

  @override
  Stream<List<InviteUsage>> watchUsages(String inviteId) => Stream.value([]);
}
