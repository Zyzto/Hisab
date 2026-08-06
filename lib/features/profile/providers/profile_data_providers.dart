import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repository/repository_providers.dart';
import '../../../domain/domain.dart';
import '../../groups/providers/groups_provider.dart';
import '../../transaction_scanner/providers/scanner_providers.dart';
import 'notification_providers.dart';

/// One DB watch for all expenses (avoids N per-group streams on profile).
final allExpensesProvider = StreamProvider<List<Expense>>((ref) {
  return ref.watch(expenseRepositoryProvider).watchAll();
});

/// One DB watch for all participants.
final allParticipantsProvider = StreamProvider<List<Participant>>((ref) {
  return ref.watch(participantRepositoryProvider).watchAll();
});

/// One DB watch for the signed-in user's memberships across groups.
final myMembershipsProvider = StreamProvider<List<GroupMember>>((ref) {
  return ref.watch(groupMemberRepositoryProvider).watchMyMembers();
});

/// Shared snapshot used by profile dashboard + my-expenses (single load gate).
class ProfileDataSnapshot {
  const ProfileDataSnapshot({
    required this.groups,
    required this.archived,
    required this.expensesByGroupId,
    required this.activeParticipantsByGroupId,
    required this.myParticipantIdByGroupId,
    required this.pendingDrafts,
    required this.unreadNotifications,
  });

  final List<Group> groups;
  final List<Group> archived;
  final Map<String, List<Expense>> expensesByGroupId;
  final Map<String, List<Participant>> activeParticipantsByGroupId;
  final Map<String, String> myParticipantIdByGroupId;
  final int pendingDrafts;
  final int unreadNotifications;
}

final profileDataSnapshotProvider = Provider<AsyncValue<ProfileDataSnapshot>>((
  ref,
) {
  final groupsAsync = ref.watch(groupsProvider);
  final archivedAsync = ref.watch(archivedGroupsProvider);
  final expensesAsync = ref.watch(allExpensesProvider);
  final participantsAsync = ref.watch(allParticipantsProvider);
  final membersAsync = ref.watch(myMembershipsProvider);
  // KPI badges only — never block the profile body on these.
  final drafts = ref.watch(pendingDraftCountProvider).asData?.value ?? 0;
  final unread = ref.watch(unreadNotificationCountProvider).asData?.value ?? 0;

  return _combineAsync5(
    groupsAsync,
    archivedAsync,
    expensesAsync,
    participantsAsync,
    membersAsync,
    (groups, archived, expenses, participants, members) {
      final groupIds = {for (final g in groups) g.id};

      final expensesByGroupId = <String, List<Expense>>{};
      for (final e in expenses) {
        if (!groupIds.contains(e.groupId)) continue;
        (expensesByGroupId[e.groupId] ??= []).add(e);
      }

      final activeParticipantsByGroupId = <String, List<Participant>>{};
      for (final p in participants) {
        if (!groupIds.contains(p.groupId) || p.leftAt != null) continue;
        (activeParticipantsByGroupId[p.groupId] ??= []).add(p);
      }

      final myParticipantIdByGroupId = <String, String>{
        for (final m in members)
          if (groupIds.contains(m.groupId) && m.participantId != null)
            m.groupId: m.participantId!,
      };

      return ProfileDataSnapshot(
        groups: groups,
        archived: archived,
        expensesByGroupId: expensesByGroupId,
        activeParticipantsByGroupId: activeParticipantsByGroupId,
        myParticipantIdByGroupId: myParticipantIdByGroupId,
        pendingDrafts: drafts,
        unreadNotifications: unread,
      );
    },
  );
});

AsyncValue<R> _combineAsync5<A, B, C, D, E, R>(
  AsyncValue<A> a,
  AsyncValue<B> b,
  AsyncValue<C> c,
  AsyncValue<D> d,
  AsyncValue<E> e,
  R Function(A a, B b, C c, D d, E e) combine,
) {
  if (a.hasError) {
    return AsyncValue.error(a.error!, a.stackTrace ?? StackTrace.current);
  }
  if (b.hasError) {
    return AsyncValue.error(b.error!, b.stackTrace ?? StackTrace.current);
  }
  if (c.hasError) {
    return AsyncValue.error(c.error!, c.stackTrace ?? StackTrace.current);
  }
  if (d.hasError) {
    return AsyncValue.error(d.error!, d.stackTrace ?? StackTrace.current);
  }
  if (e.hasError) {
    return AsyncValue.error(e.error!, e.stackTrace ?? StackTrace.current);
  }
  if (!a.hasValue || !b.hasValue || !c.hasValue || !d.hasValue || !e.hasValue) {
    return const AsyncValue.loading();
  }
  return AsyncValue.data(
    combine(
      a.value as A,
      b.value as B,
      c.value as C,
      d.value as D,
      e.value as E,
    ),
  );
}
