import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/constrained_content.dart';
import '../domain/draft_transaction.dart';
import '../providers/scanner_providers.dart';

class DraftTransactionDetailPage extends ConsumerStatefulWidget {
  final DraftTransaction draft;

  const DraftTransactionDetailPage({super.key, required this.draft});

  @override
  ConsumerState<DraftTransactionDetailPage> createState() =>
      _DraftTransactionDetailPageState();
}

class _DraftTransactionDetailPageState
    extends ConsumerState<DraftTransactionDetailPage> {
  late TextEditingController _merchantController;
  late TextEditingController _amountController;
  late String _currencyCode;
  late bool _isIncome;
  bool _showRaw = false;

  @override
  void initState() {
    super.initState();
    _isIncome = widget.draft.amountCents < 0;
    _merchantController =
        TextEditingController(text: widget.draft.merchantName ?? '');
    _amountController = TextEditingController(
      text: (widget.draft.amountCents.abs() / 100).toStringAsFixed(2),
    );
    _currencyCode = widget.draft.currencyCode;
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final draft = widget.draft;

    return Scaffold(
      appBar: AppBar(
        title: Text('scanner_draft_detail'.tr()),
        actions: [
          IconButton(
            onPressed: () {
              ref
                  .read(scannerControllerProvider)
                  .dismissDraft(draft.id);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_outline),
            tooltip: 'scanner_dismiss'.tr(),
          ),
        ],
      ),
      body: ConstrainedContent(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Extracted fields ──
            _buildFieldCard(
              context,
              icon: Icons.store_outlined,
              label: 'scanner_merchant'.tr(),
              child: TextField(
                controller: _merchantController,
                decoration: InputDecoration(
                  hintText: 'scanner_merchant_hint'.tr(),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildFieldCard(
              context,
              icon: Icons.attach_money,
              label: 'scanner_amount'.tr(),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _currencyCode,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (draft.cardLastFour != null)
              _buildInfoRow(
                context,
                Icons.credit_card,
                'scanner_card'.tr(),
                '••••  ${draft.cardLastFour}',
              ),
            _buildInfoRow(
              context,
              Icons.calendar_today,
              'scanner_date'.tr(),
              _formatFullDate(draft.transactionDate),
            ),
            if (draft.hasLocation)
              _buildInfoRow(
                context,
                Icons.location_on_outlined,
                'scanner_location'.tr(),
                '${draft.latitude!.toStringAsFixed(4)}, ${draft.longitude!.toStringAsFixed(4)}',
              ),
            _buildInfoRow(
              context,
              Icons.app_shortcut,
              'scanner_source'.tr(),
              draft.senderTitle ?? draft.senderPackage,
            ),
            _buildInfoRow(
              context,
              Icons.speed,
              'scanner_confidence'.tr(),
              '${(draft.confidence * 100).round()}%',
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // ── Raw notification ──
            InkWell(
              onTap: () => setState(() => _showRaw = !_showRaw),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _showRaw
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'scanner_raw_notification'.tr(),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showRaw) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildHighlightedText(context, draft),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => _confirm(context),
            icon: const Icon(Icons.check),
            label: Text('scanner_confirm_add'.tr()),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  /// Highlights extracted portions of the raw notification text.
  Widget _buildHighlightedText(BuildContext context, DraftTransaction draft) {
    final theme = Theme.of(context);
    final raw = draft.rawNotificationText;
    final spans = <TextSpan>[];

    final highlights = <String>{};
    if (draft.merchantName != null) highlights.add(draft.merchantName!);
    if (draft.cardLastFour != null) highlights.add(draft.cardLastFour!);
    final amountStr = (draft.amountCents.abs() / 100).toStringAsFixed(2);
    highlights.add(amountStr);

    if (highlights.isEmpty) {
      return SelectableText(
        raw,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
        ),
      );
    }

    final pattern = highlights
        .map((h) => RegExp.escape(h))
        .join('|');
    final regex = RegExp(pattern, caseSensitive: false);
    int lastEnd = 0;

    for (final match in regex.allMatches(raw)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: raw.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          backgroundColor:
              theme.colorScheme.primary.withValues(alpha: 0.2),
          fontWeight: FontWeight.w700,
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < raw.length) {
      spans.add(TextSpan(text: raw.substring(lastEnd)));
    }

    return SelectableText.rich(
      TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
        children: spans,
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _confirm(BuildContext context) {
    final editedMerchant = _merchantController.text.trim();
    final editedAmount = double.tryParse(_amountController.text.trim());
    int? editedCents;
    if (editedAmount != null) {
      final absCents = (editedAmount * 100).round();
      editedCents = _isIncome ? -absCents : absCents;
    }

    ref.read(scannerControllerProvider).confirmDraft(
      widget.draft.id,
      overrideMerchant:
          editedMerchant.isNotEmpty ? editedMerchant : null,
      overrideAmountCents: editedCents,
    );
    Navigator.pop(context);
  }
}
