import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/sign_in_sheet.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/widgets/toast.dart';
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
  bool _accepting = false;
  String? _error;
  /// Set when accept fails because user is already a member; enables "Open Group" action.
  String? _alreadyMemberGroupId;

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
                        color: _alreadyMemberGroupId != null
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (_alreadyMemberGroupId != null)
            FilledButton(
              onPressed: () => context.go(RoutePaths.groupDetail(_alreadyMemberGroupId!)),
              child: Text('open_group'.tr()),
            )
          else
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
    if (!ref.read(isAuthenticatedProvider)) {
      final result = await showSignInSheet(context, ref);
      switch (result) {
        case SignInResult.success:
          break;
        case SignInResult.pendingRedirect:
          return;
        case SignInResult.cancelled:
          if (context.mounted) context.showToast('sign_in_required'.tr());
          return;
      }
    }

    setState(() {
      _accepting = true;
      _error = null;
      _alreadyMemberGroupId = null;
    });

    try {
      final repo = ref.read(groupInviteRepositoryProvider);
      final groupId = await repo.accept(widget.token);
      TelemetryService.sendEvent('invite_accepted', {
        'groupId': groupId,
      }, enabled: ref.read(telemetryEnabledProvider));
      Log.info('Invite accepted: token=${widget.token} groupId=$groupId');
      ref.invalidate(groupsProvider);
      ref.invalidate(futureGroupProvider(groupId));
      if (context.mounted) {
        context.go(RoutePaths.groupDetail(groupId));
      }
    } catch (e, st) {
      Log.warning('Invite accept failed', error: e, stackTrace: st);
      if (mounted) {
        final isAlreadyMember = e.toString().contains('Already a member of this group');
        setState(() {
          if (isAlreadyMember) {
            _error = 'invite_already_member'.tr();
            _alreadyMemberGroupId = group.id;
          } else {
            _error = e.toString().contains('Unauthenticated')
                ? 'sign_in_required'.tr()
                : e.toString();
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _accepting = false);
      }
    }
  }
}
