import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/constrained_content.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/widgets/user_text.dart';
import '../domain/scanner_notification_log.dart';
import '../providers/scanner_providers.dart';
import 'draft_transaction_detail_page.dart';

class ScannerHistoryPage extends ConsumerStatefulWidget {
  final String? packageName;

  const ScannerHistoryPage({super.key, this.packageName});

  @override
  ConsumerState<ScannerHistoryPage> createState() => _ScannerHistoryPageState();
}

class _ScannerHistoryPageState extends ConsumerState<ScannerHistoryPage> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(
      scannerNotificationLogProvider((
        packageName: widget.packageName,
        filter: _filter,
      )),
    );

    return Scaffold(
      appBar: AppBar(title: Text('scanner_history_title'.tr())),
      body: ConstrainedContent(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final f in ['all', 'added', 'ignored', 'pending'])
                    FilterChip(
                      label: Text('scanner_history_$f'.tr()),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                ],
              ),
            ),
            Expanded(
              child: logsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (logs) {
                  if (logs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'scanner_history_empty'.tr(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, i) => _LogTile(log: logs[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogTile extends ConsumerWidget {
  final ScannerNotificationLog log;

  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final added = log.outcome == ScannerLogOutcome.added;
    final pending = log.outcome == ScannerLogOutcome.pending;
    final color = added
        ? Colors.green
        : pending
        ? cs.primary
        : cs.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(
          added
              ? Icons.check_circle
              : pending
              ? Icons.hourglass_top
              : Icons.block,
          color: color,
        ),
        title: UserText(
          log.merchantName ?? log.senderTitle ?? log.senderPackage,
        ),
        subtitle: Text(
          [
            log.outcome.reasonKey.tr(),
            if (log.amountCents != null)
              '${log.currencyCode ?? ''} ${(log.amountCents!.abs() / 100).toStringAsFixed(2)}',
            log.rawText.length > 60
                ? '${log.rawText.substring(0, 60)}…'
                : log.rawText,
          ].where((s) => s.trim().isNotEmpty).join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () async {
          if (added &&
              log.createdExpenseId != null &&
              log.targetGroupId != null) {
            context.push(RoutePaths.groupDetail(log.targetGroupId!));
            return;
          }
          if (pending && log.draftId != null) {
            final draft = await ref
                .read(scannerRepositoryProvider)
                .getDraftById(log.draftId!);
            if (draft != null && context.mounted) {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DraftTransactionDetailPage(draft: draft),
                ),
              );
            }
          }
        },
        trailing: log.outcome.isIgnored && log.amountCents != null
            ? TextButton(
                onPressed: () {
                  ref.read(scannerControllerProvider).promoteLogToDraft(log);
                },
                child: Text('scanner_add_anyway'.tr()),
              )
            : null,
      ),
    );
  }
}
