import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hisab/core/auth/auth_service.dart';
import 'package:hisab/core/auth/auth_user_profile.dart';
import 'package:hisab/core/auth/auth_providers.dart';
import 'package:hisab/core/repository/group_invite_repository.dart';
import 'package:hisab/core/repository/repository_providers.dart';
import 'package:hisab/core/services/connectivity_service.dart';
import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/groups/pages/invite_accept_page.dart';
import 'package:hisab/features/settings/providers/settings_framework_providers.dart';
import 'package:hisab/features/settings/settings_definitions.dart';

import '../widget_test_helpers.dart';

class _FakeAuthService extends AuthService {
  @override
  AuthUserProfile? getUserProfile() {
    return const AuthUserProfile(
      name: 'Test User',
      email: 'test@example.com',
      sub: 'user-1',
      avatarId: null,
    );
  }
}

class _FakeGroupInviteRepository implements IGroupInviteRepository {
  _FakeGroupInviteRepository({
    this.acceptErrorMessage,
    required this.invite,
    required this.group,
  });

  final String? acceptErrorMessage;
  final GroupInvite invite;
  final Group group;
  int acceptCalls = 0;

  @override
  Future<({String id, String token})> createInvite(
    String groupId, {
    String? inviteeEmail,
    String? role,
    String? label,
    int? maxUses,
    Duration? expiresIn,
    InviteAccessMode accessMode = InviteAccessMode.standard,
  }) async => (id: 'id', token: 'token');

  @override
  Future<({GroupInvite invite, Group group})?> getByToken(String token) async =>
      (invite: invite, group: group);

  @override
  Future<String> accept(
    String token, {
    String? newParticipantName,
    String? participantId,
  }) async {
    acceptCalls += 1;
    if (acceptErrorMessage != null) {
      throw acceptErrorMessage!;
    }
    return 'group-1';
  }

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

/// Bounded pumps for invite auto-join tests. Avoid [WidgetTester.pumpAndSettle]
/// (CircularProgressIndicator never idles). Advance clock briefly to flush the
/// logging aggregation timer from invite entry helpers.
Future<void> pumpInviteAutoJoinFrames(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 120));
}

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
    SharedPreferences.setMockInitialValues({});
  });

  GroupInvite makeInvite() => GroupInvite(
    id: 'invite-1',
    groupId: 'group-1',
    token: 'token-1',
    role: 'member',
    createdAt: DateTime(2026, 1, 1),
    expiresAt: DateTime(2026, 12, 31),
  );

  Group makeGroup() => Group(
    id: 'group-1',
    name: 'بيت لحم',
    currencyCode: 'USD',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Future<void> pump(
    WidgetTester tester,
    _FakeGroupInviteRepository repo,
    {bool authenticated = true, bool localOnly = false}
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveLocalOnlyProvider.overrideWith((ref) => localOnly),
          isAuthenticatedProvider.overrideWith((ref) => authenticated),
          authServiceProvider.overrideWith((ref) => _FakeAuthService()),
          groupInviteRepositoryProvider.overrideWithValue(repo),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: testSupportedLocales,
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(home: InviteAcceptPage(token: 'token-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpWithRouter(
    WidgetTester tester,
    _FakeGroupInviteRepository repo, {
    bool authenticated = false,
    bool localOnly = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveLocalOnlyProvider.overrideWith((ref) => localOnly),
          isAuthenticatedProvider.overrideWith((ref) => authenticated),
          authServiceProvider.overrideWith((ref) => _FakeAuthService()),
          groupInviteRepositoryProvider.overrideWithValue(repo),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: testSupportedLocales,
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/invite/token-1',
              routes: [
                GoRoute(
                  path: '/invite/:token',
                  builder: (context, state) =>
                      InviteAcceptPage(token: state.pathParameters['token']!),
                ),
                GoRoute(
                  path: '/invite/:token/preview',
                  builder: (context, state) => Scaffold(
                    body: Center(
                      child: Text('PREVIEW_PAGE_${state.pathParameters['token']}'),
                    ),
                  ),
                ),
                GoRoute(
                  path: '/settings',
                  builder: (context, state) =>
                      const Scaffold(body: Center(child: Text('SETTINGS_PAGE'))),
                ),
                GoRoute(
                  path: '/onboarding',
                  builder: (context, state) => const Scaffold(
                    body: Center(child: Text('ONBOARDING_PAGE')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('handles already-member accept failure without crashing', (
    tester,
  ) async {
    final repo = _FakeGroupInviteRepository(
      acceptErrorMessage: 'Already a member of this group',
      invite: makeInvite(),
      group: makeGroup(),
    );
    await pump(tester, repo);

    expect(find.text('بيت لحم'), findsOneWidget);
    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    expect(repo.acceptCalls, 1);
    expect(find.text('بيت لحم'), findsOneWidget);
  });

  testWidgets('handles unauthenticated accept failure without crashing', (
    tester,
  ) async {
    final repo = _FakeGroupInviteRepository(
      acceptErrorMessage: 'Unauthenticated',
      invite: makeInvite(),
      group: makeGroup(),
    );
    await pump(tester, repo);

    expect(find.text('بيت لحم'), findsOneWidget);
    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    expect(repo.acceptCalls, 1);
    expect(find.text('بيت لحم'), findsOneWidget);
  });

  testWidgets(
    'maps invalid or expired backend message to invite_expired text',
    (tester) async {
      final repo = _FakeGroupInviteRepository(
        acceptErrorMessage: 'Invalid or expired invite',
        invite: makeInvite(),
        group: makeGroup(),
      );
      await pump(tester, repo);

      expect(find.text('بيت لحم'), findsOneWidget);
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();

      expect(repo.acceptCalls, 1);
      expect(find.textContaining('expired'), findsOneWidget);
    },
  );

  testWidgets('accept button is usable again after failure', (tester) async {
    final repo = _FakeGroupInviteRepository(
      acceptErrorMessage: 'Invite service unavailable',
      invite: makeInvite(),
      group: makeGroup(),
    );
    await pump(tester, repo);

    expect(find.text('بيت لحم'), findsOneWidget);
    final acceptButton = find.byType(FilledButton).first;
    await tester.tap(acceptButton);
    await tester.pumpAndSettle();
    await tester.tap(acceptButton);
    await tester.pumpAndSettle();

    expect(repo.acceptCalls, 2);
    expect(find.textContaining('Invite service unavailable'), findsOneWidget);
  });

  testWidgets('readonly_join unauthenticated shows preview actions', (tester) async {
    final repo = _FakeGroupInviteRepository(
      invite: makeInvite().copyWith(accessMode: InviteAccessMode.readonlyJoin),
      group: makeGroup(),
    );
    await pump(tester, repo, authenticated: false);

    expect(find.text('بيت لحم'), findsOneWidget);
    expect(find.textContaining('preview'), findsWidgets);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  testWidgets('readonly_only hides join action', (tester) async {
    final repo = _FakeGroupInviteRepository(
      invite: makeInvite().copyWith(accessMode: InviteAccessMode.readonlyOnly),
      group: makeGroup(),
    );
    await pump(tester, repo, authenticated: true);

    expect(find.text('بيت لحم'), findsOneWidget);
    // Preview button remains, accept action is disabled.
    expect(find.byType(OutlinedButton), findsAtLeastNWidgets(1));
  });

  testWidgets('local-only standard invite still shows online required message', (
    tester,
  ) async {
    final repo = _FakeGroupInviteRepository(
      invite: makeInvite().copyWith(accessMode: InviteAccessMode.standard),
      group: makeGroup(),
    );
    await pump(tester, repo, authenticated: false, localOnly: true);

    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            ((w.data ?? '').contains('Invites require online mode') ||
                (w.data ?? '').contains('invite_requires_online')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('local-only readonly invite is blocked when backend is missing', (
    tester,
  ) async {
    final repo = _FakeGroupInviteRepository(
      invite: makeInvite().copyWith(accessMode: InviteAccessMode.readonlyOnly),
      group: makeGroup(),
    );
    await pump(tester, repo, authenticated: false, localOnly: true);

    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            ((w.data ?? '').contains('Invites require online mode') ||
                (w.data ?? '').contains('invite_requires_online')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('unauthenticated readonly_join stays on invite choice page', (
    tester,
  ) async {
    final repo = _FakeGroupInviteRepository(
      invite: makeInvite().copyWith(accessMode: InviteAccessMode.readonlyJoin),
      group: makeGroup(),
    );
    await pumpWithRouter(tester, repo, authenticated: false);

    expect(find.text('PREVIEW_PAGE_token-1'), findsNothing);
    expect(find.textContaining('preview'), findsWidgets);
    expect(find.textContaining('join'), findsWidgets);
  }, skip: !kIsWeb);

  testWidgets(
    'readonly_join unauthenticated join CTA opens sign-in not onboarding',
    (tester) async {
      final repo = _FakeGroupInviteRepository(
        invite: makeInvite().copyWith(accessMode: InviteAccessMode.readonlyJoin),
        group: makeGroup(),
      );
      await pumpWithRouter(tester, repo, authenticated: false);

      await tester.tap(find.textContaining('join').first);
      await tester.pumpAndSettle();

      expect(find.text('ONBOARDING_PAGE'), findsNothing);
      // Sign-in sheet title (login / register), not full onboarding.
      expect(find.text('sign_in'.tr()), findsWidgets);
    },
    skip: !kIsWeb,
  );

  testWidgets('unauthenticated readonly_only routes directly to preview', (
    tester,
  ) async {
    final repo = _FakeGroupInviteRepository(
      invite: makeInvite().copyWith(accessMode: InviteAccessMode.readonlyOnly),
      group: makeGroup(),
    );
    await pumpWithRouter(tester, repo, authenticated: false);

    expect(find.text('PREVIEW_PAGE_token-1'), findsOneWidget);
  }, skip: !kIsWeb);

  testWidgets(
    'local-only readonly_join authenticated join CTA stays on invite not settings',
    (tester) async {
      final repo = _FakeGroupInviteRepository(
        invite: makeInvite().copyWith(accessMode: InviteAccessMode.readonlyJoin),
        group: makeGroup(),
      );
      await pumpWithRouter(
        tester,
        repo,
        authenticated: true,
        localOnly: true,
      );

      await tester.tap(find.textContaining('join').first);
      await tester.pumpAndSettle();

      expect(find.text('SETTINGS_PAGE'), findsNothing);
      expect(find.text('ONBOARDING_PAGE'), findsNothing);
      // Still on invite accept (force-online cannot flip when overridden local-only).
      expect(find.textContaining('join'), findsWidgets);
    },
    skip: !kIsWeb,
  );

  testWidgets(
    'authenticated view+join auto-accepts when pending_invite_auto_join is set',
    (tester) async {
      final settings = await tester.runAsync(initializeHisabSettings);
      expect(settings, isNotNull);
      settings!.controller.set(pendingInviteTokenSettingDef, 'token-1');
      settings.controller.set(pendingInviteAutoJoinSettingDef, true);

      final repo = _FakeGroupInviteRepository(
        acceptErrorMessage: 'Already a member of this group',
        invite: makeInvite().copyWith(
          accessMode: InviteAccessMode.readonlyJoin,
        ),
        group: makeGroup(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hisabSettingsProvidersProvider.overrideWithValue(settings),
            effectiveLocalOnlyProvider.overrideWith((ref) => false),
            connectivityProvider.overrideWithValue(true),
            isAuthenticatedProvider.overrideWith((ref) => true),
            authServiceProvider.overrideWith((ref) => _FakeAuthService()),
            groupInviteRepositoryProvider.overrideWithValue(repo),
          ],
          child: EasyLocalization(
            path: 'assets/translations',
            supportedLocales: testSupportedLocales,
            fallbackLocale: const Locale('en'),
            startLocale: const Locale('en'),
            child: const MaterialApp(
              home: InviteAcceptPage(token: 'token-1'),
            ),
          ),
        ),
      );
      await pumpInviteAutoJoinFrames(tester);

      expect(repo.acceptCalls, greaterThanOrEqualTo(1));
      expect(find.textContaining('already'), findsOneWidget);
      // Leftover pending would bounce /groups → /invite after Open Group.
      expect(
        settings.controller.get(pendingInviteTokenSettingDef),
        isEmpty,
      );
      expect(
        settings.controller.get(pendingInviteAutoJoinSettingDef),
        isFalse,
      );
    },
  );

  testWidgets(
    'authenticated standard invite auto-accepts when auto-join flag set',
    (tester) async {
      final settings = await tester.runAsync(initializeHisabSettings);
      expect(settings, isNotNull);
      settings!.controller.set(pendingInviteAutoJoinSettingDef, true);

      final repo = _FakeGroupInviteRepository(
        // Stay on page after accept attempt (nav needs sync/DB mocks).
        acceptErrorMessage: 'Already a member of this group',
        invite: makeInvite(),
        group: makeGroup(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hisabSettingsProvidersProvider.overrideWithValue(settings),
            effectiveLocalOnlyProvider.overrideWith((ref) => false),
            connectivityProvider.overrideWithValue(true),
            isAuthenticatedProvider.overrideWith((ref) => true),
            authServiceProvider.overrideWith((ref) => _FakeAuthService()),
            groupInviteRepositoryProvider.overrideWithValue(repo),
          ],
          child: EasyLocalization(
            path: 'assets/translations',
            supportedLocales: testSupportedLocales,
            fallbackLocale: const Locale('en'),
            startLocale: const Locale('en'),
            child: const MaterialApp(
              home: InviteAcceptPage(token: 'token-1'),
            ),
          ),
        ),
      );
      await pumpInviteAutoJoinFrames(tester);

      expect(repo.acceptCalls, 1);
    },
  );

  testWidgets(
    'authenticated does not auto-accept when auto-join flag is off',
    (tester) async {
      final settings = await tester.runAsync(initializeHisabSettings);
      expect(settings, isNotNull);
      settings!.controller.set(pendingInviteAutoJoinSettingDef, false);

      final repo = _FakeGroupInviteRepository(
        invite: makeInvite().copyWith(
          accessMode: InviteAccessMode.readonlyJoin,
        ),
        group: makeGroup(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hisabSettingsProvidersProvider.overrideWithValue(settings),
            effectiveLocalOnlyProvider.overrideWith((ref) => false),
            connectivityProvider.overrideWithValue(true),
            isAuthenticatedProvider.overrideWith((ref) => true),
            authServiceProvider.overrideWith((ref) => _FakeAuthService()),
            groupInviteRepositoryProvider.overrideWithValue(repo),
          ],
          child: EasyLocalization(
            path: 'assets/translations',
            supportedLocales: testSupportedLocales,
            fallbackLocale: const Locale('en'),
            startLocale: const Locale('en'),
            child: const MaterialApp(
              home: InviteAcceptPage(token: 'token-1'),
            ),
          ),
        ),
      );
      await pumpInviteAutoJoinFrames(tester);

      expect(repo.acceptCalls, 0);
    },
  );

  testWidgets(
    'readonly_only never auto-accepts even with auto-join flag',
    (tester) async {
      final settings = await tester.runAsync(initializeHisabSettings);
      expect(settings, isNotNull);
      settings!.controller.set(pendingInviteAutoJoinSettingDef, true);

      final repo = _FakeGroupInviteRepository(
        invite: makeInvite().copyWith(
          accessMode: InviteAccessMode.readonlyOnly,
        ),
        group: makeGroup(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hisabSettingsProvidersProvider.overrideWithValue(settings),
            effectiveLocalOnlyProvider.overrideWith((ref) => false),
            connectivityProvider.overrideWithValue(true),
            isAuthenticatedProvider.overrideWith((ref) => true),
            authServiceProvider.overrideWith((ref) => _FakeAuthService()),
            groupInviteRepositoryProvider.overrideWithValue(repo),
          ],
          child: EasyLocalization(
            path: 'assets/translations',
            supportedLocales: testSupportedLocales,
            fallbackLocale: const Locale('en'),
            startLocale: const Locale('en'),
            child: const MaterialApp(
              home: InviteAcceptPage(token: 'token-1'),
            ),
          ),
        ),
      );
      await pumpInviteAutoJoinFrames(tester);

      expect(repo.acceptCalls, 0);
    },
  );

  testWidgets(
    'local-only authenticated does not auto-accept with auto-join flag',
    (tester) async {
      final settings = await tester.runAsync(initializeHisabSettings);
      expect(settings, isNotNull);
      settings!.controller.set(pendingInviteAutoJoinSettingDef, true);

      final repo = _FakeGroupInviteRepository(
        invite: makeInvite().copyWith(
          accessMode: InviteAccessMode.readonlyJoin,
        ),
        group: makeGroup(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hisabSettingsProvidersProvider.overrideWithValue(settings),
            effectiveLocalOnlyProvider.overrideWith((ref) => true),
            connectivityProvider.overrideWithValue(true),
            isAuthenticatedProvider.overrideWith((ref) => true),
            authServiceProvider.overrideWith((ref) => _FakeAuthService()),
            groupInviteRepositoryProvider.overrideWithValue(repo),
          ],
          child: EasyLocalization(
            path: 'assets/translations',
            supportedLocales: testSupportedLocales,
            fallbackLocale: const Locale('en'),
            startLocale: const Locale('en'),
            child: const MaterialApp(
              home: InviteAcceptPage(token: 'token-1'),
            ),
          ),
        ),
      );
      await pumpInviteAutoJoinFrames(tester);

      expect(repo.acceptCalls, 0);
    },
  );

  testWidgets(
    'auto-join accepts at most once even if widget rebuilds',
    (tester) async {
      final settings = await tester.runAsync(initializeHisabSettings);
      expect(settings, isNotNull);
      settings!.controller.set(pendingInviteAutoJoinSettingDef, true);

      final repo = _FakeGroupInviteRepository(
        acceptErrorMessage: 'Already a member of this group',
        invite: makeInvite(),
        group: makeGroup(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hisabSettingsProvidersProvider.overrideWithValue(settings),
            effectiveLocalOnlyProvider.overrideWith((ref) => false),
            connectivityProvider.overrideWithValue(true),
            isAuthenticatedProvider.overrideWith((ref) => true),
            authServiceProvider.overrideWith((ref) => _FakeAuthService()),
            groupInviteRepositoryProvider.overrideWithValue(repo),
          ],
          child: EasyLocalization(
            path: 'assets/translations',
            supportedLocales: testSupportedLocales,
            fallbackLocale: const Locale('en'),
            startLocale: const Locale('en'),
            child: const MaterialApp(
              home: InviteAcceptPage(token: 'token-1'),
            ),
          ),
        ),
      );
      await pumpInviteAutoJoinFrames(tester);
      // Re-enable flag and force another frame (simulates setting flicker).
      settings.controller.set(pendingInviteAutoJoinSettingDef, true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(repo.acceptCalls, 1);
    },
  );

  testWidgets('accept error for expired invite surfaces message', (tester) async {
    final settings = await tester.runAsync(initializeHisabSettings);
    expect(settings, isNotNull);
    settings!.controller.set(pendingInviteAutoJoinSettingDef, true);

    final repo = _FakeGroupInviteRepository(
      acceptErrorMessage: 'This invite has expired',
      invite: makeInvite(),
      group: makeGroup(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hisabSettingsProvidersProvider.overrideWithValue(settings),
          effectiveLocalOnlyProvider.overrideWith((ref) => false),
          connectivityProvider.overrideWithValue(true),
          isAuthenticatedProvider.overrideWith((ref) => true),
          authServiceProvider.overrideWith((ref) => _FakeAuthService()),
          groupInviteRepositoryProvider.overrideWithValue(repo),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: testSupportedLocales,
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(
            home: InviteAcceptPage(token: 'token-1'),
          ),
        ),
      ),
    );
    await pumpInviteAutoJoinFrames(tester);

    expect(repo.acceptCalls, 1);
    expect(find.textContaining('expired'), findsOneWidget);
  });
}
