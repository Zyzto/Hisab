import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../daos/group_dao.dart';
import '../daos/participant_dao.dart';
import '../daos/expense_dao.dart';
import '../daos/expense_tag_dao.dart';
import 'database_provider.dart';

part 'dao_providers.g.dart';

@riverpod
GroupDao groupDao(Ref ref) {
  return GroupDao(ref.watch(databaseProvider));
}

@riverpod
ParticipantDao participantDao(Ref ref) {
  return ParticipantDao(ref.watch(databaseProvider));
}

@riverpod
ExpenseDao expenseDao(Ref ref) {
  return ExpenseDao(ref.watch(databaseProvider));
}

@riverpod
ExpenseTagDao expenseTagDao(Ref ref) {
  return ExpenseTagDao(ref.watch(databaseProvider));
}
