import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/receipt/receipt_image_view.dart';
import '../../../features/settings/providers/settings_framework_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/domain.dart';
import '../../groups/providers/groups_provider.dart';

/// Body content for a single expense in the detail shell (no Scaffold).
class ExpenseDetailBody extends ConsumerWidget {
  final String groupId;
  final String expenseId;

  const ExpenseDetailBody({
    super.key,
    required this.groupId,
    required this.expenseId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseAsync = ref.watch(futureExpenseProvider(expenseId));
    final participantsAsync = ref.watch(participantsByGroupProvider(groupId));

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
            return ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              children: [
                ExpenseDetailBodyHeader(
                  expense: expense,
                  use24HourFormat: ref.watch(use24HourFormatProvider),
                ),
                if (expense.receiptImagePath != null &&
                    expense.receiptImagePath!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'receipt'.tr(),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
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
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: CircularProgressIndicator()),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: CircularProgressIndicator()),
    );
  }

  static String _payerSectionLabel(Expense expense) {
    switch (expense.transactionType) {
      case TransactionType.transfer:
        return 'from'.tr();
      case TransactionType.expense:
      case TransactionType.income:
        return 'from'.tr();
    }
  }

  static List<_ShareEntry> _participantShares(
    Expense expense,
    List<Participant> participants,
    Map<String, String> nameOf,
  ) {
    if (expense.transactionType == TransactionType.transfer) {
      final toId = expense.toParticipantId;
      if (toId == null) return [];
      return [
        _ShareEntry(
          name: nameOf[toId] ?? toId,
          cents: expense.amountCents,
        ),
      ];
    }
    final shares = expense.splitShares;
    if (shares.isEmpty) return [];
    return participants
        .where((p) => shares.containsKey(p.id) && (shares[p.id] ?? 0) > 0)
        .map(
          (p) => _ShareEntry(
            name: nameOf[p.id] ?? p.id,
            cents: shares[p.id]!,
          ),
        )
        .toList();
  }
}

class _ShareEntry {
  final String name;
  final int cents;
  _ShareEntry({required this.name, required this.cents});
}

class ExpenseDetailBodyHeader extends StatelessWidget {
  final Expense expense;
  final bool use24HourFormat;

  const ExpenseDetailBodyHeader({
    super.key,
    required this.expense,
    this.use24HourFormat = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _iconForType(expense.transactionType);
    final dateFormat = use24HourFormat
        ? DateFormat('EEEE, MMMM d, yyyy').add_Hm()
        : DateFormat('EEEE, MMMM d, yyyy').add_jm();
    // Display in device timezone: stored date is UTC, convert for display.
    final localDate = expense.date.isUtc ? expense.date.toLocal() : expense.date;

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
          dateFormat.format(localDate),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  static IconData _iconForType(TransactionType type) {
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
