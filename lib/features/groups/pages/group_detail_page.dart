import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import '../providers/groups_provider.dart';
import '../providers/group_member_provider.dart';
import '../widgets/create_invite_sheet.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/async_value_builder.dart';
import '../../../core/widgets/error_content.dart';
import '../../../core/widgets/toast.dart';
import '../../expenses/widgets/expense_list_tile.dart';
import '../../expenses/category_icons.dart';
import '../../balance/widgets/balance_list.dart';
import '../../settings/providers/settings_framework_providers.dart';
import '../../../core/auth/predefined_avatars.dart';
import '../../../domain/domain.dart';
import '../utils/group_icon_utils.dart';

class GroupDetailPage extends ConsumerStatefulWidget {
  final String groupId;

  const GroupDetailPage({super.key, required this.groupId});

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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(RoutePaths.home);
              }
            }
          });
          return const SizedBox.shrink();
        }
        return _GroupDetailContent(group: group);
      },
      loading: (context) =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

class _GroupDetailContent extends ConsumerStatefulWidget {
  final Group group;

  const _GroupDetailContent({required this.group});

  @override
  ConsumerState<_GroupDetailContent> createState() =>
      _GroupDetailContentState();
}

class _GroupDetailContentState extends ConsumerState<_GroupDetailContent> {
  int _selectedTabIndex = 0;
  late ValueNotifier<int> _tabIndexNotifier;
  late PageController _pageController;
  late CustomSegmentedController<int> _segmentController;
  /// When non-null, we're animating to this page from a segment tap; ignore
  /// intermediate [onPageChanged] until we reach this index.
  int? _programmaticTargetPage;

  @override
  void initState() {
    super.initState();
    _tabIndexNotifier = ValueNotifier<int>(0);
    _pageController = PageController(initialPage: 0);
    _segmentController = CustomSegmentedController<int>(value: 0);
  }

  @override
  void dispose() {
    _tabIndexNotifier.dispose();
    _pageController.dispose();
    _segmentController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    final localOnly = ref.read(effectiveLocalOnlyProvider);
    if (!localOnly) {
      Log.info('Group detail refresh: syncing group ${widget.group.id}');
      await ref.read(dataSyncServiceProvider.notifier).syncNow();
      Log.info('Group detail refresh: sync complete, invalidating providers');
    } else {
      Log.debug('Group detail refresh: local-only, invalidating providers only');
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
    final groupColor = widget.group.color != null
        ? Color(widget.group.color!)
        : theme.colorScheme.surfaceContainerHighest;
    final iconData = groupIconFromKey(widget.group.icon);
    final hasCustomColor = widget.group.color != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: groupColor,
          child: iconData != null
              ? Icon(iconData, size: 20, color: Colors.white)
              : Text(
                  widget.group.name.isNotEmpty
                      ? widget.group.name[0].toUpperCase()
                      : '?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: hasCustomColor
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            widget.group.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
                'group_archived'.tr(),
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
    final theme = Theme.of(context);
    final isOwnerOrAdmin =
        localOnly || myRole == GroupRole.owner || myRole == GroupRole.admin;
    final canAddExpense = isOwnerOrAdmin || widget.group.allowMemberAddExpense;

    if (index == 0) {
      if (widget.group.isSettlementFrozen || !canAddExpense) return null;
      return _FABWithLabel(
        icon: Icons.add,
        label: 'add_expense'.tr(),
        theme: theme,
        onTap: () => context.push(RoutePaths.groupExpenseAdd(widget.group.id)),
      );
    }
    if (index == 2) {
      if (!isOwnerOrAdmin) return null;
      return _FABWithLabel(
        icon: Icons.person_add,
        label: 'add_participant'.tr(),
        theme: theme,
        onTap: () => _showAddParticipant(
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

  @override
  Widget build(BuildContext context) {
    final localOnly = ref.watch(effectiveLocalOnlyProvider);
    final myRoleAsync = localOnly
        ? const AsyncValue.data(null)
        : ref.watch(myRoleInGroupProvider(widget.group.id));
    final myRole = myRoleAsync.value;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
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
        title: _buildAppBarTitle(context),
        actions: [
          if (!localOnly &&
              (myRole == GroupRole.owner || myRole == GroupRole.admin))
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: 'invite_people'.tr(),
              onPressed: () =>
                  showCreateInviteSheet(context, ref, widget.group.id),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () =>
                context.push(RoutePaths.groupSettings(widget.group.id)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.group.isArchived) _buildArchivedBanner(context),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      children: {
                        0: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
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
                          padding: const EdgeInsets.symmetric(vertical: 4),
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
                          padding: const EdgeInsets.symmetric(vertical: 4),
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
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.1),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      isStretch: true,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      onValueChanged: (v) {
                        setState(() {
                          _selectedTabIndex = v;
                          _programmaticTargetPage = v;
                        });
                        _tabIndexNotifier.value = v;
                        _pageController.animateToPage(
                          v,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ).whenComplete(() {
                          if (mounted) {
                            setState(() => _programmaticTargetPage = null);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) {
                if (_programmaticTargetPage != null && i != _programmaticTargetPage) {
                  return;
                }
                if (_programmaticTargetPage != null) {
                  setState(() => _programmaticTargetPage = null);
                }
                setState(() => _selectedTabIndex = i);
                _tabIndexNotifier.value = i;
                _segmentController.value = i;
              },
              children: [
                _ExpensesTab(
                  groupId: widget.group.id,
                  group: widget.group,
                  onRefresh: _onRefresh,
                ),
                _BalanceTab(
                  groupId: widget.group.id,
                  onRefresh: _onRefresh,
                ),
                _PeopleTab(
                  groupId: widget.group.id,
                  group: widget.group,
                  onRefresh: _onRefresh,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: ValueListenableBuilder<int>(
        valueListenable: _tabIndexNotifier,
        builder: (context, index, _) =>
            _buildFAB(context, index, myRole, localOnly) ??
            const SizedBox.shrink(),
      ),
    );
  }
}

class _ExpensesTab extends ConsumerWidget {
  final String groupId;
  final Group group;
  final Future<void> Function() onRefresh;

  const _ExpensesTab({
    required this.groupId,
    required this.group,
    required this.onRefresh,
  });

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

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
        final currentUserParticipantId = myMemberAsync is AsyncData<GroupMember?>
            ? myMemberAsync.value?.participantId
            : null;

        return expensesAsync.when(
          data: (expenses) {
            if (expenses.isEmpty) {
              return Center(
                child: Text(
                  'add_expense'.tr(),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              );
            }

            final sorted = List<Expense>.from(expenses)
              ..sort((a, b) => b.date.compareTo(a.date));
            final byDate = <DateTime, List<Expense>>{};
            int myExpensesCents = 0;
            int totalCents = 0;
            for (final e in sorted) {
              final key = _dateOnly(e.date.isUtc ? e.date.toLocal() : e.date);
              byDate.putIfAbsent(key, () => []).add(e);
              totalCents += e.effectiveBaseAmountCents;
              if (currentUserParticipantId != null &&
                  e.payerParticipantId == currentUserParticipantId) {
                myExpensesCents += e.effectiveBaseAmountCents;
              }
            }
            final dateKeys = byDate.keys.toList()
              ..sort((a, b) => b.compareTo(a));

            final currencyCode = group.currencyCode;
            final dateFormat = DateFormat('MMMM d, yyyy');
            final theme = Theme.of(context);

            // Flatten for ListView.builder: [summary] + for each date [header, ...expenses]
            final flattenedItems = <_ExpenseListItem>[
              _ExpenseListSummaryItem(
                myExpensesCents: myExpensesCents,
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
                padding: const EdgeInsets.only(bottom: 24),
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
                      child: Row(
                        children: [
                          Expanded(
                            child: _ExpenseSummaryCard(
                              label: 'my_expenses'.tr(),
                              value:
                                  '${CurrencyFormatter.formatCompactCents(item.myExpensesCents)} $currencyCode',
                              theme: theme,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ExpenseSummaryCard(
                              label: 'total_expenses'.tr(),
                              value:
                                  '${CurrencyFormatter.formatCompactCents(item.totalCents)} $currencyCode',
                              theme: theme,
                            ),
                          ),
                        ],
                      ),
                    );
                  case _ExpenseListDateHeaderItem():
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                      child: Text(
                        dateFormat.format(item.date),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  case _ExpenseListExpenseItem():
                    final expense = item.expense;
                    return InkWell(
                      key: ValueKey(expense.id),
                      onTap: () => context.push(
                        RoutePaths.groupExpenseDetail(groupId, expense.id),
                      ),
                      child: ExpenseListTile(
                        expense: expense,
                        payerName:
                            nameOf[expense.payerParticipantId] ??
                            expense.payerParticipantId,
                        icon: iconForExpenseTag(expense.tag, customTags),
                      ),
                    );
                }
              },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(
            child: ErrorContentWidget(
              message: e.toString(),
              onRetry: () {
                ref.invalidate(expensesByGroupProvider(groupId));
                ref.invalidate(participantsByGroupProvider(groupId));
              },
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: ErrorContentWidget(
          message: e.toString(),
          onRetry: () {
            ref.invalidate(expensesByGroupProvider(groupId));
            ref.invalidate(participantsByGroupProvider(groupId));
          },
        ),
      ),
    );
  }
}

class _BalanceTab extends ConsumerWidget {
  final String groupId;
  final Future<void> Function() onRefresh;

  const _BalanceTab({required this.groupId, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BalanceList(groupId: groupId, onRefresh: onRefresh);
  }
}

class _PeopleTab extends ConsumerWidget {
  final String groupId;
  final Group group;
  final Future<void> Function() onRefresh;

  const _PeopleTab({
    required this.groupId,
    required this.group,
    required this.onRefresh,
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
            final isOwnerOrAdmin = localOnly ||
                myRole == GroupRole.owner ||
                myRole == GroupRole.admin;

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
            final pastParticipants = participants
                .where((p) => p.leftAt != null)
                .toList();

            if (activeParticipants.isEmpty && pastParticipants.isEmpty) {
              return Center(
                child: Text(
                  'add_participants_first'.tr(),
                  style: theme.textTheme.bodyLarge,
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                children: [
                ...activeParticipants.map((p) {
                  final linkedMember = memberByParticipantId[p.id];
                  final hasUserId = p.userId != null;
                  final isActive = linkedMember != null;
                  final isLeft = hasUserId && !isActive;

                  final emoji = avatarEmoji(p.avatarId);

                  return ListTile(
                    key: ValueKey(p.id),
                    leading: CircleAvatar(
                      backgroundColor: isLeft
                          ? theme.colorScheme.surfaceContainerHighest
                          : null,
                      child: emoji != null
                          ? Text(
                              emoji,
                              style: TextStyle(
                                fontSize: 22,
                                color: isLeft
                                    ? theme.colorScheme.onSurfaceVariant
                                    : null,
                              ),
                            )
                          : Text(
                              p.name.isNotEmpty
                                  ? p.name[0].toUpperCase()
                                  : '?',
                              style: isLeft
                                  ? TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    )
                                  : null,
                            ),
                    ),
                    title: Text(
                      p.name,
                      style: isLeft
                          ? TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            )
                          : null,
                    ),
                    subtitle: isActive
                        ? Text(_roleLabel(linkedMember.role))
                        : isLeft
                            ? Text(
                                'left'.tr(),
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            : null,
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
                  );
                }),
                if (pastParticipants.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Text(
                      'past_members'.tr(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  ...pastParticipants.map((p) {
                    final emoji = avatarEmoji(p.avatarId);
                    return ListTile(
                      key: ValueKey('past_${p.id}'),
                      leading: CircleAvatar(
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        child: emoji != null
                            ? Text(
                                emoji,
                                style: TextStyle(
                                  fontSize: 22,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              )
                            : Text(
                                p.name.isNotEmpty
                                    ? p.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                      ),
                      title: Text(
                        p.name,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      subtitle: Text(
                        'left'.tr(),
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      trailing: null,
                    );
                  }),
                ],
              ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: ErrorContentWidget(
              message: e.toString(),
              onRetry: () => ref.invalidate(participantsByGroupProvider(groupId)),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: ErrorContentWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(participantsByGroupProvider(groupId)),
        ),
      ),
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
      return PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') {
            _showEditParticipant(context, ref, participant);
          } else if (v == 'delete') {
            _showDeleteParticipant(context, ref, participant);
          } else {
            _onMemberAction(context, ref, v, linkedMember);
          }
        },
        itemBuilder: (ctx) => [
          PopupMenuItem(
            value: 'edit',
            child: Text('edit_name'.tr()),
          ),
          if (myRole == GroupRole.owner) ...[
            PopupMenuItem(
              value: 'role',
              child: Text('change_role'.tr()),
            ),
            PopupMenuItem(
              value: 'transfer',
              child: Text('transfer_ownership'.tr()),
            ),
          ],
          PopupMenuItem(
            value: 'kick',
            child: Text('kick_member'.tr()),
          ),
        ],
      );
    }

    // Left participant (had userId, no current member) — allow archive to remove from list
    if (isLeft && isOwnerOrAdmin) {
      return PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'archive') {
            _showArchiveParticipant(context, ref, groupId, participant);
          }
        },
        itemBuilder: (ctx) => [
          PopupMenuItem(
            value: 'archive',
            child: Text('archive_participant'.tr()),
          ),
        ],
      );
    }

    // Standalone participant (no userId) or local-only mode — allow edit/delete/merge
    if (!isActive && !isLeft && isOwnerOrAdmin) {
      return PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') {
            _showEditParticipant(context, ref, participant);
          } else if (v == 'delete') {
            _showDeleteParticipant(context, ref, participant);
          } else if (v == 'merge') {
            _showMergeWithUser(
              context,
              ref,
              groupId,
              participant,
              members,
              participants,
            );
          }
        },
        itemBuilder: (ctx) => [
          PopupMenuItem(
            value: 'edit',
            child: Text('edit_name'.tr()),
          ),
          if (!localOnly)
            PopupMenuItem(
              value: 'merge',
              child: Text('merge_with_user'.tr()),
            ),
          PopupMenuItem(
            value: 'delete',
            child: Text('delete_participant'.tr()),
          ),
        ],
      );
    }

    return null;
  }

  Future<void> _showArchiveParticipant(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    Participant participant,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('archive_participant'.tr()),
        content: Text(
          'archive_participant_confirm'.tr().replaceAll('{name}', participant.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('archive_participant'.tr()),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      try {
        await ref.read(participantRepositoryProvider).archive(groupId, participant.id);
        ref.invalidate(participantsByGroupProvider(groupId));
        if (!ref.read(effectiveLocalOnlyProvider)) {
          await ref.read(dataSyncServiceProvider.notifier).syncNow();
        }
        if (context.mounted) {
          context.showSuccess('archive_participant'.tr());
        }
      } catch (e, st) {
        Log.warning('Archive participant failed', error: e, stackTrace: st);
        if (context.mounted) {
          context.showError('$e');
        }
      }
    }
  }

  Future<void> _showEditParticipant(
    BuildContext context,
    WidgetRef ref,
    Participant participant,
  ) async {
    final nameController = TextEditingController(text: participant.name);
    try {
      final newName = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('participant_name'.tr()),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'participant_name'.tr(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('cancel'.tr()),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(nameController.text.trim()),
              child: Text('done'.tr()),
            ),
          ],
        ),
      );
      if (newName != null && newName.isNotEmpty && context.mounted) {
        await ref
            .read(participantRepositoryProvider)
            .update(participant.copyWith(name: newName));
        ref.invalidate(participantsByGroupProvider(groupId));
      }
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameController.dispose();
      });
    }
  }

  Future<void> _showDeleteParticipant(
    BuildContext context,
    WidgetRef ref,
    Participant participant,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('delete_participant'.tr()),
        content: Text(
          'delete_participant_confirm'.tr().replaceAll('{name}', participant.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      try {
        await ref.read(participantRepositoryProvider).delete(participant.id);
        ref.invalidate(participantsByGroupProvider(groupId));
      } catch (e, st) {
        Log.warning('Delete participant failed', error: e, stackTrace: st);
        if (context.mounted) {
          context.showError('$e');
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
    final chosen = await showModalBottomSheet<GroupMember>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                    title: Text(label),
                    subtitle: Text(_roleLabel(m.role)),
                    onTap: () => Navigator.pop(ctx, m),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;
    try {
      await ref.read(groupMemberRepositoryProvider).mergeParticipantWithMember(
            groupId,
            participant.id,
            chosen.id,
          );
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
      if (context.mounted) context.showError('$e');
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
    final role = await showDialog<GroupRole>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('change_role'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
    );
    if (role != null && context.mounted) {
      try {
        await ref
            .read(groupMemberRepositoryProvider)
            .updateRole(groupId, member.id, role);
        ref.invalidate(membersByGroupProvider(groupId));
      } catch (e, st) {
        Log.warning('Change role failed', error: e, stackTrace: st);
        if (context.mounted) {
          context.showError('$e');
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
      ref.invalidate(futureGroupProvider(groupId));
      ref.invalidate(membersByGroupProvider(groupId));
      ref.invalidate(myRoleInGroupProvider(groupId));
      if (context.mounted) {
        context.showSuccess('ownership_transferred'.tr());
      }
    } catch (e, st) {
      Log.warning('Transfer failed', error: e, stackTrace: st);
      if (context.mounted) {
        context.showError('$e');
      }
    }
  }

  Future<void> _showKickMember(
    BuildContext context,
    WidgetRef ref,
    GroupMember member,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('kick_member'.tr()),
        content: Text('kick_member_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('kick_member'.tr()),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      try {
        await ref
            .read(groupMemberRepositoryProvider)
            .kickMember(groupId, member.id);
        ref.invalidate(membersByGroupProvider(groupId));
        ref.invalidate(participantsByGroupProvider(groupId));
      } catch (e, st) {
        Log.warning('Kick failed', error: e, stackTrace: st);
        if (context.mounted) {
          context.showError('$e');
        }
      }
    }
  }

}

/// Sealed-like item types for virtualized expense list.
sealed class _ExpenseListItem {
  const _ExpenseListItem();
}

class _ExpenseListSummaryItem extends _ExpenseListItem {
  final int myExpensesCents;
  final int totalCents;
  _ExpenseListSummaryItem({
    required this.myExpensesCents,
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
  });

  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// FAB with label below (add expense / add participant).
class _FABWithLabel extends StatelessWidget {
  const _FABWithLabel({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Semantics(
          label: label,
          button: true,
          child: Material(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            elevation: 4,
            shadowColor: theme.colorScheme.shadow,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: onTap,
              child: SizedBox(
                width: 56,
                height: 56,
                child: Icon(icon, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

Future<void> _showAddParticipant(
  BuildContext context,
  WidgetRef ref,
  String groupId,
  int currentCount,
) async {
  final nameController = TextEditingController();
  try {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('add_participant'.tr()),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'participants'.tr(),
            hintText: 'participant_name'.tr(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(nameController.text.trim()),
            child: Text('done'.tr()),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && context.mounted) {
      await ref
          .read(participantRepositoryProvider)
          .create(groupId, name, currentCount);
    }
  } finally {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
    });
  }
}
