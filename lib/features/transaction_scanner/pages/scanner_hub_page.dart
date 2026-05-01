import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/constrained_content.dart';
import '../providers/scanner_providers.dart';
import 'draft_transactions_page.dart';
import 'scanner_patterns_page.dart';
import 'scanner_setup_page.dart';
import 'sender_rules_page.dart';

/// Entry point for the Transaction Scanner feature.
/// Shows pending drafts count, links to review page, sender management,
/// and pattern configuration.
class ScannerHubPage extends ConsumerWidget {
  const ScannerHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(scannerEnabledProvider);
    final pendingCount = ref.watch(pendingDraftCountProvider).asData?.value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('scanner_hub_title'.tr()),
      ),
      body: ConstrainedContent(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!isEnabled) ...[
              _StatusCard(
                icon: Icons.document_scanner_outlined,
                title: 'scanner_disabled_title'.tr(),
                subtitle: 'scanner_disabled_subtitle'.tr(),
                action: FilledButton.icon(
                  onPressed: () => _openSetup(context),
                  icon: const Icon(Icons.play_arrow),
                  label: Text('scanner_enable'.tr()),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              _StatusCard(
                icon: Icons.check_circle,
                iconColor: Colors.green,
                title: 'scanner_active_title'.tr(),
                subtitle: pendingCount > 0
                    ? 'scanner_pending_count'
                        .tr(args: [pendingCount.toString()])
                    : 'scanner_no_pending'.tr(),
                action: pendingCount > 0
                    ? FilledButton.icon(
                        onPressed: () => _openReview(context),
                        icon: const Icon(Icons.checklist),
                        label: Text('scanner_review'.tr()),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
            ],
            _NavTile(
              icon: Icons.checklist,
              title: 'scanner_pending_title'.tr(),
              subtitle: '$pendingCount ${'scanner_pending_items'.tr()}',
              badge: pendingCount,
              onTap: () => _openReview(context),
            ),
            _NavTile(
              icon: Icons.app_shortcut,
              title: 'scanner_senders_title'.tr(),
              subtitle: 'scanner_senders_subtitle'.tr(),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SenderRulesPage(),
                ),
              ),
            ),
            _NavTile(
              icon: Icons.pattern,
              title: 'scanner_patterns_title'.tr(),
              subtitle: 'scanner_patterns_subtitle'.tr(),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ScannerPatternsPage(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSetup(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => const ScannerSetupPage(),
      ),
    );
  }

  void _openReview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DraftTransactionsPage(),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final Widget? action;

  const _StatusCard({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: iconColor ?? theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int badge;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge > 99 ? '99+' : '$badge',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
