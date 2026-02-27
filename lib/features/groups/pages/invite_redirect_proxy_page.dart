import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/supabase_config.dart';
import '../../../core/navigation/route_paths.dart';
import 'invite_redirect_proxy.dart';

/// Page shown when the user opens the invite link on the custom domain (e.g.
/// hisab.shenepoy.com/functions/v1/invite-redirect?token=...). On web, it
/// immediately redirects to the Supabase Edge Function URL so the token can
/// be validated and the user sent to redirect.html. On non-web, this route
/// is not normally hit; shows a brief "Redirecting..." state.
/// When Supabase is not configured (local-only), shows a message and a way to go home.
class InviteRedirectProxyPage extends StatefulWidget {
  const InviteRedirectProxyPage({super.key, required this.uri});

  final Uri uri;

  @override
  State<InviteRedirectProxyPage> createState() => _InviteRedirectProxyPageState();
}

class _InviteRedirectProxyPageState extends State<InviteRedirectProxyPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirect());
  }

  void _redirect() {
    if (!supabaseConfigAvailable) return;
    final base = supabaseUrl.endsWith('/')
        ? supabaseUrl.substring(0, supabaseUrl.length - 1)
        : supabaseUrl;
    final path = widget.uri.path;
    final query = widget.uri.hasQuery ? '?${widget.uri.query}' : '';
    final target = '$base$path$query';
    redirectToSupabaseInviteUrl(target);
  }

  @override
  Widget build(BuildContext context) {
    if (!supabaseConfigAvailable) {
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
              'Redirecting...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
