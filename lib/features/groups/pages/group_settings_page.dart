import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/groups_provider.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/services/settle_up_service.dart';
import '../../../domain/domain.dart';

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
      Log.info('Settlement method changed: groupId=${widget.groupId} method=$method');
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
      Log.info('Treasurer changed: groupId=${widget.groupId} treasurerId=$treasurerId');
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
}
