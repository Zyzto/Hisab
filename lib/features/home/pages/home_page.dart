import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/layout/content_aligned_app_bar.dart';
import '../../../core/layout/content_aligned_fab_location.dart';
import '../../../core/layout/constrained_content.dart';
import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/theme/theme_providers.dart';
import '../../../core/widgets/async_value_builder.dart';
import '../../../core/widgets/participant_avatar.dart';
import '../../../core/widgets/sheet_option_tile.dart';
import '../../../core/widgets/shell_menu_button.dart';
import '../../../core/widgets/sync_status_icon.dart';
import '../../groups/providers/groups_provider.dart';
import '../../settings/providers/settings_framework_providers.dart';
import '../../settings/settings_definitions.dart';
import '../../groups/widgets/group_card.dart';
import '../../groups/widgets/group_section_header.dart';
import '../../transaction_scanner/providers/scanner_providers.dart';
import '../providers/home_list_provider.dart';
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
            ref
                .read(settings.provider(homeListDisplaySettingDef).notifier)
                .set(value);
            Log.info(
              'Setting changed: ${homeListDisplaySettingDef.key}=$value',
            );
            context.go(RoutePaths.homeMode(_modePathForDisplay(value)));
          }

          void setSort(String value) {
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
                      padding: EdgeInsets.fromLTRB(16, isTablet ? 8 : 0, 16, 8),
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
                          leading: Icon(
                            Icons.drag_handle_rounded,
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
          final showMobileProfileAvatar =
              !LayoutBreakpoints.isTabletOrWider(context) && !inSelectionMode;
          final profile = ref.watch(authUserProfileProvider).asData?.value;
          final signedIn = ref.watch(currentUserProvider) != null;
          final avatarName =
              profile?.name ??
              profile?.email ??
              (signedIn ? 'account'.tr() : 'sign_in'.tr());

          return Scaffold(
            floatingActionButtonLocation: ContentAlignedFabLocation.of(
              context,
              contentAreaWidth: contentAreaWidth,
              narrowFallback: showMobileProfileAvatar
                  ? FloatingActionButtonLocation.centerFloat
                  : FloatingActionButtonLocation.endFloat,
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

                  Widget buildCard(Group group) {
                    return GroupCard(
                      key: ValueKey(group.id),
                      group: group,
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
                    Log.info(
                      'Setting changed: ${homeListCustomOrderSettingDef.key}=${newOrderIds.length} items, '
                      '${homeListSortSettingDef.key}=custom',
                    );
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
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: GroupSectionHeader(
                                label: 'personal'.tr(),
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
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: GroupSectionHeader(label: 'groups'.tr()),
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
            floatingActionButton: _HomeFabCluster(
              localOnly: localOnly,
              showProfileAvatar: showMobileProfileAvatar,
              avatarName: avatarName,
              avatarId: profile?.avatarId,
              onCreate: () => _showCreateModal(context, ref),
              onScan: () {
                clearSelection();
                context.push(RoutePaths.scanInvite);
              },
              onProfile: () {
                clearSelection();
                // Profile shows local stats + sign-in / switch-online CTAs.
                context.push(RoutePaths.profile);
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
    required this.showProfileAvatar,
    required this.avatarName,
    required this.onCreate,
    required this.onScan,
    required this.onProfile,
    this.avatarId,
  });

  final bool localOnly;
  final bool showProfileAvatar;
  final String avatarName;
  final String? avatarId;
  final VoidCallback onCreate;
  final VoidCallback onScan;
  final VoidCallback onProfile;

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

    final Widget endFabs;
    if (localOnly) {
      endFabs = createFab;
    } else {
      endFabs = LayoutBuilder(
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

    if (!showProfileAvatar) return endFabs;

    final cs = Theme.of(context).colorScheme;
    final avatarFab = Semantics(
      label: 'profile'.tr(),
      button: true,
      child: Material(
        elevation: 6,
        shape: const CircleBorder(),
        color: cs.primaryContainer,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onProfile,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: ParticipantAvatar(
              name: avatarName,
              avatarId: avatarId,
              radius: 24,
              backgroundColor: cs.primaryContainer,
              foregroundColor: cs.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      width: MediaQuery.sizeOf(context).width - 32,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          avatarFab,
          const Spacer(),
          endFabs,
        ],
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
