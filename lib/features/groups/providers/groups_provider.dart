import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../domain/domain.dart';

final groupsProvider = StreamProvider<List<Group>>((ref) {
  return ref.watch(groupRepositoryProvider).watchAll();
});

final futureGroupProvider = FutureProvider.family<Group?, String>((
  ref,
  groupId,
) async {
  return ref.read(groupRepositoryProvider).getById(groupId);
});

final expensesByGroupProvider = StreamProvider.family<List<Expense>, String>((
  ref,
  groupId,
) {
  return ref.watch(expenseRepositoryProvider).watchByGroupId(groupId);
});

final futureExpenseProvider = FutureProvider.family<Expense?, String>((
  ref,
  expenseId,
) async {
  return ref.read(expenseRepositoryProvider).getById(expenseId);
});

final participantsByGroupProvider =
    StreamProvider.family<List<Participant>, String>((ref, groupId) {
      return ref.watch(participantRepositoryProvider).watchByGroupId(groupId);
    });

final tagsByGroupProvider = StreamProvider.family<List<ExpenseTag>, String>((
  ref,
  groupId,
) {
  return ref.watch(tagRepositoryProvider).watchByGroupId(groupId);
});
