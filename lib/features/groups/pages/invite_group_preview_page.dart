import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_content.dart';
import '../../../domain/domain.dart';
import '../../expenses/pages/expense_detail_shell.dart';
import '../../expenses/widgets/expense_detail_body.dart';
import '../providers/group_member_provider.dart';
import '../providers/groups_provider.dart';
import '../providers/invite_preview_provider.dart';
import 'group_detail_page.dart';

class InviteGroupPreviewPage extends ConsumerWidget {
  const InviteGroupPreviewPage({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewAsync = ref.watch(invitePreviewDataProvider(token));
    return previewAsync.when(
      data: (preview) {
        if (preview == null) {
          return Scaffold(
            body: Center(
              child: Text(
                'invite_expired'.tr(),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }
        return ProviderScope(
          overrides: [..._buildPreviewOverrides(preview)],
          child: GroupDetailPage(
            groupId: preview.group.id,
            readOnlyPreview: true,
            previewToken: token,
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(
        body: Center(
          child: ErrorContentWidget(
            message: e.toString(),
            details: e.toString(),
            stackTrace: st,
            onRetry: () => ref.invalidate(invitePreviewDataProvider(token)),
          ),
        ),
      ),
    );
  }
}

class InvitePreviewExpenseDetailPage extends ConsumerWidget {
  const InvitePreviewExpenseDetailPage({
    super.key,
    required this.token,
    required this.expenseId,
  });

  final String token;
  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewAsync = ref.watch(invitePreviewDataProvider(token));
    return previewAsync.when(
      data: (preview) {
        if (preview == null) {
          return Scaffold(
            body: Center(
              child: Text(
                'invite_expired'.tr(),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }
        final groupId = preview.group.id;
        final found = preview.expenses.any((e) => e.id == expenseId);
        if (!found) {
          return Scaffold(
            body: Center(
              child: Text(
                'invite_expired'.tr(),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }
        return ProviderScope(
          overrides: [..._buildPreviewOverrides(preview)],
          child: ExpenseDetailShell(
            groupId: groupId,
            expenseId: expenseId,
            readOnlyPreview: true,
            previewToken: token,
            child: ExpenseDetailBody(groupId: groupId, expenseId: expenseId),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(
        body: Center(
          child: ErrorContentWidget(
            message: e.toString(),
            details: e.toString(),
            stackTrace: st,
            onRetry: () => ref.invalidate(invitePreviewDataProvider(token)),
          ),
        ),
      ),
    );
  }
}

Iterable<dynamic> _buildPreviewOverrides(InvitePreviewData preview) {
  final groupId = preview.group.id;
  final activeParticipants = preview.participants
      .where((p) => p.leftAt == null)
      .toList();
  final members = <GroupMember>[];
  preview.participantRoles.forEach((participantId, role) {
    if (role == null || role.isEmpty) return;
    members.add(
      GroupMember(
        id: 'preview-$participantId',
        groupId: groupId,
        userId: 'preview-user-$participantId',
        role: role,
        participantId: participantId,
        joinedAt: preview.group.createdAt,
      ),
    );
  });

  return [
    futureGroupProvider(groupId).overrideWith((ref) async => preview.group),
    participantsByGroupProvider(
      groupId,
    ).overrideWith((ref) => Stream.value(preview.participants)),
    activeParticipantsByGroupProvider(
      groupId,
    ).overrideWith((ref) => Stream.value(activeParticipants)),
    expensesByGroupProvider(
      groupId,
    ).overrideWith((ref) => Stream.value(preview.expenses)),
    tagsByGroupProvider(
      groupId,
    ).overrideWith((ref) => Stream.value(const <ExpenseTag>[])),
    myRoleInGroupProvider(groupId).overrideWith((ref) async => null),
    myMemberInGroupProvider(groupId).overrideWith((ref) async => null),
    membersByGroupProvider(groupId).overrideWith((ref) => Stream.value(members)),
  ];
}
