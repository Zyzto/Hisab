import 'package:flutter_test/flutter_test.dart';

import 'package:hisab/core/services/household_service.dart';
import 'package:hisab/domain/domain.dart';

final _date = DateTime.utc(2026, 1, 1);

Participant _participant(String id, {String? parent, int unnamed = 0}) =>
    Participant(
      id: id,
      groupId: 'g',
      name: id,
      order: 0,
      parentParticipantId: parent,
      unnamedDependentCount: unnamed,
      createdAt: _date,
      updatedAt: _date,
    );

Expense _expense({required Map<String, int> shares}) => Expense(
  id: 'e',
  groupId: 'g',
  payerParticipantId: 'a',
  amountCents: 600,
  currencyCode: 'USD',
  title: 'Dinner',
  date: _date,
  splitType: SplitType.amounts,
  splitShares: shares,
  createdAt: _date,
  updatedAt: _date,
);

Expense _transfer() => Expense(
  id: 'transfer',
  groupId: 'g',
  payerParticipantId: 'b',
  amountCents: 100,
  currencyCode: 'USD',
  title: 'Paid back',
  date: _date,
  splitType: SplitType.equal,
  splitShares: const {},
  transactionType: TransactionType.transfer,
  toParticipantId: 'd',
  createdAt: _date,
  updatedAt: _date,
);

void main() {
  test('recursive roots and subtree sizes include unnamed dependents', () {
    final participants = [
      _participant('a', unnamed: 2),
      _participant('b', parent: 'a'),
      _participant('c', parent: 'b', unnamed: 1),
      _participant('d'),
    ];

    expect(HouseholdService.rootByParticipant(participants), {
      'a': 'a',
      'b': 'a',
      'c': 'a',
      'd': 'd',
    });
    expect(HouseholdService.subtreeSize('a', participants), 6);
    expect(HouseholdService.subtreeSize('b', participants), 3);
  });

  test('cycles and cross-group parents are rejected', () {
    final cycle = [
      _participant('a', parent: 'b'),
      _participant('b', parent: 'a'),
    ];
    expect(() => HouseholdService.rootByParticipant(cycle), throwsStateError);
    final crossGroup = [
      _participant('a'),
      _participant('b', parent: 'missing'),
    ];
    expect(
      () => HouseholdService.rootByParticipant(crossGroup),
      throwsStateError,
    );
  });

  test('household projection rolls named rows up to family roots', () {
    final participants = [
      _participant('a', unnamed: 2),
      _participant('b', parent: 'a'),
      _participant('d'),
    ];
    final group = Group(
      id: 'g',
      name: 'Group',
      currencyCode: 'USD',
      createdAt: _date,
      updatedAt: _date,
      householdCountingEnabled: true,
    );
    final projection = HouseholdService.computeProjection(
      group: group,
      participants: participants,
      expenses: [
        _expense(shares: {'a': 360, 'b': 120, 'd': 120}),
      ],
    );

    expect(
      projection.family.map((b) => (b.participantId, b.balanceCents)),
      containsAll([('a', 120), ('d', -120)]),
    );
    expect(projection.settlements.single, isA<SettlementTransaction>());
    expect(projection.settlements.single.amountCents, 120);
  });

  test(
    'signed reassignment moves an archived balance to a surviving branch',
    () {
      final balances = [
        const ParticipantBalance(
          participantId: 'child',
          balanceCents: -50,
          currencyCode: 'USD',
        ),
      ];
      final adjusted = HouseholdService.applyReassignments(
        balances: balances,
        reassignments: [
          HouseholdBalanceReassignment(
            id: 'r',
            groupId: 'g',
            sourceParticipantId: 'parent',
            targetParticipantId: 'child',
            amountCents: 125,
            createdAt: _date,
          ),
        ],
      );
      expect(adjusted.single.balanceCents, 75);
    },
  );

  test('snapshot round-trips counts and per-person inputs', () {
    const snapshot = HouseholdSplitSnapshot(
      splitType: SplitType.amounts,
      includedUnitCounts: {'a': 3, 'b': 1},
      perPersonInputs: {'a': '10.00', 'b': '30.00'},
    );
    final parsed = HouseholdSplitSnapshot.fromJsonString(
      snapshot.toJsonString(),
    );
    expect(parsed?.splitType, SplitType.amounts);
    expect(parsed?.includedUnitCounts, {'a': 3, 'b': 1});
    expect(parsed?.perPersonInputs['a'], '10.00');
  });

  test('transfer endpoints stay participant-to-participant', () {
    final participants = [
      _participant('a'),
      _participant('b', parent: 'a'),
      _participant('d'),
    ];
    final projected = HouseholdService.projectExpensesToRoots(
      participants: participants,
      expenses: [_transfer()],
    );
    expect(projected.single.payerParticipantId, 'b');
    expect(projected.single.toParticipantId, 'd');
  });
}
