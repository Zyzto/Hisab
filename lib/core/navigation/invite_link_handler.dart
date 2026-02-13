import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/providers/settings_framework_providers.dart';
import '../../features/settings/settings_definitions.dart';

/// Scheme and host used by the invite-redirect edge function for app deep links.
const String _inviteScheme = 'io.supabase.hisab';
const String _inviteHost = 'invite';

/// Extracts invite token from a URI (deep link or web /invite?token=...).
String? extractInviteTokenFromUri(Uri? uri) {
  if (uri == null) return null;
  final token = uri.queryParameters['token'];
  if (token == null || token.isEmpty) return null;
  // Deep link: io.supabase.hisab://invite?token=...
  if (uri.scheme == _inviteScheme && uri.host == _inviteHost) return token;
  // Web: https://domain/invite?token=...
  if (uri.path.contains('invite')) return token;
  return null;
}

/// Listens for app links (initial + stream) and persists invite token to settings
/// so it survives onboarding and OAuth redirects.
class InviteLinkHandler extends ConsumerStatefulWidget {
  const InviteLinkHandler({super.key, required this.ref, required this.child});

  final WidgetRef ref;
  final Widget child;

  @override
  ConsumerState<InviteLinkHandler> createState() => _InviteLinkHandlerState();
}

class _InviteLinkHandlerState extends ConsumerState<InviteLinkHandler> {
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupAppLinks());
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _setupAppLinks() async {
    final settings = ref.read(hisabSettingsProvidersProvider);
    if (settings == null) return;

    final notifier = ref.read(
      settings.provider(pendingInviteTokenSettingDef).notifier,
    );
    final appLinks = AppLinks();

    // Initial link (cold start from invite link)
    final initialUri = await appLinks.getInitialLink();
    final initialToken = extractInviteTokenFromUri(initialUri);
    if (initialToken != null) notifier.set(initialToken);

    // Link stream (app opened from background with invite link)
    _linkSubscription = appLinks.uriLinkStream.listen((Uri uri) {
      final token = extractInviteTokenFromUri(uri);
      if (token != null) notifier.set(token);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
