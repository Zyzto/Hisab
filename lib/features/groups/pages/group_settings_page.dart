import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/groups_provider.dart';
import '../providers/group_member_provider.dart';
import '../widgets/invite_link_sheet.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/services/settle_up_service.dart';
import '../../../core/telemetry/telemetry_service.dart';
import '../../../domain/domain.dart';
import '../../settings/providers/settings_framework_providers.dart';

class GroupSettingsPage extends ConsumerStatefulWidget {
  final String groupId;

  const GroupSettingsPage({super.key, required this.groupId});

  @override
  ConsumerState<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends ConsumerState<GroupSettingsPage> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(futureGroupProvider(widget.groupId));
    final participantsAsync = ref.watch(
      participantsByGroupProvider(widget.groupId),
    );
    final expensesAsync = ref.watch(expensesByGroupProvider(widget.groupId));
    final localOnly = ref.watch(effectiveLocalOnlyProvider);
    final myRoleAsync = localOnly
        ? const AsyncValue.data(null)
        : ref.watch(myRoleInGroupProvider(widget.groupId));

    return groupAsync.when(
      data: (group) {
        if (group == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text('settlement_settings'.tr()),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSettlementMethodSection(context, group, ref),
              const SizedBox(height: 24),
              if (group.settlementMethod == SettlementMethod.treasurer)
                _buildTreasurerSection(context, group, participantsAsync, ref),
              const SizedBox(height: 24),
              _buildFreezeSection(
                context,
                group,
                participantsAsync,
                expensesAsync,
                ref,
              ),
              if (!localOnly) ...[
                const SizedBox(height: 24),
                _buildOnlineSection(context, group, myRoleAsync, ref),
              ],
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text('settlement_settings'.tr())),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildSettlementMethodSection(
    BuildContext context,
    Group group,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'settlement_method'.tr(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        RadioGroup<SettlementMethod>(
          groupValue: group.settlementMethod,
          onChanged: (v) {
            if (!_saving && v != null) _onMethodChanged(ref, group, v);
          },
          child: Column(
            children: SettlementMethod.values
                .map(
                  (method) => RadioListTile<SettlementMethod>(
                    value: method,
                    title: Text(_methodLabel(method)),
                    subtitle: Text(_methodDescription(method)),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTreasurerSection(
    BuildContext context,
    Group group,
    AsyncValue<List<Participant>> participantsAsync,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    return participantsAsync.when(
      data: (participants) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'select_treasurer'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue:
                  group.treasurerParticipantId ??
                  (participants.isNotEmpty ? participants.first.id : null),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              items: participants
                  .map(
                    (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (v) => _onTreasurerChanged(ref, group, v),
            ),
          ],
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }

  Widget _buildFreezeSection(
    BuildContext context,
    Group group,
    AsyncValue<List<Participant>> participantsAsync,
    AsyncValue<List<Expense>> expensesAsync,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    final isFrozen = group.isSettlementFrozen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'settlement_freeze'.tr(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (isFrozen) ...[
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'settlement_frozen_since'.tr().replaceAll(
                      '{date}',
                      group.settlementFreezeAt != null
                          ? DateFormat.yMMMd().format(group.settlementFreezeAt!)
                          : '',
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'settlement_frozen_hint'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _saving ? null : () => _onUnfreeze(ref),
            icon: const Icon(Icons.play_circle_outline),
            label: Text('unfreeze_settlement'.tr()),
          ),
        ] else ...[
          Text(
            'settlement_freeze_description'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _saving
                ? null
                : () => _onFreeze(ref, group, participantsAsync, expensesAsync),
            icon: const Icon(Icons.pause_circle_outline),
            label: Text('freeze_settlement'.tr()),
          ),
        ],
      ],
    );
  }

  String _methodLabel(SettlementMethod m) {
    switch (m) {
      case SettlementMethod.pairwise:
        return 'settlement_method_pairwise'.tr();
      case SettlementMethod.greedy:
        return 'settlement_method_greedy'.tr();
      case SettlementMethod.consolidated:
        return 'settlement_method_consolidated'.tr();
      case SettlementMethod.treasurer:
        return 'settlement_method_treasurer'.tr();
    }
  }

  String _methodDescription(SettlementMethod m) {
    switch (m) {
      case SettlementMethod.pairwise:
        return 'settlement_method_pairwise_desc'.tr();
      case SettlementMethod.greedy:
        return 'settlement_method_greedy_desc'.tr();
      case SettlementMethod.consolidated:
        return 'settlement_method_consolidated_desc'.tr();
      case SettlementMethod.treasurer:
        return 'settlement_method_treasurer_desc'.tr();
    }
  }

  Future<void> _onMethodChanged(
    WidgetRef ref,
    Group group,
    SettlementMethod? method,
  ) async {
    if (method == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(groupRepositoryProvider)
          .update(
            group.copyWith(settlementMethod: method, updatedAt: DateTime.now()),
          );
      Log.info(
        'Settlement method changed: groupId=${widget.groupId} method=$method',
      );
      ref.invalidate(futureGroupProvider(widget.groupId));
    } catch (e, st) {
      Log.warning('Settlement method change failed', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onTreasurerChanged(
    WidgetRef ref,
    Group group,
    String? treasurerId,
  ) async {
    if (treasurerId == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(groupRepositoryProvider)
          .update(
            group.copyWith(
              treasurerParticipantId: treasurerId,
              updatedAt: DateTime.now(),
            ),
          );
      Log.info(
        'Treasurer changed: groupId=${widget.groupId} treasurerId=$treasurerId',
      );
      ref.invalidate(futureGroupProvider(widget.groupId));
    } catch (e, st) {
      Log.warning('Treasurer change failed', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onFreeze(
    WidgetRef ref,
    Group group,
    AsyncValue<List<Participant>> participantsAsync,
    AsyncValue<List<Expense>> expensesAsync,
  ) async {
    final participants = participantsAsync.value;
    final expenses = expensesAsync.value;
    if (participants == null || expenses == null) return;
    setState(() => _saving = true);
    try {
      final snapshot = createSnapshot(participants, expenses, group);
      await ref
          .read(groupRepositoryProvider)
          .freezeSettlement(widget.groupId, snapshot);
      Log.info('Settlement frozen: groupId=${widget.groupId}');
      ref.invalidate(futureGroupProvider(widget.groupId));
    } catch (e, st) {
      Log.warning('Settlement freeze failed', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onUnfreeze(WidgetRef ref) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(groupRepositoryProvider)
          .unfreezeSettlement(widget.groupId);
      Log.info('Settlement unfrozen: groupId=${widget.groupId}');
      ref.invalidate(futureGroupProvider(widget.groupId));
    } catch (e, st) {
      Log.warning('Settlement unfreeze failed', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildOnlineSection(
    BuildContext context,
    Group group,
    AsyncValue<GroupRole?> myRoleAsync,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    return myRoleAsync.when(
      data: (myRole) {
        final isOwnerOrAdmin =
            myRole == GroupRole.owner || myRole == GroupRole.admin;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isOwnerOrAdmin && group.ownerId != null) ...[
              Text(
                'group_permissions'.tr(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text('allow_add_expense'.tr()),
                value: group.allowMemberAddExpense,
                onChanged: _saving
                    ? null
                    : (v) => _onPermissionChanged(
                        ref,
                        group,
                        allowMemberAddExpense: v,
                      ),
              ),
              SwitchListTile(
                title: Text('allow_add_participant'.tr()),
                value: group.allowMemberAddParticipant,
                onChanged: _saving
                    ? null
                    : (v) => _onPermissionChanged(
                        ref,
                        group,
                        allowMemberAddParticipant: v,
                      ),
              ),
              SwitchListTile(
                title: Text('allow_change_settings'.tr()),
                value: group.allowMemberChangeSettings,
                onChanged: _saving
                    ? null
                    : (v) => _onPermissionChanged(
                        ref,
                        group,
                        allowMemberChangeSettings: v,
                      ),
              ),
              SwitchListTile(
                title: Text('require_participant_assignment'.tr()),
                subtitle: Text('require_participant_assignment_desc'.tr()),
                value: group.requireParticipantAssignment,
                onChanged: _saving
                    ? null
                    : (v) => _onPermissionChanged(
                        ref,
                        group,
                        requireParticipantAssignment: v,
                      ),
              ),
              const SizedBox(height: 24),
            ],
            if (isOwnerOrAdmin) ...[
              Text(
                'invite_people'.tr(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () =>
                    createAndShowInviteSheet(context, ref, widget.groupId),
                icon: const Icon(Icons.add_link),
                label: Text('invite_people'.tr()),
              ),
              const SizedBox(height: 24),
            ],
            if (myRole == GroupRole.owner) ...[
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () => _showTransferOwnership(context, ref),
                icon: const Icon(Icons.swap_horiz),
                label: Text('transfer_ownership'.tr()),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () => _showDeleteGroup(context, ref),
                icon: const Icon(Icons.delete_outline),
                label: Text('delete_group'.tr()),
              ),
              const SizedBox(height: 24),
            ],
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _showLeaveGroup(context, ref),
              icon: const Icon(Icons.exit_to_app),
              label: Text('leave_group'.tr()),
            ),
          ],
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Future<void> _onPermissionChanged(
    WidgetRef ref,
    Group group, {
    bool? allowMemberAddExpense,
    bool? allowMemberAddParticipant,
    bool? allowMemberChangeSettings,
    bool? requireParticipantAssignment,
  }) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(groupRepositoryProvider)
          .update(
            group.copyWith(
              allowMemberAddExpense:
                  allowMemberAddExpense ?? group.allowMemberAddExpense,
              allowMemberAddParticipant:
                  allowMemberAddParticipant ?? group.allowMemberAddParticipant,
              allowMemberChangeSettings:
                  allowMemberChangeSettings ?? group.allowMemberChangeSettings,
              requireParticipantAssignment:
                  requireParticipantAssignment ??
                  group.requireParticipantAssignment,
              updatedAt: DateTime.now(),
            ),
          );
      ref.invalidate(futureGroupProvider(widget.groupId));
    } catch (e, st) {
      Log.warning('Permission change failed', error: e, stackTrace: st);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showTransferOwnership(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final members = await ref
        .read(groupMemberRepositoryProvider)
        .listByGroup(widget.groupId);
    if (!context.mounted) return;
    final others = members.where((m) => m.role != 'owner').toList();
    if (others.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('no_other_members'.tr())));
      return;
    }
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: others
            .map(
              (m) => ListTile(
                title: Text('${m.userId.substring(0, 8)}... (${m.role})'),
                onTap: () => Navigator.pop(ctx, m.id),
              ),
            )
            .toList(),
      ),
    );
    if (chosen == null || !context.mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(groupMemberRepositoryProvider)
          .transferOwnership(widget.groupId, chosen);
      TelemetryService.sendEvent('ownership_transferred', {
        'groupId': widget.groupId,
      }, enabled: ref.read(telemetryEnabledProvider));
      ref.invalidate(futureGroupProvider(widget.groupId));
      ref.invalidate(myRoleInGroupProvider(widget.groupId));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ownership_transferred'.tr())));
      }
    } catch (e, st) {
      Log.warning('Transfer failed', error: e, stackTrace: st);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showDeleteGroup(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('delete_group'.tr()),
        content: Text('delete_group_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('delete_group'.tr()),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(groupRepositoryProvider).delete(widget.groupId);
      if (context.mounted) context.go(RoutePaths.home);
    } catch (e, st) {
      Log.warning('Delete group failed', error: e, stackTrace: st);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showLeaveGroup(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('leave_group'.tr()),
        content: Text('leave_group_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('leave_group'.tr()),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(groupMemberRepositoryProvider).leave(widget.groupId);
      TelemetryService.sendEvent('member_left', {
        'groupId': widget.groupId,
      }, enabled: ref.read(telemetryEnabledProvider));
      if (context.mounted) context.go(RoutePaths.home);
    } catch (e, st) {
      Log.warning('Leave failed', error: e, stackTrace: st);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
