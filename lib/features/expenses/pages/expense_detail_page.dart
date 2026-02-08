import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/receipt/receipt_image_view.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/domain.dart';
import '../../groups/providers/groups_provider.dart';

class ExpenseDetailPage extends ConsumerWidget {
  final String groupId;
  final String expenseId;

  const ExpenseDetailPage({
    super.key,
    required this.groupId,
    required this.expenseId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseAsync = ref.watch(futureExpenseProvider(expenseId));
    final participantsAsync = ref.watch(participantsByGroupProvider(groupId));
    final theme = Theme.of(context);

    return expenseAsync.when(
      data: (expense) {
        if (expense == null || expense.groupId != groupId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.pop();
          });
          return const SizedBox.shrink();
        }
        return participantsAsync.when(
          data: (participants) {
            final nameOf = {for (final p in participants) p.id: p.name};
            final expensesAsync = ref.watch(expensesByGroupProvider(groupId));
            return expensesAsync.when(
              data: (expenses) {
                final sorted = List<Expense>.from(expenses)
                  ..sort((a, b) => b.date.compareTo(a.date));
                final index = sorted.indexWhere((e) => e.id == expense.id);
                final hasPrev = index > 0;
                final hasNext = index >= 0 && index < sorted.length - 1;
                final prevId = hasPrev ? sorted[index - 1].id : null;
                final nextId = hasNext ? sorted[index + 1].id : null;
                return Scaffold(
                  appBar: AppBar(
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.pop(),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: hasPrev && prevId != null
                            ? () => context.go(
                                RoutePaths.groupExpenseDetail(groupId, prevId),
                              )
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: hasNext && nextId != null
                            ? () => context.go(
                                RoutePaths.groupExpenseDetail(groupId, nextId),
                              )
                            : null,
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) async {
                          if (value == 'edit') {
                            await context.push(
                              RoutePaths.groupExpenseEdit(groupId, expenseId),
                            );
                            if (context.mounted) {
                              // Defer invalidation to next frame to avoid scheduling on a disposing view (Flutter Web)
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (context.mounted) {
                                  ref.invalidate(
                                    futureExpenseProvider(expenseId),
                                  );
                                  ref.invalidate(
                                    expensesByGroupProvider(groupId),
                                  );
                                }
                              });
                            }
                          } else if (value == 'delete') {
                            _confirmDelete(context, ref, expense);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Delete',
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  body: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    children: [
                      _ExpenseHeader(expense: expense),
                      if (expense.receiptImagePath != null &&
                          expense.receiptImagePath!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'receipt'.tr(),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => showReceiptImageFullScreen(
                            context,
                            expense.receiptImagePath!,
                          ),
                          child: buildReceiptImageView(
                            expense.receiptImagePath,
                            maxHeight: 280,
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      _SectionLabel(label: _payerSectionLabel(expense)),
                      const SizedBox(height: 10),
                      _PersonCard(
                        name:
                            nameOf[expense.payerParticipantId] ??
                            expense.payerParticipantId,
                        amountCents: expense.amountCents,
                        currencyCode: expense.currencyCode,
                      ),
                      const SizedBox(height: 24),
                      _SectionLabel(
                        label:
                            expense.transactionType == TransactionType.transfer
                            ? 'to'.tr()
                            : 'participants'.tr(),
                      ),
                      const SizedBox(height: 10),
                      ..._participantShares(expense, participants, nameOf).map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PersonCard(
                            name: e.name,
                            amountCents: e.cents,
                            currencyCode: expense.currencyCode,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          },
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(child: Text('$e')),
      ),
    );
  }

  String _payerSectionLabel(Expense expense) {
    switch (expense.transactionType) {
      case TransactionType.transfer:
        return 'from'.tr();
      case TransactionType.expense:
      case TransactionType.income:
        return 'from'.tr();
    }
  }

  List<_ShareEntry> _participantShares(
    Expense expense,
    List<Participant> participants,
    Map<String, String> nameOf,
  ) {
    if (expense.transactionType == TransactionType.transfer) {
      final toId = expense.toParticipantId;
      if (toId == null) return [];
      return [
        _ShareEntry(name: nameOf[toId] ?? toId, cents: expense.amountCents),
      ];
    }
    final shares = expense.splitShares;
    if (shares.isEmpty) return [];
    return participants
        .where((p) => shares.containsKey(p.id) && (shares[p.id] ?? 0) > 0)
        .map(
          (p) => _ShareEntry(name: nameOf[p.id] ?? p.id, cents: shares[p.id]!),
        )
        .toList();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
          '${expense.title} – ${CurrencyFormatter.formatCents(expense.amountCents, expense.currencyCode)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(expenseRepositoryProvider).delete(expense.id);
      if (context.mounted) context.pop();
    }
  }
}

class _ShareEntry {
  final String name;
  final int cents;
  _ShareEntry({required this.name, required this.cents});
}

class _ExpenseHeader extends StatelessWidget {
  final Expense expense;

  const _ExpenseHeader({required this.expense});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _iconForType(expense.transactionType);
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');

    return Column(
      children: [
        Icon(icon, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          expense.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          dateFormat.format(expense.date),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  IconData _iconForType(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return Icons.credit_card;
      case TransactionType.income:
        return Icons.trending_up;
      case TransactionType.transfer:
        return Icons.swap_horiz;
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final String name;
  final int amountCents;
  final String currencyCode;

  const _PersonCard({
    required this.name,
    required this.amountCents,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            child: Text(
              initial,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.bodyLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            CurrencyFormatter.formatCents(amountCents, currencyCode),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
