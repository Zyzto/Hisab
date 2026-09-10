import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab_backend/hisab_backend.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/toast.dart';
import '../providers/billing_providers.dart';

class BillingPlusCard extends ConsumerWidget {
  const BillingPlusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(billingSnapshotProvider);
    return snapshot.when(
      loading: () => const ListTile(
        leading: Icon(Icons.workspace_premium_outlined),
        title: Text('Hisab Plus'),
        subtitle: LinearProgressIndicator(),
      ),
      error: (_, _) => ListTile(
        leading: const Icon(Icons.workspace_premium_outlined),
        title: Text('hisab_plus'.tr()),
        subtitle: Text('hisab_plus_error'.tr()),
        onTap: () => ref.invalidate(billingSnapshotProvider),
      ),
      data: (value) => _BillingPlusTile(snapshot: value),
    );
  }
}

class _BillingPlusTile extends ConsumerWidget {
  const _BillingPlusTile({required this.snapshot});

  final CloudBillingSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!snapshot.configured) return const SizedBox.shrink();

    final title = snapshot.isPlus
        ? 'hisab_plus_active'.tr()
        : 'hisab_plus'.tr();
    final subtitle = snapshot.isPlus
        ? _activeSubtitle(context, snapshot)
        : 'hisab_plus_description'.tr();

    return ListTile(
      leading: Icon(
        snapshot.isPlus
            ? Icons.workspace_premium
            : Icons.workspace_premium_outlined,
        color: snapshot.isPlus ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showBillingPlusSheet(context, ref, snapshot: snapshot),
    );
  }
}

Future<void> showBillingPlusSheet(
  BuildContext context,
  WidgetRef ref, {
  CloudBillingSnapshot? snapshot,
}) async {
  late final CloudBillingSnapshot value;
  if (snapshot != null) {
    value = snapshot;
  } else {
    value = await ref.read(billingSnapshotProvider.future);
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _BillingSheet(snapshot: value),
  );
}

class _BillingSheet extends ConsumerWidget {
  const _BillingSheet({required this.snapshot});

  final CloudBillingSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(billingOffersProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              snapshot.isPlus ? 'hisab_plus_active'.tr() : 'hisab_plus'.tr(),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              snapshot.isPlus
                  ? _activeSubtitle(context, snapshot)
                  : 'hisab_plus_description'.tr(),
            ),
            const SizedBox(height: 12),
            _UsageSummary(snapshot: snapshot),
            const SizedBox(height: 16),
            if (!snapshot.isPlus)
              offers.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, _) => Text('hisab_plus_error'.tr()),
                data: (items) => Column(
                  children: [
                    for (final offer in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FilledButton(
                          onPressed: () => _purchase(context, ref, offer),
                          child: Text('${offer.title} · ${offer.price}'),
                        ),
                      ),
                    if (items.isEmpty) Text('hisab_plus_not_configured'.tr()),
                  ],
                ),
              ),
            OutlinedButton(
              onPressed: () => _restore(context, ref),
              child: Text('hisab_plus_restore'.tr()),
            ),
            if (snapshot.isPlus)
              TextButton(
                onPressed: () => _manage(context),
                child: Text('hisab_plus_manage'.tr()),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _purchase(
  BuildContext context,
  WidgetRef ref,
  CloudOffer offer,
) async {
  try {
    final result = await purchaseBillingOffer(ref, offer);
    if (!context.mounted) return;
    if (result.status == CloudPurchaseStatus.cancelled) {
      context.showToast('hisab_plus_purchase_cancelled'.tr());
    } else if (result.status == CloudPurchaseStatus.pending) {
      context.showToast('hisab_plus_purchase_pending'.tr());
    } else {
      context.showSuccess('hisab_plus_active'.tr());
      Navigator.of(context).pop();
    }
  } on CloudException catch (error) {
    if (context.mounted) {
      context.showError(
        error.kind == CloudErrorKind.quotaExceeded
            ? 'hisab_plus_limit_reached'.tr()
            : error.message,
      );
    }
  } catch (_) {
    if (context.mounted) context.showError('hisab_plus_error'.tr());
  }
}

Future<void> _restore(BuildContext context, WidgetRef ref) async {
  try {
    await restoreBillingPurchases(ref);
    if (context.mounted) {
      context.showSuccess('hisab_plus_restore_done'.tr());
      Navigator.of(context).pop();
    }
  } catch (_) {
    if (context.mounted) context.showError('hisab_plus_error'.tr());
  }
}

Future<void> _manage(BuildContext context) async {
  final backend = cloudBackend;
  if (backend == null) return;
  try {
    final uri = await backend.billing.managementUrl();
    if (uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
    if (context.mounted) context.showError('hisab_plus_manage_error'.tr());
  } catch (_) {
    if (context.mounted) context.showError('hisab_plus_manage_error'.tr());
  }
}

String _activeSubtitle(BuildContext context, CloudBillingSnapshot snapshot) {
  final expiry = snapshot.expiresAt;
  if (expiry == null) return 'hisab_plus_active_description'.tr();
  final messageKey = snapshot.willRenew == false
      ? 'hisab_plus_ends'
      : 'hisab_plus_renews';
  return messageKey.tr(
    namedArgs: {
      'date': MaterialLocalizations.of(context).formatMediumDate(expiry),
    },
  );
}

class _UsageSummary extends StatelessWidget {
  const _UsageSummary({required this.snapshot});

  final CloudBillingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final groups = snapshot.usage.groups;
    final maxPeople = groups.isEmpty
        ? 0
        : groups
              .map((group) => group.people)
              .reduce((left, right) => left > right ? left : right);
    final maxExpenses = groups.isEmpty
        ? 0
        : groups
              .map((group) => group.expenses)
              .reduce((left, right) => left > right ? left : right);
    final unlimited = 'hisab_plus_unlimited'.tr();
    String limit(int? value) => value?.toString() ?? unlimited;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'hisab_plus_usage'.tr(),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'hisab_plus_groups'.tr(
            namedArgs: {
              'used': groups.length.toString(),
              'limit': limit(snapshot.limits.maxGroups),
            },
          ),
        ),
        Text(
          'hisab_plus_people'.tr(
            namedArgs: {
              'used': maxPeople.toString(),
              'limit': limit(snapshot.limits.maxPeoplePerGroup),
            },
          ),
        ),
        Text(
          'hisab_plus_expenses'.tr(
            namedArgs: {
              'used': maxExpenses.toString(),
              'limit': limit(snapshot.limits.maxExpensesPerGroup),
            },
          ),
        ),
        Text(
          'hisab_plus_receipts'.tr(
            namedArgs: {
              'used': _formatBytes(snapshot.usage.receiptBytes),
              'limit': snapshot.limits.maxReceiptBytes == null
                  ? unlimited
                  : _formatBytes(snapshot.limits.maxReceiptBytes!),
            },
          ),
        ),
      ],
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
