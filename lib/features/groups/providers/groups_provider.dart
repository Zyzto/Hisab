import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../domain/domain.dart';

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
      ctrl.add(
        latestGroups!
            .where((g) => !latestIds.contains(g.id))
            .toList(),
      );
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

@riverpod
Future<Group?> futureGroup(Ref ref, String groupId) async {
  return ref.read(groupRepositoryProvider).getById(groupId);
}

@riverpod
Stream<List<Expense>> expensesByGroup(Ref ref, String groupId) {
  return ref.watch(expenseRepositoryProvider).watchByGroupId(groupId);
}

@riverpod
Future<Expense?> futureExpense(Ref ref, String expenseId) async {
  return ref.read(expenseRepositoryProvider).getById(expenseId);
}

@riverpod
Stream<List<Participant>> participantsByGroup(Ref ref, String groupId) {
  return ref.watch(participantRepositoryProvider).watchByGroupId(groupId);
}

@riverpod
Stream<List<ExpenseTag>> tagsByGroup(Ref ref, String groupId) {
  return ref.watch(tagRepositoryProvider).watchByGroupId(groupId);
}
