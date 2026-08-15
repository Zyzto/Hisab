import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hisab_backend/hisab_backend.dart';

import '../../../core/navigation/invite_link_handler.dart';
import '../../../core/navigation/route_paths.dart';
import 'invite_redirect_proxy.dart';

/// Shown when an invite link on the custom domain reaches the SPA instead of
/// the static redirect page. On web it bounces straight to the backend's
/// resolver so the token can be validated and the visitor sent onward. On
/// native this route is not normally hit and only shows "Redirecting...".
///
/// An offline build has no resolver, so it explains that and offers a way home.
class InviteRedirectProxyPage extends StatefulWidget {
  const InviteRedirectProxyPage({super.key, required this.uri});

  final Uri uri;

  @override
  State<InviteRedirectProxyPage> createState() =>
      _InviteRedirectProxyPageState();
}

class _InviteRedirectProxyPageState extends State<InviteRedirectProxyPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirect());
  }

  void _redirect() {
    final invites = cloudBackend?.invites;
    final token = extractInviteTokenFromUri(widget.uri);
    if (invites == null || token == null) return;
    redirectToInviteResolver(invites.resolverUrlFor(token).toString());
  }

  @override
  Widget build(BuildContext context) {
    if (!cloudAvailable) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'onboarding_online_unavailable'.tr(),
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go(RoutePaths.home),
                    child: Text('go_home'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'redirecting'.tr(),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
