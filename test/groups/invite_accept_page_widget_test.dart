import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hisab/core/auth/auth_service.dart';
import 'package:hisab/core/auth/auth_user_profile.dart';
import 'package:hisab/core/auth/auth_providers.dart';
import 'package:hisab/core/repository/group_invite_repository.dart';
import 'package:hisab/core/repository/repository_providers.dart';
import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/groups/pages/invite_accept_page.dart';
import 'package:hisab/features/settings/providers/settings_framework_providers.dart';

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
  Future<String> accept(String token, {String? newParticipantName}) async {
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

void main() {
  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
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
    {bool authenticated = true}
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveLocalOnlyProvider.overrideWith((ref) => false),
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
}
