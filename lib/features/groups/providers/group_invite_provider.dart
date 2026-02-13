import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../domain/domain.dart';

part 'group_invite_provider.g.dart';

@riverpod
Future<({GroupInvite invite, Group group})?> inviteByToken(
  Ref ref,
  String token,
) async {
  return ref.watch(groupInviteRepositoryProvider).getByToken(token);
}

@riverpod
Stream<List<GroupInvite>> invitesByGroup(Ref ref, String groupId) {
  return ref.watch(groupInviteRepositoryProvider).watchByGroup(groupId);
}

@riverpod
Stream<List<InviteUsage>> inviteUsages(Ref ref, String inviteId) {
  return ref.watch(groupInviteRepositoryProvider).watchUsages(inviteId);
}
