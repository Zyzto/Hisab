import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/settle_up_service.dart';
import '../../../domain/domain.dart';
import '../../groups/providers/groups_provider.dart';

/// Computed provider for group balances and settlements. Caches computation
/// and recomputes when group, participants, or expenses change.
final groupBalanceProvider =
    Provider.family<AsyncValue<GroupBalanceResult?>, String>((ref, groupId) {
  final groupAsync = ref.watch(futureGroupProvider(groupId));
  final participantsAsync = ref.watch(participantsByGroupProvider(groupId));
  final expensesAsync = ref.watch(expensesByGroupProvider(groupId));

  return groupAsync.when(
    data: (group) {
      if (group == null) return const AsyncValue.data(null);
      return participantsAsync.when(
        data: (participants) => expensesAsync.when(
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
              } catch (e) {
                Log.warning(
                  'Balance provider: snapshot parse failed, using live computation',
                  error: e,
                );
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

            return AsyncValue.data(
              GroupBalanceResult(
                group: group,
                participants: participants,
                balances: balances,
                settlements: settlements,
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
});
