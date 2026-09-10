import 'dart:convert';

import '../../domain/domain.dart';
import 'settle_up_service.dart';

/// A participant's direct contribution to a household split. Named children
/// are represented by their own row; the count applies only to unnamed people
/// directly represented by that row.
class HouseholdUnitCount {
  final String participantId;
  final int unitCount;

  const HouseholdUnitCount({
    required this.participantId,
    required this.unitCount,
  });

  Map<String, dynamic> toJson() => {
    'participant_id': participantId,
    'unit_count': unitCount,
  };
}

/// Immutable explanation stored with a household-aware expense.
class HouseholdSplitSnapshot {
  final int version;
  final SplitType splitType;
  final Map<String, int> includedUnitCounts;
  final Map<String, String> perPersonInputs;

  /// Parent ids captured at the time of the expense.  This keeps the detail
  /// view's directory stable if someone is reparented later.
  final Map<String, String?> parentParticipantIds;

  const HouseholdSplitSnapshot({
    this.version = 1,
    required this.splitType,
    required this.includedUnitCounts,
    this.perPersonInputs = const {},
    this.parentParticipantIds = const {},
  });

  String toJsonString() => jsonEncode({
    'version': version,
    'split_type': splitType.name,
    'included_unit_counts': includedUnitCounts,
    'per_person_inputs': perPersonInputs,
    if (parentParticipantIds.isNotEmpty)
      'parent_participant_ids': parentParticipantIds,
  });

  static HouseholdSplitSnapshot? fromJsonString(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      final rawCounts = decoded['included_unit_counts'];
      final rawInputs = decoded['per_person_inputs'];
      final rawParents = decoded['parent_participant_ids'];
      final counts = rawCounts is Map
          ? rawCounts.map(
              (key, val) => MapEntry(key.toString(), (val as num).toInt()),
            )
          : <String, int>{};
      final inputs = rawInputs is Map
          ? rawInputs.map(
              (key, val) => MapEntry(key.toString(), val.toString()),
            )
          : <String, String>{};
      final parents = rawParents is Map
          ? rawParents.map(
              (key, value) => MapEntry(
                key.toString(),
                value == null || value.toString().isEmpty
                    ? null
                    : value.toString(),
              ),
            )
          : <String, String?>{};
      final splitType = switch (decoded['split_type']?.toString()) {
        'parts' => SplitType.parts,
        'amounts' => SplitType.amounts,
        _ => SplitType.equal,
      };
      return HouseholdSplitSnapshot(
        version: (decoded['version'] as num?)?.toInt() ?? 1,
        splitType: splitType,
        includedUnitCounts: counts,
        perPersonInputs: inputs,
        parentParticipantIds: parents,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Shared household-tree calculations used by balances, settlement and UI.
class HouseholdService {
  const HouseholdService._();

  static Map<String, Participant> _byId(List<Participant> participants) => {
    for (final p in participants) p.id: p,
  };

  /// Returns the top-level root for every participant. Invalid references and
  /// cycles are rejected instead of silently producing an incorrect settlement.
  static Map<String, String> rootByParticipant(List<Participant> participants) {
    final byId = _byId(participants);
    final roots = <String, String>{};
    for (final participant in participants) {
      final seen = <String>{};
      var current = participant;
      while (current.parentParticipantId != null) {
        if (!seen.add(current.id)) {
          throw StateError('Household hierarchy contains a cycle');
        }
        final parentId = current.parentParticipantId!;
        final parent = byId[parentId];
        if (parent == null || parent.groupId != participant.groupId) {
          throw StateError(
            'Household parent is missing or belongs to another group',
          );
        }
        current = parent;
      }
      roots[participant.id] = current.id;
    }
    return roots;
  }

  static int directUnitCount(Participant participant) =>
      participant.directHouseholdSize;

  static int subtreeSize(String participantId, List<Participant> participants) {
    final children = <String, List<Participant>>{};
    for (final p in participants) {
      final parent = p.parentParticipantId;
      if (parent != null) children.putIfAbsent(parent, () => []).add(p);
    }
    int visit(String id, Set<String> path) {
      if (!path.add(id)) {
        throw StateError('Household hierarchy contains a cycle');
      }
      final participant = participants.firstWhere((p) => p.id == id);
      var total = directUnitCount(participant);
      for (final child in children[id] ?? const <Participant>[]) {
        total += visit(child.id, path);
      }
      path.remove(id);
      return total;
    }

    return visit(participantId, <String>{});
  }

  /// Aggregates participant balances to their top-level family roots.
  static List<ParticipantBalance> rollUpBalances({
    required List<Participant> participants,
    required List<ParticipantBalance> balances,
    required String currencyCode,
  }) {
    final roots = rootByParticipant(participants);
    final totals = <String, int>{};
    for (final balance in balances) {
      final root = roots[balance.participantId] ?? balance.participantId;
      totals[root] = (totals[root] ?? 0) + balance.balanceCents;
    }
    return [
      for (final entry in totals.entries)
        ParticipantBalance(
          participantId: entry.key,
          balanceCents: entry.value,
          currencyCode: currencyCode,
        ),
    ];
  }

  /// Applies immutable balance adjustments created when an archived parent is
  /// removed. A source that is still present is reduced as well; normally the
  /// source is absent from the active participant list, so only the surviving
  /// branch receives the signed amount.
  static List<ParticipantBalance> applyReassignments({
    required List<ParticipantBalance> balances,
    required List<HouseholdBalanceReassignment> reassignments,
  }) {
    if (reassignments.isEmpty) return balances;
    final byId = <String, ParticipantBalance>{
      for (final balance in balances) balance.participantId: balance,
    };
    for (final reassignment in reassignments) {
      final source = byId[reassignment.sourceParticipantId];
      if (source != null) {
        byId[reassignment.sourceParticipantId] = source.copyWith(
          balanceCents: source.balanceCents - reassignment.amountCents,
        );
      }
      final target = byId[reassignment.targetParticipantId];
      if (target != null) {
        byId[reassignment.targetParticipantId] = target.copyWith(
          balanceCents: target.balanceCents + reassignment.amountCents,
        );
      }
    }
    return byId.values.toList();
  }

  /// Projects expenses to root participants before running pairwise or
  /// consolidated settlement algorithms. Effective shares remain unchanged;
  /// only their display/settlement owner is rolled up.
  static List<Expense> projectExpensesToRoots({
    required List<Participant> participants,
    required List<Expense> expenses,
  }) {
    final roots = rootByParticipant(participants);
    return expenses.map((expense) {
      // Transfers are explicit participant-to-participant movements.  They
      // are not household split legs and must retain their original endpoints.
      if (expense.transactionType == TransactionType.transfer) {
        return expense;
      }
      final shares = <String, int>{};
      for (final entry in expense.splitShares.entries) {
        final root = roots[entry.key] ?? entry.key;
        shares[root] = (shares[root] ?? 0) + entry.value;
      }
      return expense.copyWith(
        payerParticipantId:
            roots[expense.payerParticipantId] ?? expense.payerParticipantId,
        splitShares: shares,
        toParticipantId: expense.toParticipantId == null
            ? null
            : (roots[expense.toParticipantId!] ?? expense.toParticipantId),
      );
    }).toList();
  }

  /// Computes the group-wide family projection while retaining the normal
  /// participant balances for a signed-in person's own view.
  static ({
    List<ParticipantBalance> individual,
    List<ParticipantBalance> family,
    List<SettlementTransaction> settlements,
  })
  computeProjection({
    required Group group,
    required List<Participant> participants,
    required List<Expense> expenses,
    List<HouseholdBalanceReassignment> reassignments = const [],
  }) {
    final individual = applyReassignments(
      balances: computeBalances(participants, expenses, group.currencyCode),
      reassignments: reassignments,
    );
    final family = rollUpBalances(
      participants: participants,
      balances: individual,
      currencyCode: group.currencyCode,
    );
    final roots = rootByParticipant(participants);
    final rootParticipants = participants
        .where((p) => roots[p.id] == p.id)
        .toList();
    final projectedExpenses = projectExpensesToRoots(
      participants: participants,
      expenses: expenses,
    );
    final treasurer = group.treasurerParticipantId == null
        ? null
        : (roots[group.treasurerParticipantId!] ??
              group.treasurerParticipantId);
    // A reassignment stores only the archived parent's unresolved net, not
    // the original expense legs. Use the balance-based algorithm for that
    // projection so pairwise/consolidated settlement cannot reference the
    // removed participant or silently drop the carried amount.
    final settlements = reassignments.isNotEmpty
        ? computeSettleUpGreedy(family, group.currencyCode)
        : computeSettlements(
            group.settlementMethod,
            family,
            rootParticipants,
            projectedExpenses,
            group.currencyCode,
            treasurer,
          );
    return (individual: individual, family: family, settlements: settlements);
  }
}
