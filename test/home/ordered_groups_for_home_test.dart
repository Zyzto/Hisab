import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/home/providers/home_list_provider.dart';

Group _g(String id, {DateTime? updated}) {
  final now = updated ?? DateTime(2025, 1, 1);
  return Group(
    id: id,
    name: id,
    currencyCode: 'USD',
    createdAt: now,
    updatedAt: now,
    isPersonal: false,
  );
}

void main() {
  test('custom sort ignores pins and follows custom order only', () {
    final groups = [_g('a'), _g('b'), _g('c')];
    final ordered = orderedGroupsForHome(
      groups,
      sortMode: 'custom',
      customOrderRaw: 'c,a,b',
      pinnedIdsRaw: 'a,b',
    );
    expect(ordered.map((g) => g.id).toList(), ['c', 'a', 'b']);
  });

  test('date sort still puts pinned first', () {
    final groups = [
      _g('a', updated: DateTime(2025, 1, 3)),
      _g('b', updated: DateTime(2025, 1, 2)),
      _g('c', updated: DateTime(2025, 1, 1)),
    ];
    final ordered = orderedGroupsForHome(
      groups,
      sortMode: 'updated_at',
      customOrderRaw: '',
      pinnedIdsRaw: 'c',
    );
    expect(ordered.map((g) => g.id).toList(), ['c', 'a', 'b']);
  });
}
