import '../../domain/domain.dart';

/// Greedy debt minimization: compute the fewest transfers to settle balances.
/// [balances] is a list of (participantId, balanceCents). Positive = owed to them.
/// Returns list of (fromId, toId, amountCents).
List<SettlementTransaction> computeSettleUpGreedy(
  List<ParticipantBalance> balances,
  String currencyCode,
) {
  final debtors = <String, int>{}; // negative balance -> amount to pay
  final creditors = <String, int>{}; // positive balance -> amount to receive

  for (final b in balances) {
    if (b.balanceCents > 0) {
      creditors[b.participantId] = b.balanceCents;
    } else if (b.balanceCents < 0) {
      debtors[b.participantId] = -b.balanceCents;
    }
  }

  final result = <SettlementTransaction>[];

  for (final entry in debtors.entries) {
    int remaining = entry.value;
    final fromId = entry.key;

    for (final cred in creditors.entries) {
      if (remaining <= 0) break;
      final toId = cred.key;
      final credit = cred.value;
      if (credit <= 0) continue;

      final transfer = remaining < credit ? remaining : credit;
      result.add(
        SettlementTransaction(
          fromParticipantId: fromId,
          toParticipantId: toId,
          amountCents: transfer,
          currencyCode: currencyCode,
        ),
      );
      remaining -= transfer;
      creditors[toId] = credit - transfer;
    }
  }

  return result;
}

/// Pairwise: per-pair net. For each pair (A,B), net = (B paid for A) - (A paid for B).
/// One transfer per pair with non-zero net.
List<SettlementTransaction> computeSettleUpPairwise(
  List<Participant> participants,
  List<Expense> expenses,
  String currencyCode,
) {
  // debt[A][B] = how much A owes B (from expenses where B paid and A was a sharer)
  final debt = <String, Map<String, int>>{};
  for (final p in participants) {
    debt[p.id] = {};
    for (final other in participants) {
      if (other.id != p.id) debt[p.id]![other.id] = 0;
    }
  }

  for (final e in expenses) {
    final shares = _computeShares(e);
    for (final entry in shares.entries) {
      final sharer = entry.key;
      final amount = entry.value;
      final payer = e.payerParticipantId;
      if (sharer != payer && amount > 0) {
        debt[sharer]![payer] = (debt[sharer]![payer] ?? 0) + amount;
      }
    }
  }

  final result = <SettlementTransaction>[];
  final seen = <String>{};

  for (final a in participants) {
    for (final b in participants) {
      if (a.id.compareTo(b.id) >= 0) continue;
      final key = '${a.id}_${b.id}';
      if (seen.contains(key)) continue;

      final aOwesB = debt[a.id]![b.id] ?? 0;
      final bOwesA = debt[b.id]![a.id] ?? 0;
      final net = aOwesB - bOwesA;

      if (net > 0) {
        result.add(
          SettlementTransaction(
            fromParticipantId: a.id,
            toParticipantId: b.id,
            amountCents: net,
            currencyCode: currencyCode,
          ),
        );
      } else if (net < 0) {
        result.add(
          SettlementTransaction(
            fromParticipantId: b.id,
            toParticipantId: a.id,
            amountCents: -net,
            currencyCode: currencyCode,
          ),
        );
      }
      seen.add(key);
    }
  }

  return result;
}

/// Consolidated: per-payer aggregation with itemized expense breakdown.
List<SettlementTransaction> computeSettleUpConsolidated(
  List<Participant> participants,
  List<Expense> expenses,
  String currencyCode,
) {
  // (debtor, creditor) -> [(expenseId, title, amountCents)]
  final byPair = <String, Map<String, List<SettlementItem>>>{};

  for (final e in expenses) {
    final shares = _computeShares(e);
    final payer = e.payerParticipantId;
    for (final entry in shares.entries) {
      final sharer = entry.key;
      final amount = entry.value;
      if (sharer != payer && amount > 0) {
        byPair.putIfAbsent(sharer, () => {});
        byPair[sharer]!.putIfAbsent(payer, () => []);
        byPair[sharer]![payer]!.add(
          SettlementItem(expenseId: e.id, title: e.title, amountCents: amount),
        );
      }
    }
  }

  final result = <SettlementTransaction>[];
  for (final entry in byPair.entries) {
    final debtor = entry.key;
    for (final credEntry in entry.value.entries) {
      final creditor = credEntry.key;
      final items = credEntry.value;
      final total = items.fold<int>(0, (s, i) => s + i.amountCents);
      if (total > 0) {
        result.add(
          SettlementTransaction(
            fromParticipantId: debtor,
            toParticipantId: creditor,
            amountCents: total,
            currencyCode: currencyCode,
            items: items,
          ),
        );
      }
    }
  }

  return result;
}

/// Treasurer: route all flows through one person.
List<SettlementTransaction> computeSettleUpTreasurer(
  List<ParticipantBalance> balances,
  String currencyCode,
  String treasurerParticipantId,
) {
  final debtors = <String, int>{};
  final creditors = <String, int>{};
  for (final b in balances) {
    if (b.balanceCents > 0) {
      creditors[b.participantId] = b.balanceCents;
    } else if (b.balanceCents < 0) {
      debtors[b.participantId] = -b.balanceCents;
    }
  }

  final result = <SettlementTransaction>[];

  for (final entry in debtors.entries) {
    final fromId = entry.key;
    if (fromId == treasurerParticipantId) continue;
    result.add(
      SettlementTransaction(
        fromParticipantId: fromId,
        toParticipantId: treasurerParticipantId,
        amountCents: entry.value,
        currencyCode: currencyCode,
      ),
    );
  }

  for (final entry in creditors.entries) {
    final toId = entry.key;
    if (toId == treasurerParticipantId) continue;
    result.add(
      SettlementTransaction(
        fromParticipantId: treasurerParticipantId,
        toParticipantId: toId,
        amountCents: entry.value,
        currencyCode: currencyCode,
      ),
    );
  }

  return result;
}

/// Dispatcher: compute settlements based on group's method.
List<SettlementTransaction> computeSettlements(
  SettlementMethod method,
  List<ParticipantBalance> balances,
  List<Participant> participants,
  List<Expense> expenses,
  String currencyCode,
  String? treasurerParticipantId,
) {
  switch (method) {
    case SettlementMethod.pairwise:
      return computeSettleUpPairwise(participants, expenses, currencyCode);
    case SettlementMethod.greedy:
      return computeSettleUpGreedy(balances, currencyCode);
    case SettlementMethod.consolidated:
      return computeSettleUpConsolidated(participants, expenses, currencyCode);
    case SettlementMethod.treasurer:
      final treasurer = treasurerParticipantId ?? participants.firstOrNull?.id;
      if (treasurer == null) return [];
      return computeSettleUpTreasurer(balances, currencyCode, treasurer);
  }
}

/// Create a snapshot for settlement freeze.
SettlementSnapshot createSnapshot(
  List<Participant> participants,
  List<Expense> expenses,
  Group group,
) {
  final balances = computeBalances(participants, expenses, group.currencyCode);
  final settlements = computeSettlements(
    group.settlementMethod,
    balances,
    participants,
    expenses,
    group.currencyCode,
    group.treasurerParticipantId,
  );
  return SettlementSnapshot(
    frozenAt: DateTime.now(),
    balances: balances,
    settlements: settlements,
  );
}

/// Compute per-participant balances from expenses and participants.
/// Balance = what they paid minus what they owe. Positive = owed to them.
List<ParticipantBalance> computeBalances(
  List<Participant> participants,
  List<Expense> expenses,
  String currencyCode,
) {
  final paid = <String, int>{};
  final owed = <String, int>{};

  for (final p in participants) {
    paid[p.id] = 0;
    owed[p.id] = 0;
  }

  for (final e in expenses) {
    paid[e.payerParticipantId] =
        (paid[e.payerParticipantId] ?? 0) + e.amountCents;

    final shares = _computeShares(e);
    for (final entry in shares.entries) {
      owed[entry.key] = (owed[entry.key] ?? 0) + entry.value;
    }
  }

  return participants.map((p) {
    final pPaid = paid[p.id] ?? 0;
    final pOwed = owed[p.id] ?? 0;
    return ParticipantBalance(
      participantId: p.id,
      balanceCents: pPaid - pOwed,
      currencyCode: currencyCode,
    );
  }).toList();
}

/// For an expense, compute how much each participant owes (in cents).
Map<String, int> _computeShares(Expense e) {
  switch (e.splitType) {
    case SplitType.equal:
      if (e.splitShares.isEmpty) return {};
      return Map.from(e.splitShares);
    case SplitType.parts:
    case SplitType.amounts:
      return Map.from(e.splitShares);
  }
}

// Legacy alias for backward compatibility.
List<SettlementTransaction> computeSettleUp(
  List<ParticipantBalance> balances,
  String currencyCode,
) => computeSettleUpGreedy(balances, currencyCode);
