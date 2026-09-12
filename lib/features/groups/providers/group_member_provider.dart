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
  return ref
      .watch(groupMemberRepositoryProvider)
      .watchMyMember(groupId)
      .map((member) => member == null ? null : GroupRole.fromString(member.role));
}

@riverpod
Stream<List<GroupMember>> membersByGroup(Ref ref, String groupId) {
  return ref.watch(groupMemberRepositoryProvider).watchByGroup(groupId);
}
