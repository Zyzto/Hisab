import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../domain/domain.dart';

part 'group_member_provider.g.dart';

@riverpod
Stream<GroupMember?> myMemberInGroup(Ref ref, String groupId) {
  return ref.watch(groupMemberRepositoryProvider).watchMyMember(groupId);
}

@riverpod
Stream<GroupRole?> myRoleInGroup(Ref ref, String groupId) {
  // Same source as myMemberInGroup; fingerprint-gated web poll shares the cost.
  return ref
      .watch(groupMemberRepositoryProvider)
      .watchMyMember(groupId)
      .map((m) => m == null ? null : GroupRole.fromString(m.role));
}

@riverpod
Stream<List<GroupMember>> membersByGroup(Ref ref, String groupId) {
  return ref.watch(groupMemberRepositoryProvider).watchByGroup(groupId);
}
