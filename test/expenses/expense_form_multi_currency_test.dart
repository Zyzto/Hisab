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
import 'package:hisab/features/groups/providers/group_member_provider.dart';
import 'package:hisab/features/groups/providers/groups_provider.dart';
import 'package:hisab/features/settings/providers/settings_framework_providers.dart';

import '../widget_test_helpers.dart';

void main() {
  const groupId = 'g1';
  final now = DateTime(2026, 1, 10);
  final participant = Participant(
    id: 'p1',
    groupId: groupId,
    name: 'Member One',
    order: 0,
    userId: 'u1',
    createdAt: now,
    updatedAt: now,
  );
  final member = GroupMember(
    id: 'm1',
    groupId: groupId,
    userId: 'u1',
    role: 'owner',
    participantId: participant.id,
    joinedAt: now,
  );

  setUpAll(() {
    EasyLocalization.logger.enableBuildModes = [];
  });

  testWidgets('typing in converted amount field does not overwrite it (multi-currency)', (tester) async {
    final group = Group(
      id: groupId,
      name: 'Trip',
      currencyCode: 'SAR',
      createdAt: now,
      updatedAt: now,
      isPersonal: false,
    );
    const expenseId = 'e1';
    final expense = Expense(
      id: expenseId,
      groupId: groupId,
      payerParticipantId: participant.id,
      amountCents: 10000,
      currencyCode: 'USD',
      exchangeRate: 100 / 375,
      baseAmountCents: 37500,
      title: 'Coffee',
      date: now,
      splitType: SplitType.equal,
      splitShares: {participant.id: 10000},
      createdAt: now,
      updatedAt: now,
    );
    final fakeGroupRepo = FakeGroupRepository(group);
    final fakeParticipantRepo = FakeParticipantRepository([participant]);
    final fakeExpenseRepo = FakeExpenseRepositoryWithGetById(expense);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveLocalOnlyProvider.overrideWith((ref) => false),
          groupRepositoryProvider.overrideWithValue(fakeGroupRepo),
          participantRepositoryProvider.overrideWithValue(fakeParticipantRepo),
          expenseRepositoryProvider.overrideWithValue(fakeExpenseRepo),
          futureGroupProvider(groupId).overrideWithValue(AsyncValue.data(group)),
          participantsByGroupProvider(groupId).overrideWithValue(AsyncValue.data([participant])),
          activeParticipantsByGroupProvider(groupId).overrideWithValue(AsyncValue.data([participant])),
          tagsByGroupProvider(groupId).overrideWithValue(const AsyncValue.data(<ExpenseTag>[])),
          myRoleInGroupProvider(groupId).overrideWithValue(AsyncValue.data(GroupRole.owner)),
          myMemberInGroupProvider(groupId).overrideWithValue(AsyncValue.data(member)),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: testSupportedLocales,
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(
            home: ExpenseFormPage(groupId: groupId, expenseId: expenseId),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final baseAmountFinder = find.byKey(const Key('expense_form_base_amount'));
    expect(baseAmountFinder, findsOneWidget);
    await tester.enterText(baseAmountFinder, '376');
    await tester.pumpAndSettle();

    final baseAmountField = tester.widget<TextFormField>(baseAmountFinder);
    expect(baseAmountField.controller?.text, '376');
  });

  testWidgets('changing amount field updates converted amount (recalc runs)', (tester) async {
    final group = Group(
      id: groupId,
      name: 'Trip',
      currencyCode: 'SAR',
      createdAt: now,
      updatedAt: now,
      isPersonal: false,
    );
    const expenseId = 'e1';
    final expense = Expense(
      id: expenseId,
      groupId: groupId,
      payerParticipantId: participant.id,
      amountCents: 10000,
      currencyCode: 'USD',
      exchangeRate: 100 / 375,
      baseAmountCents: 37500,
      title: 'Lunch',
      date: now,
      splitType: SplitType.equal,
      splitShares: {participant.id: 10000},
      createdAt: now,
      updatedAt: now,
    );
    final fakeGroupRepo = FakeGroupRepository(group);
    final fakeParticipantRepo = FakeParticipantRepository([participant]);
    final fakeExpenseRepo = FakeExpenseRepositoryWithGetById(expense);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          effectiveLocalOnlyProvider.overrideWith((ref) => false),
          groupRepositoryProvider.overrideWithValue(fakeGroupRepo),
          participantRepositoryProvider.overrideWithValue(fakeParticipantRepo),
          expenseRepositoryProvider.overrideWithValue(fakeExpenseRepo),
          futureGroupProvider(groupId).overrideWithValue(AsyncValue.data(group)),
          participantsByGroupProvider(groupId).overrideWithValue(AsyncValue.data([participant])),
          activeParticipantsByGroupProvider(groupId).overrideWithValue(AsyncValue.data([participant])),
          tagsByGroupProvider(groupId).overrideWithValue(const AsyncValue.data(<ExpenseTag>[])),
          myRoleInGroupProvider(groupId).overrideWithValue(AsyncValue.data(GroupRole.owner)),
          myMemberInGroupProvider(groupId).overrideWithValue(AsyncValue.data(member)),
        ],
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: testSupportedLocales,
          fallbackLocale: const Locale('en'),
          startLocale: const Locale('en'),
          child: const MaterialApp(
            home: ExpenseFormPage(groupId: groupId, expenseId: expenseId),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final amountFieldFinder = find.byType(TextFormField).at(1);
    await tester.enterText(amountFieldFinder, '200');
    await tester.pumpAndSettle();

    final baseAmountFinder = find.byKey(const Key('expense_form_base_amount'));
    final baseAmountField = tester.widget<TextFormField>(baseAmountFinder);
    expect(baseAmountField.controller?.text, '750.00');
  });
}

class FakeGroupRepository implements IGroupRepository {
  FakeGroupRepository(this.group);

  final Group group;

  @override
  Future<Group?> getById(String id) async => id == group.id ? group : null;

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

class FakeParticipantRepository implements IParticipantRepository {
  FakeParticipantRepository(this.participants);

  final List<Participant> participants;

  @override
  Future<List<Participant>> getAll() async => participants;

  @override
  Future<List<Participant>> getByGroupId(String groupId) async =>
      participants;

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

class FakeExpenseRepository implements IExpenseRepository {
  @override
  Future<List<Expense>> getAll() async => const <Expense>[];

  @override
  Future<List<Expense>> getByGroupId(String groupId) async =>
      const <Expense>[];

  @override
  Stream<List<Expense>> watchByGroupId(String groupId) =>
      const Stream.empty();

  @override
  Future<Expense?> getById(String id) async => null;

  @override
  Future<String> create(Expense expense) async => 'e1';

  @override
  Future<void> update(Expense expense) async {}

  @override
  Future<void> delete(String id) async {}
}

class FakeExpenseRepositoryWithGetById implements IExpenseRepository {
  FakeExpenseRepositoryWithGetById(this.expense);

  final Expense expense;

  @override
  Future<List<Expense>> getAll() async => [expense];

  @override
  Future<List<Expense>> getByGroupId(String groupId) async =>
      groupId == expense.groupId ? [expense] : const <Expense>[];

  @override
  Stream<List<Expense>> watchByGroupId(String groupId) =>
      Stream.value(groupId == expense.groupId ? [expense] : const <Expense>[]);

  @override
  Future<Expense?> getById(String id) async =>
      id == expense.id ? expense : null;

  @override
  Future<String> create(Expense expense) async => 'e1';

  @override
  Future<void> update(Expense expense) async {}

  @override
  Future<void> delete(String id) async {}
}
