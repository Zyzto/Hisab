import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/layout/constrained_content.dart';
import '../domain/sender_rule.dart';
import '../providers/scanner_providers.dart';

const _uuid = Uuid();

class SenderRulesPage extends ConsumerWidget {
  const SenderRulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(senderRulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('scanner_senders_title'.tr()),
      ),
      body: ConstrainedContent(
        child: rulesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (rules) => rules.isEmpty
              ? _buildEmptyState(context)
              : _buildList(context, ref, rules),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
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
              Icons.app_shortcut,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'scanner_no_senders'.tr(),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'scanner_no_senders_subtitle'.tr(),
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
    List<SenderRule> rules,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rules.length,
      itemBuilder: (context, index) {
        final rule = rules[index];
        return _SenderRuleTile(rule: rule);
      },
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final packageController = TextEditingController();
    final labelController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('scanner_add_sender'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: packageController,
              decoration: InputDecoration(
                labelText: 'scanner_package_name'.tr(),
                hintText: 'com.example.bank',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelController,
              decoration: InputDecoration(
                labelText: 'scanner_sender_label'.tr(),
                hintText: 'My Bank',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              final pkg = packageController.text.trim();
              if (pkg.isEmpty) return;
              final rule = SenderRule(
                id: _uuid.v4(),
                packageName: pkg,
                senderLabel: labelController.text.trim().isEmpty
                    ? null
                    : labelController.text.trim(),
                createdAt: DateTime.now(),
              );
              ref.read(scannerRepositoryProvider).upsertSenderRule(rule).then((_) {
                ref.invalidate(senderRulesProvider);
                ref
                    .read(scannerControllerProvider)
                    .syncSendersToNative();
              });
              Navigator.pop(ctx);
            },
            child: Text('scanner_add'.tr()),
          ),
        ],
      ),
    );
  }
}

class _SenderRuleTile extends ConsumerWidget {
  final SenderRule rule;

  const _SenderRuleTile({required this.rule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: rule.enabled
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.app_shortcut,
          color: rule.enabled
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(rule.displayName),
      subtitle: Text(
        '${rule.packageName}  •  ${rule.matchCount} ${'scanner_matches'.tr()}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Switch.adaptive(
        value: rule.enabled,
        onChanged: (v) {
          final updated = rule.copyWith(enabled: v);
          ref.read(scannerRepositoryProvider).upsertSenderRule(updated).then((_) {
            ref.invalidate(senderRulesProvider);
            ref.read(scannerControllerProvider).syncSendersToNative();
          });
        },
      ),
      onLongPress: () => _confirmDelete(context, ref),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('scanner_delete_sender'.tr()),
        content: Text(rule.displayName),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        ref.read(scannerRepositoryProvider).deleteSenderRule(rule.id).then((_) {
          ref.invalidate(senderRulesProvider);
          ref.read(scannerControllerProvider).syncSendersToNative();
        });
      }
    });
  }
}
