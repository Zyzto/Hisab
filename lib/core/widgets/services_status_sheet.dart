import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

import '../layout/layout_breakpoints.dart';
import '../layout/responsive_sheet.dart';
import '../../features/settings/providers/settings_framework_providers.dart';
import '../services/connectivity_service.dart';
import '../services/firebase_status_client.dart';
import '../services/status_page_client.dart';

const _supabaseStatusUrl = 'https://status.supabase.com';
const _firebaseStatusUrl = 'https://status.firebase.google.com';
const _openaiStatusUrl = 'https://status.openai.com';
const _geminiStatusUrl = 'https://status.cloud.google.com';

/// Hours window for "recent" incidents in the modal.
const _recentIncidentsHours = 6;

/// Shows a bottom sheet with Supabase and Firebase status, links to status
/// pages, and recent incidents (Supabase only). Call from [SyncStatusChip] onTap.
void showServicesStatusSheet(BuildContext context, WidgetRef ref) {
  showResponsiveSheet<void>(
    context: context,
    title: 'services_status_title'.tr(),
    isScrollControlled: true,
    useSafeArea: true,
    child: _ServicesStatusSheet(ref: ref),
  );
}

class _ServicesStatusSheet extends ConsumerStatefulWidget {
  const _ServicesStatusSheet({required this.ref});
  final WidgetRef ref;

  @override
  ConsumerState<_ServicesStatusSheet> createState() => _ServicesStatusSheetState();
}

class _ServicesStatusSheetState extends ConsumerState<_ServicesStatusSheet> {
  Future<StatusPageResult>? _supabaseFuture;
  Future<FirebaseStatusResult>? _firebaseFuture;

  @override
  void initState() {
    super.initState();
    _supabaseFuture = fetchSupabaseStatus();
    _firebaseFuture = fetchFirebaseStatus();
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(syncStatusForDisplayProvider);
    final aiEnabled = ref.watch(receiptAiEnabledProvider);
    final aiProvider = ref.watch(receiptAiProviderProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final showGemini = aiEnabled && (aiProvider == 'gemini');
    final showOpenAI = aiEnabled && (aiProvider == 'openai');

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!LayoutBreakpoints.isTabletOrWider(context))
                Text(
                  'services_status_title'.tr(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 6),
              _SyncStatusLine(status: syncStatus),
              const SizedBox(height: 16),
              Text(
                'services_status_services'.tr(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<StatusPageResult>(
                future: _supabaseFuture,
                builder: (context, snapshot) {
                  return _ServiceRow(
                    name: 'service_supabase'.tr(),
                    result: snapshot.data,
                    statusPageUrl: _supabaseStatusUrl,
                  );
                },
              ),
              const SizedBox(height: 12),
              FutureBuilder<FirebaseStatusResult>(
                future: _firebaseFuture,
                builder: (context, snapshot) {
                  return _FirebaseServiceRow(
                    name: 'service_firebase'.tr(),
                    result: snapshot.data,
                    statusPageUrl: _firebaseStatusUrl,
                  );
                },
              ),
              if (showGemini) ...[
                const SizedBox(height: 12),
                _LinkOnlyServiceRow(
                  name: 'service_gemini'.tr(),
                  statusPageUrl: _geminiStatusUrl,
                ),
              ],
              if (showOpenAI) ...[
                const SizedBox(height: 12),
                _LinkOnlyServiceRow(
                  name: 'service_openai'.tr(),
                  statusPageUrl: _openaiStatusUrl,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SyncStatusLine extends StatelessWidget {
  const _SyncStatusLine({required this.status});
  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == SyncStatus.localOnly) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final (label, icon) = switch (status) {
      SyncStatus.connected => ('sync_connected'.tr(), Icons.cloud_done_outlined),
      SyncStatus.syncing => ('sync_syncing'.tr(), Icons.sync),
      SyncStatus.offline => ('sync_offline'.tr(), Icons.cloud_off_outlined),
      SyncStatus.syncFailed => ('sync_failed'.tr(), Icons.cloud_off_outlined),
      SyncStatus.localOnly => ('', Icons.storage),
    };
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '${'services_status_app_sync'.tr()}: $label',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.name,
    required this.result,
    required this.statusPageUrl,
  });

  final String name;
  final StatusPageResult? result;
  final String statusPageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    String statusText;
    Color statusColor;

    if (result == null) {
      statusText = 'services_status_loading'.tr();
      statusColor = cs.onSurfaceVariant;
    } else if (result is StatusPageFailure) {
      statusText = 'services_status_unable_to_load'.tr();
      statusColor = cs.error;
    } else {
      final summary = result! as StatusPageSummary;
      statusText = _statusDescription(summary.status.indicator);
      statusColor = _statusColor(summary.status.indicator, cs);
    }

    final recentIncidents = result is StatusPageSummary
        ? _recentIncidents((result as StatusPageSummary).incidents)
        : <StatusPageIncident>[];

    // Kuma-style: status dot on left, name + status, link on right
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openUrl(context, statusPageUrl),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status dot (Kuma-style indicator)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: cs.primary,
                  ),
                ],
              ),
              // Always show recent section (Kuma-style): list incidents or "None"
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'services_status_recent_incidents'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (recentIncidents.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'services_status_no_incidents'.tr(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      ...recentIncidents.take(3).map(
                            (i) => Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '• ${i.name}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _statusDescription(String indicator) {
    return switch (indicator) {
      'none' => 'services_status_operational'.tr(),
      'minor' => 'services_status_degraded'.tr(),
      'major' || 'critical' => 'services_status_major_outage'.tr(),
      _ => 'services_status_operational'.tr(),
    };
  }

  static Color _statusColor(String indicator, ColorScheme cs) {
    return switch (indicator) {
      'none' => cs.primary,
      'minor' => cs.tertiary,
      'major' || 'critical' => cs.error,
      _ => cs.onSurfaceVariant,
    };
  }

  static List<StatusPageIncident> _recentIncidents(
    List<StatusPageIncident> incidents,
  ) {
    final cutoff = DateTime.now().subtract(
      const Duration(hours: _recentIncidentsHours),
    );
    return incidents
        .where((i) => i.updatedAt != null && i.updatedAt!.isAfter(cutoff))
        .toList();
  }

  static Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _FirebaseServiceRow extends StatelessWidget {
  const _FirebaseServiceRow({
    required this.name,
    required this.result,
    required this.statusPageUrl,
  });

  final String name;
  final FirebaseStatusResult? result;
  final String statusPageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    String statusText;
    Color statusColor;

    if (result == null) {
      statusText = 'services_status_loading'.tr();
      statusColor = cs.onSurfaceVariant;
    } else if (result is FirebaseStatusFailure) {
      statusText = 'services_status_unable_to_load'.tr();
      statusColor = cs.error;
    } else {
      final summary = result! as FirebaseStatusSummary;
      statusText = summary.operational
          ? 'services_status_operational'.tr()
          : 'services_status_degraded'.tr();
      statusColor = summary.operational ? cs.primary : cs.tertiary;
    }

    final recentIncidents = result is FirebaseStatusSummary
        ? (result as FirebaseStatusSummary).recentIncidents
        : <FirebaseIncident>[];

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openUrl(context, statusPageUrl),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.open_in_new, size: 18, color: cs.primary),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'services_status_recent_incidents'.tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (recentIncidents.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'services_status_no_incidents'.tr(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      ...recentIncidents.take(3).map(
                            (i) => Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '• ${i.name}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Service row with no API: name, "Check status", link to status page.
class _LinkOnlyServiceRow extends StatelessWidget {
  const _LinkOnlyServiceRow({
    required this.name,
    required this.statusPageUrl,
  });

  final String name;
  final String statusPageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final statusColor = cs.onSurfaceVariant;

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openUrl(context, statusPageUrl),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'services_status_check_status'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new, size: 18, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
