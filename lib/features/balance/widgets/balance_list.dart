import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/services/settle_up_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../groups/providers/groups_provider.dart';

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
                final balances = computeBalances(
                  participants,
                  expenses,
                  group.currencyCode,
                );
                final settlements = computeSettleUp(
                  balances,
                  group.currencyCode,
                );
                final nameOf = {for (final p in participants) p.id: p.name};

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'balance'.tr(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...balances.map((b) {
                      final name = nameOf[b.participantId] ?? b.participantId;
                      final isPositive = b.balanceCents >= 0;
                      final color = isPositive
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error;
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
                    Text(
                      'settle_up'.tr(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (settlements.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'All Settled',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    else
                      ...settlements.map((s) {
                        final from =
                            nameOf[s.fromParticipantId] ?? s.fromParticipantId;
                        final to =
                            nameOf[s.toParticipantId] ?? s.toParticipantId;
                        return ListTile(
                          title: Text('$from → $to'),
                          subtitle: Text(
                            CurrencyFormatter.formatCents(
                              s.amountCents,
                              s.currencyCode,
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
