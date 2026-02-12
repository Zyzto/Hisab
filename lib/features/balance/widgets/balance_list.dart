import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/services/settle_up_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/navigation/route_paths.dart';
import '../../groups/providers/groups_provider.dart';
import '../../../domain/domain.dart';

class BalanceList extends ConsumerWidget {
  final String groupId;

  const BalanceList({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(futureGroupProvider(groupId));
    final participantsAsync = ref.watch(participantsByGroupProvider(groupId));
    final expensesAsync = ref.watch(expensesByGroupProvider(groupId));

    return groupAsync.when(
      data: (group) {
        if (group == null) {
          return const Center(child: Text('Group Not Found'));
        }
        return participantsAsync.when(
          data: (participants) {
            return expensesAsync.when(
              data: (expenses) {
                List<ParticipantBalance> balances;
                List<SettlementTransaction> settlements;

                if (group.isSettlementFrozen &&
                    group.settlementSnapshotJson != null &&
                    group.settlementSnapshotJson!.isNotEmpty) {
                  try {
                    final snapshot = SettlementSnapshot.fromJsonString(
                      group.settlementSnapshotJson!,
                    );
                    balances = snapshot.balances;
                    settlements = snapshot.settlements;
                  } catch (_) {
                    balances = computeBalances(
                      participants,
                      expenses,
                      group.currencyCode,
                    );
                    settlements = computeSettlements(
                      group.settlementMethod,
                      balances,
                      participants,
                      expenses,
                      group.currencyCode,
                      group.treasurerParticipantId,
                    );
                  }
                } else {
                  balances = computeBalances(
                    participants,
                    expenses,
                    group.currencyCode,
                  );
                  settlements = computeSettlements(
                    group.settlementMethod,
                    balances,
                    participants,
                    expenses,
                    group.currencyCode,
                    group.treasurerParticipantId,
                  );
                }

                final nameOf = {for (final p in participants) p.id: p.name};
                final theme = Theme.of(context);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (group.isSettlementFrozen) ...[
                      Card(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.pause_circle,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'settlement_frozen'.tr(),
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      'settlement_frozen_hint'.tr(),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.push(
                                  RoutePaths.groupSettings(groupId),
                                ),
                                child: Text('unfreeze_settlement'.tr()),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text('balance'.tr(), style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...balances.map((b) {
                      final name = nameOf[b.participantId] ?? b.participantId;
                      final isPositive = b.balanceCents >= 0;
                      final color = isPositive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(name),
                          trailing: Text(
                            '${isPositive ? '' : '-'}${CurrencyFormatter.formatCompactCents(b.balanceCents.abs())} ${group.currencyCode}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Text('settle_up'.tr(), style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (settlements.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'all_settled'.tr(),
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                    else
                      ...settlements.map((s) {
                        final from =
                            nameOf[s.fromParticipantId] ?? s.fromParticipantId;
                        final to =
                            nameOf[s.toParticipantId] ?? s.toParticipantId;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text('$from → $to'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  CurrencyFormatter.formatCents(
                                    s.amountCents,
                                    s.currencyCode,
                                  ),
                                ),
                                if (s.items != null && s.items!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  ...s.items!.map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Text(
                                        '${item.title}: ${CurrencyFormatter.formatCents(item.amountCents, s.currencyCode)}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
