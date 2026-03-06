import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hisab/core/repository/expense_repository.dart';
import 'package:hisab/core/repository/group_repository.dart';
import 'package:hisab/core/repository/participant_repository.dart';
import 'package:hisab/core/repository/repository_providers.dart';
import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/expenses/pages/expense_form_page.dart';
import 'package:hisab/features/groups/pages/group_settings_page.dart';
import 'package:hisab/features/groups/providers/group_member_provider.dart';
import 'package:hisab/features/groups/providers/groups_provider.dart';
import 'package:hisab/features/settings/providers/settings_framework_providers.dart';

import '../widget_test_helpers.dart';

void main() {
  const groupId = 'g1';
  final now = DateTime(2026, 1, 10);
  final memberParticipant = Participant(
    id: 'p1',
    groupId: groupId,
    name: 'Member One',
    order: 0,
    userId: 'u1',
    createdAt: now,
    updatedAt: now,
  );

  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets(
    'Group settings is read-only for member when change settings is disabled',
    (tester) async {
      final group = Group(
        id: groupId,
        name: 'Trip',
        currencyCode: 'USD',
        createdAt: now,
        updatedAt: now,
        allowMemberChangeSettings: false,
        isPersonal: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveLocalOnlyProvider.overrideWith((ref) => false),
            futureGroupProvider(
              groupId,
            ).overrideWithValue(AsyncValue.data(group)),
            expensesByGroupProvider(
              groupId,
            ).overrideWithValue(const AsyncValue.data(<Expense>[])),
            activeParticipantsByGroupProvider(
              groupId,
            ).overrideWithValue(const AsyncValue.data(<Participant>[])),
            locallyArchivedGroupIdsProvider.overrideWithValue(
              const AsyncValue.data(<String>{}),
            ),
            myRoleInGroupProvider(
              groupId,
            ).overrideWithValue(const AsyncValue.data(GroupRole.member)),
          ],
          child: EasyLocalization(
            path: 'assets/translations',
            supportedLocales: testSupportedLocales,
            fallbackLocale: const Locale('en'),
            startLocale: const Locale('en'),
            child: const MaterialApp(home: GroupSettingsPage(groupId: groupId)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      final switches = tester.widgetList<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switches.isNotEmpty, isTrue);
      expect(switches.every((s) => s.onChanged == null), isTrue);
    },
  );

  testWidgets(
    'Expense save is blocked for member when add expense is disabled',
    (tester) async {
      final group = Group(
        id: groupId,
        name: 'Trip',
        currencyCode: 'USD',
        createdAt: now,
        updatedAt: now,
        allowMemberAddExpense: false,
        allowExpenseAsOtherParticipant: true,
        isPersonal: false,
      );
      final member = GroupMember(
        id: 'm1',
        groupId: groupId,
        userId: 'u1',
        role: 'member',
        participantId: memberParticipant.id,
        joinedAt: now,
      );
      final fakeGroupRepo = _FakeGroupRepository(group);
      final fakeParticipantRepo = _FakeParticipantRepository([
        memberParticipant,
      ]);
      final fakeExpenseRepo = _FakeExpenseRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveLocalOnlyProvider.overrideWith((ref) => false),
            groupRepositoryProvider.overrideWithValue(fakeGroupRepo),
            participantRepositoryProvider.overrideWithValue(
              fakeParticipantRepo,
            ),
            expenseRepositoryProvider.overrideWithValue(fakeExpenseRepo),
            futureGroupProvider(
              groupId,
            ).overrideWithValue(AsyncValue.data(group)),
            participantsByGroupProvider(
              groupId,
            ).overrideWithValue(AsyncValue.data([memberParticipant])),
            activeParticipantsByGroupProvider(
              groupId,
            ).overrideWithValue(AsyncValue.data([memberParticipant])),
            tagsByGroupProvider(
              groupId,
            ).overrideWithValue(const AsyncValue.data(<ExpenseTag>[])),
            myRoleInGroupProvider(
              groupId,
            ).overrideWithValue(const AsyncValue.data(GroupRole.member)),
            myMemberInGroupProvider(
              groupId,
            ).overrideWithValue(AsyncValue.data(member)),
          ],
          child: EasyLocalization(
            path: 'assets/translations',
            supportedLocales: testSupportedLocales,
            fallbackLocale: const Locale('en'),
            startLocale: const Locale('en'),
            child: const MaterialApp(home: ExpenseFormPage(groupId: groupId)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      expect(textFields, findsWidgets);
      await tester.enterText(textFields.at(0), 'Lunch');
      await tester.enterText(textFields.at(1), '12');
      await tester.pumpAndSettle();

      final submitButton = find.byType(FilledButton).last;
      expect(submitButton, findsOneWidget);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(fakeParticipantRepo.getByGroupCalls, greaterThanOrEqualTo(1));
      expect(fakeGroupRepo.getByIdCalls, greaterThanOrEqualTo(1));
      expect(fakeExpenseRepo.createCalls, 0);
      await tester.pump(const Duration(seconds: 5));
    },
  );
}

class _FakeGroupRepository implements IGroupRepository {
  _FakeGroupRepository(this.group);

  final Group group;
  int getByIdCalls = 0;

  @override
  Future<Group?> getById(String id) async {
    getByIdCalls += 1;
    return id == group.id ? group : null;
  }

  @override
  Future<List<Group>> getAll() async => [group];

  @override
  Stream<List<Group>> watchAll() => Stream.value([group]);

  @override
  Stream<List<Group>> watchArchived() => const Stream.empty();

  @override
  Future<String> create(
    String name,
    String currencyCode, {
    String? icon,
    int? color,
    List<String> initialParticipants = const [],
    bool isPersonal = false,
    int? budgetAmountCents,
  }) async => group.id;

  @override
  Future<void> update(Group group) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> freezeSettlement(
    String groupId,
    SettlementSnapshot snapshot,
  ) async {}

  @override
  Future<void> unfreezeSettlement(String groupId) async {}

  @override
  Future<void> archive(String groupId) async {}

  @override
  Future<void> unarchive(String groupId) async {}

  @override
  Future<void> setLocalArchived(String groupId) async {}

  @override
  Future<void> clearLocalArchived(String groupId) async {}

  @override
  Future<Set<String>> getLocallyArchivedGroupIds() async => <String>{};

  @override
  Stream<Set<String>> watchLocallyArchivedGroupIds() =>
      Stream.value(<String>{});

  @override
  Stream<List<Group>> watchLocallyArchivedGroups() => const Stream.empty();
}

class _FakeParticipantRepository implements IParticipantRepository {
  _FakeParticipantRepository(this.participants);

  final List<Participant> participants;
  int getByGroupCalls = 0;

  @override
  Future<List<Participant>> getAll() async => participants;

  @override
  Future<List<Participant>> getByGroupId(String groupId) async {
    getByGroupCalls += 1;
    return participants;
  }

  @override
  Stream<List<Participant>> watchByGroupId(String groupId) =>
      Stream.value(participants);

  @override
  Future<Participant?> getById(String id) async {
    for (final p in participants) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<String> create(
    String groupId,
    String name,
    int order, {
    String? userId,
    String? avatarId,
  }) async => 'new-participant';

  @override
  Future<void> update(Participant participant) async {}

  @override
  Future<void> updateProfileByUserId(
    String userId,
    String newName, {
    String? avatarId,
  }) async {}

  @override
  Future<void> archive(String groupId, String participantId) async {}

  @override
  Future<void> delete(String id) async {}
}

class _FakeExpenseRepository implements IExpenseRepository {
  int createCalls = 0;

  @override
  Future<List<Expense>> getAll() async => const <Expense>[];

  @override
  Future<List<Expense>> getByGroupId(String groupId) async => const <Expense>[];

  @override
  Stream<List<Expense>> watchByGroupId(String groupId) => const Stream.empty();

  @override
  Future<Expense?> getById(String id) async => null;

  @override
  Future<String> create(Expense expense) async {
    createCalls += 1;
    return 'e1';
  }

  @override
  Future<void> update(Expense expense) async {}

  @override
  Future<void> delete(String id) async {}
}
