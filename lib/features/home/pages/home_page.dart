import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/layout/content_aligned_app_bar.dart';
import '../../../core/layout/constrained_content.dart';
import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/theme/theme_providers.dart';
import '../../../core/widgets/async_value_builder.dart';
import '../../../core/widgets/sync_status_icon.dart';
import '../../groups/providers/groups_provider.dart';
import '../../settings/providers/settings_framework_providers.dart';
import '../../settings/settings_definitions.dart';
import '../../groups/widgets/group_card.dart';
import '../providers/home_list_provider.dart';
import '../../../domain/domain.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _onRefresh(WidgetRef ref) async {
    await ref.read(dataSyncServiceProvider.notifier).syncNow();
    ref.invalidate(groupsProvider);
  }

  void _showCreateModal(BuildContext context, WidgetRef ref) {
    ref.read(selectedGroupIdsProvider.notifier).state = {};
    final colorScheme = Theme.of(context).colorScheme;
    showResponsiveSheet<void>(
      context: context,
      title: 'create'.tr(),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.group_outlined,
                color: colorScheme.onSurfaceVariant,
              ),
              title: Text('create_group'.tr()),
              onTap: () {
                ref.read(selectedGroupIdsProvider.notifier).state = {};
                Navigator.pop(context);
                context.push(RoutePaths.groupCreate);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.person_outline,
                color: colorScheme.onSurfaceVariant,
              ),
              title: Text('create_personal'.tr()),
              onTap: () {
                ref.read(selectedGroupIdsProvider.notifier).state = {};
                Navigator.pop(context);
                context.push(RoutePaths.groupCreatePersonal);
              },
            ),
          ],
        ),
      ),
    );
  }

  static void _showListOptionsSheet(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.read(hisabSettingsProvidersProvider);
    if (settings == null) return;

    showResponsiveSheet<void>(
      context: context,
      title: 'home_list_options'.tr(),
      child: Consumer(
        builder: (context, ref, _) {
          final rawDisplay = ref.watch(homeListDisplayProvider);
          const validDisplays = {'list_separate', 'list_combined'};
          final display = validDisplays.contains(rawDisplay)
              ? rawDisplay
              : 'list_separate';
          final sort = ref.watch(homeListSortProvider);
          final showCreatedAt = ref.watch(homeListShowCreatedAtProvider);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!LayoutBreakpoints.isTabletOrWider(context))
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        'home_list_options'.tr(),
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ListTile(
                    title: Text('home_list_display'.tr()),
                    trailing: DropdownButton<String>(
                      value: display,
                      items: [
                        DropdownMenuItem(
                          value: 'list_separate',
                          child: Text('home_list_display_list_separate'.tr()),
                        ),
                        DropdownMenuItem(
                          value: 'list_combined',
                          child: Text('home_list_display_list_combined'.tr()),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          ref
                              .read(
                                settings
                                    .provider(homeListDisplaySettingDef)
                                    .notifier,
                              )
                              .set(v);
                        }
                      },
                    ),
                  ),
                  ListTile(
                    title: Text('home_list_sort'.tr()),
                    trailing: DropdownButton<String>(
                      value: sort,
                      items: [
                        DropdownMenuItem(
                          value: 'created_at',
                          child: Text('home_list_sort_created'.tr()),
                        ),
                        DropdownMenuItem(
                          value: 'updated_at',
                          child: Text('home_list_sort_updated'.tr()),
                        ),
                        DropdownMenuItem(
                          value: 'custom',
                          child: Text('home_list_sort_custom'.tr()),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          ref
                              .read(
                                settings
                                    .provider(homeListSortSettingDef)
                                    .notifier,
                              )
                              .set(v);
                        }
                      },
                    ),
                  ),
                  SwitchListTile(
                    title: Text('home_list_show_created_at'.tr()),
                    value: showCreatedAt,
                    onChanged: (v) {
                      ref
                          .read(
                            settings
                                .provider(homeListShowCreatedAtSettingDef)
                                .notifier,
                          )
                          .set(v);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderedAsync = ref.watch(orderedGroupsForHomeProvider);
    final selectedIds = ref.watch(selectedGroupIdsProvider);
    final ordered = orderedAsync.value;
    final inSelectionMode = selectedIds.isNotEmpty;
    final selectedGroups = ordered != null
        ? ordered.where((g) => selectedIds.contains(g.id)).toList()
        : <Group>[];
    final localOnly = ref.watch(effectiveLocalOnlyProvider);
    final rawDisplay = ref.watch(homeListDisplayProvider);
    const validDisplays = {'list_separate', 'list_combined'};
    final display = validDisplays.contains(rawDisplay)
        ? rawDisplay
        : 'list_separate';
    final displaySeparate = display == 'list_separate';
    final sortCustom = ref.watch(homeListSortProvider) == 'custom';
    final showCreatedAt = ref.watch(homeListShowCreatedAtProvider);
    final pinnedIdsRaw = ref.watch(homeListPinnedIdsProvider);
    final pinnedSet = pinnedIdsRaw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    final selectionAllPinned =
        selectedIds.isNotEmpty &&
        selectedIds.every((id) => pinnedSet.contains(id));
    final settings = ref.read(hisabSettingsProvidersProvider);
    String? formatCreatedDateLabel(DateTime date) {
      if (!showCreatedAt) return null;
      final day = DateFormat.d().format(date);
      final month = DateFormat.MMM().format(date);
      return '$day\n$month';
    }

    void clearSelection() {
      ref.read(selectedGroupIdsProvider.notifier).state = {};
    }

    void toggleSelection(String groupId) {
      final current = ref.read(selectedGroupIdsProvider);
      final next = Set<String>.from(current);
      if (next.contains(groupId)) {
        next.remove(groupId);
      } else {
        next.add(groupId);
      }
      ref.read(selectedGroupIdsProvider.notifier).state = next;
    }

    void pinSelected() {
      if (settings == null || selectedIds.isEmpty) return;
      final list = pinnedIdsRaw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      for (final id in selectedIds) {
        if (!list.contains(id)) list.add(id);
      }
      ref
          .read(settings.provider(homeListPinnedIdsSettingDef).notifier)
          .set(list.join(','));
      clearSelection();
    }

    void unpinSelected() {
      if (settings == null || selectedIds.isEmpty) return;
      final list = pinnedIdsRaw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      list.removeWhere(selectedIds.contains);
      ref
          .read(settings.provider(homeListPinnedIdsSettingDef).notifier)
          .set(list.join(','));
      clearSelection();
    }

    return PopScope(
      canPop: !inSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && inSelectionMode) clearSelection();
      },
      child: LayoutBuilder(
        builder: (context, layoutConstraints) {
          final contentAreaWidth = layoutConstraints.maxWidth;
          return Scaffold(
            appBar: ContentAlignedAppBar(
              contentAreaWidth: contentAreaWidth,
              leading: inSelectionMode
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: clearSelection,
                      tooltip: 'cancel'.tr(),
                    )
                  : const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SyncStatusChip(),
                    ),
              title: inSelectionMode
                  ? Text(
                      selectedGroups.length == 1
                          ? selectedGroups.first.name
                          : 'selected_count'.tr(
                              namedArgs: {
                                'count': selectedGroups.length.toString(),
                              },
                            ),
                      overflow: TextOverflow.ellipsis,
                    )
                  : _ExperimentTitle(),
              actions: inSelectionMode
                  ? [
                      IconButton(
                        icon: const Icon(Icons.push_pin),
                        onPressed: selectionAllPinned
                            ? unpinSelected
                            : pinSelected,
                        tooltip: selectionAllPinned ? 'unpin'.tr() : 'pin'.tr(),
                      ),
                    ]
                  : [
                      Semantics(
                        label: 'home_list_options'.tr(),
                        button: true,
                        child: IconButton(
                          icon: const Icon(Icons.view_list),
                          onPressed: () {
                            clearSelection();
                            _showListOptionsSheet(context, ref);
                          },
                          tooltip: 'home_list_options'.tr(),
                        ),
                      ),
                      Semantics(
                        label: 'archived_groups'.tr(),
                        button: true,
                        child: IconButton(
                          icon: const Icon(Icons.archive_outlined),
                          onPressed: () {
                            clearSelection();
                            context.push(RoutePaths.archivedGroups);
                          },
                          tooltip: 'archived_groups'.tr(),
                        ),
                      ),
                    ],
            ),
            body: ConstrainedContent(
              child: AsyncValueBuilder<List<Group>>(
                value: orderedAsync,
                data: (context, ordered) {
                  final isEmpty = ordered.isEmpty;

                  Widget wrapRefresh(Widget child) {
                    if (inSelectionMode) return child;
                    return RefreshIndicator(
                      onRefresh: () => _onRefresh(ref),
                      child: child,
                    );
                  }

                  if (isEmpty) {
                    return wrapRefresh(
                      LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                              key: const PageStorageKey<String>(
                                'home_list_empty',
                              ),
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.group_outlined,
                                          size: 64,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'no_groups'.tr(),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'add_first_group'.tr(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      ),
                    );
                  }

                  final personal = ordered.where((g) => g.isPersonal).toList();
                  final shared = ordered.where((g) => !g.isPersonal).toList();

                  Widget buildCard(Group group) {
                    return GroupCard(
                      key: ValueKey(group.id),
                      group: group,
                      isSelected: selectedIds.contains(group.id),
                      onTap: () {
                        final cur = ref.read(selectedGroupIdsProvider);
                        if (cur.isNotEmpty) {
                          toggleSelection(group.id);
                        } else {
                          context.push(RoutePaths.groupDetail(group.id));
                        }
                      },
                      createdDateLabel: formatCreatedDateLabel(group.createdAt),
                      isPinned: pinnedSet.contains(group.id),
                      onPinToggle: null,
                      onLongPress: () {
                        final cur = ref.read(selectedGroupIdsProvider);
                        if (cur.isEmpty) {
                          ref.read(selectedGroupIdsProvider.notifier).state = {
                            group.id,
                          };
                        } else {
                          toggleSelection(group.id);
                        }
                      },
                    );
                  }

                  void persistOrder(List<Group> newOrder) {
                    if (settings == null) return;
                    final newOrderIds = newOrder.map((g) => g.id).toList();
                    ref.read(homeListPendingOrderIdsProvider.notifier).state =
                        newOrderIds;
                    ref
                        .read(
                          settings
                              .provider(homeListCustomOrderSettingDef)
                              .notifier,
                        )
                        .set(newOrderIds.join(','));
                    ref
                        .read(
                          settings.provider(homeListSortSettingDef).notifier,
                        )
                        .set('custom');
                    SchedulerBinding.instance.addPostFrameCallback((_) {
                      ref.read(homeListPendingOrderIdsProvider.notifier).state =
                          null;
                    });
                  }

                  List<Widget> buildListItems(List<Group> list) {
                    return list.map((g) => buildCard(g)).toList();
                  }

                  Widget buildReorderableItem(Group group, int index) {
                    final theme = Theme.of(context);
                    return IntrinsicHeight(
                      key: ValueKey(group.id),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: ReorderableDragStartListener(
                              index: index,
                              child: Semantics(
                                label: 'reorder'.tr(),
                                child: SizedBox(
                                  width: 32,
                                  child: Center(
                                    child: Icon(
                                      Icons.drag_handle,
                                      color: theme.colorScheme.onSurfaceVariant,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(child: buildCard(group)),
                        ],
                      ),
                    );
                  }

                  if (displaySeparate) {
                    return wrapRefresh(
                      ListView(
                        key: const PageStorageKey<String>('home_list_separate'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          if (personal.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Text(
                                'personal'.tr(),
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            if (sortCustom && inSelectionMode)
                              ReorderableListView(
                                shrinkWrap: true,
                                buildDefaultDragHandles: false,
                                onReorder: (oldIndex, newIndex) {
                                  if (newIndex > oldIndex) newIndex--;
                                  final newPersonal = List<Group>.from(
                                    personal,
                                  );
                                  final item = newPersonal.removeAt(oldIndex);
                                  newPersonal.insert(newIndex, item);
                                  persistOrder([...newPersonal, ...shared]);
                                },
                                children: personal
                                    .asMap()
                                    .entries
                                    .map(
                                      (e) =>
                                          buildReorderableItem(e.value, e.key),
                                    )
                                    .toList(),
                              )
                            else
                              ...buildListItems(personal),
                            const SizedBox(height: 16),
                          ],
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              'groups'.tr(),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (shared.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              child: Text(
                                'no_groups'.tr(),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else if (sortCustom && inSelectionMode)
                            ReorderableListView(
                              shrinkWrap: true,
                              buildDefaultDragHandles: false,
                              onReorder: (oldIndex, newIndex) {
                                if (newIndex > oldIndex) newIndex--;
                                final newShared = List<Group>.from(shared);
                                final item = newShared.removeAt(oldIndex);
                                newShared.insert(newIndex, item);
                                persistOrder([...personal, ...newShared]);
                              },
                              children: shared
                                  .asMap()
                                  .entries
                                  .map(
                                    (e) => buildReorderableItem(e.value, e.key),
                                  )
                                  .toList(),
                            )
                          else
                            ...buildListItems(shared),
                        ],
                      ),
                    );
                  }

                  return wrapRefresh(
                    sortCustom && inSelectionMode
                        ? ReorderableListView(
                            key: const PageStorageKey<String>(
                              'home_list_combined',
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            buildDefaultDragHandles: false,
                            onReorder: (oldIndex, newIndex) {
                              if (newIndex > oldIndex) newIndex--;
                              final newOrder = List<Group>.from(ordered);
                              final item = newOrder.removeAt(oldIndex);
                              newOrder.insert(newIndex, item);
                              persistOrder(newOrder);
                            },
                            children: ordered
                                .asMap()
                                .entries
                                .map(
                                  (e) => buildReorderableItem(e.value, e.key),
                                )
                                .toList(),
                          )
                        : ListView(
                            key: const PageStorageKey<String>(
                              'home_list_combined',
                            ),
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            children: buildListItems(ordered),
                          ),
                  );
                },
              ),
            ),
            floatingActionButton: localOnly
                ? Semantics(
                    label: 'create_group'.tr(),
                    button: true,
                    child: GestureDetector(
                      onLongPress: () => _showCreateModal(context, ref),
                      child: FloatingActionButton(
                        onPressed: () => _showCreateModal(context, ref),
                        child: const Icon(Icons.add),
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      const fabHeight = 56.0;
                      const twoFabHeight = fabHeight * 2;
                      final spacing =
                          (constraints.maxHeight >= twoFabHeight + 12)
                          ? 12.0
                          : (constraints.maxHeight - twoFabHeight).clamp(
                              0.0,
                              12.0,
                            );
                      final column = Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Semantics(
                            label: 'scan_invite'.tr(),
                            button: true,
                            child: FloatingActionButton(
                              heroTag: 'scan_invite',
                              onPressed: () {
                                clearSelection();
                                context.push(RoutePaths.scanInvite);
                              },
                              child: const Icon(Icons.qr_code_scanner),
                            ),
                          ),
                          SizedBox(height: spacing),
                          Semantics(
                            label: 'create_group'.tr(),
                            button: true,
                            child: GestureDetector(
                              onLongPress: () => _showCreateModal(context, ref),
                              child: FloatingActionButton(
                                onPressed: () => _showCreateModal(context, ref),
                                child: const Icon(Icons.add),
                              ),
                            ),
                          ),
                        ],
                      );
                      if (constraints.maxHeight.isFinite &&
                          constraints.maxHeight < twoFabHeight &&
                          constraints.maxHeight > 0) {
                        return FittedBox(
                          alignment: Alignment.bottomCenter,
                          child: column,
                        );
                      }
                      return column;
                    },
                  ),
          );
        },
      ),
    );
  }
}

/// Tappable app title with current experiment style name below (smaller font). Cycles through 6 styles on tap.
class _ExperimentTitle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(experimentStyleIndexProvider);
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        final nextIndex = (index + 1) % 6;
        ref.read(experimentStyleIndexProvider.notifier).state = nextIndex;
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('app_name'.tr()),
          Text(experimentStyleNameAt(index), style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
