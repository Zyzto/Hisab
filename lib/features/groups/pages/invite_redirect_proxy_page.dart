import 'package:flutter/material.dart';

import '../../../core/constants/supabase_config.dart';
import 'invite_redirect_proxy.dart';

/// Page shown when the user opens the invite link on the custom domain (e.g.
/// hisab.shenepoy.com/functions/v1/invite-redirect?token=...). On web, it
/// immediately redirects to the Supabase Edge Function URL so the token can
/// be validated and the user sent to redirect.html. On non-web, this route
/// is not normally hit; shows a brief "Redirecting..." state.
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
