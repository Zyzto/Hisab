import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../domain/domain.dart';
import '../../expenses/providers/pending_expense_deletion_provider.dart';

part 'groups_provider.g.dart';

@riverpod
Stream<List<Group>> groups(Ref ref) {
  final repo = ref.watch(groupRepositoryProvider);
  return _combineExcludingLocalArchived(
    repo.watchAll(),
    repo.watchLocallyArchivedGroupIds(),
  );
}

/// Emits when either stream emits, excluding groups whose id is in [localArchivedIds].
Stream<List<Group>> _combineExcludingLocalArchived(
  Stream<List<Group>> allGroups,
  Stream<Set<String>> localArchivedIds,
) {
  List<Group>? latestGroups;
  Set<String> latestIds = {};
  final ctrl = StreamController<List<Group>>(sync: true);
  void emit() {
    if (latestGroups != null) {
      ctrl.add(latestGroups!.where((g) => !latestIds.contains(g.id)).toList());
    }
  }

  final sub1 = allGroups.listen((v) {
    latestGroups = v;
    emit();
  });
  final sub2 = localArchivedIds.listen((v) {
    latestIds = v;
    emit();
  });
  ctrl.onCancel = () async {
    await sub1.cancel();
    await sub2.cancel();
  };
  return ctrl.stream;
}

@riverpod
Stream<List<Group>> archivedGroups(Ref ref) {
  return ref.watch(groupRepositoryProvider).watchArchived();
}

@riverpod
Stream<List<Group>> locallyArchivedGroups(Ref ref) {
  return ref.watch(groupRepositoryProvider).watchLocallyArchivedGroups();
}

@riverpod
Stream<Set<String>> locallyArchivedGroupIds(Ref ref) {
  return ref.watch(groupRepositoryProvider).watchLocallyArchivedGroupIds();
}

/// Kept name `futureGroup` for call-site stability; backed by a live stream
/// so group detail/settings/balance refresh after remote sync.
@riverpod
Stream<Group?> futureGroup(Ref ref, String groupId) {
  return ref.watch(groupRepositoryProvider).watchById(groupId);
}

@riverpod
Stream<List<Expense>> expensesByGroup(Ref ref, String groupId) {
  final pendingIds = ref.watch(pendingExpenseDeletionProvider);
  return ref
      .watch(expenseRepositoryProvider)
      .watchByGroupId(groupId)
      .map(
        (expenses) => expenses
            .where((expense) => !pendingIds.contains(expense.id))
            .toList(),
      );
}

@riverpod
Stream<Expense?> futureExpense(Ref ref, String expenseId) {
  if (ref.watch(pendingExpenseDeletionProvider).contains(expenseId)) {
    return Stream<Expense?>.value(null);
  }
  return ref.watch(expenseRepositoryProvider).watchById(expenseId);
}

@riverpod
Stream<List<Participant>> participantsByGroup(Ref ref, String groupId) {
  return ref.watch(participantRepositoryProvider).watchByGroupId(groupId);
}

@riverpod
Stream<List<HouseholdBalanceReassignment>> householdReassignmentsByGroup(
  Ref ref,
  String groupId,
) {
  return ref
      .watch(householdBalanceReassignmentRepositoryProvider)
      .watchByGroupId(groupId);
}

/// Active participants only (left_at == null). Use for new expenses and balance
/// so left/archived members do not count towards splits or settlements.
@riverpod
Stream<List<Participant>> activeParticipantsByGroup(Ref ref, String groupId) {
  return ref
      .watch(participantRepositoryProvider)
      .watchByGroupId(groupId)
      .map(
        (participants) => participants.where((p) => p.leftAt == null).toList(),
      );
}

/// Participants needed to explain historical household balances. Archived
/// rows with no named children remain visible as historical roots; archived
/// parents with promoted branches are represented by reassignment records.
@riverpod
Stream<List<Participant>> balanceParticipantsByGroup(Ref ref, String groupId) {
  return ref.watch(participantRepositoryProvider).watchByGroupId(groupId).map((
    participants,
  ) {
    final hasChildren = <String>{
      for (final p in participants)
        if (p.parentParticipantId != null) p.parentParticipantId!,
    };
    return participants
        .where((p) => p.leftAt == null || !hasChildren.contains(p.id))
        .toList();
  });
}

@riverpod
Stream<List<ExpenseTag>> tagsByGroup(Ref ref, String groupId) {
  return ref.watch(tagRepositoryProvider).watchByGroupId(groupId);
}
