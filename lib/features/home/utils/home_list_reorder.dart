import '../../../domain/domain.dart';

/// Reorders [items] while keeping pinned and unpinned cohorts separate.
///
/// Home always shows pinned groups first; allowing a drag across that boundary
/// looks like it works, then snaps back when [orderedGroupsForHome] re-applies
/// pin partitioning. Clamping avoids that.
///
/// [newIndex] uses Flutter reorder convention (decrement when moving down).
List<T> reorderWithinPinGroups<T>({
  required List<T> items,
  required int oldIndex,
  required int newIndex,
  required bool Function(T item) isPinned,
}) {
  if (items.isEmpty) return items;
  if (oldIndex < 0 || oldIndex >= items.length) return List<T>.from(items);

  var target = newIndex;
  if (target > oldIndex) target--;
  target = target.clamp(0, items.length - 1);

  final item = items[oldIndex];
  final itemPinned = isPinned(item);
  final firstUnpinned = items.indexWhere((e) => !isPinned(e));
  final pinnedCount = firstUnpinned == -1 ? items.length : firstUnpinned;

  if (itemPinned) {
    if (pinnedCount == 0) return List<T>.from(items);
    target = target.clamp(0, pinnedCount - 1);
  } else {
    target = target.clamp(pinnedCount, items.length - 1);
  }

  if (target == oldIndex) return List<T>.from(items);

  final next = List<T>.from(items);
  final moved = next.removeAt(oldIndex);
  next.insert(target, moved);
  return next;
}

/// Moves [fromIndex] so it lands before [insertBeforeIndex] (0..length).
///
/// List stays visually stable during drag; this runs only on drop. Pin cohorts
/// are still respected.
List<T> moveToInsertSlot<T>({
  required List<T> items,
  required int fromIndex,
  required int insertBeforeIndex,
  required bool Function(T item) isPinned,
}) {
  if (items.isEmpty) return items;
  if (fromIndex < 0 || fromIndex >= items.length) return List<T>.from(items);

  final insertBefore = insertBeforeIndex.clamp(0, items.length);
  // No-op when dropping onto its own slot (before itself or before next).
  if (insertBefore == fromIndex || insertBefore == fromIndex + 1) {
    return List<T>.from(items);
  }

  final flutterNewIndex = insertBefore > fromIndex
      ? insertBefore
      : insertBefore;
  return reorderWithinPinGroups(
    items: items,
    oldIndex: fromIndex,
    newIndex: flutterNewIndex,
    isPinned: isPinned,
  );
}

/// Writes a reordered section back into the full home list order.
///
/// Section slots keep their positions among non-section items (e.g. reordering
/// personal groups does not reshuffle shared groups relative to them).
List<Group> replaceSectionOrder({
  required List<Group> fullOrder,
  required List<Group> sectionNewOrder,
  required bool Function(Group group) inSection,
}) {
  if (sectionNewOrder.isEmpty) return List<Group>.from(fullOrder);

  final queue = List<Group>.from(sectionNewOrder);
  var i = 0;
  return fullOrder.map((group) {
    if (!inSection(group)) return group;
    if (i >= queue.length) return group;
    return queue[i++];
  }).toList();
}
