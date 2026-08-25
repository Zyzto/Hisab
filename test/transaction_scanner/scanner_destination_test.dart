import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/domain/group.dart';
import 'package:hisab/features/transaction_scanner/utils/scanner_destination.dart';

Group _group({
  required String id,
  bool personal = false,
  DateTime? archivedAt,
  bool allowAdd = true,
}) {
  final now = DateTime(2026, 1, 1);
  return Group(
    id: id,
    name: id,
    currencyCode: 'SAR',
    createdAt: now,
    updatedAt: now,
    isPersonal: personal,
    archivedAt: archivedAt,
    allowMemberAddExpense: allowAdd,
  );
}

void main() {
  test('prefers sender, then draft, then default, then first personal', () {
    final groups = [
      _group(id: 'p1', personal: true),
      _group(id: 's1'),
      _group(id: 's2'),
    ];
    expect(
      resolveScannerDestination(
        explicitGroupId: 's1',
        senderTargetGroupId: 's2',
        draftTargetGroupId: 'p1',
        defaultGroupId: 'p1',
        groups: groups,
      ),
      's1',
    );
    expect(
      resolveScannerDestination(
        senderTargetGroupId: 's2',
        draftTargetGroupId: 's1',
        defaultGroupId: 'p1',
        groups: groups,
      ),
      's2',
    );
    expect(
      resolveScannerDestination(
        senderTargetGroupId: null,
        draftTargetGroupId: 's1',
        defaultGroupId: 'p1',
        groups: groups,
      ),
      's1',
    );
    expect(
      resolveScannerDestination(
        senderTargetGroupId: null,
        draftTargetGroupId: null,
        defaultGroupId: 's2',
        groups: groups,
      ),
      's2',
    );
    expect(
      resolveScannerDestination(
        senderTargetGroupId: null,
        draftTargetGroupId: null,
        defaultGroupId: '',
        groups: groups,
      ),
      'p1',
    );
  });

  test('skips archived groups', () {
    final groups = [
      _group(id: 'old', personal: true, archivedAt: DateTime(2026, 1, 2)),
      _group(id: 'new', personal: true),
    ];
    expect(
      resolveScannerDestination(
        senderTargetGroupId: 'old',
        draftTargetGroupId: null,
        defaultGroupId: '',
        groups: groups,
      ),
      'new',
    );
  });

  test('equal split remainder', () {
    expect(equalSplitShares(['a', 'b', 'c'], 100), {'a': 34, 'b': 33, 'c': 33});
    expect(equalSplitShares([], 100), isEmpty);
  });

  test('canAddScannerExpense', () {
    expect(
      canAddScannerExpense(_group(id: 'p', personal: true), isOwner: false),
      isTrue,
    );
    expect(
      canAddScannerExpense(_group(id: 's', allowAdd: false), isOwner: false),
      isFalse,
    );
    expect(
      canAddScannerExpense(_group(id: 's', allowAdd: false), isOwner: true),
      isTrue,
    );
  });
}
