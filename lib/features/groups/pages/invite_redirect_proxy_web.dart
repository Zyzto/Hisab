import 'package:web/web.dart' as web;

/// On web: full-page redirect to the backend's invite resolver so it can
/// validate the token and send the visitor on to the redirect page.
void redirectToInviteResolver(String target) {
  web.window.location.href = target;
}
