import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/groups_provider.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/async_value_builder.dart';
import '../../expenses/widgets/expense_list_tile.dart';
import '../../balance/widgets/balance_list.dart';
import '../../../domain/domain.dart';

class GroupDetailPage extends ConsumerWidget {
  final String groupId;

  const GroupDetailPage({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(futureGroupProvider(groupId));
    return AsyncValueBuilder<Group?>(
      value: groupAsync,
      data: (context, group) {
        if (group == null) {
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

class _GroupDetailContentState extends ConsumerState<_GroupDetailContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabIndexChanged);
  }

  void _onTabIndexChanged() => setState(() {});

  @override
  void dispose() {
    _tabController.removeListener(_onTabIndexChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onRefresh() {
    ref.invalidate(futureGroupProvider(widget.group.id));
    ref.invalidate(expensesByGroupProvider(widget.group.id));
    ref.invalidate(participantsByGroupProvider(widget.group.id));
  }

  Widget _buildAppBarTitle(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          child: Text(
            widget.group.name.isNotEmpty
                ? widget.group.name[0].toUpperCase()
                : '?',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
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

  Widget _buildSegmentedTabs(BuildContext context) {
    final theme = Theme.of(context);
    final selectedIndex = _tabController.index;
    final labels = ['expenses'.tr(), 'balance'.tr(), 'participants'.tr()];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: List.generate(3, (i) {
            final selected = selectedIndex == i;
            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _tabController.animateTo(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: theme.colorScheme.shadow.withValues(
                                  alpha: 0.08,
                                ),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        labels[i],
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget? _buildFAB(BuildContext context) {
    final theme = Theme.of(context);
    final index = _tabController.index;
    if (index == 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Material(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
            elevation: 4,
            shadowColor: theme.colorScheme.shadow,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () =>
                  context.push(RoutePaths.groupExpenseAdd(widget.group.id)),
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'add_expense'.tr(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      );
    }
    if (index == 2) {
      final participantsAsync =
          ref.watch(participantsByGroupProvider(widget.group.id));
      final participantCount = participantsAsync.value?.length ?? 0;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Material(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
            elevation: 4,
            shadowColor: theme.colorScheme.shadow,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showAddParticipant(
                context,
                ref,
                widget.group.id,
                participantCount,
              ),
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(
                  Icons.person_add,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'add_participant'.tr(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _onRefresh,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSegmentedTabs(context),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ExpensesTab(groupId: widget.group.id, group: widget.group),
                _BalanceTab(groupId: widget.group.id),
                _ParticipantsTab(groupId: widget.group.id),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(context),
    );
  }
}

class _ExpensesTab extends ConsumerWidget {
  final String groupId;
  final Group group;

  const _ExpensesTab({required this.groupId, required this.group});

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesByGroupProvider(groupId));
    final participantsAsync = ref.watch(participantsByGroupProvider(groupId));

    return participantsAsync.when(
      data: (participants) {
        final nameOf = {for (final p in participants) p.id: p.name};
        final firstParticipantId =
            participants.isNotEmpty ? participants.first.id : null;

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
            for (final e in sorted) {
              final key = _dateOnly(e.date);
              byDate.putIfAbsent(key, () => []).add(e);
            }
            final dateKeys = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

            int myExpensesCents = 0;
            int totalCents = 0;
            for (final e in expenses) {
              totalCents += e.amountCents;
              if (firstParticipantId != null &&
                  e.payerParticipantId == firstParticipantId) {
                myExpensesCents += e.amountCents;
              }
            }

            final currencyCode = group.currencyCode;
            final dateFormat = DateFormat('MMMM d, yyyy');
            final theme = Theme.of(context);

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'my_expenses'.tr(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${CurrencyFormatter.formatCompactCents(myExpensesCents)} $currencyCode',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'total_expenses'.tr(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${CurrencyFormatter.formatCompactCents(totalCents)} $currencyCode',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...dateKeys.expand((dateKey) {
                  final list = byDate[dateKey]!;
                  return [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                      child: Text(
                        dateFormat.format(dateKey),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    ...list.map(
                      (expense) => InkWell(
                        onTap: () => context.push(
                          RoutePaths.groupExpenseDetail(groupId, expense.id),
                        ),
                        child: ExpenseListTile(
                          expense: expense,
                          payerName: nameOf[expense.payerParticipantId] ??
                              expense.payerParticipantId,
                        ),
                      ),
                    ),
                  ];
                }),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (e, st) => Center(
            child: Text(
              e.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(
        child: Text(
          e.toString(),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _BalanceTab extends ConsumerWidget {
  final String groupId;

  const _BalanceTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BalanceList(groupId: groupId);
  }
}

class _ParticipantsTab extends ConsumerWidget {
  final String groupId;

  const _ParticipantsTab({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantsAsync = ref.watch(participantsByGroupProvider(groupId));
    return AsyncValueBuilder<List<Participant>>(
      value: participantsAsync,
      data: (context, participants) {
        if (participants.isEmpty) {
          return Center(
            child: Text(
              'participants'.tr(),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          itemCount: participants.length,
          itemBuilder: (context, index) {
            final p = participants[index];
            return ListTile(
              title: Text(p.name),
              subtitle: Text('${'participants'.tr()} ${index + 1}'),
            );
          },
        );
      },
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
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('participants'.tr()),
      content: TextField(
        controller: nameController,
        decoration: InputDecoration(
          labelText: 'participants'.tr(),
          hintText: 'Name',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(nameController.text.trim()),
          child: const Text('Add'),
        ),
      ],
    ),
  );
  if (name != null && name.isNotEmpty && context.mounted) {
    await ref
        .read(participantRepositoryProvider)
        .create(groupId, name, currentCount);
  }
}
