import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/constrained_content.dart';
import '../domain/draft_transaction.dart';
import '../providers/scanner_providers.dart';
import 'draft_transaction_detail_page.dart';

class DraftTransactionsPage extends ConsumerWidget {
  const DraftTransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsAsync = ref.watch(pendingDraftsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('scanner_pending_title'.tr()),
        actions: [
          if (draftsAsync.asData?.value.isNotEmpty == true)
            TextButton.icon(
              onPressed: () => _confirmAll(context, ref),
              icon: const Icon(Icons.done_all),
              label: Text('scanner_confirm_all'.tr()),
            ),
        ],
      ),
      body: ConstrainedContent(
        child: draftsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (drafts) => drafts.isEmpty
              ? _buildEmptyState(context)
              : _buildList(context, ref, drafts),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'scanner_no_pending'.tr(),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'scanner_no_pending_subtitle'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<DraftTransaction> drafts,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: drafts.length,
      itemBuilder: (context, index) {
        final draft = drafts[index];
        return _DraftCard(draft: draft);
      },
    );
  }

  void _confirmAll(BuildContext context, WidgetRef ref) {
    final controller = ref.read(scannerControllerProvider);
    final drafts = ref.read(pendingDraftsProvider).asData?.value ?? [];
    final highConfidence = drafts.where((d) => d.confidence >= 0.7).toList();
    if (highConfidence.isEmpty) return;

    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('scanner_confirm_all_title'.tr()),
        content: Text(
          'scanner_confirm_all_body'.tr(
            args: [highConfidence.length.toString()],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        for (final d in highConfidence) {
          controller.confirmDraft(d.id);
        }
      }
    });
  }
}

class _DraftCard extends ConsumerWidget {
  final DraftTransaction draft;

  const _DraftCard({required this.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isNegative = draft.amountCents < 0;

    return Dismissible(
      key: ValueKey(draft.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          ref.read(scannerControllerProvider).confirmDraft(draft.id);
          return true;
        } else {
          ref.read(scannerControllerProvider).dismissDraft(draft.id);
          return true;
        }
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: Colors.green,
        child: const Icon(Icons.check, color: Colors.white, size: 28),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: colorScheme.error,
        child: const Icon(Icons.close, color: Colors.white, size: 28),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DraftTransactionDetailPage(draft: draft),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _ConfidenceIndicator(confidence: draft.confidence),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.displayTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (draft.cardLastFour != null) ...[
                            Text(
                              '•${draft.cardLastFour}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            _formatDate(draft.transactionDate),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${isNegative ? '+' : ''}${_formatAmount(draft.amountCents.abs(), draft.currencyCode)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isNegative ? Colors.green : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatAmount(int cents, String currency) {
    final whole = cents ~/ 100;
    final frac = cents % 100;
    return '$currency $whole.${frac.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}';
  }
}

class _ConfidenceIndicator extends StatelessWidget {
  final double confidence;

  const _ConfidenceIndicator({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 0.7
        ? Colors.green
        : confidence >= 0.4
            ? Colors.orange
            : Colors.red;

    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: confidence,
            strokeWidth: 3,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Text(
            '${(confidence * 100).round()}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
