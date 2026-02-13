import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/telemetry/telemetry_service.dart';
import '../../../domain/domain.dart';
import '../providers/group_invite_provider.dart';
import '../providers/groups_provider.dart';
import '../../settings/providers/settings_framework_providers.dart';

class InviteAcceptPage extends ConsumerStatefulWidget {
  final String token;

  const InviteAcceptPage({super.key, required this.token});

  @override
  ConsumerState<InviteAcceptPage> createState() => _InviteAcceptPageState();
}

class _InviteAcceptPageState extends ConsumerState<InviteAcceptPage> {
  String? _selectedParticipantId;
  String _newParticipantName = '';
  bool _useNewParticipant = false;
  bool _accepting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final localOnly = ref.watch(effectiveLocalOnlyProvider);
    final inviteAsync = ref.watch(inviteByTokenProvider(widget.token));

    if (localOnly) {
      return Scaffold(
        appBar: AppBar(title: Text('invite'.tr())),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'invite_requires_online'.tr(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('invite'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(RoutePaths.home),
        ),
      ),
      body: inviteAsync.when(
        data: (data) {
          if (data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.link_off,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'invite_expired'.tr(),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            );
          }
          return _buildInviteContent(context, data.invite, data.group);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text('$e', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInviteContent(
    BuildContext context,
    GroupInvite invite,
    Group group,
  ) {
    final participantsAsync = ref.watch(participantsByGroupProvider(group.id));
    final requireChoice = group.requireParticipantAssignment;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'invite_to_group'.tr().replaceAll('{name}', group.name),
                    style: theme.textTheme.titleLarge,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            requireChoice
                ? 'choose_your_participant'.tr()
                : 'choose_your_participant_optional'.tr(),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          participantsAsync.when(
            data: (participants) {
              final groupValue = _useNewParticipant
                  ? 'new'
                  : _selectedParticipantId;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RadioGroup<String?>(
                    groupValue: groupValue,
                    onChanged: (v) {
                      setState(() {
                        if (v == 'new') {
                          _useNewParticipant = true;
                          _selectedParticipantId = null;
                          _newParticipantName = '';
                        } else {
                          _useNewParticipant = false;
                          _selectedParticipantId = v;
                          _newParticipantName = '';
                        }
                      });
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (participants.isNotEmpty)
                          ...participants.map(
                            (p) => RadioListTile<String?>(
                              value: p.id,
                              title: Text(p.name),
                            ),
                          ),
                        RadioListTile<String?>(
                          value: 'new',
                          title: Text('create_new_participant'.tr()),
                        ),
                      ],
                    ),
                  ),
                  if (_useNewParticipant)
                    Padding(
                      padding: const EdgeInsets.only(left: 48, top: 8),
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'participant_name'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) =>
                            setState(() => _newParticipantName = v.trim()),
                      ),
                    ),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _accepting ? null : () => _accept(context, group),
            child: _accepting
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('accept_invite'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _accept(BuildContext context, Group group) async {
    if (group.requireParticipantAssignment) {
      if (_useNewParticipant) {
        if (_newParticipantName.isEmpty) {
          setState(() => _error = 'participant_name_required'.tr());
          return;
        }
      } else if (_selectedParticipantId == null) {
        setState(() => _error = 'choose_your_participant'.tr());
        return;
      }
    }

    setState(() {
      _accepting = true;
      _error = null;
    });

    try {
      final repo = ref.read(groupInviteRepositoryProvider);
      final groupId = await repo.accept(
        widget.token,
        participantId: _useNewParticipant ? null : _selectedParticipantId,
        newParticipantName: _useNewParticipant ? _newParticipantName : null,
      );
      TelemetryService.sendEvent('invite_accepted', {
        'groupId': groupId,
      }, enabled: ref.read(telemetryEnabledProvider));
      Log.info('Invite accepted: token=${widget.token} groupId=$groupId');
      if (context.mounted) {
        context.go(RoutePaths.groupDetail(groupId));
      }
    } catch (e, st) {
      Log.warning('Invite accept failed', error: e, stackTrace: st);
      if (mounted) {
        setState(() {
          _accepting = false;
          _error = e.toString().contains('Unauthenticated')
              ? 'sign_in_required'.tr()
              : e.toString();
        });
      }
    }
  }
}
