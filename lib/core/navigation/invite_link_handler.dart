import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';

import 'app_router.dart';
import 'invite_auth_helpers.dart';
import 'route_paths.dart';
import '../settings/providers/settings_framework_providers.dart';
import '../settings/settings_definitions.dart';

/// Scheme used for app deep links. [inviteScheme] is current; [legacyInviteScheme]
/// stays accepted so links shared before the rename keep opening the app.
const String inviteScheme = 'com.shenepoy.hisab';
const String legacyInviteScheme = 'io.supabase.hisab';
const String _inviteHost = 'invite';

bool _isInviteScheme(String scheme) =>
    scheme == inviteScheme || scheme == legacyInviteScheme;

/// Extracts invite token from a URI (deep link or web /invite?token=...).
String? extractInviteTokenFromUri(Uri? uri) {
  if (uri == null) return null;
  final queryToken = uri.queryParameters['token']?.trim();
  final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

  String? nonEmpty(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  // Deep link: com.shenepoy.hisab://invite?token=... (or the legacy scheme).
  if (_isInviteScheme(uri.scheme)) {
    if (uri.host != _inviteHost) return null;
    return nonEmpty(queryToken) ??
        (pathSegments.isNotEmpty ? nonEmpty(pathSegments.first) : null);
  }
  // Web: https://domain/invite?token=... or /invite/:token.
  if (pathSegments.isNotEmpty && pathSegments.first == 'invite') {
    return nonEmpty(queryToken) ??
        (pathSegments.length >= 2 ? nonEmpty(pathSegments[1]) : null);
  }
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
    Uri? initialUri = await appLinks.getInitialLink();
    // Some platforms deliver the intent slightly after cold start; retry once.
    if (initialUri == null) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      initialUri = await appLinks.getInitialLink();
    }
    final initialToken = extractInviteTokenFromUri(initialUri);
    if (initialToken != null) {
      notifier.set(initialToken);
      Log.info(
        'Setting changed: ${pendingInviteTokenSettingDef.key}=(set from link)',
      );
      // Force online + go invite directly. refresh() while on onboarding is a
      // no-op for pending invite (stay-on-onboarding). Initial link wins.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        prepareInviteOnlineMode(ref);
        ref.read(routerProvider).go(RoutePaths.inviteAccept(initialToken));
      });
    }

    // Link stream (app opened from background with invite link)
    _linkSubscription = appLinks.uriLinkStream.listen((Uri uri) {
      final token = extractInviteTokenFromUri(uri);
      if (token != null) {
        notifier.set(token);
        Log.info(
          'Setting changed: ${pendingInviteTokenSettingDef.key}=(set from stream)',
        );
        if (!mounted) return;
        prepareInviteOnlineMode(ref);
        // Navigate even when already on another invite (token switch).
        ref.read(routerProvider).go(RoutePaths.inviteAccept(token));
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
