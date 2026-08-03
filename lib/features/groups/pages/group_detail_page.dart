import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import '../../../core/celebration/celebration_controller.dart';
import '../../../core/celebration/celebration_kind.dart';
import '../../../core/celebration/membership_celebration_binder.dart';
import '../../../core/layout/content_aligned_app_bar.dart';
import '../../../core/layout/content_aligned_fab_location.dart';
import '../../../core/layout/constrained_content.dart';
import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../../../core/platform/ui_perf.dart';
import '../providers/groups_provider.dart';
import '../providers/group_member_provider.dart';
import '../widgets/create_invite_sheet.dart';
import '../widgets/group_section_header.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/navigation/decorative_route.dart';
import '../../../core/navigation/invite_auth_helpers.dart';
import '../../../core/navigation/nav_back.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/widgets/missing_route_page.dart';
import '../../../core/theme/accent_style.dart';
import '../../../core/theme/theme_config.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/error_report_helper.dart';
import '../../../core/services/settle_up_service.dart';
import '../../../core/utils/expense_totals.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/utils/user_text.dart';
import '../../../core/widgets/amount_with_secondary_display.dart';
import '../../../core/widgets/app_fab.dart';
import '../../../core/widgets/async_value_builder.dart';
import '../../../core/widgets/error_content.dart';
import '../../../core/widgets/participant_avatar.dart';
import '../../../core/widgets/sheet_helpers.dart';
import '../../../core/widgets/sheet_option_tile.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/widgets/user_text.dart';
import '../../expenses/widgets/expense_list_tile.dart';
import '../../expenses/category_icons.dart';
import '../../balance/widgets/balance_list.dart';
import '../../profile/widgets/personal_budget_card.dart';
import '../../settings/providers/settings_framework_providers.dart';
import '../../settings/settings_definitions.dart';
import '../../../domain/domain.dart';
import '../utils/group_icon_utils.dart';

const double _kTabFabBottomClearance = 96.0;

const double _kTabListBottomSpacing = 16.0;

enum GroupDetailTab { expenses, balance, people }

/// Maps a location path to the group-detail tab index (0 expenses / 1 balance /
/// 2 people), or null when the path is not a tab URL for this group/preview.
@visibleForTesting
int? groupDetailTabIndexFromPath({
  required String path,
  required String groupId,
  bool readOnlyPreview = false,
  String? previewToken,
}) {
  if (readOnlyPreview) {
    final token = previewToken ?? '';
    if (token.isEmpty) return null;
    if (path == RoutePaths.invitePreviewBalance(token)) return 1;
    if (path == RoutePaths.invitePreviewPeople(token)) return 2;
    if (path == RoutePaths.invitePreviewExpenses(token)) return 0;
    return null;
  }
  if (path == RoutePaths.groupBalance(groupId)) return 1;
  if (path == RoutePaths.groupPeople(groupId)) return 2;
  if (path == RoutePaths.groupExpenses(groupId)) return 0;
  return null;
}

/// Keeps a [PageView.builder] child alive after first visit (scroll position).
class _KeepAliveTab extends StatefulWidget {
  const _KeepAliveTab({required this.child});

  final Widget child;

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class GroupDetailPage extends ConsumerStatefulWidget {
  final String groupId;
  final bool readOnlyPreview;
  final String? previewToken;
  final InviteAccessMode? previewAccessMode;
  final GroupDetailTab initialTab;

  const GroupDetailPage({
    super.key,
    required this.groupId,
    this.readOnlyPreview = false,
    this.previewToken,
    this.previewAccessMode,
    this.initialTab = GroupDetailTab.expenses,
  });

  @override
  ConsumerState<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends ConsumerState<GroupDetailPage> {
  bool _nullRetryDone = false;

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(futureGroupProvider(widget.groupId));
    return AsyncValueBuilder<Group?>(
      value: groupAsync,
      // Keep tab PageView / segment state across refresh/sync reloads.
      skipLoadingOnReload: true,
      data: (context, group) {
        if (group == null) {
          if (!_nullRetryDone) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _nullRetryDone) return;
              setState(() => _nullRetryDone = true);
              Future.delayed(const Duration(milliseconds: 300), () {
                if (!mounted) return;
                ref.invalidate(futureGroupProvider(widget.groupId));
              });
            });
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return const MissingRoutePage(
            titleKey: 'group_not_found',
            messageKey: 'group_not_found_message',
          );
        }
        return _GroupDetailContent(
          group: group,
          readOnlyPreview: widget.readOnlyPreview,
          previewToken: widget.previewToken,
          previewAccessMode: widget.previewAccessMode,
          initialTab: widget.initialTab,
        );
      },
      loading: (context) =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

class _GroupDetailContent extends ConsumerStatefulWidget {
  final Group group;
  final bool readOnlyPreview;
  final String? previewToken;
  final InviteAccessMode? previewAccessMode;
  final GroupDetailTab initialTab;

  const _GroupDetailContent({
    required this.group,
    required this.readOnlyPreview,
    required this.previewToken,
    required this.previewAccessMode,
    required this.initialTab,
  });

  @override
  ConsumerState<_GroupDetailContent> createState() =>
      _GroupDetailContentState();
}

class _GroupDetailContentState extends ConsumerState<_GroupDetailContent> {
  int _selectedTabIndex = 0;
  /// Stable seed for [CustomSlidingSegmentedControl.initialValue]. The package
  /// ignores [CustomSegmentedController]'s constructor value and defaults the
  /// thumb to the first segment unless [initialValue] is set; keep this fixed
  /// after init so later tab changes do not re-trigger [didUpdateWidget] resets.
  late final int _initialTabIndex;
  late ValueNotifier<int> _tabIndexNotifier;
  late PageController _pageController;
  late CustomSegmentedController<int> _segmentController;

  /// When non-null, we're animating to this page from a segment tap; ignore
  /// intermediate [onPageChanged] until we reach this index.
  int? _programmaticTargetPage;

  int _tabIndexFromInitialTab() {
    // Decorative hash updates can leave GoRouter on the originally matched
    // tab while the address bar shows another. Prefer the browser path on web
    // so remounts stay aligned with the location.
    final fromBrowser = _tabIndexFromBrowserPath();
    if (fromBrowser != null) return fromBrowser;
    switch (widget.initialTab) {
      case GroupDetailTab.expenses:
        return 0;
      case GroupDetailTab.balance:
        return 1;
      case GroupDetailTab.people:
        return 2;
    }
  }

  int? _tabIndexFromBrowserPath() {
    final path = webVisibleAppRoutePath();
    if (path == null) return null;
    return groupDetailTabIndexFromPath(
      path: path,
      groupId: widget.group.id,
      readOnlyPreview: widget.readOnlyPreview,
      previewToken: widget.previewToken,
    );
  }

  String _targetPathForTabIndex(int index) {
    if (widget.readOnlyPreview) {
      final token = widget.previewToken ?? '';
      if (token.isEmpty) return RoutePaths.home;
      switch (index) {
        case 1:
          return RoutePaths.invitePreviewBalance(token);
        case 2:
          return RoutePaths.invitePreviewPeople(token);
        case 0:
        default:
          return RoutePaths.invitePreviewExpenses(token);
      }
    }
    switch (index) {
      case 1:
        return RoutePaths.groupBalance(widget.group.id);
      case 2:
        return RoutePaths.groupPeople(widget.group.id);
      case 0:
      default:
        return RoutePaths.groupExpenses(widget.group.id);
    }
  }

  /// Update the browser URL bar to reflect the active tab without triggering
  /// a GoRouter navigation (which would destroy and recreate this widget,
  /// killing any in-progress PageView animation).
  void _syncUrlToTab(int index) {
    syncDecorativeRoutePath(context, _targetPathForTabIndex(index));
  }

  @override
  void initState() {
    super.initState();
    _initialTabIndex = _tabIndexFromInitialTab();
    _selectedTabIndex = _initialTabIndex;
    _tabIndexNotifier = ValueNotifier<int>(_selectedTabIndex);
    _pageController = PageController(initialPage: _selectedTabIndex);
    _segmentController = CustomSegmentedController<int>(value: _selectedTabIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      seedParentHistoryForBrowserBack(
        context: context,
        parentPath: RoutePaths.home,
        currentPath: _targetPathForTabIndex(_selectedTabIndex),
      );
    });
  }

  void _navigateBack() {
    // Preview Join may have set pending invite; clear on dismiss so
    // home is not redirected straight back to /invite.
    if (widget.readOnlyPreview) {
      clearInviteFlowState(ref);
    }
    popOrGo(context, RoutePaths.home);
  }

  @override
  void dispose() {
    _tabIndexNotifier.dispose();
    _pageController.dispose();
    _segmentController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    if (widget.readOnlyPreview) return;
    final localOnly = ref.read(effectiveLocalOnlyProvider);
    if (!localOnly) {
      Log.info('Group detail refresh: syncing group ${widget.group.id}');
      await ref.read(dataSyncServiceProvider.notifier).syncNow();
      Log.info('Group detail refresh: sync complete, invalidating providers');
    } else {
      Log.debug(
        'Group detail refresh: local-only, invalidating providers only',
      );
    }
    ref.invalidate(futureGroupProvider(widget.group.id));
    ref.invalidate(expensesByGroupProvider(widget.group.id));
    ref.invalidate(participantsByGroupProvider(widget.group.id));
    ref.invalidate(tagsByGroupProvider(widget.group.id));
    ref.invalidate(membersByGroupProvider(widget.group.id));
    ref.invalidate(myRoleInGroupProvider(widget.group.id));
  }

  Widget _buildAppBarTitle(BuildContext context) {
    final theme = Theme.of(context);
    final fullName = widget.group.name;
    final groupColor = widget.group.color != null
        ? Color(widget.group.color!)
        : theme.colorScheme.surfaceContainerHighest;
    final iconData = groupIconFromKey(widget.group.icon);
    final hasCustomColor = widget.group.color != null;

    final avatarFg = hasCustomColor
        ? ThemeConfig.foregroundOnBackground(groupColor)
        : theme.colorScheme.onSurface;
    final letter = fullName.trim().isNotEmpty
        ? fullName.trim().characters.first.toUpperCase()
        : '?';
    // Fill the start-aligned title slot so the name can use space up to the
    // actions before ellipsis (LTR start=left, RTL start=right).
    final titleRow = Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: groupColor,
          child: iconData != null
              ? Icon(iconData, size: 20, color: avatarFg)
              : Text(
                  letter,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: avatarFg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: UserText(
            fullName,
            key: const Key('group_detail_title'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            semanticsLabel: fullName,
          ),
        ),
      ],
    );
    return Semantics(
      label: fullName,
      child: Tooltip(message: fullName, child: titleRow),
    );
  }

  Widget _buildArchivedBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.archive_outlined,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                (widget.group.isPersonal ? 'list_archived' : 'group_archived')
                    .tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFAB(
    BuildContext context,
    int index,
    GroupRole? myRole,
    bool localOnly,
  ) {
    if (widget.readOnlyPreview) return null;
    final isOwnerOrAdmin =
        localOnly || myRole == GroupRole.owner || myRole == GroupRole.admin;
    final canAddExpense = isOwnerOrAdmin || widget.group.allowMemberAddExpense;

    if (index == 0) {
      if (widget.group.isArchived || widget.group.isSettlementFrozen || !canAddExpense) {
        return null;
      }
      return AppFab(
        icon: Icons.add,
        label: 'add_expense'.tr(),
        tooltip: 'add_expense'.tr(),
        onPressed: () =>
            context.push(RoutePaths.groupExpenseAdd(widget.group.id)),
      );
    }
    if (index == 2) {
      if (widget.group.isPersonal || !isOwnerOrAdmin) return null;
      return AppFab(
        icon: Icons.person_add,
        label: 'add_participant'.tr(),
        tooltip: 'add_participant'.tr(),
        onPressed: () => _showAddParticipant(
          context,
          ref,
          widget.group.id,
          ref
                  .read(participantsByGroupProvider(widget.group.id))
                  .value
                  ?.length ??
              0,
        ),
      );
    }
    return null;
  }

  Widget? _buildPreviewJoinBar(BuildContext context) {
    if (!widget.readOnlyPreview) return null;
    if (widget.previewAccessMode != InviteAccessMode.readonlyJoin) return null;
    final token = widget.previewToken;
    if (token == null || token.isEmpty) return null;
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'invite_preview_readonly_join_message'.tr(),
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () {
                    final settings = ref.read(hisabSettingsProvidersProvider);
                    if (settings != null) {
                      ref
                          .read(
                            settings
                                .provider(pendingInviteTokenSettingDef)
                                .notifier,
                          )
                          .set(token);
                      ref
                          .read(
                            settings
                                .provider(pendingInviteAutoJoinSettingDef)
                                .notifier,
                          )
                          .set(true);
                    }
                    context.push(RoutePaths.inviteAccept(token));
                  },
                  child: Text('invite_preview_join_cta'.tr()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localOnly = ref.watch(effectiveLocalOnlyProvider);
    final myRoleAsync = localOnly
        ? const AsyncValue.data(null)
        : ref.watch(myRoleInGroupProvider(widget.group.id));
    final myRole = myRoleAsync.value;

    final canPop = routerCanPop(context);
    return MembershipCelebrationBinder(
      groupId: widget.group.id,
      child: PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _navigateBack();
      },
      child: LayoutBuilder(
      builder: (context, layoutConstraints) {
        return Scaffold(
          floatingActionButtonLocation: ContentAlignedFabLocation.of(
            context,
            contentAreaWidth: layoutConstraints.maxWidth,
          ),
          appBar: ContentAlignedAppBar(
            contentAreaWidth: layoutConstraints.maxWidth,
            centerTitle: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _navigateBack,
            ),
            title: _buildAppBarTitle(context),
            actions: [
              if (!widget.readOnlyPreview)
                IconButton(
                  icon: const Icon(Icons.analytics_outlined),
                  tooltip: 'analytics'.tr(),
                  onPressed: () =>
                      context.push(RoutePaths.groupAnalytics(widget.group.id)),
                ),
              if (!localOnly &&
                  !widget.readOnlyPreview &&
                  (myRole == GroupRole.owner || myRole == GroupRole.admin) &&
                  !widget.group.isPersonal)
                IconButton(
                  icon: const Icon(Icons.person_add),
                  tooltip: 'invite_people'.tr(),
                  onPressed: () =>
                      showCreateInviteSheet(context, ref, widget.group.id),
                ),
              if (!widget.readOnlyPreview)
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () =>
                      context.push(RoutePaths.groupSettings(widget.group.id)),
                ),
            ],
          ),
          body: ConstrainedContent(
            child: Column(
              children: [
                if (widget.group.isArchived) _buildArchivedBanner(context),
                if (widget.group.isPersonal) ...[
                  _PersonalBudgetHeader(group: widget.group),
                  Expanded(
                    child: _ExpensesTab(
                      groupId: widget.group.id,
                      group: widget.group,
                      onRefresh: _onRefresh,
                      readOnlyPreview: widget.readOnlyPreview,
                      previewToken: widget.previewToken,
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        splashFactory: NoSplash.splashFactory,
                        highlightColor: Colors.transparent,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Builder(
                          builder: (context) {
                            final theme = Theme.of(context);
                            final colorScheme = theme.colorScheme;
                            return CustomSlidingSegmentedControl<int>(
                              controller: _segmentController,
                              initialValue: _initialTabIndex,
                              children: {
                                0: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    'expenses'.tr(),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: _selectedTabIndex == 0
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                1: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    'balance'.tr(),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: _selectedTabIndex == 1
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                2: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    'people'.tr(),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: _selectedTabIndex == 2
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              },
                              height: 52,
                              padding: 16,
                              innerPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              thumbDecoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: UiPerf.preferCheapShadows
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: colorScheme.shadow.withValues(
                                            alpha: 0.1,
                                          ),
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                              ),
                              isStretch: true,
                              duration: UiPerf.preferInstantShellTabs
                                  ? Duration.zero
                                  : const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              onValueChanged: (v) {
                                _syncUrlToTab(v);
                                setState(() {
                                  _selectedTabIndex = v;
                                  _programmaticTargetPage = v;
                                });
                                _tabIndexNotifier.value = v;
                                final pageDuration =
                                    UiPerf.preferInstantShellTabs
                                    ? Duration.zero
                                    : const Duration(milliseconds: 300);
                                if (pageDuration == Duration.zero) {
                                  _pageController.jumpToPage(v);
                                  if (mounted) {
                                    setState(
                                      () => _programmaticTargetPage = null,
                                    );
                                  }
                                } else {
                                  _pageController
                                      .animateToPage(
                                        v,
                                        duration: pageDuration,
                                        curve: Curves.easeInOut,
                                      )
                                      .whenComplete(() {
                                        if (mounted) {
                                          setState(
                                            () =>
                                                _programmaticTargetPage = null,
                                          );
                                        }
                                      });
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: 3,
                      onPageChanged: (i) {
                        if (_programmaticTargetPage != null &&
                            i != _programmaticTargetPage) {
                          return;
                        }
                        if (_programmaticTargetPage != null) {
                          setState(() => _programmaticTargetPage = null);
                        }
                        setState(() => _selectedTabIndex = i);
                        _tabIndexNotifier.value = i;
                        _segmentController.value = i;
                        _syncUrlToTab(i);
                      },
                      itemBuilder: (context, i) {
                        // Lazy: only visited pages mount; keepAlive preserves scroll.
                        return _KeepAliveTab(
                          child: switch (i) {
                            0 => _ExpensesTab(
                              groupId: widget.group.id,
                              group: widget.group,
                              onRefresh: _onRefresh,
                              readOnlyPreview: widget.readOnlyPreview,
                              previewToken: widget.previewToken,
                            ),
                            1 => _BalanceTab(
                              groupId: widget.group.id,
                              onRefresh: _onRefresh,
                              readOnlyPreview: widget.readOnlyPreview,
                            ),
                            _ => _PeopleTab(
                              groupId: widget.group.id,
                              group: widget.group,
                              onRefresh: _onRefresh,
                              readOnlyPreview: widget.readOnlyPreview,
                            ),
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          floatingActionButton: ValueListenableBuilder<int>(
            valueListenable: _tabIndexNotifier,
            builder: (context, index, _) =>
                _buildFAB(
                  context,
                  widget.group.isPersonal ? 0 : index,
                  myRole,
                  localOnly,
                ) ??
                const SizedBox.shrink(),
          ),
          bottomNavigationBar: _buildPreviewJoinBar(context),
        );
      },
    ),
    ),
    );
  }
}

/// Budget summary for personal groups: My budget + total spent; theme-aware color when near/over budget.
class _PersonalBudgetHeader extends ConsumerWidget {
  const _PersonalBudgetHeader({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesByGroupProvider(group.id));

    return expensesAsync.when(
      data: (expenses) {
        final totalSpentCents = expenses.fold<int>(
          0,
          (s, e) => s + contributionToExpenseTotal(e),
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: PersonalBudgetCard(
            group: group,
            spentCents: totalSpentCents,
            budgetCents: group.budgetAmountCents,
            showTitle: false,
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          height: 56,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _ExpensesTab extends ConsumerWidget {
  final String groupId;
  final Group group;
  final Future<void> Function() onRefresh;
  final bool readOnlyPreview;
  final String? previewToken;

  const _ExpensesTab({
    required this.groupId,
    required this.group,
    required this.onRefresh,
    required this.readOnlyPreview,
    required this.previewToken,
  });

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static Widget _buildError(WidgetRef ref, String groupId, Object error) {
    sendErrorTelemetryIfOnline(
      ref,
      message: error.toString(),
      details: error.toString(),
    );
    return Center(
      child: ErrorContentWidget(
        message: error.toString(),
        details: error.toString(),
        onRetry: () {
          ref.invalidate(expensesByGroupProvider(groupId));
          ref.invalidate(participantsByGroupProvider(groupId));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesByGroupProvider(groupId));
    final participantsAsync = ref.watch(participantsByGroupProvider(groupId));
    final myMemberAsync = ref.watch(myMemberInGroupProvider(groupId));
    final tagsAsync = ref.watch(tagsByGroupProvider(groupId));
    final customTags = tagsAsync.value ?? [];

    return participantsAsync.when(
      data: (participants) {
        final nameOf = {for (final p in participants) p.id: p.name};
        final currentUserParticipantId =
            myMemberAsync is AsyncData<GroupMember?>
            ? myMemberAsync.value?.participantId
            : null;

        return expensesAsync.when(
          data: (expenses) {
            if (expenses.isEmpty) {
              final theme = Theme.of(context);
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom:
                        _kTabFabBottomClearance +
                        _kTabListBottomSpacing +
                        MediaQuery.of(context).padding.bottom,
                  ),
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.55),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.receipt_long_rounded,
                                size: 34,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'add_expense'.tr(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final sorted = List<Expense>.from(expenses)
              ..sort((a, b) => b.date.compareTo(a.date));
            final byDate = <DateTime, List<Expense>>{};
            int myShareCents = 0;
            int youPaidCents = 0;
            int totalCents = 0;
            for (final e in sorted) {
              final key = _dateOnly(e.date.isUtc ? e.date.toLocal() : e.date);
              byDate.putIfAbsent(key, () => []).add(e);
              totalCents += contributionToExpenseTotal(e);
              if (currentUserParticipantId != null) {
                myShareCents += participantShareContributionCents(
                  e,
                  currentUserParticipantId,
                );
                if (e.payerParticipantId == currentUserParticipantId) {
                  youPaidCents += contributionToExpenseTotal(e);
                }
              }
            }
            final dateKeys = byDate.keys.toList()
              ..sort((a, b) => b.compareTo(a));

            final currencyCode = group.currencyCode;
            final dateFormat = DateFormat('MMMM d, yyyy');
            final theme = Theme.of(context);

            // Flatten for ListView.builder: [summary] + for each date [header, ...expenses]
            // Personal: skip summary in list (budget header above already shows total).
            final flattenedItems = <_ExpenseListItem>[
              if (!group.isPersonal)
                _ExpenseListSummaryItem(
                  myShareCents: myShareCents,
                  youPaidCents: youPaidCents,
                  totalCents: totalCents,
                ),
            ];
            for (final dateKey in dateKeys) {
              flattenedItems.add(_ExpenseListDateHeaderItem(dateKey));
              for (final e in byDate[dateKey]!) {
                flattenedItems.add(_ExpenseListExpenseItem(e));
              }
            }

            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView.builder(
                key: const PageStorageKey<String>('group_detail_expenses'),
                padding: EdgeInsets.only(
                  bottom:
                      _kTabFabBottomClearance +
                      _kTabListBottomSpacing +
                      MediaQuery.of(context).padding.bottom,
                ),
                itemCount: flattenedItems.length,
                itemBuilder: (context, index) {
                  final item = flattenedItems[index];
                  switch (item) {
                    case _ExpenseListSummaryItem():
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: group.isPersonal
                            ? _ExpenseSummaryCard(
                                label: 'my_expenses'.tr(),
                                value:
                                    '${CurrencyFormatter.formatCompactCents(item.totalCents)} $currencyCode',
                                theme: theme,
                                valueWidget: AmountWithSecondaryDisplay(
                                  amountCents: item.totalCents,
                                  groupCurrencyCode: currencyCode,
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _ExpenseSummaryCard(
                                          label: 'your_share'.tr(),
                                          value:
                                              '${CurrencyFormatter.formatCompactCents(item.myShareCents)} $currencyCode',
                                          theme: theme,
                                          valueWidget:
                                              AmountWithSecondaryDisplay(
                                            amountCents: item.myShareCents,
                                            groupCurrencyCode: currencyCode,
                                            showSecondary: false,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _ExpenseSummaryCard(
                                          label: 'you_paid'.tr(),
                                          value:
                                              '${CurrencyFormatter.formatCompactCents(item.youPaidCents)} $currencyCode',
                                          theme: theme,
                                          valueWidget:
                                              AmountWithSecondaryDisplay(
                                            amountCents: item.youPaidCents,
                                            groupCurrencyCode: currencyCode,
                                            showSecondary: false,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _ExpenseSummaryCard(
                                    label: 'total_expenses'.tr(),
                                    value:
                                        '${CurrencyFormatter.formatCompactCents(item.totalCents)} $currencyCode',
                                    theme: theme,
                                    valueWidget: AmountWithSecondaryDisplay(
                                      amountCents: item.totalCents,
                                      groupCurrencyCode: currencyCode,
                                      showSecondary: false,
                                    ),
                                  ),
                                ],
                              ),
                      );
                    case _ExpenseListDateHeaderItem():
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                        child: GroupSectionHeader(
                          label: dateFormat.format(item.date),
                        ),
                      );
                    case _ExpenseListExpenseItem():
                      final expense = item.expense;
                      return ExpenseListTile(
                        key: ValueKey(expense.id),
                        expense: expense,
                        payerName:
                            nameOf[expense.payerParticipantId] ??
                            expense.payerParticipantId,
                        toParticipantName: expense.toParticipantId == null
                            ? null
                            : nameOf[expense.toParticipantId!],
                        icon: iconForExpenseTag(expense.tag, customTags),
                        showPaidBy: !group.isPersonal,
                        groupCurrencyCode: group.currencyCode,
                        showDisclosure: true,
                        onTap: () {
                          if (readOnlyPreview && previewToken != null) {
                            context.push(
                              RoutePaths.invitePreviewExpenseDetail(
                                previewToken!,
                                expense.id,
                              ),
                            );
                            return;
                          }
                          context.push(
                            RoutePaths.groupExpenseDetail(groupId, expense.id),
                          );
                        },
                      );
                  }
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => _ExpensesTab._buildError(ref, groupId, e),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => _ExpensesTab._buildError(ref, groupId, e),
    );
  }
}

class _BalanceTab extends ConsumerWidget {
  final String groupId;
  final Future<void> Function() onRefresh;
  final bool readOnlyPreview;

  const _BalanceTab({
    required this.groupId,
    required this.onRefresh,
    required this.readOnlyPreview,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BalanceList(
      groupId: groupId,
      onRefresh: onRefresh,
      readOnlyMode: readOnlyPreview,
    );
  }
}

class _PeopleTab extends ConsumerWidget {
  final String groupId;
  final Group group;
  final Future<void> Function() onRefresh;
  final bool readOnlyPreview;

  const _PeopleTab({
    required this.groupId,
    required this.group,
    required this.onRefresh,
    required this.readOnlyPreview,
  });

  String _roleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'group_owner'.tr();
      case 'admin':
        return 'group_admin'.tr();
      default:
        return 'group_member'.tr();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localOnly = ref.watch(effectiveLocalOnlyProvider);
    final participantsAsync = ref.watch(participantsByGroupProvider(groupId));
    final membersAsync = localOnly
        ? const AsyncValue<List<GroupMember>>.data([])
        : ref.watch(membersByGroupProvider(groupId));
    final myRoleAsync = localOnly
        ? const AsyncValue.data(null)
        : ref.watch(myRoleInGroupProvider(groupId));
    return participantsAsync.when(
      data: (participants) {
        return membersAsync.when(
          data: (members) {
            final theme = Theme.of(context);
            final myRole = myRoleAsync.value;
            final isOwnerOrAdmin =
                !readOnlyPreview &&
                (localOnly ||
                    myRole == GroupRole.owner ||
                    myRole == GroupRole.admin);

            // Build lookup: participantId -> GroupMember
            final memberByParticipantId = <String, GroupMember>{};
            for (final m in members) {
              if (m.participantId != null) {
                memberByParticipantId[m.participantId!] = m;
              }
            }

            final activeParticipants = participants
                .where((p) => p.leftAt == null)
                .toList();
            // Past members: only show participants who had a user account (left/kicked).
            // Manually added participants that were removed stay in expenses but are hidden from this tab.
            final pastParticipants = participants
                .where((p) => p.leftAt != null && p.userId != null)
                .toList();

            if (activeParticipants.isEmpty && pastParticipants.isEmpty) {
              return RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom:
                        _kTabFabBottomClearance +
                        _kTabListBottomSpacing +
                        MediaQuery.of(context).padding.bottom,
                  ),
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.18),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.55),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.group_add_rounded,
                                size: 34,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'add_participants_first'.tr(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                key: const PageStorageKey<String>('group_detail_members'),
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  8 +
                      _kTabFabBottomClearance +
                      _kTabListBottomSpacing +
                      MediaQuery.of(context).padding.bottom,
                ),
                children: [
                  ...activeParticipants.map((p) {
                    final linkedMember = memberByParticipantId[p.id];
                    final hasUserId = p.userId != null;
                    final isActive = linkedMember != null;
                    final isLeft = hasUserId && !isActive;
                    final roleLabel = isActive
                        ? _roleLabel(linkedMember.role)
                        : isLeft
                        ? 'left'.tr()
                        : null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PeoplePersonCard(
                        key: ValueKey(p.id),
                        name: p.name,
                        avatarId: p.avatarId,
                        subtitle: roleLabel,
                        muted: isLeft,
                        trailing: _buildTrailing(
                          context,
                          ref,
                          groupId,
                          p,
                          linkedMember,
                          isActive,
                          isLeft,
                          isOwnerOrAdmin,
                          myRole,
                          localOnly,
                          members,
                          participants,
                        ),
                      ),
                    );
                  }),
                  if (pastParticipants.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GroupSectionHeader(label: 'past_members'.tr()),
                    const SizedBox(height: 10),
                    ...pastParticipants.map((p) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PeoplePersonCard(
                          key: ValueKey('past_${p.id}'),
                          name: p.name,
                          avatarId: p.avatarId,
                          subtitle: 'left'.tr(),
                          muted: true,
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) {
            sendErrorTelemetryIfOnline(
              ref,
              message: e.toString(),
              details: e.toString(),
            );
            return Center(
              child: ErrorContentWidget(
                message: e.toString(),
                details: e.toString(),
                stackTrace: st,
                onRetry: () =>
                    ref.invalidate(participantsByGroupProvider(groupId)),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) {
        sendErrorTelemetryIfOnline(
          ref,
          message: e.toString(),
          details: e.toString(),
        );
        return Center(
          child: ErrorContentWidget(
            message: e.toString(),
            details: e.toString(),
            stackTrace: st,
            onRetry: () => ref.invalidate(participantsByGroupProvider(groupId)),
          ),
        );
      },
    );
  }

  Widget? _buildTrailing(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    Participant participant,
    GroupMember? linkedMember,
    bool isActive,
    bool isLeft,
    bool isOwnerOrAdmin,
    GroupRole? myRole,
    bool localOnly,
    List<GroupMember> members,
    List<Participant> participants,
  ) {
    // Active member with member-management actions
    if (isActive && isOwnerOrAdmin && linkedMember!.role != 'owner') {
      return IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => _showActiveParticipantActions(
          context,
          ref,
          participant,
          linkedMember,
          myRole,
        ),
      );
    }

    // Left participant (had userId, no current member) — allow archive to remove from list
    if (isLeft && isOwnerOrAdmin) {
      return IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () =>
            _showLeftParticipantActions(context, ref, groupId, participant),
      );
    }

    // Standalone participant (no userId) or local-only mode — allow edit/delete/merge
    if (!isActive && !isLeft && isOwnerOrAdmin) {
      return IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => _showStandaloneParticipantActions(
          context,
          ref,
          groupId,
          participant,
          localOnly,
          members,
          participants,
        ),
      );
    }

    return null;
  }

  Future<void> _showActiveParticipantActions(
    BuildContext context,
    WidgetRef ref,
    Participant participant,
    GroupMember linkedMember,
    GroupRole? myRole,
  ) async {
    final action = await showResponsiveSheet<String>(
      context: context,
      title: participant.name,
      isScrollControlled: true,
      centerInFullViewport: true,
      child: Builder(
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).padding.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!LayoutBreakpoints.isTabletOrWider(context))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: UserText(
                      participant.name,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                SheetOptionList(
                  children: [
                    SheetOptionTile(
                      title: 'edit_name'.tr(),
                      leading: const Icon(Icons.edit_outlined),
                      onTap: () => Navigator.pop(ctx, 'edit'),
                    ),
                    if (myRole == GroupRole.owner) ...[
                      SheetOptionTile(
                        title: 'change_role'.tr(),
                        leading: const Icon(Icons.manage_accounts_outlined),
                        onTap: () => Navigator.pop(ctx, 'role'),
                      ),
                      SheetOptionTile(
                        title: 'transfer_ownership'.tr(),
                        leading: const Icon(Icons.swap_horiz),
                        onTap: () => Navigator.pop(ctx, 'transfer'),
                      ),
                    ],
                    SheetOptionTile(
                      title: 'kick_member'.tr(),
                      leading: Icon(
                        Icons.person_remove_outlined,
                        color: Theme.of(ctx).colorScheme.error,
                      ),
                      destructive: true,
                      onTap: () => Navigator.pop(ctx, 'kick'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'edit') {
      await _showEditParticipant(context, ref, participant);
      return;
    }
    await _onMemberAction(context, ref, action, linkedMember);
  }

  Future<void> _showLeftParticipantActions(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    Participant participant,
  ) async {
    final action = await showResponsiveSheet<String>(
      context: context,
      title: participant.name,
      isScrollControlled: true,
      centerInFullViewport: true,
      child: Builder(
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).padding.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!LayoutBreakpoints.isTabletOrWider(context))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: UserText(
                      participant.name,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                SheetOptionList(
                  children: [
                    SheetOptionTile(
                      title: 'archive_participant'.tr(),
                      leading: const Icon(Icons.archive_outlined),
                      onTap: () => Navigator.pop(ctx, 'archive'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (action != 'archive' || !context.mounted) return;
    await _showArchiveParticipant(context, ref, groupId, participant);
  }

  Future<void> _showStandaloneParticipantActions(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    Participant participant,
    bool localOnly,
    List<GroupMember> members,
    List<Participant> participants,
  ) async {
    final action = await showResponsiveSheet<String>(
      context: context,
      title: participant.name,
      isScrollControlled: true,
      centerInFullViewport: true,
      child: Builder(
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).padding.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!LayoutBreakpoints.isTabletOrWider(context))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: UserText(
                      participant.name,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                SheetOptionList(
                  children: [
                    SheetOptionTile(
                      title: 'edit_name'.tr(),
                      leading: const Icon(Icons.edit_outlined),
                      onTap: () => Navigator.pop(ctx, 'edit'),
                    ),
                    if (!localOnly)
                      SheetOptionTile(
                        title: 'merge_with_user'.tr(),
                        leading: const Icon(Icons.merge_type),
                        onTap: () => Navigator.pop(ctx, 'merge'),
                      ),
                    SheetOptionTile(
                      title: 'delete_participant'.tr(),
                      leading: Icon(
                        Icons.delete_outline,
                        color: Theme.of(ctx).colorScheme.error,
                      ),
                      destructive: true,
                      onTap: () => Navigator.pop(ctx, 'delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'edit') {
      await _showEditParticipant(context, ref, participant);
      return;
    }
    if (action == 'delete') {
      await _showDeleteParticipant(context, ref, groupId, participant);
      return;
    }
    if (action == 'merge') {
      await _showMergeWithUser(
        context,
        ref,
        groupId,
        participant,
        members,
        participants,
      );
    }
  }

  Future<void> _showArchiveParticipant(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    Participant participant,
  ) async {
    final ok = await showConfirmSheet(
      context,
      title: 'archive_participant'.tr(),
      content: 'archive_participant_confirm'.tr().replaceAll(
        '{name}',
        isolateBidi(participant.name),
      ),
      confirmLabel: 'archive_participant'.tr(),
      centerInFullViewport: true,
    );
    if (ok == true && context.mounted) {
      try {
        await ref
            .read(participantRepositoryProvider)
            .archive(groupId, participant.id);
        ref.invalidate(participantsByGroupProvider(groupId));
        if (!ref.read(effectiveLocalOnlyProvider)) {
          await ref.read(dataSyncServiceProvider.notifier).syncNow();
        }
        await fireCelebration(
          ref,
          CelebrationKind.personLeft,
          dedupeKey: CelebrationKeys.personLeft(groupId, participant.id),
        );
        if (context.mounted) {
          context.showSuccess('archive_participant'.tr());
        }
      } catch (e, st) {
        Log.warning('Archive participant failed', error: e, stackTrace: st);
        if (context.mounted) {
          context.showError('generic_error'.tr());
        }
      }
    }
  }

  Future<void> _showEditParticipant(
    BuildContext context,
    WidgetRef ref,
    Participant participant,
  ) async {
    final newName = await showTextInputSheet(
      context,
      title: 'participant_name'.tr(),
      hint: 'participant_name'.tr(),
      initialValue: participant.name,
      maxLength: FormValidators.participantNameMax,
      centerInFullViewport: true,
    );
    if (newName != null &&
        FormValidators.participantName(newName) == null &&
        context.mounted) {
      await ref
          .read(participantRepositoryProvider)
          .update(participant.copyWith(name: newName));
      ref.invalidate(participantsByGroupProvider(groupId));
    }
  }

  static bool _participantUsedInExpenses(
    String participantId,
    List<Expense> expenses,
  ) {
    for (final e in expenses) {
      if (e.payerParticipantId == participantId) return true;
      if (e.splitShares.containsKey(participantId)) return true;
      if (e.toParticipantId == participantId) return true;
    }
    return false;
  }

  Future<void> _showDeleteParticipant(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    Participant participant,
  ) async {
    final ok = await showConfirmSheet(
      context,
      title: 'delete_participant'.tr(),
      content: 'delete_participant_confirm'.tr().replaceAll(
        '{name}',
        isolateBidi(participant.name),
      ),
      confirmLabel: 'delete'.tr(),
      isDestructive: true,
      centerInFullViewport: true,
    );
    if (ok == true && context.mounted) {
      try {
        // Load expenses from DB so we know if this participant is used (archive vs delete).
        List<Expense> expenses;
        try {
          expenses = await ref
              .read(expenseRepositoryProvider)
              .getByGroupId(groupId);
          Log.info(
            'Remove participant: expenses loaded count=${expenses.length}',
          );
        } catch (e, st) {
          Log.warning(
            'Remove participant: failed to load expenses',
            error: e,
            stackTrace: st,
          );
          expenses = <Expense>[];
        }
        if (!context.mounted) return;
        Log.info(
          'Remove participant: groupId=$groupId participantId=${participant.id} name="${participant.name}" userId=${participant.userId} '
          'expensesCount=${expenses.length}',
        );
        for (final e in expenses) {
          final asPayer = e.payerParticipantId == participant.id;
          final inSplit = e.splitShares.containsKey(participant.id);
          final asTo = e.toParticipantId == participant.id;
          if (asPayer || inSplit || asTo) {
            Log.info(
              '  expense ${e.id}: payer=${e.payerParticipantId} toParticipantId=${e.toParticipantId} '
              'splitKeys=${e.splitShares.keys.toList()} -> asPayer=$asPayer inSplit=$inSplit asTo=$asTo',
            );
          }
        }
        final usedInExpenses = _participantUsedInExpenses(
          participant.id,
          expenses,
        );
        Log.info(
          'Remove participant: usedInExpenses=$usedInExpenses -> ${usedInExpenses ? "archive" : "delete"}',
        );
        if (usedInExpenses) {
          await ref
              .read(participantRepositoryProvider)
              .archive(groupId, participant.id);
          ref.invalidate(participantsByGroupProvider(groupId));
          if (!ref.read(effectiveLocalOnlyProvider)) {
            await ref.read(dataSyncServiceProvider.notifier).syncNow();
          }
          await fireCelebration(
            ref,
            CelebrationKind.personLeft,
            dedupeKey: CelebrationKeys.personLeft(groupId, participant.id),
          );
          if (context.mounted) {
            context.showSuccess('archive_participant'.tr());
          }
        } else {
          await ref.read(participantRepositoryProvider).delete(participant.id);
          ref.invalidate(participantsByGroupProvider(groupId));
          await fireCelebration(
            ref,
            CelebrationKind.personLeft,
            dedupeKey: CelebrationKeys.personLeft(groupId, participant.id),
          );
        }
      } catch (e, st) {
        Log.warning('Delete participant failed', error: e, stackTrace: st);
        if (context.mounted) {
          context.showError('generic_error'.tr());
        }
      }
    }
  }

  Future<void> _showMergeWithUser(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    Participant participant,
    List<GroupMember> members,
    List<Participant> participants,
  ) async {
    final theme = Theme.of(context);
    final chosen = await showResponsiveSheet<GroupMember>(
      context: context,
      title: 'merge_with_user'.tr(),
      isScrollControlled: true,
      centerInFullViewport: true,
      child: Builder(
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!LayoutBreakpoints.isTabletOrWider(context))
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'merge_with_user'.tr(),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: members.length,
                  itemBuilder: (ctx, i) {
                    final m = members[i];
                    Participant? linked;
                    if (m.participantId != null) {
                      try {
                        linked = participants.firstWhere(
                          (p) => p.id == m.participantId,
                        );
                      } catch (_) {
                        linked = null;
                      }
                    } else {
                      linked = null;
                    }
                    final label = linked?.name ?? 'group_member'.tr();
                    return ListTile(
                      leading: ParticipantAvatar(
                        name: label,
                        avatarId: linked?.avatarId,
                        radius: 18,
                      ),
                      title: linked != null
                          ? UserText(linked.name)
                          : Text(label),
                      subtitle: Text(_roleLabel(m.role)),
                      onTap: () => Navigator.pop(ctx, m),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;
    final confirmed = await showConfirmSheet(
      context,
      title: 'merge_with_user'.tr(),
      content: 'merge_with_user_confirm'.tr().replaceAll(
        '{name}',
        isolateBidi(participant.name),
      ),
      confirmLabel: 'merge_with_user'.tr(),
      centerInFullViewport: true,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref
          .read(groupMemberRepositoryProvider)
          .mergeParticipantWithMember(groupId, participant.id, chosen.id);
      ref.invalidate(participantsByGroupProvider(groupId));
      ref.invalidate(membersByGroupProvider(groupId));
      if (!ref.read(effectiveLocalOnlyProvider)) {
        await ref.read(dataSyncServiceProvider.notifier).syncNow();
      }
      if (context.mounted) {
        context.showSuccess('merge_with_user_success'.tr());
      }
    } catch (e, st) {
      Log.warning('Merge participant failed', error: e, stackTrace: st);
      if (context.mounted) context.showError('generic_error'.tr());
    }
  }

  Future<void> _onMemberAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    GroupMember member,
  ) async {
    switch (action) {
      case 'role':
        await _showChangeRole(context, ref, member);
        break;
      case 'transfer':
        await _showTransferOwnership(context, ref, member.id);
        break;
      case 'kick':
        await _showKickMember(context, ref, member);
        break;
    }
  }

  Future<void> _showChangeRole(
    BuildContext context,
    WidgetRef ref,
    GroupMember member,
  ) async {
    final role = await showResponsiveSheet<GroupRole>(
      context: context,
      title: 'change_role'.tr(),
      maxHeight: MediaQuery.of(context).size.height * 0.75,
      isScrollControlled: true,
      centerInFullViewport: true,
      child: Builder(
        builder: (ctx) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).padding.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!LayoutBreakpoints.isTabletOrWider(context))
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'change_role'.tr(),
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                    ),
                  ListTile(
                    title: Text('group_admin'.tr()),
                    onTap: () => Navigator.pop(ctx, GroupRole.admin),
                  ),
                  ListTile(
                    title: Text('group_member'.tr()),
                    onTap: () => Navigator.pop(ctx, GroupRole.member),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (role != null && context.mounted) {
      try {
        await ref
            .read(groupMemberRepositoryProvider)
            .updateRole(groupId, member.id, role);
        if (!ref.read(effectiveLocalOnlyProvider)) {
          await ref.read(dataSyncServiceProvider.notifier).syncNow();
        }
        ref.invalidate(membersByGroupProvider(groupId));
      } catch (e, st) {
        Log.warning('Change role failed', error: e, stackTrace: st);
        if (context.mounted) {
          context.showError('generic_error'.tr());
        }
      }
    }
  }

  Future<void> _showTransferOwnership(
    BuildContext context,
    WidgetRef ref,
    String memberId,
  ) async {
    try {
      await ref
          .read(groupMemberRepositoryProvider)
          .transferOwnership(groupId, memberId);
      if (!ref.read(effectiveLocalOnlyProvider)) {
        await ref.read(dataSyncServiceProvider.notifier).syncNow();
      }
      ref.invalidate(futureGroupProvider(groupId));
      ref.invalidate(membersByGroupProvider(groupId));
      ref.invalidate(myRoleInGroupProvider(groupId));
      if (context.mounted) {
        context.showSuccess('ownership_transferred'.tr());
      }
    } catch (e, st) {
      Log.warning('Transfer failed', error: e, stackTrace: st);
      if (context.mounted) {
        context.showError('generic_error'.tr());
      }
    }
  }

  Future<void> _showKickMember(
    BuildContext context,
    WidgetRef ref,
    GroupMember member,
  ) async {
    final ok = await showConfirmSheet(
      context,
      title: 'kick_member'.tr(),
      content: 'kick_member_confirm'.tr(),
      confirmLabel: 'kick_member'.tr(),
      centerInFullViewport: true,
    );
    if (ok == true && context.mounted) {
      try {
        await ref
            .read(groupMemberRepositoryProvider)
            .kickMember(groupId, member.id);
        // Sync so local DB gets updated (RPC only changes server); then invalidate so UI refreshes.
        if (!ref.read(effectiveLocalOnlyProvider)) {
          await ref.read(dataSyncServiceProvider.notifier).syncNow();
        }
        if (!context.mounted) return;
        ref.invalidate(membersByGroupProvider(groupId));
        ref.invalidate(participantsByGroupProvider(groupId));
        ref.invalidate(activeParticipantsByGroupProvider(groupId));
        final participantId = member.participantId;
        if (participantId != null) {
          await fireCelebration(
            ref,
            CelebrationKind.personLeft,
            dedupeKey: CelebrationKeys.personLeft(groupId, participantId),
          );
        }
        if (!context.mounted) return;
        context.showSuccess('kick_member'.tr());
      } catch (e, st) {
        Log.warning('Kick failed', error: e, stackTrace: st);
        if (context.mounted) {
          context.showError('generic_error'.tr());
        }
      }
    }
  }
}

/// Sealed-like item types for virtualized expense list.
sealed class _ExpenseListItem {
  const _ExpenseListItem();
}

/// Person row for the People tab — matches expense-detail person cards.
class _PeoplePersonCard extends StatelessWidget {
  final String name;
  final String? avatarId;
  final String? subtitle;
  final bool muted;
  final Widget? trailing;

  const _PeoplePersonCard({
    super.key,
    required this.name,
    this.avatarId,
    this.subtitle,
    this.muted = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedColor = colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: muted
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.55)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          ParticipantAvatar(
            name: name,
            avatarId: avatarId,
            backgroundColor: muted
                ? colorScheme.surfaceContainerHighest
                : colorScheme.secondaryContainer.withValues(alpha: 0.7),
            foregroundColor: muted
                ? mutedColor
                : colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserText(
                  name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: muted ? mutedColor : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.8,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w600,
                        fontStyle: muted ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _ExpenseListSummaryItem extends _ExpenseListItem {
  final int myShareCents;
  final int youPaidCents;
  final int totalCents;
  _ExpenseListSummaryItem({
    required this.myShareCents,
    required this.youPaidCents,
    required this.totalCents,
  }) : super();
}

class _ExpenseListDateHeaderItem extends _ExpenseListItem {
  final DateTime date;
  _ExpenseListDateHeaderItem(this.date) : super();
}

class _ExpenseListExpenseItem extends _ExpenseListItem {
  final Expense expense;
  _ExpenseListExpenseItem(this.expense) : super();
}

/// Summary card for my/total expenses in the expenses tab.
class _ExpenseSummaryCard extends StatelessWidget {
  const _ExpenseSummaryCard({
    required this.label,
    required this.value,
    required this.theme,
    this.valueWidget,
  });

  final String label;
  final String value;
  final ThemeData theme;

  /// When set, shown instead of [value] (e.g. [AmountWithSecondaryDisplay]).
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: AccentSurfaces.panel(
        colorScheme,
        subtle: context.subtleAccents,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: DefaultTextStyle.merge(
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.end,
              child: valueWidget ??
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showAddParticipant(
  BuildContext context,
  WidgetRef ref,
  String groupId,
  int currentCount,
) async {
  final name = await showTextInputSheet(
    context,
    title: 'add_participant'.tr(),
    hint: 'participant_name'.tr(),
    maxLength: FormValidators.participantNameMax,
    centerInFullViewport: true,
  );
  if (name != null &&
      FormValidators.participantName(name) == null &&
      context.mounted) {
    // Defer create to the next frame so the sheet overlay is fully disposed
    // before any provider/stream updates. Otherwise Flutter can hit
    // _dependents.isEmpty when the Directionality is deactivated while the
    // overlay still has dependents. Deferring keeps tests and production
    // consistent.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;
      try {
        await ref
            .read(participantRepositoryProvider)
            .create(groupId, name, currentCount);
      } catch (e, st) {
        Log.warning('Add participant failed', error: e, stackTrace: st);
        if (context.mounted) context.showError('generic_error'.tr());
      }
    });
  }
}
