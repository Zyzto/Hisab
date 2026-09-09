import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import '../../../core/services/settle_up_service.dart';
import '../../../core/services/household_service.dart';
import '../../../domain/domain.dart';
import '../../groups/providers/groups_provider.dart';

part 'balance_provider.g.dart';

/// Computed provider for group balances and settlements. Caches computation
/// and recomputes when group, participants, or expenses change.
@riverpod
AsyncValue<GroupBalanceResult?> groupBalance(Ref ref, String groupId) {
  final groupAsync = ref.watch(futureGroupProvider(groupId));
  final participantsAsync = ref.watch(
    balanceParticipantsByGroupProvider(groupId),
  );
  final expensesAsync = ref.watch(expensesByGroupProvider(groupId));
  final reassignmentsAsync = ref.watch(
    householdReassignmentsByGroupProvider(groupId),
  );

  return groupAsync.when(
    data: (group) {
      if (group == null) return const AsyncValue.data(null);
      return participantsAsync.when(
        data: (participants) => expensesAsync.when(
          data: (expenses) {
            return reassignmentsAsync.when(
              data: (reassignments) => _computeGroupBalance(
                group: group,
                participants: participants,
                expenses: expenses,
                reassignments: reassignments,
              ),
              loading: () => const AsyncValue.loading(),
              error: (e, s) => AsyncValue.error(e, s),
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

AsyncValue<GroupBalanceResult?> _computeGroupBalance({
  required Group group,
  required List<Participant> participants,
  required List<Expense> expenses,
  required List<HouseholdBalanceReassignment> reassignments,
}) {
  final calculationParticipants = group.householdCountingEnabled
      ? participants
      : participants.where((p) => p.leftAt == null).toList();
  List<ParticipantBalance> balances;
  List<ParticipantBalance> individualBalances;
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
      final snapshot = SettlementSnapshot.fromJsonString(snapshotJson);
      balances = snapshot.balances;
      individualBalances = snapshot.balances;
      settlements = snapshot.settlements;
    } catch (e) {
      Log.warning(
        'Balance provider: snapshot parse failed; keeping frozen empty state',
        error: e,
      );
      snapshotCorrupt = true;
      balances = [
        for (final p in calculationParticipants)
          ParticipantBalance(
            participantId: p.id,
            balanceCents: 0,
            currencyCode: group.currencyCode,
          ),
      ];
      individualBalances = balances;
      settlements = const [];
    }
  } else if (group.isSettlementFrozen &&
      (snapshotJson == null || snapshotJson.isEmpty)) {
    snapshotCorrupt = true;
    balances = [
      for (final p in calculationParticipants)
        ParticipantBalance(
          participantId: p.id,
          balanceCents: 0,
          currencyCode: group.currencyCode,
        ),
    ];
    individualBalances = balances;
    settlements = const [];
  } else {
    // Live compute: unfrozen, or archive auto-freeze marker.
    if (group.householdCountingEnabled) {
      final projection = HouseholdService.computeProjection(
        group: group,
        participants: calculationParticipants,
        expenses: expenses,
        reassignments: reassignments,
      );
      balances = projection.family;
      individualBalances = projection.individual;
      settlements = projection.settlements;
    } else {
      balances = computeBalances(
        calculationParticipants,
        expenses,
        group.currencyCode,
      );
      individualBalances = balances;
      settlements = computeSettlements(
        group.settlementMethod,
        balances,
        calculationParticipants,
        expenses,
        group.currencyCode,
        group.treasurerParticipantId,
      );
    }
  }

  return AsyncValue.data(
    GroupBalanceResult(
      group: group,
      participants: calculationParticipants,
      balances: balances,
      individualBalances: individualBalances,
      settlements: settlements,
      snapshotCorrupt: snapshotCorrupt,
    ),
  );
}
