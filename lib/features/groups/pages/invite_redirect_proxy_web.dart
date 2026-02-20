import 'package:web/web.dart' as web;

/// On web: full-page redirect to the Supabase invite-redirect URL so the
/// Edge Function can validate the token and redirect to redirect.html.
void redirectToSupabaseInviteUrl(String target) {
  web.window.location.href = target;
}
