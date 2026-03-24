import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/route_paths.dart';
import '../../../core/services/settle_up_service.dart';
import '../../../core/widgets/error_content.dart';
import '../../../domain/domain.dart';
import '../../balance/providers/balance_provider.dart';
import '../../expenses/pages/expense_detail_shell.dart';
import '../../expenses/widgets/expense_detail_body.dart';
import '../providers/group_member_provider.dart';
import '../providers/groups_provider.dart';
import '../providers/invite_preview_provider.dart';
import 'group_detail_page.dart';

class InviteGroupPreviewPage extends ConsumerWidget {
  const InviteGroupPreviewPage({
    super.key,
    required this.token,
    this.initialTab = GroupDetailTab.expenses,
  });

  final String token;
  final GroupDetailTab initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewAsync = ref.watch(invitePreviewDataProvider(token));
    return previewAsync.when(
      data: (preview) {
        if (preview == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'invite_expired'.tr(),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () => context.go(RoutePaths.home),
                    icon: const Icon(Icons.home_outlined, size: 20),
                    label: Text('go_home'.tr()),
                  ),
                ],
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
            previewAccessMode: preview.invite.accessMode,
            initialTab: initialTab,
          ),
        );
      },
      loading: () => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => context.go(RoutePaths.home),
                icon: const Icon(Icons.home_outlined, size: 20),
                label: Text('go_home'.tr()),
              ),
            ],
          ),
        ),
      ),
      error: (e, st) => Scaffold(
        body: Center(
          child: ErrorContentWidget(
            message: e.toString(),
            details: e.toString(),
            stackTrace: st,
            onRetry: () => ref.invalidate(invitePreviewDataProvider(token)),
            onGoHome: () => context.go(RoutePaths.home),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'invite_expired'.tr(),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () => context.go(RoutePaths.home),
                    icon: const Icon(Icons.home_outlined, size: 20),
                    label: Text('go_home'.tr()),
                  ),
                ],
              ),
            ),
          );
        }
        final groupId = preview.group.id;
        final previewExpense = _previewExpenseById(preview, expenseId);
        if (previewExpense == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'invite_expired'.tr(),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () => context.go(RoutePaths.home),
                    icon: const Icon(Icons.home_outlined, size: 20),
                    label: Text('go_home'.tr()),
                  ),
                ],
              ),
            ),
          );
        }
        return ProviderScope(
          overrides: [
            ..._buildPreviewOverrides(preview),
            futureExpenseProvider(
              expenseId,
            ).overrideWith((ref) async => previewExpense),
          ],
          child: ExpenseDetailShell(
            groupId: groupId,
            expenseId: expenseId,
            readOnlyPreview: true,
            previewToken: token,
            child: ExpenseDetailBody(groupId: groupId, expenseId: expenseId),
          ),
        );
      },
      loading: () => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => context.go(RoutePaths.home),
                icon: const Icon(Icons.home_outlined, size: 20),
                label: Text('go_home'.tr()),
              ),
            ],
          ),
        ),
      ),
      error: (e, st) => Scaffold(
        body: Center(
          child: ErrorContentWidget(
            message: e.toString(),
            details: e.toString(),
            stackTrace: st,
            onRetry: () => ref.invalidate(invitePreviewDataProvider(token)),
            onGoHome: () => context.go(RoutePaths.home),
          ),
        ),
      ),
    );
  }
}

Expense? _previewExpenseById(InvitePreviewData preview, String expenseId) {
  for (final expense in preview.expenses) {
    if (expense.id == expenseId) return expense;
  }
  return null;
}

Iterable<dynamic> _buildPreviewOverrides(InvitePreviewData preview) {
  final groupId = preview.group.id;
  final activeParticipants = preview.participants
      .where((p) => p.leftAt == null)
      .toList();
  final balances = computeBalances(
    activeParticipants,
    preview.expenses,
    preview.group.currencyCode,
  );
  final settlements = computeSettlements(
    preview.group.settlementMethod,
    balances,
    activeParticipants,
    preview.expenses,
    preview.group.currencyCode,
    preview.group.treasurerParticipantId,
  );
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
    groupBalanceProvider(groupId).overrideWithValue(
      AsyncValue.data(
        GroupBalanceResult(
          group: preview.group,
          participants: activeParticipants,
          balances: balances,
          settlements: settlements,
        ),
      ),
    ),
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
