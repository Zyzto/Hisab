import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/database_providers.dart';
import 'group_repository.dart';
import 'participant_repository.dart';
import 'expense_repository.dart';
import 'group_member_repository.dart';
import 'tag_repository.dart';
import 'powersync_repository.dart';
import 'household_balance_reassignment_repository.dart';

part 'repository_providers.g.dart';

@riverpod
IGroupRepository groupRepository(Ref ref) {
  return PowerSyncGroupRepository(
    ref.watch(powerSyncDatabaseProvider),
  );
}

@riverpod
IParticipantRepository participantRepository(Ref ref) {
  return PowerSyncParticipantRepository(
    ref.watch(powerSyncDatabaseProvider),
  );
}

@riverpod
IExpenseRepository expenseRepository(Ref ref) {
  return PowerSyncExpenseRepository(
    ref.watch(powerSyncDatabaseProvider),
  );
}

@riverpod
IHouseholdBalanceReassignmentRepository householdBalanceReassignmentRepository(
  Ref ref,
) {
  return PowerSyncHouseholdBalanceReassignmentRepository(
    ref.watch(powerSyncDatabaseProvider),
  );
}

@riverpod
ITagRepository tagRepository(Ref ref) {
  return PowerSyncTagRepository(
    ref.watch(powerSyncDatabaseProvider),
  );
}

@riverpod
IGroupMemberRepository groupMemberRepository(Ref ref) {
  return PowerSyncGroupMemberRepository(ref.watch(powerSyncDatabaseProvider));
}
