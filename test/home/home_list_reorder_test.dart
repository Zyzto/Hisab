import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/domain/domain.dart';
import 'package:hisab/features/home/utils/home_list_reorder.dart';

Group _g(String id, {bool personal = false}) {
  final now = DateTime(2025, 1, 1);
  return Group(
    id: id,
    name: id,
    currencyCode: 'USD',
    createdAt: now,
    updatedAt: now,
    isPersonal: personal,
  );
}

void main() {
  group('reorderWithinPinGroups', () {
    test('reorders within unpinned cohort', () {
      final items = [_g('a'), _g('b'), _g('c')];
      final next = reorderWithinPinGroups(
        items: items,
        oldIndex: 2,
        newIndex: 0,
        isPinned: (_) => false,
      );
      expect(next.map((g) => g.id).toList(), ['c', 'a', 'b']);
    });

    test('does not move unpinned above pinned', () {
      final items = [_g('p1'), _g('p2'), _g('u1'), _g('u2')];
      final pinned = {'p1', 'p2'};
      final next = reorderWithinPinGroups(
        items: items,
        oldIndex: 3,
        newIndex: 0,
        isPinned: (g) => pinned.contains(g.id),
      );
      expect(next.map((g) => g.id).toList(), ['p1', 'p2', 'u2', 'u1']);
    });

    test('reorders within pinned cohort', () {
      final items = [_g('p1'), _g('p2'), _g('u1')];
      final pinned = {'p1', 'p2'};
      final next = reorderWithinPinGroups(
        items: items,
        oldIndex: 0,
        newIndex: 2,
        isPinned: (g) => pinned.contains(g.id),
      );
      expect(next.map((g) => g.id).toList(), ['p2', 'p1', 'u1']);
    });
  });

  group('replaceSectionOrder', () {
    test('rewrites personal slots without reshuffling shared', () {
      final full = [
        _g('p1', personal: true),
        _g('s1'),
        _g('p2', personal: true),
        _g('s2'),
      ];
      final newPersonal = [_g('p2', personal: true), _g('p1', personal: true)];
      final next = replaceSectionOrder(
        fullOrder: full,
        sectionNewOrder: newPersonal,
        inSection: (g) => g.isPersonal,
      );
      expect(next.map((g) => g.id).toList(), ['p2', 's1', 'p1', 's2']);
    });
  });

  group('moveToInsertSlot', () {
    test('moves item before a later index', () {
      final items = [_g('a'), _g('b'), _g('c')];
      final next = moveToInsertSlot(
        items: items,
        fromIndex: 0,
        insertBeforeIndex: 3,
        isPinned: (_) => false,
      );
      expect(next.map((g) => g.id).toList(), ['b', 'c', 'a']);
    });

    test('no-op when dropping on own slot', () {
      final items = [_g('a'), _g('b'), _g('c')];
      final next = moveToInsertSlot(
        items: items,
        fromIndex: 1,
        insertBeforeIndex: 1,
        isPinned: (_) => false,
      );
      expect(next.map((g) => g.id).toList(), ['a', 'b', 'c']);
    });
  });
}
