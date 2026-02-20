/// Non-web: no-op. This route is only used when the app is loaded from the
/// custom domain (hisab.shenepoy.com) on web; native apps open the Supabase
/// invite-redirect URL directly when INVITE_BASE_URL is set.
void redirectToSupabaseInviteUrl(String target) {}
