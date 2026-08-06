import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/domain/domain.dart';

/// Mirrors balance/profile frozen-snapshot resolution for unit coverage.
({
  List<ParticipantBalance> balances,
  List<SettlementTransaction> settlements,
  bool snapshotCorrupt,
  bool useLive,
})
resolveFrozenSnapshot({
  required bool isFrozen,
  required String? snapshotJson,
  required String currencyCode,
  required List<Participant> participants,
}) {
  final isArchiveAutoFreeze =
      isFrozen && snapshotJson == archiveAutoFreezeSnapshotMarker;

  if (isFrozen &&
      snapshotJson != null &&
      snapshotJson.isNotEmpty &&
      !isArchiveAutoFreeze) {
    try {
      final snapshot = SettlementSnapshot.fromJsonString(snapshotJson);
      return (
        balances: snapshot.balances,
        settlements: snapshot.settlements,
        snapshotCorrupt: false,
        useLive: false,
      );
    } catch (_) {
      return (
        balances: [
          for (final p in participants)
            ParticipantBalance(
              participantId: p.id,
              balanceCents: 0,
              currencyCode: currencyCode,
            ),
        ],
        settlements: const [],
        snapshotCorrupt: true,
        useLive: false,
      );
    }
  }
  if (isFrozen && (snapshotJson == null || snapshotJson.isEmpty)) {
    return (
      balances: [
        for (final p in participants)
          ParticipantBalance(
            participantId: p.id,
            balanceCents: 0,
            currencyCode: currencyCode,
          ),
      ],
      settlements: const [],
      snapshotCorrupt: true,
      useLive: false,
    );
  }
  return (
    balances: const [],
    settlements: const [],
    snapshotCorrupt: false,
    useLive: true,
  );
}

void main() {
  final now = DateTime.utc(2026, 1, 1);
  final participants = [
    Participant(
      id: 'p1',
      groupId: 'g1',
      name: 'Alice',
      order: 0,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  test('valid snapshot loads without corrupt flag', () {
    final snapshot = SettlementSnapshot(
      frozenAt: now,
      balances: const [
        ParticipantBalance(
          participantId: 'p1',
          balanceCents: 500,
          currencyCode: 'USD',
        ),
      ],
      settlements: const [],
    );
    final result = resolveFrozenSnapshot(
      isFrozen: true,
      snapshotJson: snapshot.toJsonString(),
      currencyCode: 'USD',
      participants: participants,
    );
    expect(result.snapshotCorrupt, isFalse);
    expect(result.useLive, isFalse);
    expect(result.balances.single.balanceCents, 500);
  });

  test('corrupt JSON yields empty balances and corrupt flag', () {
    final result = resolveFrozenSnapshot(
      isFrozen: true,
      snapshotJson: '{not-json',
      currencyCode: 'USD',
      participants: participants,
    );
    expect(result.snapshotCorrupt, isTrue);
    expect(result.useLive, isFalse);
    expect(result.balances.single.balanceCents, 0);
    expect(result.settlements, isEmpty);
  });

  test('archive auto-freeze marker uses live path', () {
    final result = resolveFrozenSnapshot(
      isFrozen: true,
      snapshotJson: archiveAutoFreezeSnapshotMarker,
      currencyCode: 'USD',
      participants: participants,
    );
    expect(result.snapshotCorrupt, isFalse);
    expect(result.useLive, isTrue);
  });

  test('frozen with empty snapshot is corrupt', () {
    final result = resolveFrozenSnapshot(
      isFrozen: true,
      snapshotJson: '',
      currencyCode: 'USD',
      participants: participants,
    );
    expect(result.snapshotCorrupt, isTrue);
    expect(result.useLive, isFalse);
  });
}
