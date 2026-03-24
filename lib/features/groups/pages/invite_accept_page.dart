import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../core/auth/sign_in_sheet.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/layout/content_aligned_app_bar.dart';
import '../../../core/layout/constrained_content.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/utils/error_report_helper.dart';
import '../../../core/widgets/error_content.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/repository/repository_providers.dart';
import '../../../core/telemetry/telemetry_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../domain/domain.dart';
import '../providers/group_invite_provider.dart';
import '../providers/invite_preview_provider.dart';
import '../providers/groups_provider.dart';
import '../../settings/providers/settings_framework_providers.dart';
import '../../settings/settings_definitions.dart';

/// Shown when a post-frame [GoRouter.go] did not leave the page (web/router edge cases).
Widget _inviteStalledNavigationBody(
  BuildContext context, {
  required VoidCallback onPrimary,
  required String primaryLabelKey,
  required VoidCallback onGoHome,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'invite_navigation_stalled_hint'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onPrimary,
            child: Text(primaryLabelKey.tr()),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onGoHome,
            icon: const Icon(Icons.home_outlined, size: 20),
            label: Text('go_home'.tr()),
          ),
        ],
      ),
    ),
  );
}

class InviteAcceptPage extends ConsumerStatefulWidget {
  final String token;

  const InviteAcceptPage({super.key, required this.token});

  @override
  ConsumerState<InviteAcceptPage> createState() => _InviteAcceptPageState();
}

class _InviteAcceptPageState extends ConsumerState<InviteAcceptPage> {
  bool _accepting = false;
  String? _error;
  bool _didAttemptWebPreviewRedirect = false;
  bool _didAttemptPreviewRedirectForNotOnboarded = false;
  bool _didAttemptOnboardingRedirectForNotOnboarded = false;

  bool _shouldAutoRedirectToPreview(InviteAccessMode? mode) =>
      mode == InviteAccessMode.readonlyOnly;

  /// Set when accept fails because user is already a member; enables "Open Group" action.
  String? _alreadyMemberGroupId;

  _InviteAcceptErrorKind _classifyInviteAcceptError(Object error) {
    if (error is AuthException) return _InviteAcceptErrorKind.unauthenticated;
    final dynamic d = error;
    int? statusCode;
    String? code;
    String? message;
    String? details;
    String? hint;
    try {
      if (d.status is int) statusCode = d.status as int;
      if (d.statusCode is int) statusCode = d.statusCode as int;
      if (d.code is String) code = d.code as String;
      if (d.message is String) message = d.message as String;
      if (d.details is String) details = d.details as String;
      if (d.hint is String) hint = d.hint as String;
    } catch (_) {}

    if (statusCode == 401 || statusCode == 403) {
      return _InviteAcceptErrorKind.unauthenticated;
    }
    final combined = <String>[
      error.toString(),
      ...[message, details, hint].whereType<String>(),
    ].join(' | ').toLowerCase();
    final normalizedCode = code?.toUpperCase();

    if (normalizedCode == 'UNAUTHENTICATED' ||
        combined.contains('unauthenticated') ||
        combined.contains('not authenticated')) {
      return _InviteAcceptErrorKind.unauthenticated;
    }
    if (normalizedCode == 'ALREADY_MEMBER' ||
        combined.contains('already a member of this group')) {
      return _InviteAcceptErrorKind.alreadyMember;
    }
    if (normalizedCode == 'INVITE_INVALID_OR_EXPIRED' ||
        normalizedCode == 'INVITE_INACTIVE' ||
        normalizedCode == 'INVITE_MAX_USES' ||
        combined.contains('invalid or expired invite') ||
        combined.contains('invite is not active') ||
        combined.contains('invite has reached max uses')) {
      return _InviteAcceptErrorKind.invalidOrExpired;
    }
    return _InviteAcceptErrorKind.unknown;
  }

  String _errorMessageForDisplay(Object error) {
    final dynamic d = error;
    try {
      if (d.message is String && (d.message as String).trim().isNotEmpty) {
        return d.message as String;
      }
    } catch (_) {}
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    final localOnly = ref.watch(effectiveLocalOnlyProvider);
    final hasNetwork = ref.watch(connectivityProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final onboardingCompleted = ref.watch(onboardingCompletedProvider);
    final inviteAsync = ref.watch(inviteByTokenProvider(widget.token));

    // Not onboarded and not authenticated: resolve via preview (anon) and redirect to preview or onboarding
    if (!onboardingCompleted &&
        !isAuthenticated &&
        supabaseConfigAvailable &&
        !localOnly) {
      if (widget.token.isEmpty) {
        return LayoutBuilder(
          builder: (context, layoutConstraints) {
            return Scaffold(
              appBar: ContentAlignedAppBar(
                contentAreaWidth: layoutConstraints.maxWidth,
                title: Text('invite'.tr()),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => context.go(RoutePaths.home),
                ),
              ),
              body: Center(
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
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => context.go(RoutePaths.home),
                      child: Text('go_home'.tr()),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
      final previewAsync = ref.watch(invitePreviewDataProvider(widget.token));
      return LayoutBuilder(
        builder: (context, layoutConstraints) {
          return Scaffold(
            appBar: ContentAlignedAppBar(
              contentAreaWidth: layoutConstraints.maxWidth,
              title: Text('invite'.tr()),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.go(RoutePaths.home),
              ),
            ),
            body: previewAsync.when(
              data: (preview) {
                if (preview != null) {
                  final shouldAutoPreview = _shouldAutoRedirectToPreview(
                    preview.invite.accessMode,
                  );
                  if (shouldAutoPreview && !_didAttemptPreviewRedirectForNotOnboarded) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      if (_didAttemptPreviewRedirectForNotOnboarded) return;
                      setState(
                        () => _didAttemptPreviewRedirectForNotOnboarded = true,
                      );
                      if (mounted) {
                        context.go(RoutePaths.invitePreview(widget.token));
                      }
                    });
                  }
                  if (shouldAutoPreview && _didAttemptPreviewRedirectForNotOnboarded) {
                    return _inviteStalledNavigationBody(
                      context,
                      onPrimary: () =>
                          context.go(RoutePaths.invitePreview(widget.token)),
                      primaryLabelKey: 'invite_preview_open_group',
                      onGoHome: () => context.go(RoutePaths.home),
                    );
                  }
                  if (preview.invite.accessMode == InviteAccessMode.readonlyJoin ||
                      preview.invite.accessMode == InviteAccessMode.standard) {
                    return ConstrainedContent(
                      child: _buildInviteContent(context, preview.invite, preview.group),
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                }
                if (preview == null &&
                    !_didAttemptOnboardingRedirectForNotOnboarded) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    if (_didAttemptOnboardingRedirectForNotOnboarded) return;
                    setState(
                        () => _didAttemptOnboardingRedirectForNotOnboarded = true);
                    _persistPendingInviteToken();
                    if (mounted) context.go(RoutePaths.onboarding);
                  });
                }
                if (preview == null &&
                    _didAttemptOnboardingRedirectForNotOnboarded) {
                  return _inviteStalledNavigationBody(
                    context,
                    onPrimary: () {
                      _persistPendingInviteToken();
                      context.go(RoutePaths.onboarding);
                    },
                    primaryLabelKey: 'onboarding_next',
                    onGoHome: () => context.go(RoutePaths.home),
                  );
                }
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      Text(
                        'invite_taking_to_sign_in'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => context.go(RoutePaths.home),
                        icon: const Icon(Icons.home_outlined, size: 20),
                        label: Text('go_home'.tr()),
                      ),
                    ],
                  ),
                );
              },
              loading: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () => context.go(RoutePaths.home),
                      icon: const Icon(Icons.home_outlined, size: 20),
                      label: Text('go_home'.tr()),
                    ),
                  ],
                ),
              ),
              error: (e, st) {
                if (!_didAttemptOnboardingRedirectForNotOnboarded) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    if (_didAttemptOnboardingRedirectForNotOnboarded) return;
                    setState(
                        () => _didAttemptOnboardingRedirectForNotOnboarded = true);
                    _persistPendingInviteToken();
                    if (mounted) context.go(RoutePaths.onboarding);
                  });
                }
                return Center(
                  child: ErrorContentWidget(
                    message: e.toString(),
                    details: e.toString(),
                    stackTrace: st,
                    onRetry: () =>
                        ref.invalidate(invitePreviewDataProvider(widget.token)),
                    onGoHome: () => context.go(RoutePaths.home),
                  ),
                );
              },
            ),
          );
        },
      );
    }

    // Local-only without backend configuration cannot resolve invites at all.
    if (localOnly) {
      return LayoutBuilder(
        builder: (context, layoutConstraints) {
          return Scaffold(
            appBar: ContentAlignedAppBar(
              contentAreaWidth: layoutConstraints.maxWidth,
              title: Text('invite'.tr()),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.go(RoutePaths.home),
              ),
            ),
            body: (!supabaseConfigAvailable || !hasNetwork)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'invite_requires_online'.tr(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  )
                : inviteAsync.when(
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
                      if (data.invite.accessMode == InviteAccessMode.standard) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'invite_requires_online'.tr(),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        );
                      }
                      final shouldAutoPreview = _shouldAutoRedirectToPreview(
                        data.invite.accessMode,
                      );
                      if (kIsWeb &&
                          shouldAutoPreview &&
                          !_didAttemptWebPreviewRedirect) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          if (_didAttemptWebPreviewRedirect) return;
                          setState(() => _didAttemptWebPreviewRedirect = true);
                          if (mounted) {
                            context.go(RoutePaths.invitePreview(widget.token));
                          }
                        });
                        return const Center(child: CircularProgressIndicator());
                      }
                      return ConstrainedContent(
                        child: _buildInviteContent(context, data.invite, data.group),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, st) {
                      sendErrorTelemetryIfOnline(
                        ref,
                        message: e.toString(),
                        details: e.toString(),
                      );
                      return Center(
                        child: ErrorContentWidget(
                          message: e.toString(),
                          details: e.toString(),
                          stackTrace: st,
                          onRetry: () =>
                              ref.invalidate(inviteByTokenProvider(widget.token)),
                          onGoHome: () => context.go(RoutePaths.home),
                        ),
                      );
                    },
                  ),
          );
        },
      );
    }

    // Keep the existing web landing for unauthenticated users only in standard mode.
    if (kIsWeb && !isAuthenticated) {
      return LayoutBuilder(
        builder: (context, layoutConstraints) {
          return Scaffold(
            appBar: ContentAlignedAppBar(
              contentAreaWidth: layoutConstraints.maxWidth,
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
                        const SizedBox(height: 24),
                        TextButton.icon(
                          onPressed: () => context.go(RoutePaths.home),
                          icon: const Icon(Icons.home_outlined, size: 20),
                          label: Text('go_home'.tr()),
                        ),
                      ],
                    ),
                  );
                }
                if (data.invite.accessMode == InviteAccessMode.standard) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'invite_web_heading'.tr(),
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'invite_web_message'.tr(),
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          FilledButton.icon(
                            onPressed: () => _openSignInForWebInvite(context),
                            icon: const Icon(Icons.login),
                            label: Text('invite_web_sign_in'.tr()),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final shouldAutoPreview = _shouldAutoRedirectToPreview(
                  data.invite.accessMode,
                );
                final router = GoRouter.maybeOf(context);
                if (router != null &&
                    shouldAutoPreview &&
                    !_didAttemptWebPreviewRedirect) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    if (_didAttemptWebPreviewRedirect) return;
                    setState(() => _didAttemptWebPreviewRedirect = true);
                    if (mounted) {
                      context.go(RoutePaths.invitePreview(widget.token));
                    }
                  });
                  return const Center(child: CircularProgressIndicator());
                }
                return ConstrainedContent(
                  child: _buildInviteContent(context, data.invite, data.group),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) {
                if (!isAuthenticated) {
                  return _InvitePreviewFallbackOnError(
                    token: widget.token,
                    inviteError: e,
                    inviteStack: st,
                    onRetry: () =>
                        ref.invalidate(inviteByTokenProvider(widget.token)),
                    onGoHome: () => context.go(RoutePaths.home),
                  );
                }
                sendErrorTelemetryIfOnline(
                  ref,
                  message: e.toString(),
                  details: e.toString(),
                );
                return Center(
                  child: ErrorContentWidget(
                    message: e.toString(),
                    details: e.toString(),
                    stackTrace: st,
                    onRetry: () =>
                        ref.invalidate(inviteByTokenProvider(widget.token)),
                    onGoHome: () => context.go(RoutePaths.home),
                  ),
                );
              },
            ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, layoutConstraints) {
        return Scaffold(
          appBar: ContentAlignedAppBar(
            contentAreaWidth: layoutConstraints.maxWidth,
            title: Text('invite'.tr()),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => context.go(RoutePaths.home),
            ),
          ),
          body: ConstrainedContent(
            child: inviteAsync.when(
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
                        const SizedBox(height: 24),
                        TextButton.icon(
                          onPressed: () => context.go(RoutePaths.home),
                          icon: const Icon(Icons.home_outlined, size: 20),
                          label: Text('go_home'.tr()),
                        ),
                      ],
                    ),
                  );
                }
                return _buildInviteContent(context, data.invite, data.group);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) {
                if (!isAuthenticated) {
                  return _InvitePreviewFallbackOnError(
                    token: widget.token,
                    inviteError: e,
                    inviteStack: st,
                    onRetry: () =>
                        ref.invalidate(inviteByTokenProvider(widget.token)),
                    onGoHome: () => context.go(RoutePaths.home),
                  );
                }
                sendErrorTelemetryIfOnline(
                  ref,
                  message: e.toString(),
                  details: e.toString(),
                );
                return Center(
                  child: ErrorContentWidget(
                    message: e.toString(),
                    details: e.toString(),
                    stackTrace: st,
                    onRetry: () =>
                        ref.invalidate(inviteByTokenProvider(widget.token)),
                    onGoHome: () => context.go(RoutePaths.home),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildInviteContent(
    BuildContext context,
    GroupInvite invite,
    Group group,
  ) {
    final theme = Theme.of(context);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final localOnly = ref.watch(effectiveLocalOnlyProvider);
    final isReadonlyJoin = invite.accessMode == InviteAccessMode.readonlyJoin;
    final isReadonlyOnly = invite.accessMode == InviteAccessMode.readonlyOnly;
    final showReadonlyBanner = isReadonlyJoin || isReadonlyOnly;
    final canAcceptInvite = !isReadonlyOnly;
    final showJoinRequiresOnlineCta = isReadonlyJoin && localOnly;
    final showJoinOnboardingCta =
        isReadonlyJoin && !isAuthenticated && !localOnly;

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
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'invite_to_group_prefix'.tr(),
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        group.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
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
          if (showReadonlyBanner) ...[
            const SizedBox(height: 12),
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  isReadonlyOnly
                      ? 'invite_preview_readonly_only_message'.tr()
                      : 'invite_preview_readonly_join_message'.tr(),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          if (_alreadyMemberGroupId != null)
            FilledButton(
              onPressed: () =>
                  context.go(RoutePaths.groupDetail(_alreadyMemberGroupId!)),
              child: Text('open_group'.tr()),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showReadonlyBanner) ...[
                  OutlinedButton(
                    onPressed: () =>
                        context.push(RoutePaths.invitePreview(widget.token)),
                    child: Text('invite_preview_open_group'.tr()),
                  ),
                  const SizedBox(height: 12),
                ],
                if (showJoinRequiresOnlineCta)
                  FilledButton(
                    onPressed: () => _goToOnlineRequiredForInvite(context),
                    child: Text('invite_preview_join_cta'.tr()),
                  )
                else if (showJoinOnboardingCta)
                  FilledButton(
                    onPressed: () => _goToOnboardingForInvite(context),
                    child: Text('invite_preview_join_cta'.tr()),
                  )
                else if (canAcceptInvite)
                  FilledButton(
                    onPressed: _accepting ? null : () => _accept(context, group),
                    child: _accepting
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('accept_invite'.tr()),
                  )
                else
                  OutlinedButton(
                    onPressed: null,
                    child: Text('accept_invite'.tr()),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _persistPendingInviteToken() {
    final settings = ref.read(hisabSettingsProvidersProvider);
    if (settings == null) return;
    ref.read(settings.provider(pendingInviteTokenSettingDef).notifier).set(
      widget.token,
    );
  }

  void _goToOnboardingForInvite(BuildContext context) {
    _persistPendingInviteToken();
    context.go(RoutePaths.onboarding);
  }

  void _goToOnlineRequiredForInvite(BuildContext context) {
    _persistPendingInviteToken();
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    if (isAuthenticated) {
      context.go(RoutePaths.settings);
      return;
    }
    context.go(RoutePaths.onboarding);
  }

  Future<void> _openSignInForWebInvite(BuildContext context) async {
    final result = await showSignInSheet(context, ref);
    switch (result) {
      case SignInResult.success:
        await ref.read(dataSyncServiceProvider.notifier).syncNow();
        // Page will rebuild; invite content or accept button will show
        break;
      case SignInResult.pendingRedirect:
        _persistPendingInviteToken();
        break;
      case SignInResult.cancelled:
        if (context.mounted) context.showToast('sign_in_required'.tr());
        break;
    }
  }

  Future<void> _accept(BuildContext context, Group group) async {
    if (!ref.read(isAuthenticatedProvider)) {
      final result = await showSignInSheet(context, ref);
      switch (result) {
        case SignInResult.success:
          await ref.read(dataSyncServiceProvider.notifier).syncNow();
          break;
        case SignInResult.pendingRedirect:
          _persistPendingInviteToken();
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
      final profile = ref.read(authServiceProvider).getUserProfile();
      final name = profile?.name?.trim();
      final displayName = (name != null && name.isNotEmpty)
          ? name
          : (ref.read(currentUserProvider)?.email ?? 'Member');
      final repo = ref.read(groupInviteRepositoryProvider);
      final groupId = await repo.accept(
        widget.token,
        newParticipantName: displayName,
      );
      TelemetryService.sendEvent('invite_accepted', {
        'groupId': groupId,
      }, enabled: ref.read(telemetryEnabledProvider));
      Log.info('Invite accepted: token=${widget.token} groupId=$groupId');
      Log.info('Syncing after invite accept (groupId=$groupId)');
      await ref.read(dataSyncServiceProvider.notifier).syncNow();
      // Ensure group is in local DB so GroupDetailPage does not redirect to home.
      const maxAttempts = 3;
      const retryDelay = Duration(milliseconds: 450);
      Group? groupInDb;
      for (var i = 0; i < maxAttempts; i++) {
        groupInDb = await ref.read(groupRepositoryProvider).getById(groupId);
        if (groupInDb != null) break;
        if (i < maxAttempts - 1) await Future.delayed(retryDelay);
      }
      if (groupInDb == null) {
        Log.info(
          'Group $groupId not in DB after $maxAttempts attempts, syncing once more',
        );
        await ref.read(dataSyncServiceProvider.notifier).syncNow();
      }
      Log.info('Sync after invite complete, navigating to group $groupId');
      ref.invalidate(groupsProvider);
      ref.invalidate(futureGroupProvider(groupId));
      if (context.mounted) {
        context.go(RoutePaths.groupDetail(groupId));
      }
    } catch (e, st) {
      Log.warning('Invite accept or sync failed', error: e, stackTrace: st);
      final errorKind = _classifyInviteAcceptError(e);
      final errorText = _errorMessageForDisplay(e);
      if (mounted) {
        if (errorKind == _InviteAcceptErrorKind.invalidOrExpired) {
          // The invite may have been consumed/revoked after initial preview.
          ref.invalidate(inviteByTokenProvider(widget.token));
        }
        setState(() {
          if (errorKind == _InviteAcceptErrorKind.alreadyMember) {
            _error = 'invite_already_member'.tr();
            _alreadyMemberGroupId = group.id;
          } else if (errorKind == _InviteAcceptErrorKind.invalidOrExpired) {
            _error = 'invite_expired'.tr();
          } else {
            _error = errorKind == _InviteAcceptErrorKind.unauthenticated
                ? 'sign_in_required'.tr()
                : errorText;
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

/// When inviteByToken failed (e.g. 401) and user is not authenticated, try
/// preview (anon-callable); if preview has data (readonly invite), redirect to
/// group preview so returning users with readonly links still land on preview.
class _InvitePreviewFallbackOnError extends ConsumerStatefulWidget {
  const _InvitePreviewFallbackOnError({
    required this.token,
    required this.inviteError,
    required this.inviteStack,
    required this.onRetry,
    required this.onGoHome,
  });

  final String token;
  final Object inviteError;
  final StackTrace? inviteStack;
  final VoidCallback onRetry;
  final VoidCallback onGoHome;

  @override
  ConsumerState<_InvitePreviewFallbackOnError> createState() =>
      _InvitePreviewFallbackOnErrorState();
}

class _InvitePreviewFallbackOnErrorState
    extends ConsumerState<_InvitePreviewFallbackOnError> {
  bool _didRedirect = false;

  void _persistPendingInviteToken() {
    final settings = ref.read(hisabSettingsProvidersProvider);
    if (settings == null) return;
    ref.read(settings.provider(pendingInviteTokenSettingDef).notifier).set(
      widget.token,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.token.isEmpty) {
      return Center(
        child: ErrorContentWidget(
          message: widget.inviteError.toString(),
          details: widget.inviteError.toString(),
          stackTrace: widget.inviteStack,
          onRetry: widget.onRetry,
          onGoHome: widget.onGoHome,
        ),
      );
    }
    final previewAsync = ref.watch(invitePreviewDataProvider(widget.token));
    return previewAsync.when(
      data: (preview) {
        if (preview != null) {
          if (preview.invite.accessMode == InviteAccessMode.readonlyJoin) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'invite_preview_readonly_join_message'.tr(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () =>
                          context.go(RoutePaths.invitePreview(widget.token)),
                      child: Text('invite_preview_open_group'.tr()),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        _persistPendingInviteToken();
                        context.go(RoutePaths.onboarding);
                      },
                      child: Text('invite_preview_join_cta'.tr()),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!_didRedirect) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (_didRedirect) return;
              setState(() => _didRedirect = true);
              if (mounted) {
                context.go(RoutePaths.invitePreview(widget.token));
              }
            });
          }
          if (_didRedirect) {
            return _inviteStalledNavigationBody(
              context,
              onPrimary: () =>
                  context.go(RoutePaths.invitePreview(widget.token)),
              primaryLabelKey: 'invite_preview_open_group',
              onGoHome: widget.onGoHome,
            );
          }
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: ErrorContentWidget(
            message: widget.inviteError.toString(),
            details: widget.inviteError.toString(),
            stackTrace: widget.inviteStack,
            onRetry: widget.onRetry,
            onGoHome: widget.onGoHome,
          ),
        );
      },
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: widget.onGoHome,
              icon: const Icon(Icons.home_outlined, size: 20),
              label: Text('go_home'.tr()),
            ),
          ],
        ),
      ),
      error: (_, _) => Center(
        child: ErrorContentWidget(
          message: widget.inviteError.toString(),
          details: widget.inviteError.toString(),
          stackTrace: widget.inviteStack,
          onRetry: widget.onRetry,
          onGoHome: widget.onGoHome,
        ),
      ),
    );
  }
}

enum _InviteAcceptErrorKind {
  alreadyMember,
  invalidOrExpired,
  unauthenticated,
  unknown,
}
