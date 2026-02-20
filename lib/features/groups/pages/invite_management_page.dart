import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../../core/constants/supabase_config.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/theme/theme_config.dart';
import '../../../domain/domain.dart';
import '../providers/group_invite_provider.dart';
import '../providers/groups_provider.dart';
import '../widgets/create_invite_sheet.dart';

class InviteManagementPage extends ConsumerStatefulWidget {
  final String groupId;
  const InviteManagementPage({super.key, required this.groupId});

  @override
  ConsumerState<InviteManagementPage> createState() =>
      _InviteManagementPageState();
}

class _InviteManagementPageState extends ConsumerState<InviteManagementPage> {
  InviteStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invitesAsync = ref.watch(invitesByGroupProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(
        title: Text('invite_links'.tr()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateInviteSheet(context, ref, widget.groupId),
        tooltip: 'create_invite'.tr(),
        child: const Icon(Icons.add),
      ),
      body: invitesAsync.when(
        data: (invites) {
          // Sort: active first, then by created_at desc
          invites.sort((a, b) {
            final aActive = a.status == InviteStatus.active ? 0 : 1;
            final bActive = b.status == InviteStatus.active ? 0 : 1;
            if (aActive != bActive) return aActive.compareTo(bActive);
            return b.createdAt.compareTo(a.createdAt);
          });

          final filtered = _filter == null
              ? invites
              : invites.where((i) => i.status == _filter).toList();

          return Column(
            children: [
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: ThemeConfig.spacingM,
                  vertical: ThemeConfig.spacingS,
                ),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'invite_filter_all'.tr(),
                      count: invites.length,
                      selected: _filter == null,
                      onSelected: () => setState(() => _filter = null),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'invite_filter_active'.tr(),
                      count: invites
                          .where((i) => i.status == InviteStatus.active)
                          .length,
                      selected: _filter == InviteStatus.active,
                      onSelected: () =>
                          setState(() => _filter = InviteStatus.active),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'invite_filter_expired'.tr(),
                      count: invites
                          .where((i) => i.status == InviteStatus.expired)
                          .length,
                      selected: _filter == InviteStatus.expired,
                      onSelected: () =>
                          setState(() => _filter = InviteStatus.expired),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'invite_filter_revoked'.tr(),
                      count: invites
                          .where((i) => i.status == InviteStatus.revoked)
                          .length,
                      selected: _filter == InviteStatus.revoked,
                      onSelected: () =>
                          setState(() => _filter = InviteStatus.revoked),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.link_off,
                              size: 48,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withAlpha(120),
                            ),
                            const SizedBox(height: ThemeConfig.spacingM),
                            Text(
                              'invite_empty'.tr(),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(
                          top: ThemeConfig.spacingS,
                          bottom: 80,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => _InviteCard(
                          invite: filtered[i],
                          groupId: widget.groupId,
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

// ─── Filter Chip ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
    );
  }
}

// ─── Invite Card ─────────────────────────────────────────────────────────────

class _InviteCard extends ConsumerStatefulWidget {
  final GroupInvite invite;
  final String groupId;

  const _InviteCard({required this.invite, required this.groupId});

  @override
  ConsumerState<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends ConsumerState<_InviteCard> {
  bool _expanded = false;
  bool _actionLoading = false;

  String _inviteUrl(String token) {
    final base = inviteLinkBaseUrl.endsWith('/')
        ? inviteLinkBaseUrl.substring(0, inviteLinkBaseUrl.length - 1)
        : inviteLinkBaseUrl;
    return '$base/functions/v1/invite-redirect?token=$token';
  }

  Widget _statusChip(BuildContext context) {
    final theme = Theme.of(context);
    final invite = widget.invite;
    Color bg;
    Color fg;
    String text;

    switch (invite.status) {
      case InviteStatus.active:
        bg = Colors.green.withAlpha(30);
        fg = Colors.green;
        text = 'invite_status_active'.tr();
        break;
      case InviteStatus.expired:
        bg = theme.colorScheme.onSurfaceVariant.withAlpha(20);
        fg = theme.colorScheme.onSurfaceVariant;
        text = 'invite_status_expired'.tr();
        break;
      case InviteStatus.maxedOut:
        bg = Colors.orange.withAlpha(30);
        fg = Colors.orange;
        text = 'invite_status_maxed'.tr();
        break;
      case InviteStatus.revoked:
        bg = theme.colorScheme.error.withAlpha(30);
        fg = theme.colorScheme.error;
        text = 'invite_status_revoked'.tr();
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }

  String _expiryText() {
    final invite = widget.invite;
    if (invite.expiresAt == null) return 'invite_never_expires'.tr();
    if (invite.isExpired) {
      return 'invite_expired_on'.tr(args: [
        DateFormat.yMMMd().format(invite.expiresAt!),
      ]);
    }
    final diff = invite.expiresAt!.difference(DateTime.now());
    if (diff.inDays > 0) {
      return 'invite_expires_in_days'.tr(args: ['${diff.inDays}']);
    }
    if (diff.inHours > 0) {
      return 'invite_expires_in_hours'.tr(args: ['${diff.inHours}']);
    }
    return 'invite_expires_in_minutes'.tr(args: ['${diff.inMinutes}']);
  }

  String _usageText() {
    final invite = widget.invite;
    if (invite.maxUses != null) {
      return '${invite.useCount} / ${invite.maxUses}';
    }
    return '${invite.useCount} (${'invite_unlimited'.tr()})';
  }

  Future<void> _toggleActive() async {
    setState(() => _actionLoading = true);
    try {
      final repo = ref.read(groupInviteRepositoryProvider);
      await repo.toggleActive(widget.invite.id, !widget.invite.isActive);
    } catch (e, st) {
      Log.warning('Toggle invite failed', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted) setState(() => _actionLoading = false);
  }

  Future<void> _revoke() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('invite_revoke_title'.tr()),
        content: Text('invite_revoke_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('invite_revoke'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _actionLoading = true);
    try {
      await ref.read(groupInviteRepositoryProvider).revoke(widget.invite.id);
    } catch (e, st) {
      Log.warning('Revoke invite failed', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted) setState(() => _actionLoading = false);
  }

  void _showQrCode() {
    final url = _inviteUrl(widget.invite.token);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      builder: (ctx) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: PrettyQrView.data(
                    data: url,
                    errorCorrectLevel: QrErrorCorrectLevel.M,
                    decoration: const PrettyQrDecoration(
                      shape: PrettyQrSmoothSymbol(color: Colors.black),
                      background: Colors.white,
                      quietZone: PrettyQrQuietZone.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                url,
                style: Theme.of(ctx).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('invite_link_copied'.tr())),
                  );
                },
                icon: const Icon(Icons.copy),
                label: Text('copy_link'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invite = widget.invite;
    final displayLabel = invite.label?.isNotEmpty == true
        ? invite.label!
        : 'invite_untitled'.tr();

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: ThemeConfig.spacingM,
        vertical: ThemeConfig.spacingXS,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(ThemeConfig.cardBorderRadius),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(ThemeConfig.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayLabel,
                                style: theme.textTheme.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _statusChip(context),
                            if (invite.role == 'admin') ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'group_admin'.tr(),
                                  style:
                                      theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Info row
                        DefaultTextStyle(
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.people_outline, size: 14),
                              const SizedBox(width: 4),
                              Text(_usageText()),
                              const SizedBox(width: 12),
                              const Icon(Icons.schedule, size: 14),
                              const SizedBox(width: 4),
                              Flexible(child: Text(_expiryText())),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              // Expanded section
              if (_expanded) ...[
                const SizedBox(height: ThemeConfig.spacingS),
                const Divider(height: 1),
                const SizedBox(height: ThemeConfig.spacingS),

                // Created info
                Text(
                  'invite_created_on'.tr(args: [
                    DateFormat.yMMMd().add_jm().format(invite.createdAt),
                  ]),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: ThemeConfig.spacingS),

                // Actions
                if (_actionLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (invite.isUsable) ...[
                        _ActionChip(
                          icon: Icons.copy,
                          label: 'copy_link'.tr(),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(
                                  text: _inviteUrl(invite.token)),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('invite_link_copied'.tr())),
                            );
                          },
                        ),
                        _ActionChip(
                          icon: Icons.qr_code,
                          label: 'show_qr_code'.tr(),
                          onPressed: _showQrCode,
                        ),
                      ],
                      if (invite.isActive)
                        _ActionChip(
                          icon: Icons.pause,
                          label: 'invite_pause'.tr(),
                          onPressed: _toggleActive,
                        )
                      else if (invite.status == InviteStatus.revoked)
                        _ActionChip(
                          icon: Icons.play_arrow,
                          label: 'invite_resume'.tr(),
                          onPressed: _toggleActive,
                        ),
                      if (invite.isActive)
                        _ActionChip(
                          icon: Icons.block,
                          label: 'invite_revoke'.tr(),
                          onPressed: _revoke,
                          isDestructive: true,
                        ),
                    ],
                  ),

                // Usage history
                if (invite.useCount > 0) ...[
                  const SizedBox(height: ThemeConfig.spacingS),
                  const Divider(height: 1),
                  const SizedBox(height: ThemeConfig.spacingS),
                  Text(
                    'invite_usage_history'.tr(),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: ThemeConfig.spacingXS),
                  _UsageHistoryList(
                      inviteId: invite.id, groupId: widget.groupId),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Action Chip ─────────────────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
      onPressed: onPressed,
      side: BorderSide(
        color: isDestructive
            ? theme.colorScheme.error.withAlpha(80)
            : theme.colorScheme.outlineVariant,
      ),
    );
  }
}

// ─── Usage History List ──────────────────────────────────────────────────────

class _UsageHistoryList extends ConsumerWidget {
  final String inviteId;
  final String groupId;
  const _UsageHistoryList(
      {required this.inviteId, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final usagesAsync = ref.watch(inviteUsagesProvider(inviteId));
    final participantsAsync = ref.watch(participantsByGroupProvider(groupId));

    return usagesAsync.when(
      data: (usages) {
        if (usages.isEmpty) {
          return Text(
            'invite_no_usages'.tr(),
            style: theme.textTheme.bodySmall,
          );
        }
        final participants = switch (participantsAsync) {
          AsyncData(value: final list) => list,
          _ => <Participant>[],
        };
        final userIdToName = <String, String>{
          for (final p in participants)
            if (p.userId != null &&
                p.name.isNotEmpty &&
                p.userId!.isNotEmpty)
              p.userId!: p.name,
        };
        return Column(
          children: usages.map((usage) {
            final dateStr =
                DateFormat.yMMMd().add_jm().format(usage.acceptedAt);
            final displayLabel = userIdToName[usage.userId] ??
                (usage.userId.length > 8
                    ? '${usage.userId.substring(0, 8)}...'
                    : usage.userId);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayLabel,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(8.0),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Text('$e', style: theme.textTheme.bodySmall),
    );
  }
}
