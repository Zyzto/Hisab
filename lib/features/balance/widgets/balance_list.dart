import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/theme/accent_style.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_report_helper.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/widgets/amount_with_secondary_display.dart';
import '../../../core/widgets/error_content.dart';
import '../../../core/widgets/participant_avatar.dart';
import '../../../domain/domain.dart';
import '../../groups/providers/group_member_provider.dart';
import '../../groups/widgets/group_section_header.dart';
import '../providers/balance_provider.dart';
import 'record_settlement_sheet.dart';

class BalanceList extends ConsumerWidget {
  final String groupId;
  final Future<void> Function()? onRefresh;
  final bool readOnlyMode;

  const BalanceList({
    super.key,
    required this.groupId,
    this.onRefresh,
    this.readOnlyMode = false,
  });

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
        final sortedBalances = List<ParticipantBalance>.from(balances)
          ..sort((a, b) {
            final ac = a.balanceCents;
            final bc = b.balanceCents;
            if (ac >= 0 && bc < 0) return -1;
            if (ac < 0 && bc >= 0) return 1;
            if (ac >= 0 && bc >= 0) return bc.compareTo(ac);
            return ac.compareTo(bc);
          });
        final visibleBalances = sortedBalances
            .where((b) => b.balanceCents != 0)
            .toList();
        final settlements = result.settlements;

        final myMember = myMemberAsync.hasValue ? myMemberAsync.value : null;
        final myRole = myRoleAsync.hasValue ? myRoleAsync.value : null;
        String bidiIsolate(String value) => '\u2068$value\u2069';
        bool canRecordSettlement(SettlementTransaction s) {
          if (readOnlyMode) return false;
          if (group.isArchived) return false;
          if (group.isSettlementFrozen) return false;
          if (group.allowMemberSettleForOthers) return true;
          if (myRole == GroupRole.owner) return true;
          if (myMember?.participantId == s.fromParticipantId) return true;
          return false;
        }

        final nameOf = {for (final p in participants) p.id: p.name};
        final avatarOf = {for (final p in participants) p.id: p.avatarId};

        // Flatten for ListView.builder: compute item count and build by index.
        // Keep frozen-state context visible in read-only preview too.
        final hasFrozen = group.isSettlementFrozen || group.isArchived;
        var itemCount = (hasFrozen ? 1 : 0) + 4 + visibleBalances.length;
        itemCount += settlements.isEmpty ? 1 : settlements.length;

        final bottomInset = MediaQuery.paddingOf(context).bottom;
        final listView = ListView.builder(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            var i = index;
            if (hasFrozen) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _FrozenBanner(
                    readOnlyMode: readOnlyMode,
                    onUnfreeze: () =>
                        context.push(RoutePaths.groupSettings(groupId)),
                  ),
                );
              }
              i -= 1;
            }
            if (i == 0) {
              return GroupSectionHeader(label: 'balance'.tr());
            }
            i--;
            if (i == 0) {
              return const SizedBox(height: 10);
            }
            i--;
            if (i < visibleBalances.length) {
              final b = visibleBalances[i];
              final name = nameOf[b.participantId] ?? b.participantId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _BalancePersonCard(
                  name: name,
                  avatarId: avatarOf[b.participantId],
                  balanceCents: b.balanceCents,
                  currencyCode: group.currencyCode,
                ),
              );
            }
            i -= visibleBalances.length;
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: GroupSectionHeader(label: 'settle_up'.tr()),
              );
            }
            i--;
            if (i == 0) {
              return const SizedBox(height: 10);
            }
            i--;
            if (settlements.isEmpty) {
              return _SettledHintCard(
                message: 'all_settled'.tr(),
                icon: Icons.check_circle_outline_rounded,
              );
            }
            final s = settlements[i];
            final from = nameOf[s.fromParticipantId] ?? s.fromParticipantId;
            final to = nameOf[s.toParticipantId] ?? s.toParticipantId;
            final settlementTitle =
                '${bidiIsolate(from)} \u200E\u2192\u200E ${bidiIsolate(to)}';
            final canRecord = canRecordSettlement(s);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SettlementCard(
                title: settlementTitle,
                settlement: s,
                canRecord: canRecord,
                readOnlyMode: readOnlyMode,
                hasFrozen: hasFrozen,
                onRecord: () => showRecordSettlementSheet(
                  context,
                  ref,
                  groupId: groupId,
                  currencyCode: group.currencyCode,
                  settlement: s,
                  fromName: from,
                  toName: to,
                ),
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
      error: (e, st) {
        sendErrorTelemetryIfOnline(
          ref,
          message: e.toString(),
          details: e.toString(),
        );
        return Center(
          child: ErrorContentWidget(
            message: e.toString(),
            details: e.toString(),
            stackTrace: st,
            onRetry: () => ref.invalidate(groupBalanceProvider(groupId)),
          ),
        );
      },
    );
  }
}

class _FrozenBanner extends StatelessWidget {
  final bool readOnlyMode;
  final VoidCallback onUnfreeze;

  const _FrozenBanner({
    required this.readOnlyMode,
    required this.onUnfreeze,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: AccentSurfaces.panel(
        colorScheme,
        subtle: context.subtleAccents,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pause_circle_filled_rounded,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'settlement_frozen'.tr(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'settlement_frozen_hint'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: readOnlyMode ? null : onUnfreeze,
              child: Text('unfreeze_settlement'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettledHintCard extends StatelessWidget {
  final String message;
  final IconData icon;

  const _SettledHintCard({
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalancePersonCard extends StatelessWidget {
  final String name;
  final String? avatarId;
  final int balanceCents;
  final String currencyCode;

  const _BalancePersonCard({
    required this.name,
    this.avatarId,
    required this.balanceCents,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPositive = balanceCents >= 0;
    final color = isPositive ? colorScheme.primary : colorScheme.error;
    final amountStyle =
        theme.textTheme.titleMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ) ??
        TextStyle(color: color, fontWeight: FontWeight.w700);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          ParticipantAvatar(
            name: name,
            avatarId: avatarId,
            backgroundColor: color.withValues(alpha: 0.14),
            foregroundColor: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AmountWithSecondaryDisplay(
            amountCents: balanceCents.abs(),
            groupCurrencyCode: currencyCode,
            primaryStyle: amountStyle,
            isNegative: !isPositive,
          ),
        ],
      ),
    );
  }
}

class _SettlementCard extends StatelessWidget {
  final String title;
  final SettlementTransaction settlement;
  final bool canRecord;
  final bool readOnlyMode;
  final bool hasFrozen;
  final VoidCallback onRecord;

  const _SettlementCard({
    required this.title,
    required this.settlement,
    required this.canRecord,
    required this.readOnlyMode,
    required this.hasFrozen,
    required this.onRecord,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final s = settlement;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: hasFrozen || readOnlyMode
            ? null
            : canRecord
            ? onRecord
            : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AmountWithSecondaryDisplay(
                      amountCents: s.amountCents,
                      groupCurrencyCode: s.currencyCode,
                      primaryStyle: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                      secondaryStyle: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      secondaryOnSameRow: true,
                    ),
                    if (s.items != null && s.items!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ...s.items!.map(
                        (subItem) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '${subItem.title}: ${CurrencyFormatter.formatCents(subItem.amountCents, s.currencyCode)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!readOnlyMode)
                Semantics(
                  label: canRecord
                      ? 'record_settlement'.tr()
                      : 'record_settlement_restricted'.tr(),
                  button: true,
                  child: IconButton(
                    icon: Icon(
                      Icons.payments_outlined,
                      color: canRecord
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    tooltip: canRecord
                        ? 'record_settlement'.tr()
                        : 'record_settlement_restricted'.tr(),
                    onPressed: canRecord ? onRecord : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
