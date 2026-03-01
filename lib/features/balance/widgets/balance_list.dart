import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/widgets/amount_with_secondary_display.dart';
import '../../../core/widgets/error_content.dart';
import '../../../domain/domain.dart';
import '../../groups/providers/group_member_provider.dart';
import '../providers/balance_provider.dart';
import 'record_settlement_sheet.dart';

class BalanceList extends ConsumerWidget {
  final String groupId;
  final Future<void> Function()? onRefresh;

  const BalanceList({super.key, required this.groupId, this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(groupBalanceProvider(groupId));
    final myMemberAsync = ref.watch(myMemberInGroupProvider(groupId));
    final myRoleAsync = ref.watch(myRoleInGroupProvider(groupId));

    return balanceAsync.when(
      data: (result) {
        if (result == null) {
          return Center(child: Text('group_not_found'.tr()));
        }
        final group = result.group;
        final participants = result.participants;
        final balances = result.balances;
        final settlements = result.settlements;

        final myMember = myMemberAsync.hasValue ? myMemberAsync.value : null;
        final myRole = myRoleAsync.hasValue ? myRoleAsync.value : null;
        bool canRecordSettlement(SettlementTransaction s) {
          if (group.isSettlementFrozen) return false;
          if (group.allowMemberSettleForOthers) return true;
          if (myRole == GroupRole.owner) return true;
          if (myMember?.participantId == s.fromParticipantId) return true;
          return false;
        }

        final nameOf = {for (final p in participants) p.id: p.name};
        final theme = Theme.of(context);

        // Flatten for ListView.builder: compute item count and build by index
        final hasFrozen = group.isSettlementFrozen;
        var itemCount = (hasFrozen ? 1 : 0) + 4 + balances.length;
        itemCount += settlements.isEmpty ? 1 : settlements.length;

        final listView = ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            var i = index;
            if (hasFrozen) {
              if (i == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'settlement_frozen_hint'.tr(),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
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
                );
              }
              i -= 1;
            }
            if (i == 0) {
              return Text('balance'.tr(), style: theme.textTheme.titleMedium);
            }
            i--;
            if (i == 0) {
              return const SizedBox(height: 8);
            }
            i--;
            if (i < balances.length) {
              final b = balances[i];
              final name = nameOf[b.participantId] ?? b.participantId;
              final isPositive = b.balanceCents >= 0;
              final color = isPositive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error;
              final amountStyle = theme.textTheme.bodyLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ) ??
                  TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                  );
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(name),
                  trailing: AmountWithSecondaryDisplay(
                    amountCents: b.balanceCents.abs(),
                    groupCurrencyCode: group.currencyCode,
                    primaryStyle: amountStyle,
                    isNegative: !isPositive,
                  ),
                ),
              );
            }
            i -= balances.length;
            if (i == 0) {
              return Text('settle_up'.tr(), style: theme.textTheme.titleMedium);
            }
            i--;
            if (i == 0) {
              return const SizedBox(height: 8);
            }
            i--;
            if (settlements.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'all_settled'.tr(),
                  style: theme.textTheme.bodyMedium,
                ),
              );
            }
            final s = settlements[i];
            final from = nameOf[s.fromParticipantId] ?? s.fromParticipantId;
            final to = nameOf[s.toParticipantId] ?? s.toParticipantId;
            final canRecord = canRecordSettlement(s);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('$from \u2192 $to'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AmountWithSecondaryDisplay(
                      amountCents: s.amountCents,
                      groupCurrencyCode: s.currencyCode,
                      primaryStyle: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      secondaryStyle: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      secondaryOnSameRow: true,
                    ),
                    if (s.items != null && s.items!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      ...s.items!.map(
                        (subItem) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            '${subItem.title}: ${CurrencyFormatter.formatCents(subItem.amountCents, s.currencyCode)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: !hasFrozen
                    ? Semantics(
                        label: canRecord
                            ? 'record_settlement'.tr()
                            : 'record_settlement_restricted'.tr(),
                        button: true,
                        child: IconButton(
                          icon: Icon(
                            Icons.payments_outlined,
                            color: canRecord
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          tooltip: canRecord
                              ? 'record_settlement'.tr()
                              : 'record_settlement_restricted'.tr(),
                          onPressed: canRecord
                              ? () => showRecordSettlementSheet(
                                    context,
                                    ref,
                                    groupId: groupId,
                                    currencyCode: group.currencyCode,
                                    settlement: s,
                                    fromName: from,
                                    toName: to,
                                  )
                              : null,
                        ),
                      )
                    : null,
                onTap: hasFrozen
                    ? null
                    : canRecord
                        ? () => showRecordSettlementSheet(
                              context,
                              ref,
                              groupId: groupId,
                              currencyCode: group.currencyCode,
                              settlement: s,
                              fromName: from,
                              toName: to,
                            )
                        : null,
              ),
            );
          },
        );
        if (onRefresh != null) {
          return RefreshIndicator(onRefresh: onRefresh!, child: listView);
        }
        return listView;
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: ErrorContentWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(groupBalanceProvider(groupId)),
        ),
      ),
    );
  }
}
