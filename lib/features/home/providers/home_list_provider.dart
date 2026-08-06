import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../../../domain/domain.dart';
import '../../groups/providers/groups_provider.dart';
import 'package:hisab/core/settings/providers/settings_framework_providers.dart';

/// Ordered list of groups for the home page.
///
/// Custom sort uses [customOrderRaw] only (pinning is disabled).
/// Date sorts put pinned groups first, then order by created/updated.
/// Home page uses [homeListDisplayProvider] to show one list or Personal + Groups sections.
List<Group> orderedGroupsForHome(
  List<Group> groups, {
  required String sortMode,
  required String customOrderRaw,
  required String pinnedIdsRaw,
}) {
  if (groups.isEmpty) return [];

  final idToGroup = {for (final g in groups) g.id: g};
  final groupIds = idToGroup.keys.toSet();

  final customOrderList = customOrderRaw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .where(groupIds.contains)
      .toList();
  final customOrderSet = customOrderList.toSet();
  final pinnedSet = pinnedIdsRaw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .where(groupIds.contains)
      .toSet();

  int compareBySort(String a, String b) {
    final ga = idToGroup[a]!;
    final gb = idToGroup[b]!;
    if (sortMode == 'created_at') {
      return gb.createdAt.compareTo(ga.createdAt);
    }
    return gb.updatedAt.compareTo(ga.updatedAt);
  }

  final List<String> orderedIds;
  if (sortMode == 'custom') {
    // Pure custom order — pinning does not apply.
    final notInCustom = groupIds.difference(customOrderSet).toList()
      ..sort(compareBySort);
    orderedIds = [...customOrderList, ...notInCustom];
  } else {
    // Date sort: sort all by date, then partition so pinned first (same order within each half).
    final allIds = groupIds.toList()..sort(compareBySort);
    final pinnedOrdered = allIds.where(pinnedSet.contains).toList();
    final unpinnedOrdered = allIds
        .where((id) => !pinnedSet.contains(id))
        .toList();
    orderedIds = [...pinnedOrdered, ...unpinnedOrdered];
  }

  return orderedIds.map((id) => idToGroup[id]!).toList();
}

/// When non-empty, the home page is in selection mode; ids are the selected group/list ids.
final selectedGroupIdsProvider = StateProvider<Set<String>>(
  (ref) => <String>{},
);

/// Optimistic custom order after a drag-reorder.
///
/// Kept until the home page clears it after settings persist succeeds.
/// Clearing after one frame raced async `.set()` and snapped the list back.
final homeListPendingOrderIdsProvider = StateProvider<List<String>?>(
  (ref) => null,
);

/// Provider that yields the ordered list for the home page. Combines [groupsProvider] with home list settings.
/// When [homeListPendingOrderIdsProvider] is set (optimistic reorder), uses that order until cleared.
final orderedGroupsForHomeProvider = Provider<AsyncValue<List<Group>>>((ref) {
  final groupsAsync = ref.watch(groupsProvider);
  final sort = ref.watch(homeListSortProvider);
  final customOrder = ref.watch(homeListCustomOrderProvider);
  final pendingOrderIds = ref.watch(homeListPendingOrderIdsProvider);
  final pinnedIds = ref.watch(homeListPinnedIdsProvider);

  return groupsAsync.when(
    data: (groups) {
      final customOrderRaw = (sort == 'custom' && pendingOrderIds != null)
          ? pendingOrderIds.join(',')
          : customOrder;
      return AsyncValue.data(
        orderedGroupsForHome(
          groups,
          sortMode: sort,
          customOrderRaw: customOrderRaw,
          pinnedIdsRaw: pinnedIds,
        ),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});
