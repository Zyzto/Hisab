import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../database/providers/dao_providers.dart';
import '../../features/settings/providers/settings_framework_providers.dart';
import 'group_repository.dart';
import 'participant_repository.dart';
import 'expense_repository.dart';
import 'tag_repository.dart';
import 'local_repository.dart';
import 'convex_repository.dart';

part 'repository_providers.g.dart';

@riverpod
IGroupRepository groupRepository(Ref ref) {
  final useLocal = ref.watch(effectiveLocalOnlyProvider);
  Log.debug('Using ${useLocal ? "local" : "Convex"} repository');
  if (useLocal) {
    return LocalGroupRepository(ref.watch(groupDaoProvider));
  }
  return ConvexGroupRepository();
}

@riverpod
IParticipantRepository participantRepository(Ref ref) {
  final useLocal = ref.watch(effectiveLocalOnlyProvider);
  if (useLocal) {
    return LocalParticipantRepository(ref.watch(participantDaoProvider));
  }
  return ConvexParticipantRepository();
}

@riverpod
IExpenseRepository expenseRepository(Ref ref) {
  final useLocal = ref.watch(effectiveLocalOnlyProvider);
  if (useLocal) {
    return LocalExpenseRepository(ref.watch(expenseDaoProvider));
  }
  return ConvexExpenseRepository();
}

@riverpod
ITagRepository tagRepository(Ref ref) {
  final useLocal = ref.watch(effectiveLocalOnlyProvider);
  if (useLocal) {
    return LocalTagRepository(ref.watch(expenseTagDaoProvider));
  }
  return ConvexTagRepository();
}
