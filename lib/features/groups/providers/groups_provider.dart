import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../domain/domain.dart';

part 'groups_provider.g.dart';

@riverpod
Stream<List<Group>> groups(Ref ref) {
  return ref.watch(groupRepositoryProvider).watchAll();
}

@riverpod
Stream<List<Group>> archivedGroups(Ref ref) {
  return ref.watch(groupRepositoryProvider).watchArchived();
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
