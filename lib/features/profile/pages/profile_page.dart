import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/layout/constrained_content.dart';
import '../../../core/layout/content_aligned_app_bar.dart';
import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/amount_with_secondary_display.dart';
import '../../../core/widgets/group_section_header.dart';
import '../../../core/widgets/page_section_index.dart';
import '../../../domain/domain.dart';
import '../../groups/providers/groups_provider.dart';
import '../../groups/widgets/group_card.dart';
import '../../settings/providers/settings_framework_providers.dart';
import '../providers/notification_providers.dart';
import '../providers/profile_activity_provider.dart';
import '../providers/profile_dashboard_provider.dart';
import '../providers/profile_my_expenses_provider.dart';
import '../utils/notification_grouping.dart';
import '../widgets/personal_budget_card.dart';
import '../widgets/profile_account_section.dart';
import '../widgets/profile_activity_section.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _chronologicalFeed = false;
  String? _activeSectionId;
  bool _programmaticScroll = false;

  final _scrollController = ScrollController();
  final _scrollViewKey = GlobalKey();
  final _accountKey = GlobalKey();
  final _overviewKey = GlobalKey();
  final _analyticsKey = GlobalKey();
  final _expensesKey = GlobalKey();
  final _balancesKey = GlobalKey();
  final _budgetsKey = GlobalKey();
  final _activityKey = GlobalKey();
  final _groupsKey = GlobalKey();

  /// Last known scroll-pixel offsets for section tops (survives dispose).
  final Map<String, double> _sectionOffsets = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _rememberSectionOffset(String id, GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null || !_scrollController.hasClients) return;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final scrollable = Scrollable.maybeOf(ctx);
    if (scrollable == null) return;
    final scrollBox = scrollable.context.findRenderObject();
    if (scrollBox is! RenderBox) return;
    final local = box.localToGlobal(Offset.zero, ancestor: scrollBox);
    _sectionOffsets[id] = (local.dy + scrollable.position.pixels).clamp(
      0.0,
      double.infinity,
    );
  }

  void _captureVisibleOffsets() {
    final pairs = <(String, GlobalKey)>[
      ('account', _accountKey),
      ('overview', _overviewKey),
      ('analytics', _analyticsKey),
      ('expenses', _expensesKey),
      ('balances', _balancesKey),
      ('budgets', _budgetsKey),
      ('activity', _activityKey),
      ('groups', _groupsKey),
    ];
    for (final (id, key) in pairs) {
      _rememberSectionOffset(id, key);
    }
  }

  List<PageSectionIndexEntry> _entriesFor(ProfileDashboardData? data) {
    final entries = <PageSectionIndexEntry>[
      PageSectionIndexEntry(
        id: 'account',
        label: 'profile_index_account'.tr(),
        key: _accountKey,
        icon: Icons.person_outline_rounded,
      ),
      PageSectionIndexEntry(
        id: 'overview',
        label: 'profile_index_overview'.tr(),
        key: _overviewKey,
        icon: Icons.dashboard_outlined,
      ),
      PageSectionIndexEntry(
        id: 'analytics',
        label: 'profile_my_analytics'.tr(),
        key: _analyticsKey,
        icon: Icons.pie_chart_outline_rounded,
      ),
      PageSectionIndexEntry(
        id: 'expenses',
        label: 'profile_my_expenses'.tr(),
        key: _expensesKey,
        icon: Icons.receipt_long_outlined,
      ),
    ];
    if (data?.balanceRows.isNotEmpty == true) {
      entries.add(
        PageSectionIndexEntry(
          id: 'balances',
          label: 'profile_balances'.tr(),
          key: _balancesKey,
          icon: Icons.account_balance_wallet_outlined,
        ),
      );
    }
    if (data?.personalBudgets.isNotEmpty == true) {
      entries.add(
        PageSectionIndexEntry(
          id: 'budgets',
          label: 'profile_personal_budgets'.tr(),
          key: _budgetsKey,
          icon: Icons.savings_outlined,
        ),
      );
    }
    entries.add(
      PageSectionIndexEntry(
        id: 'activity',
        label: 'profile_recent_activity'.tr(),
        key: _activityKey,
        icon: Icons.notifications_none_rounded,
      ),
    );
    if (data?.groups.isNotEmpty == true) {
      entries.add(
        PageSectionIndexEntry(
          id: 'groups',
          label: 'profile_your_groups'.tr(),
          key: _groupsKey,
          icon: Icons.groups_outlined,
        ),
      );
    }
    return entries;
  }

  Future<void> _jumpTo(PageSectionIndexEntry entry) async {
    setState(() {
      _activeSectionId = entry.id;
      _programmaticScroll = true;
    });
    // Account is always at the top; jump there even if the widget was disposed.
    final known = entry.id == 'account'
        ? 0.0
        : _sectionOffsets[entry.id];
    await scrollToPageSection(
      entry.key,
      controller: _scrollController,
      knownOffset: known,
    );
    if (!mounted) return;
    _captureVisibleOffsets();
    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (mounted) _programmaticScroll = false;
    });
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      _captureVisibleOffsets();
    }
    if (_programmaticScroll) return false;
    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollEndNotification) {
      return false;
    }
    final scrollCtx = _scrollViewKey.currentContext;
    if (scrollCtx == null) return false;
    final data = ref.read(profileDashboardProvider).asData?.value;
    final entries = _entriesFor(data);
    final next = activePageSectionId(
      entries: entries,
      scrollContext: scrollCtx,
    );
    if (next != null && next != _activeSectionId) {
      setState(() => _activeSectionId = next);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(profileDashboardProvider);
    final data = dashboardAsync.asData?.value;
    final entries = _entriesFor(data);
    final entryIds = {for (final e in entries) e.id};
    final activeId = (_activeSectionId != null &&
            entryIds.contains(_activeSectionId))
        ? _activeSectionId
        : entries.firstOrNull?.id;

    return LayoutBuilder(
      builder: (context, layoutConstraints) {
        // Use the same width ConstrainedContent will see (scaffold body).
        final showSideIndex = _canShowSideIndex(
          context,
          layoutConstraints.maxWidth,
        );
        return Scaffold(
          appBar: ContentAlignedAppBar(
            contentAreaWidth: layoutConstraints.maxWidth,
            title: Text('profile'.tr()),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RoutePaths.home);
                }
              },
            ),
            actions: [
              IconButton(
                tooltip: 'settings'.tr(),
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push(RoutePaths.settings),
              ),
            ],
          ),
          body: ConstrainedContent(
            aside: showSideIndex
                ? PageSectionIndex(
                    entries: entries,
                    activeId: activeId,
                    onSelect: _jumpTo,
                  )
                : null,
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(dataSyncServiceProvider.notifier).syncNow();
                    ref.invalidate(profileDashboardProvider);
                    ref.invalidate(profileActivityProvider);
                    ref.invalidate(profileMyExpensesProvider);
                    ref.invalidate(userNotificationsProvider);
                  },
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: ListView(
                      key: _scrollViewKey,
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(
                        bottom: showSideIndex ? 32 : 88,
                      ),
                      children: [
                        KeyedSubtree(
                          key: _accountKey,
                          child: const ProfileAccountSection(),
                        ),
                        const Divider(height: 24),
                        dashboardAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (e, _) => Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('$e'),
                          ),
                          data: (data) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              KeyedSubtree(
                                key: _overviewKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _GlobalNetHero(net: data.globalNet),
                                    const SizedBox(height: 8),
                                    _KpiStrip(kpis: data.kpis),
                                  ],
                                ),
                              ),
                              ProfileActivitySection(
                                analyticsSectionKey: _analyticsKey,
                                expensesSectionKey: _expensesKey,
                              ),
                              if (data.balanceRows.isNotEmpty) ...[
                                KeyedSubtree(
                                  key: _balancesKey,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      8,
                                    ),
                                    child: GroupSectionHeader(
                                      label: 'profile_balances'.tr(),
                                    ),
                                  ),
                                ),
                                ...data.balanceRows.map(
                                  (row) => ListTile(
                                    title: Text(row.group.name),
                                    subtitle: Text(
                                      row.youOwe
                                          ? 'you_owe'.tr()
                                          : 'owes_you'.tr(),
                                    ),
                                    trailing: AmountWithSecondaryDisplay(
                                      amountCents: row.balanceCents.abs(),
                                      groupCurrencyCode: row.currencyCode,
                                      isNegative: row.youOwe,
                                    ),
                                    onTap: () => context.push(
                                      RoutePaths.groupDetail(row.group.id),
                                    ),
                                  ),
                                ),
                              ],
                              if (data.personalBudgets.isNotEmpty) ...[
                                KeyedSubtree(
                                  key: _budgetsKey,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      8,
                                    ),
                                    child: GroupSectionHeader(
                                      label: 'profile_personal_budgets'.tr(),
                                    ),
                                  ),
                                ),
                                ...data.personalBudgets.map(
                                  (row) => Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      4,
                                    ),
                                    child: PersonalBudgetCard.fromRow(
                                      row,
                                      onTap: () => context.push(
                                        RoutePaths.groupDetail(row.group.id),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              KeyedSubtree(
                                key: _activityKey,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    0,
                                  ),
                                  child: GroupSectionHeader(
                                    label: 'profile_recent_activity'.tr(),
                                    trailing: TextButton(
                                      onPressed: () => setState(
                                        () => _chronologicalFeed =
                                            !_chronologicalFeed,
                                      ),
                                      child: Text(
                                        _chronologicalFeed
                                            ? 'profile_feed_grouped'.tr()
                                            : 'profile_feed_show_all'.tr(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              _ActivityFeed(
                                chronological: _chronologicalFeed,
                                groups: data.groups,
                              ),
                              if (data.groups.isNotEmpty) ...[
                                KeyedSubtree(
                                  key: _groupsKey,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      8,
                                    ),
                                    child: GroupSectionHeader(
                                      label: 'profile_your_groups'.tr(),
                                    ),
                                  ),
                                ),
                                ...data.groups.map(
                                  (g) => GroupCard(
                                    group: g,
                                    onTap: () => context.push(
                                      RoutePaths.groupDetail(g.id),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!showSideIndex)
                  PageSectionIndexOverlay(
                    entries: entries,
                    activeId: activeId,
                    onSelect: _jumpTo,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Matches [ConstrainedContent] aside visibility so mobile TOC appears when
  /// the side rail would not fit.
  bool _canShowSideIndex(BuildContext context, double contentAreaWidth) {
    if (!LayoutBreakpoints.isTabletOrWider(context)) return false;
    final (leftOffset, bandWidth) = LayoutBreakpoints.contentBandMetrics(
      context,
      contentAreaWidth,
    );
    final rightFree = (contentAreaWidth - leftOffset - bandWidth).clamp(
      0.0,
      double.infinity,
    );
    return rightFree >= 176 + 8;
  }
}

class _GlobalNetHero extends ConsumerWidget {
  const _GlobalNetHero({required this.net});

  final ProfileGlobalNet? net;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final displayCurrency = ref.watch(displayCurrencyProvider);

    if (displayCurrency.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          child: ListTile(
            leading: Icon(Icons.currency_exchange, color: cs.primary),
            title: Text('profile_set_display_currency'.tr()),
            subtitle: Text('profile_set_display_currency_hint'.tr()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(RoutePaths.settings),
          ),
        ),
      );
    }

    if (net == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'profile_global_net_empty'.tr(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      );
    }

    final owed = net!.netDisplayCents >= 0;
    final label = owed ? 'owes_you'.tr() : 'you_owe'.tr();
    final color = owed ? cs.primary : cs.error;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'profile_global_net'.tr(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(color: color),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.formatCents(
                net!.netDisplayCents.abs(),
                net!.displayCurrencyCode,
              ),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            if (net!.isPartial) ...[
              const SizedBox(height: 8),
              Text(
                'profile_global_net_partial'.tr(
                  namedArgs: {
                    'converted': '${net!.convertedGroupCount}',
                    'skipped': '${net!.skippedGroupCount}',
                  },
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.kpis});

  final ProfileKpis kpis;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.groups_outlined, 'profile_kpi_groups'.tr(), kpis.sharedGroups),
      (Icons.person_outline, 'profile_kpi_personal'.tr(), kpis.personalLists),
      (Icons.archive_outlined, 'profile_kpi_archived'.tr(), kpis.archived),
      (
        Icons.receipt_long_outlined,
        'profile_kpi_drafts'.tr(),
        kpis.pendingDrafts,
      ),
      (
        Icons.notifications_outlined,
        'profile_kpi_unread'.tr(),
        kpis.unreadNotifications,
      ),
    ];

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (icon, label, value) = items[i];
          final cs = Theme.of(context).colorScheme;
          return Container(
            width: 108,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: cs.primary),
                const Spacer(),
                Text(
                  '$value',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ActivityFeed extends ConsumerWidget {
  const _ActivityFeed({required this.chronological, required this.groups});

  final bool chronological;
  final List<Group> groups;

  String _groupName(String? groupId) {
    if (groupId == null) return 'groups'.tr();
    for (final g in groups) {
      if (g.id == groupId) return g.name;
    }
    return 'groups'.tr();
  }

  String _groupedTitle(NotificationFeedItem item) {
    final count = '${item.items.length}';
    final group = _groupName(item.groupId);
    final args = {'count': count, 'group': group};
    return switch (item.actionFamily) {
      'expense' => 'profile_feed_grouped_expenses'.tr(namedArgs: args),
      'member' => 'profile_feed_grouped_members'.tr(namedArgs: args),
      _ => 'profile_feed_grouped_other'.tr(namedArgs: args),
    };
  }

  Future<void> _openItem(
    BuildContext context,
    WidgetRef ref,
    NotificationFeedItem item,
  ) async {
    for (final x in item.items) {
      if (x.isUnread) {
        await ref.read(userNotificationRepositoryProvider).markRead(x.id);
      }
    }
    if (!context.mounted) return;
    final n = item.items.first;
    final groupId = n.groupId;
    if (groupId == null) return;
    if (item.isGroup || n.expenseId == null) {
      context.push(RoutePaths.groupDetail(groupId));
    } else {
      context.push(RoutePaths.groupExpenseDetail(groupId, n.expenseId!));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(userNotificationsProvider);
    // Keep groups list fresh if dashboard snapshot is stale.
    ref.watch(groupsProvider);

    return notificationsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('profile_activity_empty'.tr()),
      ),
      data: (notifications) {
        if (notifications.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'profile_activity_empty'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        final items = chronological
            ? notifications
                  .map(NotificationFeedItem.single)
                  .toList(growable: false)
            : groupNotifications(notifications);

        return Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () =>
                    ref.read(userNotificationRepositoryProvider).markAllRead(),
                child: Text('profile_mark_all_read'.tr()),
              ),
            ),
            ...items.map((item) {
              final n = item.items.first;
              final unread = item.hasUnread;
              final title = item.isGroup ? _groupedTitle(item) : n.title;
              final leading = CircleAvatar(
                backgroundColor: unread
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  item.actionFamily == 'member'
                      ? Icons.person_add_alt_1_outlined
                      : Icons.receipt_long_outlined,
                  size: 18,
                ),
              );

              if (item.isGroup) {
                return ExpansionTile(
                  leading: leading,
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    _groupName(item.groupId),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  children: [
                    for (final child in item.items)
                      ListTile(
                        dense: true,
                        title: Text(child.title),
                        subtitle: Text(
                          child.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _openItem(
                          context,
                          ref,
                          NotificationFeedItem.single(child),
                        ),
                      ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.open_in_new, size: 18),
                      title: Text('profile_your_groups'.tr()),
                      onTap: () => _openItem(context, ref, item),
                    ),
                  ],
                );
              }

              return ListTile(
                leading: leading,
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  n.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _openItem(context, ref, item),
              );
            }),
          ],
        );
      },
    );
  }
}
