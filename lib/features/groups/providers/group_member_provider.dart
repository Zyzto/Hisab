import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../domain/domain.dart';

part 'group_member_provider.g.dart';

@riverpod
Future<GroupRole?> myRoleInGroup(Ref ref, String groupId) async {
  return ref.watch(groupMemberRepositoryProvider).getMyRole(groupId);
}

@riverpod
Future<GroupMember?> myMemberInGroup(Ref ref, String groupId) async {
  return ref.watch(groupMemberRepositoryProvider).getMyMember(groupId);
}

@riverpod
Stream<List<GroupMember>> membersByGroup(Ref ref, String groupId) {
  return ref.watch(groupMemberRepositoryProvider).watchByGroup(groupId);
}
