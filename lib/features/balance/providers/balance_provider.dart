import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import '../../../core/services/settle_up_service.dart';
import '../../../domain/domain.dart';
import '../../groups/providers/groups_provider.dart';

part 'balance_provider.g.dart';

/// Computed provider for group balances and settlements. Caches computation
/// and recomputes when group, participants, or expenses change.
@riverpod
AsyncValue<GroupBalanceResult?> groupBalance(Ref ref, String groupId) {
  final groupAsync = ref.watch(futureGroupProvider(groupId));
  final participantsAsync = ref.watch(
    activeParticipantsByGroupProvider(groupId),
  );
  final expensesAsync = ref.watch(expensesByGroupProvider(groupId));

  return groupAsync.when(
    data: (group) {
      if (group == null) return const AsyncValue.data(null);
      return participantsAsync.when(
        data: (participants) => expensesAsync.when(
          data: (expenses) {
            List<ParticipantBalance> balances;
            List<SettlementTransaction> settlements;
            var snapshotCorrupt = false;

            final snapshotJson = group.settlementSnapshotJson;
            final isArchiveAutoFreeze =
                group.isSettlementFrozen &&
                snapshotJson == archiveAutoFreezeSnapshotMarker;

            if (group.isSettlementFrozen &&
                snapshotJson != null &&
                snapshotJson.isNotEmpty &&
                !isArchiveAutoFreeze) {
              try {
                final snapshot = SettlementSnapshot.fromJsonString(
                  snapshotJson,
                );
                balances = snapshot.balances;
                settlements = snapshot.settlements;
              } catch (e) {
                Log.warning(
                  'Balance provider: snapshot parse failed; keeping frozen empty state',
                  error: e,
                );
                snapshotCorrupt = true;
                balances = [
                  for (final p in participants)
                    ParticipantBalance(
                      participantId: p.id,
                      balanceCents: 0,
                      currencyCode: group.currencyCode,
                    ),
                ];
                settlements = const [];
              }
            } else if (group.isSettlementFrozen &&
                (snapshotJson == null || snapshotJson.isEmpty)) {
              snapshotCorrupt = true;
              balances = [
                for (final p in participants)
                  ParticipantBalance(
                    participantId: p.id,
                    balanceCents: 0,
                    currencyCode: group.currencyCode,
                  ),
              ];
              settlements = const [];
            } else {
              // Live compute: unfrozen, or archive auto-freeze marker.
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

            return AsyncValue.data(
              GroupBalanceResult(
                group: group,
                participants: participants,
                balances: balances,
                settlements: settlements,
                snapshotCorrupt: snapshotCorrupt,
              ),
            );
          },
          loading: () => const AsyncValue.loading(),
          error: (e, s) => AsyncValue.error(e, s),
        ),
        loading: () => const AsyncValue.loading(),
        error: (e, s) => AsyncValue.error(e, s),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
}
