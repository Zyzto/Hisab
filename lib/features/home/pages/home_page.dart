import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/layout/content_aligned_app_bar.dart';
import '../../../core/layout/content_aligned_fab_location.dart';
import '../../../core/layout/constrained_content.dart';
import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/theme/theme_providers.dart';
import '../../../core/widgets/async_value_builder.dart';
import '../../../core/widgets/sheet_option_tile.dart';
import '../../../core/widgets/shell_menu_button.dart';
import '../../../core/widgets/sync_status_icon.dart';
import '../../../core/widgets/user_text.dart';
import '../../groups/providers/groups_provider.dart';
import '../../settings/providers/settings_framework_providers.dart';
import '../../settings/settings_definitions.dart';
import '../../settings/widgets/apply_setting.dart';
import '../../groups/widgets/group_card.dart';
import '../../groups/widgets/group_section_header.dart';
import '../../transaction_scanner/providers/scanner_providers.dart';
import '../providers/home_list_provider.dart';
import '../utils/home_list_reorder.dart';
import '../widgets/home_reorderable_groups_sliver.dart';
import '../../../domain/domain.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key, this.routeDisplayMode});

  final String? routeDisplayMode;

  static String _modePathForDisplay(String display) {
    return switch (display) {
      'list_combined' => 'combined',
      _ => 'separate',
    };
  }

  static String? _displayModeFromPath(String path) {
    if (!path.startsWith('${RoutePaths.homeModeBase}/')) return null;
    if (path.endsWith('/combined')) return 'list_combined';
    if (path.endsWith('/separate')) return 'list_separate';
    return null;
  }

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
      centerInFullViewport: false,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          child: SheetOptionList(
            children: [
              SheetOptionTile(
                title: 'create_group'.tr(),
                subtitle: 'create_group_desc'.tr(),
                leading: Icon(
                  Icons.group_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () {
                  ref.read(selectedGroupIdsProvider.notifier).state = {};
                  Navigator.pop(context);
                  context.push(RoutePaths.groupCreate);
                },
              ),
              SheetOptionTile(
                title: 'create_personal'.tr(),
                subtitle: 'create_personal_desc'.tr(),
                leading: Icon(
                  Icons.person_outline,
                  color: colorScheme.onSurfaceVariant,
                ),
                onTap: () {
                  ref.read(selectedGroupIdsProvider.notifier).state = {};
                  Navigator.pop(context);
                  context.push(RoutePaths.groupCreatePersonal);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showListOptionsSheet(BuildContext context, WidgetRef ref) {
    final settings = ref.read(hisabSettingsProvidersProvider);
    if (settings == null) return;

    showResponsiveSheet<void>(
      context: context,
      title: 'home_list_options'.tr(),
      maxHeight: MediaQuery.of(context).size.height * 0.75,
      isScrollControlled: true,
      centerInFullViewport: true,
      child: Consumer(
        builder: (context, ref, _) {
          final theme = Theme.of(context);
          final cs = theme.colorScheme;
          final isTablet = LayoutBreakpoints.isTabletOrWider(context);
          final rawDisplay = ref.watch(homeListDisplayProvider);
          const validDisplays = {'list_separate', 'list_combined'};
          final display = validDisplays.contains(rawDisplay)
              ? rawDisplay
              : 'list_separate';
          final sort = ref.watch(homeListSortProvider);
          final showCreatedAt = ref.watch(homeListShowCreatedAtProvider);

          void setDisplay(String value) {
            final router = GoRouter.of(context);
            final path = RoutePaths.homeMode(_modePathForDisplay(value));
            ref
                .read(settings.provider(homeListDisplaySettingDef).notifier)
                .set(value);
            Log.info(
              'Setting changed: ${homeListDisplaySettingDef.key}=$value',
            );
            // Pop the sheet before navigating — go() under an open root dialog
            // replaces HomePage and leaves the options sheet stuck/unresponsive.
            final nav = Navigator.of(context, rootNavigator: true);
            if (nav.canPop()) {
              nav.pop();
            }
            router.go(path);
          }

          void setSort(String value) {
            if (value != 'custom') {
              ref.read(homeListPendingOrderIdsProvider.notifier).state = null;
            }
            ref
                .read(settings.provider(homeListSortSettingDef).notifier)
                .set(value);
            Log.info('Setting changed: ${homeListSortSettingDef.key}=$value');
          }

          void setShowCreatedAt(bool value) {
            ref
                .read(
                  settings.provider(homeListShowCreatedAtSettingDef).notifier,
                )
                .set(value);
            Log.info(
              'Setting changed: ${homeListShowCreatedAtSettingDef.key}=$value',
            );
          }

          Widget sectionLabel(String text) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                text,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isTablet)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'home_list_options'.tr(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    sectionLabel('home_list_display'.tr()),
                    SheetOptionList(
                      children: [
                        SheetOptionTile(
                          title: 'home_list_display_list_separate'.tr(),
                          leading: Icon(
                            Icons.view_agenda_outlined,
                            color: cs.onSurfaceVariant,
                          ),
                          selected: display == 'list_separate',
                          onTap: () => setDisplay('list_separate'),
                        ),
                        SheetOptionTile(
                          title: 'home_list_display_list_combined'.tr(),
                          leading: Icon(
                            Icons.view_list_outlined,
                            color: cs.onSurfaceVariant,
                          ),
                          selected: display == 'list_combined',
                          onTap: () => setDisplay('list_combined'),
                        ),
                      ],
                    ),
                    sectionLabel('home_list_sort'.tr()),
                    SheetOptionList(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      children: [
                        SheetOptionTile(
                          title: 'home_list_sort_created'.tr(),
                          leading: Icon(
                            Icons.event_outlined,
                            color: cs.onSurfaceVariant,
                          ),
                          selected: sort == 'created_at',
                          onTap: () => setSort('created_at'),
                        ),
                        SheetOptionTile(
                          title: 'home_list_sort_updated'.tr(),
                          leading: Icon(
                            Icons.update_outlined,
                            color: cs.onSurfaceVariant,
                          ),
                          selected: sort == 'updated_at',
                          onTap: () => setSort('updated_at'),
                        ),
                        SheetOptionTile(
                          title: 'home_list_sort_custom'.tr(),
                          subtitle: 'home_list_hold_to_reorder'.tr(),
                          leading: Icon(
                            Icons.swap_vert_rounded,
                            color: cs.onSurfaceVariant,
                          ),
                          selected: sort == 'custom',
                          onTap: () => setSort('custom'),
                        ),
                      ],
                    ),
                    sectionLabel('home_list_show_created_at'.tr()),
                    SheetOptionList(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      children: [
                        SheetOptionTile(
                          title: 'home_list_show_created_at'.tr(),
                          leading: Icon(
                            Icons.calendar_today_outlined,
                            color: cs.onSurfaceVariant,
                          ),
                          selected: showCreatedAt,
                          trailing: Switch.adaptive(
                            value: showCreatedAt,
                            onChanged: setShowCreatedAt,
                          ),
                          onTap: () => setShowCreatedAt(!showCreatedAt),
                        ),
                      ],
                    ),
                  ],
                ),
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
    final router = GoRouter.maybeOf(context);
    final routeDisplay =
        _displayModeFromPath(
          router?.routerDelegate.currentConfiguration.uri.path ?? '',
        ) ??
        routeDisplayMode;
    final display = validDisplays.contains(routeDisplay)
        ? routeDisplay!
        : (validDisplays.contains(rawDisplay) ? rawDisplay : 'list_separate');
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
    final experimentStyleIndex = ref.watch(experimentStyleIndexProvider);
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
      Log.info(
        'Setting changed: ${homeListPinnedIdsSettingDef.key}=${list.length} items',
      );
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
      Log.info(
        'Setting changed: ${homeListPinnedIdsSettingDef.key}=${list.length} items',
      );
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
            floatingActionButtonLocation: ContentAlignedFabLocation.of(
              context,
              contentAreaWidth: contentAreaWidth,
            ),
            appBar: ContentAlignedAppBar(
              contentAreaWidth: contentAreaWidth,
              leadingWidth: ShellAppBarLeading.widthFor(context),
              leading: inSelectionMode
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: clearSelection,
                      tooltip: 'cancel'.tr(),
                    )
                  : const ShellAppBarLeading(fallback: SyncStatusChip()),
              title: inSelectionMode
                  ? (selectedGroups.length == 1
                        ? UserText(
                            selectedGroups.first.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : Text(
                            'selected_count'.tr(
                              namedArgs: {
                                'count': selectedGroups.length.toString(),
                              },
                            ),
                            overflow: TextOverflow.ellipsis,
                          ))
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
                      if (ShellAppBarLeading.syncInActions(context))
                        const SyncStatusChip(),
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
                                    padding: const EdgeInsets.all(32.0),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 72,
                                          height: 72,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primaryContainer
                                                .withValues(alpha: 0.55),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.group_outlined,
                                            size: 34,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'no_groups'.tr(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
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

                  final scannerBadge = scannerAvailable
                      ? ref.watch(pendingDraftCountProvider).asData?.value ?? 0
                      : 0;

                  Widget buildCard(Group group, {bool keyed = true}) {
                    // Custom sort: hold-to-drag only.
                    // Other sorts: hold to select, then pin from the app bar.
                    final holdToReorder = sortCustom && !inSelectionMode;
                    return RepaintBoundary(
                      key: keyed ? ValueKey(group.id) : null,
                      child: GroupCard(
                        group: group,
                        experimentStyleIndex: experimentStyleIndex,
                        isSelected: selectedIds.contains(group.id),
                        badgeCount: group.isPersonal ? scannerBadge : 0,
                        onTap: () {
                          final cur = ref.read(selectedGroupIdsProvider);
                          if (cur.isNotEmpty) {
                            toggleSelection(group.id);
                          } else {
                            context.push(RoutePaths.groupDetail(group.id));
                          }
                        },
                        createdDateLabel:
                            formatCreatedDateLabel(group.createdAt),
                        isPinned: pinnedSet.contains(group.id),
                        onPinToggle: null,
                        onLongPress: holdToReorder
                            ? null
                            : () {
                                final cur = ref.read(selectedGroupIdsProvider);
                                if (cur.isEmpty) {
                                  ref
                                      .read(selectedGroupIdsProvider.notifier)
                                      .state = {group.id};
                                } else {
                                  toggleSelection(group.id);
                                }
                              },
                      ),
                    );
                  }

                  Future<void> persistOrder(List<Group> newOrder) async {
                    if (settings == null) return;
                    final newOrderIds = newOrder.map((g) => g.id).toList();
                    ref.read(homeListPendingOrderIdsProvider.notifier).state =
                        newOrderIds;
                    final orderOk = await applySetting(
                      ref,
                      settings,
                      homeListCustomOrderSettingDef,
                      newOrderIds.join(','),
                    );
                    final sortOk = await applySetting(
                      ref,
                      settings,
                      homeListSortSettingDef,
                      'custom',
                    );
                    final pending = ref.read(homeListPendingOrderIdsProvider);
                    if (orderOk &&
                        sortOk &&
                        pending != null &&
                        pending.join(',') == newOrderIds.join(',')) {
                      ref.read(homeListPendingOrderIdsProvider.notifier).state =
                          null;
                    }
                  }

                  Widget buildGroupSliver(List<Group> list) {
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => buildCard(list[index]),
                        childCount: list.length,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: false,
                      ),
                    );
                  }

                  // Custom sort: hold a card to drag; list stays put until drop.
                  final canReorder = sortCustom && !inSelectionMode;

                  Widget buildReorderSliver(
                    List<Group> list, {
                    required void Function(List<Group> sectionOrder) onSectionReorder,
                  }) {
                    return HomeReorderableGroupsSliver(
                      groups: list,
                      pinnedIds: pinnedSet,
                      itemBuilder: (context, group) =>
                          buildCard(group, keyed: false),
                      onReorderComplete: onSectionReorder,
                    );
                  }

                  if (displaySeparate) {
                    return wrapRefresh(
                      CustomScrollView(
                        key: const PageStorageKey<String>('home_list_separate'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          const SliverPadding(
                            padding: EdgeInsets.only(top: 8),
                          ),
                          if (personal.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  8,
                                ),
                                child: GroupSectionHeader(
                                  label: 'personal'.tr(),
                                ),
                              ),
                            ),
                            if (canReorder)
                              buildReorderSliver(
                                personal,
                                onSectionReorder: (newPersonal) {
                                  persistOrder(
                                    replaceSectionOrder(
                                      fullOrder: ordered,
                                      sectionNewOrder: newPersonal,
                                      inSection: (g) => g.isPersonal,
                                    ),
                                  );
                                },
                              )
                            else
                              buildGroupSliver(personal),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 16),
                            ),
                          ],
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                8,
                              ),
                              child: GroupSectionHeader(label: 'groups'.tr()),
                            ),
                          ),
                          if (shared.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
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
                              ),
                            )
                          else if (canReorder)
                            buildReorderSliver(
                              shared,
                              onSectionReorder: (newShared) {
                                persistOrder(
                                  replaceSectionOrder(
                                    fullOrder: ordered,
                                    sectionNewOrder: newShared,
                                    inSection: (g) => !g.isPersonal,
                                  ),
                                );
                              },
                            )
                          else
                            buildGroupSliver(shared),
                          const SliverPadding(
                            padding: EdgeInsets.only(bottom: 8),
                          ),
                        ],
                      ),
                    );
                  }

                  return wrapRefresh(
                    CustomScrollView(
                      key: const PageStorageKey<String>('home_list_combined'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        const SliverPadding(padding: EdgeInsets.only(top: 8)),
                        if (canReorder)
                          buildReorderSliver(
                            ordered,
                            onSectionReorder: persistOrder,
                          )
                        else
                          buildGroupSliver(ordered),
                        const SliverPadding(padding: EdgeInsets.only(bottom: 8)),
                      ],
                    ),
                  );
                },
              ),
            ),
            floatingActionButton: _HomeFabCluster(
              localOnly: localOnly,
              onCreate: () => _showCreateModal(context, ref),
              onScan: () {
                clearSelection();
                context.push(RoutePaths.scanInvite);
              },
            ),
          );
        },
      ),
    );
  }
}

class _HomeFabCluster extends StatelessWidget {
  const _HomeFabCluster({
    required this.localOnly,
    required this.onCreate,
    required this.onScan,
  });

  final bool localOnly;
  final VoidCallback onCreate;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final createFab = Semantics(
      label: 'create_group'.tr(),
      button: true,
      child: GestureDetector(
        onLongPress: onCreate,
        child: FloatingActionButton(
          heroTag: 'create_group',
          onPressed: onCreate,
          child: const Icon(Icons.add),
        ),
      ),
    );

    if (localOnly) return createFab;

    return LayoutBuilder(
      builder: (context, constraints) {
        const fabHeight = 56.0;
        const twoFabHeight = fabHeight * 2;
        final spacing = (constraints.maxHeight >= twoFabHeight + 12)
            ? 12.0
            : (constraints.maxHeight - twoFabHeight).clamp(0.0, 12.0);
        final column = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Semantics(
              label: 'scan_invite'.tr(),
              button: true,
              child: FloatingActionButton(
                heroTag: 'scan_invite',
                onPressed: onScan,
                child: const Icon(Icons.qr_code_scanner),
              ),
            ),
            SizedBox(height: spacing),
            createFab,
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
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('app_name'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              experimentStyleNameAt(index),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
